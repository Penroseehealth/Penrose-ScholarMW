from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field

from app.voice.voice_catalog import DEFAULT_VOICE_ID


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


class SpeechScenario(str, Enum):
    NATURAL_CONVERSATION = "natural_conversation"
    CLASSROOM_TEACHING = "classroom_teaching"
    ACADEMIC_PRESENTATION = "academic_presentation"
    ONE_TO_ONE_TUTORING = "one_to_one_tutoring"
    STORYTELLING = "storytelling"
    SCIENTIFIC_EXPLANATION = "scientific_explanation"
    PODCAST_DISCUSSION = "podcast_discussion"


class SpeechDeliveryStyle(str, Enum):
    CLEAN_NATURAL = "clean_natural"
    CONVERSATIONAL = "conversational"
    HIGHLY_EXPRESSIVE = "highly_expressive"
    PROFESSIONAL = "professional"


class SpeechMode(str, Enum):
    CONVERSATION = "conversation"
    FAITHFUL_READING = "faithful_reading"


class TTSRequest(BaseModel):
    text: str = Field(min_length=1)
    voice_id: str = "default"
    speed: float = Field(default=1.0, ge=0.5, le=2.0)
    language: str = "en"
    scenario: SpeechScenario = SpeechScenario.NATURAL_CONVERSATION
    delivery_style: SpeechDeliveryStyle = SpeechDeliveryStyle.CLEAN_NATURAL
    mode: SpeechMode = SpeechMode.CONVERSATION


class TTSResponse(BaseModel):
    audio_base64: str
    duration_ms: int
    sample_rate: int = 24000
    provider: str = "browser"
    scenario: SpeechScenario = SpeechScenario.NATURAL_CONVERSATION
    delivery_style: SpeechDeliveryStyle = SpeechDeliveryStyle.CLEAN_NATURAL
    mode: SpeechMode = SpeechMode.CONVERSATION
    applied_controls: dict[str, str | float | bool] = Field(default_factory=dict)


class VoiceInterruptRequest(BaseModel):
    session_id: str


class ConversationTurn(BaseModel):
    role: str
    content: str
    modality: str = "text"
    timestamp: datetime = Field(default_factory=lambda: datetime.now())
    metadata: dict = Field(default_factory=dict)


class VoiceOption(BaseModel):
    id: str
    label: str
    accent: str
    gender: str
    locale: str
    provider: str
    voice_name: str
    description: str
    preview_text: str
    is_default: bool = False


class VoiceListResponse(BaseModel):
    voices: list[VoiceOption]
    accents: list[str]
    genders: list[str]
    default_voice_id: str


class VoiceHealthResponse(BaseModel):
    status: str
    tts_available: bool
    stt_available: bool
    session_count: int
    default_voice_id: str = DEFAULT_VOICE_ID
    provider: str = "browser"
