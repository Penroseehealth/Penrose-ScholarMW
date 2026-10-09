from datetime import datetime, timedelta, timezone
from random import sample

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import User
from app.models.stem import MasteryRecord, STEMConcept, STMAssessmentQuestion

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])


def _compute_next_review(
    mastery_level: float,
    attempts: int = 1,
    previous_interval_days: float | None = None,
) -> datetime:
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
        interval_days = 1.0 if attempts <= 1 else 6.0
    else:
        interval_days = min(max(previous_interval_days * ease_factor, 1.0), 365.0)
    return datetime.now(timezone.utc) + timedelta(days=interval_days)


class AnswerSubmission(BaseModel):
    question_id: int
    answer: str


class AssessmentGenerateRequest(BaseModel):
    concept_id: int
    assessment_type: str
    num_questions: int = 5
    difficulty: str | None = None


class QuestionResponse(BaseModel):
    id: int
    question_text: str
    question_type: str
    options: str | None
    bloom_level: str
    difficulty: str
    marks: int


class AssessmentGenerateResponse(BaseModel):
    concept_id: int
    assessment_type: str
    questions: list[QuestionResponse]


class QuestionFeedback(BaseModel):
    question_id: int
    submitted_answer: str
    correct_answer: str | None
    is_correct: bool
    explanation: str | None


class AssessmentSubmitRequest(BaseModel):
    assessment_type: str
    concept_id: int
    answers: list[AnswerSubmission]


class AssessmentSubmitResponse(BaseModel):
    total_questions: int
    correct_count: int
    score_percentage: float
    feedback: list[QuestionFeedback]


class AssessmentHistoryItem(BaseModel):
    concept_id: int
    concept_title: str | None
    assessment_type: str
    attempts: int
    correct: int
    mastery_level: float
    last_practiced: datetime | None


@router.post("/assessment/generate", response_model=AssessmentGenerateResponse)
async def generate_assessment(
    body: AssessmentGenerateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    valid_types = {"diagnostic", "formative", "summative", "practice"}
    if body.assessment_type not in valid_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid assessment type. Must be one of: {', '.join(sorted(valid_types))}",
        )

    concept_result = await db.execute(
        select(STEMConcept).where(STEMConcept.id == body.concept_id)
    )
    if not concept_result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Concept not found"
        )

    stmt = select(STMAssessmentQuestion).where(
        STMAssessmentQuestion.concept_id == body.concept_id,
        STMAssessmentQuestion.assessment_type == body.assessment_type,
        STMAssessmentQuestion.is_published.is_(True),
    )
    if body.difficulty:
        stmt = stmt.where(STMAssessmentQuestion.difficulty == body.difficulty)

    result = await db.execute(stmt)
    all_questions = result.scalars().all()

    if not all_questions:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No questions available for this concept and assessment type",
        )

    selected = sample(all_questions, min(body.num_questions, len(all_questions)))

    return AssessmentGenerateResponse(
        concept_id=body.concept_id,
        assessment_type=body.assessment_type,
        questions=[
            QuestionResponse(
                id=q.id,
                question_text=q.question_text,
                question_type=q.question_type,
                options=q.options,
                bloom_level=q.bloom_level,
                difficulty=q.difficulty,
                marks=q.marks,
            )
            for q in selected
        ],
    )


@router.post("/assessment/submit", response_model=AssessmentSubmitResponse)
async def submit_assessment(
    body: AssessmentSubmitRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    question_ids = [a.question_id for a in body.answers]
    if not question_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="No answers submitted"
        )

    questions_result = await db.execute(
        select(STMAssessmentQuestion).where(STMAssessmentQuestion.id.in_(question_ids))
    )
    questions_map = {q.id: q for q in questions_result.scalars().all()}

    if len(questions_map) != len(question_ids):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="One or more question IDs are invalid",
        )

    feedback: list[QuestionFeedback] = []
    correct_count = 0

    for answer in body.answers:
        q = questions_map[answer.question_id]
        is_correct = answer.answer.strip().lower() == (q.answer or "").strip().lower()
        if is_correct:
            correct_count += 1
        feedback.append(
            QuestionFeedback(
                question_id=answer.question_id,
                submitted_answer=answer.answer,
                correct_answer=q.answer,
                is_correct=is_correct,
                explanation=q.explanation,
            )
        )

    total = len(body.answers)
    score_pct = (correct_count / total * 100) if total > 0 else 0.0

    existing_result = await db.execute(
        select(MasteryRecord).where(
            MasteryRecord.user_id == user.id,
            MasteryRecord.concept_id == body.concept_id,
        )
    )
    record = existing_result.scalar_one_or_none()
    now = datetime.now(timezone.utc)

    if record:
        record.attempts += total
        record.correct += correct_count
        record.mastery_level = (
            record.correct / record.attempts if record.attempts > 0 else 0.0
        )
        record.last_practiced = now
        record.next_review = _compute_next_review(record.mastery_level, record.attempts)
    else:
        record = MasteryRecord(
            user_id=user.id,
            concept_id=body.concept_id,
            mastery_level=correct_count / total if total > 0 else 0.0,
            attempts=total,
            correct=correct_count,
            last_practiced=now,
            next_review=_compute_next_review(
                correct_count / total if total > 0 else 0.0, total
            ),
        )
        db.add(record)

    await db.commit()
    await db.refresh(record)

    return AssessmentSubmitResponse(
        total_questions=total,
        correct_count=correct_count,
        score_percentage=score_pct,
        feedback=feedback,
    )


@router.get("/assessment/history", response_model=list[AssessmentHistoryItem])
async def get_assessment_history(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    records_result = await db.execute(
        select(MasteryRecord)
        .where(MasteryRecord.user_id == user.id)
        .order_by(MasteryRecord.last_practiced.desc().nullslast())
    )
    records = records_result.scalars().all()

    items: list[AssessmentHistoryItem] = []
    for r in records:
        concept_result = await db.execute(
            select(STEMConcept).where(STEMConcept.id == r.concept_id)
        )
        concept = concept_result.scalar_one_or_none()
        items.append(
            AssessmentHistoryItem(
                concept_id=r.concept_id,
                concept_title=concept.title if concept else None,
                assessment_type="practice",
                attempts=r.attempts,
                correct=r.correct,
                mastery_level=r.mastery_level,
                last_practiced=r.last_practiced,
            )
        )
    return items
