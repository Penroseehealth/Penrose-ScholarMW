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
def test_solve_produces_verified_answers(
    problem: str, topic: str, expected: str
) -> None:
    solution = solve(problem)

    assert solution.topic == topic
    assert solution.verification_status == "verified"
    assert solution.subject in {"algebra", "geometry", "percentage", "arithmetic"}
    assert expected in solution.final_answer_text
    assert solution.final_answer_latex
    assert solution.steps, "every solution must expose steps"


def test_quadratic_steps_are_ordered_and_narrated() -> None:
    solution = solve("Solve x^2 + 5x + 6 = 0")

    assert [step.id for step in solution.steps] == list(
        range(1, len(solution.steps) + 1)
    )
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
    assert all(
        {"id", "title", "explanation", "narration"} <= set(s) for s in payload["steps"]
    )


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


async def test_explain_endpoint_falls_back_without_a_model(
    client, student_token
) -> None:
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

    assert [step.id for step in solution.steps] == list(
        range(1, len(solution.steps) + 1)
    )
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


# ---------------------------------------------------------------------------
# Generalised coverage: the tutor must solve topics it was never given a
# hardcoded answer for, and must verify each result independently.
# ---------------------------------------------------------------------------

GENERALISED_CASES = [
    ("Solve 3x - 4 = 11", "linear_equation", "x = 5"),
    ("Solve x^2 - 5x + 6 = 0", "quadratic_equation", "2"),
    ("Calculate 3/4 + 2/8", "fraction_arithmetic", "1"),
    ("Calculate 1/2 + 1/3", "fraction_arithmetic", "5/6"),
    ("What is 15% of 240?", "percentage_of_quantity", "36"),
    (
        "Solve the simultaneous equations 2x + y = 7 and x - y = 2",
        "simultaneous_equations",
        "x = 3",
    ),
    (
        "The angles of a triangle are in the ratio 2:3:4. Find the angles",
        "triangle_angles_ratio",
        "40",
    ),
    (
        "Find the third angle of a triangle with angles 50 and 60 degrees",
        "triangle_third_angle",
        "70",
    ),
    ("What is sin 30 degrees?", "sin_of_angle", "0.5"),
    ("Calculate the mean of 4, 7, 9, 12 and 18", "mean", "10"),
    ("Find the median of 3, 5, 7, 9, 11", "median", "7"),
    ("Find the mode of 4, 7, 4, 9, 4, 7", "mode", "4"),
    (
        "A shop increases 4500 kwacha by 10%. Find the new price",
        "percentage_increase",
        "4950",
    ),
    ("What is 2/5 of 35?", "fraction_of_quantity", "14"),
    ("Simplify (x + 3)(x - 1)", "simplify_expression", "x^2"),
    ("Find the distance between (2, 3) and (6, 7)", "distance", "5"),
    ("Share 120 in the ratio 2:3", "share_in_ratio", "48"),
    ("If f(x) = 2x + 1, find f(4)", "function_evaluation", "9"),
    (
        "Find the 10th term of the arithmetic sequence 4, 10, 16, ...",
        "arithmetic_sequence",
        "58",
    ),
    ("A circle has radius 7 cm. Find its area", "circle_area", "153.938"),
    ("Solve the inequality 2x + 3 < 11", "inequality", "x < 4"),
    (
        "A bag has 5 red and 3 blue balls. Find the probability of drawing red",
        "simple_probability",
        "0.625",
    ),
    ("Find the gradient of the line joining (1, 3) and (5, 11)", "gradient", "2"),
    ("A rectangle is 10 cm long and 6 cm wide. Find its area", "rectangle_area", "60"),
    ("A triangle has base 10 cm and height 4 cm. Find its area", "triangle_area", "20"),
    (
        "Maximise P = 3x + 2y subject to x + y ≤ 4, x ≥ 0, y ≥ 0",
        "linear_programming",
        "P = 12",
    ),
    (
        "Maximize Z = 2x + 3y subject to 2x + y ≤ 12, x + y ≤ 8, x ≥ 0, y ≥ 0",
        "linear_programming",
        "Z = 24",
    ),
    (
        "Minimise C = 4x + 3y subject to 2x + y ≥ 10, x + y ≥ 6, x ≥ 0, y ≥ 0",
        "linear_programming",
        "C = 22",
    ),
]


@pytest.mark.parametrize(("problem", "topic", "expected"), GENERALISED_CASES)
def test_generalised_topics_are_solved_and_verified(
    problem: str, topic: str, expected: str
) -> None:
    solution = solve(problem)

    assert solution.topic == topic, f"{problem!r} was claimed as {solution.topic!r}"
    assert solution.verification_status == "verified", problem
    assert expected in solution.final_answer_text, solution.final_answer_text
    assert solution.steps, problem
    assert [s.id for s in solution.steps] == list(range(1, len(solution.steps) + 1))
    assert all(s.narration for s in solution.steps), problem


@pytest.mark.parametrize("problem", [problem for problem, _, _ in GENERALISED_CASES])
def test_no_generalised_answer_is_invented(problem: str) -> None:
    """A solver must never claim a topic it could not actually work out."""
    solution = solve(problem)

    assert solution.topic != "needs_more_information", problem
    assert solution.verification_status == "verified", problem


def test_question_wording_never_leaks_into_the_parser() -> None:
    """Words like "the" must not be read as products of variables (t*h*e)."""
    solution = solve("Solve the inequality 2x + 3 < 11")

    assert solution.verification_status == "verified"
    assert solution.final_answer_text == "x < 4"


def test_percentages_read_the_base_from_before_the_percentage() -> None:
    solution = solve("A shop increases 4500 kwacha by 10%. Find the new price")

    assert solution.final_answer_text == "4950"


def test_probabilities_can_be_read_from_counted_outcomes() -> None:
    solution = solve(
        "A bag has 5 red and 3 blue balls. Find the probability of drawing red"
    )

    assert solution.final_answer_text == "0.625"


def test_fraction_of_a_quantity_keeps_exact_notation() -> None:
    solution = solve("What is 2/5 of 35?")

    assert solution.final_answer_text == "14"
    assert "14" in solution.final_answer_latex


def test_simplified_expressions_are_readable_in_plain_text() -> None:
    solution = solve("Simplify (x + 3)(x - 1)")

    assert "**" not in solution.final_answer_text
    assert solution.final_answer_text == "x^2 + 2*x - 3"


def test_mode_reports_verification_and_handles_ties() -> None:
    single = solve("Find the mode of 4, 7, 4, 9, 4, 7")
    tied = solve("Find the mode of 4, 7, 4, 9, 7, 9")

    assert single.verification_status == "verified"
    assert single.final_answer_text == "4"
    assert tied.verification_status == "verified"
    assert "4" in tied.final_answer_text and "7" in tied.final_answer_text


def test_triangle_area_uses_the_perpendicular_height() -> None:
    solution = solve("A triangle has base 10 cm and height 4 cm. Find its area")

    assert solution.final_answer_text == "20 cm"
    assert solution.verification_status == "verified"


def test_inches_are_not_mistaken_for_a_variable() -> None:
    solution = solve("A triangle has base 10 inches and height 4 inches. Find its area")

    assert solution.final_answer_text == "20 inches"
    assert "e" not in solution.final_answer_latex, solution.final_answer_latex
    assert "20" in solution.final_answer_latex


def test_ambiguous_triangle_keywords_do_not_hijack_other_questions() -> None:
    solution = solve("A bag has 5 red and 3 blue balls. Find the probability of red")

    assert solution.topic == "simple_probability"


# ---------------------------------------------------------------------------
# Linear programming (the graphical method)
# ---------------------------------------------------------------------------


def test_linear_programming_finds_the_optimal_corner_point() -> None:
    solution = solve("Maximise P = 3x + 2y subject to x + y ≤ 4, x ≥ 0, y ≥ 0")

    assert solution.topic == "linear_programming"
    assert solution.verification_status == "verified"
    assert solution.final_answer_text == "P = 12 at x = 4, y = 0"


def test_linear_programming_reports_the_variable_values_not_just_the_number() -> None:
    """A student needs to know *where* the optimum happens, not only its value."""
    solution = solve("Maximise P = 3x + 2y subject to x + y ≤ 4, x ≥ 0, y ≥ 0")

    assert "x = 4" in solution.final_answer_text
    assert "y = 0" in solution.final_answer_text


def test_linear_programming_lists_every_corner_point() -> None:
    solution = solve("Maximise P = 3x + 2y subject to x + y ≤ 4, x ≥ 0, y ≥ 0")

    table = "\n".join(solution.steps[2].latex_lines)
    assert "array" in table
    for expected in ("0", "4", "8", "12"):
        assert expected in table


def test_linear_programming_handles_minimisation() -> None:
    solution = solve(
        "Minimise C = 4x + 3y subject to 2x + y ≥ 10, x + y ≥ 6, x ≥ 0, y ≥ 0"
    )

    assert solution.verification_status == "verified"
    assert solution.final_answer_text == "C = 22 at x = 4, y = 2"


def test_linear_programming_reads_grouped_non_negativity() -> None:
    solution = solve("Maximise P = 3x + 2y subject to x + y ≤ 4, x, y ≥ 0")

    assert solution.verification_status == "verified"
    assert solution.final_answer_text == "P = 12 at x = 4, y = 0"


def test_linear_programming_checks_the_optimum_against_other_corners() -> None:
    solution = solve("Maximise P = 3x + 2y subject to x + y ≤ 4, x ≥ 0, y ≥ 0")

    check_step = solution.steps[-1]
    assert check_step.title == "Check the answer"
    assert "no other corner point" in check_step.explanation.lower()
    assert solution.verification_status == "verified"


def test_maximising_an_area_is_still_mensuration_not_linear_programming() -> None:
    solution = solve("Maximise the area of a rectangle 10 cm by 6 cm")

    assert solution.topic == "rectangle_area"
    assert solution.final_answer_text == "60 cm"


def test_a_maximise_word_without_constraints_falls_through() -> None:
    solution = solve("Maximise P = 3x + 2y")

    assert solution.topic == "needs_more_information"


# ---------------------------------------------------------------------------
# Algebra, coordinate geometry, calculus, trigonometry and edge cases
# ---------------------------------------------------------------------------

EXTENDED_CASES = [
    ("Factorise x^2 - 5x + 6", "factorise_expression", "(x - 3)*(x - 2)"),
    ("Factorize x^2 - 5x + 6", "factorise_expression", "(x - 3)*(x - 2)"),
    (
        "Find the nth term of the sequence 3, 7, 11, 15",
        "arithmetic_sequence",
        "a_n = 4n - 1",
    ),
    (
        "Find the equation of the line through (0, 3) and (4, 11)",
        "line_equation",
        "y = 2x + 3",
    ),
    ("Differentiate x^2 + 3x", "differentiation", "2*x + 3"),
    ("Find the derivative of x^2 + 3x", "differentiation", "2*x + 3"),
    ("Integrate x^2", "integration", "x^3/3"),
    (
        "Find the turning point of y = x^2 - 4x + 1",
        "stationary_points",
        "(2, -3)",
    ),
    (
        "Solve sin(x) = 0.5 for 0 <= x <= 360",
        "trigonometric_equation",
        "30",
    ),
]


@pytest.mark.parametrize(("problem", "topic", "expected"), EXTENDED_CASES)
def test_extended_topics_are_solved_and_verified(
    problem: str, topic: str, expected: str
) -> None:
    solution = solve(problem)

    assert solution.topic == topic, f"{problem!r} was claimed as {solution.topic!r}"
    assert solution.verification_status == "verified", problem
    assert expected in solution.final_answer_text, solution.final_answer_text
    assert solution.steps, problem
    assert [s.id for s in solution.steps] == list(range(1, len(solution.steps) + 1))
    assert all(s.narration for s in solution.steps), problem


def test_simultaneous_equations_need_no_keyword() -> None:
    """Two equations in two unknowns are enough to recognise the topic."""
    solution = solve("Solve x + y = 7 and x - y = 1")

    assert solution.topic == "simultaneous_equations"
    assert solution.verification_status == "verified"
    assert "x = 4" in solution.final_answer_text
    assert "y = 3" in solution.final_answer_text


def test_equation_with_no_solution_is_reported_not_invented() -> None:
    solution = solve("Solve 2x + 3 = 2x + 5")

    assert solution.topic == "linear_equation"
    assert solution.verification_status == "verified"
    assert solution.final_answer_text == "no solution"


def test_equation_true_for_every_value_has_infinitely_many_solutions() -> None:
    solution = solve("Solve 2x + 3 = 2x + 3")

    assert solution.topic == "linear_equation"
    assert solution.verification_status == "verified"
    assert solution.final_answer_text == "infinitely many solutions"


def test_two_point_line_is_not_mistaken_for_a_distance() -> None:
    """The word "equation" must route to a line, not the distance formula."""
    solution = solve("Find the equation of the line through (0, 3) and (4, 11)")

    assert solution.topic == "line_equation"
    assert "y = 2x + 3" in solution.final_answer_text


@pytest.mark.parametrize(
    "problem",
    ["!!!!", "Solve 2x + 5 =", "hello there", "   "],
)
def test_malformed_input_never_crashes(problem: str) -> None:
    solution = solve(problem)

    assert solution.topic == "needs_more_information"
    assert solution.verification_status == "unverified"
    assert solution.steps
    assert solution.steps[0].narration


# ---------------------------------------------------------------------------
# Diagram specifications (hand-drawn figure contract for the frontend)
# ---------------------------------------------------------------------------

FIGURE_PRIMITIVE_TYPES = {
    "axes",
    "segment",
    "point",
    "polygon",
    "circle",
    "rect",
    "path",
    "label",
}


def _figure(problem: str) -> tuple:
    solution = solve(problem)
    visual = solution.visual
    assert visual is not None, problem
    assert visual["kind"] == "figure", problem
    view = visual["view"]
    assert {"xmin", "xmax", "ymin", "ymax"} <= set(view), problem
    assert all(isinstance(view[k], (int, float)) for k in view), problem
    assert isinstance(visual["primitives"], list) and visual["primitives"], problem
    return solution, visual


def _types(visual: dict) -> set:
    return {primitive["type"] for primitive in visual["primitives"]}


def _primitive(visual: dict, kind: str) -> dict:
    return next(p for p in visual["primitives"] if p["type"] == kind)


@pytest.mark.parametrize(
    "problem",
    [
        "A triangle has base 10 cm and perpendicular height 6 cm. Find its area",
        "A circle has radius 7 cm. Find its area",
        "Find the equation of the line through (0, 3) and (4, 11)",
        "Maximise P = 3x + 2y subject to x + y <= 4, x >= 0, y >= 0",
        "What is the mean of 4, 7, 9, 12, 18?",
        "Find the turning point of y = x^2 - 4x + 1",
    ],
)
def test_figures_emit_only_known_primitives(problem: str) -> None:
    _, visual = _figure(problem)

    assert _types(visual) <= FIGURE_PRIMITIVE_TYPES, problem
    assert all("type" in p for p in visual["primitives"]), problem


def test_triangle_figure_labels_the_base_and_height() -> None:
    _, visual = _figure(
        "A triangle has base 10 cm and perpendicular height 6 cm. Find its area"
    )

    assert "polygon" in _types(visual)
    texts = " ".join(p.get("text", "") for p in visual["primitives"])
    assert "base = 10" in texts
    assert "height = 6" in texts


def test_circle_figure_draws_the_radius() -> None:
    _, visual = _figure("A circle has radius 7 cm. Find its area")

    circle = _primitive(visual, "circle")
    assert circle["r"] == 7
    assert "segment" in _types(visual)


def test_line_figure_marks_the_given_points() -> None:
    _, visual = _figure("Find the equation of the line through (0, 3) and (4, 11)")

    point_labels = {
        p.get("label") for p in visual["primitives"] if p["type"] == "point"
    }
    assert "(0, 3)" in point_labels
    assert "(4, 11)" in point_labels
    assert "axes" in _types(visual)


def test_linear_programming_figure_shades_the_feasible_region() -> None:
    _, visual = _figure("Maximise P = 3x + 2y subject to x + y <= 4, x >= 0, y >= 0")

    assert "polygon" in _types(visual)
    assert any(p.get("dashed") for p in visual["primitives"])
    optimum = _primitive(visual, "point")
    assert "P = 12" in optimum.get("label", "")


def test_statistics_figure_draws_a_bar_per_value() -> None:
    _, visual = _figure("What is the mean of 4, 7, 9, 12, 18?")

    bars = [p for p in visual["primitives"] if p["type"] == "rect"]
    assert len(bars) == 5
    assert any(p.get("dashed") for p in visual["primitives"])


def test_stationary_point_figure_plots_the_curve() -> None:
    _, visual = _figure("Find the turning point of y = x^2 - 4x + 1")

    path = _primitive(visual, "path")
    assert len(path["points"]) > 20
    turning = _primitive(visual, "point")
    assert turning["x"] == 2
    assert turning["y"] == -3
