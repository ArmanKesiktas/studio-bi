"""
Gemini API wrapper.

Rules:
  - Raw data NEVER goes to Gemini. Only schema + statistical profiles.
  - All numeric results are computed by pandas deterministically first.
  - Gemini is used for: summarization, insight narration, NL intent parsing.
"""

from __future__ import annotations

import json
import re
from typing import Any, Optional

from config import settings

_client = None


def _get_client():
    global _client
    if _client is None:
        from google import genai
        _client = genai.Client(api_key=settings.gemini_api_key)
    return _client


def is_configured() -> bool:
    return bool(settings.gemini_api_key and settings.gemini_api_key != "your_gemini_api_key_here")


# ─────────────────────────────────────────────
# 1. Dataset Summary
# ─────────────────────────────────────────────

def summarize_dataset(profile_dict: dict) -> str:
    """
    Given a dataset profile (not raw data), generate a plain-language summary.
    Returns a 2–3 sentence description of what the dataset likely represents.
    """
    if not is_configured():
        return _mock_summary(profile_dict)

    prompt = f"""You are a data analyst assistant. Analyze this dataset profile and write a concise 2–3 sentence summary in the same language the column names suggest (Turkish or English). Describe what this dataset is about, its time range if applicable, and any notable data quality issues.

Dataset profile (JSON):
{json.dumps(profile_dict, ensure_ascii=False, indent=2)}

Rules:
- Do NOT make up data that isn't in the profile.
- Be specific about column names and counts.
- Keep it under 100 words.
- Output plain text only, no markdown.
"""
    try:
        client = _get_client()
        response = client.models.generate_content(model=settings.gemini_model, contents=prompt)
        return response.text.strip()
    except Exception as e:
        return f"Veri seti özeti oluşturulamadı: {str(e)}"


# ─────────────────────────────────────────────
# 2. Chart Explanation
# ─────────────────────────────────────────────

def explain_chart(chart_config: dict, aggregated_result: dict) -> str:
    """
    Given a chart config and its aggregated data result,
    generate a 1–2 sentence plain-language explanation.
    """
    if not is_configured():
        return _mock_chart_explanation(chart_config)

    prompt = f"""You are a data analyst. Write a 1–2 sentence insight about this chart in plain language (Turkish or English based on column names).

Chart type: {chart_config.get('chart_type')}
X axis: {chart_config.get('x_column')}
Y axis: {chart_config.get('y_column')} ({chart_config.get('aggregation')})
Top data points: {json.dumps(aggregated_result.get('preview', []), ensure_ascii=False)}

Rules:
- Mention the most notable trend, peak, or pattern.
- Do not invent numbers not shown above.
- Output plain text only, no markdown.
"""
    try:
        client = _get_client()
        response = client.models.generate_content(model=settings.gemini_model, contents=prompt)
        return response.text.strip()
    except Exception as e:
        return ""


# ─────────────────────────────────────────────
# 3. Chat — Intent Parsing
# ─────────────────────────────────────────────

INTENT_SCHEMA = {
    "operation": "str — one of: sum | mean | max | min | count | count_distinct | top_n | filter | trend",
    "column": "str — the column to operate on (must exist in schema)",
    "group_by": "str | null — column to group by",
    "filter_column": "str | null — column to filter on",
    "filter_value": "str | null — value to filter by",
    "top_n": "int | null — for top_n operation, how many rows",
    "date_column": "str | null — for trend operation",
}


def parse_chat_intent(question: str, schema_summary: list[dict]) -> dict:
    """
    Parse a natural language question into a structured query intent.
    Returns a dict matching INTENT_SCHEMA.
    Gemini output is validated — falls back to safe defaults on failure.
    """
    if not is_configured():
        return _mock_intent(question)

    schema_text = json.dumps(schema_summary, ensure_ascii=False)

    prompt = f"""You are a data query planner. Convert the user's question into a structured JSON query intent.

Available columns (name + type):
{schema_text}

User question: "{question}"

Return ONLY valid JSON matching this schema (no markdown, no explanation):
{{
  "operation": "<sum|mean|max|min|count|count_distinct|top_n|filter|trend>",
  "column": "<column_name or null>",
  "group_by": "<column_name or null>",
  "filter_column": "<column_name or null>",
  "filter_value": "<value or null>",
  "top_n": <integer or null>,
  "date_column": "<column_name or null>"
}}

Rules:
- Only use column names from the available columns list above.
- If you cannot map the question to a valid query, set operation to "count" and column to null.
- Output pure JSON only.
"""
    try:
        client = _get_client()
        response = client.models.generate_content(model=settings.gemini_model, contents=prompt)
        raw = response.text.strip()
        # Strip markdown code fences if present
        raw = re.sub(r"^```(?:json)?\s*", "", raw)
        raw = re.sub(r"\s*```$", "", raw)
        intent = json.loads(raw)
        return _validate_intent(intent, schema_summary)
    except Exception:
        return {"operation": "count", "column": None, "group_by": None,
                "filter_column": None, "filter_value": None, "top_n": None, "date_column": None}


def narrate_result(question: str, result: dict) -> str:
    """
    Given a pandas query result, produce a user-friendly natural language answer.
    The result dict contains 'value' (scalar) or 'rows' (list of dicts).
    """
    if not is_configured():
        return _mock_narration(question, result)

    prompt = f"""You are a friendly data analyst. Answer the user's question based on the computed result below. Be concise (1–3 sentences). Use the same language as the question (Turkish or English).

User question: "{question}"
Computed result: {json.dumps(result, ensure_ascii=False, default=str)}

Rules:
- State the answer clearly with the actual numbers.
- If result is a list, mention the top 3 items.
- Do not guess or add information not in the result.
- Output plain text only, no markdown.
"""
    try:
        client = _get_client()
        response = client.models.generate_content(model=settings.gemini_model, contents=prompt)
        return response.text.strip()
    except Exception as e:
        return f"Sonuç: {json.dumps(result, ensure_ascii=False, default=str)}"


# ─────────────────────────────────────────────
# Validation helpers
# ─────────────────────────────────────────────

def _validate_intent(intent: dict, schema: list[dict]) -> dict:
    valid_columns = {c["name"] for c in schema}
    valid_ops = {"sum", "mean", "max", "min", "count", "count_distinct", "top_n", "filter", "trend"}

    if intent.get("operation") not in valid_ops:
        intent["operation"] = "count"
    for key in ("column", "group_by", "filter_column", "date_column"):
        if intent.get(key) and intent[key] not in valid_columns:
            intent[key] = None
    return intent


# ─────────────────────────────────────────────
# Mock responses (when API key not configured)
# ─────────────────────────────────────────────

def _mock_summary(profile: dict) -> str:
    cols = len(profile.get("columns", []))
    rows = profile.get("row_count", 0)
    return (
        f"Bu veri seti {rows} satır ve {cols} sütundan oluşmaktadır. "
        "Gemini API key ayarlandığında gerçek özet burada görünecektir."
    )


def _mock_chart_explanation(chart: dict) -> str:
    return f"{chart.get('y_column', 'Değer')} verisi {chart.get('x_column', 'kategorilere')} göre analiz edilmiştir."


def _mock_intent(question: str) -> dict:
    return {"operation": "count", "column": None, "group_by": None,
            "filter_column": None, "filter_value": None, "top_n": None, "date_column": None}


def _mock_narration(question: str, result: dict) -> str:
    return f"Gemini API key ayarlanmadığı için gerçek yanıt üretilemedi. Ham sonuç: {result}"
