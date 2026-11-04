"""Multimodal schemas for ScholarAI file upload, voice, and TTS."""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class FileUploadResponse(BaseModel):
    file_id: str
    filename: str
    file_type: str
    size_bytes: int
    status: str = "ready"
    extracted_text: str | None = None
    error: str | None = None


class MultimodalChatRequest(BaseModel):
    message: str
    session_id: int | None = None
    agent_type: str = "tutor"
    context_course_id: int | None = None
    file_ids: list[str] = Field(default_factory=list)


class MultimodalChatResponse(BaseModel):
    id: int
    role: str
    content: str
    sources: str | None = None
    attachments: list[dict] | None = None
    created_at: datetime
    model_config = {"from_attributes": True}


class VoiceUploadRequest(BaseModel):
    transcript: str
    session_id: int | None = None


class TTSRequest(BaseModel):
    text: str = Field(min_length=1)
    voice_id: str = "default"
    speed: float = Field(default=1.0, ge=0.5, le=2.0)
    language: str = "en"
    scenario: Literal[
        "natural_conversation",
        "classroom_teaching",
        "academic_presentation",
        "one_to_one_tutoring",
        "storytelling",
        "scientific_explanation",
        "podcast_discussion",
    ] = "natural_conversation"
    delivery_style: Literal[
        "clean_natural", "conversational", "highly_expressive", "professional"
    ] = "clean_natural"
    mode: Literal["conversation", "faithful_reading"] = "conversation"


class TTSResponse(BaseModel):
    audio_url: str | None = None
    duration_seconds: float
    voice_id: str
    audio_base64: str
    provider: str
    applied_controls: dict[str, str | float | bool] = Field(default_factory=dict)


class VoiceListItem(BaseModel):
    voice_id: str
    name: str
    preview_url: str | None = None
    language: str
    gender: str | None = None
    description: str | None = None
    is_default: bool = False


class VoiceSettings(BaseModel):
    default_voice_id: str = "en-us-academic-female-1"
    playback_speed: float = 1.0
    auto_read: bool = False
    stt_language: str = "auto"
    tts_language: str = "auto"


class VoiceCloneRequest(BaseModel):
    voice_name: str
    consent_confirmed: bool = False
    sample_text: str | None = None


class VoiceCloneResponse(BaseModel):
    clone_id: str
    voice_name: str
    status: str
    created_at: datetime
    message: str | None = None


class STEMNotationRequest(BaseModel):
    latex: str
    language: str = "en"


class STEMNotationResponse(BaseModel):
    original_latex: str
    speech_text: str
    language: str


class FileAttachment(BaseModel):
    file_id: str
    filename: str
    file_type: str
    size_bytes: int
    status: str = "ready"
    extracted_text: str | None = None


class ChatSessionWithFiles(BaseModel):
    id: int
    title: str
    agent_type: str
    attachments: list[FileAttachment] = []
    created_at: datetime
    updated_at: datetime
    model_config = {"from_attributes": True}
