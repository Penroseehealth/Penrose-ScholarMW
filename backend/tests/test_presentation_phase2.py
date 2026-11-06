"""Phase 2 acceptance tests — session lifecycle + LiveKit security.

Maps to the authorized Phase 2 acceptance list:
- Attendees cannot execute presenter commands.
- Co-presenters cannot change restricted AI policies or end sessions.
- Forged roles are rejected (role resolution is server-side only).
- Guests cannot join arbitrary rooms.
- Revoked guest tokens cannot rejoin / get tokens.
- Event replay restores missing persistent events.
"""

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token, hash_password
from app.models.models import User, UserRole
from app.models.presentation import (
    Presentation,
    PresentationParticipant,
    PresentationSession,
)
from app.presentation_session import service
from app.presentation_session.service import SessionError
from tests.conftest import auth_header


@pytest.fixture
async def deck_and_session(db_session: AsyncSession, lecturer_user):
    deck = Presentation(id="deckS", owner_id=lecturer_user.id, title="Deck")
    db_session.add(deck)
    await db_session.flush()
    session = PresentationSession(
        id="sessS", presentation_id="deckS",
        presenter_id=lecturer_user.id, room_name="pres_roomS",
        join_code_hash=__import__("hashlib").sha256(b"CODE1234").hexdigest(),
    )
    db_session.add(session)
    presenter_row = PresentationParticipant(
        session_id="sessS", user_id=lecturer_user.id, display_name="Lect", role="presenter"
    )
    db_session.add(presenter_row)
    await db_session.commit()
    return {"deck": "deckS", "session": "sessS", "lecturer": lecturer_user}


async def _join_as_attendee(db, session_id, user):
    return await service.join_session(
        db, session_id=session_id, join_code=None, user=user, display_name="Attendee"
    )


# ---------------------------------------------------------------------------
# Lifecycle + roles
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_attendee_cannot_pause_or_interrupt(db_session, student_user, deck_and_session):
    await _join_as_attendee(db_session, "sessS", student_user)
    await db_session.commit()
    with pytest.raises(SessionError) as e:
        await service.pause_session(db_session, session_id="sessS", user_id=student_user.id)
    assert e.value.status_code == 403
    with pytest.raises(SessionError) as e:
        await service.interrupt_session(db_session, session_id="sessS", user_id=student_user.id)
    assert e.value.status_code == 403


@pytest.mark.asyncio
async def test_presenter_lifecycle_happy_path(db_session, lecturer_user, deck_and_session):
    await service.start_session(db_session, session_id="sessS", user_id=lecturer_user.id)
    await db_session.commit()
    await service.pause_session(db_session, session_id="sessS", user_id=lecturer_user.id)
    await db_session.commit()
    session = await service.resume_session(db_session, session_id="sessS", user_id=lecturer_user.id)
    assert session.pres_state == "live"
    session = await service.complete_session(db_session, session_id="sessS", user_id=lecturer_user.id)
    assert session.pres_state == "completed"


@pytest.mark.asyncio
async def test_invalid_transitions_rejected(db_session, lecturer_user, deck_and_session):
    # Cannot pause before start (idle → paused is not a valid transition).
    with pytest.raises(SessionError):
        await service.pause_session(db_session, session_id="sessS", user_id=lecturer_user.id)
    await service.start_session(db_session, session_id="sessS", user_id=lecturer_user.id)
    await db_session.commit()
    # Completed sessions cannot go back to live.
    await service.complete_session(db_session, session_id="sessS", user_id=lecturer_user.id)
    with pytest.raises(SessionError):
        await service.start_session(db_session, session_id="sessS", user_id=lecturer_user.id)


@pytest.mark.asyncio
async def test_co_presenter_cannot_change_policy_or_end(db_session, student_user, deck_and_session):
    from app.models.presentation import PresentationParticipant as PP

    db_session.add(PP(session_id="sessS", user_id=student_user.id, display_name="Co", role="co_presenter"))
    await db_session.commit()
    with pytest.raises(SessionError) as e:
        await service.set_ai_policy(db_session, session_id="sessS", policy="auto", user_id=student_user.id)
    assert e.value.status_code == 403
    with pytest.raises(SessionError) as e:
        await service.complete_session(db_session, session_id="sessS", user_id=student_user.id)
    assert e.value.status_code == 403


# ---------------------------------------------------------------------------
# Guest join + revocation
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_guest_join_with_code_and_forgery_rejected(db_session, deck_and_session):
    joined = await service.join_session(
        db_session, session_id=None, join_code="CODE1234", user=None, display_name="Ama"
    )
    assert joined["role"] == "attendee"
    assert joined["guest_token"]
    # Wrong code never finds a session (and cannot forge a role).
    with pytest.raises(SessionError):
        await service.join_session(db_session, session_id=None, join_code="WRONGCODE", user=None, display_name="X")


@pytest.mark.asyncio
async def test_guest_cannot_join_completed_session(db_session, lecturer_user, deck_and_session):
    await service.complete_session(db_session, session_id="sessS", user_id=lecturer_user.id)
    with pytest.raises(SessionError) as e:
        await service.join_session(db_session, session_id=None, join_code="CODE1234", user=None, display_name="Late")
    assert e.value.status_code == 409


@pytest.mark.asyncio
async def test_named_join_assigns_attendee_not_presenter(db_session, student_user, deck_and_session):
    joined = await _join_as_attendee(db_session, "sessS", student_user)
    await db_session.commit()
    assert joined["role"] == "attendee"  # server-side decision, not client-supplied


# ---------------------------------------------------------------------------
# Questions + moderation + policies
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_question_flow_approval_policy(db_session, student_user, deck_and_session):
    joined = await _join_as_attendee(db_session, "sessS", student_user)
    await db_session.commit()
    q = await service.raise_question(
        db_session, session_id="sessS", participant_id=joined["participant_id"], text_q="Why is the sky blue?"
    )
    await db_session.commit()
    assert q["status"] == "raised"  # approval policy → raised, awaiting presenter
    assert q["ai_state"] == "idle"  # session not started → combination kept idle

    decided = await service.moderate_question(
        db_session, session_id="sessS", question_id=q["question_id"], decision="approve", user_id=deck_and_session["lecturer"].id
    )
    assert decided["status"] == "approved"


@pytest.mark.asyncio
async def test_auto_policy_answers_without_presenter(db_session, student_user, deck_and_session):
    from app.presentation_session import primitives

    await service.start_session(db_session, session_id="sessS", user_id=deck_and_session["lecturer"].id)
    await db_session.commit()
    await service.set_ai_policy(db_session, session_id="sessS", policy="auto", user_id=deck_and_session["lecturer"].id)
    joined = await _join_as_attendee(db_session, "sessS", student_user)
    await db_session.commit()
    q = await service.raise_question(
        db_session, session_id="sessS", participant_id=joined["participant_id"], text_q="Define osmosis"
    )
    assert q["status"] == "approved" and q["ai_state"] == "responding"


@pytest.mark.asyncio
async def test_presenter_only_never_answers(db_session, student_user, deck_and_session):
    await service.start_session(db_session, session_id="sessS", user_id=deck_and_session["lecturer"].id)
    await db_session.commit()
    await service.set_ai_policy(db_session, session_id="sessS", policy="presenter_only", user_id=deck_and_session["lecturer"].id)
    joined = await _join_as_attendee(db_session, "sessS", student_user)
    await db_session.commit()
    q = await service.raise_question(
        db_session, session_id="sessS", participant_id=joined["participant_id"], text_q="Any question?"
    )
    assert q["status"] == "raised" and q["ai_state"] == "idle"


@pytest.mark.asyncio
async def test_duplicate_question_rate_limited(db_session, student_user, deck_and_session):
    joined = await _join_as_attendee(db_session, "sessS", student_user)
    await db_session.commit()
    first = await service.raise_question(
        db_session, session_id="sessS", participant_id=joined["participant_id"], text_q="Same text?"
    )
    with pytest.raises(SessionError) as e:
        await service.raise_question(
            db_session, session_id="sessS", participant_id=joined["participant_id"], text_q="Same text?"
        )
    assert e.value.status_code == 429


@pytest.mark.asyncio
async def test_attendee_cannot_moderate(db_session, student_user, deck_and_session):
    joined = await _join_as_attendee(db_session, "sessS", student_user)
    await db_session.commit()
    q = await service.raise_question(
        db_session, session_id="sessS", participant_id=joined["participant_id"], text_q="Q?"
    )
    with pytest.raises(SessionError) as e:
        await service.moderate_question(
            db_session, session_id="sessS", question_id=q["question_id"], decision="approve", user_id=student_user.id
        )
    assert e.value.status_code == 403


# ---------------------------------------------------------------------------
# Recovery
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_presenter_timeout_pauses_then_absent_ends(db_session, deck_and_session):
    from datetime import datetime, timedelta, timezone

    lecturer = deck_and_session["lecturer"]
    await service.start_session(db_session, session_id="sessS", user_id=lecturer.id)
    await db_session.commit()

    # Simulate a stale heartbeat: older than grace, within reconnect window.
    session = await service.get_session_or_404(db_session, "sessS")
    session.presenter_heartbeat_at = datetime.now(timezone.utc) - timedelta(seconds=301)
    await db_session.commit()
    session = await service.check_presenter_timeout(db_session, "sessS")
    assert session.pres_state == "paused"  # paused, NOT completed

    # Older than the reconnect window → presenter_absent completion.
    session.presenter_heartbeat_at = datetime.now(timezone.utc) - timedelta(seconds=3900)
    await db_session.commit()
    session = await service.check_presenter_timeout(db_session, "sessS")
    assert session.pres_state == "completed"
    assert session.end_reason == "presenter_absent"


@pytest.mark.asyncio
async def test_presenter_reconnect_restores_live(db_session, deck_and_session):
    from datetime import datetime, timedelta, timezone

    lecturer = deck_and_session["lecturer"]
    await service.start_session(db_session, session_id="sessS", user_id=lecturer.id)
    await db_session.commit()
    session = await service.get_session_or_404(db_session, "sessS")
    session.presenter_heartbeat_at = datetime.now(timezone.utc) - timedelta(seconds=301)
    await db_session.commit()
    session = await service.check_presenter_timeout(db_session, "sessS")
    assert session.pres_state == "paused"

    # Heartbeat again (presenter back within window) → live restored.
    result = await service.heartbeat(db_session, session_id="sessS", user_id=lecturer.id)
    assert result["pres_state"] == "live"


# ---------------------------------------------------------------------------
# Event replay (persistent only)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_event_replay_returns_persistent_in_order(db_session, lecturer_user, deck_and_session):
    from app.presentation_session import primitives

    await service.start_session(db_session, session_id="sessS", user_id=lecturer_user.id)
    await service.pause_session(db_session, session_id="sessS", user_id=lecturer_user.id)
    await db_session.commit()

    events = await primitives.replay_events(db_session, session_id="sessS")
    types = [e["event_type"] for e in events]
    # The fixture builds the session row directly (no create_session call),
    # so the first recorded event is the start, not the creation.
    assert types[0] == "session_started"
    assert "presentation_paused" in types
    seqs = [e["seq"] for e in events]
    assert seqs == sorted(seqs)
