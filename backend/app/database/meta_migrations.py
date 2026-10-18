"""Lightweight idempotent column migrations.

``Base.metadata.create_all`` creates missing tables but never adds columns to
existing tables, so the DB that ships already-created must be patched here.
Each entry is applied only when the column is absent, making this safe to run
on every startup.
"""

from __future__ import annotations

import logging

from sqlalchemy import inspect as sa_inspect

log = logging.getLogger(__name__)

# (table, column, ddl_fragment) applied via raw ALTER TABLE when the column
# is missing. ddl_fragment is the part after "ADD COLUMN <column> ".
_VAULT_COLUMNS = [
    ("vault_documents", "processing_status", "VARCHAR(32) NOT NULL DEFAULT 'uploaded'"),
    ("vault_documents", "processing_error", "TEXT"),
    ("vault_documents", "processing_method", "VARCHAR(32)"),
    ("vault_documents", "page_count", "INTEGER"),
]


async def run_meta_migrations(conn) -> None:
    """Ensure schema columns added after v1 exist."""
    for table, column, ddl in _VAULT_COLUMNS:
        exists = await _column_exists(conn, table, column)
        if exists:
            continue
        try:
            async with conn.begin_nested():
                await conn.exec_driver_sql(
                    f"ALTER TABLE {table} ADD COLUMN {column} {ddl}"
                )
            log.info("Added column %s.%s", table, column)
        except Exception as e:  # pragma: no cover - depends on DB dialect
            log.warning("Could not add column %s.%s: %s", table, column, e)


async def _column_exists(conn, table: str, column: str) -> bool:
    def _sync(sync_conn):
        inspector = sa_inspect(sync_conn)
        if not inspector.has_table(table):
            return False
        return column in {c["name"] for c in inspector.get_columns(table)}

    try:
        return await conn.run_sync(_sync)
    except Exception:
        return False
