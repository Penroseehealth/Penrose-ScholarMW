"""Settings facade for the speech module.

The module was written against penrose-research-assistant's lowercase config
names; this maps them onto ScholarMW's uppercase pydantic Settings so the
ported service/cloning code needs no changes.
"""

from __future__ import annotations

from types import SimpleNamespace

from app.config.settings import get_settings as _get_app_settings


def get_settings() -> SimpleNamespace:
    s = _get_app_settings()
    return SimpleNamespace(
        upload_dir=s.SPEECH_UPLOAD_DIR,
        stt_provider=s.STT_PROVIDER,
        tts_voice=s.TTS_VOICE,
        tts_speed=s.TTS_SPEED,
        tts_provider_fallback_order=s.TTS_PROVIDER_FALLBACK_ORDER,
        groq_api_key=s.GROQ_API_KEY,
        groq_base_url=s.GROQ_BASE_URL,
        groq_stt_model=s.GROQ_STT_MODEL,
        groq_tts_model=s.GROQ_TTS_MODEL,
        freeai_api_key=s.FREEAI_API_KEY,
        freeai_base_url=s.FREEAI_BASE_URL,
        freeai_tts_model=s.FREEAI_TTS_MODEL,
        clone_provider=s.CLONE_PROVIDER,
        elevenlabs_api_key=s.ELEVENLABS_API_KEY,
        elevenlabs_base_url=s.ELEVENLABS_BASE_URL,
        elevenlabs_tts_model=s.ELEVENLABS_MODEL,
        elevenlabs_clone_mode=s.ELEVENLABS_CLONE_MODE,
        elevenlabs_default_voice_id=s.ELEVENLABS_DEFAULT_VOICE_ID,
        openvoice_sidecar_url=s.OPENVOICE_SIDECAR_URL,
        openvoice_base_speaker=s.OPENVOICE_BASE_SPEAKER,
        openvoice_health_timeout_s=s.OPENVOICE_HEALTH_TIMEOUT_S,
        openvoice_synthesize_timeout_s=s.OPENVOICE_SYNTHESIZE_TIMEOUT_S,
    )
