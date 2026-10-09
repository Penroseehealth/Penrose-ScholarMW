"""API for the Penrose visual physics tutor.

Three endpoints mirror the mathematics tutor:

* ``POST /physics/tutor/solve`` - deterministic worked solution with verified
  steps, a diagram payload, an optional simulation model and graph series.
* ``POST /physics/tutor/explain`` - conversational replies grounded in the
  deterministic solution. The model may only explain, never change a number.
* ``POST /physics/tutor/check`` - inspect a line of the student's working.
"""

from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from app.config.ai_client import AIProviderError, call_ai_json
from app.dependencies.auth import get_current_user
from app.models.models import User
from app.physics.solution_types import PhysicsSolution
from app.physics.tutor import check_working, solve, topics

log = logging.getLogger(__name__)

router = APIRouter(prefix="/physics/tutor", tags=["Physics Tutor"])


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------


class SolveRequest(BaseModel):
    problem: str = Field(min_length=1, max_length=800)


class SolveResponse(BaseModel):
    problem: str
    subject: str
    topic: str
    principle: str
    given: list[dict[str, Any]]
    find: list[str]
    steps: list[dict[str, Any]]
    final_answer_latex: str
    final_answer_text: str
    verification_status: str
    verification_detail: str
    warnings: list[str]
    visual: dict[str, Any] | None = None
    simulation: dict[str, Any] | None = None
    graphs: list[dict[str, Any]] = Field(default_factory=list)


class ChatTurn(BaseModel):
    role: str
    content: str


class ExplainRequest(BaseModel):
    problem: str = Field(min_length=1, max_length=800)
    question: str = Field(min_length=1, max_length=1000)
    solution: dict[str, Any] | None = None
    step_id: int | None = None
    topic: str | None = None
    current_equation: str | None = None
    concepts_explained: list[str] = Field(default_factory=list)
    history: list[ChatTurn] = Field(default_factory=list)


class ExplainResponse(BaseModel):
    reply: str
    step_ref: int | None = None
    source: str


class CheckRequest(BaseModel):
    problem: str = Field(min_length=1, max_length=800)
    student_line: str = Field(min_length=1, max_length=200)


class CheckResponse(BaseModel):
    ok: bool
    message: str
    expected_latex: str = ""
    correction_latex: str = ""
    step_ref: int | None = None


class TopicsResponse(BaseModel):
    topics: list[str]


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.post("/solve", response_model=SolveResponse)
async def solve_problem(
    payload: SolveRequest, user: User = Depends(get_current_user)
) -> SolveResponse:
    """Solve a problem deterministically and return verified, structured steps."""
    solution: PhysicsSolution = solve(payload.problem)
    return SolveResponse(**solution.to_dict())


@router.get("/topics", response_model=TopicsResponse)
async def list_topics(user: User = Depends(get_current_user)) -> TopicsResponse:
    """List the physics topics the deterministic engine can solve."""
    return TopicsResponse(topics=topics())


_EXPLAIN_SYSTEM = """You are a university-level physics tutor speaking with a \
student one on one. You are given a problem and the VERIFIED step-by-step \
solution produced by a deterministic physics engine that has already checked \
every number against the relevant physical law.

ABSOLUTE RULES
1. Never invent, alter or recompute any number, unit, vector or result. The \
solution you are given is already verified; you only explain it.
2. Never output raw LaTeX to the student. Use these delimiters only: \\( ... \\) \
for inline maths and \\[ ... \\] for display maths. Plain words everywhere else.
3. Be conversational and warm, like a good tutor beside the student. Two or \
three sentences is usually right.
4. If the question refers to a step ("why did you do that", "step 3"), set \
step_ref to that step's number. Otherwise use null.
5. Always keep the physical meaning in view: name the law, then the reasoning \
about forces, fields or energy behind it.
6. If the student's own working is wrong, say so kindly, name the operation \
that went wrong, and explain the rule that fixes it.

Respond with JSON only:
{"reply": "...", "step_ref": 3 or null}
"""


def _solution_brief(solution: dict[str, Any] | None) -> str:
    if not solution:
        return "No solution is currently on screen."
    lines = [f"Problem: {solution.get('problem', '')}"]
    principle = solution.get("principle")
    if principle:
        lines.append(f"Principle: {principle}")
    for step in solution.get("steps", []) or []:
        latex = " ".join(step.get("latex_lines") or [])
        lines.append(
            f"Step {step.get('id')} - {step.get('title')}: {step.get('explanation', '')}"
            + (f" [{latex}]" if latex else "")
        )
    lines.append(f"Verified answer: {solution.get('final_answer_latex', '')}")
    lines.append(f"Verification: {solution.get('verification_detail', '')}")
    return "\n".join(lines)


def _deterministic_reply(payload: ExplainRequest) -> tuple[str, int | None]:
    """Explain without a model, so the tutor panel never goes silent."""
    question = payload.question.strip()
    steps = (payload.solution or {}).get("steps") or []
    lowered = question.lower()

    if steps:
        target: dict[str, Any] | None = None
        if payload.step_id:
            target = next((s for s in steps if s.get("id") == payload.step_id), None)
        if target is None:
            for word in question.replace("?", " ").split():
                if word.isdigit() and 0 < int(word) <= len(steps):
                    target = steps[int(word) - 1]
                    break
        if target is not None and (
            any(word in lowered for word in ("why", "how", "step", "explain", "what"))
            or target.get("id") == payload.step_id
        ):
            return (
                target.get("explanation") or target.get("narration", ""),
                target.get("id"),
            )

        if any(word in lowered for word in ("answer", "result", "final")):
            return (
                "The verified answer is "
                f"{payload.solution.get('final_answer_text') or payload.solution.get('final_answer_latex')}. "
                + str(payload.solution.get("verification_detail", ""))
            ).strip(), None

        if any(word in lowered for word in ("again", "repeat", "read")) and steps:
            first = steps[0]
            return (
                first.get("narration") or first.get("explanation", ""),
                first.get("id"),
            )

    return (
        "Let us work through this together. Ask me to explain any step, or tell "
        "me which part of the working you would like me to go through again."
    ), None


def _context_block(payload: ExplainRequest) -> str:
    lines: list[str] = []
    if payload.topic:
        lines.append(f"Current topic: {payload.topic}")
    if payload.current_equation:
        lines.append(f"Current equation: {payload.current_equation}")
    if payload.step_id:
        lines.append(f"Current step: {payload.step_id}")
    if payload.concepts_explained:
        lines.append(
            "Concepts already explained: " + ", ".join(payload.concepts_explained)
        )
    return "\n".join(lines)


@router.post("/explain", response_model=ExplainResponse)
async def explain_step(
    payload: ExplainRequest, user: User = Depends(get_current_user)
) -> ExplainResponse:
    """Answer a conversational question about the current solution."""
    context = _context_block(payload)
    messages: list[dict[str, str]] = [
        {"role": "system", "content": _EXPLAIN_SYSTEM},
        {
            "role": "user",
            "content": (
                "VERIFIED SOLUTION\n"
                f"{_solution_brief(payload.solution)}\n\n"
                + (f"CURRENT CONTEXT\n{context}\n\n" if context else "")
                + f"STUDENT QUESTION: {payload.question}"
            ),
        },
    ]
    for turn in payload.history[-6:]:
        if turn.role in {"user", "assistant"} and turn.content.strip():
            messages.append({"role": turn.role, "content": turn.content})

    try:
        parsed = await call_ai_json(messages, max_tokens=600, temperature=0.3)
    except (AIProviderError, RuntimeError, ValueError, TimeoutError, OSError) as exc:
        log.info("Falling back to deterministic explanation: %s", exc)
        reply, step_ref = _deterministic_reply(payload)
        return ExplainResponse(reply=reply, step_ref=step_ref, source="deterministic")

    if not isinstance(parsed, dict):
        reply, step_ref = _deterministic_reply(payload)
        return ExplainResponse(reply=reply, step_ref=step_ref, source="deterministic")

    reply = str(parsed.get("reply") or "").strip()
    if not reply:
        fallback, step_ref = _deterministic_reply(payload)
        return ExplainResponse(
            reply=fallback, step_ref=step_ref, source="deterministic"
        )

    raw_ref = parsed.get("step_ref")
    step_ref: int | None = None
    if isinstance(raw_ref, int):
        count = len((payload.solution or {}).get("steps") or [])
        step_ref = raw_ref if 1 <= raw_ref <= max(count, 1) else None

    return ExplainResponse(reply=reply, step_ref=step_ref, source="ai")


@router.post("/check", response_model=CheckResponse)
async def check_student_working(
    payload: CheckRequest, user: User = Depends(get_current_user)
) -> CheckResponse:
    """Inspect a line of the student's own working and explain any mistake."""
    result = check_working(payload.problem, payload.student_line)
    return CheckResponse(
        ok=result.ok,
        message=result.message,
        expected_latex=result.expected_latex,
        correction_latex=result.correction_latex,
        step_ref=result.step_ref,
    )
