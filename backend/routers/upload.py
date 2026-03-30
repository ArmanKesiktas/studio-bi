import uuid
import shutil
from pathlib import Path

from fastapi import APIRouter, File, HTTPException, UploadFile

from config import UPLOAD_DIR, settings
from models.dataset import UploadResponse
from services import file_parser, profiler
from services.profiler import profile_to_dict
from services import gemini

router = APIRouter()


@router.post("/upload", response_model=UploadResponse)
async def upload_file(file: UploadFile = File(...)):
    # Validate extension
    try:
        suffix = file_parser.validate_extension(file.filename or "")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    # Check file size
    max_bytes = settings.max_upload_size_mb * 1024 * 1024
    contents = await file.read()
    if len(contents) > max_bytes:
        raise HTTPException(
            status_code=413,
            detail=f"Dosya boyutu {settings.max_upload_size_mb}MB limitini aşıyor.",
        )

    # Save to disk
    dataset_id = str(uuid.uuid4())
    safe_name = f"{dataset_id}{suffix}"
    save_path = UPLOAD_DIR / safe_name
    save_path.write_bytes(contents)

    # Parse + profile
    try:
        df = file_parser.parse_file(save_path, dataset_id)
    except Exception as e:
        save_path.unlink(missing_ok=True)
        raise HTTPException(status_code=422, detail=f"Dosya okunamadı: {str(e)}")

    profile = profiler.profile_dataframe(df, dataset_id)
    profile_dict = profile_to_dict(profile)

    # Gemini summary (non-blocking: if it fails, we continue)
    ai_summary = gemini.summarize_dataset(profile_dict)

    return UploadResponse(
        dataset_id=dataset_id,
        filename=file.filename or safe_name,
        file_type=suffix.lstrip("."),
        row_count=profile.row_count,
        col_count=profile.col_count,
        ai_summary=ai_summary,
    )
