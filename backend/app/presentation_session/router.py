"""HTTP surface for presentation sessions (Phase 2).

Public endpoints under ``/api/v1/presentation-sessions`` authenticate with the
existing user JWT chain. Internal endpoints (separate module) use the
INTERNAL_TOKEN shared secret and are never exposed to Flutter/browser
clients.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user, require_lecturer
from app.models.models import User
from app.presentation_session import service as sessions
from app.presentation_session.service import SessionError

router = APIRouter(prefix="/presentation-sessions", tags=["Presentation Sessions"])


def _http(e: SessionError) -> HTTPException:
    return HTTPException(status_code=e.status_code, detail=e.detail)


# -- schemas (kept here: they are HTTP-only concerns) -----------------------


class SessionCreateRequest(BaseModel):
    presentation_id: str
    ai_policy: str = Field(default="approval", pattern="^(auto|approval|presenter_only)$")


class JoinRequest(BaseModel):
    session_id: str | None = None
    join_code: str | None = None
    display_name: str = Field(default="", max_length=128)


class QuestionRequest(BaseModel):
    participant_id: int
    text: str = Field(min_length=1, max_length=2000)
    source: str = Field(default="text", pattern="^(text|voice)$")
    audio_recording_id: str | None = None
    idempotency_key: str | None = Field(default=None, max_length=64)


class ModerationRequest(BaseModel):
    decision: str = Field(pattern="^(approve|defer|reject|answer)$")
    answer_text: str | None = Field(default=None, max_length=4000)


class PolicyRequest(BaseModel):
    ai_policy: str = Field(pattern="^(auto|approval|presenter_only)$")


class InstructionRequest(BaseModel):
    text: str = Field(min_length=1, max_length=2000)
    kind: str = Field(default="correction", pattern="^(correction|steer|stop_topic)$")
    target_slide_id: str | None = None


class ParticipantRemoveRequest(BaseModel):
    participant_id: int


# -- session lifecycle -------------------------------------------------------


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_session(body: SessionCreateRequest, user: User = Depends(require_lecturer), db: AsyncSession = Depends(get_db)):
    try:
        return await sessions.create_session(db, presenter=user, presentation_id=body.presentation_id, ai_policy=body.ai_policy)
    except SessionError as e:
        raise _http(e)


@router.get("/{session_id}")
async def get_session(session_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    try:
        view = await sessions.session_view(db, session_id)
    except SessionError as e:
        raise _http(e)
    # Guests cannot read the roster with tokens; named users must belong.
    # (Minimal check: any authenticated user may read state; membership
    # enforcement for actions is per-endpoint. Roster trimming for non-members
    # comes with the guest UI in Phase 5.)
    return view


@router.post("/{session_id}/start")
async def start(session_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    try:
        session = await sessions.start_session(db, session_id=session_id, user_id=user.id)
        await db.commit()
        return {"pres_state": session.pres_state, "ai_state": session.ai_state}
    except SessionError as e:
        raise _http(e)


@router.post("/{session_id}/pause")
async def pause(session_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    try:
        session = await sessions.pause_session(db, session_id=session_id, user_id=user.id)
        await db.commit()
        return {"pres_state": session.pres_state, "ai_state": session.ai_state}
    except SessionError as e:
        raise _http(e)


@router.post("/{session_id}/resume")
async def resume(session_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    try:
        session = await sessions.resume_session(db, session_id=session_id, user_id=user.id)
        await db.commit()
        return {"pres_state": session.pres_state, "ai_state": session.ai_state}
    except SessionError as e:
        raise _http(e)


@router.post("/{session_id}/end")
async def end(session_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    try:
        session = await sessions.complete_session(db, session_id=session_id, user_id=user.id)
        await db.commit()
        return {"pres_state": session.pres_state, "end_reason": session.end_reason}
    except SessionError as e:
        raise _http(e)


@router.post("/{session_id}/interrupt")
async def interrupt(session_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    try:
        return await sessions.interrupt_session(db, session_id=session_id, user_id=user.id)
    except SessionError as e:
        raise _http(e)


@router.post("/{session_id}/takeover")
async def takeover(session_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    try:
        return await sessions.takeover_session(db, session_id=session_id, user_id=user.id)
    except SessionError as e:
        raise _http(e)


# -- participation -----------------------------------------------------------


@router.post("/join")
async def join(body: JoinRequest, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Named-user join. Guest join (no account) uses the /join-guest route."""
    try:
        return await sessions.join_session(db, session_id=body.session_id, join_code=body.join_code, user=user, display_name=body.display_name)
    except SessionError as e:
        raise _http(e)


@router.post("/join-guest")
async def join_guest(body: JoinRequest, db: AsyncSession = Depends(get_db)):
    """Anonymous join with a join code and display name — no account."""
    try:
        return await sessions.join_session(db, session_id=body.session_id, join_code=body.join_code, user=None, display_name=body.display_name)
    except SessionError as e:
        raise _http(e)


@router.post("/{session_id}/participants/remove")
async def remove_participant(session_id: str, body: ParticipantRemoveRequest, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    try:
        removed = await sessions.remove_participant(db, session_id=session_id, participant_id=body.participant_id, user_id=user.id)
        return {"removed": removed}
    except SessionError as e:
        raise _http(e)


@router.post("/{session_id}/heartbeat")
async def heartbeat(session_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    try:
        return await sessions.heartbeat(db, session_id=session_id, user_id=user.id)
    except SessionError as e:
        raise _http(e)


# -- questions + moderation --------------------------------------------------


@router.post("/{session_id}/questions", status_code=status.HTTP_201_CREATED)
async def raise_question(session_id: str, body: QuestionRequest, db: AsyncSession = Depends(get_db)):
    """Attendee question submission (guests included — participant_id is the
    registration handle; the service checks active membership)."""
    try:
        return await sessions.raise_question(
            db, session_id=session_id, participant_id=body.participant_id,
            text_q=body.text, source=body.source,
            audio_recording_id=body.audio_recording_id,
            idempotency_key=body.idempotency_key,
        )
    except SessionError as e:
        raise _http(e)


@router.post("/{session_id}/questions/{question_id}/moderate")
async def moderate(session_id: str, question_id: int, body: ModerationRequest, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    try:
        return await sessions.moderate_question(
            db, session_id=session_id, question_id=question_id,
            decision=body.decision, user_id=user.id, answer_text=body.answer_text,
        )
    except SessionError as e:
        raise _http(e)


# -- live slide operations (presenter/co-presenter via HTTP surface) ---------


class SlideCommandRequest(BaseModel):
    action: str = Field(pattern="^(goto_slide|add_slide|delete_slide|reorder)$")
    params: dict = Field(default_factory=dict)


@router.post("/{session_id}/command")
async def slide_command(session_id: str, body: SlideCommandRequest, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Live slide commands from the presenter cockpit (Phase 5). Roles are
    resolved from the participant row — attendees get 403."""
    from app.models.presentation import PresentationParticipant
    from sqlalchemy import select as _select
    from app.presentation_session import slides as slide_ops

    try:
        session_row = await sessions.get_session_or_404(db, session_id)
    except SessionError as e:
        raise _http(e)
    participant = (await db.execute(
        _select(PresentationParticipant)
        .where(PresentationParticipant.session_id == session_id)
        .where(PresentationParticipant.user_id == user.id)
    )).scalar_one_or_none()
    if participant is None:
        raise _http(SessionError(403, "Not an active participant of this session"))
    try:
        return await slide_ops.apply_command(
            db, session_id=session_id, action=body.action,
            params=body.params, participant=participant,
        )
    except SessionError as e:
        raise _http(e)


# -- policy, instructions, events ---------------------------------------------


@router.patch("/{session_id}/ai-policy")
async def set_policy(session_id: str, body: PolicyRequest, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    try:
        session = await sessions.set_ai_policy(db, session_id=session_id, policy=body.ai_policy, user_id=user.id)
        return {"ai_policy": session.ai_policy}
    except SessionError as e:
        raise _http(e)


@router.post("/{session_id}/instructions", status_code=status.HTTP_201_CREATED)
async def add_instruction(session_id: str, body: InstructionRequest, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    try:
        return await sessions.add_instruction(
            db, session_id=session_id, user_id=user.id,
            text_i=body.text, kind=body.kind, target_slide_id=body.target_slide_id,
        )
    except SessionError as e:
        raise _http(e)


# -- Phase 6: recording consent + artifacts -----------------------------------


class ConsentDecisionRequest(BaseModel):
    decision: str = Field(pattern="^(granted|denied|withdrawn)$")
    scope: str = Field(default="session_audio", pattern="^(session_audio|own_voice)$")


class ConsentStartRequest(BaseModel):
    participant_id: int
    decision: str = Field(pattern="^(granted|denied|withdrawn)$")
    scope: str = Field(default="session_audio", pattern="^(session_audio|own_voice)$")


@router.post("/{session_id}/recording-consents", status_code=201)
async def record_consent(session_id: str, body: ConsentStartRequest, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Append a consent decision (granted/denied/withdrawn) for a participant.
    Withdrawal inserts a NEW row — history is never overwritten."""
    from datetime import datetime, timezone

    from app.models.presentation import (
        PresentationParticipant, PresentationRecordingConsent,
    )

    try:
        await sessions.get_session_or_404(db, session_id)
    except SessionError as e:
        raise _http(e)
    participant = await db.get(PresentationParticipant, body.participant_id)
    if participant is None or participant.session_id != session_id:
        raise _http(SessionError(404, "Participant not found in this session"))
    latest = (await db.execute(
        select(PresentationRecordingConsent)
        .where(PresentationRecordingConsent.session_id == session_id)
        .where(PresentationRecordingConsent.participant_id == body.participant_id)
        .order_by(PresentationRecordingConsent.id.desc())
    )).scalars().first()
    row = PresentationRecordingConsent(
        session_id=session_id,
        participant_id=body.participant_id,
        decision=body.decision,
        scope=body.scope,
        granted_at=datetime.now(timezone.utc) if body.decision == "granted" else None,
        withdrawn_at=datetime.now(timezone.utc) if body.decision == "withdrawn" else None,
        prev_record_id=latest.id if latest else None,
        recorded_by_endpoint="/presentation-sessions/recording-consents",
    )
    db.add(row)
    await db.commit()
    return {"consent_id": row.id, "decision": row.decision}


@router.get("/{session_id}/recording-consents")
async def consent_ledger(session_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    from app.models.presentation import PresentationRecordingConsent

    try:
        await sessions.get_session_or_404(db, session_id)
    except SessionError as e:
        raise _http(e)
    rows = (await db.execute(
        select(PresentationRecordingConsent)
        .where(PresentationRecordingConsent.session_id == session_id)
        .order_by(PresentationRecordingConsent.id)
    )).scalars().all()
    return {"consents": [
        {"id": r.id, "participant_id": r.participant_id, "decision": r.decision,
         "scope": r.scope, "granted_at": r.granted_at.isoformat() if r.granted_at else None,
         "withdrawn_at": r.withdrawn_at.isoformat() if r.withdrawn_at else None,
         "prev_record_id": r.prev_record_id}
        for r in rows
    ]}


@router.get("/{session_id}/artifacts")
async def session_artifacts(session_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Post-session artifacts: transcript + unanswered/answered questions."""
    from app.presentation_session import artifacts as art

    try:
        return await art.artifacts(db, session_id)
    except SessionError as e:
        raise _http(e)


@router.post("/{session_id}/artifacts/summary")
async def session_summary(session_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    from app.presentation_session import artifacts as art

    try:
        return {"summary": await art.summary(db, session_id)}
    except SessionError as e:
        raise _http(e)


@router.post("/{session_id}/artifacts/quiz")
async def session_quiz(session_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    from app.presentation_session import artifacts as art

    try:
        return {"quiz": await art.quiz(db, session_id)}
    except SessionError as e:
        raise _http(e)


@router.get("/{session_id}/events")
async def replay_events(session_id: str, after_seq: int = 0, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Persistent-event replay for reconnecting clients (approved 0D §4:
    ephemeral events are never replayed)."""
    try:
        await sessions.get_session_or_404(db, session_id)
    except SessionError as e:
        raise _http(e)
    from app.presentation_session import primitives

    events = await primitives.replay_events(db, session_id=session_id, after_seq=after_seq)
    return {"events": events, "after_seq": after_seq}
