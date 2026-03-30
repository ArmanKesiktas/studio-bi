from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers import upload, datasets, dashboard, chat

app = FastAPI(
    title="Studio BI API",
    description="AI-powered mobile analytics backend",
    version="0.1.0",
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
