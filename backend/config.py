from pydantic_settings import BaseSettings
from pathlib import Path


class Settings(BaseSettings):
    gemini_api_key: str = ""
    gemini_model: str = "gemini-2.0-flash"
    max_upload_size_mb: int = 50
    storage_path: str = "./storage"

    class Config:
        env_file = ".env"


settings = Settings()

UPLOAD_DIR = Path(settings.storage_path) / "uploads"
PARQUET_DIR = Path(settings.storage_path) / "parquet"

UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
PARQUET_DIR.mkdir(parents=True, exist_ok=True)
