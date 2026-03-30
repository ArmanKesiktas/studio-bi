"""
Chat router — safe NL → pandas → Gemini narration pipeline.

Flow:
  1. Parse user question → structured intent (Gemini)
  2. Execute intent against real DataFrame (pandas, deterministic)
  3. Narrate the result (Gemini)
  4. Return answer + supporting data snippet

Gemini never touches raw data — only the aggregated result.
"""

from __future__ import annotations

from typing import Any

import pandas as pd
from fastapi import APIRouter, HTTPException

from models.chat import ChatRequest, ChatResponse
from services import file_parser, profiler, gemini

router = APIRouter()


@router.post("/datasets/{dataset_id}/chat", response_model=ChatResponse)
def chat_with_data(dataset_id: str, request: ChatRequest):
    try:
        df = file_parser.load_parquet(dataset_id)
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail=f"Dataset bulunamadı: {dataset_id}")

    profile = profiler.profile_dataframe(df, dataset_id)
    schema_summary = [
        {"name": c.name, "type": c.col_type}
        for c in profile.columns
    ]

    # Step 1: Parse intent
    intent = gemini.parse_chat_intent(request.question, schema_summary)

    # Step 2: Execute deterministically
    result, result_data = _execute_intent(df, intent)

    # Step 3: Narrate
    answer = gemini.narrate_result(request.question, result)

    return ChatResponse(
        question=request.question,
        answer=answer,
        operation_used=intent.get("operation", "unknown"),
        result_data=result_data,
        is_mocked=not gemini.is_configured(),
    )


# ─────────────────────────────────────────────
# Deterministic execution engine
# ─────────────────────────────────────────────

def _execute_intent(df: pd.DataFrame, intent: dict) -> tuple[dict, Any]:
    op = intent.get("operation", "count")
    col = intent.get("column")
    group_by = intent.get("group_by")
    filter_col = intent.get("filter_column")
    filter_val = intent.get("filter_value")
    top_n = intent.get("top_n") or 5
    date_col = intent.get("date_column")

    # Apply filter first if requested
    working_df = df.copy()
    if filter_col and filter_col in df.columns and filter_val:
        mask = working_df[filter_col].astype(str).str.lower() == str(filter_val).lower()
        working_df = working_df[mask]

    try:
        if op == "count":
            value = len(working_df)
            return {"value": value, "label": "Toplam kayıt"}, value

        if op == "count_distinct" and col and col in df.columns:
            value = int(working_df[col].nunique())
            return {"value": value, "label": f"{col} benzersiz değer sayısı"}, value

        if op in ("sum", "mean", "max", "min") and col and col in df.columns:
            numeric = pd.to_numeric(working_df[col], errors="coerce").dropna()
            if op == "sum":
                value = float(numeric.sum())
            elif op == "mean":
                value = round(float(numeric.mean()), 4)
            elif op == "max":
                value = float(numeric.max())
            else:
                value = float(numeric.min())
            return {"value": value, "column": col, "operation": op}, value

        if op == "top_n" and col and col in df.columns:
            if group_by and group_by in df.columns:
                numeric_col = col
                numeric = pd.to_numeric(working_df[numeric_col], errors="coerce")
                working_df = working_df.copy()
                working_df[numeric_col] = numeric
                grouped = working_df.groupby(group_by)[numeric_col].sum().reset_index()
                grouped = grouped.sort_values(numeric_col, ascending=False).head(int(top_n))
                rows = grouped.to_dict(orient="records")
                return {"rows": rows, "group_by": group_by, "value_column": col}, rows
            else:
                top = working_df[col].value_counts().head(int(top_n))
                rows = [{"value": str(k), "count": int(v)} for k, v in top.items()]
                return {"rows": rows, "column": col}, rows

        if op == "trend" and date_col and col and date_col in df.columns and col in df.columns:
            tmp = working_df[[date_col, col]].copy()
            tmp[date_col] = pd.to_datetime(tmp[date_col], errors="coerce", format="mixed")
            tmp[col] = pd.to_numeric(tmp[col], errors="coerce")
            tmp = tmp.dropna()
            grouped = tmp.set_index(date_col)[col].resample("ME").sum().reset_index()
            grouped.columns = ["date", "value"]
            grouped["date"] = grouped["date"].dt.strftime("%Y-%m")
            rows = grouped.to_dict(orient="records")
            return {"rows": rows, "type": "trend"}, rows

        # Fallback: row count
        return {"value": len(working_df), "label": "Toplam kayıt"}, len(working_df)

    except Exception as e:
        return {"error": str(e), "value": len(df)}, None
