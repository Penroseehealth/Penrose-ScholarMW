"""Narration voice catalog for tutor audio.

Exposes stable, app-level voice ids (accent + gender) that map onto concrete
provider voices, so the tutor never depends on a specific TTS vendor. Each
accent offers one male and one female voice.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass

ACCENTS: tuple[str, ...] = ("American", "British", "Indian")
GENDERS: tuple[str, ...] = ("male", "female")


@dataclass(frozen=True)
class TutorVoice:
    """A selectable narration voice."""

    id: str
    label: str
    accent: str
    gender: str
    locale: str
    provider: str
    voice_name: str
    description: str
    preview_text: str

    def to_dict(self) -> dict:
        return asdict(self)


_PREVIEW = "Let's work through this together, one clear step at a time."

VOICE_CATALOG: tuple[TutorVoice, ...] = (
    TutorVoice(
        id="en-us-male",
        label="American Male",
        accent="American",
        gender="male",
        locale="en-US",
        provider="edge",
        voice_name="en-US-GuyNeural",
        description="General American, steady and clear",
        preview_text=_PREVIEW,
    ),
    TutorVoice(
        id="en-us-female",
        label="American Female",
        accent="American",
        gender="female",
        locale="en-US",
        provider="edge",
        voice_name="en-US-AriaNeural",
        description="General American, warm and articulate",
        preview_text=_PREVIEW,
    ),
    TutorVoice(
        id="en-gb-male",
        label="British Male",
        accent="British",
        gender="male",
        locale="en-GB",
        provider="edge",
        voice_name="en-GB-RyanNeural",
        description="Received pronunciation, measured and formal",
        preview_text=_PREVIEW,
    ),
    TutorVoice(
        id="en-gb-female",
        label="British Female",
        accent="British",
        gender="female",
        locale="en-GB",
        provider="edge",
        voice_name="en-GB-SoniaNeural",
        description="Received pronunciation, calm and encouraging",
        preview_text=_PREVIEW,
    ),
    TutorVoice(
        id="en-in-male",
        label="Indian Male",
        accent="Indian",
        gender="male",
        locale="en-IN",
        provider="edge",
        voice_name="en-IN-PrabhatNeural",
        description="Indian English, direct and confident",
        preview_text=_PREVIEW,
    ),
    TutorVoice(
        id="en-in-female",
        label="Indian Female",
        accent="Indian",
        gender="female",
        locale="en-IN",
        provider="edge",
        voice_name="en-IN-NeerjaNeural",
        description="Indian English, friendly and precise",
        preview_text=_PREVIEW,
    ),
)

VOICES_BY_ID: dict[str, TutorVoice] = {v.id: v for v in VOICE_CATALOG}

# Malawi's language of instruction is British English, so that is the built-in
# default. It can be overridden at runtime via NARRATION_VOICE_ID (see
# resolve_default_voice_id); this constant remains the last-resort fallback so
# an unknown or empty setting can never leave the app without a voice.
DEFAULT_VOICE_ID = "en-gb-female"


def resolve_default_voice_id() -> str:
    """Return the configured narration voice id, falling back safely.

    Order: NARRATION_VOICE_ID when it names a real catalog voice, else the
    built-in DEFAULT_VOICE_ID. Never returns an unknown id, so callers get a
    voice the provider can actually synthesize.
    """
    from app.config.settings import get_settings

    configured = (get_settings().NARRATION_VOICE_ID or "").strip().lower()
    if configured in VOICES_BY_ID:
        return configured
    return DEFAULT_VOICE_ID


# Fallback language -> Edge voice for non-catalog locales (used when the caller
# asks for a language rather than a catalog voice id).
LANGUAGE_VOICES: dict[str, str] = {
    "en": "en-GB-SoniaNeural",
    "en-gb": "en-GB-SoniaNeural",
    "en-us": "en-US-AriaNeural",
    "en-au": "en-AU-NatashaNeural",
    "zh": "zh-CN-XiaoxiaoNeural",
    "zh-cn": "zh-CN-XiaoxiaoNeural",
    "zh-tw": "zh-TW-HsiaoChenNeural",
    "ny": "ny-CN-MwanaSpeechNeural",
    "sn": "sn-ZA-ThandiSpeechNeural",
    "es": "es-ES-ElviraNeural",
    "fr": "fr-FR-DeniseNeural",
    "pt": "pt-BR-FranciscaNeural",
}


def get_voice(voice_id: str | None) -> TutorVoice | None:
    """Return the catalog entry for a voice id, if it is a known id."""
    if not voice_id:
        return None
    return VOICES_BY_ID.get(voice_id.strip().lower())


def resolve_edge_voice(voice_id: str | None, language: str = "en") -> str:
    """Resolve a request into a concrete Edge voice name.

    Accepts a catalog id, a raw Edge voice name, or nothing at all (in which
    case the language mapping decides).
    """
    voice = get_voice(voice_id)
    if voice is not None:
        return voice.voice_name
    candidate = (voice_id or "").strip()
    if candidate.lower().endswith("neural"):
        return candidate
    return LANGUAGE_VOICES.get(
        (language or "en").strip().lower(), LANGUAGE_VOICES["en"]
    )


def voice_payloads() -> list[dict]:
    """Catalog as API payloads, with the default flagged."""
    default_id = resolve_default_voice_id()
    return [{**v.to_dict(), "is_default": v.id == default_id} for v in VOICE_CATALOG]
