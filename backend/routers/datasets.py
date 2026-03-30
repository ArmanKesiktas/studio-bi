import math
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import StreamingResponse
import io

from config import PARQUET_DIR, UPLOAD_DIR
from models.dataset import DatasetResponse, ColumnProfileResponse, TablePageResponse
from services import file_parser, profiler
from services.profiler import profile_to_dict
from services import gemini

router = APIRouter()

PAGE_SIZE = 100


def _load_profile(dataset_id: str):
    try:
        df = file_parser.load_parquet(dataset_id)
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail=f"Dataset bulunamadı: {dataset_id}")
    return df


@router.get("/datasets/{dataset_id}", response_model=DatasetResponse)
def get_dataset(dataset_id: str):
    df = _load_profile(dataset_id)
    profile = profiler.profile_dataframe(df, dataset_id)
    profile_dict = profile_to_dict(profile)
    ai_summary = gemini.summarize_dataset(profile_dict)

    # Find original filename from uploads dir
    filename = _find_filename(dataset_id)

    columns = [
        ColumnProfileResponse(
            name=c.name,
            col_type=c.col_type,
            dtype=c.dtype,
            null_count=c.null_count,
            null_percent=c.null_percent,
            unique_count=c.unique_count,
            sample_values=c.sample_values,
            min_value=c.min_value,
            max_value=c.max_value,
            mean_value=c.mean_value,
            median_value=c.median_value,
            top_values=c.top_values,
            date_min=c.date_min,
            date_max=c.date_max,
            date_granularity=c.date_granularity,
            is_kpi_candidate=c.is_kpi_candidate,
        )
        for c in profile.columns
    ]

    return DatasetResponse(
        dataset_id=dataset_id,
        filename=filename,
        file_type=Path(filename).suffix.lstrip("."),
        row_count=profile.row_count,
        col_count=profile.col_count,
        duplicate_row_count=profile.duplicate_row_count,
        duplicate_row_percent=profile.duplicate_row_percent,
        ai_summary=ai_summary,
        columns=columns,
    )


@router.get("/datasets/{dataset_id}/table", response_model=TablePageResponse)
def get_table(
    dataset_id: str,
    page: int = Query(1, ge=1),
    page_size: int = Query(PAGE_SIZE, ge=1, le=500),
):
    df = _load_profile(dataset_id)
    total_rows = len(df)
    total_pages = max(1, math.ceil(total_rows / page_size))

    if page > total_pages:
        raise HTTPException(status_code=400, detail=f"Sayfa {page} mevcut değil. Toplam: {total_pages}")

    start = (page - 1) * page_size
    end = start + page_size
    page_df = df.iloc[start:end]

    # Serialize safely
    rows = []
    for _, row in page_df.iterrows():
        rows.append([_safe(v) for v in row.tolist()])

    return TablePageResponse(
        dataset_id=dataset_id,
        page=page,
        page_size=page_size,
        total_rows=total_rows,
        total_pages=total_pages,
        columns=list(df.columns),
        rows=rows,
    )


@router.get("/datasets/{dataset_id}/export/csv")
def export_csv(dataset_id: str):
    df = _load_profile(dataset_id)
    buf = io.StringIO()
    df.to_csv(buf, index=False, encoding="utf-8")
    buf.seek(0)
    return StreamingResponse(
        iter([buf.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={dataset_id}.csv"},
    )


def _find_filename(dataset_id: str) -> str:
    for ext in (".csv", ".xlsx", ".xls"):
        path = UPLOAD_DIR / f"{dataset_id}{ext}"
        if path.exists():
            return path.name
    return f"{dataset_id}.csv"


def _safe(value):
    import math as _math
    import numpy as _np
    if isinstance(value, (_np.integer,)):
        return int(value)
    if isinstance(value, (_np.floating,)):
        if _math.isnan(value) or _math.isinf(value):
            return None
        return float(value)
    if isinstance(value, _np.bool_):
        return bool(value)
    try:
        if _math.isnan(value):
            return None
    except (TypeError, ValueError):
        pass
    return value
