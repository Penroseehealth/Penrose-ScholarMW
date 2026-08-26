from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field


class VoiceSessionState(str, Enum):
    IDLE = "idle"
    LISTENING = "listening"
    TRANSCRIBING = "transcribing"
    THINKING = "thinking"
    GENERATING = "generating"
    SPEAKING = "speaking"
    INTERRUPTED = "interrupted"


class VoiceSessionRequest(BaseModel):
    subject: str = ""
    topic: str = ""
    agent_type: str = "tutor"
    language: str = "en"


class VoiceSessionResponse(BaseModel):
    session_id: str
    state: VoiceSessionState
    created_at: datetime


class VoiceTranscriptRequest(BaseModel):
    session_id: str
    transcript: str
    is_final: bool = True
    confidence: float = 1.0


class VoiceTranscriptResponse(BaseModel):
    session_id: str
    user_text: str
    ai_text: str
    response_modality: str = "text"
    audio_url: str | None = None
    visual_data: dict | None = None
    state: VoiceSessionState
    created_at: datetime


class TTSRequest(BaseModel):
    text: str
    voice_id: str = "default"
    speed: float = 1.0
    language: str = "en"


class TTSResponse(BaseModel):
    audio_base64: str
    duration_ms: int
    sample_rate: int = 24000


class VoiceInterruptRequest(BaseModel):
    session_id: str


class ConversationTurn(BaseModel):
    role: str
    content: str
    modality: str = "text"
    timestamp: datetime = Field(default_factory=lambda: datetime.now())
    metadata: dict = Field(default_factory=dict)


class VoiceHealthResponse(BaseModel):
    status: str
    tts_available: bool
    stt_available: bool
    session_count: int
