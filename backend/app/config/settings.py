from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

_BACKEND_DIR = Path(__file__).resolve().parent.parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=str(_BACKEND_DIR / ".env"),
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    DATABASE_URL: str = "sqlite+aiosqlite:///./penrose_scholar.db"
    DATABASE_URL_SYNC: str = "sqlite:///./penrose_scholar.db"
    SECRET_KEY: str = "change-me-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    OPENAI_API_KEY: str = ""
    OPENAI_MODEL: str = "gpt-4o"
    CHROMA_PERSIST_DIR: str = "./chroma_data"
    MEDIA_DIR: str = "./media"
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
