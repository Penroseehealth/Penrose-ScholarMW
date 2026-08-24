from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import User
from app.models.stem import (
    MasteryRecord,
    STEMAssessment,
    STEMConcept,
    STEMDiscipline,
    STEMSubject,
    STEMSubtopic,
    STEMTopic,
    STLearningMaterial,
    STLearningObjective,
    STPractice,
)


class SubjectResponse(BaseModel):
    id: int
    title: str
    slug: str
    description: str | None
    icon: str
    color: str
    discipline_count: int = 0


class DisciplineResponse(BaseModel):
    id: int
    title: str
    slug: str
    description: str | None
    subject_id: int
    topic_count: int = 0


class TopicResponse(BaseModel):
    id: int
    title: str
    description: str | None
    discipline_id: int
    difficulty_level: str
    order_index: int
    subtopic_count: int = 0


class SubtopicResponse(BaseModel):
    id: int
    title: str
    description: str | None
    topic_id: int
    difficulty_level: str
    order_index: int
    concept_count: int = 0


class ConceptResponse(BaseModel):
    id: int
    title: str
    description: str | None
    learning_objectives_text: str | None
    prerequisites_text: str | None
    subtopic_id: int
    difficulty_level: str
    order_index: int


class LearningObjectiveResponse(BaseModel):
    id: int
    title: str
    description: str | None
    bloom_level: str
    concept_id: int


class LearningMaterialResponse(BaseModel):
    id: int
    title: str
    content: str | None
    material_type: str
    duration_minutes: int | None
    concept_id: int


class PracticeResponse(BaseModel):
    id: int
    title: str
    question_text: str
    question_type: str
    options: str | None
    answer: str | None
    explanation: str | None
    difficulty: str
    marks: int
    concept_id: int


class MasteryResponse(BaseModel):
    id: int
    user_id: int
    concept_id: int
    mastery_level: float
    attempts: int
    correct: int
    last_practiced: datetime | None
    next_review: datetime | None


class MasteryCreateRequest(BaseModel):
    concept_id: int
    correct: bool
    time_spent_seconds: int | None = None


class AssessmentResponse(BaseModel):
    id: int
    title: str
    description: str | None
    assessment_type: str
    total_marks: int
    duration_minutes: int | None
    is_published: bool


class AssessmentQuestionResponse(BaseModel):
    id: int
    assessment_id: int
    practice_id: int
    order_index: int
    marks: int


class TreeDisciplineResponse(BaseModel):
    id: int
    title: str
    slug: str
    description: str | None
    order_index: int
    topics: list["TreeTopicResponse"] = []


class TreeTopicResponse(BaseModel):
    id: int
    title: str
    description: str | None
    difficulty_level: str
    order_index: int


class TreeSubjectResponse(BaseModel):
    id: int
    title: str
    slug: str
    description: str | None
    icon: str
    color: str
    disciplines: list[TreeDisciplineResponse] = []


class SearchItem(BaseModel):
    type: str
    id: int
    title: str
    description: str | None
    parent_title: str | None = None


class StatsResponse(BaseModel):
    total_concepts: int
    mastered_concepts: int
    in_progress_concepts: int
    not_started_concepts: int
    total_attempts: int
    total_correct: int
    average_mastery: float
    streak_days: int
    concepts_due_for_review: int


router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])


def _subject_to_response(subject: STEMSubject, discipline_count: int = 0) -> SubjectResponse:
    return SubjectResponse(
        id=subject.id,
        title=subject.title,
        slug=subject.subject_slug,
        description=subject.description,
        icon=getattr(subject, "icon", "") or "",
        color=getattr(subject, "color", "") or "",
        discipline_count=discipline_count,
    )


def _discipline_to_response(discipline: STEMDiscipline, topic_count: int = 0) -> DisciplineResponse:
    return DisciplineResponse(
        id=discipline.id,
        title=discipline.title,
        slug=discipline.discipline_slug,
        description=discipline.description,
        subject_id=discipline.subject_id,
        topic_count=topic_count,
    )


def _topic_to_response(topic: STEMTopic, subtopic_count: int = 0) -> TopicResponse:
    return TopicResponse(
        id=topic.id,
        title=topic.title,
        description=topic.description,
        discipline_id=topic.discipline_id,
        difficulty_level=topic.difficulty_level,
        order_index=topic.order_index,
        subtopic_count=subtopic_count,
    )


def _subtopic_to_response(subtopic: STEMSubtopic, concept_count: int = 0) -> SubtopicResponse:
    return SubtopicResponse(
        id=subtopic.id,
        title=subtopic.title,
        description=subtopic.description,
        topic_id=subtopic.topic_id,
        difficulty_level=subtopic.difficulty_level,
        order_index=subtopic.order_index,
        concept_count=concept_count,
    )


def _concept_to_response(concept: STEMConcept) -> ConceptResponse:
    return ConceptResponse(
        id=concept.id,
        title=concept.title,
        description=concept.description,
        learning_objectives_text=concept.learning_objectives_text,
        prerequisites_text=concept.prerequisites_text,
        subtopic_id=concept.subtopic_id,
        difficulty_level=concept.difficulty_level,
        order_index=concept.order_index,
    )


def _mastery_to_response(record: MasteryRecord) -> MasteryResponse:
    return MasteryResponse(
        id=record.id,
        user_id=record.user_id,
        concept_id=record.concept_id,
        mastery_level=record.mastery_level,
        attempts=record.attempts,
        correct=record.correct,
        last_practiced=record.last_practiced,
        next_review=record.next_review,
    )


def _compute_next_review(
    mastery_level: float,
    attempts: int = 1,
    previous_interval_days: float | None = None,
) -> datetime:
    """SM-2-inspired spaced repetition scheduler.

    Maps mastery_level to a quality score (0-5) and computes next review interval.
    """
    if mastery_level >= 0.9:
        quality = 5
    elif mastery_level >= 0.8:
        quality = 4
    elif mastery_level >= 0.6:
        quality = 3
    elif mastery_level >= 0.4:
        quality = 2
    elif mastery_level >= 0.2:
        quality = 1
    else:
        quality = 0

    ease_factor = max(1.3, 2.5 + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)))

    if quality < 3:
        interval_days = 1.0
    elif previous_interval_days is None:
        if attempts <= 1:
            interval_days = 1.0
        elif attempts == 2:
            interval_days = 6.0
        else:
            interval_days = max(previous_interval_days or 1.0, 6.0) * ease_factor
            interval_days = min(interval_days, 365.0)
    else:
        interval_days = previous_interval_days * ease_factor
        interval_days = min(max(interval_days, 1.0), 365.0)

    return datetime.now(timezone.utc) + timedelta(days=interval_days)


@router.get("/subjects", response_model=list[SubjectResponse])
async def list_subjects(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(STEMSubject).order_by(STEMSubject.id))
    subjects = result.scalars().all()
    responses = []
    for subject in subjects:
        count_result = await db.execute(select(func.count()).where(STEMDiscipline.subject_id == subject.id))
        discipline_count = count_result.scalar() or 0
        responses.append(_subject_to_response(subject, discipline_count))
    return responses


class SubjectModuleResponse(BaseModel):
    slug: str
    title: str
    description: str | None
    icon: str | None
    color: str | None
    features: list[str]


@router.get("/subjects/modules", response_model=list[SubjectModuleResponse])
async def get_subject_modules():
    from app.core.subject_registry import get_enabled_subjects

    return [
        SubjectModuleResponse(
            slug=m.slug,
            title=m.title,
            description=m.description,
            icon=m.icon,
            color=m.color,
            features=m.features,
        )
        for m in get_enabled_subjects()
    ]


@router.get("/subjects/{slug}", response_model=SubjectResponse)
async def get_subject(slug: str, db: AsyncSession = Depends(get_db)):
    from app.stem.slug_utils import resolve_slug

    slug = resolve_slug(slug)
    result = await db.execute(select(STEMSubject).where(STEMSubject.subject_slug == slug))
    subject = result.scalar_one_or_none()
    if not subject:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Subject not found")
    count_result = await db.execute(select(func.count()).where(STEMDiscipline.subject_id == subject.id))
    discipline_count = count_result.scalar() or 0
    return _subject_to_response(subject, discipline_count)


@router.get("/subjects/{slug}/disciplines", response_model=list[DisciplineResponse])
async def list_disciplines_for_subject(slug: str, db: AsyncSession = Depends(get_db)):
    from app.stem.slug_utils import resolve_slug

    slug = resolve_slug(slug)
    subject_result = await db.execute(select(STEMSubject).where(STEMSubject.subject_slug == slug))
    subject = subject_result.scalar_one_or_none()
    if not subject:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Subject not found")
    result = await db.execute(
        select(STEMDiscipline).where(STEMDiscipline.subject_id == subject.id).order_by(STEMDiscipline.order_index)
    )
    disciplines = result.scalars().all()
    responses = []
    for disc in disciplines:
        count_result = await db.execute(select(func.count()).where(STEMTopic.discipline_id == disc.id))
        topic_count = count_result.scalar() or 0
        responses.append(_discipline_to_response(disc, topic_count))
    return responses


@router.get("/disciplines/{id}", response_model=DisciplineResponse)
async def get_discipline(id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(STEMDiscipline).where(STEMDiscipline.id == id))
    discipline = result.scalar_one_or_none()
    if not discipline:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Discipline not found")
    count_result = await db.execute(select(func.count()).where(STEMTopic.discipline_id == discipline.id))
    topic_count = count_result.scalar() or 0
    return _discipline_to_response(discipline, topic_count)


@router.get("/disciplines/{id}/topics", response_model=list[TopicResponse])
async def list_topics_for_discipline(id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(STEMTopic).where(STEMTopic.discipline_id == id).order_by(STEMTopic.order_index))
    topics = result.scalars().all()
    responses = []
    for topic in topics:
        count_result = await db.execute(select(func.count()).where(STEMSubtopic.topic_id == topic.id))
        subtopic_count = count_result.scalar() or 0
        responses.append(_topic_to_response(topic, subtopic_count))
    return responses


@router.get("/topics/{id}", response_model=TopicResponse)
async def get_topic(id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(STEMTopic).where(STEMTopic.id == id))
    topic = result.scalar_one_or_none()
    if not topic:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Topic not found")
    count_result = await db.execute(select(func.count()).where(STEMSubtopic.topic_id == topic.id))
    subtopic_count = count_result.scalar() or 0
    return _topic_to_response(topic, subtopic_count)


@router.get("/topics/{id}/subtopics", response_model=list[SubtopicResponse])
async def list_subtopics_for_topic(id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(STEMSubtopic).where(STEMSubtopic.topic_id == id).order_by(STEMSubtopic.order_index)
    )
    subtopics = result.scalars().all()
    responses = []
    for sub in subtopics:
        count_result = await db.execute(select(func.count()).where(STEMConcept.subtopic_id == sub.id))
        concept_count = count_result.scalar() or 0
        responses.append(_subtopic_to_response(sub, concept_count))
    return responses


@router.get("/subtopics/{id}", response_model=SubtopicResponse)
async def get_subtopic(id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(STEMSubtopic).where(STEMSubtopic.id == id))
    subtopic = result.scalar_one_or_none()
    if not subtopic:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Subtopic not found")
    count_result = await db.execute(select(func.count()).where(STEMConcept.subtopic_id == subtopic.id))
    concept_count = count_result.scalar() or 0
    return _subtopic_to_response(subtopic, concept_count)


@router.get("/subtopics/{id}/concepts", response_model=list[ConceptResponse])
async def list_concepts_for_subtopic(id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(STEMConcept).where(STEMConcept.subtopic_id == id).order_by(STEMConcept.order_index)
    )
    return [_concept_to_response(c) for c in result.scalars().all()]


@router.get("/concepts/{id}", response_model=ConceptResponse)
async def get_concept(id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(STEMConcept).where(STEMConcept.id == id))
    concept = result.scalar_one_or_none()
    if not concept:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Concept not found")
    return _concept_to_response(concept)


@router.get("/concepts/{id}/objectives", response_model=list[LearningObjectiveResponse])
async def list_objectives_for_concept(id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(STLearningObjective)
        .where(STLearningObjective.concept_id == id)
        .order_by(STLearningObjective.order_index)
    )
    return [
        LearningObjectiveResponse(
            id=o.id,
            title=o.title,
            description=o.description,
            bloom_level=o.bloom_level,
            concept_id=o.concept_id,
        )
        for o in result.scalars().all()
    ]


@router.get("/concepts/{id}/materials", response_model=list[LearningMaterialResponse])
async def list_materials_for_concept(id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(STLearningMaterial).where(STLearningMaterial.concept_id == id).order_by(STLearningMaterial.order_index)
    )
    return [
        LearningMaterialResponse(
            id=m.id,
            title=m.title,
            content=m.content,
            material_type=m.material_type,
            duration_minutes=m.duration_minutes,
            concept_id=m.concept_id,
        )
        for m in result.scalars().all()
    ]


@router.get("/concepts/{id}/practices", response_model=list[PracticeResponse])
async def list_practices_for_concept(id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(STPractice).where(STPractice.concept_id == id).order_by(STPractice.order_index))
    return [
        PracticeResponse(
            id=p.id,
            title=p.title,
            question_text=p.question_text,
            question_type=p.question_type,
            options=p.options,
            answer=p.answer,
            explanation=p.explanation,
            difficulty=p.difficulty,
            marks=p.marks,
            concept_id=p.concept_id,
        )
        for p in result.scalars().all()
    ]


@router.get("/tree", response_model=list[TreeSubjectResponse])
async def get_full_tree(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(STEMSubject)
        .options(joinedload(STEMSubject.disciplines).joinedload(STEMDiscipline.topics))
        .order_by(STEMSubject.id)
    )
    subjects = result.unique().scalars().all()
    return [
        TreeSubjectResponse(
            id=subject.id,
            title=subject.title,
            slug=subject.subject_slug,
            description=subject.description,
            icon=getattr(subject, "icon", "") or "",
            color=getattr(subject, "color", "") or "",
            disciplines=[
                TreeDisciplineResponse(
                    id=disc.id,
                    title=disc.title,
                    slug=disc.discipline_slug,
                    description=disc.description,
                    order_index=disc.order_index,
                    topics=[
                        TreeTopicResponse(
                            id=t.id,
                            title=t.title,
                            description=t.description,
                            difficulty_level=t.difficulty_level,
                            order_index=t.order_index,
                        )
                        for t in sorted(disc.topics, key=lambda x: x.order_index)
                    ],
                )
                for disc in sorted(subject.disciplines, key=lambda x: x.order_index)
            ],
        )
        for subject in subjects
    ]


@router.get("/tree/{subject_slug}", response_model=TreeSubjectResponse)
async def get_subject_tree(subject_slug: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(STEMSubject)
        .where(STEMSubject.subject_slug == subject_slug)
        .options(joinedload(STEMSubject.disciplines).joinedload(STEMDiscipline.topics))
    )
    subject = result.unique().scalar_one_or_none()
    if not subject:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Subject not found")
    return TreeSubjectResponse(
        id=subject.id,
        title=subject.title,
        slug=subject.subject_slug,
        description=subject.description,
        icon=getattr(subject, "icon", "") or "",
        color=getattr(subject, "color", "") or "",
        disciplines=[
            TreeDisciplineResponse(
                id=disc.id,
                title=disc.title,
                slug=disc.discipline_slug,
                description=disc.description,
                order_index=disc.order_index,
                topics=[
                    TreeTopicResponse(
                        id=t.id,
                        title=t.title,
                        description=t.description,
                        difficulty_level=t.difficulty_level,
                        order_index=t.order_index,
                    )
                    for t in sorted(disc.topics, key=lambda x: x.order_index)
                ],
            )
            for disc in sorted(subject.disciplines, key=lambda x: x.order_index)
        ],
    )


@router.get("/search", response_model=list[SearchItem])
async def search_stem(
    q: str = Query(..., min_length=1),
    db: AsyncSession = Depends(get_db),
):
    items: list[SearchItem] = []

    concept_result = await db.execute(
        select(STEMConcept).where(STEMConcept.title.ilike(f"%{q}%") | STEMConcept.description.ilike(f"%{q}%"))
    )
    for concept in concept_result.scalars().all():
        subtopic_result = await db.execute(select(STEMSubtopic).where(STEMSubtopic.id == concept.subtopic_id))
        subtopic = subtopic_result.scalar_one_or_none()
        items.append(
            SearchItem(
                type="concept",
                id=concept.id,
                title=concept.title,
                description=concept.description,
                parent_title=subtopic.title if subtopic else None,
            )
        )

    material_result = await db.execute(
        select(STLearningMaterial).where(
            STLearningMaterial.title.ilike(f"%{q}%") | STLearningMaterial.content.ilike(f"%{q}%")
        )
    )
    for material in material_result.scalars().all():
        concept_result_inner = await db.execute(select(STEMConcept).where(STEMConcept.id == material.concept_id))
        parent_concept = concept_result_inner.scalar_one_or_none()
        items.append(
            SearchItem(
                type="material",
                id=material.id,
                title=material.title,
                description=material.content[:200] if material.content else None,
                parent_title=parent_concept.title if parent_concept else None,
            )
        )

    practice_result = await db.execute(
        select(STPractice).where(STPractice.title.ilike(f"%{q}%") | STPractice.question_text.ilike(f"%{q}%"))
    )
    for practice in practice_result.scalars().all():
        concept_result_inner = await db.execute(select(STEMConcept).where(STEMConcept.id == practice.concept_id))
        parent_concept = concept_result_inner.scalar_one_or_none()
        items.append(
            SearchItem(
                type="practice",
                id=practice.id,
                title=practice.title,
                description=practice.question_text[:200] if practice.question_text else None,
                parent_title=parent_concept.title if parent_concept else None,
            )
        )

    return items


@router.get("/mastery/me", response_model=list[MasteryResponse])
async def get_my_mastery(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MasteryRecord)
        .where(MasteryRecord.user_id == user.id)
        .order_by(MasteryRecord.last_practiced.desc().nullslast())
    )
    return [_mastery_to_response(r) for r in result.scalars().all()]


@router.post("/mastery", response_model=MasteryResponse, status_code=status.HTTP_201_CREATED)
async def record_mastery(
    body: MasteryCreateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    concept_result = await db.execute(select(STEMConcept).where(STEMConcept.id == body.concept_id))
    if not concept_result.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Concept not found")

    existing_result = await db.execute(
        select(MasteryRecord).where(
            MasteryRecord.user_id == user.id,
            MasteryRecord.concept_id == body.concept_id,
        )
    )
    record = existing_result.scalar_one_or_none()
    now = datetime.now(timezone.utc)

    if record:
        record.attempts += 1
        if body.correct:
            record.correct += 1
        record.mastery_level = record.correct / record.attempts if record.attempts > 0 else 0.0
        record.last_practiced = now
        record.next_review = _compute_next_review(record.mastery_level)
    else:
        record = MasteryRecord(
            user_id=user.id,
            concept_id=body.concept_id,
            mastery_level=1.0 if body.correct else 0.0,
            attempts=1,
            correct=1 if body.correct else 0,
            last_practiced=now,
            next_review=_compute_next_review(1.0 if body.correct else 0.0),
        )
        db.add(record)

    await db.commit()
    await db.refresh(record)
    return _mastery_to_response(record)


@router.get("/assessments/{id}")
async def get_assessment(id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(STEMAssessment).options(joinedload(STEMAssessment.questions)).where(STEMAssessment.id == id)
    )
    assessment = result.unique().scalar_one_or_none()
    if not assessment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assessment not found")
    return {
        "assessment": AssessmentResponse(
            id=assessment.id,
            title=assessment.title,
            description=assessment.description,
            assessment_type=assessment.assessment_type,
            total_marks=assessment.total_marks,
            duration_minutes=assessment.duration_minutes,
            is_published=assessment.is_published,
        ),
        "questions": [
            AssessmentQuestionResponse(
                id=q.id,
                assessment_id=q.assessment_id,
                practice_id=q.practice_id,
                order_index=q.order_index,
                marks=q.marks,
            )
            for q in sorted(assessment.questions, key=lambda x: x.order_index)
        ],
    }


@router.get("/stats", response_model=StatsResponse)
async def get_stem_stats(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    total_result = await db.execute(select(func.count()).select_from(STEMConcept))
    total_concepts = total_result.scalar() or 0

    mastery_result = await db.execute(select(MasteryRecord).where(MasteryRecord.user_id == user.id))
    records = mastery_result.scalars().all()

    mastered = sum(1 for r in records if r.mastery_level >= 0.8)
    in_progress = sum(1 for r in records if 0 < r.mastery_level < 0.8)
    not_started = total_concepts - len(records)

    total_attempts = sum(r.attempts for r in records)
    total_correct = sum(r.correct for r in records)
    average_mastery = sum(r.mastery_level for r in records) / len(records) if records else 0.0

    now = datetime.now(timezone.utc)
    concepts_due = sum(1 for r in records if r.next_review and r.next_review <= now)

    streak_days = 0
    if records:
        practiced_dates = set()
        for r in records:
            if r.last_practiced:
                practiced_dates.add(r.last_practiced.date())
        check_date = now.date()
        while check_date in practiced_dates:
            streak_days += 1
            check_date -= timedelta(days=1)

    return StatsResponse(
        total_concepts=total_concepts,
        mastered_concepts=mastered,
        in_progress_concepts=in_progress,
        not_started_concepts=not_started,
        total_attempts=total_attempts,
        total_correct=total_correct,
        average_mastery=average_mastery,
        streak_days=streak_days,
        concepts_due_for_review=concepts_due,
    )
