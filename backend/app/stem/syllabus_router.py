"""Syllabus CRUD API — admin-managed, student-read-only."""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.database.engine import get_db
from app.dependencies.auth import require_admin
from app.models.stem import (
    SyllabusCoreElement,
    SyllabusLearningObjective,
    SyllabusResource,
    SyllabusSubject,
    SyllabusSubtopic,
    SyllabusTopic,
    SyllabusVersion,
)

router = APIRouter(prefix="/syllabus", tags=["Syllabus Management"])


# ── Pydantic schemas ─────────────────────────────────────────────


class SubjectCreate(BaseModel):
    name: str
    slug: str
    description: str | None = None
    icon: str | None = None
    color: str | None = None


class VersionCreate(BaseModel):
    subject_id: int
    version_name: str
    year_effective: int | None = None
    examination_board: str | None = None
    description: str | None = None


class CoreElementCreate(BaseModel):
    version_id: int
    number: int
    name: str
    description: str | None = None
    order_index: int = 0


class TopicCreate(BaseModel):
    core_element_id: int
    title: str
    description: str | None = None
    year_level: int = 3
    order_index: int = 0


class SubtopicCreate(BaseModel):
    topic_id: int
    title: str
    description: str | None = None
    order_index: int = 0


class LOCreate(BaseModel):
    subtopic_id: int
    objective: str
    description: str | None = None
    cognitive_level: str = "Knowledge"
    teaching_activity: str | None = None
    teaching_method: str | None = None


class ResourceCreate(BaseModel):
    topic_id: int
    resource_text: str
    resource_type: str = "equipment"


class ReorderRequest(BaseModel):
    ordered_ids: list[int]


class TopicUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    year_level: int | None = None
    order_index: int | None = None


class SubtopicUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    order_index: int | None = None


class LOUpdate(BaseModel):
    objective: str | None = None
    description: str | None = None
    cognitive_level: str | None = None
    teaching_activity: str | None = None
    teaching_method: str | None = None


# ── Student read-only endpoints ───────────────────────────────────


@router.get("/subjects")
async def list_subjects(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(SyllabusSubject).where(SyllabusSubject.is_active == True))
    return [
        {
            "id": s.id,
            "name": s.name,
            "slug": s.slug,
            "description": s.description,
            "icon": s.icon,
            "color": s.color,
        }
        for s in result.scalars().all()
    ]


@router.get("/subjects/{slug}/tree")
async def get_syllabus_tree(slug: str, db: AsyncSession = Depends(get_db)):
    """Full syllabus tree for a subject: versions → core elements → topics → subtopics → L.O.s"""
    from app.stem.slug_utils import resolve_slug

    slug = resolve_slug(slug)
    subject = (
        await db.execute(select(SyllabusSubject).where(SyllabusSubject.slug == slug, SyllabusSubject.is_active == True))
    ).scalar_one_or_none()
    if not subject:
        raise HTTPException(404, "Subject not found")

    versions = (
        (
            await db.execute(
                select(SyllabusVersion)
                .where(SyllabusVersion.subject_id == subject.id)
                .options(
                    joinedload(SyllabusVersion.core_elements)
                    .joinedload(SyllabusCoreElement.topics)
                    .joinedload(SyllabusTopic.subtopics)
                    .joinedload(SyllabusSubtopic.learning_objectives),
                    joinedload(SyllabusVersion.core_elements)
                    .joinedload(SyllabusCoreElement.topics)
                    .joinedload(SyllabusTopic.resources),
                )
                .order_by(SyllabusVersion.id.desc())
            )
        )
        .scalars()
        .unique()
        .all()
    )

    def _lo(lo: SyllabusLearningObjective) -> dict:
        return {
            "id": lo.id,
            "objective": lo.objective,
            "description": lo.description,
            "cognitive_level": lo.cognitive_level,
            "teaching_activity": lo.teaching_activity,
            "teaching_method": lo.teaching_method,
        }

    def _sub(sub: SyllabusSubtopic) -> dict:
        return {
            "id": sub.id,
            "title": sub.title,
            "description": sub.description,
            "learning_objectives": [_lo(lo) for lo in sub.learning_objectives],
        }

    def _topic(t: SyllabusTopic) -> dict:
        return {
            "id": t.id,
            "title": t.title,
            "description": t.description,
            "year_level": t.year_level,
            "subtopics": [_sub(s) for s in t.subtopics],
            "resources": [r.resource_text for r in t.resources],
        }

    def _ce(ce: SyllabusCoreElement) -> dict:
        return {
            "id": ce.id,
            "number": ce.number,
            "name": ce.name,
            "description": ce.description,
            "topics": [_topic(t) for t in ce.topics],
        }

    def _ver(v: SyllabusVersion) -> dict:
        return {
            "id": v.id,
            "version_name": v.version_name,
            "year_effective": v.year_effective,
            "examination_board": v.examination_board,
            "is_current": v.is_current,
            "core_elements": [_ce(ce) for ce in v.core_elements],
        }

    return {
        "subject": {"id": subject.id, "name": subject.name, "slug": subject.slug},
        "versions": [_ver(v) for v in versions],
    }


@router.get("/subjects/{slug}/topics")
async def list_topics_flat(slug: str, db: AsyncSession = Depends(get_db)):
    """Flat list of all topics for a subject — useful for search and dropdown."""
    from app.stem.slug_utils import resolve_slug

    slug = resolve_slug(slug)
    subject = (
        await db.execute(select(SyllabusSubject).where(SyllabusSubject.slug == slug, SyllabusSubject.is_active == True))
    ).scalar_one_or_none()
    if not subject:
        raise HTTPException(404, "Subject not found")

    ce_ids = [
        ce.id
        for ce in (
            await db.execute(
                select(SyllabusCoreElement).join(SyllabusVersion).where(SyllabusVersion.subject_id == subject.id)
            )
        )
        .scalars()
        .all()
    ]
    topics = (
        (
            await db.execute(
                select(SyllabusTopic)
                .where(SyllabusTopic.core_element_id.in_(ce_ids))
                .order_by(SyllabusTopic.order_index)
            )
        )
        .scalars()
        .all()
    )

    return [{"id": t.id, "title": t.title, "year_level": t.year_level} for t in topics]


@router.get("/search")
async def search_syllabus(q: str, db: AsyncSession = Depends(get_db)):
    """Search across topics, subtopics, and learning objectives."""
    pattern = f"%{q}%"
    lo_results = await db.execute(
        select(
            SyllabusLearningObjective.id,
            SyllabusLearningObjective.objective,
            SyllabusLearningObjective.cognitive_level,
            SyllabusTopic.title.label("topic_title"),
            SyllabusCoreElement.name.label("ce_name"),
            SyllabusSubject.slug.label("subject_slug"),
        )
        .join(
            SyllabusSubtopic,
            SyllabusLearningObjective.subtopic_id == SyllabusSubtopic.id,
        )
        .join(SyllabusTopic, SyllabusSubtopic.topic_id == SyllabusTopic.id)
        .join(SyllabusCoreElement, SyllabusTopic.core_element_id == SyllabusCoreElement.id)
        .join(SyllabusVersion, SyllabusCoreElement.version_id == SyllabusVersion.id)
        .join(SyllabusSubject, SyllabusVersion.subject_id == SyllabusSubject.id)
        .where(
            SyllabusLearningObjective.objective.ilike(pattern)
            | (
                SyllabusLearningObjective.description.is_not(None)
                & SyllabusLearningObjective.description.ilike(pattern)
            )
        )
    ).all()

    return [
        {
            "type": "learning_objective",
            "id": row.id,
            "text": row.objective,
            "cognitive_level": row.cognitive_level,
            "topic": row.topic_title,
            "core_element": row.ce_name,
            "subject": row.subject_slug,
        }
        for row in lo_results
    ]


# ── Admin-only CRUD endpoints ─────────────────────────────────────


@router.post("/admin/subjects", dependencies=[Depends(require_admin)])
async def create_subject(data: SubjectCreate, db: AsyncSession = Depends(get_db)):
    subject = SyllabusSubject(**data.model_dump())
    db.add(subject)
    await db.commit()
    await db.refresh(subject)
    return {"id": subject.id, "name": subject.name, "slug": subject.slug}


@router.post("/admin/versions", dependencies=[Depends(require_admin)])
async def create_version(data: VersionCreate, db: AsyncSession = Depends(get_db)):
    version = SyllabusVersion(**data.model_dump())
    db.add(version)
    await db.commit()
    await db.refresh(version)
    return {"id": version.id, "version_name": version.version_name}


@router.post("/admin/core-elements", dependencies=[Depends(require_admin)])
async def create_core_element(data: CoreElementCreate, db: AsyncSession = Depends(get_db)):
    ce = SyllabusCoreElement(**data.model_dump())
    db.add(ce)
    await db.commit()
    await db.refresh(ce)
    return {"id": ce.id, "name": ce.name}


@router.post("/admin/topics", dependencies=[Depends(require_admin)])
async def create_topic(data: TopicCreate, db: AsyncSession = Depends(get_db)):
    topic = SyllabusTopic(**data.model_dump())
    db.add(topic)
    await db.commit()
    await db.refresh(topic)
    return {"id": topic.id, "title": topic.title}


@router.put("/admin/topics/{topic_id}", dependencies=[Depends(require_admin)])
async def update_topic(topic_id: int, data: TopicUpdate, db: AsyncSession = Depends(get_db)):
    topic = (await db.execute(select(SyllabusTopic).where(SyllabusTopic.id == topic_id))).scalar_one_or_none()
    if not topic:
        raise HTTPException(404, "Topic not found")
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(topic, k, v)
    await db.commit()
    return {"ok": True}


@router.delete("/admin/topics/{topic_id}", dependencies=[Depends(require_admin)])
async def delete_topic(topic_id: int, db: AsyncSession = Depends(get_db)):
    topic = (await db.execute(select(SyllabusTopic).where(SyllabusTopic.id == topic_id))).scalar_one_or_none()
    if not topic:
        raise HTTPException(404, "Topic not found")
    await db.delete(topic)
    await db.commit()
    return {"ok": True}


@router.post("/admin/subtopics", dependencies=[Depends(require_admin)])
async def create_subtopic(data: SubtopicCreate, db: AsyncSession = Depends(get_db)):
    sub = SyllabusSubtopic(**data.model_dump())
    db.add(sub)
    await db.commit()
    await db.refresh(sub)
    return {"id": sub.id, "title": sub.title}


@router.put("/admin/subtopics/{sub_id}", dependencies=[Depends(require_admin)])
async def update_subtopic(sub_id: int, data: SubtopicUpdate, db: AsyncSession = Depends(get_db)):
    sub = (await db.execute(select(SyllabusSubtopic).where(SyllabusSubtopic.id == sub_id))).scalar_one_or_none()
    if not sub:
        raise HTTPException(404, "Subtopic not found")
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(sub, k, v)
    await db.commit()
    return {"ok": True}


@router.delete("/admin/subtopics/{sub_id}", dependencies=[Depends(require_admin)])
async def delete_subtopic(sub_id: int, db: AsyncSession = Depends(get_db)):
    sub = (await db.execute(select(SyllabusSubtopic).where(SyllabusSubtopic.id == sub_id))).scalar_one_or_none()
    if not sub:
        raise HTTPException(404, "Subtopic not found")
    await db.delete(sub)
    await db.commit()
    return {"ok": True}


@router.post("/admin/learning-objectives", dependencies=[Depends(require_admin)])
async def create_learning_objective(data: LOCreate, db: AsyncSession = Depends(get_db)):
    lo = SyllabusLearningObjective(**data.model_dump())
    db.add(lo)
    await db.commit()
    await db.refresh(lo)
    return {"id": lo.id, "objective": lo.objective}


@router.put("/admin/learning-objectives/{lo_id}", dependencies=[Depends(require_admin)])
async def update_learning_objective(lo_id: int, data: LOUpdate, db: AsyncSession = Depends(get_db)):
    lo = (
        await db.execute(select(SyllabusLearningObjective).where(SyllabusLearningObjective.id == lo_id))
    ).scalar_one_or_none()
    if not lo:
        raise HTTPException(404, "Learning objective not found")
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(lo, k, v)
    await db.commit()
    return {"ok": True}


@router.delete("/admin/learning-objectives/{lo_id}", dependencies=[Depends(require_admin)])
async def delete_learning_objective(lo_id: int, db: AsyncSession = Depends(get_db)):
    lo = (
        await db.execute(select(SyllabusLearningObjective).where(SyllabusLearningObjective.id == lo_id))
    ).scalar_one_or_none()
    if not lo:
        raise HTTPException(404, "Learning objective not found")
    await db.delete(lo)
    await db.commit()
    return {"ok": True}


@router.post("/admin/resources", dependencies=[Depends(require_admin)])
async def create_resource(data: ResourceCreate, db: AsyncSession = Depends(get_db)):
    res = SyllabusResource(**data.model_dump())
    db.add(res)
    await db.commit()
    await db.refresh(res)
    return {"id": res.id}


@router.post("/admin/topics/reorder", dependencies=[Depends(require_admin)])
async def reorder_topics(data: ReorderRequest, db: AsyncSession = Depends(get_db)):
    for idx, tid in enumerate(data.ordered_ids):
        topic = (await db.execute(select(SyllabusTopic).where(SyllabusTopic.id == tid))).scalar_one_or_none()
        if topic:
            topic.order_index = idx
    await db.commit()
    return {"ok": True}


@router.post("/admin/subtopics/reorder", dependencies=[Depends(require_admin)])
async def reorder_subtopics(data: ReorderRequest, db: AsyncSession = Depends(get_db)):
    for idx, sid in enumerate(data.ordered_ids):
        sub = (await db.execute(select(SyllabusSubtopic).where(SyllabusSubtopic.id == sid))).scalar_one_or_none()
        if sub:
            sub.order_index = idx
    await db.commit()
    return {"ok": True}
