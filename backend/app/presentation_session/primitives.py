"""Presentation-session primitives: event sequencing + voice lease.

Phase 1 delivers the concurrency primitives; Phase 2 builds the HTTP surface
around them. Everything here talks to the database directly, because the
FastAPI app and the LiveKit agent worker are separate processes and the
database is their ONLY coordination channel (approved Phase 0D design).
"""

from __future__ import annotations

import json
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import text, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.presentation import PresentationSession, PresentationSessionEvent


# ---------------------------------------------------------------------------
# Transactional event sequencing with idempotency
# ---------------------------------------------------------------------------


async def record_event(
    db: AsyncSession,
    *,
    session_id: str,
    event_type: str,
    event_key: str | None = None,
    payload: dict | None = None,
    actor_role: str = "system",
    actor_user_id: int | None = None,
    persistence: str = "persistent",
) -> dict:
    """Append one event with a transactionally-assigned sequence number.

    The seq comes from a single ``INSERT ... SELECT max(seq)+1`` so two
    concurrent writers get distinct, ordered sequences without a separate
    counter table; the unique constraint on (session_id, seq) makes any
    residual race a hard, visible failure rather than silent duplication.

    ``event_key`` is the idempotency handle: a repeat call with the same key
    on the same session returns the EXISTING event (matched=True) and writes
    nothing — duplicates can never trigger duplicate actions downstream.
    """
    if event_key is None:
        event_key = uuid.uuid4().hex

    existing = await db.execute(
        text(
            "SELECT id, seq, event_type FROM presentation_session_events "
            "WHERE session_id = :sid AND event_key = :key"
        ),
        {"sid": session_id, "key": event_key},
    )
    row = existing.first()
    if row is not None:
        return {
            "id": row.id,
            "seq": row.seq,
            "event_type": row.event_type,
            "matched": True,
        }

    result = await db.execute(
        text(
            "INSERT INTO presentation_session_events "
            "(session_id, seq, event_key, event_type, actor_role, actor_user_id, "
            " persistence, payload_json, created_at) "
            "SELECT :sid, COALESCE(MAX(seq), 0) + 1, :key, :etype, :role, :uid, "
            " :persist, :payload, CURRENT_TIMESTAMP "
            "FROM presentation_session_events WHERE session_id = :sid"
        ),
        {
            "sid": session_id,
            "key": event_key,
            "etype": event_type,
            "role": actor_role,
            "uid": actor_user_id,
            "persist": persistence,
            "payload": json.dumps(payload) if payload else None,
        },
    )
    await db.commit()

    stored = await db.execute(
        text(
            "SELECT id, seq FROM presentation_session_events "
            "WHERE session_id = :sid AND event_key = :key"
        ),
        {"sid": session_id, "key": event_key},
    )
    row = stored.first()
    return {"id": row.id, "seq": row.seq, "event_type": event_type, "matched": False}


async def replay_events(
    db: AsyncSession, *, session_id: str, after_seq: int = 0
) -> list[dict]:
    """Persistent events after ``after_seq``, in order — the reconnect
    replay. Ephemeral events are never returned."""
    result = await db.execute(
        text(
            "SELECT seq, event_key, event_type, payload_json, created_at "
            "FROM presentation_session_events "
            "WHERE session_id = :sid AND seq > :after AND persistence = 'persistent' "
            "ORDER BY seq"
        ),
        {"sid": session_id, "after": after_seq},
    )
    events = []
    for row in result:
        try:
            payload = json.loads(row.payload_json) if row.payload_json else None
        except (TypeError, ValueError):
            payload = None
        events.append(
            {
                "seq": row.seq,
                "event_key": row.event_key,
                "event_type": row.event_type,
                "payload": payload,
                "created_at": row.created_at.isoformat() if hasattr(row.created_at, "isoformat") else row.created_at,
            }
        )
    return events


# ---------------------------------------------------------------------------
# Atomic voice lease (cross-process single-owner arbitration)
# ---------------------------------------------------------------------------

LEASE_TTL_S = 15
SPEECH_COOLDOWN_S = 2


async def acquire_voice_lease(
    db: AsyncSession, *, session_id: str, owner: str, ttl_s: int = LEASE_TTL_S
) -> dict:
    """Atomically claim AI audio ownership for a session.

    One UPDATE statement decides the winner, so this is safe across the two
    processes without any in-process lock: only when the lease is free (or
    expired, or past the post-interrupt cooldown) does the row change. The
    caller that affected zero rows lost and must not speak.
    """
    now = datetime.now(timezone.utc)
    token = uuid.uuid4().hex
    result = await db.execute(
        update(PresentationSession)
        .where(PresentationSession.id == session_id)
        .where(
            (PresentationSession.voice_owner == "none")
            | (PresentationSession.voice_lease_expires_at < now)
        )
        .where(
            (PresentationSession.voice_next_allowed_at.is_(None))
            | (PresentationSession.voice_next_allowed_at <= now)
        )
        .values(
            voice_owner=owner,
            voice_lease_token=token,
            voice_lease_expires_at=now + timedelta(seconds=ttl_s),
        )
    )
    await db.commit()
    return {"acquired": result.rowcount == 1, "token": token if result.rowcount == 1 else None}


async def renew_voice_lease(
    db: AsyncSession, *, session_id: str, token: str, ttl_s: int = LEASE_TTL_S
) -> bool:
    """Extend the lease. Only the current token holder can renew."""
    now = datetime.now(timezone.utc)
    result = await db.execute(
        update(PresentationSession)
        .where(PresentationSession.id == session_id)
        .where(PresentationSession.voice_lease_token == token)
        .values(voice_lease_expires_at=now + timedelta(seconds=ttl_s))
    )
    await db.commit()
    return result.rowcount == 1


async def release_voice_lease(db: AsyncSession, *, session_id: str, token: str) -> bool:
    """Voluntary release (answer finished)."""
    result = await db.execute(
        update(PresentationSession)
        .where(PresentationSession.id == session_id)
        .where(PresentationSession.voice_lease_token == token)
        .values(voice_owner="none", voice_lease_token=None, voice_lease_expires_at=None)
    )
    await db.commit()
    return result.rowcount == 1


async def cancel_voice_lease(
    db: AsyncSession, *, session_id: str, cooldown_s: int = SPEECH_COOLDOWN_S
) -> bool:
    """Presenter interrupt: force-release regardless of holder, with a short
    cooldown so AI audio cannot instantly re-grab. Returns True when a lease
    existed and was cancelled."""
    now = datetime.now(timezone.utc)
    result = await db.execute(
        update(PresentationSession)
        .where(PresentationSession.id == session_id)
        .where(PresentationSession.voice_owner != "none")
        .values(
            voice_owner="none",
            voice_lease_token=None,
            voice_lease_expires_at=None,
            voice_next_allowed_at=now + timedelta(seconds=cooldown_s),
        )
    )
    await db.commit()
    return result.rowcount == 1


async def voice_lease_owner(db: AsyncSession, session_id: str) -> str:
    """Effective owner right now: 'none' when the lease has expired."""
    row = (await db.execute(
        text(
            "SELECT voice_owner, voice_lease_expires_at FROM presentation_sessions "
            "WHERE id = :sid"
        ),
        {"sid": session_id},
    )).first()
    if row is None:
        return "none"
    owner, expires_at = row.voice_owner, row.voice_lease_expires_at
    if owner == "none":
        return "none"
    if expires_at is not None:
        # Raw text() selects bypass ORM type coercion: aiosqlite hands the
        # stored value back as a string, so normalize before comparing.
        if isinstance(expires_at, str):
            try:
                expires_at = datetime.fromisoformat(expires_at.replace("Z", "+00:00"))
            except ValueError:
                expires_at = None
        if expires_at is not None:
            if expires_at.tzinfo is None:
                expires_at = expires_at.replace(tzinfo=timezone.utc)
            if expires_at < datetime.now(timezone.utc):
                return "none"
    return owner
