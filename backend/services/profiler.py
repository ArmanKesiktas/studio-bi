"""
Dataset profiler — fully deterministic, no LLM.
Classifies columns and computes statistics.

Column types:
  DATE       — parseable datetime values (>80% success)
  METRIC     — numeric with meaningful variance (not an ID)
  DIMENSION  — low-cardinality text (<= 50 unique values)
  IDENTIFIER — high-cardinality text (names, IDs)
  FREE_TEXT  — long natural language strings
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Optional

import pandas as pd
import numpy as np


COLUMN_TYPE = str  # "DATE" | "METRIC" | "DIMENSION" | "IDENTIFIER" | "FREE_TEXT"

DIMENSION_THRESHOLD = 50      # unique value count ceiling for DIMENSION
IDENTIFIER_RATIO = 0.95       # unique/total ratio above which column is IDENTIFIER
DATE_PARSE_THRESHOLD = 0.8    # fraction of non-null values that must parse as date
METRIC_KEYWORDS = {"revenue", "sales", "amount", "total", "price", "cost", "qty",
                   "quantity", "profit", "count", "units", "income", "spend"}


@dataclass
class ColumnProfile:
    name: str
    col_type: COLUMN_TYPE
    dtype: str
    null_count: int
    null_percent: float
    unique_count: int
    sample_values: list[Any]
    # Numeric stats (METRIC only)
    min_value: Optional[float] = None
    max_value: Optional[float] = None
    mean_value: Optional[float] = None
    median_value: Optional[float] = None
    # Categorical stats (DIMENSION only)
    top_values: list[dict] = field(default_factory=list)
    # Date stats (DATE only)
    date_min: Optional[str] = None
    date_max: Optional[str] = None
    date_granularity: Optional[str] = None  # "daily" | "weekly" | "monthly" | "yearly"
    # Priority flag for KPI cards
    is_kpi_candidate: bool = False


@dataclass
class DatasetProfile:
    dataset_id: str
    row_count: int
    col_count: int
    duplicate_row_count: int
    duplicate_row_percent: float
    columns: list[ColumnProfile]


def profile_dataframe(df: pd.DataFrame, dataset_id: str) -> DatasetProfile:
    duplicate_count = int(df.duplicated().sum())
    columns = [_profile_column(df[col], col) for col in df.columns]

    return DatasetProfile(
        dataset_id=dataset_id,
        row_count=len(df),
        col_count=len(df.columns),
        duplicate_row_count=duplicate_count,
        duplicate_row_percent=round(duplicate_count / max(len(df), 1) * 100, 2),
        columns=columns,
    )


def _profile_column(series: pd.Series, name: str) -> ColumnProfile:
    null_count = int(series.isna().sum())
    total = len(series)
    null_percent = round(null_count / max(total, 1) * 100, 2)
    non_null = series.dropna()
    unique_count = int(series.nunique(dropna=True))
    sample_values = non_null.head(5).tolist()

    col_type = _classify_column(series, name, non_null, unique_count, total)

    profile = ColumnProfile(
        name=name,
        col_type=col_type,
        dtype=str(series.dtype),
        null_count=null_count,
        null_percent=null_percent,
        unique_count=unique_count,
        sample_values=[_safe_serialize(v) for v in sample_values],
        is_kpi_candidate=_is_kpi_candidate(name, col_type),
    )

    if col_type == "METRIC":
        numeric = pd.to_numeric(non_null, errors="coerce").dropna()
        profile.min_value = float(numeric.min()) if len(numeric) else None
        profile.max_value = float(numeric.max()) if len(numeric) else None
        profile.mean_value = round(float(numeric.mean()), 4) if len(numeric) else None
        profile.median_value = float(numeric.median()) if len(numeric) else None

    elif col_type == "DIMENSION":
        top = series.value_counts().head(5)
        profile.top_values = [{"value": str(k), "count": int(v)} for k, v in top.items()]

    elif col_type == "DATE":
        parsed = pd.to_datetime(non_null, errors="coerce", format="mixed").dropna()
        if len(parsed):
            profile.date_min = str(parsed.min().date())
            profile.date_max = str(parsed.max().date())
            profile.date_granularity = _infer_date_granularity(parsed)

    return profile


def _classify_column(
    series: pd.Series,
    name: str,
    non_null: pd.Series,
    unique_count: int,
    total: int,
) -> COLUMN_TYPE:
    if len(non_null) == 0:
        return "FREE_TEXT"

    # Try numeric first
    numeric = pd.to_numeric(non_null, errors="coerce")
    numeric_ratio = numeric.notna().sum() / len(non_null)

    if numeric_ratio >= 0.9:
        # Classify as IDENTIFIER only when column name looks like an ID
        # AND values are integers (no decimals). Real metrics rarely fit both.
        name_lower = name.lower()
        looks_like_id_name = any(
            name_lower.endswith(suf) or name_lower.startswith(pre)
            for suf in ("_id", "id", "_key", "_code", "_no", "_num")
            for pre in ("id_", "pk_")
        ) or name_lower in ("id", "key", "code", "no", "num", "index", "row")

        has_decimals = bool((numeric % 1 != 0).any())

        if looks_like_id_name and not has_decimals:
            return "IDENTIFIER"
        return "METRIC"

    # Try date
    parsed_dates = pd.to_datetime(non_null, errors="coerce", format="mixed")
    date_ratio = parsed_dates.notna().sum() / len(non_null)
    if date_ratio >= DATE_PARSE_THRESHOLD:
        return "DATE"

    # Text-based classification
    unique_ratio = unique_count / max(total, 1)

    if unique_count <= DIMENSION_THRESHOLD:
        return "DIMENSION"

    if unique_ratio >= IDENTIFIER_RATIO:
        return "IDENTIFIER"

    # Check average string length for free text
    avg_len = non_null.astype(str).str.len().mean()
    if avg_len > 80:
        return "FREE_TEXT"

    return "IDENTIFIER"


def _infer_date_granularity(parsed: pd.Series) -> str:
    if len(parsed) < 2:
        return "daily"
    diffs = parsed.sort_values().diff().dropna()
    median_days = diffs.dt.days.median()
    if median_days <= 1:
        return "daily"
    if median_days <= 8:
        return "weekly"
    if median_days <= 32:
        return "monthly"
    return "yearly"


def _is_kpi_candidate(name: str, col_type: COLUMN_TYPE) -> bool:
    if col_type != "METRIC":
        return False
    name_lower = name.lower()
    return any(kw in name_lower for kw in METRIC_KEYWORDS)


def _safe_serialize(value: Any) -> Any:
    if isinstance(value, (np.integer,)):
        return int(value)
    if isinstance(value, (np.floating,)):
        return float(value)
    if pd.isna(value) if not isinstance(value, (list, dict)) else False:
        return None
    return value


def profile_to_dict(profile: DatasetProfile) -> dict:
    """Convert profile to a JSON-serializable dict (for Gemini prompt)."""
    return {
        "dataset_id": profile.dataset_id,
        "row_count": profile.row_count,
        "col_count": profile.col_count,
        "duplicate_row_count": profile.duplicate_row_count,
        "columns": [
            {
                "name": c.name,
                "type": c.col_type,
                "null_percent": c.null_percent,
                "unique_count": c.unique_count,
                "sample_values": c.sample_values,
                "top_values": c.top_values,
                "min_value": c.min_value,
                "max_value": c.max_value,
                "mean_value": c.mean_value,
                "date_min": c.date_min,
                "date_max": c.date_max,
                "date_granularity": c.date_granularity,
                "is_kpi_candidate": c.is_kpi_candidate,
            }
            for c in profile.columns
        ],
    }
