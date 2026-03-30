"""
File parsing service.
Reads CSV / XLSX files into a pandas DataFrame and caches as Parquet.
Raw data never leaves this layer — only the DataFrame is passed forward.
"""

import pickle
import uuid
from pathlib import Path

import pandas as pd

from config import PARQUET_DIR, UPLOAD_DIR, settings


ALLOWED_EXTENSIONS = {".csv", ".xlsx", ".xls", ".json"}
MAX_BYTES = settings.max_upload_size_mb * 1024 * 1024


def validate_extension(filename: str) -> str:
    suffix = Path(filename).suffix.lower()
    if suffix not in ALLOWED_EXTENSIONS:
        raise ValueError(f"Desteklenmeyen dosya tipi: {suffix}. Kabul edilenler: {', '.join(ALLOWED_EXTENSIONS)}")
    return suffix


def parse_file(file_path: Path, dataset_id: str) -> pd.DataFrame:
    """Parse an uploaded file into a DataFrame and cache as Parquet."""
    suffix = Path(file_path).suffix.lower()

    if suffix == ".csv":
        df = _parse_csv(file_path)
    elif suffix in (".xlsx", ".xls"):
        df = _parse_xlsx(file_path)
    elif suffix == ".json":
        df = _parse_json(file_path)
    else:
        raise ValueError(f"Desteklenmeyen format: {suffix}")

    df = _basic_clean(df)
    _save_parquet(df, dataset_id)
    return df


def load_parquet(dataset_id: str) -> pd.DataFrame:
    """Load a previously cached DataFrame from disk."""
    path = PARQUET_DIR / f"{dataset_id}.pkl"
    if not path.exists():
        raise FileNotFoundError(f"Dataset bulunamadı: {dataset_id}")
    with open(path, "rb") as f:
        return pickle.load(f)


def _parse_csv(path: Path) -> pd.DataFrame:
    encodings = ["utf-8", "utf-8-sig", "latin-1", "iso-8859-1"]
    for enc in encodings:
        try:
            return pd.read_csv(path, encoding=enc, low_memory=False)
        except UnicodeDecodeError:
            continue
    raise ValueError("CSV dosyası okunamadı: desteklenen encoding bulunamadı.")


def _parse_xlsx(path: Path) -> pd.DataFrame:
    return pd.read_excel(path, engine="openpyxl")


def _parse_json(path: Path) -> pd.DataFrame:
    df = pd.read_json(path)
    # JSON records formatı: [{}, {}, …] — normalize edilmiş düz tablo
    if isinstance(df.columns[0], int):
        # Dikey format: normalize et
        df = pd.json_normalize(pd.read_json(path, typ="series").tolist())
    return df


def _basic_clean(df: pd.DataFrame) -> pd.DataFrame:
    # Boş sütun adlarını düzelt
    df.columns = [
        str(col).strip() if str(col).strip() else f"col_{i}"
        for i, col in enumerate(df.columns)
    ]
    # Tamamen boş satırları sil
    df = df.dropna(how="all")
    # Tamamen boş sütunları sil
    df = df.dropna(axis=1, how="all")
    return df.reset_index(drop=True)


def _save_parquet(df: pd.DataFrame, dataset_id: str) -> None:
    path = PARQUET_DIR / f"{dataset_id}.pkl"
    with open(path, "wb") as f:
        pickle.dump(df, f)
