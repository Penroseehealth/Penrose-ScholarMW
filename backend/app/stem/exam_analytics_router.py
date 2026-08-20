import json

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import User
from app.models.stem import MockExamResult

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])


class ExamTrendPoint(BaseModel):
    model_config = {"from_attributes": True}

    date: str
    percentage: float
    score: int
    total: int
    time_taken: int


class SubjectSummary(BaseModel):
    slug: str
    count: int
    avg_pct: float


class ExamSummary(BaseModel):
    total_exams: int
    avg_percentage: float
    best_percentage: float
    total_time_minutes: int
    exams_by_subject: list[SubjectSummary]


class ConceptBreakdownItem(BaseModel):
    concept_id: int
    concept_title: str
    total: int
    correct: int


class DifficultyBreakdownItem(BaseModel):
    level: str
    total: int
    correct: int


class ExamBreakdown(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    subject_slug: str
    total_questions: int
    correct_count: int
    total_marks: int
    score_marks: int
    percentage: float
    time_taken_seconds: int
    time_limit_minutes: int
    concept_breakdown: list[ConceptBreakdownItem] | None
    difficulty_breakdown: list[DifficultyBreakdownItem] | None
    created_at: str


@router.get("/analytics/exam-trends/{slug}", response_model=list[ExamTrendPoint])
async def get_exam_trends(
    slug: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MockExamResult)
        .where(
            MockExamResult.user_id == user.id,
            MockExamResult.subject_slug == slug,
        )
        .order_by(MockExamResult.created_at.desc())
        .limit(20)
    )
    rows = result.scalars().all()
    return [
        ExamTrendPoint(
            date=row.created_at.strftime("%Y-%m-%d"),
            percentage=row.percentage,
            score=row.score_marks,
            total=row.total_marks,
            time_taken=row.time_taken_seconds,
        )
        for row in reversed(rows)
    ]


@router.get("/analytics/exam-summary", response_model=ExamSummary)
async def get_exam_summary(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(
            func.count(MockExamResult.id),
            func.coalesce(func.avg(MockExamResult.percentage), 0.0),
            func.coalesce(func.max(MockExamResult.percentage), 0.0),
            func.coalesce(func.sum(MockExamResult.time_taken_seconds), 0),
        ).where(MockExamResult.user_id == user.id)
    )
    row = result.one()
    total_exams = row[0]
    avg_percentage = round(float(row[1]), 2)
    best_percentage = round(float(row[2]), 2)
    total_time_minutes = int(row[3]) // 60

    subject_result = await db.execute(
        select(
            MockExamResult.subject_slug,
            func.count(MockExamResult.id),
            func.coalesce(func.avg(MockExamResult.percentage), 0.0),
        )
        .where(MockExamResult.user_id == user.id)
        .group_by(MockExamResult.subject_slug)
    )
    exams_by_subject = [
        SubjectSummary(slug=r[0], count=r[1], avg_pct=round(float(r[2]), 2))
        for r in subject_result.all()
    ]

    return ExamSummary(
        total_exams=total_exams,
        avg_percentage=avg_percentage,
        best_percentage=best_percentage,
        total_time_minutes=total_time_minutes,
        exams_by_subject=exams_by_subject,
    )


@router.get("/analytics/exam-breakdown/{result_id}", response_model=ExamBreakdown)
async def get_exam_breakdown(
    result_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MockExamResult).where(
            MockExamResult.id == result_id,
            MockExamResult.user_id == user.id,
        )
    )
    row = result.scalar_one_or_none()
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Exam result not found",
        )

    concept_bd = None
    if row.concept_breakdown:
        raw = json.loads(row.concept_breakdown)
        concept_bd = [ConceptBreakdownItem(**item) for item in raw]

    difficulty_bd = None
    if row.difficulty_breakdown:
        raw = json.loads(row.difficulty_breakdown)
        difficulty_bd = [
            DifficultyBreakdownItem(level=k, total=v["total"], correct=v["correct"])
            for k, v in raw.items()
        ]

    return ExamBreakdown(
        id=row.id,
        subject_slug=row.subject_slug,
        total_questions=row.total_questions,
        correct_count=row.correct_count,
        total_marks=row.total_marks,
        score_marks=row.score_marks,
        percentage=row.percentage,
        time_taken_seconds=row.time_taken_seconds,
        time_limit_minutes=row.time_limit_minutes,
        concept_breakdown=concept_bd,
        difficulty_breakdown=difficulty_bd,
        created_at=row.created_at.isoformat(),
    )
