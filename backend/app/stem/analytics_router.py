from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import User
from app.models.stem import (
    MasteryRecord,
    STEMConcept,
    STEMDailyProgress,
    STEMDiscipline,
    STEMStudySession,
    STEMSubject,
    STEMSubtopic,
    STEMTopic,
)

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])


class HeatmapDay(BaseModel):
    date: str
    study_minutes: int
    concepts_reviewed: int
    streak_days: int


class ProgressDataset(BaseModel):
    subject: str
    values: list[float]


class ProgressOverTime(BaseModel):
    labels: list[str]
    datasets: list[ProgressDataset]


class SubjectComparison(BaseModel):
    subject_slug: str
    subject_title: str
    mastery_avg: float
    concepts_total: int
    concepts_mastered: int


class StudySummary(BaseModel):
    total_minutes: int
    total_sessions: int
    current_streak: int
    longest_streak: int
    avg_daily_minutes: float


class WeakestConcept(BaseModel):
    concept_id: int
    title: str
    subject_slug: str
    mastery_level: float
    attempts: int


class RecentActivity(BaseModel):
    date: str
    minutes: int


class SubjectBreakdown(BaseModel):
    subject_title: str
    total_disciplines: int
    total_topics: int
    total_concepts: int
    mastery_avg: float
    study_hours: float
    recent_activity: list[RecentActivity]


def _today_str() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def _days_ago_str(days: int) -> str:
    return (datetime.now(timezone.utc) - timedelta(days=days)).strftime("%Y-%m-%d")


@router.get("/analytics/heatmap", response_model=list[HeatmapDay])
async def analytics_heatmap(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    since = _days_ago_str(30)
    result = await db.execute(
        select(STEMDailyProgress)
        .where(
            STEMDailyProgress.user_id == user.id,
            STEMDailyProgress.date >= since,
        )
        .order_by(STEMDailyProgress.date)
    )
    rows = result.scalars().all()
    return [
        HeatmapDay(
            date=r.date,
            study_minutes=r.study_minutes,
            concepts_reviewed=r.concepts_reviewed,
            streak_days=r.streak_days,
        )
        for r in rows
    ]


@router.get("/analytics/progress-over-time", response_model=ProgressOverTime)
async def analytics_progress_over_time(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    records_result = await db.execute(select(MasteryRecord).where(MasteryRecord.user_id == user.id))
    records = records_result.scalars().all()

    if not records:
        return ProgressOverTime(labels=[], datasets=[])

    concept_ids = [r.concept_id for r in records]

    concepts_result = await db.execute(
        select(STEMConcept.id, STEMConcept.title, STEMSubtopic.id.label("subtopic_id"))
        .join(STEMSubtopic, STEMSubtopic.id == STEMConcept.subtopic_id)
        .where(STEMConcept.id.in_(concept_ids))
    )
    concept_map = {row[0]: {"title": row[1], "subtopic_id": row[2]} for row in concepts_result.all()}

    subtopic_ids = list({c["subtopic_id"] for c in concept_map.values()})
    subtopic_result = await db.execute(
        select(STEMSubtopic.id, STEMTopic.id.label("topic_id"))
        .join(STEMTopic, STEMTopic.id == STEMSubtopic.topic_id)
        .where(STEMSubtopic.id.in_(subtopic_ids))
    )
    subtopic_map = {row[0]: row[1] for row in subtopic_result.all()}

    topic_ids = list(subtopic_map.values())
    topic_result = await db.execute(
        select(STEMTopic.id, STEMDiscipline.id.label("discipline_id"))
        .join(STEMDiscipline, STEMDiscipline.id == STEMTopic.discipline_id)
        .where(STEMTopic.id.in_(topic_ids))
    )
    topic_map = {row[0]: row[1] for row in topic_result.all()}

    discipline_ids = list(topic_map.values())
    disc_result = await db.execute(
        select(STEMDiscipline.id, STEMSubject.title, STEMSubject.subject_slug)
        .join(STEMSubject, STEMSubject.id == STEMDiscipline.subject_id)
        .where(STEMDiscipline.id.in_(discipline_ids))
    )
    disc_map = {row[0]: {"title": row[1], "slug": row[2]} for row in disc_result.all()}

    from collections import defaultdict

    subject_mastery: dict[str, list[float]] = defaultdict(list)
    for r in records:
        info = concept_map.get(r.concept_id)
        if not info:
            continue
        topic_id = subtopic_map.get(info["subtopic_id"])
        if not topic_id:
            continue
        disc_info = disc_map.get(topic_map.get(topic_id))
        if not disc_info:
            continue
        subject_mastery[disc_info["title"]].append(r.mastery_level)

    labels = sorted(subject_mastery.keys())
    datasets = [
        ProgressDataset(
            subject=s,
            values=[round(sum(subject_mastery[s]) / len(subject_mastery[s]), 4)],
        )
        for s in labels
    ]
    return ProgressOverTime(labels=labels, datasets=datasets)


@router.get("/analytics/subject-comparison", response_model=list[SubjectComparison])
async def analytics_subject_comparison(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    subjects_result = await db.execute(select(STEMSubject).order_by(STEMSubject.title))
    subjects = subjects_result.scalars().all()

    records_result = await db.execute(select(MasteryRecord).where(MasteryRecord.user_id == user.id))
    records = {r.concept_id: r for r in records_result.scalars().all()}

    comparisons: list[SubjectComparison] = []
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
        mastered = sum(1 for cid in concept_ids if cid in records and records[cid].mastery_level >= 0.8)
        avg = (
            sum(records[cid].mastery_level for cid in concept_ids if cid in records)
            / len([cid for cid in concept_ids if cid in records])
            if any(cid in records for cid in concept_ids)
            else 0.0
        )
        comparisons.append(
            SubjectComparison(
                subject_slug=subject.subject_slug,
                subject_title=subject.title,
                mastery_avg=round(avg, 4),
                concepts_total=total,
                concepts_mastered=mastered,
            )
        )
    return comparisons


@router.get("/analytics/study-summary", response_model=StudySummary)
async def analytics_study_summary(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    sessions_result = await db.execute(select(STEMStudySession).where(STEMStudySession.user_id == user.id))
    sessions = sessions_result.scalars().all()

    total_minutes = sum(s.duration_minutes for s in sessions)
    total_sessions = len(sessions)

    progress_result = await db.execute(
        select(STEMDailyProgress)
        .where(
            STEMDailyProgress.user_id == user.id,
            STEMDailyProgress.study_minutes > 0,
        )
        .order_by(STEMDailyProgress.date.desc())
    )
    progress_rows = progress_result.scalars().all()

    current_streak = 0
    longest_streak = 0
    streak = 0
    for p in progress_rows:
        if p.study_minutes > 0:
            streak += 1
            longest_streak = max(longest_streak, streak)
        else:
            streak = 0

    current_streak = streak if streak > 0 else 0

    if progress_rows:
        total_study_days = sum(1 for p in progress_rows if p.study_minutes > 0)
        avg_daily = total_minutes / total_study_days if total_study_days > 0 else 0.0
    else:
        avg_daily = 0.0

    return StudySummary(
        total_minutes=total_minutes,
        total_sessions=total_sessions,
        current_streak=current_streak,
        longest_streak=longest_streak,
        avg_daily_minutes=round(avg_daily, 2),
    )


@router.get("/analytics/weakest-concepts", response_model=list[WeakestConcept])
async def analytics_weakest_concepts(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    records_result = await db.execute(
        select(MasteryRecord)
        .where(MasteryRecord.user_id == user.id, MasteryRecord.mastery_level < 0.5)
        .order_by(MasteryRecord.mastery_level.asc())
        .limit(10)
    )
    records = records_result.scalars().all()

    weakest: list[WeakestConcept] = []
    for r in records:
        concept_result = await db.execute(
            select(STEMConcept.id, STEMConcept.title, STEMSubtopic.id.label("subtopic_id"))
            .join(STEMSubtopic, STEMSubtopic.id == STEMConcept.subtopic_id)
            .where(STEMConcept.id == r.concept_id)
        )
        row = concept_result.first()
        subject_slug = ""
        if row:
            subtopic_id = row[2]
            subtopic_row = await db.execute(
                select(STEMSubtopic.id, STEMTopic.id.label("topic_id"))
                .join(STEMTopic, STEMTopic.id == STEMSubtopic.topic_id)
                .where(STEMSubtopic.id == subtopic_id)
            )
            st_row = subtopic_row.first()
            if st_row:
                topic_row = await db.execute(
                    select(STEMTopic.id, STEMDiscipline.id.label("discipline_id"))
                    .join(STEMDiscipline, STEMDiscipline.id == STEMTopic.discipline_id)
                    .where(STEMTopic.id == st_row[1])
                )
                t_row = topic_row.first()
                if t_row:
                    disc_row = await db.execute(
                        select(STEMDiscipline.id, STEMSubject.subject_slug)
                        .join(STEMSubject, STEMSubject.id == STEMDiscipline.subject_id)
                        .where(STEMDiscipline.id == t_row[1])
                    )
                    d_row = disc_row.first()
                    if d_row:
                        subject_slug = d_row[1]

        weakest.append(
            WeakestConcept(
                concept_id=r.concept_id,
                title=row[1] if row else "Unknown",
                subject_slug=subject_slug,
                mastery_level=r.mastery_level,
                attempts=r.attempts,
            )
        )
    return weakest


@router.get("/analytics/subject-breakdown/{slug}", response_model=SubjectBreakdown)
async def analytics_subject_breakdown(
    slug: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    subject_result = await db.execute(select(STEMSubject).where(STEMSubject.subject_slug == slug))
    subject = subject_result.scalar_one_or_none()
    if not subject:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Subject not found")

    disciplines_result = await db.execute(select(STEMDiscipline).where(STEMDiscipline.subject_id == subject.id))
    disciplines = disciplines_result.scalars().all()
    total_disciplines = len(disciplines)

    discipline_ids = [d.id for d in disciplines]

    topics_result = await db.execute(select(STEMTopic).where(STEMTopic.discipline_id.in_(discipline_ids)))
    topics = topics_result.scalars().all()
    total_topics = len(topics)

    topic_ids = [t.id for t in topics]

    concepts_result = await db.execute(
        select(STEMConcept).where(
            STEMConcept.subtopic_id.in_(select(STEMSubtopic.id).where(STEMSubtopic.topic_id.in_(topic_ids)))
        )
    )
    concept_ids = [c.id for c in concepts_result.scalars().all()]
    total_concepts = len(concept_ids)

    mastery_avg = 0.0
    if concept_ids:
        records_result = await db.execute(
            select(MasteryRecord).where(
                MasteryRecord.user_id == user.id,
                MasteryRecord.concept_id.in_(concept_ids),
            )
        )
        records = records_result.scalars().all()
        if records:
            mastery_avg = sum(r.mastery_level for r in records) / len(records)

    sessions_result = await db.execute(
        select(STEMStudySession).where(
            STEMStudySession.user_id == user.id,
            STEMStudySession.subject_slug == slug,
        )
    )
    sessions = sessions_result.scalars().all()
    study_hours = round(sum(s.duration_minutes for s in sessions) / 60.0, 2)

    since = _days_ago_str(7)
    progress_result = await db.execute(
        select(STEMDailyProgress)
        .where(
            STEMDailyProgress.user_id == user.id,
            STEMDailyProgress.date >= since,
        )
        .order_by(STEMDailyProgress.date.desc())
    )
    recent_progress = progress_result.scalars().all()
    recent_activity = [RecentActivity(date=p.date, minutes=p.study_minutes) for p in recent_progress]

    return SubjectBreakdown(
        subject_title=subject.title,
        total_disciplines=total_disciplines,
        total_topics=total_topics,
        total_concepts=total_concepts,
        mastery_avg=round(mastery_avg, 4),
        study_hours=study_hours,
        recent_activity=recent_activity,
    )
