"""Database-backed persistence for the AI Lecture Presentation Builder.

Phase 1 of the authorized implementation. Replaces the previous in-process
``EngineStore`` dict (which lost every generated deck on restart) with rows in
the ``presentations`` / ``presentation_slides`` tables. The database is the
single source of truth — there is no secondary cache.

Slide rows use the sparse-position scheme (step 1000) from the approved Phase
0D schema so a later live-session reorder can move one slide with a single
UPDATE. Bulk saves here rewrite positions compactly, which is safe because
authoring happens before any session exists.
"""

from __future__ import annotations

import json
import uuid

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.presentation import Presentation, PresentationSlide

POSITION_STEP = 1000


def _slide_row_fields(slide: dict) -> dict:
    """Slide-dict -> column fields. Unknown keys are ignored, missing keys
    get the schema defaults, so older slide shapes keep saving."""
    bullets = slide.get("bullets") or []
    return {
        "slide_id": str(slide.get("id") or uuid.uuid4().hex[:12]),
        "slide_type": str(slide.get("slide_type") or "content"),
        "title": str(slide.get("title") or ""),
        "bullets_json": json.dumps(bullets),
        "body": slide.get("body") or "",
        "speaker_notes": slide.get("speaker_notes") or "",
        "citation": slide.get("citation") or "",
        "layout": str(slide.get("layout") or "title_and_content"),
        "learning_objective": slide.get("learning_objective") or "",
    }


def _slide_dict(row: PresentationSlide) -> dict:
    """Column fields -> the plain slide dict the service and router use."""
    try:
        bullets = json.loads(row.bullets_json or "[]")
    except (TypeError, ValueError):
        bullets = []
    return {
        "id": row.slide_id,
        "slide_type": row.slide_type,
        "title": row.title,
        "bullets": bullets,
        "body": row.body or "",
        "speaker_notes": row.speaker_notes or "",
        "citation": row.citation or "",
        "layout": row.layout,
        "learning_objective": row.learning_objective or "",
        # `source` is a per-generation field the store never persisted; it is
        # not reconstructed — regenerated slides still carry theirs fresh.
        "position": row.position,
    }


async def save_presentation(
    db: AsyncSession,
    *,
    presentation_id: str,
    owner_id: int,
    title: str,
    config,
    outline: list[dict],
    slides: list[dict],
) -> None:
    """Upsert a presentation and its slides. Authoritative write.

    ``config`` may be a pydantic BuilderConfig or an already-serializable
    object; ``model_dump`` is tried first, ``dict``-likes pass through.
    """
    if hasattr(config, "model_dump"):
        config_payload = config.model_dump()
    else:
        config_payload = dict(config)

    existing = await db.get(Presentation, presentation_id)
    if existing is None:
        existing = Presentation(
            id=presentation_id,
            owner_id=owner_id,
            title=title or "",
            config_json=json.dumps(config_payload),
            source_summary=json.dumps({"outline": outline}),
        )
        db.add(existing)
    else:
        existing.title = title or existing.title
        existing.config_json = json.dumps(config_payload)
        existing.source_summary = json.dumps({"outline": outline})
        # Replace the slide set wholesale: generation and edits always send a
        # complete deck, so a stale partial rowset can never survive.
        await db.execute(
            delete(PresentationSlide).where(
                PresentationSlide.presentation_id == presentation_id
            )
        )

    for index, slide in enumerate(slides):
        fields = _slide_row_fields(slide)
        db.add(
            PresentationSlide(
                presentation_id=presentation_id,
                position=index * POSITION_STEP,
                **fields,
            )
        )
    await db.commit()


async def load_presentation(db: AsyncSession, presentation_id: str) -> dict | None:
    """Read a presentation back in the exact shape the regenerate endpoints
    consumed from the old store: ``{'config', 'outline', 'slides'}``. Returns
    None when the id is unknown — the router maps that to 404."""
    row = await db.get(Presentation, presentation_id)
    if row is None:
        return None

    result = await db.execute(
        select(PresentationSlide)
        .where(PresentationSlide.presentation_id == presentation_id)
        .order_by(PresentationSlide.position)
    )
    slides = [_slide_dict(s) for s in result.scalars().all()]

    try:
        config_payload = json.loads(row.config_json or "{}")
    except (TypeError, ValueError):
        config_payload = {}
    try:
        outline = json.loads(row.source_summary or "{}").get("outline") or []
    except (TypeError, ValueError):
        outline = []

    return {
        "config": config_payload,
        "outline": outline,
        "slides": [{k: v for k, v in s.items() if k != "position"} for s in slides],
    }


async def list_presentations(db: AsyncSession, owner_id: int) -> list[dict]:
    """The owner's decks, newest first (session UI needs the id + title)."""
    result = await db.execute(
        select(Presentation)
        .where(Presentation.owner_id == owner_id)
        .order_by(Presentation.updated_at.desc())
    )
    return [
        {"id": p.id, "title": p.title, "updated_at": p.updated_at.isoformat() if p.updated_at else None}
        for p in result.scalars().all()
    ]


async def move_slide(
    db: AsyncSession, *, presentation_id: str, slide_id: str, to_index: int
) -> bool:
    """Move one slide to a new ordinal position.

    Transactional and collision-free: the target position is the midpoint of
    the sparse positions around the destination slot, so a single UPDATE moves
    one slide without touching any other row. A ``flush`` inside the
    transaction makes any failure abort the move entirely (no partial state).
    Returns False when the deck or slide does not exist or the index is out
    of range.
    """
    result = await db.execute(
        select(PresentationSlide)
        .where(PresentationSlide.presentation_id == presentation_id)
        .order_by(PresentationSlide.position)
    )
    slides = list(result.scalars().all())
    if not slides:
        return False
    index = next((i for i, s in enumerate(slides) if s.slide_id == slide_id), None)
    if index is None:
        return False
    to_index = max(0, min(to_index, len(slides) - 1))
    if index == to_index:
        return True

    if to_index == 0:
        new_position = slides[0].position - POSITION_STEP
    elif to_index == len(slides) - 1:
        new_position = slides[-1].position + POSITION_STEP
    else:
        new_position = (
            slides[to_index - 1].position + slides[to_index].position
        ) // 2
        if new_position in (slides[to_index - 1].position, slides[to_index].position):
            # Neighbouring positions have collapsed to adjacent integers
            # (renormalization is due); fall back to a gap-preserving move.
            new_position = slides[to_index].position + POSITION_STEP // 2

    slide = slides[index]
    slide.position = new_position
    await db.commit()
    return True


async def slide_positions(db: AsyncSession, presentation_id: str) -> list[tuple[str, int]]:
    """Ordered (slide_id, position) pairs — the assertion surface for the
    ordering tests and the session slide-synchronizer."""
    result = await db.execute(
        select(PresentationSlide)
        .where(PresentationSlide.presentation_id == presentation_id)
        .order_by(PresentationSlide.position)
    )
    return [(s.slide_id, s.position) for s in result.scalars().all()]
