from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import User
from app.models.stem import (
    MasteryRecord,
    STEMConcept,
    STEMDiscipline,
    STEMSubject,
    STEMSubtopic,
    STEMTopic,
)

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])


class DueReviewItem(BaseModel):
    concept_id: int
    concept_title: str
    subject_title: str | None
    topic_title: str | None
    mastery_level: float
    attempts: int
    next_review: datetime


class LearningPathStep(BaseModel):
    step_number: int
    concept_id: int
    concept_title: str
    topic_title: str | None
    discipline_title: str | None
    mastery_level: float
    status: str
    estimated_minutes: int
    priority: str


class LearningPathResponse(BaseModel):
    subject_title: str
    subject_slug: str
    total_steps: int
    completed_steps: int
    in_progress_steps: int
    not_started_steps: int
    estimated_total_minutes: int
    steps: list[LearningPathStep]


@router.get(
    "/adaptive/due-reviews",
    response_model=list[DueReviewItem],
)
async def get_due_reviews(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    now = datetime.now(timezone.utc)
    result = await db.execute(
        select(MasteryRecord).where(
            MasteryRecord.user_id == user.id,
            MasteryRecord.next_review.isnot(None),
            MasteryRecord.next_review <= now,
        )
    )
    records = result.scalars().all()
    items: list[DueReviewItem] = []
    for r in records:
        concept_result = await db.execute(
            select(
                STEMConcept.id.label("concept_id"),
                STEMConcept.title.label("concept_title"),
                STEMTopic.title.label("topic_title"),
                STEMSubject.title.label("subject_title"),
            )
            .join(STEMSubtopic, STEMSubtopic.id == STEMConcept.subtopic_id)
            .join(STEMTopic, STEMTopic.id == STEMSubtopic.topic_id)
            .join(STEMDiscipline, STEMDiscipline.id == STEMTopic.discipline_id)
            .join(STEMSubject, STEMSubject.id == STEMDiscipline.subject_id)
            .where(STEMConcept.id == r.concept_id)
        )
        row = concept_result.first()
        if not row:
            continue
        items.append(
            DueReviewItem(
                concept_id=row.concept_id,
                concept_title=row.concept_title,
                subject_title=row.subject_title,
                topic_title=row.topic_title,
                mastery_level=r.mastery_level,
                attempts=r.attempts,
                next_review=r.next_review,
            )
        )
    items.sort(key=lambda x: x.next_review)
    return items


@router.get(
    "/adaptive/learning-path/{slug}",
    response_model=LearningPathResponse,
)
async def get_learning_path(
    slug: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    subject_result = await db.execute(select(STEMSubject).where(STEMSubject.subject_slug == slug))
    subject = subject_result.scalar_one_or_none()
    if not subject:
        return LearningPathResponse(
            subject_title="Unknown",
            subject_slug=slug,
            total_steps=0,
            completed_steps=0,
            in_progress_steps=0,
            not_started_steps=0,
            estimated_total_minutes=0,
            steps=[],
        )

    hierarchy_result = await db.execute(
        select(
            STEMConcept.id.label("concept_id"),
            STEMConcept.title.label("concept_title"),
            STEMConcept.difficulty_level,
            STEMSubtopic.title.label("topic_title"),
            STEMDiscipline.title.label("discipline_title"),
        )
        .join(STEMSubtopic, STEMSubtopic.id == STEMConcept.subtopic_id)
        .join(STEMTopic, STEMTopic.id == STEMSubtopic.topic_id)
        .join(STEMDiscipline, STEMDiscipline.id == STEMTopic.discipline_id)
        .where(STEMDiscipline.subject_id == subject.id)
    )
    hierarchy = hierarchy_result.all()

    concept_ids = [row.concept_id for row in hierarchy]

    mastery_result = await db.execute(
        select(MasteryRecord).where(
            MasteryRecord.user_id == user.id,
            MasteryRecord.concept_id.in_(concept_ids),
        )
    )
    mastery_map = {r.concept_id: r for r in mastery_result.scalars().all()}

    _DIFFICULTY_MINUTES = {
        "beginner": 10,
        "intermediate": 15,
        "advanced": 20,
    }

    steps: list[LearningPathStep] = []
    for i, row in enumerate(hierarchy, 1):
        record = mastery_map.get(row.concept_id)
        mastery = record.mastery_level if record else 0.0

        if mastery >= 0.8:
            status = "completed"
            priority = "none"
        elif mastery > 0:
            status = "in_progress"
            priority = "high" if mastery < 0.4 else "medium"
        else:
            status = "not_started"
            priority = "high" if row.difficulty_level == "beginner" else "medium"

        est = _DIFFICULTY_MINUTES.get(row.difficulty_level, 15)
        if status == "completed":
            est = max(3, est // 3)

        steps.append(
            LearningPathStep(
                step_number=i,
                concept_id=row.concept_id,
                concept_title=row.concept_title,
                topic_title=row.topic_title,
                discipline_title=row.discipline_title,
                mastery_level=round(mastery, 4),
                status=status,
                estimated_minutes=est,
                priority=priority,
            )
        )

    not_started = sum(1 for s in steps if s.status == "not_started")
    in_progress = sum(1 for s in steps if s.status == "in_progress")
    completed = sum(1 for s in steps if s.status == "completed")
    total_minutes = sum(s.estimated_minutes for s in steps if s.status != "completed")

    return LearningPathResponse(
        subject_title=subject.title,
        subject_slug=subject.subject_slug,
        total_steps=len(steps),
        completed_steps=completed,
        in_progress_steps=in_progress,
        not_started_steps=not_started,
        estimated_total_minutes=total_minutes,
        steps=steps,
    )


@router.get(
    "/adaptive/study-schedule",
    response_model=list[LearningPathStep],
)
async def get_study_schedule(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    now = datetime.utcnow()

    due_result = await db.execute(
        select(MasteryRecord).where(
            MasteryRecord.user_id == user.id,
            MasteryRecord.next_review.isnot(None),
            MasteryRecord.next_review <= now + timedelta(days=7),
        )
    )
    due_records = due_result.scalars().all()

    items: list[LearningPathStep] = []
    for r in due_records:
        concept_result = await db.execute(
            select(
                STEMConcept.id.label("concept_id"),
                STEMConcept.title.label("concept_title"),
                STEMTopic.title.label("topic_title"),
                STEMDiscipline.title.label("discipline_title"),
            )
            .join(STEMSubtopic, STEMSubtopic.id == STEMConcept.subtopic_id)
            .join(STEMTopic, STEMTopic.id == STEMSubtopic.topic_id)
            .join(STEMDiscipline, STEMDiscipline.id == STEMTopic.discipline_id)
            .where(STEMConcept.id == r.concept_id)
        )
        row = concept_result.first()
        if not row:
            continue
        est = 10 if r.mastery_level >= 0.8 else (15 if r.mastery_level >= 0.4 else 20)
        overdue = r.next_review <= now
        items.append(
            LearningPathStep(
                step_number=0,
                concept_id=row.concept_id,
                concept_title=row.concept_title,
                topic_title=row.topic_title,
                discipline_title=row.discipline_title,
                mastery_level=round(r.mastery_level, 4),
                status="due" if overdue else "upcoming",
                estimated_minutes=est,
                priority="urgent" if overdue else "high",
            )
        )

    items.sort(key=lambda x: x.priority)
    for i, item in enumerate(items, 1):
        item.step_number = i

    return items
