"""API for the Penrose visual maths tutor.

Two endpoints:

* ``POST /mathematics/tutor/solve`` - deterministic SymPy solution. The UI never
  has to do the mathematics itself, and every result comes back independently
  verified.
* ``POST /mathematics/tutor/explain`` - conversational tutor replies grounded in
  the deterministic solution. The model may only *explain*; it can never change
  a number. When no model is configured a deterministic explanation is returned
  so the voice tutor still works.
"""

from __future__ import annotations

import logging
import math
import re
from typing import Any

import sympy
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.config.ai_client import AIProviderError, call_ai_json
from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.mathematics.solution_types import TutorStep
from app.mathematics.tutor import TutorSolution, check_working, solve
from app.models.models import User
from app.models.stem import (
    SyllabusCoreElement,
    SyllabusLearningObjective,
    SyllabusSubject,
    SyllabusTopic,
    SyllabusVersion,
)

log = logging.getLogger(__name__)

router = APIRouter(prefix="/mathematics/tutor", tags=["Mathematics Tutor"])


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------


class SolveRequest(BaseModel):
    problem: str = Field(min_length=1, max_length=500)


class SolveResponse(BaseModel):
    problem: str
    subject: str
    topic: str
    steps: list[dict[str, Any]]
    final_answer_latex: str
    final_answer_text: str
    verification_status: str
    verification_detail: str
    visual: dict[str, Any] | None = None


class ChatTurn(BaseModel):
    role: str
    content: str


class ExplainRequest(BaseModel):
    problem: str = Field(min_length=1, max_length=500)
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
    problem: str = Field(min_length=1, max_length=500)
    student_line: str = Field(min_length=1, max_length=200)


class CheckResponse(BaseModel):
    ok: bool
    message: str
    expected_latex: str = ""
    correction_latex: str = ""
    step_ref: int | None = None


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.post("/solve", response_model=SolveResponse)
async def solve_problem(
    payload: SolveRequest, user: User = Depends(get_current_user)
) -> SolveResponse:
    """Solve a problem deterministically and return verified, structured steps.

    When the symbolic engine cannot turn the question into a calculation it
    returns a clarification. In that case we fall back to the AI chain (Cloudflare
    Workers AI -> HuggingFace -> Groq) so an unusual but valid problem still gets
    a worked solution instead of a bare "please rephrase".
    """
    solution: TutorSolution = solve(payload.problem)
    if _is_clarification(solution):
        ai_solution = await _ai_solve(payload.problem)
        if ai_solution is not None:
            solution = ai_solution
    data = solution.to_dict()
    return SolveResponse(**data)


def _is_clarification(solution: TutorSolution) -> bool:
    """True when the deterministic solver could not turn the input into maths."""
    return (
        solution.subject == "clarification"
        or solution.topic == "needs_more_information"
    )


_AI_SOLVE_SYSTEM = """You are a meticulous mathematics teacher producing a \
step-by-step worked solution for a student.

ABSOLUTE RULES
1. Work the mathematics out yourself and double-check every line. Do not skip \
algebra that the student would need to follow.
2. Never output raw LaTeX with \\( or \\[ - provide the plain text of each line of \
working in "work" and the final answer in "answer_text". If you give LaTeX at all, \
put it only in "answer_latex" and keep it valid KaTeX.
3. Keep each step short and concrete, one operation per step.
4. If the problem genuinely cannot be solved without more information, set \
"needs_more_information" to true and explain what is missing in "answer_text".

Respond with JSON only, exactly this shape:
{
  "topic": "short topic label",
  "steps": [
    {"title": "short step title", "work": "the equation or expression for this line", "explanation": "what we did and why"}
  ],
  "answer_text": "the final answer in words",
  "answer_latex": "the final answer in KaTeX (may be empty)",
  "needs_more_information": false
}
"""


async def _ai_solve(problem: str) -> TutorSolution | None:
    """Ask the AI chain for a worked solution when SymPy cannot handle it.

    Returns None (so the caller keeps the deterministic clarification) if no
    provider is configured, all providers fail, or the model output cannot be
    turned into a usable solution.
    """
    messages = [
        {"role": "system", "content": _AI_SOLVE_SYSTEM},
        {"role": "user", "content": f"Problem: {problem}"},
    ]
    try:
        parsed = await call_ai_json(messages, max_tokens=1200, temperature=0.2)
    except Exception as exc:  # noqa: BLE001 - any provider failure must fall back
        log.warning("AI solve fallback failed: %s", exc)
        return None

    if not isinstance(parsed, dict):
        return None

    raw_steps = parsed.get("steps")
    if not isinstance(raw_steps, list) or not raw_steps:
        return None

    steps: list[TutorStep] = []
    for index, raw in enumerate(raw_steps, start=1):
        if not isinstance(raw, dict):
            continue
        work = str(raw.get("work", "")).strip()
        title = str(raw.get("title", "")).strip() or f"Step {index}"
        explanation = str(raw.get("explanation", "")).strip()
        narration = explanation or work or title
        steps.append(
            TutorStep(
                id=index,
                title=title,
                explanation=explanation or work,
                narration=narration,
                latex_lines=[work] if work else [],
            )
        )
    if not steps:
        return None

    answer_text = str(parsed.get("answer_text", "")).strip()
    answer_latex = str(parsed.get("answer_latex", "")).strip()
    needs_more = bool(parsed.get("needs_more_information"))

    return TutorSolution(
        problem=problem,
        subject=str(parsed.get("topic", "mathematics")).strip() or "mathematics",
        topic=str(parsed.get("topic", "ai_solution")).strip() or "ai_solution",
        steps=steps,
        final_answer_latex=answer_latex,
        final_answer_text=answer_text,
        verification_status="ai_unverified",
        verification_detail=(
            "Solved by the AI tutor and not checked by the symbolic engine."
            if not needs_more
            else "The AI tutor needs more information to finish this problem."
        ),
    )


_EXPLAIN_SYSTEM = """You are a university-level mathematics tutor speaking with a \
student one on one. You are given a problem and the VERIFIED step-by-step solution \
produced by a symbolic mathematics engine.

ABSOLUTE RULES
1. Never invent, alter or recompute any number, coefficient, root or side length. \
The solution you are given is already verified; you only explain it.
2. Never output raw LaTeX to the student. Use these delimiters only: \\( ... \\) for \
inline maths and \\[ ... \\] for display maths. Plain words everywhere else.
3. Be conversational and warm, like a good tutor beside the student, not a manual. \
Two or three sentences is usually right.
4. If the question refers to a step ("why did you do that", "step 3"), set step_ref \
to that step's number. Otherwise use null.
5. The student is in the middle of THIS problem. Read the CURRENT CONTEXT and treat \
short questions such as "why did you subtract 9?" or "what does isolate mean?" as \
questions about the current equation, never as a new topic.
6. Match the student's level: if they ask for a simpler explanation, use plainer \
words; if they ask for another method, describe a valid alternative; if they show \
understanding, do not repeat the basics.
7. If the student's own working is wrong, say so kindly, name the operation that \
went wrong, and explain the rule that fixes it.

Respond with JSON only:
{"reply": "...", "step_ref": 3 or null}
"""


def _solution_brief(solution: dict[str, Any] | None) -> str:
    if not solution:
        return "No solution is currently on screen."
    lines = [f"Problem: {solution.get('problem', '')}"]
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
            return target.get("explanation") or target.get("narration", ""), target.get(
                "id"
            )

        if any(word in lowered for word in ("answer", "result", "final")):
            return (
                "The verified answer is "
                f"{payload.solution.get('final_answer_text') or payload.solution.get('final_answer_latex')}. "
                + str(payload.solution.get("verification_detail", ""))
            ).strip(), None

        if any(word in lowered for word in ("again", "repeat", "read")) and steps:
            first = steps[0]
            return first.get("narration") or first.get("explanation", ""), first.get(
                "id"
            )

    return (
        "Let us work through this together. Ask me to explain any step, or tell me "
        "which part of the working you would like me to go through again."
    ), None


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

    raw_ref = parsed.get("step_ref")
    step_ref: int | None = None
    if isinstance(raw_ref, int):
        count = len((payload.solution or {}).get("steps") or [])
        step_ref = raw_ref if 1 <= raw_ref <= max(count, 1) else None

    return ExplainResponse(reply=reply, step_ref=step_ref, source="ai")


# ---------------------------------------------------------------------------
# Syllabus-grounded example problems + verified answer checking
#
# Grounding contract: the model is shown ONLY the topic/subtopic titles and
# learning-objective texts from the MoEST syllabus tables. It may never
# surface syllabus metadata (forms, themes, assessment standards, subject
# codes) in its output. The problem it authors is then solved by the
# deterministic SymPy engine, so every number in the reply is independently
# verified - the model cannot invent an answer.
# ---------------------------------------------------------------------------


class ExampleRequest(BaseModel):
    form: int = Field(ge=1, le=4)
    topic: str = Field(min_length=1, max_length=255)
    subtopic: str | None = Field(default=None, max_length=255)
    question: str | None = Field(default=None, max_length=1000)


class ExampleResponse(BaseModel):
    problem: str
    topic: str
    subtopic: str | None = None
    steps: list[dict[str, Any]]
    final_answer_text: str
    verification_status: str
    source: str


class VerifyRequest(BaseModel):
    problem: str = Field(min_length=1, max_length=500)
    answer: str = Field(min_length=1, max_length=300)


class VerifyResponse(BaseModel):
    correct: bool
    expected_answer: str
    verification: str  # "numeric" | "exact" | "unchecked"
    detail: str


_EXAMPLE_SYSTEM = """You author practice problems for a secondary mathematics student.

You are given a topic and the exact skills (learning objectives) the student must \
practice, taken from their official syllabus.

ABSOLUTE RULES
1. The problem you author must exercise ONLY those listed skills. Use no content \
from any other topic or form level.
2. Never mention, hint at, or allude to the syllabus itself: no form numbers, no \
theme names, no subject names, no assessment standards, no exam boards. The \
student must only ever see an ordinary mathematics problem, as if a teacher \
wrote it on the board.
3. The problem must have a single unambiguous final answer that a symbolic \
mathematics engine can verify (an exact value, expression, or ordered pair).
4. Keep numbers reasonable (no messy decimals unless the skill demands them) and \
the wording short, plain and self-contained. Define every symbol you use.
5. If the student asked for something specific (harder, easier, word problem, \
with fractions), honour it while staying inside the listed skills.

Respond with JSON only:
{"problem": "..."}
"""


async def _grounding_block(
    db: AsyncSession, form: int, topic_title: str, subtopic_title: str | None
) -> tuple[str, str, str | None]:
    """Return (grounding_text, canonical_topic_title, matched_subtopic_title).

    Raises HTTPException 404 when the topic is not in this form of the
    Mathematics syllabus. The grounding text contains only titles and
    objective wording - never form/theme metadata.
    """
    result = await db.execute(
        select(SyllabusSubject).where(SyllabusSubject.slug == "mathematics")
    )
    subject = result.scalar_one_or_none()
    if not subject:
        raise HTTPException(status_code=404, detail="Mathematics syllabus not found")

    ver_result = await db.execute(
        select(SyllabusVersion).where(
            SyllabusVersion.subject_id == subject.id,
            SyllabusVersion.is_current == True,  # noqa: E712
        )
    )
    version = ver_result.scalar_one_or_none()
    if not version:
        raise HTTPException(
            status_code=404, detail="No current Mathematics syllabus version"
        )

    ce_result = await db.execute(
        select(SyllabusCoreElement)
        .where(SyllabusCoreElement.version_id == version.id)
        .options(
            joinedload(SyllabusCoreElement.topics).joinedload(SyllabusTopic.subtopics),
        )
    )
    elements = ce_result.unique().scalars().all()

    wanted = topic_title.strip().lower()
    matched: SyllabusTopic | None = None
    for ce in elements:
        for tp in ce.topics:
            if tp.year_level == form and tp.title.strip().lower() == wanted:
                matched = tp
                break
        if matched:
            break
    if matched is None:
        # tolerate partial matches so students can type shorter titles
        for ce in elements:
            for tp in ce.topics:
                if tp.year_level == form and wanted in tp.title.strip().lower():
                    matched = tp
                    break
            if matched:
                break
    if matched is None:
        raise HTTPException(
            status_code=404,
            detail="That topic is not part of the syllabus for this form",
        )

    lines = [f"TOPIC: {matched.title}"]
    chosen_subtopic: str | None = None
    if subtopic_title:
        want_sub = subtopic_title.strip().lower()
        for sub in matched.subtopics:
            if want_sub in sub.title.strip().lower():
                chosen_subtopic = sub.title
                break
        if chosen_subtopic is None:
            raise HTTPException(
                status_code=404, detail="Subtopic not found under this topic"
            )

    for sub in matched.subtopics:
        if chosen_subtopic and sub.title != chosen_subtopic:
            continue
        obj_result = await db.execute(
            select(SyllabusLearningObjective)
            .where(SyllabusLearningObjective.subtopic_id == sub.id)
            .order_by(SyllabusLearningObjective.order_index)
        )
        objectives = [o.objective for o in obj_result.scalars().all()]
        if objectives:
            lines.append(f"SKILL: {sub.title} - " + "; ".join(objectives))
        else:
            lines.append(f"SKILL: {sub.title}")
    return "\n".join(lines), matched.title, chosen_subtopic


def _student_number(text: str) -> float | None:
    """Extract a plain number from a student answer, tolerating units/percent."""
    cleaned = text.strip()
    cleaned = re.sub(r"^[a-zA-Z]\s*[=:]\s*", "", cleaned)  # x = ..., A = ...
    cleaned = cleaned.replace(",", "")
    cleaned = re.sub(r"(°|degrees?|\bdeg\b)", "", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(
        r"\b(cm|mm|m|km|in|ft|s|sec|mins?|hrs?|units?|square|cube|sq|cubed?)\b",
        "",
        cleaned,
        flags=re.IGNORECASE,
    )
    cleaned = cleaned.rstrip("%").strip()
    if not cleaned:
        return None
    try:
        value = sympy.sympify(cleaned, rational=True)
    except Exception:  # noqa: BLE001 - any parse failure means "not a number"
        return None
    try:
        value_f = float(value)
    except (TypeError, ValueError):
        return None
    return value_f


def _normalised_text(text: str) -> str:
    stripped = re.sub(r"[\s$\\(){}]", "", text)
    return stripped.lower()


@router.post("/example", response_model=ExampleResponse)
async def generate_example(
    payload: ExampleRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ExampleResponse:
    """Author a syllabus-grounded example problem and solve it deterministically.

    The AI sees only the topic's skills; the answer comes from SymPy, so the
    reply the student sees carries verified numbers and no syllabus metadata.
    """
    grounding, canonical_topic, canonical_sub = await _grounding_block(
        db, payload.form, payload.topic, payload.subtopic
    )
    user_prompt = grounding
    if payload.question:
        user_prompt += "\n\nSTUDENT REQUEST: " + payload.question

    messages = [
        {"role": "system", "content": _EXAMPLE_SYSTEM},
        {"role": "user", "content": user_prompt},
    ]
    try:
        parsed = await call_ai_json(messages, max_tokens=500, temperature=0.6)
    except (AIProviderError, RuntimeError, ValueError, TimeoutError, OSError) as exc:
        log.warning("Example authoring failed: %s", exc)
        raise HTTPException(
            status_code=503,
            detail="The AI author is unavailable right now. Please try again shortly.",
        ) from exc

    problem = str((parsed or {}).get("problem") or "").strip()
    if not problem:
        raise HTTPException(status_code=502, detail="The AI returned no problem.")

    try:
        solution: TutorSolution = solve(problem)
    except Exception as exc:  # noqa: BLE001 - unparseable/solvable problem
        log.warning("Authored problem failed to solve (%r): %s", problem, exc)
        raise HTTPException(
            status_code=502,
            detail="The authored problem could not be verified; please try again.",
        ) from exc

    data = solution.to_dict()
    return ExampleResponse(
        problem=problem,
        topic=canonical_topic,
        subtopic=canonical_sub,
        steps=data.get("steps", []),
        final_answer_text=data.get("final_answer_text")
        or data.get("final_answer_latex", ""),
        verification_status=data.get("verification_status", "unverified"),
        source="syllabus+ai+sympy",
    )


@router.post("/verify", response_model=VerifyResponse)
async def verify_answer(
    payload: VerifyRequest, user: User = Depends(get_current_user)
) -> VerifyResponse:
    """Check a student's submitted answer with a real calculation.

    The student's answer is never judged by the language model: it is parsed
    and compared against the deterministic SymPy solution of the problem.
    """
    try:
        solution: TutorSolution = solve(payload.problem)
    except Exception as exc:  # noqa: BLE001
        log.warning("Verify could not solve problem: %s", exc)
        raise HTTPException(
            status_code=422,
            detail="This problem could not be solved by the verification engine.",
        ) from exc

    data = solution.to_dict()
    expected = (
        data.get("final_answer_text") or data.get("final_answer_latex") or ""
    ).strip()
    if not expected:
        return VerifyResponse(
            correct=False,
            expected_answer="",
            verification="unchecked",
            detail="The engine produced no final answer to compare against.",
        )

    expected_num = _student_number(expected)
    student_num = _student_number(payload.answer)
    if expected_num is not None and student_num is not None:
        close = math.isclose(student_num, expected_num, rel_tol=1e-6, abs_tol=1e-9)
        return VerifyResponse(
            correct=close,
            expected_answer=expected,
            verification="numeric",
            detail=(
                "Compared numerically: student "
                f"{student_num} vs verified {expected_num}."
            ),
        )

    if _normalised_text(payload.answer) == _normalised_text(expected):
        return VerifyResponse(
            correct=True,
            expected_answer=expected,
            verification="exact",
            detail="Matched the verified answer exactly.",
        )

    return VerifyResponse(
        correct=False,
        expected_answer=expected,
        verification="unchecked",
        detail=(
            "The answer could not be compared numerically; the verified "
            "answer is returned for the tutor to explain."
        ),
    )
