"""Regression tests for the mathematics generation/validation pipeline.

Covers the brief's minimum categories: valid questions accepted, vague or
incomplete questions rejected, incorrect worked solutions rejected, missing
information detected, and the exact defective semicircle question from the
bug report failing validation.
"""

from __future__ import annotations

import asyncio

import pytest

from app.examinations_builder.math_validate import (
    is_mathematics,
    validate_math_question,
    validation_status,
)
from app.examinations_builder.service import (
    MathGenerationError,
    _normalise_ai_question,
    generate_questions,
)
from app.examinations_builder.schemas import ExamBuilderConfig

DEFECTIVE_SEMICIRCLE = (
    "Carry out a calculation related to the theorem: the angle in a semicircle "
    "is a right angle. Show all your working and give your final answer with "
    "the correct units."
)

VALID_SEMICIRCLE = (
    "A, B and C lie on a circle, centre O. AB is a diameter and angle "
    "BAC = 32 degrees. Calculate angle ABC, giving a reason for your answer."
)

VAGUE_CALC = (
    "Carry out a calculation related to quadratic equations. Show all your "
    "working and give your final answer with the correct units."
)


def _q(text: str, q_type: str = "calculation", **extra) -> dict:
    base = {
        "id": "t1",
        "question_type": q_type,
        "question_text": text,
        "options": [],
        "correct_answer": "",
        "marks": 5,
        "difficulty": "medium",
        "bloom_level": "Applying",
        "learning_outcome": "",
        "rubric": "",
        "reference": "",
    }
    base.update(extra)
    return base


# ── Category: geometry (circle theorems) ────────────────────────────────────


def test_defective_semicircle_question_rejected():
    problems = validate_math_question(_q(DEFECTIVE_SEMICIRCLE))
    assert problems, "The exact defective semicircle question must fail validation"
    assert any("placeholder" in p for p in problems)


def test_valid_semicircle_question_accepted():
    q = _q(
        VALID_SEMICIRCLE,
        worked_solution="angle ACB = 90 (angle in semicircle); angle ABC = 180 - 90 - 32 = 58",
        final_answer="58",
        units="degrees",
    )
    assert validate_math_question(q) == []
    assert validation_status(q) == "structural"  # geometry: not SymPy-verified


def test_theorem_mention_without_task_rejected():
    q = _q(
        "The angle in a semicircle is a right angle.",
        q_type="structured",
    )
    problems = validate_math_question(q)
    assert any("specific unknown" in p for p in problems)


def test_calculation_without_numbers_rejected():
    problems = validate_math_question(_q(VAGUE_CALC, q_type="calculation"))
    assert problems
    assert any("placeholder" in p or "No numerical data" in p for p in problems)


def test_proof_style_question_without_numbers_accepted():
    q = _q(
        "Simplify the expression (x + 3)(x - 3) and show that it equals x^2 - 9.",
        q_type="short_answer",
        final_answer="x^2 - 9",
        equations_or_expressions=["(x + 3)(x - 3)"],
    )
    assert validate_math_question(q) == []


# ── Category: algebra (SymPy verification) ─────────────────────────────────


def test_correct_answer_verified_by_sympy():
    q = _q(
        "Solve for x: 2x + 3 = 11.",
        equations_or_expressions=["2x + 3 = 11"],
        final_answer="x = 4",
    )
    problems = validate_math_question(q)
    assert problems == []
    assert validation_status(q) == "sympy_verified"


def test_incorrect_worked_solution_rejected():
    q = _q(
        "Solve for x: 2x + 3 = 11.",
        equations_or_expressions=["2x + 3 = 11"],
        final_answer="x = 7",
    )
    problems = validate_math_question(q)
    assert any("does not satisfy" in p for p in problems)


def test_fraction_answer_verified():
    q = _q(
        "Solve for y: 3y = 4.",
        equations_or_expressions=["3y = 4"],
        final_answer="y = 4/3",
    )
    assert validate_math_question(q) == []


# ── Category: no determinate ask ────────────────────────────────────────────


def test_statement_without_ask_rejected():
    q = _q("A triangle has sides 3 cm, 4 cm and 5 cm.", q_type="calculation")
    problems = validate_math_question(q)
    assert any("specific unknown" in p for p in problems)


# ── Pipeline behaviour (mocked provider) ───────────────────────────────────


def test_provider_failure_for_math_raises_no_fallback(monkeypatch):
    """AI failure for Mathematics must raise, never return template questions."""
    from app.config.ai_client import AIProviderError
    from app.examinations_builder import service

    async def _fail(messages, **kwargs):
        raise AIProviderError([("mock", RuntimeError("provider down"))])

    monkeypatch.setattr(service, "call_ai_json", _fail)
    cfg = ExamBuilderConfig(
        subject="Mathematics",
        form=4,
        topic="Circle theorems",
        num_questions=5,
        question_types=["calculation"],
        learning_objectives=["Use circle theorems to calculate angles"],
    )
    with pytest.raises(MathGenerationError):
        asyncio.run(generate_questions(cfg, None))


def test_generic_math_response_rejected_and_never_shown(monkeypatch):
    """A provider returning the defective template must raise, not display it."""
    from app.examinations_builder import service

    async def _generic(messages, **kwargs):
        return {
            "questions": [
                {
                    "question_type": "calculation",
                    "question_text": DEFECTIVE_SEMICIRCLE,
                    "options": [],
                    "correct_answer": "",
                    "marks": 6,
                    "difficulty": "hard",
                }
            ]
        }

    monkeypatch.setattr(service, "call_ai_json", _generic)
    monkeypatch.setattr(
        service,
        "_repair_math_questions",
        _async([]),  # repair round returns nothing usable
    )
    cfg = ExamBuilderConfig(
        subject="Mathematics",
        form=4,
        topic="Circle theorems",
        num_questions=3,
        question_types=["calculation"],
        learning_objectives=["Use circle theorems"],
    )
    with pytest.raises(MathGenerationError):
        asyncio.run(generate_questions(cfg, None))


def test_valid_math_response_passes_with_structured_fields(monkeypatch):
    """A validated structured response flows through with its fields intact."""
    from app.examinations_builder import service

    payload = {
        "questions": [
            {
                "question_type": "calculation",
                "question_text": VALID_SEMICIRCLE,
                "options": [],
                "correct_answer": "58",
                "marks": 5,
                "difficulty": "medium",
                "topic": "Geometry",
                "subtopic": "Circle theorems",
                "given_information": "AB is a diameter; angle BAC = 32 degrees",
                "required_unknown": "angle ABC",
                "equations_or_expressions": [],
                "worked_solution": "angle ACB = 90; angle ABC = 180 - 90 - 32 = 58",
                "final_answer": "58",
                "units": "degrees",
                "source_references": [],
            }
        ]
    }

    async def _ok(messages, **kwargs):
        return payload

    monkeypatch.setattr(service, "call_ai_json", _ok)
    cfg = ExamBuilderConfig(
        subject="Mathematics",
        form=4,
        topic="Circle theorems",
        num_questions=1,
        question_types=["calculation"],
        learning_objectives=["Use circle theorems"],
    )
    questions = asyncio.run(generate_questions(cfg, None))
    assert len(questions) == 1
    q = questions[0]
    assert q["given_information"].startswith("AB is a diameter")
    assert q["final_answer"] == "58"
    assert q["validation_status"] == "structural"
    assert q["topic"] == "Geometry"


def test_normaliser_keeps_structured_fields():
    raw = {
        "question_type": "calculation",
        "question_text": VALID_SEMICIRCLE,
        "marks": 5,
        "final_answer": "58",
        "equations_or_expressions": ["angle ABC = 180 - 90 - 32"],
        "units": "degrees",
    }
    q = _normalise_ai_question(raw)
    assert q["final_answer"] == "58"
    assert q["units"] == "degrees"
    assert q["equations_or_expressions"] == ["angle ABC = 180 - 90 - 32"]
    # Non-math subjects unaffected: is_mathematics discipline
    assert is_mathematics("Mathematics") is True
    assert is_mathematics("maths") is True
    assert is_mathematics("Biology") is False


def _async(value):
    async def _inner(*a, **k):
        return value

    return _inner