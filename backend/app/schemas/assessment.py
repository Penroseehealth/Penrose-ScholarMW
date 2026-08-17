from datetime import datetime

from pydantic import BaseModel


class AssessmentCreate(BaseModel):
    course_id: int
    title: str
    description: str | None = None
    assessment_type: str
    total_marks: int = 100
    weight_pct: float = 0.0
    due_at: datetime | None = None
    duration_minutes: int | None = None


class AssessmentResponse(BaseModel):
    id: int
    course_id: int
    title: str
    description: str | None = None
    assessment_type: str
    total_marks: int
    weight_pct: float
    due_at: datetime | None = None
    is_published: bool
    ai_generated: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class QuestionCreate(BaseModel):
    question_text: str
    question_type: str
    marks: int = 1
    options: str | None = None
    correct_answer: str | None = None
    rubric: str | None = None
    learning_outcome: str | None = None
    difficulty: str = "medium"


class QuestionResponse(BaseModel):
    id: int
    assessment_id: int
    question_text: str
    question_type: str
    marks: int
    options: str | None = None
    learning_outcome: str | None = None
    difficulty: str

    model_config = {"from_attributes": True}


class SubmissionCreate(BaseModel):
    assessment_id: int
    answers: str


class SubmissionResponse(BaseModel):
    id: int
    assessment_id: int
    student_id: int
    ai_suggested_marks: int | None = None
    ai_feedback: str | None = None
    final_marks: int | None = None
    lecturer_feedback: str | None = None
    status: str
    submitted_at: datetime

    model_config = {"from_attributes": True}


class MarkingDecision(BaseModel):
    submission_id: int
    final_marks: int
    feedback: str | None = None
    decision: str  # accept | modify | reject
