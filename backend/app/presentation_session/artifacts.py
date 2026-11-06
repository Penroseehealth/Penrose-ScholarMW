"""Session artifacts (Phase 6): transcript, summary, unanswered/deferred
questions and a generated quiz — all from DB rows, all AI text through the
EXISTING provider chain (``call_ai_text``), no new AI configuration.
"""

from __future__ import annotations

import json

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.ai_client import call_ai_text
from app.models.presentation import (
    PresentationInstruction,
    PresentationQuestion,
    PresentationSession,
    PresentationTranscriptEvent,
)
from app.presentation_session.service import SessionError


async def transcript(db: AsyncSession, session_id: str) -> list[dict]:
    """Full ordered transcript with speaker attribution."""
    rows = (await db.execute(
        select(PresentationTranscriptEvent)
        .where(PresentationTranscriptEvent.session_id == session_id)
        .order_by(PresentationTranscriptEvent.created_at)
    )).scalars().all()
    return [
        {
            "speaker": r.speaker_label or r.source,
            "source": r.source,
            "text": r.text,
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r in rows
    ]


async def _question_lists(db: AsyncSession, session_id: str) -> tuple[list[str], list[str]]:
    rows = (await db.execute(
        select(PresentationQuestion).where(
            PresentationQuestion.session_id == session_id
        )
    )).scalars().all()
    unanswered = [q.text for q in rows if q.status in ("unanswered", "raised", "deferred")]
    answered = [f"Q: {q.text}\nA: {q.answer_text or ''}" for q in rows if q.status == "answered"]
    return unanswered, answered


async def summary(db: AsyncSession, session_id: str) -> str:
    """AI summary of the session from transcript + answered questions."""
    session = await db.get(PresentationSession, session_id)
    if session is None:
        raise SessionError(404, "Session not found")
    events = await transcript(db, session_id)
    _, answered = await _question_lists(db, session_id)
    corrections = (await db.execute(
        select(PresentationInstruction)
        .where(PresentationInstruction.session_id == session_id)
        .order_by(PresentationInstruction.created_at)
    )).scalars().all()

    lines = [f"{e['speaker']}: {e['text']}" for e in events[:80]]
    prompt = (
        "Summarize this live lesson session in at most 8 sentences for the "
        "presenter's post-session report. Cover what was taught, audience "
        "engagement, and corrections the presenter made.\n\n"
        "TRANSCRIPT:\n" + "\n".join(lines) + "\n\n"
        "ANSWERED QUESTIONS:\n" + ("\n".join(answered) or "(none)") + "\n\n"
        "PRESENTER CORRECTIONS:\n"
        + ("\n".join(f"- {c.text}" for c in corrections) or "(none)")
    )
    return await call_ai_text(
        [{"role": "user", "content": prompt}], max_tokens=600, timeout=90.0
    )


async def quiz(db: AsyncSession, session_id: str, *, count: int = 5) -> list[dict]:
    """Generate a comprehension quiz from the transcript (JSON list)."""
    events = await transcript(db, session_id)
    lines = [f"{e['speaker']}: {e['text']}" for e in events[:60]]
    if not lines:
        return []
    prompt = (
        f"Create {count} multiple-choice quiz questions from this lesson "
        "transcript. Return ONLY a JSON array; each item is "
        '{"question": str, "options": [str, str, str, str], "answer_index": int}. '
        "No markdown fences.\n\nTRANSCRIPT:\n" + "\n".join(lines)
    )
    raw = await call_ai_text(
        [{"role": "user", "content": prompt}], max_tokens=1200, temperature=0.4, timeout=90.0
    )
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, list):
            return [q for q in parsed if isinstance(q, dict) and q.get("question")]
    except (json.JSONDecodeError, TypeError):
        pass
    # One fenced-block retry before giving up (never fabricate a quiz).
    try:
        cleaned = raw[raw.index("["): raw.rindex("]") + 1]
        parsed = json.loads(cleaned)
        return [q for q in parsed if isinstance(q, dict) and q.get("question")]
    except (ValueError, json.JSONDecodeError):
        return []


async def artifacts(db: AsyncSession, session_id: str) -> dict:
    """Everything the presenter needs after a session (Phase 0D deliverable)."""
    session = await db.get(PresentationSession, session_id)
    if session is None:
        raise SessionError(404, "Session not found")
    unanswered, answered = await _question_lists(db, session_id)
    return {
        "session_id": session_id,
        "transcript": await transcript(db, session_id),
        "unanswered_questions": unanswered,
        "answered_questions": answered,
    }
