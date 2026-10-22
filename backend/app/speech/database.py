"""Sync engine/session for the speech module.

The speech service, cloning and repository layers were written against a
synchronous SQLAlchemy Session; FastAPI runs their `def` endpoints in a
threadpool, so a sync session is the faithful port. Tables still live in the
same database file/server as the async engine (DATABASE_URL_SYNC mirrors
DATABASE_URL) and are created by the async `Base.metadata.create_all` in
main.py's lifespan, because the models subclass the shared async Base.
"""

from __future__ import annotations

from collections.abc import Generator
from typing import Annotated

from fastapi import Depends
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.config.settings import get_settings


def _sync_url(url: str) -> str:
    if url.startswith("postgresql+asyncpg://"):
        return "postgresql://" + url[len("postgresql+asyncpg://") :]
    if url.startswith("sqlite+aiosqlite://"):
        return "sqlite:///" + url[len("sqlite+aiosqlite://") :]
    return url


_settings = get_settings()
_sync_url = _sync_url(_settings.DATABASE_URL_SYNC)

engine = create_engine(
    _sync_url,
    # Same file as the async engine in dev (SQLite); needed so threadpool
    # sessions may touch a connection created on another thread.
    connect_args={"check_same_thread": False} if _sync_url.startswith("sqlite") else {},
)
SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


DbSessionDep = Annotated[Session, Depends(get_db)]
