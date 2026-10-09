"""Tests for the deterministic Penrose physics tutor engine."""

from __future__ import annotations

import pytest

from app.physics.tutor import check_working, solve, topics

GENERALISED_CASES = [
    (
        "A 5 kg box is pushed with a force of 20 N. Find the acceleration.",
        "newtons_second_law",
        "4.0",
    ),
    (
        "A car accelerates from 0 to 20 m/s in 5 s. Find the acceleration.",
        "kinematics",
        "4.0",
    ),
    (
        "A ball is thrown upward at 30 m/s. Find the maximum height.",
        "projectile_motion",
        "45.87",
    ),
    (
        "A 2 kg mass moving at 4 m/s collides with a stationary 2 kg mass "
        "and they stick together. Find the final speed.",
        "momentum_collisions",
        "2.0",
    ),
    ("Calculate the weight of a 10 kg object.", "weight", "98.1"),
    (
        "A 3 kg block slides down a rough incline of 30 degrees with "
        "coefficient of friction 0.2. Find the acceleration.",
        "inclined_plane",
        "3.20",
    ),
    ("A pendulum of length 0.5 m swings. Find its period.", "pendulum_period", "1.41"),
    (
        "A spring with extension 0.1 m feels a force of 5 N. Find the spring "
        "constant.",
        "hookes_law",
        "50.0",
    ),
    (
        "A 1000 kg car travels around a circle of radius 10 m at 5 m/s. Find "
        "the centripetal force.",
        "circular_motion",
        "2500.0",
    ),
    (
        "A stone is dropped from rest from a height of 45 m. Find how long it "
        "takes to reach the ground.",
        "free_fall",
        "3.02",
    ),
    (
        "A worker does 600 J of work in 20 s pushing a box. Find the power.",
        "work_energy_power",
        "30.0",
    ),
    (
        "A 12 V battery drives a current of 3 A through a resistor. Find the "
        "resistance.",
        "ohms_law",
        "4.0",
    ),
    (
        "Three resistors of 2 ohms, 3 ohms and 5 ohms are connected in series "
        "across a 10 V battery. Find the total resistance.",
        "series_parallel_circuits",
        "10.0",
    ),
    (
        "A capacitor stores a charge of 0.006 C when the potential difference "
        "across it is 12 V. Find its capacitance.",
        "capacitance",
        "0.0005",
    ),
    (
        "A wire of length 0.5 m carrying a current of 4 A is placed at right "
        "angles to a uniform magnetic field of strength 0.2 T. Find the force "
        "on the wire.",
        "magnetic_force_wire",
        "0.4",
    ),
    (
        "A coil of 200 turns experiences a change in magnetic flux from "
        "0.02 Wb to 0.06 Wb in 0.1 s. Find the induced emf.",
        "faradays_law",
        "80.0",
    ),
    (
        "A wave has a frequency of 500 Hz and a wavelength of 0.6 m. Find the "
        "speed.",
        "waves",
        "300",
    ),
    (
        "An object is placed 20 cm from a converging lens of focal length "
        "10 cm. Find the image distance.",
        "optics",
        "0.2",
    ),
    (
        "A ray of light travels from air (n=1.0) into glass (n=1.5) at an "
        "angle of incidence of 30 degrees. Find the angle of refraction.",
        "refraction",
        "19.47",
    ),
    (
        "Calculate the heat energy needed to raise the temperature of 2 kg of "
        "water from 20 \u00b0C to 60 \u00b0C. The specific heat capacity of "
        "water is 4200 J/(kg K).",
        "specific_heat",
        "336000",
    ),
    (
        "A 0.2 kg block absorbs 4800 J of heat and its temperature rises by "
        "30 K. Find the specific heat capacity.",
        "specific_heat",
        "800",
    ),
    (
        "How much heat is needed to melt 0.5 kg of ice at 0 \u00b0C? The "
        "specific latent heat of fusion of ice is 334000 J/kg.",
        "latent_heat",
        "167000",
    ),
    (
        "A 0.25 kg mass of a substance requires 50000 J to melt it at its "
        "melting point. Find the specific latent heat of fusion.",
        "latent_heat",
        "200000",
    ),
]


@pytest.mark.parametrize(("problem", "topic", "expected"), GENERALISED_CASES)
def test_solve_produces_verified_answers(
    problem: str, topic: str, expected: str
) -> None:
    solution = solve(problem)

    assert solution.topic == topic, f"{problem!r} was claimed as {solution.topic!r}"
    assert solution.verification_status == "verified", problem
    assert solution.subject == "physics"
    assert expected in solution.final_answer_text, solution.final_answer_text
    assert solution.final_answer_latex
    assert solution.steps, "every solution must expose steps"
    assert [s.id for s in solution.steps] == list(range(1, len(solution.steps) + 1))
    assert all(s.narration for s in solution.steps), problem
    assert all(s.explanation for s in solution.steps), problem


@pytest.mark.parametrize("problem", [problem for problem, _, _ in GENERALISED_CASES])
def test_no_answer_is_invented(problem: str) -> None:
    """A solver must never claim a topic it could not actually work out."""
    solution = solve(problem)

    assert solution.topic != "needs_more_information", problem
    assert solution.verification_status == "verified", problem


def test_solution_serialises_for_the_api() -> None:
    payload = solve(
        "A 5 kg box is pushed with a force of 20 N. Find the " "acceleration."
    ).to_dict()

    assert payload["problem"].startswith("A 5 kg box")
    assert payload["subject"] == "physics"
    assert payload["verification_status"] == "verified"
    assert isinstance(payload["given"], list)
    assert isinstance(payload["find"], list)
    assert isinstance(payload["steps"], list)
    assert all(
        {"id", "title", "explanation", "narration"} <= set(s) for s in payload["steps"]
    )
    assert "graphs" in payload and "visual" in payload and "simulation" in payload


def test_unrecognised_problem_asks_for_clarification() -> None:
    solution = solve("hello there")

    assert solution.topic == "needs_more_information"
    assert solution.verification_status == "unverified"
    assert solution.steps[0].narration
    assert solution.final_answer_latex == ""


def test_empty_problem_asks_for_a_question() -> None:
    solution = solve("   ")

    assert solution.topic == "needs_more_information"


def test_topics_lists_distinct_solver_families() -> None:
    listed = topics()

    assert "circuits" in listed
    assert "waves" in listed
    assert "Newton's laws" in listed
    assert len(listed) == len(set(listed))


# ---------------------------------------------------------------------------
# Student working checker
# ---------------------------------------------------------------------------


def test_check_working_accepts_a_correct_line() -> None:
    result = check_working(
        "A 5 kg box is pushed with a force of 20 N. Find the acceleration.",
        "a = 4",
    )

    assert result.ok is True


def test_check_working_flags_a_wrong_value() -> None:
    result = check_working(
        "A 5 kg box is pushed with a force of 20 N. Find the acceleration.",
        "a = 9",
    )

    assert result.ok is False
    assert result.expected_latex


def test_check_working_reads_a_leading_number() -> None:
    result = check_working(
        "A wave has a frequency of 500 Hz and a wavelength of 0.6 m. Find the speed.",
        "v = 300 m/s",
    )

    assert result.ok is True


# ---------------------------------------------------------------------------
# API surface
# ---------------------------------------------------------------------------


async def test_solve_endpoint_returns_verified_solution(client, student_token) -> None:
    from tests.conftest import auth_header

    response = await client.post(
        "/api/v1/physics/tutor/solve",
        json={
            "problem": "A 5 kg box is pushed with a force of 20 N. "
            "Find the acceleration."
        },
        headers=auth_header(student_token),
    )

    assert response.status_code == 200
    body = response.json()
    assert body["topic"] == "newtons_second_law"
    assert body["subject"] == "physics"
    assert body["verification_status"] == "verified"
    assert "4.0" in body["final_answer_text"]
    assert body["steps"]


async def test_solve_endpoint_requires_authentication(client) -> None:
    response = await client.post(
        "/api/v1/physics/tutor/solve",
        json={"problem": "Calculate the weight of a 10 kg object."},
    )

    assert response.status_code in {401, 403}


async def test_topics_endpoint_lists_solvers(client, student_token) -> None:
    from tests.conftest import auth_header

    response = await client.get(
        "/api/v1/physics/tutor/topics", headers=auth_header(student_token)
    )

    assert response.status_code == 200
    assert "circuits" in response.json()["topics"]


async def test_check_endpoint_returns_a_verdict(client, student_token) -> None:
    from tests.conftest import auth_header

    response = await client.post(
        "/api/v1/physics/tutor/check",
        json={
            "problem": "A 5 kg box is pushed with a force of 20 N. Find the "
            "acceleration.",
            "student_line": "a = 9",
        },
        headers=auth_header(student_token),
    )

    assert response.status_code == 200
    body = response.json()
    assert body["ok"] is False
    assert body["message"]


async def test_explain_endpoint_falls_back_without_a_model(
    client, student_token
) -> None:
    """The tutor panel must keep answering even when the LLM is unavailable."""
    from tests.conftest import auth_header

    solution = solve(
        "A 5 kg box is pushed with a force of 20 N. Find the acceleration."
    ).to_dict()
    response = await client.post(
        "/api/v1/physics/tutor/explain",
        json={
            "problem": "A 5 kg box is pushed with a force of 20 N. Find the "
            "acceleration.",
            "question": "Why do we divide force by mass?",
            "step_id": 2,
            "solution": solution,
        },
        headers=auth_header(student_token),
    )

    assert response.status_code == 200
    body = response.json()
    assert body["reply"]
    assert body["source"] in {"ai", "deterministic"}
