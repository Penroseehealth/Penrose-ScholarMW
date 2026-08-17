from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user, require_lecturer
from app.models.models import Assessment, AssessmentQuestion, Submission, User
from app.schemas.assessment import (
    AssessmentCreate,
    AssessmentResponse,
    MarkingDecision,
    QuestionCreate,
    QuestionResponse,
    SubmissionCreate,
    SubmissionResponse,
)

router = APIRouter(prefix="/assessments", tags=["Assessments"])


@router.get("/course/{course_id}", response_model=list[AssessmentResponse])
async def list_assessments(
    course_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Assessment).where(Assessment.course_id == course_id)
    )
    return [AssessmentResponse.model_validate(a) for a in result.scalars().all()]


@router.post(
    "/", response_model=AssessmentResponse, status_code=status.HTTP_201_CREATED
)
async def create_assessment(
    body: AssessmentCreate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    assessment = Assessment(**body.model_dump(), ai_generated=False)
    db.add(assessment)
    await db.commit()
    await db.refresh(assessment)
    return AssessmentResponse.model_validate(assessment)


@router.post(
    "/{assessment_id}/questions",
    response_model=QuestionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_question(
    assessment_id: int,
    body: QuestionCreate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    question = AssessmentQuestion(assessment_id=assessment_id, **body.model_dump())
    db.add(question)
    await db.commit()
    await db.refresh(question)
    return QuestionResponse.model_validate(question)


@router.get("/{assessment_id}/questions", response_model=list[QuestionResponse])
async def list_questions(
    assessment_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(AssessmentQuestion)
        .where(AssessmentQuestion.assessment_id == assessment_id)
        .order_by(AssessmentQuestion.order)
    )
    return [QuestionResponse.model_validate(q) for q in result.scalars().all()]


@router.post(
    "/submit", response_model=SubmissionResponse, status_code=status.HTTP_201_CREATED
)
async def submit_assessment(
    body: SubmissionCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    submission = Submission(
        assessment_id=body.assessment_id,
        student_id=user.id,
        answers=body.answers,
        status="submitted",
    )
    db.add(submission)
    await db.commit()
    await db.refresh(submission)
    return SubmissionResponse.model_validate(submission)


@router.get("/{assessment_id}/submissions", response_model=list[SubmissionResponse])
async def list_submissions(
    assessment_id: int,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Submission).where(Submission.assessment_id == assessment_id)
    )
    return [SubmissionResponse.model_validate(s) for s in result.scalars().all()]


@router.put("/submissions/{submission_id}/mark")
async def mark_submission(
    submission_id: int,
    body: MarkingDecision,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Submission).where(Submission.id == submission_id))
    submission = result.scalar_one_or_none()
    if not submission:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Submission not found"
        )

    if body.decision == "accept":
        submission.final_marks = submission.ai_suggested_marks
    elif body.decision == "modify":
        submission.final_marks = body.final_marks
    elif body.decision == "reject":
        submission.final_marks = None

    submission.lecturer_feedback = body.lecturer_feedback
    submission.status = "graded"
    submission.graded_at = datetime.now(timezone.utc)
    await db.commit()
    return {"detail": "Submission graded"}


@router.post("/{assessment_id}/publish")
async def publish_assessment(
    assessment_id: int,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Assessment).where(Assessment.id == assessment_id))
    assessment = result.scalar_one_or_none()
    if not assessment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Assessment not found"
        )
    assessment.is_published = True
    await db.commit()
    return {"detail": "Assessment published"}
