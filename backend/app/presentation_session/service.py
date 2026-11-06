"""Presentation-session service: lifecycle, participants, moderation, policy.

Phase 2 of the authorized implementation. All state lives in the database
(cross-process authority — the LiveKit agent worker reads the same rows).
Every state change is validated by ``state_machine`` and recorded as a
persistent event in the same transaction.
"""

from __future__ import annotations

import hashlib
import hmac
import secrets
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select, text, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.presentation import (
    PARTICIPANT_ROLES,
    END_REASONS,
    Presentation,
    PresentationInstruction,
    PresentationParticipant,
    PresentationQuestion,
    PresentationSession,
)
from app.presentation_session import primitives, state_machine as sm
from app.presentation_session.state_machine import (
    AI_IDLE,
    AI_LISTENING,
    AI_RESPONDING,
    AI_SUSPENDED,
    PRES_COMPLETED,
    PRES_IDLE,
    PRES_LIVE,
    PRES_PAUSED,
)

# ---------------------------------------------------------------------------
# Rate limits (per-session, DB-bounded; approved Phase 0D §4)
# ---------------------------------------------------------------------------

MAX_PENDING_QUESTIONS_PER_PARTICIPANT = 3
QUESTION_MIN_INTERVAL_S = 10


def _hash_code(code: str) -> str:
    return hashlib.sha256(code.encode("utf-8")).hexdigest()


def _now() -> datetime:
    return datetime.now(timezone.utc)


class SessionError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        super().__init__(detail)
        self.status_code = status_code
        self.detail = detail


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------


async def create_session(
    db: AsyncSession,
    *,
    presenter: "object",
    presentation_id: str,
    ai_policy: str = "approval",
) -> dict:
    """Create a session for an owned presentation. Generates the room name and
    the guest join code server-side."""
    if ai_policy not in sm.AI_POLICIES:
        raise SessionError(422, f"ai_policy must be one of {sm.AI_POLICIES}")

    deck = await db.get(Presentation, presentation_id)
    if deck is None:
        raise SessionError(404, "Presentation not found")
    if deck.owner_id != presenter.id:
        raise SessionError(403, "Only the presentation owner can start a session")

    active = (await db.execute(
        text(
            "SELECT id FROM presentation_sessions "
            "WHERE presentation_id = :pid AND pres_state != 'completed'"
        ),
        {"pid": presentation_id},
    )).first()
    if active is not None:
        raise SessionError(409, "This presentation already has an active session")

    join_code = uuid.uuid4().hex[:8].upper()
    session = PresentationSession(
        id=uuid.uuid4().hex,
        presentation_id=presentation_id,
        presenter_id=presenter.id,
        room_name=f"pres_{uuid.uuid4().hex[:10]}",
        join_code_hash=_hash_code(join_code),
        pres_state=PRES_IDLE,
        ai_state=AI_IDLE,
        ai_policy=ai_policy,
    )
    db.add(session)
    presenter_row = PresentationParticipant(
        session_id=session.id,
        user_id=presenter.id,
        display_name=getattr(presenter, "full_name", "") or "Presenter",
        role="presenter",
    )
    db.add(presenter_row)
    await db.flush()
    await primitives.record_event(
        db, session_id=session.id, event_type="session_created",
        payload={"presentation_id": presentation_id, "policy": ai_policy},
        actor_role="presenter", actor_user_id=presenter.id,
    )
    await db.commit()
    return {"session_id": session.id, "room_name": session.room_name, "join_code": join_code, "pres_state": session.pres_state, "ai_state": session.ai_state, "ai_policy": session.ai_policy}


async def get_session_or_404(db: AsyncSession, session_id: str) -> PresentationSession:
    session = await db.get(PresentationSession, session_id)
    if session is None:
        raise SessionError(404, "Session not found")
    return session


async def _participant_of(db: AsyncSession, session_id: str, user_id: int) -> PresentationParticipant | None:
    return (await db.execute(
        select(PresentationParticipant)
        .where(PresentationParticipant.session_id == session_id)
        .where(PresentationParticipant.user_id == user_id)
    )).scalar_one_or_none()


def _require_role(session: PresentationSession, participant: PresentationParticipant | None, allowed: tuple[str, ...]) -> PresentationParticipant:
    if participant is None or participant.role not in allowed:
        raise SessionError(403, "Not permitted for your role in this session")
    return participant


async def _set_state(
    db: AsyncSession,
    session: PresentationSession,
    *,
    pres: str | None = None,
    ai: str | None = None,
    event_type: str,
    actor_role: str = "system",
    actor_user_id: int | None = None,
    payload: dict | None = None,
) -> PresentationSession:
    """Validate the dual state change, apply it, and record one persistent
    event — all inside the caller's transaction."""
    new_pres = pres if pres is not None else session.pres_state
    new_ai = ai if ai is not None else session.ai_state
    if new_pres != session.pres_state:
        check = sm.check_pres_transition(session.pres_state, new_pres)
        if not check.allowed:
            raise SessionError(409, check.reason)
    if new_ai != session.ai_state:
        check = sm.check_ai_transition(session.ai_state, new_ai)
        if not check.allowed:
            raise SessionError(409, check.reason)
    check = sm.check_combination(new_pres, new_ai)
    if not check.allowed:
        raise SessionError(409, check.reason)

    await primitives.record_event(
        db, session_id=session.id, event_type=event_type,
        payload=payload or {"pres_state": new_pres, "ai_state": new_ai},
        actor_role=actor_role, actor_user_id=actor_user_id,
    )
    session.pres_state = new_pres
    session.ai_state = new_ai
    return session


async def start_session(db: AsyncSession, *, session_id: str, user_id: int) -> PresentationSession:
    session = await get_session_or_404(db, session_id)
    participant = await _participant_of(db, session_id, user_id)
    _require_role(session, participant, ("presenter",))
    if session.pres_state != PRES_IDLE:
        raise SessionError(409, f"Session is already {session.pres_state}")
    session.started_at = _now()
    session.presenter_heartbeat_at = _now()
    return await _set_state(db, session, pres=PRES_LIVE, event_type="session_started", actor_role="presenter", actor_user_id=user_id)


async def pause_session(db: AsyncSession, *, session_id: str, user_id: int) -> PresentationSession:
    session = await get_session_or_404(db, session_id)
    participant = await _participant_of(db, session_id, user_id)
    _require_role(session, participant, ("presenter",))
    return await _set_state(db, session, pres=PRES_PAUSED, event_type="presentation_paused", actor_role="presenter", actor_user_id=user_id)


async def resume_session(db: AsyncSession, *, session_id: str, user_id: int) -> PresentationSession:
    session = await get_session_or_404(db, session_id)
    participant = await _participant_of(db, session_id, user_id)
    _require_role(session, participant, ("presenter",))
    return await _set_state(db, session, pres=PRES_LIVE, event_type="presentation_resumed", actor_role="presenter", actor_user_id=user_id)


async def complete_session(
    db: AsyncSession, *, session_id: str, user_id: int, reason: str = "presenter"
) -> PresentationSession:
    session = await get_session_or_404(db, session_id)
    if reason in ("timeout", "presenter_absent"):
        # System-initiated completion (recovery path) — no role check.
        pass
    else:
        participant = await _participant_of(db, session_id, user_id)
        _require_role(session, participant, ("presenter",))
    if reason not in END_REASONS:
        raise SessionError(422, f"end_reason must be one of {END_REASONS}")
    session.ended_at = _now()
    session.end_reason = reason
    return await _set_state(db, session, pres=PRES_COMPLETED, ai=AI_IDLE, event_type="session_completed", actor_role="presenter" if reason == "presenter" else "system", payload={"end_reason": reason})


# ---------------------------------------------------------------------------
# Interrupt / takeover
# ---------------------------------------------------------------------------


async def interrupt_session(
    db: AsyncSession, *, session_id: str, user_id: int, actor_role_hint: str | None = None
) -> dict:
    """Presenter/co-presenter emergency stop.

    Cancels the voice lease (with cooldown), moves AI to idle, and emits the
    persistent command event the agent/client react to by stopping playback
    and frame publication. The flag change is NOT treated as audio
    cancellation — the consumer's acknowledgement is a separate event.
    """
    session = await get_session_or_404(db, session_id)
    participant = await _participant_of(db, session_id, user_id)
    _require_role(session, participant, ("presenter", "co_presenter"))
    lease_existed = await primitives.cancel_voice_lease(db, session_id=session_id)
    new_ai = AI_IDLE if session.ai_state in (AI_RESPONDING, AI_LISTENING) else None
    session2 = await _set_state(
        db, session, ai=new_ai, event_type="presentation_interrupted",
        actor_role=participant.role, actor_user_id=user_id,
        payload={"lease_cancelled": lease_existed},
    )
    await db.commit()
    return {"pres_state": session2.pres_state, "ai_state": session2.ai_state, "lease_cancelled": lease_existed}


async def takeover_session(db: AsyncSession, *, session_id: str, user_id: int) -> dict:
    """Force-return to presenter control: same as interrupt but also drops any
    awaiting AI work. Co-presenter allowed."""
    session = await get_session_or_404(db, session_id)
    participant = await _participant_of(db, session_id, user_id)
    _require_role(session, participant, ("presenter", "co_presenter"))
    await primitives.cancel_voice_lease(db, session_id=session_id)
    session2 = await _set_state(db, session, ai=AI_IDLE, event_type="presenter_takeover", actor_role=participant.role, actor_user_id=user_id)
    await db.commit()
    return {"pres_state": session2.pres_state, "ai_state": session2.ai_state}


# ---------------------------------------------------------------------------
# Participants
# ---------------------------------------------------------------------------


async def join_session(
    db: AsyncSession,
    *,
    session_id: str | None,
    join_code: str | None,
    user: "object | None",
    display_name: str,
) -> dict:
    """Register a participant and assign the role SERVER-SIDE.

    Named users get presenter only when they own the presentation; guests
    (no user) must present the session's join code. The role is never read
    from any client-supplied field.
    """
    if session_id:
        session = await get_session_or_404(db, session_id)
    elif join_code:
        hashed = _hash_code(join_code)
        session = (await db.execute(
            select(PresentationSession).where(PresentationSession.join_code_hash == hashed)
        )).scalar_one_or_none()
        if session is None:
            raise SessionError(404, "Invalid join code")
    else:
        raise SessionError(422, "Provide session_id or join_code")

    if session.pres_state == PRES_COMPLETED:
        raise SessionError(409, "This session has ended")

    participant = None
    if user is not None:
        participant = await _participant_of(db, session.id, user.id)
        if participant is None:
            role = "presenter" if user.id == session.presenter_id else "attendee"
            participant = PresentationParticipant(
                session_id=session.id, user_id=user.id,
                display_name=display_name or getattr(user, "full_name", "") or "Participant",
                role=role,
            )
            db.add(participant)
            await db.flush()
        else:
            participant.left_at = None  # reconnection
            participant.reconnected_count += 1
    else:
        # Guest: anonymous display-name registration (approved decision).
        if session.join_code_hash and join_code and _hash_code(join_code) != session.join_code_hash:
            raise SessionError(403, "Invalid join code")
        participant = PresentationParticipant(
            session_id=session.id, user_id=None,
            display_name=(display_name or "").strip()[:128] or "Guest",
            role="attendee",
        )
        db.add(participant)
        await db.flush()
        guest_token = secrets.token_urlsafe(24)
        participant.guest_token_hash = _hash_code(guest_token)
        await db.commit()
        return {
            "session_id": session.id, "participant_id": participant.id,
            "role": participant.role, "room_name": session.room_name,
            "guest_token": guest_token, "pres_state": session.pres_state,
            "ai_state": session.ai_state,
        }

    await primitives.record_event(
        db, session_id=session.id, event_type="participant_joined",
        payload={"participant_id": participant.id, "role": participant.role},
        actor_role=participant.role, actor_user_id=user.id if user else None,
    )
    await db.commit()
    return {
        "session_id": session.id, "participant_id": participant.id,
        "role": participant.role, "room_name": session.room_name,
        "pres_state": session.pres_state, "ai_state": session.ai_state,
    }


async def remove_participant(
    db: AsyncSession, *, session_id: str, participant_id: int, user_id: int
) -> bool:
    session = await get_session_or_404(db, session_id)
    participant = await _participant_of(db, session_id, user_id)
    _require_role(session, participant, ("presenter",))
    row = await db.get(PresentationParticipant, participant_id)
    if row is None or row.session_id != session_id:
        raise SessionError(404, "Participant not found")
    if row.role == "presenter":
        raise SessionError(409, "The presenter cannot be removed")
    row.left_at = _now()
    await primitives.record_event(
        db, session_id=session_id, event_type="participant_removed",
        payload={"participant_id": participant_id},
        actor_role="presenter", actor_user_id=user_id,
    )
    await db.commit()
    return True


# ---------------------------------------------------------------------------
# Questions + moderation
# ---------------------------------------------------------------------------


async def raise_question(
    db: AsyncSession, *, session_id: str, participant_id: int, text_q: str,
    source: str = "text", audio_recording_id: str | None = None,
    idempotency_key: str | None = None,
) -> dict:
    """Attendee question submission with duplicate prevention."""
    session = await get_session_or_404(db, session_id)
    participant = await db.get(PresentationParticipant, participant_id)
    if participant is None or participant.session_id != session_id or participant.left_at is not None:
        raise SessionError(403, "Not an active participant of this session")

    key = idempotency_key or hashlib.sha256(text_q.strip().lower().encode()).hexdigest()[:32]
    dup = (await db.execute(
        select(PresentationQuestion).where(
            PresentationQuestion.session_id == session_id,
            PresentationQuestion.participant_id == participant_id,
            PresentationQuestion.idempotency_key == key,
        )
    )).scalar_one_or_none()
    if dup is not None:
        raise SessionError(429, "The same question is already pending or answered")

    # Rate limit: max pending + min interval.
    pending = (await db.execute(
        select(PresentationQuestion).where(
            PresentationQuestion.session_id == session_id,
            PresentationQuestion.participant_id == participant_id,
            PresentationQuestion.status.in_(("raised", "approved")),
        )
    )).scalars().all()
    if len(pending) >= MAX_PENDING_QUESTIONS_PER_PARTICIPANT:
        raise SessionError(429, f"Too many pending questions (max {MAX_PENDING_QUESTIONS_PER_PARTICIPANT})")
    if pending and (_now() - (pending[-1].created_at or _now())).total_seconds() < QUESTION_MIN_INTERVAL_S:
        raise SessionError(429, f"Please wait {QUESTION_MIN_INTERVAL_S}s between questions")

    question = PresentationQuestion(
        session_id=session_id, participant_id=participant_id,
        source=source, text=text_q.strip(), audio_recording_id=audio_recording_id,
        status="raised", idempotency_key=key,
    )
    db.add(question)
    await db.flush()

    # Policy decides the AI path (approved Phase 0D §4 policy paths) — but
    # only while the presentation is live or paused: an idle/completed
    # presentation can never host a responding AI (combination matrix).
    ai_gate_ok = session.pres_state in (PRES_LIVE, PRES_PAUSED)
    if session.ai_policy == "auto" and ai_gate_ok and sm.policy_allows_ai_any_answer(session.ai_policy):
        question.status = "approved"
        new_ai = AI_RESPONDING if session.ai_state in (AI_IDLE, AI_LISTENING) else session.ai_state
        session2 = await _set_state(
            db, session, ai=new_ai, event_type="question_raised",
            payload={"question_id": question.id, "auto": True},
            actor_role=participant.role, actor_user_id=participant.user_id,
        )
        session = session2
    elif session.ai_policy == "approval" and ai_gate_ok:
        new_ai = AI_AWAITING if session.ai_state == AI_LISTENING else session.ai_state
        session = await _set_state(
            db, session, ai=new_ai, event_type="question_raised",
            payload={"question_id": question.id, "awaiting": True},
            actor_role=participant.role, actor_user_id=participant.user_id,
        )
    else:  # presenter_only — AI never answers; question waits for the presenter
        session = await _set_state(
            db, session, event_type="question_raised",
            payload={"question_id": question.id},
            actor_role=participant.role, actor_user_id=participant.user_id,
        )
    await db.commit()
    return {"question_id": question.id, "status": question.status, "pres_state": session.pres_state, "ai_state": session.ai_state}


async def moderate_question(
    db: AsyncSession, *, session_id: str, question_id: int, decision: str,
    user_id: int, answer_text: str | None = None,
) -> dict:
    """Approve / defer / reject / manual answer. Presenter only; every
    decision is recorded with decided_by/decided_at for the audit trail."""
    session = await get_session_or_404(db, session_id)
    participant = await _participant_of(db, session_id, user_id)
    _require_role(session, participant, ("presenter",))
    question = await db.get(PresentationQuestion, question_id)
    if question is None or question.session_id != session_id:
        raise SessionError(404, "Question not found")

    if decision not in ("approve", "defer", "reject", "answer"):
        raise SessionError(422, "decision must be approve|defer|reject|answer")

    status_map = {"approve": "approved", "defer": "deferred", "reject": "rejected", "answer": "answered"}
    question.status = status_map[decision]
    question.decided_by = user_id
    question.decided_at = _now()
    if decision == "answer" and answer_text:
        question.answer_text = answer_text

    # Approved question with AI allowed → RESPONDING; otherwise AI falls back
    # to listening/idle when the queue empties.
    new_ai = None
    if (
        decision == "approve"
        and session.pres_state in (PRES_LIVE, PRES_PAUSED)
        and sm.policy_allows_ai_any_answer(session.ai_policy)
    ):
        new_ai = AI_RESPONDING
    elif decision in ("defer", "reject", "answer"):
        remaining = (await db.execute(
            select(PresentationQuestion).where(
                PresentationQuestion.session_id == session_id,
                PresentationQuestion.status == "raised",
            )
        )).scalars().all()
        if not remaining and session.ai_state == "awaiting_approval":
            new_ai = AI_LISTENING
    session2 = await _set_state(
        db, session, ai=new_ai, event_type=f"question_{decision}",
        payload={"question_id": question_id}, actor_role="presenter", actor_user_id=user_id,
    )
    await db.commit()
    return {"question_id": question_id, "status": question.status, "ai_state": session2.ai_state}


# ---------------------------------------------------------------------------
# Policy + instructions + heartbeat
# ---------------------------------------------------------------------------


async def set_ai_policy(
    db: AsyncSession, *, session_id: str, policy: str, user_id: int
) -> PresentationSession:
    """Presenter-only. Co-presenters cannot change restricted policy."""
    session = await get_session_or_404(db, session_id)
    participant = await _participant_of(db, session_id, user_id)
    _require_role(session, participant, ("presenter",))  # co-presenter excluded by design
    if policy not in sm.AI_POLICIES:
        raise SessionError(422, f"ai_policy must be one of {sm.AI_POLICIES}")
    session.ai_policy = policy
    await primitives.record_event(
        db, session_id=session_id, event_type="ai_policy_changed",
        payload={"policy": policy}, actor_role="presenter", actor_user_id=user_id,
    )
    await db.commit()
    return session


async def add_instruction(
    db: AsyncSession, *, session_id: str, user_id: int, text_i: str,
    kind: str = "correction", target_slide_id: str | None = None,
) -> dict:
    """Presenter correction/steer. Appended to the ledger and returned so the
    caller can inject it into the AI context (context_engine, Phase 4)."""
    session = await get_session_or_404(db, session_id)
    participant = await _participant_of(db, session_id, user_id)
    _require_role(session, participant, ("presenter", "co_presenter"))
    if kind not in ("correction", "steer", "stop_topic"):
        raise SessionError(422, "kind must be correction|steer|stop_topic")
    instruction = PresentationInstruction(
        session_id=session_id, presenter_id=user_id, kind=kind,
        target_slide_id=target_slide_id, text=text_i.strip(),
        applied_to_context=False,
    )
    db.add(instruction)
    await db.flush()
    await primitives.record_event(
        db, session_id=session_id, event_type="correction_applied",
        payload={"instruction_id": instruction.id, "kind": kind},
        actor_role=participant.role, actor_user_id=user_id,
    )
    await db.commit()
    return {"instruction_id": instruction.id, "kind": kind}


async def heartbeat(db: AsyncSession, *, session_id: str, user_id: int) -> dict:
    """Participant heartbeat. Presenter heartbeats arm recovery; a presenter
    gap longer than grace_period_s pauses playback instead of ending."""
    session = await get_session_or_404(db, session_id)
    participant = await _participant_of(db, session_id, user_id)
    if participant is None:
        raise SessionError(403, "Not a participant of this session")

    if participant.user_id == session.presenter_id:
        was_lost = session.presenter_lost_at is not None
        session.presenter_heartbeat_at = _now()
        session.presenter_lost_at = None
        if was_lost and session.pres_state == PRES_PAUSED:
            # Presenter returned within the reconnect window: resume playback
            # state automatically (slides/questions/context were never lost).
            session = await _set_state(
                db, session, pres=PRES_LIVE, event_type="presenter_reconnected",
                actor_role="presenter", actor_user_id=user_id,
            )
    await db.commit()
    return {"pres_state": session.pres_state, "ai_state": session.ai_state}


async def check_presenter_timeout(db: AsyncSession, session_id: str) -> PresentationSession:
    """Recovery sweep (called by heartbeat of OTHER participants and by a
    periodic task): if the presenter heartbeat is older than grace_period_s,
    pause; if older than reconnect_window_s, end the session as
    presenter_absent — never a silent kill on a short network blip."""
    session = await get_session_or_404(db, session_id)
    if session.pres_state in (PRES_COMPLETED, PRES_IDLE):
        return session
    now = _now()
    beat = session.presenter_heartbeat_at
    if beat is not None:
        if isinstance(beat, str):
            beat = datetime.fromisoformat(beat.replace("Z", "+00:00"))
        gap = (now - beat).total_seconds()
        if gap <= session.grace_period_s:
            return session
        if gap > session.reconnect_window_s:
            return await complete_session(db, session_id=session.id, user_id=session.presenter_id, reason="presenter_absent")
        if session.pres_state == PRES_LIVE:
            session.presenter_lost_at = now
            return await _set_state(db, session, pres=PRES_PAUSED, event_type="presenter_lost", payload={"gap_s": gap})
    return session


# ---------------------------------------------------------------------------
# Session view (recovery checkpoint read)
# ---------------------------------------------------------------------------


async def session_view(db: AsyncSession, session_id: str) -> dict:
    session = await get_session_or_404(db, session_id)
    from app.models.presentation import PresentationSlide

    slides_rows = (await db.execute(
        select(PresentationSlide)
        .where(PresentationSlide.presentation_id == session.presentation_id)
        .order_by(PresentationSlide.position)
    )).scalars().all()
    participants = (await db.execute(
        select(PresentationParticipant).where(PresentationParticipant.session_id == session_id)
    )).scalars().all()
    questions = (await db.execute(
        select(PresentationQuestion).where(PresentationQuestion.session_id == session_id)
    )).scalars().all()
    return {
        "session_id": session.id,
        "presentation_id": session.presentation_id,
        "room_name": session.room_name,
        "pres_state": session.pres_state,
        "ai_state": session.ai_state,
        "ai_policy": session.ai_policy,
        "voice_owner": session.voice_owner,
        "recording_active": session.recording_active,
        "presenter_id": session.presenter_id,
        "slides": [
            {"id": s.slide_id, "index": i, "title": s.title,
             "bullets": __import__("json").loads(s.bullets_json or "[]"),
             "body": s.body or "", "speaker_notes": s.speaker_notes or "",
             "slide_type": s.slide_type}
            for i, s in enumerate(slides_rows)
        ],
        "participants": [
            {"id": p.id, "display_name": p.display_name, "role": p.role,
             "user_id": p.user_id, "reconnected_count": p.reconnected_count}
            for p in participants if p.left_at is None
        ],
        "questions": [
            {"id": q.id, "participant_id": q.participant_id, "status": q.status,
             "text": q.text, "source": q.source, "ai_answered": q.ai_answered,
             "answer_text": q.answer_text}
            for q in questions
        ],
    }
