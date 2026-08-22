"""Multimodal schemas for ScholarAI file upload, voice, and TTS."""

from __future__ import annotations

from datetime import datetime

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
    text: str
    voice_id: str = "default"
    speed: float = 1.0
    language: str = "en"


class TTSResponse(BaseModel):
    audio_url: str
    duration_seconds: float
    voice_id: str


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
