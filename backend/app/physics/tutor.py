"""Deterministic physics engine for the Penrose visual physics tutor.

The module mirrors :mod:`app.mathematics.tutor`: a single :func:`solve` entry
point walks an ordered registry of ``matches``/``solve`` pairs. Each solver is a
cheap keyword guard followed by deterministic computation that returns ``None``
when the question is outside its scope, so the first guard that both recognises
the question and produces a solution wins. When nothing matches, the tutor asks
the student for the missing detail rather than inventing an answer.
"""

from __future__ import annotations

import re
from collections.abc import Callable
from dataclasses import dataclass

from app.physics.solution_types import PhysicsSolution, clarification
from app.physics.solvers import electricity, mechanics, thermodynamics, waves_optics

Solver = Callable[[str], PhysicsSolution | None]
Matcher = Callable[[str], bool]

_NUMBER = re.compile(r"[-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?")


@dataclass
class WorkCheck:
    """Verdict on a line of the student's own working."""

    ok: bool
    message: str
    expected_latex: str = ""
    correction_latex: str = ""
    step_ref: int | None = None


_SOLVERS: tuple[tuple[str, Matcher, Solver], ...] = (
    ("refraction", waves_optics.matches_snell, waves_optics.solve_snell),
    ("lenses and mirrors", waves_optics.matches_optics, waves_optics.solve_optics),
    ("waves", waves_optics.matches_waves, waves_optics.solve_waves),
    ("circuits", electricity.matches_ohm, electricity.solve_ohm),
    (
        "circuits",
        electricity.matches_series_parallel,
        electricity.solve_series_parallel,
    ),
    ("electrostatics", electricity.matches_field, electricity.solve_field),
    ("capacitance", electricity.matches_capacitance, electricity.solve_capacitance),
    ("magnetism", electricity.matches_magnetic_force, electricity.solve_magnetic_force),
    ("induction", electricity.matches_induction, electricity.solve_induction),
    ("heat", thermodynamics.matches_specific_heat, thermodynamics.solve_specific_heat),
    ("heat", thermodynamics.matches_latent_heat, thermodynamics.solve_latent_heat),
    ("free fall", mechanics.matches_free_fall, mechanics.solve_free_fall),
    ("projectile motion", mechanics.matches_projectile, mechanics.solve_projectile),
    ("momentum", mechanics.matches_momentum, mechanics.solve_momentum),
    ("circular motion", mechanics.matches_circular, mechanics.solve_circular),
    ("energy", mechanics.matches_energy, mechanics.solve_energy),
    ("Newton's laws", mechanics.matches_newton, mechanics.solve_newton),
    ("kinematics", mechanics.matches_kinematics, mechanics.solve_kinematics),
    ("gravitation", mechanics.matches_gravitation, mechanics.solve_gravitation),
    ("springs", mechanics.matches_spring, mechanics.solve_spring),
    ("simple harmonic motion", mechanics.matches_shm, mechanics.solve_shm),
    ("inclined planes", mechanics.matches_inclined, mechanics.solve_inclined),
    ("friction", mechanics.matches_friction, mechanics.solve_friction),
)

_CAPABILITIES = (
    "I can work through waves and wave speed, lenses and mirrors, refraction "
    "and Snell's law, Ohm's law and resistor networks, electric fields and "
    "capacitors, magnetic forces and induction, specific and latent heat, "
    "projectiles and free fall, "
    "inclined planes and friction, simple harmonic motion and springs, "
    "circular motion and gravitation, momentum, energy and kinematics. Could "
    "you rephrase the question with the quantities you were given?"
)


def topics() -> list[str]:
    """The distinct physics topics the engine can solve."""
    seen: list[str] = []
    for topic, _matches, _solver in _SOLVERS:
        if topic not in seen:
            seen.append(topic)
    return seen


def solve(problem: str) -> PhysicsSolution:
    """Solve a supported problem deterministically, or ask for clarification."""
    text = problem.strip()
    if not text:
        return clarification(problem, "Please type a physics problem.")

    for _topic, matches, solver in _SOLVERS:
        if not matches(text):
            continue
        result = solver(text)
        if result is not None:
            return result

    return clarification(problem, _CAPABILITIES)


def _first_number(text: str) -> float | None:
    match = _NUMBER.search(text.replace(",", ""))
    if match is None:
        return None
    try:
        return float(match.group())
    except ValueError:
        return None


def check_working(problem: str, student_line: str) -> WorkCheck:
    """Compare the number in the student's line with the verified answer.

    Only the leading numeric value is compared, so a line such as
    ``v = 4`` is checked against the answer's magnitude. When neither value can
    be read the tutor says it cannot compare rather than inventing a mistake.
    """
    solution = solve(problem)
    expected_latex = solution.final_answer_latex
    expected = _first_number(solution.final_answer_text)
    student = _first_number(student_line)

    if expected is None:
        return WorkCheck(
            ok=True,
            message=(
                "I could not automatically compare that line, but the verified "
                "solution is on screen. Ask me about the step you used."
            ),
            expected_latex=expected_latex,
        )
    if student is None:
        return WorkCheck(
            ok=False,
            message=(
                "I could not read a number from that line. Write your result "
                "as a value so I can check it against the answer."
            ),
            expected_latex=expected_latex,
        )

    tolerance = max(1e-6, abs(expected) * 1e-3)
    if abs(student - expected) <= tolerance:
        return WorkCheck(
            ok=True,
            message="That matches the verified value. Well done.",
            expected_latex=expected_latex,
        )
    return WorkCheck(
        ok=False,
        message=(
            "That does not match the verified value. Recheck the formula you "
            "used and the units of every quantity."
        ),
        expected_latex=expected_latex,
    )
