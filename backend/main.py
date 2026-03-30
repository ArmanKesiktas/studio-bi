import math
import json
from typing import Any

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from routers import upload, datasets, dashboard, chat


class _SafeEncoder(json.JSONEncoder):
    """Replace NaN / Infinity with null so JSON is always valid."""

    def default(self, o: Any) -> Any:
        if isinstance(o, float) and (math.isnan(o) or math.isinf(o)):
            return None
        return super().default(o)

    def encode(self, o: Any) -> str:
        return super().encode(_sanitize(o))


def _sanitize(obj: Any) -> Any:
    if isinstance(obj, float):
        if math.isnan(obj) or math.isinf(obj):
            return None
    elif isinstance(obj, dict):
        return {k: _sanitize(v) for k, v in obj.items()}
    elif isinstance(obj, (list, tuple)):
        return [_sanitize(v) for v in obj]
    return obj


class SafeJSONResponse(JSONResponse):
    def render(self, content: Any) -> bytes:
        return json.dumps(
            content,
            ensure_ascii=False,
            allow_nan=False,
            cls=_SafeEncoder,
            default=str,
        ).encode("utf-8")


app = FastAPI(
    title="Studio BI API",
    description="AI-powered mobile analytics backend",
    version="0.1.0",
    default_response_class=SafeJSONResponse,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(upload.router, tags=["upload"])
app.include_router(datasets.router, tags=["datasets"])
app.include_router(dashboard.router, tags=["dashboard"])
app.include_router(chat.router, tags=["chat"])


@app.get("/health")
def health():
    return {"status": "ok"}
