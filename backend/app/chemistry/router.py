"""Malawi Chemistry Syllabus API — Form 1-4 CRUD + tree viewer."""

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

router = APIRouter(prefix="/chemistry/syllabus", tags=["Chemistry Syllabus"])

CHEM_SLUG = "chemistry"


# ── Public: tree by form level ───────────────────────────────────


@router.get("/tree")
async def get_chemistry_syllabus_tree(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(SyllabusSubject).where(SyllabusSubject.slug == CHEM_SLUG)
    )
    subject = result.scalar_one_or_none()
    if not subject:
        raise HTTPException(status_code=404, detail="Chemistry syllabus not found")

    ver_result = await db.execute(
        select(SyllabusVersion)
        .where(
            SyllabusVersion.subject_id == subject.id, SyllabusVersion.is_current == True
        )  # noqa: E712
        .options(joinedload(SyllabusVersion.core_elements))
    )
    version = ver_result.unique().scalar_one_or_none()
    if not version:
        return {"subject": {"name": subject.name, "slug": subject.slug}, "forms": {}}

    ce_result = await db.execute(
        select(SyllabusCoreElement)
        .where(SyllabusCoreElement.version_id == version.id)
        .options(
            joinedload(SyllabusCoreElement.topics)
            .joinedload(SyllabusTopic.subtopics)
            .joinedload(SyllabusSubtopic.learning_objectives),
            joinedload(SyllabusCoreElement.topics).joinedload(SyllabusTopic.resources),
        )
        .order_by(SyllabusCoreElement.order_index)
    )
    core_elements = ce_result.unique().scalars().all()

    forms = {}
    for ce in core_elements:
        for topic in ce.topics:
            form_key = f"Form {topic.year_level}"
            if form_key not in forms:
                forms[form_key] = {
                    "form": form_key,
                    "year_level": topic.year_level,
                    "themes": [],
                }
            theme_entry = next(
                (t for t in forms[form_key]["themes"] if t["name"] == ce.name),
                None,
            )
            if not theme_entry:
                theme_entry = {
                    "name": ce.name,
                    "number": ce.number,
                    "description": ce.description or "",
                    "topics": [],
                }
                forms[form_key]["themes"].append(theme_entry)

            topic_data = {
                "title": topic.title,
                "description": topic.description or "",
                "subtopics": [],
                "resources": [],
            }
            for sub in topic.subtopics:
                sub_data = {
                    "title": sub.title,
                    "description": sub.description or "",
                    "learning_objectives": [],
                }
                for lo in sub.learning_objectives:
                    sub_data["learning_objectives"].append(
                        {
                            "objective": lo.objective,
                            "description": lo.description or "",
                            "cognitive_level": lo.cognitive_level,
                            "teaching_activity": lo.teaching_activity or "",
                            "teaching_method": lo.teaching_method or "",
                        }
                    )
                topic_data["subtopics"].append(sub_data)
            for res in topic.resources:
                topic_data["resources"].append(
                    {"text": res.resource_text, "type": res.resource_type}
                )
            theme_entry["topics"].append(topic_data)

    return {
        "subject": {
            "name": subject.name,
            "slug": subject.slug,
            "icon": subject.icon,
            "color": subject.color,
        },
        "forms": list(forms.values()),
    }


@router.get("/tree/{form_number}")
async def get_chemistry_syllabus_tree_by_form(
    form_number: int, db: AsyncSession = Depends(get_db)
):
    if form_number not in (1, 2, 3, 4):
        raise HTTPException(status_code=400, detail="Form must be 1, 2, 3, or 4")

    result = await db.execute(
        select(SyllabusSubject).where(SyllabusSubject.slug == CHEM_SLUG)
    )
    subject = result.scalar_one_or_none()
    if not subject:
        raise HTTPException(status_code=404, detail="Chemistry syllabus not found")

    ver_result = await db.execute(
        select(SyllabusVersion).where(
            SyllabusVersion.subject_id == subject.id, SyllabusVersion.is_current == True
        )  # noqa: E712
    )
    version = ver_result.scalar_one_or_none()
    if not version:
        raise HTTPException(status_code=404, detail="No current version found")

    ce_result = await db.execute(
        select(SyllabusCoreElement)
        .where(SyllabusCoreElement.version_id == version.id)
        .options(
            joinedload(SyllabusCoreElement.topics)
            .joinedload(SyllabusTopic.subtopics)
            .joinedload(SyllabusSubtopic.learning_objectives),
            joinedload(SyllabusCoreElement.topics).joinedload(SyllabusTopic.resources),
        )
        .order_by(SyllabusCoreElement.order_index)
    )
    core_elements = ce_result.unique().scalars().all()

    themes = []
    for ce in core_elements:
        form_topics = [t for t in ce.topics if t.year_level == form_number]
        if not form_topics:
            continue
        theme_entry = {
            "name": ce.name,
            "number": ce.number,
            "description": ce.description or "",
            "topics": [],
        }
        for topic in form_topics:
            topic_data = {
                "title": topic.title,
                "description": topic.description or "",
                "subtopics": [],
                "resources": [],
            }
            for sub in topic.subtopics:
                sub_data = {
                    "title": sub.title,
                    "description": sub.description or "",
                    "learning_objectives": [],
                }
                for lo in sub.learning_objectives:
                    sub_data["learning_objectives"].append(
                        {
                            "objective": lo.objective,
                            "description": lo.description or "",
                            "cognitive_level": lo.cognitive_level,
                            "teaching_activity": lo.teaching_activity or "",
                            "teaching_method": lo.teaching_method or "",
                        }
                    )
                topic_data["subtopics"].append(sub_data)
            for res in topic.resources:
                topic_data["resources"].append(
                    {"text": res.resource_text, "type": res.resource_type}
                )
            theme_entry["topics"].append(topic_data)
        themes.append(theme_entry)

    return {
        "subject": {"name": subject.name, "slug": subject.slug},
        "form": form_number,
        "form_label": f"Form {form_number}",
        "themes": themes,
    }


# ── Admin: CRUD ──────────────────────────────────────────────────


class ChemSubjectCreate(BaseModel):
    name: str = "Chemistry"
    slug: str = CHEM_SLUG
    description: str | None = None
    icon: str | None = "science_rounded"
    color: str | None = "#F59E0B"


class ChemVersionCreate(BaseModel):
    version_name: str
    year_effective: int | None = None
    examination_board: str | None = None
    description: str | None = None


class ChemThemeCreate(BaseModel):
    number: int
    name: str
    description: str | None = None
    order_index: int = 0


class ChemTopicCreate(BaseModel):
    theme_id: int
    title: str
    description: str | None = None
    year_level: int
    order_index: int = 0


class ChemSubtopicCreate(BaseModel):
    topic_id: int
    title: str
    description: str | None = None
    order_index: int = 0


class ChemLOCreate(BaseModel):
    subtopic_id: int
    objective: str
    description: str | None = None
    cognitive_level: str = "Knowledge"
    teaching_activity: str | None = None
    teaching_method: str | None = None


class ChemResourceCreate(BaseModel):
    topic_id: int
    resource_text: str
    resource_type: str = "equipment"


@router.post("/admin/subject")
async def create_chem_subject(
    body: ChemSubjectCreate,
    db: AsyncSession = Depends(get_db),
    _admin=Depends(require_admin),
):
    existing = await db.execute(
        select(SyllabusSubject).where(SyllabusSubject.slug == body.slug)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Chemistry subject already exists")

    subject = SyllabusSubject(
        name=body.name,
        slug=body.slug,
        description=body.description,
        icon=body.icon,
        color=body.color,
    )
    db.add(subject)
    await db.commit()
    await db.refresh(subject)
    return {"id": subject.id, "name": subject.name, "slug": subject.slug}


@router.post("/admin/version")
async def create_chem_version(
    body: ChemVersionCreate,
    db: AsyncSession = Depends(get_db),
    _admin=Depends(require_admin),
):
    result = await db.execute(
        select(SyllabusSubject).where(SyllabusSubject.slug == CHEM_SLUG)
    )
    subject = result.scalar_one_or_none()
    if not subject:
        raise HTTPException(status_code=404, detail="Chemistry subject not found")

    version = SyllabusVersion(
        subject_id=subject.id,
        version_name=body.version_name,
        year_effective=body.year_effective,
        examination_board=body.examination_board,
        description=body.description,
    )
    db.add(version)
    await db.commit()
    await db.refresh(version)
    return {"id": version.id, "version_name": version.version_name}


@router.post("/admin/theme")
async def create_chem_theme(
    body: ChemThemeCreate,
    db: AsyncSession = Depends(get_db),
    _admin=Depends(require_admin),
):
    ver_result = await db.execute(
        select(SyllabusVersion)
        .join(SyllabusSubject)
        .where(SyllabusSubject.slug == CHEM_SLUG, SyllabusVersion.is_current == True)  # noqa: E712
    )
    version = ver_result.scalar_one_or_none()
    if not version:
        raise HTTPException(status_code=404, detail="No current version")

    ce = SyllabusCoreElement(
        version_id=version.id,
        number=body.number,
        name=body.name,
        description=body.description,
        order_index=body.order_index,
    )
    db.add(ce)
    await db.commit()
    await db.refresh(ce)
    return {"id": ce.id, "name": ce.name}


@router.post("/admin/topic")
async def create_chem_topic(
    body: ChemTopicCreate,
    db: AsyncSession = Depends(get_db),
    _admin=Depends(require_admin),
):
    topic = SyllabusTopic(
        core_element_id=body.theme_id,
        title=body.title,
        description=body.description,
        year_level=body.year_level,
        order_index=body.order_index,
    )
    db.add(topic)
    await db.commit()
    await db.refresh(topic)
    return {"id": topic.id, "title": topic.title}


@router.post("/admin/subtopic")
async def create_chem_subtopic(
    body: ChemSubtopicCreate,
    db: AsyncSession = Depends(get_db),
    _admin=Depends(require_admin),
):
    sub = SyllabusSubtopic(
        topic_id=body.topic_id,
        title=body.title,
        description=body.description,
        order_index=body.order_index,
    )
    db.add(sub)
    await db.commit()
    await db.refresh(sub)
    return {"id": sub.id, "title": sub.title}


@router.post("/admin/learning-objective")
async def create_chem_lo(
    body: ChemLOCreate,
    db: AsyncSession = Depends(get_db),
    _admin=Depends(require_admin),
):
    lo = SyllabusLearningObjective(
        subtopic_id=body.subtopic_id,
        objective=body.objective,
        description=body.description,
        cognitive_level=body.cognitive_level,
        teaching_activity=body.teaching_activity,
        teaching_method=body.teaching_method,
    )
    db.add(lo)
    await db.commit()
    await db.refresh(lo)
    return {"id": lo.id, "objective": lo.objective}


@router.post("/admin/resource")
async def create_chem_resource(
    body: ChemResourceCreate,
    db: AsyncSession = Depends(get_db),
    _admin=Depends(require_admin),
):
    res = SyllabusResource(
        topic_id=body.topic_id,
        resource_text=body.resource_text,
        resource_type=body.resource_type,
    )
    db.add(res)
    await db.commit()
    await db.refresh(res)
    return {"id": res.id, "resource_text": res.resource_text}


@router.get("/stats")
async def get_chemistry_syllabus_stats(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(SyllabusSubject).where(SyllabusSubject.slug == CHEM_SLUG)
    )
    subject = result.scalar_one_or_none()
    if not subject:
        return {
            "total_topics": 0,
            "total_subtopics": 0,
            "total_objectives": 0,
            "forms": {},
        }

    ver_result = await db.execute(
        select(SyllabusVersion).where(
            SyllabusVersion.subject_id == subject.id, SyllabusVersion.is_current == True
        )  # noqa: E712
    )
    version = ver_result.scalar_one_or_none()
    if not version:
        return {
            "total_topics": 0,
            "total_subtopics": 0,
            "total_objectives": 0,
            "forms": {},
        }

    topics_r = await db.execute(
        select(SyllabusTopic).where(
            SyllabusTopic.core_element_id.in_(
                select(SyllabusCoreElement.id).where(
                    SyllabusCoreElement.version_id == version.id
                )
            )
        )
    )
    topics = topics_r.scalars().all()
    form_counts = {}
    for t in topics:
        fk = f"Form {t.year_level}"
        form_counts[fk] = form_counts.get(fk, 0) + 1

    sub_r = await db.execute(
        select(SyllabusSubtopic).where(
            SyllabusSubtopic.topic_id.in_(
                select(SyllabusTopic.id).where(
                    SyllabusTopic.core_element_id.in_(
                        select(SyllabusCoreElement.id).where(
                            SyllabusCoreElement.version_id == version.id
                        )
                    )
                )
            )
        )
    )
    sub_count = len(sub_r.scalars().all())

    lo_r = await db.execute(
        select(SyllabusLearningObjective).where(
            SyllabusLearningObjective.subtopic_id.in_(
                select(SyllabusSubtopic.id).where(
                    SyllabusSubtopic.topic_id.in_(
                        select(SyllabusTopic.id).where(
                            SyllabusTopic.core_element_id.in_(
                                select(SyllabusCoreElement.id).where(
                                    SyllabusCoreElement.version_id == version.id
                                )
                            )
                        )
                    )
                )
            )
        )
    )
    lo_count = len(lo_r.scalars().all())

    return {
        "total_topics": len(topics),
        "total_subtopics": sub_count,
        "total_objectives": lo_count,
        "forms": form_counts,
    }
