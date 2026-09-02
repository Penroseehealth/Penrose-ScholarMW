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

    @property
    def livekit_configured(self) -> bool:
        return bool(
            self.LIVEKIT_URL and self.LIVEKIT_API_KEY and self.LIVEKIT_API_SECRET
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()
