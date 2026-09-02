"""Pydantic schemas for the AI Examination Builder."""

from __future__ import annotations

from pydantic import BaseModel, Field


class ExamBuilderConfig(BaseModel):
    """Step 1-5 configuration driving exam generation from syllabus content."""

    subject: str = ""
    subject_slug: str = ""
    form: int | None = None
    form_label: str = ""
    topic: str = ""
    subtopic: str = ""
    topic_id: int | None = None
    subtopic_id: int | None = None
    academic_level: str = ""
    programme: str = ""
    institution: str = ""
    lecturer: str = ""
    semester: str = ""
    academic_year: str = ""

    # Paper details
    title: str = ""
    exam_type: str = "final"  # mock | final | practice | midterm
    total_marks: int = 100
    duration_minutes: int = 120

    # Question mix
    num_questions: int = 10
    difficulty: str = "medium"  # easy | medium | hard | mixed
    bloom_focus: str = "balanced"
    question_types: list[str] = Field(
        default_factory=lambda: ["multiple_choice", "short_answer"]
    )
    include_answers: bool = False

    # Learning objectives pulled from the syllabus + lecturer extras
    learning_objectives: list[str] = Field(default_factory=list)


class QuestionItem(BaseModel):
    """A single exam question (internal representation)."""

    id: str
    question_type: str
    question_text: str
    options: list[str] = Field(default_factory=list)
    correct_answer: str = ""
    marks: int = 1
    difficulty: str = "medium"
    bloom_level: str = "Understanding"
    learning_outcome: str = ""
    rubric: str = ""
    reference: str = ""


class GenerateRequest(BaseModel):
    config: ExamBuilderConfig


class GenerateResponse(BaseModel):
    exam_id: str
    title: str
    questions: list[QuestionItem] = Field(default_factory=list)
    total_marks: int = 0


class QualityReport(BaseModel):
    id: str
    question_count: int = 0
    total_marks: int = 0
    type_distribution: dict = Field(default_factory=dict)
    difficulty_coverage: dict = Field(default_factory=dict)
    bloom_coverage: dict = Field(default_factory=dict)
    syllabus_coverage_pct: int = 0
    answer_completeness_pct: int = 0
    checks: list[dict] = Field(default_factory=list)
    warnings: list[str] = Field(default_factory=list)


class RegenerateQuestionRequest(BaseModel):
    exam_id: str
    question_id: str
    focus: str = ""


class AddQuestionRequest(BaseModel):
    question_type: str
    question_text: str
    options: list[str] = Field(default_factory=list)
    correct_answer: str = ""
    marks: int = 1
    difficulty: str = "medium"
    bloom_level: str = "Understanding"
    learning_outcome: str = ""
    rubric: str = ""
    reference: str = ""


class ExportRequest(BaseModel):
    exam_id: str
    format: str = "docx"  # docx | pdf
    include_answers: bool = False
