"""Live slide operations for presentation sessions (Phase 3).

Executed only through the internal command relay (data-channel actions) or
the Phase 5 HTTP endpoints. Slide positions are sparse (step 1000); every
change writes a persistent ``slide_changed`` event carrying the new index so
clients can resynchronize.
"""

from __future__ import annotations

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.presentation import PresentationSlide
from app.presentation import repository as deck_repo
from app.presentation_session import primitives
from app.presentation_session.service import SessionError

ALLOWED_ACTIONS = ("goto_slide", "add_slide", "delete_slide", "reorder")


async def _slides_of(db: AsyncSession, session_id: str, presentation_id: str) -> list[PresentationSlide]:
    return list((await db.execute(
        select(PresentationSlide)
        .where(PresentationSlide.presentation_id == presentation_id)
        .order_by(PresentationSlide.position)
    )).scalars().all())


async def apply_command(
    db: AsyncSession, *, session_id: str, action: str, params: dict, participant
) -> dict:
    """Apply one slide command from a verified presenter."""
    from app.models.presentation import PresentationSession

    session = await db.get(PresentationSession, session_id)
    if session is None:
        raise SessionError(404, "Session not found")

    slides = await _slides_of(db, session_id, session.presentation_id)
    index = None

    if action == "goto_slide":
        index = int(params.get("index", 0))
        if index < 0 or (slides and index >= len(slides)) or (not slides and index > 0):
            raise SessionError(422, "Slide index out of range")
        new_index = index
    elif action == "delete_slide":
        slide_id = str(params.get("slide_id", ""))
        row = next((s for s in slides if s.slide_id == slide_id), None)
        if row is None:
            raise SessionError(404, "Slide not found")
        await db.delete(row)
        await db.flush()
        slides = await _slides_of(db, session_id, session.presentation_id)
        new_index = min(int(params.get("index", 0)), max(0, len(slides) - 1))
    elif action == "add_slide":
        new_slide = dict(params.get("slide") or {})
        new_slide.setdefault("id", __import__("uuid").uuid4().hex[:12])
        # Append after the current index (or at the end).
        current = int(params.get("index", len(slides) - 1 if slides else -1))
        after = slides[current] if 0 <= current < len(slides) else None
        if after is not None and len(slides) > current + 1:
            position = (after.position + slides[current + 1].position) // 2
        elif after is not None:
            position = after.position + deck_repo.POSITION_STEP
        else:
            position = 0
        fields = deck_repo._slide_row_fields(new_slide)
        db.add(PresentationSlide(presentation_id=session.presentation_id, position=position, **fields))
        await db.flush()
        slides = await _slides_of(db, session_id, session.presentation_id)
        new_index = slides.index(next(s for s in slides if s.slide_id == new_slide["id"]))
    elif action == "reorder":
        slide_id = str(params.get("slide_id", ""))
        to_index = int(params.get("to_index", 0))
        ok = await deck_repo.move_slide(
            db, presentation_id=session.presentation_id, slide_id=slide_id, to_index=to_index
        )
        if not ok:
            raise SessionError(404, "Slide or deck not found")
        slides = await _slides_of(db, session_id, session.presentation_id)
        new_index = next((i for i, s in enumerate(slides) if s.slide_id == slide_id), 0)
    else:
        raise SessionError(422, f"Unsupported action {action}")

    payload = {
        "index": new_index,
        "count": len(slides),
        "slide_id": slides[new_index].slide_id if slides else None,
        "title": slides[new_index].title if slides else None,
        "action": action,
    }
    await primitives.record_event(
        db, session_id=session_id, event_type="slide_changed",
        payload=payload, actor_role=participant.role,
        actor_user_id=participant.user_id,
    )
    await db.commit()
    return {"pres_state": session.pres_state, "ai_state": session.ai_state, **payload}
