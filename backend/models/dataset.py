from __future__ import annotations
from typing import Any, Optional
from pydantic import BaseModel


class ColumnProfileResponse(BaseModel):
    name: str
    col_type: str
    dtype: str
    null_count: int
    null_percent: float
    unique_count: int
    sample_values: list[Any]
    min_value: Optional[float] = None
    max_value: Optional[float] = None
    mean_value: Optional[float] = None
    median_value: Optional[float] = None
    top_values: list[dict] = []
    date_min: Optional[str] = None
    date_max: Optional[str] = None
    date_granularity: Optional[str] = None
    is_kpi_candidate: bool = False


class DatasetResponse(BaseModel):
    dataset_id: str
    filename: str
    file_type: str
    row_count: int
    col_count: int
    duplicate_row_count: int
    duplicate_row_percent: float
    ai_summary: str
    columns: list[ColumnProfileResponse]


class TablePageResponse(BaseModel):
    dataset_id: str
    page: int
    page_size: int
    total_rows: int
    total_pages: int
    columns: list[str]
    rows: list[list[Any]]


class UploadResponse(BaseModel):
    dataset_id: str
    filename: str
    file_type: str
    row_count: int
    col_count: int
    ai_summary: str
