import json
import random

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.stem_latex import STEM_LATEX_INSTRUCTION, VISUAL_GENERATION_POLICY
from app.database.engine import get_db
from app.dependencies.auth import get_current_user, require_lecturer
from app.models.models import (
    Assessment,
    AssessmentQuestion,
    Examination,
    ExamQuestion,
    ExamSubmission,
    User,
)
from app.schemas.assessment import (
    AssessmentCreate,
    AssessmentResponse,
    QuestionResponse,
)
from app.schemas.examinations import (
    ExaminationCreate,
    ExaminationResponse,
    ExamMarkingDecision,
    ExamQuestionCreate,
    ExamQuestionResponse,
    ExamSubmissionCreate,
    ExamSubmissionResponse,
)

router = APIRouter(prefix="/examinations", tags=["Examination Management"])


# ── Examination endpoints (lecturer) ────────────────────────────────────────


@router.post("/", status_code=201)
async def create_examination(
    data: ExaminationCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_lecturer),
):
    exam = Examination(
        course_id=data.course_id,
        title=data.title,
        description=data.description,
        duration_minutes=data.duration_minutes,
        total_marks=data.total_marks,
        status="draft",
        created_by=current_user.id,
    )
    db.add(exam)
    await db.commit()
    await db.refresh(exam)
    return ExaminationResponse.model_validate(exam)


@router.get("/")
async def list_examinations(
    course_id: str | None = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    stmt = select(Examination)
    if course_id:
        stmt = stmt.where(Examination.course_id == course_id)
    result = await db.execute(stmt)
    exams = result.scalars().all()
    return [ExaminationResponse.model_validate(e) for e in exams]


@router.get("/{exam_id}")
async def get_examination(
    exam_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Examination).where(Examination.id == exam_id))
    exam = result.scalar_one_or_none()
    if not exam:
        raise HTTPException(status_code=404, detail="Examination not found")
    return ExaminationResponse.model_validate(exam)


@router.post("/{exam_id}/questions", status_code=201)
async def add_question(
    exam_id: str,
    data: ExamQuestionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_lecturer),
):
    result = await db.execute(select(Examination).where(Examination.id == exam_id))
    exam = result.scalar_one_or_none()
    if not exam:
        raise HTTPException(status_code=404, detail="Examination not found")

    question = ExamQuestion(
        examination_id=exam_id,
        question_text=data.question_text,
        question_type=data.question_type,
        options=data.options,
        correct_answer=data.correct_answer,
        marks=data.marks,
        order=data.order,
    )
    db.add(question)
    await db.commit()
    await db.refresh(question)
    return ExamQuestionResponse.model_validate(question)


@router.get("/{exam_id}/questions")
async def list_questions(
    exam_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Examination).where(Examination.id == exam_id))
    exam = result.scalar_one_or_none()
    if not exam:
        raise HTTPException(status_code=404, detail="Examination not found")

    result = await db.execute(
        select(ExamQuestion)
        .where(ExamQuestion.examination_id == exam_id)
        .order_by(ExamQuestion.order)
    )
    questions = result.scalars().all()
    return [ExamQuestionResponse.model_validate(q) for q in questions]


@router.put("/{exam_id}/publish")
async def publish_examination(
    exam_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_lecturer),
):
    result = await db.execute(select(Examination).where(Examination.id == exam_id))
    exam = result.scalar_one_or_none()
    if not exam:
        raise HTTPException(status_code=404, detail="Examination not found")

    exam.status = "published"
    await db.commit()
    await db.refresh(exam)
    return ExaminationResponse.model_validate(exam)


@router.put("/{exam_id}/status")
async def update_examination_status(
    exam_id: str,
    body: dict,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_lecturer),
):
    new_status = body.get("status")
    if new_status not in ("active", "completed", "archived"):
        raise HTTPException(
            status_code=400,
            detail="Status must be one of: active, completed, archived",
        )

    result = await db.execute(select(Examination).where(Examination.id == exam_id))
    exam = result.scalar_one_or_none()
    if not exam:
        raise HTTPException(status_code=404, detail="Examination not found")

    exam.status = new_status
    await db.commit()
    await db.refresh(exam)
    return ExaminationResponse.model_validate(exam)


@router.get("/{exam_id}/submissions")
async def list_exam_submissions(
    exam_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_lecturer),
):
    result = await db.execute(select(Examination).where(Examination.id == exam_id))
    exam = result.scalar_one_or_none()
    if not exam:
        raise HTTPException(status_code=404, detail="Examination not found")

    result = await db.execute(
        select(ExamSubmission).where(ExamSubmission.examination_id == exam_id)
    )
    submissions = result.scalars().all()
    return [ExamSubmissionResponse.model_validate(s) for s in submissions]


# ── Exam submission endpoints (student) ─────────────────────────────────────


@router.post("/submit", status_code=201)
async def submit_exam(
    data: ExamSubmissionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Examination).where(Examination.id == data.examination_id)
    )
    exam = result.scalar_one_or_none()
    if not exam:
        raise HTTPException(status_code=404, detail="Examination not found")
    if exam.status != "active":
        raise HTTPException(status_code=400, detail="Examination is not active")

    submission = ExamSubmission(
        examination_id=data.examination_id,
        student_id=current_user.id,
        answers=data.answers,
        status="submitted",
    )
    db.add(submission)
    await db.commit()
    await db.refresh(submission)
    return ExamSubmissionResponse.model_validate(submission)


@router.get("/my-submissions")
async def list_my_exam_submissions(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(ExamSubmission).where(ExamSubmission.student_id == current_user.id)
    )
    submissions = result.scalars().all()
    return [ExamSubmissionResponse.model_validate(s) for s in submissions]


# ── Marking endpoint ────────────────────────────────────────────────────────


@router.put("/submissions/{submission_id}/mark")
async def mark_submission(
    submission_id: str,
    data: ExamMarkingDecision,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_lecturer),
):
    result = await db.execute(
        select(ExamSubmission).where(ExamSubmission.id == submission_id)
    )
    submission = result.scalar_one_or_none()
    if not submission:
        raise HTTPException(status_code=404, detail="Submission not found")

    submission.final_marks = data.marks_awarded
    submission.lecturer_feedback = data.feedback
    submission.status = "marked"
    await db.commit()
    await db.refresh(submission)
    return ExamSubmissionResponse.model_validate(submission)


# ── Assessment Studio endpoints ─────────────────────────────────────────────


@router.post("/studio/create", status_code=201)
async def create_assessment(
    data: AssessmentCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_lecturer),
):
    assessment = Assessment(
        course_id=data.course_id,
        title=data.title,
        description=data.description,
        assessment_type=data.assessment_type,
        total_marks=data.total_marks,
        created_by=current_user.id,
    )
    db.add(assessment)
    await db.commit()
    await db.refresh(assessment)
    return AssessmentResponse.model_validate(assessment)


@router.post("/studio/generate-questions", status_code=201)
async def generate_assessment_questions(
    body: dict,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_lecturer),
):
    assessment_id = body.get("assessment_id")
    topic = body.get("topic", "")
    num_questions = body.get("num_questions", 5)
    difficulty = body.get("difficulty", "medium")
    question_types = body.get("question_types", ["multiple_choice"])

    result = await db.execute(select(Assessment).where(Assessment.id == assessment_id))
    assessment = result.scalar_one_or_none()
    if not assessment:
        raise HTTPException(status_code=404, detail="Assessment not found")

    questions = []

    try:
        from app.config.ai_client import AIProviderError, call_ai_chat

        prompt = (
            f"Generate {num_questions} {difficulty}-level assessment questions "
            f"on the topic: {topic}. "
            f"Question types: {', '.join(question_types)}. "
            f"Return JSON array with objects containing: "
            f"question_text, question_type, options (if applicable), "
            f"correct_answer, marks."
        )
        completion, _provider = await call_ai_chat(
            messages=[
                {
                    "role": "system",
                    "content": "You are an expert assessment designer. Return only valid JSON."
                    + STEM_LATEX_INSTRUCTION
                    + VISUAL_GENERATION_POLICY,
                },
                {"role": "user", "content": prompt},
            ],
            temperature=0.7,
            response_format={"type": "json_object"},
        )
        content = completion.choices[0].message.content
        parsed = json.loads(content)
        raw_questions = (
            parsed if isinstance(parsed, list) else parsed.get("questions", [])
        )
        for q in raw_questions:
            q_type = q.get("question_type", "multiple_choice")
            question = AssessmentQuestion(
                assessment_id=assessment_id,
                question_text=q.get("question_text", ""),
                question_type=q_type,
                options=q.get("options"),
                correct_answer=q.get("correct_answer"),
                marks=q.get("marks", 1),
            )
            db.add(question)
            questions.append(question)
    except (AIProviderError, Exception):
        questions = []

    if not questions:
        for i in range(num_questions):
            q_type = question_types[i % len(question_types)]
            marks = 10 if difficulty == "hard" else 5 if difficulty == "medium" else 2
            options = None
            correct = None
            if q_type == "multiple_choice":
                options = [
                    f"Option A-{i + 1}",
                    f"Option B-{i + 1}",
                    f"Option C-{i + 1}",
                    f"Option D-{i + 1}",
                ]
                correct = options[0]
            elif q_type == "true_false":
                options = ["True", "False"]
                correct = random.choice(options)
            question = AssessmentQuestion(
                assessment_id=assessment_id,
                question_text=f"Question {i + 1} on {topic} ({difficulty})",
                question_type=q_type,
                options=options,
                correct_answer=correct,
                marks=marks,
            )
            db.add(question)
            questions.append(question)

    await db.commit()
    for q in questions:
        await db.refresh(q)
    return [QuestionResponse.model_validate(q) for q in questions]


@router.get("/studio/{assessment_id}/quality-review")
async def quality_review_assessment(
    assessment_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_lecturer),
):
    result = await db.execute(select(Assessment).where(Assessment.id == assessment_id))
    assessment = result.scalar_one_or_none()
    if not assessment:
        raise HTTPException(status_code=404, detail="Assessment not found")

    result = await db.execute(
        select(AssessmentQuestion).where(
            AssessmentQuestion.assessment_id == assessment_id
        )
    )
    questions = result.scalars().all()

    if not questions:
        return {
            "assessment_id": assessment_id,
            "total_questions": 0,
            "message": "No questions found for review",
        }

    type_distribution = {}
    for q in questions:
        type_distribution[q.question_type] = (
            type_distribution.get(q.question_type, 0) + 1
        )

    total_marks = sum(q.marks for q in questions)
    avg_marks = total_marks / len(questions) if questions else 0

    ai_review = None

    try:
        from app.config.ai_client import AIProviderError, call_ai_chat

        questions_summary = "\n".join(
            f"- [{q.question_type}] {q.question_text} ({q.marks} marks)"
            for q in questions
        )
        prompt = (
            f"Review this assessment for quality. Title: {assessment.title}\n"
            f"Questions:\n{questions_summary}\n\n"
            f"Provide a JSON object with: "
            f"quality_score (0-100), strengths (list), "
            f"improvements (list), coverage_notes (string)."
        )
        completion, _provider = await call_ai_chat(
            messages=[
                {
                    "role": "system",
                    "content": "You are an expert educational assessor. Return only valid JSON."
                    + STEM_LATEX_INSTRUCTION
                    + VISUAL_GENERATION_POLICY,
                },
                {"role": "user", "content": prompt},
            ],
            temperature=0.3,
            response_format={"type": "json_object"},
        )
        ai_review = json.loads(completion.choices[0].message.content)
    except (AIProviderError, Exception):
        ai_review = None

    review = {
        "assessment_id": assessment_id,
        "total_questions": len(questions),
        "total_marks": total_marks,
        "average_marks_per_question": round(avg_marks, 2),
        "question_type_distribution": type_distribution,
        "difficulty_coverage": {
            "easy": type_distribution.get("multiple_choice", 0),
            "medium": type_distribution.get("short_answer", 0)
            + type_distribution.get("true_false", 0),
            "hard": type_distribution.get("essay", 0),
        },
    }

    if ai_review:
        review["ai_review"] = ai_review

    return review
