import sqlite3
from contextlib import contextmanager
from typing import Iterator

from .config import database_path


@contextmanager
def connection() -> Iterator[sqlite3.Connection]:
    path = database_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(path)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA foreign_keys = ON")
    try:
        yield db
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


def initialize_database() -> None:
    with connection() as db:
        db.executescript(
            """
            CREATE TABLE IF NOT EXISTS maps (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                config_json TEXT NOT NULL,
                annotations_json TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_maps_updated_at
                ON maps(updated_at DESC);
            CREATE TABLE IF NOT EXISTS exports (
                id TEXT PRIMARY KEY,
                map_id TEXT NOT NULL REFERENCES maps(id) ON DELETE CASCADE,
                kind TEXT NOT NULL CHECK(kind IN ('png')),
                media_type TEXT NOT NULL,
                content BLOB NOT NULL,
                created_at TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_exports_map_id
                ON exports(map_id, created_at DESC);
            """
        )
