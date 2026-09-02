"""Biology Visualization Engine — API router.

Curriculum-grounded structured diagram specs. SVG rendering is performed
client-side (Flutter) from the structured `spec`; the backend persists specs
and metadata so diagrams can be reopened, edited, versioned and exported.
"""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

# Import ensures the biology_viz tables register on Base.metadata at startup.
from app.biology_viz import jobs  # noqa: F401
from app.biology_viz.jobs import enqueue_spec_generation, job_store, to_status
from app.biology_viz.schemas import (
    EditRequest,
    GenerateRequest,
    GenerateStatus,
    VisualizationDetail,
    VisualizationSummary,
)
from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.biology_viz import BiologyVisualization, BiologyVisualizationVersion
from app.models.models import User
from app.models.stem import (
    SyllabusCoreElement,
    SyllabusSubject,
    SyllabusTopic,
    SyllabusVersion,
)

router = APIRouter(
    prefix="/biology/diagrams",
    tags=["Biology Visualization"],
)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _version_summary(v: BiologyVisualizationVersion) -> dict:
    return {
        "id": v.id,
        "version": v.version,
        "is_current": v.is_current,
        "created_at": v.created_at.isoformat() if v.created_at else None,
    }


def _spec_app(viz: BiologyVisualization) -> str:
    """Cell app key lives inside the structured spec, not on the row."""
    spec = viz.spec or {}
    return spec.get("app") or spec.get("app_key") or "plant_cell"


def _detail(viz: BiologyVisualization) -> VisualizationDetail:
    versions = sorted(viz.versions, key=lambda v: v.version)
    return VisualizationDetail(
        id=viz.id,
        title=viz.title,
        category=viz.category,
        app=_spec_app(viz),
        form=viz.form,
        topic=viz.topic,
        subtopic=viz.subtopic,
        diagram_type=viz.diagram_type,
        prompt=viz.prompt,
        spec=viz.spec or {},
        background=viz.background,
        quality_level=viz.quality_level,
        syllabus_reference=viz.syllabus_reference,
        versions=[_version_summary(v) for v in versions],
    )


def _summary(viz: BiologyVisualization) -> VisualizationSummary:
    versions = sorted(viz.versions, key=lambda v: v.version)
    latest_version = versions[-1].version if versions else 1
    return VisualizationSummary(
        id=viz.id,
        title=viz.title,
        category=viz.category,
        app=_spec_app(viz),
        form=viz.form,
        topic=viz.topic,
        subtopic=viz.subtopic,
        diagram_type=viz.diagram_type,
        thumbnail_svg=None,
        version=latest_version,
        created_at=viz.created_at.isoformat() if viz.created_at else None,
    )


async def _load(db: AsyncSession, viz_id: int) -> BiologyVisualization:
    viz = (
        (
            await db.execute(
                select(BiologyVisualization)
                .options(selectinload(BiologyVisualization.versions))
                .where(BiologyVisualization.id == viz_id)
            )
        )
        .scalars()
        .first()
    )
    if viz is None:
        raise HTTPException(status_code=404, detail="Visualization not found")
    return viz


@router.post("/generate", response_model=GenerateStatus, status_code=202)
async def generate(
    body: GenerateRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Queue an async spec-generation job from a user prompt."""
    job = enqueue_spec_generation(
        body.prompt,
        {
            "user_id": user.id if user else None,
            "app": body.app,
            "form": body.form,
            "topic": body.topic,
            "subtopic": body.subtopic,
            "background": body.background,
            "labels_shown": body.labels_shown,
            "quality_level": body.quality_level,
            "exclude": body.exclude,
        },
    )
    return to_status(job)


@router.get("/jobs/{job_id}", response_model=GenerateStatus)
async def generation_status(
    job_id: int,
    user: User = Depends(get_current_user),
):
    job = job_store.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Generation job not found")
    return to_status(job)


@router.get("", response_model=list[VisualizationSummary])
async def list_visualizations(
    form: int | None = Query(default=None, ge=1, le=4),
    category: str | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """History of the user's biology diagrams (optionally filtered)."""
    stmt = select(BiologyVisualization).options(
        selectinload(BiologyVisualization.versions)
    )
    if user and user.id:
        stmt = stmt.where(BiologyVisualization.user_id == user.id)
    if form:
        stmt = stmt.where(BiologyVisualization.form == form)
    if category:
        stmt = stmt.where(BiologyVisualization.category == category)
    rows = (
        (await db.execute(stmt.order_by(BiologyVisualization.updated_at.desc())))
        .scalars()
        .all()
    )
    return [_summary(v) for v in rows]


@router.get("/syllabus/topics", response_model=list[dict])
async def syllabus_topics(
    form: int | None = Query(default=None, ge=1, le=4),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Biology topics from the seeded Malawi syllabus (optionally by Form)."""
    try:
        subject = (
            await db.execute(
                select(SyllabusSubject).where(
                    SyllabusSubject.slug == "biology",
                    SyllabusSubject.is_active == True,  # noqa: E712
                )
            )
        ).scalar_one_or_none()
        if not subject:
            return []
        versions = (
            (
                await db.execute(
                    select(SyllabusVersion).where(
                        SyllabusVersion.subject_id == subject.id
                    )
                )
            )
            .scalars()
            .all()
        )
        ce_ids = [
            ce.id
            for ce in (
                await db.execute(
                    select(SyllabusCoreElement).where(
                        SyllabusCoreElement.version_id.in_([v.id for v in versions])
                    )
                )
            )
            .scalars()
            .all()
        ]
        q = select(SyllabusTopic).where(SyllabusTopic.core_element_id.in_(ce_ids))
        if form:
            q = q.where(SyllabusTopic.year_level == form)
        topics = (
            (
                await db.execute(
                    q.order_by(SyllabusTopic.year_level, SyllabusTopic.order_index)
                )
            )
            .scalars()
            .all()
        )
        return [
            {"id": t.id, "title": t.title, "year_level": t.year_level} for t in topics
        ]
    except Exception:
        return []


@router.post("/save", response_model=VisualizationDetail, status_code=200)
async def save(
    body: GenerateRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Synchronously build and persist a spec (used for fast edits/saves)."""
    from app.biology_viz.engine import build_spec

    spec, _detected = await build_spec(
        db,
        body.prompt,
        app=body.app,
        form=body.form,
        topic=body.topic,
        subtopic=body.subtopic,
        background=body.background,
        labels_shown=body.labels_shown,
        quality_level=body.quality_level,
        exclude=set(body.exclude or []),
    )
    viz = BiologyVisualization(
        user_id=user.id if user else None,
        subject_slug="biology",
        form=spec.form,
        category=spec.category,
        topic=spec.topic,
        subtopic=spec.subtopic,
        prompt=body.prompt,
        diagram_type=spec.diagram_type,
        spec=spec.model_dump(),
        title=spec.title,
        thumbnail_svg=None,
        quality_level=spec.quality_level,
        background=spec.background,
        labels_shown=spec.labels_shown,
        syllabus_reference=spec.syllabus_reference,
    )
    db.add(viz)
    await db.flush()
    db.add(
        BiologyVisualizationVersion(
            visualization_id=viz.id,
            version=1,
            is_current=True,
            spec=viz.spec,
        )
    )
    await db.commit()
    viz = await _load(db, viz.id)
    return _detail(viz)


@router.get("/{viz_id}", response_model=VisualizationDetail)
async def get_visualization(
    viz_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    viz = await _load(db, viz_id)
    return _detail(viz)


@router.put("/{viz_id}", response_model=VisualizationDetail)
async def edit_visualization(
    viz_id: int,
    body: EditRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Apply lightweight edits (background/labels/title/annotations) without full regen."""
    viz = await _load(db, viz_id)
    changed = False
    if body.background is not None and body.background != viz.background:
        viz.background = body.background
        spec = dict(viz.spec or {})
        spec["background"] = body.background
        viz.spec = spec
        changed = True
    if body.labels_shown is not None and body.labels_shown != viz.labels_shown:
        viz.labels_shown = body.labels_shown
        spec = dict(viz.spec or {})
        spec["labels_shown"] = body.labels_shown
        viz.spec = spec
        changed = True
    if body.title is not None and body.title.strip():
        viz.title = body.title.strip()
        changed = True
    if body.exclude is not None:
        spec = dict(viz.spec or {})
        drop = {e.lower().replace(" ", "_") for e in body.exclude}
        structures = [
            {**s, "present": (s.get("id") not in drop) and bool(s.get("present"))}
            for s in spec.get("structures", [])
        ]
        spec["structures"] = structures
        viz.spec = spec
        changed = True
    if changed:
        await db.commit()
        viz = await _load(db, viz_id)
    return _detail(viz)


@router.post("/{viz_id}/regenerate", response_model=GenerateStatus, status_code=202)
async def regenerate(
    viz_id: int,
    body: GenerateRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Queue a new version of an existing visualization."""
    existing = await _load(db, viz_id)
    job = enqueue_spec_generation(
        body.prompt or existing.prompt,
        {
            "user_id": user.id if user else None,
            "app": body.app or _spec_app(existing),
            "form": body.form or existing.form,
            "topic": body.topic or existing.topic,
            "subtopic": body.subtopic or existing.subtopic,
            "background": body.background or existing.background,
            "labels_shown": body.labels_shown,
            "quality_level": body.quality_level or existing.quality_level,
            "exclude": body.exclude,
        },
    )
    return to_status(job)


@router.delete("/{viz_id}", status_code=204)
async def delete_visualization(
    viz_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    viz = await _load(db, viz_id)
    await db.delete(viz)
    await db.commit()
