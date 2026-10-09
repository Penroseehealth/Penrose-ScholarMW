"""Structured output types for the mathematics tutor.

These live in their own module so that the topic solvers in
:mod:`app.mathematics.topic_solvers` can build solutions without importing the
dispatcher in :mod:`app.mathematics.tutor`, which imports them in turn.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class TutorStep:
    """One renderable, explainable and speakable step."""

    id: int
    title: str
    explanation: str
    narration: str
    latex_lines: list[str] = field(default_factory=list)


@dataclass
class TutorSolution:
    problem: str
    subject: str
    topic: str
    steps: list[TutorStep]
    final_answer_latex: str
    final_answer_text: str
    verification_status: str = "unverified"
    verification_detail: str = ""
    visual: dict[str, Any] | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "problem": self.problem,
            "subject": self.subject,
            "topic": self.topic,
            "steps": [
                {
                    "id": step.id,
                    "title": step.title,
                    "explanation": step.explanation,
                    "narration": step.narration,
                    "latex_lines": step.latex_lines,
                }
                for step in self.steps
            ],
            "final_answer_latex": self.final_answer_latex,
            "final_answer_text": self.final_answer_text,
            "verification_status": self.verification_status,
            "verification_detail": self.verification_detail,
            "visual": self.visual,
        }
