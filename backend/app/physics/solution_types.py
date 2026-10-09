"""Structured output types for the physics tutor.

The contract deliberately mirrors :mod:`app.mathematics.solution_types` so the
Flutter workspace can share the step-board, narration player and verification
badge with the maths tutor, while adding the physics-specific fields: the
given and required quantities, the physical principle, a diagram payload, a
simulation model and graph series.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class PhysicsStep:
    """One renderable, explainable and speakable step."""

    id: int
    title: str
    explanation: str
    narration: str
    latex_lines: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "title": self.title,
            "explanation": self.explanation,
            "narration": self.narration,
            "latex_lines": self.latex_lines,
        }


@dataclass
class PhysicsSolution:
    """A complete, verified physics worked solution."""

    problem: str
    topic: str
    steps: list[PhysicsStep]
    final_answer_latex: str
    final_answer_text: str
    subject: str = "physics"
    principle: str = ""
    given: list[dict[str, Any]] = field(default_factory=list)
    find: list[str] = field(default_factory=list)
    verification_status: str = "unverified"
    verification_detail: str = ""
    warnings: list[str] = field(default_factory=list)
    visual: dict[str, Any] | None = None
    simulation: dict[str, Any] | None = None
    graphs: list[dict[str, Any]] = field(default_factory=list)

    @property
    def is_clarification(self) -> bool:
        return self.topic == "needs_more_information"

    def to_dict(self) -> dict[str, Any]:
        return {
            "problem": self.problem,
            "subject": self.subject,
            "topic": self.topic,
            "principle": self.principle,
            "given": self.given,
            "find": self.find,
            "steps": [step.to_dict() for step in self.steps],
            "final_answer_latex": self.final_answer_latex,
            "final_answer_text": self.final_answer_text,
            "verification_status": self.verification_status,
            "verification_detail": self.verification_detail,
            "warnings": self.warnings,
            "visual": self.visual,
            "simulation": self.simulation,
            "graphs": self.graphs,
        }


def given_entry(symbol: str, quantity_value: Any, latex: str) -> dict[str, Any]:
    """Shape one row of the Given table."""
    return {"symbol": symbol, "latex": latex, "quantity": quantity_value}


def clarification(problem: str, question: str) -> PhysicsSolution:
    """A question back to the student instead of a fabricated answer."""
    step = PhysicsStep(
        id=1,
        title="I need one more detail",
        explanation=question,
        narration=question,
    )
    return PhysicsSolution(
        problem=problem,
        topic="needs_more_information",
        subject="clarification",
        steps=[step],
        final_answer_latex="",
        final_answer_text="",
    )
