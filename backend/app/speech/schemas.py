"""Schemas for the speech module."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field


class SpeechStatusView(BaseModel):
    enabled: bool
    stt_provider: str = ""
    stt_configured: bool = False
    tts_configured: bool = False
    stt_models: list[str] = []
    tts_models: list[str] = []
    tts_voices: list[str] = []
    default_voice: str = "hannah"
    max_audio_bytes: int
    # Cloning availability travels with the speech status so the Voice Training
    # Center can enable or explain the feature from one request.
    clone_available: bool = False
    clone_provider: str = ""
    default_clone_voice_id: int | None = None


class TranscriptionResult(BaseModel):
    transcript: str
    provider: str = "groq"
    model: str


class SynthesisRequest(BaseModel):
    text: str = Field(min_length=1, max_length=4000)
    voice: str | None = None
    # A cloned voice from MY VOICES, identified by its own id. Takes precedence
    # over `voice`/`default_voice`, which only address the engine's fixed list.
    voice_id: int | None = None
    speed: float | None = Field(default=None, gt=0.25, le=4.0)
    style: str | None = Field(default=None, max_length=40)
    language: str | None = Field(default=None, max_length=40)


class SynthesisResult(BaseModel):
    audio_base64: str
    mime: str = "audio/mpeg"
    provider: str = "groq"
    model: str
    voice: str = "hannah"
    speed: float = 1.0
    # The cloned voice that was actually spoken with, when one was selected.
    voice_id: int | None = None
    display_name: str = ""
    # The text that was synthesized, echoed for a clone preview so the client can
    # show what was said without keeping a second copy of the sentence.
    text: str = ""
    # Only the controls the engine honoured. Asking the engine for something it
    # cannot do is reported here rather than silently dropped, so a reply never
    # sounds different from what the request claimed.
    applied: dict[str, object] = {}
    # Set when the requested voice could not be used and the request was
    # refused. The client offers another voice or plain text; it never has to
    # guess why the audio sounded like somebody else.
    warning: str = ""
    voice_unavailable: bool = False


class VoiceProfileView(BaseModel):
    """One MY VOICES library entry, bound to a real engine voice."""

    id: int
    voice_key: str
    display_name: str
    accent_label: str = ""
    style_note: str = ""
    language: str = ""
    is_default: bool = False
    is_archived: bool = False
    source: str = "engine"
    created_at: datetime | None = None
    updated_at: datetime | None = None


class VoiceProfileCreate(BaseModel):
    voice_key: str = Field(min_length=1, max_length=64)
    display_name: str | None = Field(default=None, max_length=120)
    accent_label: str = Field(default="", max_length=80)
    style_note: str = Field(default="", max_length=300)
    language: str = Field(default="", max_length=40)
    make_default: bool = False


class VoiceProfileUpdate(BaseModel):
    """Every field optional so a rename, an archive and a default promotion can
    all go through one endpoint without clobbering the others."""

    display_name: str | None = Field(default=None, max_length=120)
    accent_label: str | None = Field(default=None, max_length=80)
    style_note: str | None = Field(default=None, max_length=300)
    language: str | None = Field(default=None, max_length=40)
    is_default: bool | None = None
    is_archived: bool | None = None


class VoicePreviewResult(BaseModel):
    """A short sample rendered with a library voice, for the MY VOICES preview."""

    audio_base64: str
    mime: str = "audio/wav"
    provider: str = "groq"
    model: str
    voice: str
    speed: float = 1.0


# --- cloned voices -----------------------------------------------------------


class CloneStatusView(BaseModel):
    """Whether training is offered at all, and what the provider accepts."""

    clone_available: bool = False
    clone_provider: str = ""
    # Whether the configured provider is answering, as opposed to merely being
    # configured. A stopped local sidecar must read as "start the sidecar", not
    # as "no provider configured" â€” the user would otherwise edit settings that
    # are already correct, or record a sample and only learn of the failure
    # after the backend could not make the call.
    clone_reachable: bool = True
    clone_models: list[str] = []
    speaking_styles: list[str] = []
    min_sample_ms: int = 8000
    max_sample_ms: int = 300000
    consent_text: str = ""
    default_clone_voice_id: int | None = None
    # True for providers that need minutes rather than seconds per reply. The UI
    # needs this to say so up front instead of looking frozen, and it is part of
    # the honest description of what the provider does â€” the alternative is a
    # spinner with no explanation on a request that is genuinely slow.
    synthesis_is_slow: bool = False
    # Sample containers this provider can actually train from. The UI needs it to
    # convert a capture up front: a client that hands over a container the
    # trainer cannot decode (OpenVoice reading a browser WebM) otherwise only
    # discovers the limit as an opaque failure.
    clone_sample_formats: list[str] = []
    # The subset of clone_models that can actually be produced. OpenVoice accepts
    # five base speakers but ships reference embeddings for only two, so the other
    # three fall back to en-us; offering them unchecked would present a picker of
    # accents that silently do not happen. Empty means "not applicable" (every
    # other provider), never "none available".
    base_speakers_available: list[str] = []


class VoiceModelVersionView(BaseModel):
    id: int
    voice_id: int
    version: int
    provider_voice_id: str = ""
    model_version: str = ""
    status: str = "queued"
    error_message: str = ""
    sample_ref: str = ""
    sample_mime: str = ""
    sample_duration_ms: int = 0
    sample_sha256: str = ""
    similarity_label: str = ""
    similarity_score: float = 0.0
    quality: dict = {}
    created_at: datetime | None = None


class VoiceModelView(BaseModel):
    """One cloned voice, with every training run it has had."""

    id: int
    voice_id: int
    display_name: str
    provider: str = ""
    language: str = ""
    accent_label: str = ""
    status: str = "queued"
    current_version_id: int | None = None
    similarity_label: str = ""
    similarity_score: float = 0.0
    consent_given: bool = False
    consent_text: str = ""
    consented_at: datetime | None = None
    is_default: bool = False
    is_archived: bool = False
    created_at: datetime | None = None
    updated_at: datetime | None = None
    versions: list[VoiceModelVersionView] = []


class VoiceModelRename(BaseModel):
    display_name: str = Field(min_length=1, max_length=120)
    language: str | None = Field(default=None, max_length=40)
    accent_label: str | None = Field(default=None, max_length=80)


class VoiceModelUpdate(BaseModel):
    """Optional-everything, so archive and "Use for Penrose" go through one path."""

    is_default: bool | None = None
    is_archived: bool | None = None


class CloneTrainResult(BaseModel):
    voice: VoiceModelView
    version: VoiceModelVersionView
    warnings: list[str] = []


class VoiceComparisonResult(BaseModel):
    """Â§18: the same paragraph in the cloned voice and an engine voice."""

    voice_id: int
    display_name: str
    text: str
    similarity_label: str = "Unknown"
    clone: dict = {}
    original: dict = {}
