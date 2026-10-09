from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database.engine import get_db
from app.models.stem import (
    STEMConcept,
    STEMCurriculumAlignment,
    STEMDiscipline,
    STEMMalawiExample,
    STEMSubject,
    STEMSubtopic,
    STEMTopic,
)

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])


class MalawiExampleResponse(BaseModel):
    id: int
    concept_id: int
    title: str
    description: str
    local_context: str | None
    region: str | None
    real_world_application: str | None
    is_published: bool
    concept_title: str | None = None


class CurriculumAlignmentResponse(BaseModel):
    id: int
    concept_id: int
    curriculum_name: str
    syllabus_code: str | None
    form_level: str | None
    exam_board: str | None
    learning_outcome: str | None
    concept_title: str | None = None


class SubjectOverviewResponse(BaseModel):
    subject_slug: str
    subject_title: str
    form_levels: list["FormLevelGroup"]


class FormLevelGroup(BaseModel):
    form_level: str
    alignments: list[CurriculumAlignmentResponse]


class MalawiStatsResponse(BaseModel):
    total_examples: int
    total_alignments: int
    subjects_covered: int


def _example_to_response(e: STEMMalawiExample) -> MalawiExampleResponse:
    return MalawiExampleResponse(
        id=e.id,
        concept_id=e.concept_id,
        title=e.title,
        description=e.description,
        local_context=e.local_context,
        region=e.region,
        real_world_application=e.real_world_application,
        is_published=e.is_published,
        concept_title=e.concept.title if e.concept else None,
    )


def _alignment_to_response(a: STEMCurriculumAlignment) -> CurriculumAlignmentResponse:
    return CurriculumAlignmentResponse(
        id=a.id,
        concept_id=a.concept_id,
        curriculum_name=a.curriculum_name,
        syllabus_code=a.syllabus_code,
        form_level=a.form_level,
        exam_board=a.exam_board,
        learning_outcome=a.learning_outcome,
        concept_title=a.concept.title if a.concept else None,
    )


@router.get("/malawi/examples", response_model=list[MalawiExampleResponse])
async def list_malawi_examples(
    concept_id: int | None = Query(None),
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(STEMMalawiExample)
        .where(STEMMalawiExample.is_published.is_(True))
        .options(selectinload(STEMMalawiExample.concept))
    )
    if concept_id is not None:
        stmt = stmt.where(STEMMalawiExample.concept_id == concept_id)
    stmt = stmt.order_by(STEMMalawiExample.title)
    result = await db.execute(stmt)
    return [_example_to_response(e) for e in result.scalars().all()]


@router.get("/malawi/examples/{id}", response_model=MalawiExampleResponse)
async def get_malawi_example(id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(STEMMalawiExample)
        .where(STEMMalawiExample.id == id)
        .options(selectinload(STEMMalawiExample.concept))
    )
    example = result.scalar_one_or_none()
    if not example:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Malawi example not found"
        )
    return _example_to_response(example)


@router.get("/malawi/curriculum", response_model=list[CurriculumAlignmentResponse])
async def list_malawi_curriculum(
    concept_id: int | None = Query(None),
    form_level: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(STEMCurriculumAlignment).options(
        selectinload(STEMCurriculumAlignment.concept)
    )
    if concept_id is not None:
        stmt = stmt.where(STEMCurriculumAlignment.concept_id == concept_id)
    if form_level:
        stmt = stmt.where(STEMCurriculumAlignment.form_level == form_level)
    stmt = stmt.order_by(
        STEMCurriculumAlignment.form_level, STEMCurriculumAlignment.curriculum_name
    )
    result = await db.execute(stmt)
    return [_alignment_to_response(a) for a in result.scalars().all()]


@router.get("/malawi/subjects/{slug}", response_model=SubjectOverviewResponse)
async def get_malawi_subject_overview(slug: str, db: AsyncSession = Depends(get_db)):
    subject_result = await db.execute(
        select(STEMSubject).where(STEMSubject.subject_slug == slug)
    )
    subject = subject_result.scalar_one_or_none()
    if not subject:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Subject not found"
        )

    stmt = (
        select(STEMCurriculumAlignment)
        .options(selectinload(STEMCurriculumAlignment.concept))
        .join(STEMConcept, STEMCurriculumAlignment.concept_id == STEMConcept.id)
        .join(STEMSubtopic, STEMConcept.subtopic_id == STEMSubtopic.id)
        .join(STEMTopic, STEMSubtopic.topic_id == STEMTopic.id)
        .join(STEMDiscipline, STEMTopic.discipline_id == STEMDiscipline.id)
        .where(STEMDiscipline.subject_id == subject.id)
        .order_by(
            STEMCurriculumAlignment.form_level, STEMCurriculumAlignment.curriculum_name
        )
    )
    result = await db.execute(stmt)
    alignments = [_alignment_to_response(a) for a in result.scalars().all()]

    grouped: dict[str, list[CurriculumAlignmentResponse]] = {}
    for alignment in alignments:
        level = alignment.form_level or "General"
        grouped.setdefault(level, []).append(alignment)

    return SubjectOverviewResponse(
        subject_slug=subject.subject_slug,
        subject_title=subject.title,
        form_levels=[
            FormLevelGroup(form_level=level, alignments=items)
            for level, items in sorted(grouped.items())
        ],
    )


@router.get("/malawi/stats", response_model=MalawiStatsResponse)
async def get_malawi_stats(db: AsyncSession = Depends(get_db)):
    examples_count = await db.execute(
        select(func.count())
        .select_from(STEMMalawiExample)
        .where(STEMMalawiExample.is_published.is_(True))
    )
    total_examples = examples_count.scalar_one()

    alignments_count = await db.execute(
        select(func.count()).select_from(STEMCurriculumAlignment)
    )
    total_alignments = alignments_count.scalar_one()

    subjects_count = await db.execute(
        select(func.count(func.distinct(STEMDiscipline.subject_id)))
        .select_from(STEMCurriculumAlignment)
        .join(STEMConcept, STEMCurriculumAlignment.concept_id == STEMConcept.id)
        .join(STEMSubtopic, STEMConcept.subtopic_id == STEMSubtopic.id)
        .join(STEMTopic, STEMSubtopic.topic_id == STEMTopic.id)
        .join(STEMDiscipline, STEMTopic.discipline_id == STEMDiscipline.id)
    )
    subjects_covered = subjects_count.scalar_one()

    return MalawiStatsResponse(
        total_examples=total_examples,
        total_alignments=total_alignments,
        subjects_covered=subjects_covered,
    )
