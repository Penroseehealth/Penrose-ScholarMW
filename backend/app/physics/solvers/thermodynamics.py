"""Heat and thermodynamics solvers: specific heat and latent heat.

The module covers the calorimetry laws of a school course: the heat needed to
change a body's temperature, ``Q = mc\\Delta T``, and the heat needed to change
its state at constant temperature, ``Q = mL``. Each solver follows the shared
contract: a cheap ``matches`` guard, deterministic SI computation, narrated
Given/Formula/Substitution/Answer steps and an independent verification.
"""

from __future__ import annotations

from app.mathematics.verification import verify_by_recomputation
from app.physics.interpreter import PhysicsContext
from app.physics.solution_types import PhysicsSolution
from app.physics.solvers._base import (
    SolutionBuilder,
    _invalid,
    answer_interpretation_step,
    formula_step,
    given_section_step,
    value_si,
)
from app.physics.units import (
    ENERGY,
    MASS,
    TEMPERATURE,
    fmt_number,
)

SPECIFIC_HEAT = ENERGY / MASS / TEMPERATURE
LATENT_HEAT = ENERGY / MASS

_CHANGE_WORDS = (
    "rise",
    "rises",
    "raising",
    "change",
    "changes",
    "increase",
    "increases",
    "decrease",
    "decreases",
    "through",
    " by ",
    "difference",
    "heated",
    "cooled",
)


def _temperature_change(ctx: PhysicsContext) -> float | None:
    """The temperature interval, from two readings or a stated rise."""
    readings = ctx.by_dimension(TEMPERATURE)
    if len(readings) >= 2:
        return abs(readings[1].si_value - readings[0].si_value)
    if len(readings) == 1 and any(word in ctx.lowered for word in _CHANGE_WORDS):
        return abs(readings[0].value)
    return None


def _heat_wanted(lowered: str, energy_present: bool) -> bool:
    heat_words = (
        "heat energy",
        "heat needed",
        "heat required",
        "heat absorbed",
        "heat released",
        "heat supplied",
        "thermal energy",
        "how much heat",
        "amount of heat",
        "energy needed",
        "energy required",
    )
    if any(word in lowered for word in heat_words):
        return True
    return "heat" in lowered and not energy_present


# ---------------------------------------------------------------------------
# Specific heat capacity: Q = m c dT
# ---------------------------------------------------------------------------


def matches_specific_heat(text: str) -> bool:
    lowered = text.lower()
    ctx = PhysicsContext(text)
    has_capacity = ctx.first(SPECIFIC_HEAT) is not None
    has_mass = ctx.first(MASS) is not None
    has_change = _temperature_change(ctx) is not None
    heat_words = (
        "specific heat",
        "heat energy",
        "heat needed",
        "heat required",
        "thermal energy",
        "raise the temperature",
        "temperature rise",
        "raise its temperature",
        "heated",
        "cooled",
    )
    return (
        has_mass
        and has_change
        and (has_capacity or any(word in lowered for word in heat_words))
        and any(word in lowered for word in heat_words)
    )


def solve_specific_heat(text: str) -> PhysicsSolution | None:
    lowered = text.lower()
    ctx = PhysicsContext(text)
    mass = ctx.first(MASS)
    capacity = ctx.first(SPECIFIC_HEAT)
    energy = ctx.first(ENERGY)
    delta = _temperature_change(ctx)
    if delta is None or delta == 0:
        return None

    m = value_si(mass) if mass is not None else None
    c = value_si(capacity) if capacity is not None else None
    q = value_si(energy) if energy is not None else None

    builder = SolutionBuilder(
        text,
        "specific_heat",
        "Specific heat capacity: the heat supplied raises the temperature by "
        "Q = m c deltaT, where c is the energy needed per kilogram per kelvin.",
    )

    if (
        mass is not None
        and capacity is not None
        and (q is None or _heat_wanted(lowered, energy is not None))
    ):
        if m <= 0 or c < 0:
            return _invalid(text, "Mass must be positive and capacity non-negative.")
        answer_value = m * c * delta
        formula = r"Q = mc\Delta T"
        explanation = (
            "The heat energy equals the mass times the specific heat capacity "
            "times the temperature change."
        )
        narration = "Multiply mass, capacity and the temperature change."
        substitution = [
            rf"Q = {fmt_number(round(m, 6))} \times {fmt_number(round(c, 6))} "
            rf"\times {fmt_number(round(delta, 6))}",
            rf"Q = {fmt_number(round(answer_value, 6))}\ \text{{J}}",
        ]
        check = verify_by_recomputation(answer_value, m * c * delta, "Q = mc dT")
        builder.require(["E"])
        spoken = "joules"
    elif q is not None and mass is not None and "specific heat" in lowered:
        if m <= 0 or delta == 0:
            return _invalid(text, "Mass and temperature change must be positive.")
        answer_value = q / (m * delta)
        formula = r"c = \frac{Q}{m\Delta T}"
        explanation = (
            "The specific heat capacity is the heat divided by the mass and "
            "the temperature change."
        )
        narration = "Divide the heat by mass times the temperature change."
        substitution = [
            rf"c = \frac{{{fmt_number(round(q, 6))}}}"
            rf"{{{fmt_number(round(m, 6))} \times {fmt_number(round(delta, 6))}}}",
            rf"c = {fmt_number(round(answer_value, 6))}\ \text{{J/(kg K)}}",
        ]
        check = verify_by_recomputation(answer_value, q / (m * delta), "c = Q/mdT")
        builder.require(["c"])
        spoken = "joules per kilogram per kelvin"
    elif q is not None and capacity is not None and "mass" in lowered:
        denominator = c * delta
        if denominator == 0:
            return _invalid(text, "Capacity and temperature change cannot be zero.")
        answer_value = q / denominator
        formula = r"m = \frac{Q}{c\Delta T}"
        explanation = (
            "The mass is the heat divided by the specific heat capacity and "
            "the temperature change."
        )
        narration = "Divide the heat by capacity times the temperature change."
        substitution = [
            rf"m = \frac{{{fmt_number(round(q, 6))}}}"
            rf"{{{fmt_number(round(c, 6))} \times {fmt_number(round(delta, 6))}}}",
            rf"m = {fmt_number(round(answer_value, 6))}\ \text{{kg}}",
        ]
        check = verify_by_recomputation(answer_value, q / (c * delta), "m = Q/cdT")
        builder.require(["m"])
        spoken = "kilograms"
    else:
        return None

    for symbol, quantity_value in (
        ("m", mass),
        ("c", capacity),
        ("E", energy),
        ("Delta_T", None),
    ):
        if symbol == "Delta_T":
            builder.add_given_number("Delta_T", round(delta, 6), "K")
        elif quantity_value is not None:
            builder.add_given(symbol, quantity_value)
    given_section_step(builder, text)
    formula_step(builder, "Choose the law", formula, explanation, narration)
    builder.step(
        "Substitute and calculate",
        "Put the numbers into the rearranged equation.",
        "Substitute the values and evaluate.",
        substitution,
    )
    answer_latex = substitution[-1]
    builder.step(
        "Answer",
        "The required quantity with its SI unit.",
        f"The answer is {fmt_number(round(answer_value, 6))} {spoken}.",
        [answer_latex],
    )
    answer_interpretation_step(
        builder,
        (
            "A large specific heat capacity means a substance soaks up a lot "
            "of energy for only a small temperature rise, which is why water "
            "is used to carry heat around."
        ),
        "Heat, mass and temperature change are linked by the specific heat.",
    )
    return builder.build(
        answer_latex,
        f"{round(answer_value, 6)} {spoken}",
        check,
    )


# ---------------------------------------------------------------------------
# Specific latent heat: Q = m L
# ---------------------------------------------------------------------------


def matches_latent_heat(text: str) -> bool:
    lowered = text.lower()
    ctx = PhysicsContext(text)
    state_words = (
        "latent heat",
        "melt",
        "melts",
        "melting",
        "vaporis",
        "vaporiz",
        "boil",
        "boils",
        "freez",
        "condens",
        "solidif",
        "change of state",
        "evaporat",
    )
    return any(word in lowered for word in state_words) and ctx.first(MASS) is not None


def solve_latent_heat(text: str) -> PhysicsSolution | None:
    lowered = text.lower()
    ctx = PhysicsContext(text)
    mass = ctx.first(MASS)
    latent = ctx.first(LATENT_HEAT)
    energy = ctx.first(ENERGY)

    m = value_si(mass) if mass is not None else None
    latent_value = value_si(latent) if latent is not None else None
    q = value_si(energy) if energy is not None else None

    builder = SolutionBuilder(
        text,
        "latent_heat",
        "Specific latent heat: changing state at a fixed temperature needs "
        "Q = m L, where L is the energy per kilogram for that change.",
    )

    if (
        mass is not None
        and latent is not None
        and (q is None or _heat_wanted(lowered, energy is not None))
    ):
        if m <= 0 or latent_value < 0:
            return _invalid(text, "Mass must be positive and latent heat non-negative.")
        answer_value = m * latent_value
        formula = r"Q = mL"
        explanation = "The heat energy equals the mass times the specific latent heat."
        narration = "Multiply the mass by the specific latent heat."
        substitution = [
            rf"Q = {fmt_number(round(m, 6))} \times "
            rf"{fmt_number(round(latent_value, 6))}",
            rf"Q = {fmt_number(round(answer_value, 6))}\ \text{{J}}",
        ]
        check = verify_by_recomputation(answer_value, m * latent_value, "Q = mL")
        builder.require(["E"])
        spoken = "joules"
    elif q is not None and mass is not None and "latent heat" in lowered:
        if m <= 0:
            return _invalid(text, "Mass must be positive.")
        answer_value = q / m
        formula = r"L = \frac{Q}{m}"
        explanation = "The specific latent heat is the heat divided by the mass."
        narration = "Divide the heat by the mass."
        substitution = [
            rf"L = \frac{{{fmt_number(round(q, 6))}}}{{{fmt_number(round(m, 6))}}}",
            rf"L = {fmt_number(round(answer_value, 6))}\ \text{{J/kg}}",
        ]
        check = verify_by_recomputation(answer_value, q / m, "L = Q/m")
        builder.require(["L"])
        spoken = "joules per kilogram"
    elif q is not None and latent is not None and "mass" in lowered:
        if latent_value == 0:
            return _invalid(text, "The specific latent heat cannot be zero.")
        answer_value = q / latent_value
        formula = r"m = \frac{Q}{L}"
        explanation = "The mass is the heat divided by the specific latent heat."
        narration = "Divide the heat by the specific latent heat."
        substitution = [
            rf"m = \frac{{{fmt_number(round(q, 6))}}}"
            rf"{{{fmt_number(round(latent_value, 6))}}}",
            rf"m = {fmt_number(round(answer_value, 6))}\ \text{{kg}}",
        ]
        check = verify_by_recomputation(answer_value, q / latent_value, "m = Q/L")
        builder.require(["m"])
        spoken = "kilograms"
    else:
        return None

    for symbol, quantity_value in (("m", mass), ("L", latent), ("E", energy)):
        if quantity_value is not None:
            builder.add_given(symbol, quantity_value)
    given_section_step(builder, text)
    formula_step(builder, "Choose the law", formula, explanation, narration)
    builder.step(
        "Substitute and calculate",
        "Put the numbers into the rearranged equation.",
        "Substitute the values and evaluate.",
        substitution,
    )
    answer_latex = substitution[-1]
    builder.step(
        "Answer",
        "The required quantity with its SI unit.",
        f"The answer is {fmt_number(round(answer_value, 6))} {spoken}.",
        [answer_latex],
    )
    answer_interpretation_step(
        builder,
        (
            "While a substance changes state its temperature stays put: all "
            "the energy goes into breaking or forming bonds, which is why "
            "melting ice sits at zero degrees until it is all melted."
        ),
        "Changing state takes energy even at a constant temperature.",
    )
    return builder.build(
        answer_latex,
        f"{round(answer_value, 6)} {spoken}",
        check,
    )
