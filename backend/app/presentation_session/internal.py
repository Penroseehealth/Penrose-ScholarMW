"""Internal endpoints for the LiveKit agent worker (Phase 2).

The agent runs in a separate process and must never import FastAPI
application state (approved Phase 0D §6). It talks to the app over loopback
HTTP with the INTERNAL_TOKEN shared secret — constant-time compared here.

The token never reaches Flutter, browser JavaScript or attendee clients:
it lives only in backend configuration.
"""

from __future__ import annotations

import hmac
import os

from fastapi import APIRouter, Depends, Header, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.settings import get_settings
from app.database.engine import get_db
from app.presentation_session import primitives, service as sessions
from app.presentation_session.service import SessionError



# --- sync plumbing for the clone service (Phase 4) ---------------------------

_sync_engine = None


def _get_sync_engine():
    """Lazy shared sync engine for the clone service (dialect from settings)."""
    global _sync_engine
    if _sync_engine is None:
        from sqlalchemy import create_engine

        settings = get_settings()
        _sync_engine = create_engine(settings.DATABASE_URL_SYNC, pool_pre_ping=True)
    return _sync_engine


from sqlalchemy.orm import sessionmaker  # noqa: E402


# Command permission model (single source of truth for the data-channel
# relay; mirrored by the HTTP endpoints' own checks).
COMMAND_PRESENTER_ONLY = frozenset({"pause", "resume", "end", "goto_slide", "add_slide", "delete_slide", "reorder"})
COMMAND_BOTH_ROLES = frozenset({"interrupt", "takeover"})


router = APIRouter(prefix="/internal/presentation-sessions", tags=["Presentation Sessions — Internal", "internal"])


def require_internal_token(authorization: str = Header(default="")) -> None:
    """Bearer INTERNAL_TOKEN check with constant-time comparison."""
    expected = os.getenv("INTERNAL_TOKEN") or getattr(get_settings(), "INTERNAL_TOKEN", "")
    if not expected:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Internal API not configured")
    supplied = authorization.removeprefix("Bearer ").strip()
    if not supplied or not hmac.compare_digest(supplied, expected):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid internal token")


class AgentEventRequest(BaseModel):
    event_type: str
    event_key: str | None = None
    payload: dict | None = None
    persistence: str = "persistent"


class VoiceLeaseRequest(BaseModel):
    action: str  # acquire | renew | release | cancel
    owner: str | None = None
    token: str | None = None


class CloneTtsRequest(BaseModel):
    session_id: str
    text: str


@router.get("/{session_id}/context", dependencies=[Depends(require_internal_token)])
async def agent_context(session_id: str, db: AsyncSession = Depends(get_db)):
    """Session snapshot for the agent: deck slides, corrections, policy and
    transcript tail — the agent's lesson context."""
    try:
        view = await sessions.session_view(db, session_id)
    except SessionError as e:
        raise HTTPException(status_code=e.status_code, detail=e.detail)

    from sqlalchemy import select
    from app.models.presentation import (
        PresentationInstruction, PresentationSlide, PresentationTranscriptEvent,
    )

    session_row = await sessions.get_session_or_404(db, session_id)
    slides = (await db.execute(
        select(PresentationSlide)
        .where(PresentationSlide.presentation_id == session_row.presentation_id)
        .order_by(PresentationSlide.position)
    )).scalars().all()
    corrections = (await db.execute(
        select(PresentationInstruction)
        .where(PresentationInstruction.session_id == session_id)
        .order_by(PresentationInstruction.created_at)
    )).scalars().all()
    transcript_tail = (await db.execute(
        select(PresentationTranscriptEvent)
        .where(PresentationTranscriptEvent.session_id == session_id)
        .order_by(PresentationTranscriptEvent.created_at.desc())
        .limit(20)
    )).scalars().all()

    return {
        "session": {k: view[k] for k in ("session_id", "pres_state", "ai_state", "ai_policy", "voice_owner")},
        "slides": [
            {"id": s.slide_id, "position": s.position, "title": s.title,
             "bullets": s.bullets_json, "body": s.body, "speaker_notes": s.speaker_notes,
             "learning_objective": s.learning_objective}
            for s in slides
        ],
        "corrections": [{"kind": c.kind, "text": c.text, "target_slide_id": c.target_slide_id} for c in corrections],
        "transcript_tail": [{"speaker": t.speaker_label, "text": t.text} for t in reversed(transcript_tail)],
    }


@router.post("/{session_id}/events", dependencies=[Depends(require_internal_token)])
async def agent_event(session_id: str, body: AgentEventRequest, db: AsyncSession = Depends(get_db)):
    """Agent-originated events (transcript, ai_response_started/ended,
    narration_fallback...). Sequence and idempotency handled by primitives."""
    try:
        await sessions.get_session_or_404(db, session_id)
    except SessionError as e:
        raise HTTPException(status_code=e.status_code, detail=e.detail)
    result = await primitives.record_event(
        db, session_id=session_id, event_type=body.event_type,
        event_key=body.event_key, payload=body.payload,
        actor_role="system", persistence=body.persistence,
    )
    return result


@router.post("/{session_id}/voice-lease", dependencies=[Depends(require_internal_token)])
async def voice_lease(session_id: str, body: VoiceLeaseRequest, db: AsyncSession = Depends(get_db)):
    try:
        await sessions.get_session_or_404(db, session_id)
    except SessionError as e:
        raise HTTPException(status_code=e.status_code, detail=e.detail)
    if body.action == "acquire":
        return await primitives.acquire_voice_lease(db, session_id=session_id, owner=body.owner or "agent")
    if body.action == "renew":
        if not body.token:
            raise HTTPException(status_code=422, detail="token required for renew")
        return {"renewed": await primitives.renew_voice_lease(db, session_id=session_id, token=body.token)}
    if body.action == "release":
        if not body.token:
            raise HTTPException(status_code=422, detail="token required for release")
        return {"released": await primitives.release_voice_lease(db, session_id=session_id, token=body.token)}
    if body.action == "cancel":
        return {"cancelled": await primitives.cancel_voice_lease(db, session_id=session_id)}
    raise HTTPException(status_code=422, detail="action must be acquire|renew|release|cancel")


# ---------------------------------------------------------------------------
# Data-channel command relay (Phase 3)
#
# LiveKit data-channel messages arrive from clients, so they can never be
# trusted on their own. The worker forwards every command HERE with the
# sender's LiveKit identity; the role is re-resolved from the participant
# row and the action is executed by the same service functions the HTTP
# endpoints use. Unauthorized senders are rejected and audited.
# ---------------------------------------------------------------------------


class AgentCommandRequest(BaseModel):
    identity: str          # LiveKit identity of the sender (verified server-side)
    action: str            # pause | resume | interrupt | takeover | goto_slide | add_slide | delete_slide | reorder | end
    params: dict | None = None


class CloneTtsResponse(BaseModel):
    audio_base64: str | None = None
    mime: str = "audio/wav"
    provider: str = ""
    model: str = ""
    display_name: str = ""


async def _participant_by_identity(
    db: AsyncSession, session_id: str, identity: str
):
    """Resolve a LiveKit identity to the trusted participant row."""
    from sqlalchemy import select as _select

    from app.models.presentation import PresentationParticipant

    if identity.startswith("guest_"):
        try:
            pid = int(identity.removeprefix("guest_"))
        except ValueError:
            return None
        row = await db.get(PresentationParticipant, pid)
    elif identity.startswith("user_"):
        try:
            uid = int(identity.removeprefix("user_"))
        except ValueError:
            return None
        row = (await _db_execute_participant(db, session_id, uid)).first()
        row = row[0] if row else None
    else:
        return None
    if row is None or getattr(row, "session_id", None) != session_id or getattr(row, "left_at", None) is not None:
        return None
    return row


async def _db_execute_participant(db: AsyncSession, session_id: str, user_id: int):
    from sqlalchemy import select as _select

    from app.models.presentation import PresentationParticipant

    return await db.execute(
        _select(PresentationParticipant)
        .where(PresentationParticipant.session_id == session_id)
        .where(PresentationParticipant.user_id == user_id)
    )


@router.post("/{session_id}/command", dependencies=[Depends(require_internal_token)])
async def agent_command(session_id: str, body: AgentCommandRequest, db: AsyncSession = Depends(get_db)):
    """Execute a presenter/co-presenter command arriving from the LiveKit
    data channel. Roles are resolved server-side; unauthorized senders get a
    403 and a security_rejected audit event."""
    try:
        await sessions.get_session_or_404(db, session_id)
    except SessionError as e:
        raise HTTPException(status_code=e.status_code, detail=e.detail)

    participant = await _participant_by_identity(db, session_id, body.identity)
    if participant is None:
        await primitives.record_event(
            db, session_id=session_id, event_type="security_rejected",
            payload={"identity": body.identity, "action": body.action, "reason": "unknown_participant"},
            actor_role="system",
        )
        await db.commit()
        raise HTTPException(status_code=403, detail="Unknown or inactive participant")

    if body.action in COMMAND_BOTH_ROLES and participant.role not in ("presenter", "co_presenter"):
        allowed = False
    elif body.action in COMMAND_PRESENTER_ONLY and participant.role != "presenter":
        allowed = False
    else:
        allowed = body.action in COMMAND_BOTH_ROLES or body.action in COMMAND_PRESENTER_ONLY
    if not allowed:
        await primitives.record_event(
            db, session_id=session_id, event_type="security_rejected",
            payload={"identity": body.identity, "action": body.action, "role": participant.role},
            actor_role="system",
        )
        await db.commit()
        raise HTTPException(status_code=403, detail="Not permitted for your role")

    params = body.params or {}
    try:
        if body.action == "pause":
            s = await sessions.pause_session(db, session_id=session_id, user_id=participant.user_id or -1)
        elif body.action == "resume":
            s = await sessions.resume_session(db, session_id=session_id, user_id=participant.user_id or -1)
        elif body.action == "interrupt":
            return await sessions.interrupt_session(db, session_id=session_id, user_id=participant.user_id or -1)
        elif body.action == "takeover":
            return await sessions.takeover_session(db, session_id=session_id, user_id=participant.user_id or -1)
        elif body.action == "end":
            s = await sessions.complete_session(db, session_id=session_id, user_id=participant.user_id or -1)
        elif body.action in ("goto_slide", "add_slide", "delete_slide", "reorder"):
            from app.presentation_session import slides as slide_ops

            return await slide_ops.apply_command(db, session_id=session_id, action=body.action, params=params, participant=participant)
        else:
            raise HTTPException(status_code=422, detail=f"Unsupported action {body.action}")
    except SessionError as e:
        raise HTTPException(status_code=e.status_code, detail=e.detail)
    await db.commit()
    return {"pres_state": s.pres_state, "ai_state": s.ai_state, "action": body.action}


# ---------------------------------------------------------------------------
# Cloned-voice synthesis for the agent (Phase 4)
#
# The agent process must NOT import app state (approved 0D §6). It calls this
# endpoint; the endpoint calls the SAME VoiceCloneService the VTC uses, so
# there is exactly one clone implementation. Uses the session's default
# trained clone (the narration default resolved by clone_narration).
# ---------------------------------------------------------------------------


@router.post("/{session_id}/tts-clone", response_model=CloneTtsResponse, dependencies=[Depends(require_internal_token)])
async def agent_clone_tts(session_id: str, body: CloneTtsRequest, db: AsyncSession = Depends(get_db)):
    try:
        await sessions.get_session_or_404(db, session_id)
    except SessionError as e:
        raise HTTPException(status_code=e.status_code, detail=e.detail)

    # VoiceCloneService and its repositories are synchronous (they run behind
    # the VTC's threadpool endpoints). Open an independent sync session here —
    # reusing the async one would deadlock — and run the synthesis in a worker
    # thread exactly like the existing speech endpoints do.
    import base64

    from starlette.concurrency import run_in_threadpool

    from sqlalchemy.orm import sessionmaker
    from sqlalchemy import create_engine as _create_engine

    from app.config.settings import get_settings as _gs
    from app.speech.clone_service import VoiceCloneService
    from app.speech.repository import VoiceModelRepository

    engine = _get_sync_engine()

    maker = sessionmaker(bind=engine)

    def _synthesize() -> tuple[int, dict] | None:
        sync_db = maker()
        try:
            repo = VoiceModelRepository(sync_db)
            service = VoiceCloneService(repo)
            clone = service.resolve_default()
            if clone is None:
                return None
            return clone.id, service.synthesize(clone.id, body.text)
        finally:
            sync_db.close()

    try:
        outcome = await run_in_threadpool(_synthesize)
    except Exception as e:  # noqa: BLE001 — any provider failure → disclosed fallback
        raise HTTPException(status_code=503, detail=f"clone unavailable: {e}")

    if outcome is None:
        raise HTTPException(status_code=503, detail="No ready trained clone is available")
    voice_id, envelope = outcome
    audio_b64 = envelope.get("audio_base64") or ""
    if not audio_b64:
        raise HTTPException(status_code=503, detail="clone produced no audio")
    return CloneTtsResponse(
        audio_base64=audio_b64,
        mime=envelope.get("mime", "audio/wav"),
        provider=envelope.get("provider", "openvoice"),
        model=envelope.get("model", ""),
        display_name=envelope.get("display_name", ""),
    )
