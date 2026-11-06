"""Phase 6 acceptance tests — recording consent ledger + session artifacts.

Maps to authorized Phase 6 criteria:
- Consent history is append-only (grant → withdrawal appends, never overwrites).
- Artifacts: transcript + unanswered/answered question lists from DB rows.
- Quiz generation returns [] gracefully when no transcript exists (no fabrication).
"""

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.presentation import (
    Presentation,
    PresentationParticipant,
    PresentationSession,
    PresentationTranscriptEvent,
)
from app.presentation_session import artifacts
from tests.conftest import auth_header


@pytest.fixture
async def ended_session(db_session: AsyncSession, lecturer_user):
    deck = Presentation(id="deckA", owner_id=lecturer_user.id, title="Artifacts Deck")
    session = PresentationSession(
        id="sessA", presentation_id="deckA", presenter_id=lecturer_user.id,
        room_name="pres_roomA", pres_state="completed", ai_state="idle",
        ai_policy="approval", ended_at=None, end_reason="presenter",
    )
    db_session.add(deck)
    db_session.add(session)
    presenter = PresentationParticipant(
        session_id="sessA", user_id=lecturer_user.id, display_name="L", role="presenter"
    )
    db_session.add(presenter)
    await db_session.commit()
    return {"session": "sessA", "presenter_pid": presenter.id, "lecturer": lecturer_user}


@pytest.mark.asyncio
async def test_consent_grant_then_withdraw_appends(db_session, ended_session):
    from datetime import datetime, timezone

    from app.models.presentation import PresentationRecordingConsent

    grant = PresentationRecordingConsent(
        session_id="sessA", participant_id=ended_session["presenter_pid"],
        decision="granted", scope="session_audio",
        granted_at=datetime.now(timezone.utc),
    )
    db_session.add(grant)
    await db_session.flush()
    first_id = grant.id

    withdrawal = PresentationRecordingConsent(
        session_id="sessA", participant_id=ended_session["presenter_pid"],
        decision="withdrawn", scope="session_audio",
        withdrawn_at=datetime.now(timezone.utc), prev_record_id=first_id,
    )
    db_session.add(withdrawal)
    await db_session.commit()

    rows = (await db_session.execute(
        __import__("sqlalchemy").text(
            "SELECT decision, prev_record_id FROM presentation_recording_consents "
            "WHERE session_id='sessA' ORDER BY id"
        )
    )).fetchall()
    assert [r.decision for r in rows] == ["granted", "withdrawn"]
    assert rows[1].prev_record_id == first_id  # chained, original intact


@pytest.mark.asyncio
async def test_transcript_with_attribution(db_session, ended_session):
    db_session.add_all([
        PresentationTranscriptEvent(
            session_id="sessA", speaker_label="Nkhani", source="agent",
            text="Today we cover photosynthesis.",
        ),
        PresentationTranscriptEvent(
            session_id="sessA", speaker_label="Ama", source="attendee",
            text="What about respiration?",
        ),
    ])
    await db_session.commit()
    rows = await artifacts.transcript(db_session, "sessA")
    assert len(rows) == 2
    assert rows[0]["speaker"] == "Nkhani" and rows[0]["source"] == "agent"
    assert rows[1]["speaker"] == "Ama" and rows[1]["source"] == "attendee"


@pytest.mark.asyncio
async def test_artifacts_list_unanswered_and_answered(db_session, ended_session):
    from app.models.presentation import PresentationQuestion

    db_session.add_all([
        PresentationQuestion(
            session_id="sessA", participant_id=ended_session["presenter_pid"],
            source="text", text="What is osmosis?", status="answered",
            ai_answered=True, answer_text="Movement of water across a membrane.",
        ),
        PresentationQuestion(
            session_id="sessA", participant_id=ended_session["presenter_pid"],
            source="text", text="Explain mitosis stages.", status="deferred",
        ),
    ])
    await db_session.commit()
    result = await artifacts.artifacts(db_session, "sessA")
    assert len(result["answered_questions"]) == 1
    assert "Movement of water" in result["answered_questions"][0]
    assert result["unanswered_questions"] == ["Explain mitosis stages."]


@pytest.mark.asyncio
async def test_quiz_empty_when_no_transcript(db_session, ended_session):
    result = await artifacts.quiz(db_session, "sessA")
    assert result == []  # no transcript → no fabricated quiz


@pytest.mark.asyncio
async def test_consent_endpoints_require_auth(client: AsyncClient):
    resp = await client.get("/api/v1/presentation-sessions/sessX/recording-consents")
    assert resp.status_code in (401, 403)
