from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.names import greeting_name
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
    STPractice,
)

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])


class CurrentLearning(BaseModel):
    concept_id: int
    concept_title: str
    mastery_level: float
    topic_title: str | None
    discipline_title: str | None
    subtopic_title: str | None
    last_practiced: datetime | None


class ProgressStats(BaseModel):
    overall_mastery: float
    current_topic_mastery: float
    course_completion: float
    assessment_average: float


class RecommendationItem(BaseModel):
    concept_id: int
    concept_title: str
    mastery_level: float
    reason: str
    topic_title: str | None


class RecentActivity(BaseModel):
    concept_id: int
    concept_title: str
    question_type: str | None
    marks: int | None
    mastery_level: float
    last_practiced: datetime | None


class SubjectDashboardResponse(BaseModel):
    subject_title: str
    subject_slug: str
    subject_icon: str | None
    subject_color: str | None
    subject_description: str | None
    greeting: str
    current_learning: CurrentLearning | None
    progress: ProgressStats
    recommendations: list[RecommendationItem]
    recent_activity: RecentActivity | None
    total_concepts: int
    mastered_concepts: int
    in_progress_concepts: int
    total_practice_attempts: int


def _build_greeting(user_full_name: str) -> str:
    hour = datetime.now().hour
    if hour < 12:
        time_of_day = "morning"
    elif hour < 17:
        time_of_day = "afternoon"
    else:
        time_of_day = "evening"
    return f"Good {time_of_day}, {greeting_name(user_full_name)}"


@router.get(
    "/subjects/{slug}/dashboard",
    response_model=SubjectDashboardResponse,
)
async def subject_dashboard(
    slug: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from app.stem.slug_utils import resolve_slug

    slug = resolve_slug(slug)
    subject_result = await db.execute(
        select(STEMSubject).where(STEMSubject.subject_slug == slug)
    )
    subject = subject_result.scalar_one_or_none()
    if not subject:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Subject not found",
        )

    concepts_result = await db.execute(
        select(STEMConcept)
        .join(STEMSubtopic, STEMSubtopic.id == STEMConcept.subtopic_id)
        .join(STEMTopic, STEMTopic.id == STEMSubtopic.topic_id)
        .join(STEMDiscipline, STEMDiscipline.id == STEMTopic.discipline_id)
        .where(STEMDiscipline.subject_id == subject.id)
    )
    concepts = concepts_result.scalars().all()
    concept_ids = [c.id for c in concepts]
    concepts_by_id = {c.id: c for c in concepts}

    total_concepts = len(concept_ids)

    if not concept_ids:
        return SubjectDashboardResponse(
            subject_title=subject.title,
            subject_slug=subject.subject_slug,
            subject_icon=subject.icon,
            subject_color=subject.color,
            subject_description=subject.description,
            greeting=_build_greeting(user.full_name),
            current_learning=None,
            progress=ProgressStats(
                overall_mastery=0.0,
                current_topic_mastery=0.0,
                course_completion=0.0,
                assessment_average=0.0,
            ),
            recommendations=[],
            recent_activity=None,
            total_concepts=0,
            mastered_concepts=0,
            in_progress_concepts=0,
            total_practice_attempts=0,
        )

    concept_hierarchy_result = await db.execute(
        select(
            STEMConcept.id.label("concept_id"),
            STEMSubtopic.id.label("subtopic_id"),
            STEMSubtopic.title.label("subtopic_title"),
            STEMTopic.id.label("topic_id"),
            STEMTopic.title.label("topic_title"),
            STEMDiscipline.title.label("discipline_title"),
        )
        .join(STEMSubtopic, STEMSubtopic.id == STEMConcept.subtopic_id)
        .join(STEMTopic, STEMTopic.id == STEMSubtopic.topic_id)
        .join(STEMDiscipline, STEMDiscipline.id == STEMTopic.discipline_id)
        .where(STEMConcept.id.in_(concept_ids))
    )
    hierarchy_rows = concept_hierarchy_result.all()
    hierarchy_map = {
        row.concept_id: {
            "subtopic_id": row.subtopic_id,
            "subtopic_title": row.subtopic_title,
            "topic_id": row.topic_id,
            "topic_title": row.topic_title,
            "discipline_title": row.discipline_title,
        }
        for row in hierarchy_rows
    }

    records_result = await db.execute(
        select(MasteryRecord).where(
            MasteryRecord.user_id == user.id,
            MasteryRecord.concept_id.in_(concept_ids),
        )
    )
    records = records_result.scalars().all()
    records_by_concept = {r.concept_id: r for r in records}

    mastered_concepts = sum(
        1
        for cid in concept_ids
        if cid in records_by_concept and records_by_concept[cid].mastery_level >= 0.8
    )
    in_progress_concepts = sum(
        1
        for cid in concept_ids
        if cid in records_by_concept and 0 < records_by_concept[cid].mastery_level < 0.8
    )
    total_attempts = sum(r.attempts for r in records)

    concepts_with_mastery = [cid for cid in concept_ids if cid in records_by_concept]

    overall_mastery = (
        sum(records_by_concept[cid].mastery_level for cid in concepts_with_mastery)
        / len(concepts_with_mastery)
        if concepts_with_mastery
        else 0.0
    )

    course_completion = (
        len(concepts_with_mastery) / total_concepts if total_concepts > 0 else 0.0
    )

    assessment_average = overall_mastery * 100

    last_practiced_record = None
    last_practiced_concept = None
    for r in records:
        if r.last_practiced is not None:
            if (
                last_practiced_record is None
                or r.last_practiced > last_practiced_record.last_practiced
            ):
                last_practiced_record = r
                last_practiced_concept = concepts_by_id.get(r.concept_id)

    current_learning = None
    if last_practiced_record and last_practiced_concept:
        info = hierarchy_map.get(last_practiced_concept.id, {})
        current_learning = CurrentLearning(
            concept_id=last_practiced_concept.id,
            concept_title=last_practiced_concept.title,
            mastery_level=last_practiced_record.mastery_level,
            topic_title=info.get("topic_title"),
            discipline_title=info.get("discipline_title"),
            subtopic_title=info.get("subtopic_title"),
            last_practiced=last_practiced_record.last_practiced,
        )

    current_topic_mastery = 0.0
    if current_learning and current_learning.topic_title:
        topic_concept_ids = [
            cid
            for cid in concept_ids
            if hierarchy_map.get(cid, {}).get("topic_title")
            == current_learning.topic_title
        ]
        topic_records = [
            records_by_concept[cid]
            for cid in topic_concept_ids
            if cid in records_by_concept
        ]
        if topic_records:
            current_topic_mastery = sum(r.mastery_level for r in topic_records) / len(
                topic_records
            )

    recommendations: list[RecommendationItem] = []
    weak_concept_ids = [
        cid
        for cid in concept_ids
        if cid in records_by_concept and records_by_concept[cid].mastery_level < 0.6
    ]
    for cid in weak_concept_ids[:5]:
        c = concepts_by_id[cid]
        info = hierarchy_map.get(cid, {})
        recommendations.append(
            RecommendationItem(
                concept_id=cid,
                concept_title=c.title,
                mastery_level=records_by_concept[cid].mastery_level,
                reason=f"Mastery at {records_by_concept[cid].mastery_level:.0%} — needs review",
                topic_title=info.get("topic_title"),
            )
        )

    unstarted_ids = [cid for cid in concept_ids if cid not in records_by_concept]
    remaining_slots = 5 - len(recommendations)
    for cid in unstarted_ids[:remaining_slots]:
        c = concepts_by_id[cid]
        info = hierarchy_map.get(cid, {})
        recommendations.append(
            RecommendationItem(
                concept_id=cid,
                concept_title=c.title,
                mastery_level=0.0,
                reason="Not yet started",
                topic_title=info.get("topic_title"),
            )
        )

    recent_activity = None
    if last_practiced_record and last_practiced_concept:
        practice_result = await db.execute(
            select(STPractice)
            .where(STPractice.concept_id == last_practiced_record.concept_id)
            .order_by(STPractice.created_at.desc())
            .limit(1)
        )
        last_practice = practice_result.scalar_one_or_none()
        recent_activity = RecentActivity(
            concept_id=last_practiced_concept.id,
            concept_title=last_practiced_concept.title,
            question_type=last_practice.question_type if last_practice else None,
            marks=last_practice.marks if last_practice else None,
            mastery_level=last_practiced_record.mastery_level,
            last_practiced=last_practiced_record.last_practiced,
        )

    return SubjectDashboardResponse(
        subject_title=subject.title,
        subject_slug=subject.subject_slug,
        subject_icon=subject.icon,
        subject_color=subject.color,
        subject_description=subject.description,
        greeting=_build_greeting(user.full_name),
        current_learning=current_learning,
        progress=ProgressStats(
            overall_mastery=round(overall_mastery * 100, 2),
            current_topic_mastery=round(current_topic_mastery * 100, 2),
            course_completion=round(course_completion * 100, 2),
            assessment_average=round(assessment_average, 2),
        ),
        recommendations=recommendations,
        recent_activity=recent_activity,
        total_concepts=total_concepts,
        mastered_concepts=mastered_concepts,
        in_progress_concepts=in_progress_concepts,
        total_practice_attempts=total_attempts,
    )
