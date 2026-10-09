"""Shared scaffolding for the physics topic solvers.

Every solver builds its worked solution through :class:`SolutionBuilder`, so
the Given table, the step numbering, the narration scripts and the
verification fields come out identical no matter which law was applied.
"""

from __future__ import annotations

from typing import Any

from app.mathematics.verification import (
    Verification,
    unverified,
    verification_fields,
)
from app.physics.dimensions import conversion_note
from app.physics.interpreter import SYMBOL_LATEX, unknown_word
from app.physics.solution_types import PhysicsSolution, PhysicsStep
from app.physics.units import Quantity, fmt_number


def _invalid(text: str, reason: str) -> PhysicsSolution:
    """A worked solution that explains why the numbers cannot work."""
    builder = SolutionBuilder(text, "invalid_input", "Physical consistency")
    builder.warn(reason)
    builder.step("The numbers do not work", reason, reason)
    check = unverified(reason)
    return builder.build("", "", check)


def q_latex(quantity_value: Quantity) -> str:
    """``20\\ \\text{N}`` for display inside equations."""
    return quantity_value.latex


def value_si(quantity_value: Quantity) -> float:
    return quantity_value.si_value


class SolutionBuilder:
    """Accumulates given rows, steps and one final answer."""

    def __init__(self, problem: str, topic: str, principle: str) -> None:
        self.problem = problem
        self.topic = topic
        self.principle = principle
        self._steps: list[PhysicsStep] = []
        self._given: list[dict[str, Any]] = []
        self._find: list[str] = []
        self._warnings: list[str] = []
        self._visual: dict[str, Any] | None = None
        self._simulation: dict[str, Any] | None = None
        self._graphs: list[dict[str, Any]] = []

    def add_given(self, symbol: str, quantity_value: Quantity) -> None:
        latex_symbol = SYMBOL_LATEX.get(symbol, symbol)
        line = rf"{latex_symbol} = {quantity_value.latex}"
        self._given.append(
            {
                "symbol": symbol,
                "latex": line,
                "unit": quantity_value.unit,
                "value": round(quantity_value.value, 6),
                "si_value": round(quantity_value.si_value, 6),
            }
        )

    def add_given_number(self, symbol: str, value: float, unit: str) -> None:
        latex_symbol = SYMBOL_LATEX.get(symbol, symbol)
        unit_part = rf"\ {unit}" if unit else ""
        self._given.append(
            {
                "symbol": symbol,
                "latex": rf"{latex_symbol} = {fmt_number(value)}{unit_part}",
                "unit": unit,
                "value": round(value, 6),
                "si_value": round(value, 6),
            }
        )

    def require(self, symbols: list[str]) -> None:
        self._find = [
            f"{unknown_word(symbol)} ({SYMBOL_LATEX.get(symbol, symbol)})"
            for symbol in symbols
        ]

    def warn(self, message: str) -> None:
        self._warnings.append(message)

    def step(
        self,
        title: str,
        explanation: str,
        narration: str,
        latex_lines: list[str] | None = None,
    ) -> None:
        self._steps.append(
            PhysicsStep(
                id=len(self._steps) + 1,
                title=title,
                explanation=explanation,
                narration=narration,
                latex_lines=latex_lines or [],
            )
        )

    def conversion_step(self, quantity_value: Quantity) -> None:
        """Show the unit conversion whenever the student's unit is not SI."""
        if quantity_value.unit in {"", "units"}:
            return
        si = quantity_value.to_si()
        if si.unit == quantity_value.unit:
            return
        note = conversion_note(quantity_value)
        self.step(
            "Convert to SI units",
            (
                f"Physics calculations are safest in SI units, so "
                f"{quantity_value.latex} becomes {si.latex}."
            ),
            note,
            [rf"{quantity_value.latex} = {si.latex}"],
        )

    def set_visual(self, visual: dict[str, Any] | None) -> None:
        self._visual = visual

    def set_simulation(self, model: dict[str, Any] | None) -> None:
        self._simulation = model

    def add_graph(self, graph: dict[str, Any] | None) -> None:
        if graph:
            self._graphs.append(graph)

    def build(
        self,
        answer_latex: str,
        answer_text: str,
        check: Verification,
    ) -> PhysicsSolution:
        solution = PhysicsSolution(
            problem=self.problem,
            topic=self.topic,
            principle=self.principle,
            given=self._given,
            find=self._find,
            steps=self._steps,
            final_answer_latex=answer_latex,
            final_answer_text=answer_text,
            warnings=self._warnings,
            visual=self._visual,
            simulation=self._simulation,
            graphs=self._graphs,
        )
        fields = verification_fields(check)
        solution.verification_status = fields["verification_status"]
        solution.verification_detail = fields["verification_detail"]
        return solution


def given_section_step(builder: SolutionBuilder, ctx_text: str) -> None:
    """Standard 'read the problem' opening step."""
    del ctx_text
    titles = ", ".join(entry["latex"].split("=")[0].strip() for entry in builder._given)
    known = titles if titles else "the given quantities"
    builder.step(
        "Read the problem",
        (
            "Write down every quantity the question gives us, with its unit, "
            f"before touching any formula. Here we know {known}."
        ),
        "First let us list what the question already tells us.",
        [entry["latex"] for entry in builder._given],
    )


def formula_step(
    builder: SolutionBuilder,
    title: str,
    formula: str,
    explanation: str,
    narration: str,
) -> None:
    builder.step(title, explanation, narration, [formula])


def answer_interpretation_step(
    builder: SolutionBuilder, interpretation: str, narration: str
) -> None:
    builder.step(
        "Physical interpretation",
        interpretation,
        narration,
    )
