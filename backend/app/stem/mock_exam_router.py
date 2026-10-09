import json
from datetime import datetime, timedelta, timezone
from random import sample

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import User
from app.models.stem import (
    MasteryRecord,
    MockExamResult,
    STEMConcept,
    STEMDiscipline,
    STEMSubject,
    STEMSubtopic,
    STEMTopic,
    STPractice,
)

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])

_exam_sessions: dict[int, dict] = {}
_exam_history: dict[int, list[dict]] = {}
_session_counter = 0


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


class MockExamStartRequest(BaseModel):
    subject_slug: str
    num_questions: int = 20
    difficulty: str | None = None
    time_limit_minutes: int = 60


class MockExamQuestionResponse(BaseModel):
    id: int
    question_text: str
    question_type: str
    options: str | None
    difficulty: str
    marks: int
    concept_id: int


class SubjectInfo(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    title: str
    subject_slug: str
    icon: str | None
    color: str | None


class MockExamStartResponse(BaseModel):
    exam_session_id: int
    questions: list[MockExamQuestionResponse]
    time_limit: int
    subject: SubjectInfo


class AnswerSubmission(BaseModel):
    question_id: int
    answer: str


class MockExamSubmitRequest(BaseModel):
    answers: list[AnswerSubmission]


class QuestionResult(BaseModel):
    question_id: int
    submitted_answer: str
    correct_answer: str | None
    is_correct: bool
    explanation: str | None
    marks: int
    grading_method: str


class MockExamSubmitResponse(BaseModel):
    total_score: int
    max_score: int
    percentage: float
    results: list[QuestionResult]
    time_taken: int | None


class MockExamHistoryItem(BaseModel):
    session_id: int
    subject_slug: str
    total_questions: int
    correct_count: int
    score_percentage: float
    taken_at: str


@router.post("/mock-exam/start", response_model=MockExamStartResponse)
async def start_mock_exam(
    body: MockExamStartRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    global _session_counter

    subject_result = await db.execute(
        select(STEMSubject).where(STEMSubject.subject_slug == body.subject_slug)
    )
    subject = subject_result.scalar_one_or_none()
    if not subject:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Subject not found",
        )

    stmt = (
        select(STEMConcept)
        .join(STEMSubtopic, STEMConcept.subtopic_id == STEMSubtopic.id)
        .join(STEMTopic, STEMSubtopic.topic_id == STEMTopic.id)
        .join(STEMDiscipline, STEMTopic.discipline_id == STEMDiscipline.id)
        .join(STEMSubject, STEMDiscipline.subject_id == STEMSubject.id)
        .where(STEMSubject.id == subject.id)
    )
    concepts_result = await db.execute(stmt)
    concepts = concepts_result.scalars().all()
    concept_ids = [c.id for c in concepts]

    if not concept_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No concepts available for this subject",
        )

    practice_stmt = select(STPractice).where(
        STPractice.concept_id.in_(concept_ids),
        STPractice.is_published.is_(True),
    )
    if body.difficulty:
        practice_stmt = practice_stmt.where(STPractice.difficulty == body.difficulty)

    practice_result = await db.execute(practice_stmt)
    all_questions = practice_result.scalars().all()

    if len(all_questions) < body.num_questions:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough questions available. Requested {body.num_questions}, found {len(all_questions)}",
        )

    selected = sample(all_questions, body.num_questions)

    _session_counter += 1
    session_id = _session_counter

    questions_data = []
    question_responses = []
    for q in selected:
        questions_data.append(
            {
                "id": q.id,
                "concept_id": q.concept_id,
                "correct_answer": q.answer,
            }
        )
        question_responses.append(
            MockExamQuestionResponse(
                id=q.id,
                question_text=q.question_text,
                question_type=q.question_type,
                options=q.options,
                difficulty=q.difficulty,
                marks=q.marks,
                concept_id=q.concept_id,
            )
        )

    _exam_sessions[session_id] = {
        "user_id": user.id,
        "subject_slug": body.subject_slug,
        "subject_id": subject.id,
        "questions": questions_data,
        "time_limit": body.time_limit_minutes,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }

    return MockExamStartResponse(
        exam_session_id=session_id,
        questions=question_responses,
        time_limit=body.time_limit_minutes,
        subject=SubjectInfo.model_validate(subject),
    )


@router.post("/mock-exam/{session_id}/submit", response_model=MockExamSubmitResponse)
async def submit_mock_exam(
    session_id: int,
    body: MockExamSubmitRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    session = _exam_sessions.get(session_id)
    if not session or session["user_id"] != user.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Exam session not found or expired",
        )

    created_at = datetime.fromisoformat(session["created_at"])
    elapsed = datetime.now(timezone.utc) - created_at
    if elapsed.total_seconds() > session["time_limit"] * 60 + 300:
        del _exam_sessions[session_id]
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Exam session has expired",
        )

    answers_map = {a.question_id: a.answer for a in body.answers}

    question_ids = [q["id"] for q in session["questions"]]
    practice_result = await db.execute(
        select(STPractice).where(STPractice.id.in_(question_ids))
    )
    practice_map = {p.id: p for p in practice_result.scalars().all()}

    results: list[QuestionResult] = []
    correct_count = 0
    max_score = 0

    concept_attempts: dict[int, dict] = {}
    difficulty_breakdown: dict[str, dict[str, int]] = {}
    concept_breakdown_list: list[dict] = []

    for q_data in session["questions"]:
        q_id = q_data["id"]
        concept_id = q_data["concept_id"]
        practice = practice_map.get(q_id)
        user_answer = answers_map.get(q_id, "")
        correct_answer = q_data["correct_answer"]

        is_correct = (
            user_answer.strip().lower() == (correct_answer or "").strip().lower()
        )
        marks = practice.marks if practice else 1
        max_score += marks

        auto_graded_types = {"mcq", "true_false", "fill_in_blank", "short_answer"}
        grading_method = (
            "auto"
            if practice and practice.question_type in auto_graded_types
            else "auto"
        )

        if is_correct:
            correct_count += marks

        results.append(
            QuestionResult(
                question_id=q_id,
                submitted_answer=user_answer,
                correct_answer=correct_answer,
                is_correct=is_correct,
                explanation=practice.explanation if practice else None,
                marks=marks,
                grading_method=grading_method,
            )
        )

        if concept_id not in concept_attempts:
            concept_attempts[concept_id] = {"total": 0, "correct": 0}
        concept_attempts[concept_id]["total"] += 1
        if is_correct:
            concept_attempts[concept_id]["correct"] += 1

        diff = (practice.difficulty if practice else "medium") or "medium"
        if diff not in difficulty_breakdown:
            difficulty_breakdown[diff] = {"total": 0, "correct": 0}
        difficulty_breakdown[diff]["total"] += 1
        if is_correct:
            difficulty_breakdown[diff]["correct"] += 1

        existing_cb = next(
            (cb for cb in concept_breakdown_list if cb["concept_id"] == concept_id),
            None,
        )
        if existing_cb:
            existing_cb["total"] += 1
            if is_correct:
                existing_cb["correct"] += 1
        else:
            concept_result = await db.execute(
                select(STEMConcept.title).where(STEMConcept.id == concept_id)
            )
            ct = concept_result.scalar_one_or_none()
            concept_breakdown_list.append(
                {
                    "concept_id": concept_id,
                    "concept_title": ct or "Unknown",
                    "total": 1,
                    "correct": 1 if is_correct else 0,
                }
            )

    total_score = correct_count
    percentage = (total_score / max_score * 100) if max_score > 0 else 0.0
    time_taken = int(elapsed.total_seconds())

    for concept_id, stats in concept_attempts.items():
        existing_result = await db.execute(
            select(MasteryRecord).where(
                MasteryRecord.user_id == user.id,
                MasteryRecord.concept_id == concept_id,
            )
        )
        record = existing_result.scalar_one_or_none()
        now = datetime.now(timezone.utc)

        if record:
            record.attempts += stats["total"]
            record.correct += stats["correct"]
            record.mastery_level = (
                record.correct / record.attempts if record.attempts > 0 else 0.0
            )
            record.last_practiced = now
            record.next_review = _compute_next_review(
                record.mastery_level, record.attempts
            )
        else:
            mastery = stats["correct"] / stats["total"] if stats["total"] > 0 else 0.0
            record = MasteryRecord(
                user_id=user.id,
                concept_id=concept_id,
                mastery_level=mastery,
                attempts=stats["total"],
                correct=stats["correct"],
                last_practiced=now,
                next_review=_compute_next_review(mastery, stats["total"]),
            )
            db.add(record)

    await db.commit()

    history_entry = {
        "session_id": session_id,
        "subject_slug": session["subject_slug"],
        "total_questions": len(session["questions"]),
        "correct_count": correct_count,
        "score_percentage": round(percentage, 2),
        "taken_at": datetime.now(timezone.utc).isoformat(),
    }
    if user.id not in _exam_history:
        _exam_history[user.id] = []
    _exam_history[user.id].append(history_entry)

    del _exam_sessions[session_id]

    exam_result = MockExamResult(
        user_id=user.id,
        subject_slug=session["subject_slug"],
        total_questions=len(session["questions"]),
        correct_count=correct_count,
        total_marks=max_score,
        score_marks=total_score,
        percentage=round(percentage, 2),
        time_taken_seconds=time_taken,
        time_limit_minutes=session["time_limit"],
        difficulty_breakdown=json.dumps(difficulty_breakdown),
        concept_breakdown=json.dumps(concept_breakdown_list),
        bloom_breakdown=None,
    )
    db.add(exam_result)
    await db.commit()

    return MockExamSubmitResponse(
        total_score=total_score,
        max_score=max_score,
        percentage=round(percentage, 2),
        results=results,
        time_taken=time_taken,
    )


@router.get("/mock-exam/history", response_model=list[MockExamHistoryItem])
async def get_mock_exam_history(
    user: User = Depends(get_current_user),
):
    history = _exam_history.get(user.id, [])
    return [MockExamHistoryItem(**item) for item in history]
