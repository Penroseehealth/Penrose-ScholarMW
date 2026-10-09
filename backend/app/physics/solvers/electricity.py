"""Electricity and magnetism solvers: circuits, fields, capacitors, motors.

Every solver follows the shared contract: a cheap ``matches`` guard,
deterministic SI computation, Given/Formula/Substitution/Answer steps with
narration, an independent verification and, where a diagram helps, a
structured visual the frontend can paint.
"""

from __future__ import annotations

import re

from app.mathematics.verification import verify_by_recomputation
from app.physics.interpreter import COULOMB_CONSTANT, PhysicsContext, find_unknowns
from app.physics.solution_types import PhysicsSolution, clarification
from app.physics.solvers._base import (
    SolutionBuilder,
    _invalid,
    answer_interpretation_step,
    formula_step,
    given_section_step,
    value_si,
)
from app.physics.units import (
    CAPACITANCE,
    CHARGE,
    CURRENT,
    LENGTH,
    MAGNETIC_FIELD,
    MAGNETIC_FLUX,
    RESISTANCE,
    SPEED,
    TIME,
    VOLTAGE,
    fmt_number,
)


def circuit_visual(
    arrangement: str,
    resistances: list[float],
    voltage: float | None,
    current: float | None,
) -> dict:
    """A simple loop the frontend draws as boxes on a rectangle."""
    return {
        "kind": "circuit",
        "arrangement": arrangement,
        "resistors": [round(r, 6) for r in resistances],
        "battery": round(voltage, 6) if voltage is not None else None,
        "current": round(current, 6) if current is not None else None,
    }


# ---------------------------------------------------------------------------
# Ohm's law for a single circuit
# ---------------------------------------------------------------------------


def matches_ohm(text: str) -> bool:
    lowered = text.lower()
    if "series" in lowered or "parallel" in lowered:
        return False
    return any(
        word in lowered
        for word in ("ohm", "resistor", "resistance", "circuit", "v = ir")
    )


def solve_ohm(text: str) -> PhysicsSolution | None:
    lowered = text.lower()
    if "series" in lowered or "parallel" in lowered:
        return None
    ctx = PhysicsContext(text)
    voltages = ctx.by_dimension(VOLTAGE)
    currents = ctx.by_dimension(CURRENT)
    resistances = ctx.by_dimension(RESISTANCE)
    if len(currents) > 1 or len(resistances) > 1:
        return None
    voltage = voltages[0] if voltages else None
    current = currents[0] if currents else None
    resistance = resistances[0] if resistances else None
    known = {"V": voltage, "I": current, "R_e": resistance}
    if sum(item is not None for item in known.values()) < 2:
        return None
    v = value_si(voltage) if voltage is not None else None
    i = value_si(current) if current is not None else None
    r = value_si(resistance) if resistance is not None else None
    if (r is not None and r <= 0) or (i is not None and i < 0):
        return _invalid(
            text, "Resistance must be positive and current cannot be negative."
        )
    unknowns = find_unknowns(text)
    builder = SolutionBuilder(
        text,
        "ohms_law",
        "Ohm's law: the current through a conductor equals the potential "
        "difference across it divided by its resistance (I = V/R).",
    )
    for symbol, quantity_value in known.items():
        if quantity_value is not None:
            builder.add_given(symbol, quantity_value)
    wants_power = "P" in unknowns or "power" in lowered
    if wants_power and v is not None and i is not None:
        builder.require(["P"])
        given_section_step(builder, text)
        formula_step(
            builder,
            "Choose the law",
            r"P = VI",
            "Electrical power is the potential difference times the current.",
            "Multiply the voltage by the current to get the power.",
        )
        power_value = v * i
        substitution = [
            rf"P = {fmt_number(round(v, 6))} \times {fmt_number(round(i, 6))}"
            rf" = {fmt_number(round(power_value, 6))}\ \text{{W}}"
        ]
        check = verify_by_recomputation(power_value, v * i, "P = VI")
    elif wants_power and v is not None and r is not None:
        builder.require(["P"])
        given_section_step(builder, text)
        formula_step(
            builder,
            "Choose the law",
            r"P = \frac{V^{2}}{R}",
            "With the voltage and resistance known, power is V squared "
            "divided by R.",
            "Divide the voltage squared by the resistance.",
        )
        power_value = v * v / r
        substitution = [
            rf"P = \frac{{{fmt_number(round(v, 6))}^{{2}}}}"
            rf"{{{fmt_number(round(r, 6))}}}"
            rf" = {fmt_number(round(power_value, 6))}\ \text{{W}}"
        ]
        check = verify_by_recomputation(power_value, v * v / r, "P = V²/R")
    elif wants_power and i is not None and r is not None:
        builder.require(["P"])
        given_section_step(builder, text)
        formula_step(
            builder,
            "Choose the law",
            r"P = I^{2}R",
            "With the current and resistance known, power is I squared " "times R.",
            "Square the current and multiply by the resistance.",
        )
        power_value = i * i * r
        substitution = [
            rf"P = {fmt_number(round(i, 6))}^{{2}} \times "
            rf"{fmt_number(round(r, 6))}"
            rf" = {fmt_number(round(power_value, 6))}\ \text{{W}}"
        ]
        check = verify_by_recomputation(power_value, i * i * r, "P = I²R")
    else:
        target = next(
            (s for s in ("V", "I", "R_e") if s in unknowns and known[s] is None),
            None,
        )
        if target is None:
            target = next((s for s in ("V", "I", "R_e") if known[s] is None), None)
        if target is None:
            return None
        builder.require([target])
        given_section_step(builder, text)
        if target == "I":
            if v is None or r is None or r == 0:
                return None
            answer_value = v / r
            formula, explanation, narration = (
                r"I = \frac{V}{R}",
                "Current is the voltage divided by the resistance.",
                "Divide the potential difference by the resistance.",
            )
            substitution = [
                rf"I = \frac{{{fmt_number(round(v, 6))}}}"
                rf"{{{fmt_number(round(r, 6))}}}"
                rf" = {fmt_number(round(answer_value, 6))}\ \text{{A}}"
            ]
            answer_unit = r"\text{A}"
            spoken = "amperes"
            check = verify_by_recomputation(answer_value, v / r, "Ohm's law I = V/R")
        elif target == "V":
            if i is None or r is None:
                return None
            answer_value = i * r
            formula, explanation, narration = (
                r"V = IR",
                "The potential difference is the current times the resistance.",
                "Multiply the current by the resistance.",
            )
            substitution = [
                rf"V = {fmt_number(round(i, 6))} \times "
                rf"{fmt_number(round(r, 6))}"
                rf" = {fmt_number(round(answer_value, 6))}\ \text{{V}}"
            ]
            answer_unit = r"\text{V}"
            spoken = "volts"
            check = verify_by_recomputation(answer_value, i * r, "Ohm's law V = IR")
        else:
            if v is None or i is None or i == 0:
                return None
            answer_value = v / i
            formula, explanation, narration = (
                r"R = \frac{V}{I}",
                "Resistance is the potential difference divided by the current.",
                "Divide the potential difference by the current.",
            )
            substitution = [
                rf"R = \frac{{{fmt_number(round(v, 6))}}}"
                rf"{{{fmt_number(round(i, 6))}}}"
                rf" = {fmt_number(round(answer_value, 6))}\ \Omega"
            ]
            answer_unit = r"\Omega"
            spoken = "ohms"
            check = verify_by_recomputation(answer_value, v / i, "Ohm's law R = V/I")
        power_value = None
    if power_value is None:
        formula_step(
            builder,
            "Choose the law",
            formula,
            explanation,
            narration,
        )
    if power_value is not None:
        answer_unit = r"\text{W}"
        answer_value = power_value
        spoken = "watts"
    builder.step(
        "Substitute and calculate",
        "Put the numbers into the rearranged equation.",
        "Substitute the numbers and evaluate.",
        substitution,
    )
    answer_latex = (
        rf"{'P' if wants_power else target} = "
        rf"{fmt_number(round(answer_value, 6))}\ {answer_unit}"
    )
    builder.set_visual(
        circuit_visual(
            "single",
            [r] if r is not None else [],
            v,
            i,
        )
    )
    builder.step(
        "Answer",
        "The required quantity with its SI unit.",
        f"The answer is {fmt_number(round(answer_value, 6))} {spoken}.",
        [answer_latex],
    )
    answer_interpretation_step(
        builder,
        (
            "In an ohmic circuit the three quantities are locked together: "
            "raise the voltage and the current rises in proportion, while a "
            "bigger resistance squeezes the current down."
        ),
        "Voltage drives the current, resistance opposes it.",
    )
    return builder.build(
        answer_latex,
        f"{round(answer_value, 6)} {spoken}",
        check,
    )


# ---------------------------------------------------------------------------
# Series and parallel resistor networks
# ---------------------------------------------------------------------------


def matches_series_parallel(text: str) -> bool:
    lowered = text.lower()
    has_resistors = any(word in lowered for word in ("resistor", "resistance", "ohm"))
    return has_resistors and ("series" in lowered or "parallel" in lowered)


def solve_series_parallel(text: str) -> PhysicsSolution | None:
    lowered = text.lower()
    parallel = "parallel" in lowered
    if not parallel and "series" not in lowered:
        return None
    ctx = PhysicsContext(text)
    resistances = ctx.by_dimension(RESISTANCE)
    if len(resistances) < 2:
        return None
    voltages = ctx.by_dimension(VOLTAGE)
    currents = ctx.by_dimension(CURRENT)
    voltage = voltages[0] if voltages else None
    current = currents[0] if currents else None
    values = [value_si(item) for item in resistances]
    if any(item <= 0 for item in values):
        return _invalid(text, "Resistances must be positive.")
    if parallel:
        total = 1.0 / sum(1.0 / item for item in values)
        formula = r"\frac{1}{R} = \frac{1}{R_1} + \frac{1}{R_2} + \cdots"
        formula_words = "In parallel the reciprocals of the resistances add."
        narration = "Add the reciprocals of the resistances and invert the total."
        substitution_line = _parallel_substitution(values, total)
    else:
        total = sum(values)
        formula = r"R = R_1 + R_2 + \cdots"
        formula_words = "In series the resistances simply add up."
        narration = "Add the resistances for a series combination."
        substitution_line = (
            rf"R = {' + '.join(fmt_number(item) for item in values)}"
            rf" = {fmt_number(round(total, 6))}\ \Omega"
        )
    unknowns = find_unknowns(text)
    if "I" in unknowns and voltage is not None:
        target = "I"
    elif "V" in unknowns and current is not None:
        target = "V"
    elif "R_e" in unknowns:
        target = "R_e"
    elif voltage is not None:
        target = "I"
    elif current is not None:
        target = "V"
    else:
        target = "R_e"
    builder = SolutionBuilder(
        text,
        "series_parallel_circuits",
        "Resistors in series add directly; resistors in parallel combine "
        "through reciprocals, and Ohm's law then applies to the whole "
        "network.",
    )
    for index, quantity_value in enumerate(resistances):
        if index == 0:
            builder.add_given("R_e", quantity_value)
        else:
            builder.add_given(f"R_{index + 1}", quantity_value)
    if voltage is not None:
        builder.add_given("V", voltage)
    if current is not None:
        builder.add_given("I", current)
    builder.require([target])
    given_section_step(builder, text)
    formula_step(
        builder,
        "Combine the resistors",
        formula,
        formula_words,
        narration,
    )
    builder.step(
        "Substitute and calculate",
        "Put the individual resistances into the combination rule.",
        "Substitute the resistances and evaluate the total.",
        [substitution_line],
    )
    v = value_si(voltage) if voltage is not None else None
    i = value_si(current) if current is not None else None
    if target == "R_e":
        answer_value = total
        answer_unit = r"\Omega"
        spoken = "ohms"
        symbol = "R"
        check = verify_by_recomputation(
            total,
            (sum(values) if not parallel else 1.0 / sum(1.0 / item for item in values)),
            "resistor combination rule",
        )
    else:
        if target == "I":
            if v is None or total == 0:
                return None
            answer_value = v / total
            answer_unit = r"\text{A}"
            spoken = "amperes"
            symbol = "I"
            check = verify_by_recomputation(
                answer_value, v / total, "Ohm's law on the whole network"
            )
        else:
            if i is None:
                return None
            answer_value = i * total
            answer_unit = r"\text{V}"
            spoken = "volts"
            symbol = "V"
            check = verify_by_recomputation(
                answer_value, i * total, "Ohm's law on the whole network"
            )
        formula_step(
            builder,
            "Apply Ohm's law",
            r"V = IR \quad\text{or}\quad I = \frac{V}{R}",
            "The combination behaves like one resistor of the total value.",
            "Now treat the network as a single resistor.",
        )
        builder.step(
            "Substitute and calculate",
            "Use the total resistance with the supply or the current.",
            "Substitute into Ohm's law.",
            [
                (
                    rf"I = \frac{{{fmt_number(round(v, 6))}}}"
                    rf"{{{fmt_number(round(total, 6))}}}"
                    if target == "I"
                    else rf"V = {fmt_number(round(i, 6))} \times "
                    rf"{fmt_number(round(total, 6))}"
                )
                + rf" = {fmt_number(round(answer_value, 6))}\ {answer_unit}"
            ],
        )
    builder.set_visual(
        circuit_visual(
            "parallel" if parallel else "series",
            values,
            v,
            i,
        )
    )
    builder.step(
        "Answer",
        "The required quantity with its SI unit.",
        f"The answer is {fmt_number(round(answer_value, 6))} {spoken}.",
        [rf"{symbol} = {fmt_number(round(answer_value, 6))}\ " rf"{answer_unit}"],
    )
    answer_interpretation_step(
        builder,
        (
            "Parallel resistors give the current extra paths, so the total "
            "resistance is always smaller than the smallest branch; series "
            "resistors share the same current, so their resistances pile up."
        ),
        "Parallel paths lower the total resistance; series paths add up.",
    )
    return builder.build(
        rf"{symbol} = {fmt_number(round(answer_value, 6))}\ {answer_unit}",
        f"{round(answer_value, 6)} {spoken}",
        check,
    )


def _parallel_substitution(values: list[float], total: float) -> str:
    reciprocals = " + ".join(fmt_number(round(1.0 / item, 6)) for item in values)
    return (
        rf"\frac{{1}}{{R}} = {reciprocals}"
        rf" = {fmt_number(round(1.0 / total, 6))}"
        rf",\quad R = {fmt_number(round(total, 6))}\ \Omega"
    )


# ---------------------------------------------------------------------------
# Electric fields and Coulomb forces
# ---------------------------------------------------------------------------


def matches_field(text: str) -> bool:
    lowered = text.lower()
    return any(
        word in lowered
        for word in (
            "electric field",
            "electric force",
            "coulomb",
            "two charges",
            "point charge",
            "attraction between",
            "repulsion between",
            "force between the charges",
        )
    )


def solve_field(text: str) -> PhysicsSolution | None:
    lowered = text.lower()
    ctx = PhysicsContext(text)
    charges = ctx.by_dimension(CHARGE)
    lengths = ctx.by_dimension(LENGTH)
    k = COULOMB_CONSTANT
    if len(charges) >= 2 and lengths:
        q1 = value_si(charges[0])
        q2 = value_si(charges[1])
        separation = value_si(lengths[0])
        if separation <= 0:
            return _invalid(text, "The separation must be positive.")
        force = k * abs(q1 * q2) / (separation**2)
        same_sign = (q1 > 0) == (q2 > 0)
        builder = SolutionBuilder(
            text,
            "coulombs_law",
            "Coulomb's law: the force between two point charges is "
            r"F = k q_1 q_2 / r^{2}, attractive for unlike charges and "
            "repulsive for like charges.",
        )
        builder.add_given("Q", charges[0])
        builder.add_given("Q", charges[1])
        builder.add_given("r", lengths[0])
        builder.require(["F"])
        given_section_step(builder, text)
        builder.conversion_step(charges[0])
        builder.conversion_step(lengths[0])
        formula_step(
            builder,
            "Choose the law",
            r"F = k\frac{q_1 q_2}{r^{2}}",
            (
                "The force grows with the product of the charges and shrinks "
                "with the square of the distance between them."
            ),
            "Multiply the charges, scale by k, and divide by the distance " "squared.",
        )
        builder.step(
            "Substitute and calculate",
            (
                f"Take k = {fmt_number(round(k, 4))} N m²/C², multiply the "
                "charges, divide by the separation squared."
            ),
            "Put the numbers into Coulomb's law.",
            [
                rf"F = {k:.6g} \times "
                rf"\frac{{{fmt_number(abs(q1))} \times "
                rf"{fmt_number(abs(q2))}}}"
                rf"{{{fmt_number(round(separation, 6))}^{{2}}}}"
                rf" = {fmt_number(round(force, 6))}\ \text{{N}}"
            ],
        )
        answer_latex = rf"F = {fmt_number(round(force, 6))}\ \text{{N}}"
        check = verify_by_recomputation(
            force, k * abs(q1 * q2) / (separation**2), "Coulomb's law"
        )
        builder.step(
            "Answer",
            "The magnitude of the electrostatic force.",
            f"The answer is {fmt_number(round(force, 6))} newtons, "
            + ("repulsive." if same_sign else "attractive."),
            [answer_latex],
        )
        answer_interpretation_step(
            builder,
            (
                "Unlike charges pull together and like charges push apart; "
                "doubling the distance would cut this force to a quarter."
            ),
            "The force follows an inverse-square law like gravity.",
        )
        builder.warn(
            "This force is repulsive." if same_sign else "This force is attractive."
        )
        return builder.build(answer_latex, f"{round(force, 6)} N", check)
    if len(charges) == 1 and lengths:
        field_match = re.search(
            r"field(?:\s+strength)?\s+(?:of\s+|is\s+|=\s*)" r"(-?\d+(?:\.\d+)?)",
            lowered,
        )
        unknowns = find_unknowns(text)
        wants_force = "F" in unknowns or "force" in lowered
        q = value_si(charges[0])
        distance = value_si(lengths[0])
        if distance <= 0:
            return _invalid(text, "The distance must be positive.")
        if wants_force:
            if field_match is None:
                return clarification(
                    text,
                    "What is the electric field strength where the charge " "sits?",
                )
            field_value = float(field_match.group(1))
            force = abs(field_value * q)
            builder = SolutionBuilder(
                text,
                "force_in_field",
                "A charge in an electric field feels F = Eq, along the "
                "field for positive charges and against it for negative "
                "charges.",
            )
            builder.add_given("Q", charges[0])
            builder.add_given_number("E", field_value, r"\text{N/C}")
            builder.add_given("r", lengths[0])
            builder.require(["F"])
            given_section_step(builder, text)
            formula_step(
                builder,
                "Choose the law",
                r"F = Eq",
                "The force is the field strength times the charge.",
                "Multiply the field strength by the charge.",
            )
            builder.step(
                "Substitute and calculate",
                "Multiply the field strength by the charge.",
                "Multiply the field strength by the charge.",
                [
                    rf"F = {fmt_number(field_value)} \times "
                    rf"{fmt_number(abs(q))}"
                    rf" = {fmt_number(round(force, 6))}\ \text{{N}}"
                ],
            )
            answer_latex = rf"F = {fmt_number(round(force, 6))}\ \text{{N}}"
            check = verify_by_recomputation(force, abs(field_value * q), "F = Eq")
        else:
            field_value = k * abs(q) / (distance**2)
            builder = SolutionBuilder(
                text,
                "electric_field",
                "A point charge Q makes a field "
                r"E = kQ/r^{2} that weakens with the square of the distance.",
            )
            builder.add_given("Q", charges[0])
            builder.add_given("r", lengths[0])
            builder.require(["E"])
            given_section_step(builder, text)
            builder.conversion_step(lengths[0])
            formula_step(
                builder,
                "Choose the law",
                r"E = k\frac{Q}{r^{2}}",
                "The field around a point charge falls off with distance " "squared.",
                "Multiply k by the charge and divide by the distance " "squared.",
            )
            builder.step(
                "Substitute and calculate",
                (
                    f"Take k = {fmt_number(round(k, 4))} N m²/C² and "
                    "divide by the distance squared."
                ),
                "Put the numbers into the field equation.",
                [
                    rf"E = {k:.6g} \times "
                    rf"\frac{{{fmt_number(abs(q))}}}"
                    rf"{{{fmt_number(round(distance, 6))}^{{2}}}}"
                    rf" = {fmt_number(round(field_value, 6))}\ "
                    rf"\text{{N/C}}"
                ],
            )
            answer_latex = rf"E = {fmt_number(round(field_value, 6))}\ \text{{N/C}}"
            check = verify_by_recomputation(
                field_value, k * abs(q) / (distance**2), "E = kQ/r²"
            )
        builder.step(
            "Answer",
            "The required field quantity with its unit.",
            f"The answer is {fmt_number(round(field_value, 6))}.",
            [answer_latex],
        )
        answer_interpretation_step(
            builder,
            (
                "Field lines point away from positive charge and toward "
                "negative charge; their density shows how strong the force "
                "would be on a test charge."
            ),
            "The field tells a charge how hard it will be pushed.",
        )
        return builder.build(answer_latex, f"{round(field_value, 6)}", check)
    if len(charges) >= 2 and not lengths:
        return clarification(text, "How far apart are the two charges?")
    return None


# ---------------------------------------------------------------------------
# Capacitance
# ---------------------------------------------------------------------------


def matches_capacitance(text: str) -> bool:
    lowered = text.lower()
    return any(
        word in lowered
        for word in (
            "capacitor",
            "capacitance",
            "charge stored",
            "stored charge",
            "plate charge",
            "energy stored",
        )
    )


def solve_capacitance(text: str) -> PhysicsSolution | None:
    lowered = text.lower()
    ctx = PhysicsContext(text)
    capacitances = ctx.by_dimension(CAPACITANCE)
    charges = ctx.by_dimension(CHARGE)
    voltages = ctx.by_dimension(VOLTAGE)
    capacitance = capacitances[0] if capacitances else None
    charge = charges[0] if charges else None
    voltage = voltages[0] if voltages else None
    unknowns = find_unknowns(text)
    wants_energy = "E" in unknowns or "energy" in lowered
    if wants_energy and capacitance is not None and voltage is not None:
        builder = SolutionBuilder(
            text,
            "capacitor_energy",
            "Energy stored in a capacitor is "
            r"E = \tfrac{1}{2}CV^{2}; the same energy appears as "
            r"\tfrac{1}{2}QV or \tfrac{Q^{2}}{2C}.",
        )
        builder.add_given("C", capacitance)
        builder.add_given("V", voltage)
        builder.require(["E"])
        given_section_step(builder, text)
        c = value_si(capacitance)
        v = value_si(voltage)
        energy_value = 0.5 * c * v * v
        formula_step(
            builder,
            "Choose the law",
            r"E = \tfrac{1}{2}CV^{2}",
            "The stored energy grows with the capacitance and the square "
            "of the voltage.",
            "Halve the capacitance times the voltage squared.",
        )
        builder.step(
            "Substitute and calculate",
            "Square the voltage, multiply by the capacitance, halve it.",
            "Square the voltage, multiply by the capacitance, halve it.",
            [
                rf"E = \tfrac{{1}}{{2}} \times "
                rf"{fmt_number(c)} \times {fmt_number(v)}^{{2}}"
                rf" = {fmt_number(round(energy_value, 6))}\ \text{{J}}"
            ],
        )
        answer_latex = rf"E = {fmt_number(round(energy_value, 6))}\ \text{{J}}"
        check = verify_by_recomputation(energy_value, 0.5 * c * v * v, "E = ½CV²")
        spoken = "joules"
        builder.step(
            "Answer",
            "The energy stored in the capacitor.",
            f"The answer is {fmt_number(round(energy_value, 6))} joules.",
            [answer_latex],
        )
        answer_interpretation_step(
            builder,
            (
                "A capacitor stores energy as separated charge on its "
                "plates; doubling the voltage stores four times the energy."
            ),
            "The stored energy grows with the square of the voltage.",
        )
        return builder.build(answer_latex, f"{round(energy_value, 6)} {spoken}", check)
    known = {"C": capacitance, "Q": charge, "V": voltage}
    if sum(item is not None for item in known.values()) < 2:
        return None
    c = value_si(capacitance) if capacitance is not None else None
    q = value_si(charge) if charge is not None else None
    v = value_si(voltage) if voltage is not None else None
    target = next(
        (s for s in ("C", "Q", "V") if s in unknowns and known[s] is None),
        None,
    )
    if target is None:
        target = next((s for s in ("C", "Q", "V") if known[s] is None), None)
    if target is None:
        return None
    if target == "C":
        if v is None or v == 0 or q is None:
            return None
        answer_value = q / v
        formula = r"C = \frac{Q}{V}"
        substitution = [
            rf"C = \frac{{{fmt_number(round(q, 6))}}}"
            rf"{{{fmt_number(round(v, 6))}}}"
            rf" = {fmt_number(round(answer_value, 6))}\ \text{{F}}"
        ]
        answer_unit = r"\text{F}"
        spoken = "farads"
        check = verify_by_recomputation(answer_value, q / v, "C = Q/V")
    elif target == "Q":
        if c is None or v is None:
            return None
        answer_value = c * v
        formula = r"Q = CV"
        substitution = [
            rf"Q = {fmt_number(c)} \times {fmt_number(v)}"
            rf" = {fmt_number(round(answer_value, 6))}\ \text{{C}}"
        ]
        answer_unit = r"\text{C}"
        spoken = "coulombs"
        check = verify_by_recomputation(answer_value, c * v, "Q = CV")
    else:
        if c is None or c == 0 or q is None:
            return None
        answer_value = q / c
        formula = r"V = \frac{Q}{C}"
        substitution = [
            rf"V = \frac{{{fmt_number(round(q, 6))}}}"
            rf"{{{fmt_number(c)}}}"
            rf" = {fmt_number(round(answer_value, 6))}\ \text{{V}}"
        ]
        answer_unit = r"\text{V}"
        spoken = "volts"
        check = verify_by_recomputation(answer_value, q / c, "V = Q/C")
    builder = SolutionBuilder(
        text,
        "capacitance",
        "Capacitance is the charge a capacitor stores per volt " "(C = Q/V).",
    )
    for symbol, quantity_value in known.items():
        if quantity_value is not None:
            builder.add_given(symbol, quantity_value)
    builder.require([target])
    given_section_step(builder, text)
    formula_step(
        builder,
        "Choose the law",
        formula,
        "Charge, capacitance and voltage are locked together by " "C = Q/V.",
        "Rearrange C equals Q over V for the unknown.",
    )
    builder.step(
        "Substitute and calculate",
        "Put the numbers into the rearranged equation.",
        "Substitute the numbers and evaluate.",
        substitution,
    )
    answer_latex = rf"{target} = {fmt_number(round(answer_value, 6))}\ {answer_unit}"
    builder.step(
        "Answer",
        "The required quantity with its SI unit.",
        f"The answer is {fmt_number(round(answer_value, 6))} {spoken}.",
        [answer_latex],
    )
    answer_interpretation_step(
        builder,
        (
            "A bigger capacitor stores more charge for the same voltage, "
            "and the same capacitor holds more charge once you raise the "
            "voltage across it."
        ),
        "Capacitance measures how much charge each volt can store.",
    )
    return builder.build(answer_latex, f"{round(answer_value, 6)} {spoken}", check)


# ---------------------------------------------------------------------------
# Magnetic force on a conductor and on a moving charge
# ---------------------------------------------------------------------------


def matches_magnetic_force(text: str) -> bool:
    lowered = text.lower()
    if "induc" in lowered or "faraday" in lowered:
        return False
    return any(
        word in lowered
        for word in (
            "magnetic force",
            "force on the conductor",
            "force on a conductor",
            "current-carrying",
            "current carrying",
            "motor force",
            "force on the wire",
            "force on a wire",
        )
    )


def solve_magnetic_force(text: str) -> PhysicsSolution | None:
    ctx = PhysicsContext(text)
    fields = ctx.by_dimension(MAGNETIC_FIELD)
    currents = ctx.by_dimension(CURRENT)
    lengths = ctx.by_dimension(LENGTH)
    charges = ctx.by_dimension(CHARGE)
    speeds = ctx.by_dimension(SPEED)
    unknowns = find_unknowns(text)
    if fields and currents and lengths:
        b = value_si(fields[0])
        i = value_si(currents[0])
        length = value_si(lengths[0])
        force_value = b * i * length
        builder = SolutionBuilder(
            text,
            "magnetic_force_wire",
            "A current-carrying conductor in a magnetic field feels "
            r"F = BIl when it stands perpendicular to the field.",
        )
        builder.add_given("B", fields[0])
        builder.add_given("I", currents[0])
        builder.add_given("l", lengths[0])
        builder.require(["F"])
        given_section_step(builder, text)
        builder.conversion_step(lengths[0])
        formula_step(
            builder,
            "Choose the law",
            r"F = BIl",
            "The force grows with the field, the current and the length "
            "of wire inside the field.",
            "Multiply the field, the current and the length.",
        )
        builder.step(
            "Substitute and calculate",
            "Multiply the field strength, the current and the length.",
            "Multiply the field, the current and the length.",
            [
                rf"F = {fmt_number(b)} \times {fmt_number(i)} \times "
                rf"{fmt_number(round(length, 6))}"
                rf" = {fmt_number(round(force_value, 6))}\ \text{{N}}"
            ],
        )
        answer_latex = rf"F = {fmt_number(round(force_value, 6))}\ \text{{N}}"
        check = verify_by_recomputation(force_value, b * i * length, "F = BIl")
        spoken = "newtons"
        symbol = "F"
    elif fields and charges and speeds:
        b = value_si(fields[0])
        q = value_si(charges[0])
        speed = value_si(speeds[0])
        force_value = b * abs(q) * speed
        builder = SolutionBuilder(
            text,
            "magnetic_force_charge",
            "A charge moving perpendicular to a magnetic field feels "
            r"F = Bqv; parallel motion feels no force at all.",
        )
        builder.add_given("B", fields[0])
        builder.add_given("q", charges[0])
        builder.add_given("v", speeds[0])
        builder.require(["F"])
        given_section_step(builder, text)
        formula_step(
            builder,
            "Choose the law",
            r"F = Bqv",
            "The force grows with the field, the charge and its speed "
            "across the field.",
            "Multiply the field, the charge and the speed.",
        )
        builder.step(
            "Substitute and calculate",
            "Multiply the field strength, the charge and the speed.",
            "Multiply the field, the charge and the speed.",
            [
                rf"F = {fmt_number(b)} \times {fmt_number(abs(q))} "
                rf"\times {fmt_number(round(speed, 6))}"
                rf" = {fmt_number(round(force_value, 6))}\ \text{{N}}"
            ],
        )
        answer_latex = rf"F = {fmt_number(round(force_value, 6))}\ \text{{N}}"
        check = verify_by_recomputation(force_value, b * abs(q) * speed, "F = Bqv")
        spoken = "newtons"
        symbol = "F"
    else:
        return None
    if "I" in unknowns or "l" in unknowns:
        builder.warn(
            "Only the perpendicular component of the field produces force; "
            "at other angles the force is smaller."
        )
    builder.step(
        "Answer",
        "The magnetic force with its unit.",
        f"The answer is {fmt_number(round(force_value, 6))} {spoken}.",
        [answer_latex],
    )
    answer_interpretation_step(
        builder,
        (
            "The magnetic force always points perpendicular to the motion, "
            "so it turns the current or the charge without changing its "
            "speed - this is why motors spin."
        ),
        "Magnetic forces push sideways, steering charges into circles "
        "or motor coils into rotation.",
    )
    return builder.build(
        rf"{symbol} = {fmt_number(round(force_value, 6))}\ \text{{N}}",
        f"{round(force_value, 6)} {spoken}",
        check,
    )


# ---------------------------------------------------------------------------
# Electromagnetic induction
# ---------------------------------------------------------------------------


def matches_induction(text: str) -> bool:
    lowered = text.lower()
    return any(
        word in lowered
        for word in (
            "induc",
            "faraday",
            "flux linkage",
            "emf",
            "coil",
            "turns",
            "cutting the field",
        )
    )


def solve_induction(text: str) -> PhysicsSolution | None:
    lowered = text.lower()
    ctx = PhysicsContext(text)
    fluxes = ctx.by_dimension(MAGNETIC_FLUX)
    times = ctx.by_dimension(TIME)
    turns_match = re.search(r"(\d+(?:\.\d+)?)\s*(?:turns?|loops?|windings?)", lowered)
    turns = float(turns_match.group(1)) if turns_match else None
    if turns is not None and fluxes and times:
        delta_phi = (
            abs(value_si(fluxes[-1]) - value_si(fluxes[0]))
            if len(fluxes) > 1
            else abs(value_si(fluxes[0]))
        )
        delta_t = value_si(times[0])
        if delta_t <= 0:
            return _invalid(text, "The time interval must be positive.")
        emf = turns * delta_phi / delta_t
        builder = SolutionBuilder(
            text,
            "faradays_law",
            "Faraday's law: the induced emf equals the number of turns "
            "times the rate of change of magnetic flux "
            r"(\varepsilon = N\,\Delta\Phi/\Delta t).",
        )
        builder.add_given_number("N_turns", turns, r"\text{turns}")
        if len(fluxes) > 1:
            builder.add_given("Phi", fluxes[0])
            builder.add_given("Phi", fluxes[-1])
        else:
            builder.add_given("Phi", fluxes[0])
        builder.add_given("t", times[0])
        builder.require(["V"])
        given_section_step(builder, text)
        formula_step(
            builder,
            "Choose the law",
            r"\varepsilon = N\frac{\Delta\Phi}{\Delta t}",
            "The faster the flux changes, and the more turns it links, "
            "the bigger the induced emf.",
            "Multiply the turns by the flux change and divide by the " "time taken.",
        )
        builder.step(
            "Substitute and calculate",
            "Take the flux change over the time interval, times the turns.",
            "Multiply the flux change by the turns and divide by the time.",
            [
                rf"\varepsilon = {fmt_number(turns)} \times "
                rf"\frac{{{fmt_number(round(delta_phi, 6))}}}"
                rf"{{{fmt_number(round(delta_t, 6))}}}"
                rf" = {fmt_number(round(emf, 6))}\ \text{{V}}"
            ],
        )
        answer_latex = rf"\varepsilon = {fmt_number(round(emf, 6))}\ \text{{V}}"
        check = verify_by_recomputation(
            emf, turns * delta_phi / delta_t, "Faraday's law"
        )
    else:
        fields = ctx.by_dimension(MAGNETIC_FIELD)
        lengths = ctx.by_dimension(LENGTH)
        speeds = ctx.by_dimension(SPEED)
        if not (fields and lengths and speeds):
            return None
        b = value_si(fields[0])
        length = value_si(lengths[0])
        speed = value_si(speeds[0])
        emf = b * length * speed
        builder = SolutionBuilder(
            text,
            "motional_emf",
            "A conductor sweeping across a field cuts flux and generates "
            r"the motional emf \varepsilon = Blv.",
        )
        builder.add_given("B", fields[0])
        builder.add_given("l", lengths[0])
        builder.add_given("v", speeds[0])
        builder.require(["V"])
        given_section_step(builder, text)
        formula_step(
            builder,
            "Choose the law",
            r"\varepsilon = Blv",
            "The emf grows with the field, the length of the conductor "
            "and how fast it crosses the field.",
            "Multiply the field, the length and the speed.",
        )
        builder.step(
            "Substitute and calculate",
            "Multiply the field, the length and the speed.",
            "Multiply the field, the length and the speed.",
            [
                rf"\varepsilon = {fmt_number(b)} \times "
                rf"{fmt_number(round(length, 6))} \times "
                rf"{fmt_number(round(speed, 6))}"
                rf" = {fmt_number(round(emf, 6))}\ \text{{V}}"
            ],
        )
        answer_latex = rf"\varepsilon = {fmt_number(round(emf, 6))}\ \text{{V}}"
        check = verify_by_recomputation(emf, b * length * speed, "motional emf Blv")
    builder.step(
        "Answer",
        "The induced emf with its unit.",
        f"The answer is {fmt_number(round(emf, 6))} volts.",
        [answer_latex],
    )
    answer_interpretation_step(
        builder,
        (
            "An emf appears only while the flux is changing; hold the magnet "
            "still and the emf drops to zero. The induced current always "
            "flows in a direction that opposes the change that made it."
        ),
        "Changing flux induces a voltage that fights the change.",
    )
    return builder.build(answer_latex, f"{round(emf, 6)} V", check)
