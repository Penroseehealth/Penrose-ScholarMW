from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import User
from app.models.stem import (
    MasteryRecommendation,
    MasteryRecord,
    STEMConcept,
    STEMDiscipline,
    STEMSubject,
    STEMSubtopic,
    STEMTopic,
)

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])


class SubjectMastery(BaseModel):
    subject_id: int
    subject_title: str
    subject_slug: str
    total_concepts: int
    mastered_concepts: int
    in_progress_concepts: int
    average_mastery: float


class WeakConcept(BaseModel):
    concept_id: int
    concept_title: str
    mastery_level: float
    attempts: int
    subject_title: str | None


class RecommendationBrief(BaseModel):
    id: int
    concept_id: int
    recommendation_type: str
    title: str
    description: str | None
    priority: int
    is_completed: bool


class DashboardResponse(BaseModel):
    subjects: list[SubjectMastery]
    weak_concepts: list[WeakConcept]
    recommendations: list[RecommendationBrief]


class ConceptMasteryDetail(BaseModel):
    concept_id: int
    concept_title: str
    subtopic_title: str | None
    topic_title: str | None
    discipline_title: str | None
    subject_title: str | None
    mastery_level: float
    attempts: int
    correct: int
    last_practiced: datetime | None
    next_review: datetime | None


class RecommendationCreateResponse(BaseModel):
    recommendations: list[RecommendationBrief]


class RecommendationCompleteResponse(BaseModel):
    id: int
    is_completed: bool


@router.get("/mastery/dashboard", response_model=DashboardResponse)
async def mastery_dashboard(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    records_result = await db.execute(
        select(MasteryRecord).where(MasteryRecord.user_id == user.id)
    )
    records = records_result.scalars().all()
    records_by_concept = {r.concept_id: r for r in records}

    subjects_result = await db.execute(select(STEMSubject).order_by(STEMSubject.title))
    subjects = subjects_result.scalars().all()

    subject_masteries: list[SubjectMastery] = []
    for subject in subjects:
        concepts_result = await db.execute(
            select(STEMConcept.id)
            .join(STEMSubtopic, STEMSubtopic.id == STEMConcept.subtopic_id)
            .join(STEMTopic, STEMTopic.id == STEMSubtopic.topic_id)
            .join(STEMDiscipline, STEMDiscipline.id == STEMTopic.discipline_id)
            .where(STEMDiscipline.subject_id == subject.id)
        )
        concept_ids = [row[0] for row in concepts_result.all()]
        total = len(concept_ids)
        mastered = sum(
            1
            for cid in concept_ids
            if cid in records_by_concept
            and records_by_concept[cid].mastery_level >= 0.8
        )
        in_progress = sum(
            1
            for cid in concept_ids
            if cid in records_by_concept
            and 0 < records_by_concept[cid].mastery_level < 0.8
        )
        avg = (
            sum(
                records_by_concept[cid].mastery_level
                for cid in concept_ids
                if cid in records_by_concept
            )
            / len([cid for cid in concept_ids if cid in records_by_concept])
            if any(cid in records_by_concept for cid in concept_ids)
            else 0.0
        )
        subject_masteries.append(
            SubjectMastery(
                subject_id=subject.id,
                subject_title=subject.title,
                subject_slug=subject.subject_slug,
                total_concepts=total,
                mastered_concepts=mastered,
                in_progress_concepts=in_progress,
                average_mastery=round(avg, 4),
            )
        )

    weak_concepts: list[WeakConcept] = []
    for r in records:
        if r.mastery_level < 0.5:
            concept_result = await db.execute(
                select(STEMConcept)
                .options(joinedload(STEMConcept.subtopic))
                .where(STEMConcept.id == r.concept_id)
            )
            concept = concept_result.unique().scalar_one_or_none()

            subject_title = None
            if concept and concept.subtopic:
                topic_result = await db.execute(
                    select(STEMTopic).where(STEMTopic.id == concept.subtopic.topic_id)
                )
                topic = topic_result.scalar_one_or_none()
                if topic:
                    disc_result = await db.execute(
                        select(STEMDiscipline).where(
                            STEMDiscipline.id == topic.discipline_id
                        )
                    )
                    disc = disc_result.scalar_one_or_none()
                    if disc:
                        subj_result = await db.execute(
                            select(STEMSubject).where(STEMSubject.id == disc.subject_id)
                        )
                        subj = subj_result.scalar_one_or_none()
                        subject_title = subj.title if subj else None

            weak_concepts.append(
                WeakConcept(
                    concept_id=r.concept_id,
                    concept_title=concept.title if concept else "Unknown",
                    mastery_level=r.mastery_level,
                    attempts=r.attempts,
                    subject_title=subject_title,
                )
            )
    weak_concepts.sort(key=lambda x: x.mastery_level)

    recs_result = await db.execute(
        select(MasteryRecommendation)
        .where(
            MasteryRecommendation.user_id == user.id,
            MasteryRecommendation.is_completed.is_(False),
        )
        .order_by(MasteryRecommendation.priority.desc())
        .limit(10)
    )
    recommendations = [
        RecommendationBrief(
            id=r.id,
            concept_id=r.concept_id,
            recommendation_type=r.recommendation_type,
            title=r.title,
            description=r.description,
            priority=r.priority,
            is_completed=r.is_completed,
        )
        for r in recs_result.scalars().all()
    ]

    return DashboardResponse(
        subjects=subject_masteries,
        weak_concepts=weak_concepts,
        recommendations=recommendations,
    )


@router.get("/mastery/concept/{concept_id}", response_model=ConceptMasteryDetail)
async def get_concept_mastery(
    concept_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    concept_result = await db.execute(
        select(STEMConcept)
        .options(joinedload(STEMConcept.subtopic).joinedload(STEMTopic.discipline))
        .where(STEMConcept.id == concept_id)
    )
    concept = concept_result.unique().scalar_one_or_none()
    if not concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Concept not found"
        )

    subtopic = concept.subtopic
    topic = subtopic.topic if subtopic else None
    discipline = topic.discipline if topic else None

    subject_title = None
    subject_id = discipline.subject_id if discipline else None
    if subject_id:
        subj_result = await db.execute(
            select(STEMSubject).where(STEMSubject.id == subject_id)
        )
        subj = subj_result.scalar_one_or_none()
        subject_title = subj.title if subj else None

    record_result = await db.execute(
        select(MasteryRecord).where(
            MasteryRecord.user_id == user.id,
            MasteryRecord.concept_id == concept_id,
        )
    )
    record = record_result.scalar_one_or_none()

    return ConceptMasteryDetail(
        concept_id=concept.id,
        concept_title=concept.title,
        subtopic_title=subtopic.title if subtopic else None,
        topic_title=topic.title if topic else None,
        discipline_title=discipline.title if discipline else None,
        subject_title=subject_title,
        mastery_level=record.mastery_level if record else 0.0,
        attempts=record.attempts if record else 0,
        correct=record.correct if record else 0,
        last_practiced=record.last_practiced if record else None,
        next_review=record.next_review if record else None,
    )


@router.post("/mastery/recommendations", response_model=RecommendationCreateResponse)
async def generate_recommendations(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    records_result = await db.execute(
        select(MasteryRecord).where(MasteryRecord.user_id == user.id)
    )
    records = records_result.scalars().all()
    weak = [r for r in records if r.mastery_level < 0.6]

    if not weak:
        return RecommendationCreateResponse(recommendations=[])

    new_recs: list[MasteryRecommendation] = []
    for r in weak:
        concept_result = await db.execute(
            select(STEMConcept).where(STEMConcept.id == r.concept_id)
        )
        concept = concept_result.scalar_one_or_none()
        if not concept:
            continue

        existing_result = await db.execute(
            select(MasteryRecommendation).where(
                MasteryRecommendation.user_id == user.id,
                MasteryRecommendation.concept_id == r.concept_id,
                MasteryRecommendation.is_completed.is_(False),
            )
        )
        if existing_result.scalar_one_or_none():
            continue

        priority = 3 if r.mastery_level < 0.3 else (2 if r.mastery_level < 0.5 else 1)
        rec_type = "urgent_review" if r.mastery_level < 0.3 else "review"

        rec = MasteryRecommendation(
            user_id=user.id,
            concept_id=r.concept_id,
            recommendation_type=rec_type,
            title=f"Review: {concept.title}",
            description=(
                f"Your mastery of '{concept.title}' is {r.mastery_level:.0%}. "
                f"Practice {max(3, 5 - r.correct)} more problems to strengthen understanding."
            ),
            priority=priority,
        )
        db.add(rec)
        new_recs.append(rec)

    await db.commit()

    created: list[RecommendationBrief] = []
    for rec in new_recs:
        await db.refresh(rec)
        created.append(
            RecommendationBrief(
                id=rec.id,
                concept_id=rec.concept_id,
                recommendation_type=rec.recommendation_type,
                title=rec.title,
                description=rec.description,
                priority=rec.priority,
                is_completed=rec.is_completed,
            )
        )

    return RecommendationCreateResponse(recommendations=created)


@router.get("/mastery/recommendations", response_model=list[RecommendationBrief])
async def get_pending_recommendations(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MasteryRecommendation)
        .where(
            MasteryRecommendation.user_id == user.id,
            MasteryRecommendation.is_completed.is_(False),
        )
        .order_by(
            MasteryRecommendation.priority.desc(),
            MasteryRecommendation.created_at.desc(),
        )
    )
    return [
        RecommendationBrief(
            id=r.id,
            concept_id=r.concept_id,
            recommendation_type=r.recommendation_type,
            title=r.title,
            description=r.description,
            priority=r.priority,
            is_completed=r.is_completed,
        )
        for r in result.scalars().all()
    ]


@router.post(
    "/mastery/recommendations/{id}/complete",
    response_model=RecommendationCompleteResponse,
)
async def complete_recommendation(
    id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MasteryRecommendation).where(
            MasteryRecommendation.id == id,
            MasteryRecommendation.user_id == user.id,
        )
    )
    rec = result.scalar_one_or_none()
    if not rec:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Recommendation not found",
        )

    rec.is_completed = True
    await db.commit()
    await db.refresh(rec)

    return RecommendationCompleteResponse(id=rec.id, is_completed=rec.is_completed)
