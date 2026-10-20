from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

_BACKEND_DIR = Path(__file__).resolve().parent.parent.parent

# Anchor file-backed storage to the backend root instead of the process working
# directory, so databases/media are always found regardless of where the server
# is launched from (this avoids "file not found" for uploaded documents).
_BACKEND_DIR_POSIX = _BACKEND_DIR.as_posix()
_DEFAULT_DB_URL_ASYNC = f"sqlite+aiosqlite:///{_BACKEND_DIR_POSIX}/penrose_scholar.db"
_DEFAULT_DB_URL_SYNC = f"sqlite:///{_BACKEND_DIR_POSIX}/penrose_scholar.db"
_DEFAULT_MEDIA_DIR = str(_BACKEND_DIR / "media")
_DEFAULT_CHROMA_PERSIST_DIR = str(_BACKEND_DIR / "chroma_data")


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=str(_BACKEND_DIR / ".env"),
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    DATABASE_URL: str = _DEFAULT_DB_URL_ASYNC
    DATABASE_URL_SYNC: str = _DEFAULT_DB_URL_SYNC
    SECRET_KEY: str = "change-me-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    OPENAI_API_KEY: str = ""
    OPENAI_MODEL: str = "gpt-4o"
    CHROMA_PERSIST_DIR: str = _DEFAULT_CHROMA_PERSIST_DIR
    MEDIA_DIR: str = _DEFAULT_MEDIA_DIR
    # Max upload size (in MB) for the knowledge vault and OCR uploads.
    VAULT_MAX_FILE_SIZE_MB: int = 200
    CORS_ORIGINS: list[str] = [
        "http://localhost:3000",
        "http://localhost:3001",
        "http://localhost:8080",
        "http://localhost:8000",
    ]
    ENVIRONMENT: str = "development"
    CLOUDFLARE_ACCOUNT_ID: str = ""
    CLOUDFLARE_API_TOKEN: str = ""
    CLOUDFLARE_AI_MODEL: str = "@cf/meta/llama-3.3-70b-instruct-fp8-fast"
    HUGGINGFACE_API_TOKEN: str = ""
    HUGGINGFACE_MODEL: str = "meta-llama/Llama-4-Scout-17B-16E-Instruct"
    GROQ_API_KEY: str = ""
    GROQ_MODEL: str = "llama-3.3-70b-versatile"

    # --- Educational retrieval (grounding) --------------------------------
    # Live, keyless academic/open-knowledge sources used to ground answers.
    RETRIEVAL_ENABLED: bool = True
    RETRIEVAL_TIMEOUT_SECONDS: float = 8.0
    RETRIEVAL_MAX_RESULTS_PER_PROVIDER: int = 5
    RETRIEVAL_MAX_SNIPPETS: int = 8
    # A polite identifier for open APIs (OpenAlex/Crossref request this).
    RETRIEVAL_CONTACT_EMAIL: str = "scholarai@penrose.local"
    # Wikipedia/Wikidata language edition.
    RETRIEVAL_WIKI_LANG: str = "en"

    # ElevenLabs (cloud TTS + STT, free renewable tier)
    ELEVENLABS_API_KEY: str = ""
    ELEVENLABS_VOICE_ID: str = "JBFqnCBsd6RMkjVDRZzb"
    ELEVENLABS_MODEL: str = "eleven_multilingual_v2"
    ELEVENLABS_STT_MODEL: str = "scribe_v1"

    # Video generation providers (kept only on the backend)
    RUNWAY_API_KEY: str = ""
    RUNWAY_API_SECRET: str = ""
    RUNWAY_MODEL: str = "gen3a_turbo"
    LUMA_API_KEY: str = ""
    LUMA_MODEL: str = "ray-2"

    # LiveKit (video/audio conferencing) — server-side only
    LIVEKIT_URL: str = ""
    LIVEKIT_API_KEY: str = ""
    LIVEKIT_API_SECRET: str = ""

    # --- Speech / Voice Training Center (TTS, STT, voice cloning) ---------
    ENABLE_SPEECH: bool = True
    SPEECH_UPLOAD_DIR: str = str(_BACKEND_DIR / "storage" / "uploads")
    STT_PROVIDER: str = ""  # e.g. "groq" when GROQ_API_KEY is set
    TTS_VOICE: str = "hannah"
    TTS_SPEED: float = 1.0
    TTS_PROVIDER_FALLBACK_ORDER: list[str] = ["groq", "freeai"]
    GROQ_BASE_URL: str = "https://api.groq.com/openai/v1"
    GROQ_STT_MODEL: str = "whisper-large-v3-turbo"
    GROQ_TTS_MODEL: str = "canopylabs/orpheus-v1-english"
    FREEAI_API_KEY: str = ""
    FREEAI_BASE_URL: str = "https://api.freeai.com/v1"
    FREEAI_TTS_MODEL: str = "tts-1"
    # Voice cloning providers: "openvoice" (local sidecar, no key) or
    # "elevenlabs" (hosted, paid key). Empty = cloning disabled.
    CLONE_PROVIDER: str = ""
    ELEVENLABS_BASE_URL: str = "https://api.elevenlabs.io/v1"
    ELEVENLABS_CLONE_MODE: str = "instant"
    ELEVENLABS_DEFAULT_VOICE_ID: str = ""
    OPENVOICE_SIDECAR_URL: str = "http://127.0.0.1:8011"
    OPENVOICE_BASE_SPEAKER: str = "EN-US"
    OPENVOICE_HEALTH_TIMEOUT_S: float = 3.0
    OPENVOICE_SYNTHESIZE_TIMEOUT_S: float = 900.0

    @property
    def livekit_configured(self) -> bool:
        return bool(
            self.LIVEKIT_URL and self.LIVEKIT_API_KEY and self.LIVEKIT_API_SECRET
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()
