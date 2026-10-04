"""Tests for the deterministic Penrose mathematics tutor engine."""

from __future__ import annotations

import pytest

from app.mathematics.tutor import check_working, solve


@pytest.mark.parametrize(
    ("problem", "topic", "expected"),
    [
        ("Solve x^2 + 5x + 6 = 0", "quadratic_equation", "-3"),
        ("Solve x^2 - 5x + 6 = 0", "quadratic_equation", "2"),
        ("Solve 3x + 5 = 20", "linear_equation", "5"),
        ("Solve x/4 = 6", "linear_equation", "24"),
        (
            "Find the hypotenuse of a right triangle with legs 3 and 4 cm",
            "pythagorean_theorem",
            "5",
        ),
        (
            "A right triangle has a hypotenuse of 13 cm and one leg 5 cm. Find the other leg",
            "pythagorean_theorem",
            "12",
        ),
        ("What is 15% of 240?", "percentage_of_quantity", "36"),
        ("Calculate 12 + 6 * 2", "arithmetic", "24"),
    ],
)
def test_solve_produces_verified_answers(problem: str, topic: str, expected: str) -> None:
    solution = solve(problem)

    assert solution.topic == topic
    assert solution.verification_status == "verified"
    assert solution.subject in {"algebra", "geometry", "percentage", "arithmetic"}
    assert expected in solution.final_answer_text
    assert solution.final_answer_latex
    assert solution.steps, "every solution must expose steps"


def test_quadratic_steps_are_ordered_and_narrated() -> None:
    solution = solve("Solve x^2 + 5x + 6 = 0")

    assert [step.id for step in solution.steps] == list(range(1, len(solution.steps) + 1))
    assert all(step.narration for step in solution.steps)
    assert all(step.explanation for step in solution.steps)
    assert "ax^{2} + bx + c = 0" in solution.steps[0].latex_lines
    assert solution.visual is not None
    assert solution.visual["kind"] == "parabola"


def test_negative_discriminant_reports_no_real_solutions() -> None:
    solution = solve("Solve x^2 + 1 = 0")

    assert "no real solutions" in solution.final_answer_latex
    assert solution.final_answer_text == "no real solutions"


def test_percentage_visual_is_contextual() -> None:
    solution = solve("What is 15% of 240?")

    assert solution.visual is not None
    assert solution.visual["kind"] == "percentage_bar"


def test_arithmetic_keeps_student_notation_on_screen() -> None:
    solution = solve("Calculate 12 + 6 * 2")

    assert r"\times" in solution.steps[0].latex_lines[0]
    assert solution.steps[0].latex_lines[0].endswith("= ?")


def test_solution_serialises_for_the_api() -> None:
    payload = solve("Solve 2x = 10").to_dict()

    assert payload["problem"] == "Solve 2x = 10"
    assert payload["verification_status"] == "verified"
    assert isinstance(payload["steps"], list)
    assert all({"id", "title", "explanation", "narration"} <= set(s) for s in payload["steps"])


def test_unrecognised_problem_asks_for_clarification() -> None:
    solution = solve("hello there")

    assert solution.topic == "needs_more_information"
    assert solution.verification_status == "unverified"
    assert solution.steps[0].narration
    assert solution.final_answer_latex == ""


# ---------------------------------------------------------------------------
# API surface
# ---------------------------------------------------------------------------


async def test_solve_endpoint_returns_verified_solution(client, student_token) -> None:
    from tests.conftest import auth_header

    response = await client.post(
        "/api/v1/mathematics/tutor/solve",
        json={"problem": "Solve x^2 + 5x + 6 = 0"},
        headers=auth_header(student_token),
    )

    assert response.status_code == 200
    body = response.json()
    assert body["topic"] == "quadratic_equation"
    assert body["verification_status"] == "verified"
    assert "-3" in body["final_answer_text"]
    assert body["visual"]["kind"] == "parabola"
    assert len(body["steps"]) >= 4


async def test_solve_endpoint_requires_authentication(client) -> None:
    response = await client.post(
        "/api/v1/mathematics/tutor/solve", json={"problem": "Solve 2x = 10"}
    )

    assert response.status_code in {401, 403}


async def test_explain_endpoint_falls_back_without_a_model(client, student_token) -> None:
    """The tutor panel must keep answering even when the LLM is unavailable."""
    from tests.conftest import auth_header

    solution = solve("Solve x^2 + 5x + 6 = 0").to_dict()
    response = await client.post(
        "/api/v1/mathematics/tutor/explain",
        json={
            "problem": "Solve x^2 + 5x + 6 = 0",
            "question": "Why do we use the quadratic formula?",
            "step_id": 2,
            "solution": solution,
        },
        headers=auth_header(student_token),
    )

    assert response.status_code == 200
    body = response.json()
    assert body["reply"]
    assert body["source"] in {"ai", "deterministic"}


# ---------------------------------------------------------------------------
# Live, student-friendly linear steps (specification tests A and E)
# ---------------------------------------------------------------------------


def test_linear_solution_writes_like_a_human() -> None:
    solution = solve("Solve 2x + 9 = 24")

    assert solution.topic == "linear_equation"
    assert solution.steps[0].latex_lines == ["2 x + 9 = 24"]
    assert solution.steps[1].latex_lines == ["2 x = 24 - 9", "2 x = 15"]
    assert solution.steps[2].latex_lines == ["x = \\frac{15}{2}", "x = 7.5"]
    assert solution.steps[-1].title == "Check the answer"
    assert solution.steps[-1].latex_lines[-1] == "24 = 24"
    assert solution.final_answer_text == "x = 7.5"


def test_linear_verification_substitutes_the_answer() -> None:
    solution = solve("Solve 2x + 9 = 24")

    verify = solution.steps[-1].latex_lines
    assert "2 \\cdot 7.5 + 9 = 24" in verify
    assert "15 + 9 = 24" in verify
    assert solution.verification_status == "verified"


def test_linear_steps_are_sequential_and_each_has_voice() -> None:
    solution = solve("Solve 2x + 9 = 24")

    assert [step.id for step in solution.steps] == list(range(1, len(solution.steps) + 1))
    assert all(step.narration for step in solution.steps)
    assert all(step.explanation for step in solution.steps)


# ---------------------------------------------------------------------------
# Student working checker (specification test D)
# ---------------------------------------------------------------------------


def test_check_working_detects_the_wrong_operation() -> None:
    result = check_working("Solve 2x + 9 = 24", "2x = 33")

    assert result.ok is False
    assert "subtract" in result.message
    assert "9" in result.message
    assert result.correction_latex == "x = 7.5"
    assert result.step_ref == 2


def test_check_working_accepts_a_correct_line() -> None:
    result = check_working("Solve 2x + 9 = 24", "2x = 15")

    assert result.ok is True


def test_check_working_catches_adding_instead_of_subtracting() -> None:
    result = check_working("Solve 2x + 9 = 24", "2x = 24 + 9")

    assert result.ok is False
    assert "subtract" in result.message


async def test_check_endpoint_returns_a_correction(client, student_token) -> None:
    from tests.conftest import auth_header

    response = await client.post(
        "/api/v1/mathematics/tutor/check",
        json={"problem": "Solve 2x + 9 = 24", "student_line": "2x = 33"},
        headers=auth_header(student_token),
    )

    assert response.status_code == 200
    body = response.json()
    assert body["ok"] is False
    assert "subtract" in body["message"]
    assert body["correction_latex"] == "x = 7.5"


async def test_explain_endpoint_accepts_current_context(client, student_token) -> None:
    """Context fields must be accepted and must not break the fallback path."""
    from tests.conftest import auth_header

    solution = solve("Solve 2x + 9 = 24").to_dict()
    response = await client.post(
        "/api/v1/mathematics/tutor/explain",
        json={
            "problem": "Solve 2x + 9 = 24",
            "question": "Why did you subtract 9?",
            "step_id": 2,
            "solution": solution,
            "topic": "linear_equation",
            "current_equation": "2 x = 24 - 9",
            "concepts_explained": ["inverse operations"],
        },
        headers=auth_header(student_token),
    )

    assert response.status_code == 200
    body = response.json()
    assert body["reply"]
    assert body["source"] in {"ai", "deterministic"}