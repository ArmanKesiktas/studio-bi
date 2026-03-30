from __future__ import annotations
from typing import Any, Optional
from pydantic import BaseModel


class ChatRequest(BaseModel):
    question: str


class ChatResponse(BaseModel):
    question: str
    answer: str
    operation_used: str
    result_data: Optional[Any] = None   # supporting data snippet shown in UI
    is_mocked: bool = False             # True when Gemini key not configured
