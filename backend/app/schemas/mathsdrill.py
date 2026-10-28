from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class MathsdrillSessionIn(BaseModel):
    student_name: str = Field(min_length=1, max_length=255)
    topic_id: str | None = Field(default=None, max_length=100)
    correct: int = Field(ge=0)
    total: int = Field(ge=0)
    ts: int | None = Field(default=None, ge=0)


class MathsdrillStudentSummary(BaseModel):
    student_name: str
    sessions: int
    correct: int
    total: int
    last_activity: datetime | None


class MathsdrillSessionOut(BaseModel):
    id: int
    student_name: str
    topic_id: str | None
    correct: int
    total: int
    score_ts: int | None
    created_at: datetime

    model_config = {"from_attributes": True}


class MathsdrillPaperStateIn(BaseModel):
    student_name: str = Field(min_length=1, max_length=255)
    paper_signature: str = Field(min_length=1, max_length=512)
    question_id: str = Field(min_length=1, max_length=128)
    selected: bool | None = None
    viewed: bool | None = None
    solved: bool | None = None
    answer: str | None = None
    phrase: str | None = None
    answer_lines: str | None = None
    strokes: str | None = None
    updated_at_ms: int | None = Field(default=None, ge=0)


class MathsdrillPaperStateOut(BaseModel):
    id: int
    student_name: str
    paper_signature: str
    question_id: str
    selected: bool
    viewed: bool
    solved: bool
    answer: str | None
    phrase: str | None
    answer_lines: str | None
    strokes: str | None
    updated_at_ms: int | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class MathsdrillSolveIn(BaseModel):
    """A free-text question typed or pasted into the MathsDrill chat."""

    question: str = Field(min_length=1, max_length=500)


class MathsdrillSolveOut(BaseModel):
    """Structured worked solution for the chat.

    Mirrors the mathematics tutor payload so the client gets verified maths
    plus the information needed to draw the matching diagram or graph.
    """

    question: str
    source: str  # "sympy" (verified) | "ai" (model worked it) | "clarification"
    subject: str
    topic: str
    steps: list[dict[str, Any]]
    answer_text: str
    answer_latex: str
    verification_status: str
    verification_detail: str
    visual: dict[str, Any] | None = None
