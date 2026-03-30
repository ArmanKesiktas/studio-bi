"""
Rule-based dashboard generator — fully deterministic, no LLM.

Rules:
  DATE + METRIC        → line chart
  DIMENSION + METRIC   → bar chart
  DIMENSION (<7 uniq)  → pie/donut chart (if paired with METRIC)
  Single METRIC        → KPI card
  Max 5 charts total
  Max 5 KPI cards total
  Pie slice cap: 7 (remainder → "Diğer / Other")
  Bar category cap: 15 (top N by value)
"""

from __future__ import annotations

import uuid
import math
from typing import Any

import pandas as pd
import numpy as np

from services.profiler import DatasetProfile, ColumnProfile


MAX_CHARTS = 5
MAX_KPI_CARDS = 5
PIE_SLICE_LIMIT = 7
BAR_CATEGORY_LIMIT = 15
MIN_LINE_POINTS = 3


def generate_dashboard(df: pd.DataFrame, profile: DatasetProfile) -> dict:
    """
    Returns a dict with keys: kpi_cards, charts
    All data inside is aggregated and ready to render — no raw rows.
    """
    cols_by_type: dict[str, list[ColumnProfile]] = {}
    for c in profile.columns:
        cols_by_type.setdefault(c.col_type, []).append(c)

    dates = cols_by_type.get("DATE", [])
    metrics = cols_by_type.get("METRIC", [])
    dimensions = cols_by_type.get("DIMENSION", [])

    kpi_cards = _build_kpi_cards(df, metrics)
    charts = _build_charts(df, dates, metrics, dimensions)

    return {"kpi_cards": kpi_cards, "charts": charts}


# ─────────────────────────────────────────────
# KPI Cards
# ─────────────────────────────────────────────

def _build_kpi_cards(df: pd.DataFrame, metrics: list[ColumnProfile]) -> list[dict]:
    cards = []

    # Always add row count as first KPI
    cards.append({
        "label": "Toplam Kayıt",
        "value_column": "_row_count",
        "aggregation": "count",
        "computed_value": len(df),
        "formatted_value": f"{len(df):,}",
    })

    # Prioritize KPI candidates (revenue/sales/amount columns)
    prioritized = [m for m in metrics if m.is_kpi_candidate]
    others = [m for m in metrics if not m.is_kpi_candidate]
    ordered = prioritized + others

    for col in ordered:
        if len(cards) >= MAX_KPI_CARDS:
            break
        numeric = pd.to_numeric(df[col.name], errors="coerce").dropna()
        if len(numeric) == 0:
            continue
        total = _safe_value(numeric.sum())
        if total is None:
            continue
        cards.append({
            "label": _humanize(col.name),
            "value_column": col.name,
            "aggregation": "sum",
            "computed_value": total,
            "formatted_value": _format_number(total),
        })

    return cards


# ─────────────────────────────────────────────
# Charts
# ─────────────────────────────────────────────

def _build_charts(
    df: pd.DataFrame,
    dates: list[ColumnProfile],
    metrics: list[ColumnProfile],
    dimensions: list[ColumnProfile],
) -> list[dict]:
    charts = []

    # 1. Line charts: DATE + METRIC
    for date_col in dates[:1]:   # use the first date column
        for metric_col in metrics[:2]:
            if len(charts) >= MAX_CHARTS:
                break
            chart = _build_line_chart(df, date_col, metric_col)
            if chart:
                charts.append(chart)

    # 2. Bar charts: DIMENSION + METRIC
    for dim_col in dimensions[:2]:
        for metric_col in metrics[:1]:
            if len(charts) >= MAX_CHARTS:
                break
            chart = _build_bar_chart(df, dim_col, metric_col)
            if chart:
                charts.append(chart)

    # 3. Pie charts: low-cardinality DIMENSION + METRIC
    for dim_col in dimensions:
        if len(charts) >= MAX_CHARTS:
            break
        if dim_col.unique_count <= 7 and metrics:
            chart = _build_pie_chart(df, dim_col, metrics[0])
            if chart:
                charts.append(chart)

    # Assign sort order
    for i, c in enumerate(charts):
        c["sort_order"] = i

    return charts


def _build_line_chart(df: pd.DataFrame, date_col: ColumnProfile, metric_col: ColumnProfile) -> dict | None:
    try:
        tmp = df[[date_col.name, metric_col.name]].copy()
        tmp[date_col.name] = pd.to_datetime(tmp[date_col.name], errors="coerce", format="mixed")
        tmp[metric_col.name] = pd.to_numeric(tmp[metric_col.name], errors="coerce")
        tmp = tmp.dropna()

        granularity = date_col.date_granularity or "monthly"
        freq_map = {"daily": "D", "weekly": "W", "monthly": "ME", "yearly": "YE"}
        freq = freq_map.get(granularity, "ME")

        grouped = tmp.set_index(date_col.name)[metric_col.name].resample(freq).sum().reset_index()
        grouped.columns = ["x", "y"]
        grouped["x"] = grouped["x"].dt.strftime("%Y-%m-%d")

        if len(grouped) < MIN_LINE_POINTS:
            return None

        data = _sanitize_records(grouped.to_dict(orient="records"))
        return {
            "chart_id": str(uuid.uuid4()),
            "chart_type": "line",
            "title": f"{_humanize(metric_col.name)} Trendi",
            "x_column": date_col.name,
            "y_column": metric_col.name,
            "aggregation": "sum",
            "ai_explanation": "",
            "data": data,
            "sort_order": 0,
        }
    except Exception:
        return None


def _build_bar_chart(df: pd.DataFrame, dim_col: ColumnProfile, metric_col: ColumnProfile) -> dict | None:
    try:
        tmp = df[[dim_col.name, metric_col.name]].copy()
        tmp[metric_col.name] = pd.to_numeric(tmp[metric_col.name], errors="coerce")
        tmp = tmp.dropna(subset=[metric_col.name])

        grouped = tmp.groupby(dim_col.name)[metric_col.name].sum().reset_index()
        grouped.columns = ["x", "y"]
        grouped = grouped.sort_values("y", ascending=False).head(BAR_CATEGORY_LIMIT)

        if len(grouped) == 0:
            return None

        data = _sanitize_records(grouped.to_dict(orient="records"))
        return {
            "chart_id": str(uuid.uuid4()),
            "chart_type": "bar",
            "title": f"{_humanize(dim_col.name)} bazında {_humanize(metric_col.name)}",
            "x_column": dim_col.name,
            "y_column": metric_col.name,
            "aggregation": "sum",
            "ai_explanation": "",
            "data": data,
            "sort_order": 0,
        }
    except Exception:
        return None


def _build_pie_chart(df: pd.DataFrame, dim_col: ColumnProfile, metric_col: ColumnProfile) -> dict | None:
    try:
        tmp = df[[dim_col.name, metric_col.name]].copy()
        tmp[metric_col.name] = pd.to_numeric(tmp[metric_col.name], errors="coerce")
        tmp = tmp.dropna(subset=[metric_col.name])

        grouped = tmp.groupby(dim_col.name)[metric_col.name].sum().reset_index()
        grouped.columns = ["label", "value"]
        grouped = grouped.sort_values("value", ascending=False)

        if len(grouped) > PIE_SLICE_LIMIT:
            top = grouped.head(PIE_SLICE_LIMIT)
            other_val = grouped.iloc[PIE_SLICE_LIMIT:]["value"].sum()
            other_row = pd.DataFrame([{"label": "Diğer", "value": other_val}])
            grouped = pd.concat([top, other_row], ignore_index=True)

        if len(grouped) < 2:
            return None

        data = _sanitize_records(grouped.to_dict(orient="records"))
        return {
            "chart_id": str(uuid.uuid4()),
            "chart_type": "pie",
            "title": f"{_humanize(dim_col.name)} Dağılımı",
            "x_column": dim_col.name,
            "y_column": metric_col.name,
            "aggregation": "sum",
            "ai_explanation": "",
            "data": data,
            "sort_order": 0,
        }
    except Exception:
        return None


# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────

def _humanize(col_name: str) -> str:
    return col_name.replace("_", " ").replace("-", " ").title()


def _format_number(value: float) -> str:
    if value is None or math.isnan(value) or math.isinf(value):
        return "N/A"
    if abs(value) >= 1_000_000:
        return f"{value / 1_000_000:.1f}M"
    if abs(value) >= 1_000:
        return f"{value / 1_000:.1f}K"
    return f"{value:,.2f}"


def _safe_value(v: Any) -> Any:
    """Convert numpy/pandas scalar to JSON-safe Python type. NaN/Inf → None."""
    if isinstance(v, (np.integer,)):
        return int(v)
    if isinstance(v, (np.floating, float)):
        f = float(v)
        if math.isnan(f) or math.isinf(f):
            return None
        return f
    return v


def _sanitize_records(records: list[dict]) -> list[dict]:
    """Replace NaN/Inf with None in a list of dicts (chart data)."""
    clean = []
    for row in records:
        clean.append({k: _safe_value(v) for k, v in row.items()})
    return clean
