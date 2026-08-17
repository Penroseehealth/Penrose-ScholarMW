from pydantic import BaseModel


class ExaminationCreate(BaseModel):
    course_id: int
    title: str
    description: str | None = None
    total_marks: int = 100
    duration_minutes: int = 120
    exam_type: str = "final"
    is_timed: bool = True
    allow_offline: bool = False
    randomize_questions: bool = False
    scheduled_at: str | None = None


class ExaminationResponse(BaseModel):
    id: int
    course_id: int
    title: str
    description: str | None = None
    total_marks: int
    duration_minutes: int
    exam_type: str
    is_timed: bool
    allow_offline: bool
    randomize_questions: bool
    status: str
    scheduled_at: str | None = None
    created_by: int

    model_config = {"from_attributes": True}


class ExamQuestionCreate(BaseModel):
    question_text: str
    question_type: str
    marks: int = 1
    options: str | None = None
    correct_answer: str | None = None
    rubric: str | None = None
    learning_outcome: str | None = None
    bloom_level: str | None = None
    difficulty: str = "medium"
    reference: str | None = None
    order: int = 0


class ExamQuestionResponse(BaseModel):
    id: int
    examination_id: int
    question_text: str
    question_type: str
    marks: int
    options: str | None = None
    learning_outcome: str | None = None
    bloom_level: str | None = None
    difficulty: str
    reference: str | None = None
    order: int

    model_config = {"from_attributes": True}


class ExamSubmissionCreate(BaseModel):
    examination_id: int
    answers: str | None = None


class ExamSubmissionResponse(BaseModel):
    id: int
    examination_id: int
    student_id: int
    ai_marks: int | None = None
    ai_feedback: str | None = None
    final_marks: int | None = None
    lecturer_feedback: str | None = None
    status: str
    started_at: str
    submitted_at: str | None = None

    model_config = {"from_attributes": True}


class ExamMarkingDecision(BaseModel):
    submission_id: int
    final_marks: int
    feedback: str
    decision: str  # accept, modify, reject


class EvidenceCardCreate(BaseModel):
    project_id: int
    paper_title: str
    authors: str | None = None
    year: int | None = None
    doi: str | None = None
    study_design: str | None = None
    population: str | None = None
    sample_size: str | None = None
    setting: str | None = None
    exposure: str | None = None
    outcome: str | None = None
    main_finding: str | None = None
    limitations: str | None = None
    conclusions: str | None = None


class EvidenceCardResponse(BaseModel):
    id: int
    project_id: int
    paper_title: str
    authors: str | None = None
    year: int | None = None
    doi: str | None = None
    study_design: str | None = None
    population: str | None = None
    sample_size: str | None = None
    setting: str | None = None
    exposure: str | None = None
    outcome: str | None = None
    main_finding: str | None = None
    limitations: str | None = None
    conclusions: str | None = None
    is_verified: bool

    model_config = {"from_attributes": True}


class EvidenceMatrixCreate(BaseModel):
    project_id: int
    title: str
    columns_config: str | None = None


class EvidenceMatrixResponse(BaseModel):
    id: int
    project_id: int
    title: str
    columns_config: str | None = None

    model_config = {"from_attributes": True}
