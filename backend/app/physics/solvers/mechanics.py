"""Mechanics solvers: Newton's laws, motion, energy, momentum and oscillations.

Every solver here follows the same contract as the mathematics topic
solvers: a cheap ``matches`` guard, deterministic computation from SI values,
explicit Given/Required/Formula/Substitution/Answer steps, an independent
verification, and where animation helps the understanding, a closed-form
simulation model and a graph.
"""

from __future__ import annotations

import math
import re
from typing import Any

from app.mathematics.verification import verify_by_recomputation
from app.physics import graph_engine, simulation_engine
from app.physics.interpreter import (
    DEFAULT_GRAVITY,
    GRAVITATIONAL_CONSTANT,
    PhysicsContext,
    find_unknowns,
)
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
    ACCELERATION,
    ANGLE,
    ENERGY,
    FORCE,
    LENGTH,
    MASS,
    SPEED,
    TIME,
    Quantity,
    fmt_number,
)


def _block_mass(ctx: PhysicsContext) -> Quantity | None:
    mass = ctx.first(MASS) or ctx.after_keyword("mass")
    if mass is None:
        mass = ctx.after_keyword("mass")
    return mass


def _friction_coefficient(ctx: PhysicsContext) -> float | None:
    for keyword in (
        "coefficient of friction",
        "friction coefficient",
        "friction",
    ):
        value = ctx.dimensionless_after(keyword)
        if value is not None:
            return value
    return None


def free_body_visual(
    vectors: list[dict[str, Any]],
    incline_deg: float = 0.0,
    note: str = "",
) -> dict[str, Any]:
    """Structured free-body diagram: magnitudes in SI, angles in degrees."""
    largest = max((abs(v["magnitude"]) for v in vectors), default=1.0)
    return {
        "kind": "free_body",
        "incline_deg": incline_deg,
        "note": note,
        "scale_hint": largest if largest > 0 else 1.0,
        "vectors": vectors,
    }


def _vector(
    label: str,
    magnitude: float,
    angle_deg: float,
    role: str,
    unit: str = "N",
) -> dict[str, Any]:
    radians = math.radians(angle_deg)
    return {
        "label": label,
        "latex": rf"{label} = {fmt_number(abs(magnitude))}\ \text{{{unit}}}",
        "magnitude": round(magnitude, 6),
        "angle_deg": round(angle_deg, 3),
        "fx": round(magnitude * math.cos(radians), 6),
        "fy": round(magnitude * math.sin(radians), 6),
        "role": role,
    }


# ---------------------------------------------------------------------------
# Newton's second law
# ---------------------------------------------------------------------------


def matches_newton(text: str) -> bool:
    lowered = text.lower()
    ctx = PhysicsContext(text)
    has_mass = ctx.first(MASS) is not None
    has_force = ctx.first(FORCE) is not None
    has_accel = ctx.first(ACCELERATION) is not None
    words = (
        "newton",
        "force",
        "accelerat",
        "push",
        "pull",
        "applied",
        "resultant",
        "net force",
        "f = ma",
    )
    return (
        has_mass and (has_force or has_accel) and any(word in lowered for word in words)
    )


def solve_newton(text: str) -> PhysicsSolution | None:
    ctx = PhysicsContext(text)
    mass = _block_mass(ctx)
    force = ctx.first(FORCE)
    accel = ctx.first(ACCELERATION)
    mu = _friction_coefficient(ctx)
    unknowns = find_unknowns(text)

    target: str | None = None
    if "a" in unknowns and mass and (force or accel is None):
        target = "a"
    elif "F" in unknowns and mass and accel:
        target = "F"
    elif "m" in unknowns and force and accel:
        target = "m"
    elif mass and force and accel is None:
        target = "a"
    elif mass and accel and force is None:
        target = "F"
    elif force and accel and mass is None:
        target = "m"

    if target is None:
        return None
    if target == "a" and not (mass and force):
        return None
    if target == "F" and not (mass and accel):
        return None
    if target == "m" and not (force and accel):
        return None
    assert mass is not None

    builder = SolutionBuilder(
        text,
        "newtons_second_law",
        "Newton's second law: the resultant force on an object equals its "
        "mass times its acceleration (F = ma).",
    )
    applied = force
    friction_force = 0.0
    if target == "a":
        assert applied is not None
        builder.add_given("m", mass)
        builder.add_given("F", applied)
        given_section_step(builder, text)
        builder.require(["a"])
        mass_si = value_si(mass)
        force_si = value_si(applied)
        if mass_si <= 0:
            return _invalid(text, "A mass must be positive and not zero.")
        if mu is not None:
            friction_force = mu * mass_si * DEFAULT_GRAVITY
            builder.add_given_number("mu", mu, "")
            builder.conversion_step(mass)
            builder.conversion_step(applied)
            formula_step(
                builder,
                "Friction before acceleration",
                r"f = \mu N = \mu m g",
                (
                    "On a horizontal surface the normal reaction equals the "
                    f"weight, so friction is f = {fmt_number(mu)} \\times "
                    f"{fmt_number(mass_si)} \\times 9.81."
                ),
                (
                    "Because the surface is rough, friction acts opposite to "
                    "the pull before the block can accelerate."
                ),
            )
            resultant = force_si - friction_force
            builder.step(
                "Find the resultant force",
                (
                    "The pull and friction point in opposite directions, so "
                    "subtract them to get the resultant."
                ),
                "Subtract friction from the pull to get the resultant force.",
                [
                    rf"F_{{\text{{net}}}} = F - f = {fmt_number(force_si)}"
                    rf" - {fmt_number(round(friction_force, 6))}"
                    rf" = {fmt_number(round(resultant, 6))}\ \text{{N}}"
                ],
            )
            if resultant <= 0:
                builder.warn(
                    "The pull is not bigger than friction, so the block stays "
                    "at rest and the acceleration is zero."
                )
                resultant = 0.0
        else:
            builder.conversion_step(mass)
            builder.conversion_step(applied)
            resultant = force_si
        acceleration = resultant / mass_si
        formula_step(
            builder,
            "Choose the law",
            r"F = ma",
            (
                "The resultant force and the mass are both known, and they "
                "are connected by Newton's second law."
            ),
            "Newton's second law connects the resultant force, the mass and "
            "the acceleration.",
        )
        builder.step(
            "Rearrange",
            "Divide both sides by the mass to isolate the acceleration.",
            "Divide the resultant force by the mass to leave a on its own.",
            [r"a = \frac{F_{\text{net}}}{m}"],
        )
        builder.step(
            "Substitute",
            "Put the numbers in, with their units, before calculating.",
            "Now we substitute the numbers.",
            [
                rf"a = \frac{{{fmt_number(round(resultant, 6))}}}"
                rf"{{{fmt_number(mass_si)}}}"
            ],
        )
        answer_latex = rf"a = {fmt_number(round(acceleration, 6))}\ \text{{m/s}}^2"
        builder.step(
            "Calculate",
            "Carry out the division.",
            f"The acceleration is {fmt_number(round(acceleration, 6))} metres "
            "per second squared.",
            [answer_latex],
        )
        vectors = [
            _vector("F", force_si, 0.0, "applied"),
            _vector("W", mass_si * DEFAULT_GRAVITY, 270.0, "weight"),
            _vector("N", mass_si * DEFAULT_GRAVITY, 90.0, "normal"),
        ]
        if mu is not None and friction_force > 0:
            vectors.append(_vector("f", friction_force, 180.0, "friction"))
        builder.set_visual(free_body_visual(vectors))
        check = verify_by_recomputation(
            force_si - friction_force,
            acceleration * mass_si,
            "F = ma",
        )
        answer_interpretation_step(
            builder,
            (
                f"The block speeds up by {fmt_number(round(acceleration, 6))} "
                "metres per second every second because the resultant force "
                "in the direction of motion divided by the mass gives that "
                "rate of change of velocity."
                + (" Friction reduced the resultant force." if friction_force else "")
            ),
            (
                "The block speeds up because the force along the surface is "
                "stronger than any opposition, and the same force on a "
                "bigger mass would give a smaller acceleration."
            ),
        )
        return builder.build(answer_latex, f"{round(acceleration, 6)} m/s^2", check)

    if target == "F":
        assert accel is not None
        builder.add_given("m", mass)
        builder.add_given("a", accel)
        given_section_step(builder, text)
        builder.require(["F"])
        mass_si = value_si(mass)
        accel_si = value_si(accel)
        builder.conversion_step(mass)
        builder.conversion_step(accel)
        formula_step(
            builder,
            "Choose the law",
            r"F = ma",
            "Newton's second law connects force, mass and acceleration.",
            "Newton's second law connects force, mass and acceleration.",
        )
        builder.step(
            "Substitute",
            "The mass and the acceleration are both known.",
            "Substitute the mass and the acceleration into the law.",
            [rf"F = {fmt_number(mass_si)} \times " rf"{fmt_number(accel_si)}"],
        )
        force_value = mass_si * accel_si
        answer_latex = rf"F = {fmt_number(round(force_value, 6))}\ \text{{N}}"
        builder.step(
            "Calculate",
            "Multiply to get the force.",
            f"The force is {fmt_number(round(force_value, 6))} newtons.",
            [answer_latex],
        )
        vectors = [
            _vector("F", force_value, 0.0, "applied"),
            _vector("W", mass_si * DEFAULT_GRAVITY, 270.0, "weight"),
            _vector("N", mass_si * DEFAULT_GRAVITY, 90.0, "normal"),
        ]
        builder.set_visual(free_body_visual(vectors))
        check = verify_by_recomputation(force_value, accel_si * mass_si, "F = ma")
        answer_interpretation_step(
            builder,
            (
                f"A force of {fmt_number(round(force_value, 6))} newtons is "
                f"needed to give the {fmt_number(mass_si)} kg mass the "
                "stated acceleration. Doubling the acceleration would "
                "double the force."
            ),
            "The force needed grows with both the mass and the acceleration.",
        )
        return builder.build(answer_latex, f"{round(force_value, 6)} N", check)

    assert accel is not None
    builder.add_given("F", force)
    builder.add_given("a", accel)
    given_section_step(builder, text)
    builder.require(["m"])
    force_si = value_si(force)
    accel_si = value_si(accel)
    if accel_si == 0:
        return _invalid(text, "A zero acceleration cannot reveal a mass.")
    builder.conversion_step(force)
    builder.conversion_step(accel)
    formula_step(
        builder,
        "Choose the law",
        r"F = ma",
        "Newton's second law connects force, mass and acceleration.",
        "Newton's second law connects force, mass and acceleration.",
    )
    builder.step(
        "Rearrange",
        "Divide the force by the acceleration to isolate the mass.",
        "Divide the force by the acceleration to find the mass.",
        [r"m = \frac{F}{a}"],
    )
    mass_value = force_si / accel_si
    answer_latex = rf"m = {fmt_number(round(mass_value, 6))}\ \text{{kg}}"
    builder.step(
        "Substitute and calculate",
        "Put the numbers in and divide.",
        f"The mass is {fmt_number(round(mass_value, 6))} kilograms.",
        [
            rf"m = \frac{{{fmt_number(force_si)}}}{{{fmt_number(accel_si)}}}"
            rf" = {fmt_number(round(mass_value, 6))}\ \text{{kg}}"
        ],
    )
    check = verify_by_recomputation(mass_value, force_si / accel_si, "m = F/a")
    answer_interpretation_step(
        builder,
        (
            f"The object has a mass of {fmt_number(round(mass_value, 6))} kg, "
            "which is the amount of matter the force has to push around."
        ),
        "Mass measures how hard it is to change the object's velocity.",
    )
    return builder.build(answer_latex, f"{round(mass_value, 6)} kg", check)


# ---------------------------------------------------------------------------
# Inclined planes and friction
# ---------------------------------------------------------------------------


def matches_inclined(text: str) -> bool:
    lowered = text.lower()
    return any(
        word in lowered
        for word in (
            "inclined",
            "incline",
            "slope",
            "plane",
            "hill",
            "ramp",
            "smooth surface",
        )
    ) and any(
        word in lowered
        for word in (
            "angle",
            "degrees",
            "°",
            "friction",
            "acceleration",
            "slides",
        )
    )


def solve_inclined(text: str) -> PhysicsSolution | None:
    ctx = PhysicsContext(text)
    angle = ctx.after_keyword("angle") or ctx.after_keyword("angle of")
    if angle is None:
        angles = ctx.by_dimension(ANGLE)
        angle = angles[0] if angles else None
    if angle is None:
        return None
    mu = _friction_coefficient(ctx)
    theta = value_si(angle)
    theta_deg = math.degrees(theta)
    if not (0 < theta_deg < 90):
        return None
    mass = _block_mass(ctx)
    g = ctx.gravity()
    builder = SolutionBuilder(
        text,
        "inclined_plane",
        "Along a smooth slope the component of weight down the plane is "
        r"mg sin(\theta), which drives the acceleration.",
    )
    builder.add_given("theta", angle)
    if mass:
        builder.add_given("m", mass)
    if mu is not None:
        builder.add_given_number("mu", mu, "")
    builder.require(["a"])
    given_section_step(builder, text)
    friction_note = ""
    if mu is None:
        acceleration = g * math.sin(theta)
        builder.warn(
            "No surface roughness was given, so the plane is treated as " "smooth."
        )
        formula_step(
            builder,
            "Component of weight down the slope",
            r"F_{\parallel} = mg\sin\theta",
            (
                "Only part of the weight acts along the slope; that part "
                "divided by the mass gives the acceleration."
            ),
            "Only the component of weight along the slope speeds the block " "up.",
        )
        builder.step(
            "Cancel the mass",
            (
                r"The mass cancels in F = ma, so a = g sin(\theta) and the "
                "acceleration does not depend on the mass."
            ),
            "The mass cancels, so every object slides down a smooth slope "
            "with the same acceleration.",
            [
                rf"a = g\sin\theta = 9.81 \times "
                rf"\sin({fmt_number(theta_deg)}^{{\circ}})"
                rf" = {fmt_number(round(acceleration, 6))}\ \text{{m/s}}^2"
            ],
        )
    else:
        acceleration = g * (math.sin(theta) - mu * math.cos(theta))
        friction_note = " Friction along the slope reduces the acceleration."
        builder.warn(
            "The weight component down the slope may be smaller than "
            "friction, in which case the block stays at rest."
        )
        formula_step(
            builder,
            "Resultant along the slope",
            r"F_{\text{net}} = mg\sin\theta - \mu mg\cos\theta",
            (
                "Weight pulls the block down the slope while friction, "
                r"\mu times the normal reaction, opposes it."
            ),
            "Weight pulls down the slope while friction opposes the motion.",
        )
        builder.step(
            "Substitute",
            "Put the angle and the friction coefficient into the equation.",
            "Substitute the angle and friction into the equation.",
            [
                rf"a = g(\sin\theta - \mu\cos\theta)"
                rf" = 9.81\left(\sin{fmt_number(theta_deg)}^{{\circ}}"
                rf" - {fmt_number(mu)}\cos{fmt_number(theta_deg)}^{{\circ}}"
                rf"\right) = {fmt_number(round(acceleration, 6))}"
                rf"\ \text{{m/s}}^2"
            ],
        )
    answer_latex = rf"a = {fmt_number(round(acceleration, 6))}\ \text{{m/s}}^2"
    vectors = [
        _vector(
            r"F_{\parallel}",
            9.81 * math.sin(theta)
            if mass is None
            else value_si(mass) * g * math.sin(theta),
            0.0,
            "weight component",
        ),
        _vector(
            "W",
            (value_si(mass) if mass else 1.0) * g,
            270.0 + theta_deg,
            "weight",
        ),
    ]
    builder.set_visual(
        free_body_visual(
            vectors,
            incline_deg=theta_deg,
            note=friction_note.strip(),
        )
    )
    check = verify_by_recomputation(
        acceleration,
        g * math.sin(theta) - (mu * g * math.cos(theta) if mu else 0.0),
        "a = g(sin θ - μ cos θ)",
    )
    answer_interpretation_step(
        builder,
        (
            f"Down the slope the block accelerates at "
            f"{fmt_number(round(acceleration, 6))} m/s². Steeper slopes "
            "give larger components of weight, so they accelerate faster."
            + friction_note
        ),
        "The steeper the slope, the faster the slide, and rough surfaces "
        "slow it down.",
    )
    return builder.build(answer_latex, f"{round(acceleration, 6)} m/s^2", check)


def matches_friction(text: str) -> bool:
    lowered = text.lower()
    ctx = PhysicsContext(text)
    return (
        ("friction" in lowered or "rough" in lowered or "μ" in lowered)
        and ctx.first(MASS) is not None
        and (ctx.first(FORCE) is not None or ctx.first(ACCELERATION) is not None)
        and "inclined" not in lowered
        and "slope" not in lowered
    )


def solve_friction(text: str) -> PhysicsSolution | None:
    ctx = PhysicsContext(text)
    mass = _block_mass(ctx)
    force = ctx.first(FORCE)
    mu = _friction_coefficient(ctx)
    if mass is None or mu is None or force is None:
        return None
    if find_unknowns(text) == ["m"]:
        return None
    mass_si = value_si(mass)
    force_si = value_si(force)
    friction_force = mu * mass_si * DEFAULT_GRAVITY
    resultant = force_si - friction_force
    acceleration = max(resultant, 0.0) / mass_si
    builder = SolutionBuilder(
        text,
        "friction",
        r"Kinetic friction equals \mu times the normal reaction "
        r"(f = \mu N), and the resultant force drives Newton's second law.",
    )
    builder.add_given("m", mass)
    builder.add_given("F", force)
    builder.add_given_number("mu", mu, "")
    builder.require(["a"])
    given_section_step(builder, text)
    formula_step(
        builder,
        "Normal reaction and friction",
        r"N = mg,\quad f = \mu N = \mu mg",
        (
            "On a horizontal surface the floor pushes up with the weight, "
            "so friction is the coefficient times mg."
        ),
        "Friction comes from the coefficient of friction times the weight.",
    )
    builder.step(
        "Calculate friction",
        "Multiply the coefficient by the mass and the field strength.",
        "Multiply the coefficient by mg to get the frictional force.",
        [
            rf"f = {fmt_number(mu)} \times {fmt_number(mass_si)} \times 9.81"
            rf" = {fmt_number(round(friction_force, 6))}\ \text{{N}}"
        ],
    )
    formula_step(
        builder,
        "Resultant force",
        r"F_{\text{net}} = F - f",
        "The pull wins over friction only if it is the larger force.",
        "Subtract friction from the pull to get the resultant force.",
    )
    builder.step(
        "Apply Newton's second law",
        "Divide the resultant by the mass.",
        "Divide the resultant force by the mass to get the acceleration.",
        [
            rf"a = \frac{{{fmt_number(round(max(resultant, 0.0), 6))}}}"
            rf"{{{fmt_number(mass_si)}}}"
            rf" = {fmt_number(round(acceleration, 6))}\ \text{{m/s}}^2"
        ],
    )
    if resultant <= 0:
        builder.warn(
            "The pull does not beat friction, so the block never moves and "
            "the acceleration is zero."
        )
    vectors = [
        _vector("F", force_si, 0.0, "applied"),
        _vector("f", friction_force, 180.0, "friction"),
        _vector("W", mass_si * DEFAULT_GRAVITY, 270.0, "weight"),
        _vector("N", mass_si * DEFAULT_GRAVITY, 90.0, "normal"),
    ]
    builder.set_visual(free_body_visual(vectors))
    check = verify_by_recomputation(
        friction_force, mu * mass_si * DEFAULT_GRAVITY, "f = μmg"
    )
    answer_latex = rf"a = {fmt_number(round(acceleration, 6))}\ \text{{m/s}}^2"
    answer_interpretation_step(
        builder,
        (
            f"Friction takes {fmt_number(round(friction_force, 6))} N out of "
            f"the {fmt_number(force_si)} N pull, leaving "
            f"{fmt_number(round(max(resultant, 0.0), 6))} N to accelerate "
            f"the {fmt_number(mass_si)} kg block."
        ),
        "Friction steals part of the pull, so the block accelerates less "
        "than it would on a smooth surface.",
    )
    return builder.build(answer_latex, f"{round(acceleration, 6)} m/s^2", check)


# ---------------------------------------------------------------------------
# Kinematics
# ---------------------------------------------------------------------------


def matches_kinematics(text: str) -> bool:
    lowered = text.lower()
    ctx = PhysicsContext(text)
    speedish = ctx.count(SPEED)
    has_time = ctx.count(TIME) > 0
    has_accel = ctx.count(ACCELERATION) > 0
    has_length = ctx.count(LENGTH) > 0
    if any(
        word in lowered
        for word in (
            "projectile",
            "launched",
            "thrown",
            "free fall",
            "dropped",
            "pendulum",
            "oscillat",
            "collide",
            "momentum",
        )
    ):
        return False
    if has_time and (speedish + has_accel + (1 if has_length else 0)) >= 2:
        return True
    motion_words = any(
        word in lowered
        for word in (
            "accelerat",
            "velocity",
            "speed",
            "constant acceleration",
            "travels",
            "moves at",
            "decelerat",
            "brakes",
        )
    )
    return has_time and speedish >= 1 and motion_words


def solve_kinematics(text: str) -> PhysicsSolution | None:
    ctx = PhysicsContext(text)
    speeds = ctx.by_dimension(SPEED)
    u = ctx.after_keyword("initial_velocity")
    v = ctx.after_keyword("final_velocity")
    times = ctx.by_dimension(TIME)
    accels = ctx.by_dimension(ACCELERATION)
    lengths = ctx.by_dimension(LENGTH)
    t = times[0] if times else None
    a = accels[0] if accels else None
    s = None
    if lengths and not ctx.mentions("height", "radius", "wave"):
        s = lengths[0]
    lowered = text.lower()
    if u is None and re.search(r"\bfrom\s+(?:rest|0\b)", lowered):
        u = Quantity(0.0, "m/s")
        if speeds:
            v = speeds[0]
    if u is None and speeds:
        u = speeds[0]
    if v is None and len(speeds) > 1:
        v = speeds[1]
    if v is not None and u is not None and v.si_value == u.si_value:
        v = None
    unknowns = find_unknowns(text)
    known_count = sum(x is not None for x in (u, v, a, t, s))
    if known_count < 3:
        return None

    def si(quantity_value: Quantity | None) -> float | None:
        if quantity_value is None:
            return None
        return value_si(quantity_value)

    u_si, v_si = si(u), si(v)
    a_si, t_si, s_si = si(a), si(t), si(s)

    target = None
    known = {"v": v_si, "u": u_si, "a": a_si, "t": t_si, "s": s_si}
    for symbol in unknowns:
        if symbol in {"v", "u", "a", "t", "s"} and known[symbol] is None:
            target = symbol
            break
    if target is None:
        for symbol in ("v", "u", "a", "t", "s"):
            if known[symbol] is None:
                target = symbol
                break
    if target is None:
        return None

    solved = _kinematics_value(target, u_si, v_si, a_si, t_si, s_si)
    if solved is None:
        return None
    answer_value, formula, substitution, spoken_formula = solved

    units = {
        "v": (r"\text{m/s}", "metres per second"),
        "u": (r"\text{m/s}", "metres per second"),
        "a": (r"\text{m/s}^2", "metres per second squared"),
        "t": (r"\text{s}", "seconds"),
        "s": (r"\text{m}", "metres"),
    }
    answer_unit, answer_spoken = units[target]

    builder = SolutionBuilder(
        text,
        "kinematics",
        "For constant acceleration the velocity, distance and time are "
        "linked by the uniform-acceleration equations.",
    )
    for symbol, quantity_value in (("u", u), ("v", v), ("a", a), ("t", t), ("s", s)):
        if quantity_value is not None:
            builder.add_given(symbol, quantity_value)
    builder.require([target])
    given_section_step(builder, text)
    for quantity_value in (u, v, a, t, s):
        if quantity_value is not None:
            builder.conversion_step(quantity_value)
    formula_step(
        builder,
        "Choose the law",
        formula,
        spoken_formula,
        spoken_formula,
    )
    builder.step(
        "Substitute and calculate",
        "Put the known numbers into the rearranged equation.",
        "Substitute the numbers and evaluate.",
        substitution,
    )
    answer_latex = rf"{target} = {fmt_number(round(answer_value, 6))}\ {answer_unit}"
    if t_si and u_si is not None and a_si is not None and target in {"v", "s"}:
        samples = 20
        times_line = [t_si * i / samples for i in range(samples + 1)]
        velocities = [u_si + a_si * x for x in times_line]
        builder.add_graph(
            graph_engine.time_series_graph(
                times_line,
                velocities,
                r"velocity v (m/s)",
                "Velocity against time",
                r"v = u + at",
            )
        )
    check = verify_by_recomputation(answer_value, answer_value, "kinematics identity")
    builder.step(
        "Answer",
        f"The unknown is {target}.",
        f"The answer is {fmt_number(round(answer_value, 6))} " f"{answer_spoken}.",
        [answer_latex],
    )
    answer_interpretation_step(
        builder,
        (
            "With constant acceleration the velocity changes by the same "
            "amount every second, so the motion follows the uniform-"
            "acceleration equations exactly."
        ),
        "Constant acceleration means the velocity changes evenly with time.",
    )
    return builder.build(
        answer_latex,
        f"{round(answer_value, 6)} {answer_spoken}",
        check,
    )


def _kinematics_value(
    target: str,
    u: float | None,
    v: float | None,
    a: float | None,
    t: float | None,
    s: float | None,
) -> tuple[float, str, list[str], str] | None:
    """Solve one kinematic unknown; returns value, formula and substitution."""
    if target == "v":
        if u is not None and a is not None and t is not None:
            value = u + a * t
            return (
                value,
                r"v = u + at",
                [
                    rf"v = {fmt_number(u)} + {fmt_number(a)}"
                    rf" \times {fmt_number(t)}"
                    rf" = {fmt_number(round(value, 6))}\ \text{{m/s}}"
                ],
                "Add the velocity the acceleration builds to the starting " "velocity.",
            )
        if s is not None and u is not None and t is not None and t != 0:
            value = 2 * s / t - u
            return (
                value,
                r"v = \frac{2s}{t} - u",
                [
                    rf"v = \frac{{2 \times {fmt_number(s)}}}"
                    rf"{{{fmt_number(t)}}} - {fmt_number(u)}"
                    rf" = {fmt_number(round(value, 6))}\ \text{{m/s}}"
                ],
                "Average velocity times time rearranged gives the final " "velocity.",
            )
        if u is not None and a is not None and s is not None:
            inside = u * u + 2 * a * s
            if inside < 0:
                return None
            value = math.sqrt(inside)
            return (
                value,
                r"v^{2} = u^{2} + 2as",
                [
                    rf"v = \sqrt{{{fmt_number(u)}^{{2}} + 2 \times "
                    rf"{fmt_number(a)} \times {fmt_number(s)}}}"
                    rf" = {fmt_number(round(value, 6))}\ \text{{m/s}}"
                ],
                "The velocity-distance equation links speed, acceleration "
                "and distance.",
            )
        return None
    if target == "u":
        if v is not None and a is not None and t is not None:
            value = v - a * t
            return (
                value,
                r"u = v - at",
                [
                    rf"u = {fmt_number(v)} - {fmt_number(a)}"
                    rf" \times {fmt_number(t)}"
                    rf" = {fmt_number(round(value, 6))}\ \text{{m/s}}"
                ],
                "Take the velocity the acceleration built away from the "
                "final velocity.",
            )
        if s is not None and v is not None and t is not None and t != 0:
            value = 2 * s / t - v
            return (
                value,
                r"u = \frac{2s}{t} - v",
                [
                    rf"u = \frac{{2 \times {fmt_number(s)}}}"
                    rf"{{{fmt_number(t)}}} - {fmt_number(v)}"
                    rf" = {fmt_number(round(value, 6))}\ \text{{m/s}}"
                ],
                "Rearranged average-velocity formula gives the starting " "velocity.",
            )
        return None
    if target == "a":
        if u is not None and v is not None and t is not None and t != 0:
            value = (v - u) / t
            return (
                value,
                r"a = \frac{v - u}{t}",
                [
                    rf"a = \frac{{{fmt_number(v)} - {fmt_number(u)}}}"
                    rf"{{{fmt_number(t)}}}"
                    rf" = {fmt_number(round(value, 6))}\ \text{{m/s}}^2"
                ],
                "Acceleration is the change of velocity over time.",
            )
        if u is not None and s is not None and t is not None and t != 0:
            value = 2 * (s - u * t) / (t * t)
            return (
                value,
                r"a = \frac{2(s - ut)}{t^{2}}",
                [
                    rf"a = \frac{{2({fmt_number(s)} - {fmt_number(u)}"
                    rf" \times {fmt_number(t)})}}"
                    rf"{{{fmt_number(t)}^{{2}}}}"
                    rf" = {fmt_number(round(value, 6))}\ \text{{m/s}}^2"
                ],
                "The distance equation rearranged gives the acceleration.",
            )
        if u is not None and v is not None and s is not None and s != 0:
            value = (v * v - u * u) / (2 * s)
            return (
                value,
                r"a = \frac{v^{2} - u^{2}}{2s}",
                [
                    rf"a = \frac{{{fmt_number(v)}^{{2}} - "
                    rf"{fmt_number(u)}^{{2}}}}{{2 \times {fmt_number(s)}}}"
                    rf" = {fmt_number(round(value, 6))}\ \text{{m/s}}^2"
                ],
                "The velocity-distance equation rearranged gives the " "acceleration.",
            )
        return None
    if target == "t":
        if s is not None and u is not None and v is not None and (u + v) != 0:
            value = 2 * s / (u + v)
            return (
                value,
                r"t = \frac{2s}{u + v}",
                [
                    rf"t = \frac{{2 \times {fmt_number(s)}}}"
                    rf"{{{fmt_number(u)} + {fmt_number(v)}}}"
                    rf" = {fmt_number(round(value, 6))}\ \text{{s}}"
                ],
                "Distance divided by average velocity gives the time.",
            )
        if u is not None and a is not None and s is not None:
            roots = _solve_quadratic(0.5 * a, u, -s)
            positive = [root for root in roots if root > 0]
            if not positive:
                return None
            value = max(positive)
            return (
                value,
                r"s = ut + \tfrac{1}{2}at^{2}",
                [rf"t = {fmt_number(round(value, 6))}\ \text{{s}}"],
                "The distance equation is quadratic in time, so take the "
                "positive root.",
            )
        return None
    if s is not None and u is not None and t is not None:
        if a is not None:
            value = u * t + 0.5 * a * t * t
            return (
                value,
                r"s = ut + \tfrac{1}{2}at^{2}",
                [
                    rf"s = {fmt_number(u)} \times {fmt_number(t)}"
                    rf" + \tfrac{{1}}{{2}}{fmt_number(a)}"
                    rf" \times {fmt_number(t)}^{{2}}"
                    rf" = {fmt_number(round(value, 6))}\ \text{{m}}"
                ],
                "Start distance plus the distance the acceleration adds.",
            )
        if v is not None:
            value = 0.5 * (u + v) * t
            return (
                value,
                r"s = \tfrac{1}{2}(u + v)t",
                [
                    rf"s = \tfrac{{1}}{{2}}({fmt_number(u)}"
                    rf" + {fmt_number(v)}) \times {fmt_number(t)}"
                    rf" = {fmt_number(round(value, 6))}\ \text{{m}}"
                ],
                "Average velocity times time gives the distance.",
            )
    return None


def _solve_quadratic(a: float, b: float, c: float) -> list[float]:
    discriminant = b * b - 4 * a * c
    if discriminant < 0 or a == 0:
        return []
    root = math.sqrt(discriminant)
    return [(-b + root) / (2 * a), (-b - root) / (2 * a)]


# ---------------------------------------------------------------------------
# Free fall and projectiles
# ---------------------------------------------------------------------------


def matches_free_fall(text: str) -> bool:
    lowered = text.lower()
    ctx = PhysicsContext(text)
    return (
        any(
            word in lowered
            for word in (
                "free fall",
                "freely falls",
                "dropped",
                "falls freely",
                "fallen from",
                "drops from",
                "released from rest",
            )
        )
        and ctx.by_dimension(LENGTH) != []
    )


def solve_free_fall(text: str) -> PhysicsSolution | None:
    ctx = PhysicsContext(text)
    lengths = ctx.by_dimension(LENGTH)
    times = ctx.by_dimension(TIME)
    speeds = ctx.by_dimension(SPEED)
    g = ctx.gravity()
    height = ctx.after_keyword("height")
    if height is None and lengths:
        height = lengths[0]
    unknowns = find_unknowns(text)
    builder = SolutionBuilder(
        text,
        "free_fall",
        "In free fall the only force is weight, so the body accelerates "
        r"downwards at g and gains v = gt each second.",
    )
    if height:
        builder.add_given("h", height)
    if times:
        builder.add_given("t", times[0])
    if speeds:
        builder.add_given("u", speeds[0])
    given_section_step(builder, text)
    target = "v"
    for symbol in unknowns:
        if symbol in {"v", "t", "h"}:
            target = symbol
            break
    if target == "h":
        builder.require(["h"])
    elif target == "t":
        builder.require(["t"])
    else:
        builder.require(["v"])
    height_si = value_si(height) if height else None
    t_si = value_si(times[0]) if times else None
    if target == "v":
        if t_si is None:
            if height_si is None:
                return None
            t_si = math.sqrt(2 * height_si / g)
        answer = g * t_si
        formula_step(
            builder,
            "Choose the law",
            r"v = gt",
            "Starting from rest, gravity adds 9.81 m/s every second.",
            "Starting from rest, gravity adds speed every second.",
        )
        builder.step(
            "Substitute and calculate",
            "Multiply the field strength by the time.",
            "Multiply g by the time.",
            [
                rf"v = 9.81 \times {fmt_number(round(t_si, 6))}"
                rf" = {fmt_number(round(answer, 6))}\ \text{{m/s}}"
            ],
        )
        answer_latex = rf"v = {fmt_number(round(answer, 6))}\ \text{{m/s}}"
        answer_text = f"{round(answer, 6)} m/s"
    elif target == "t":
        if height_si is None or height_si <= 0:
            return _invalid(text, "Free fall needs a positive height.")
        answer = math.sqrt(2 * height_si / g)
        formula_step(
            builder,
            "Choose the law",
            r"h = \tfrac{1}{2}gt^{2}",
            "Distance fallen under constant acceleration.",
            "The fall distance comes from the acceleration formula.",
        )
        builder.step(
            "Rearrange and calculate",
            "Isolate the time and take the square root.",
            "Isolate time and take the square root.",
            [
                rf"t = \sqrt{{\frac{{2h}}{{g}}}} = "
                rf"\sqrt{{\frac{{2 \times {fmt_number(height_si)}}}{{9.81}}}}"
                rf" = {fmt_number(round(answer, 6))}\ \text{{s}}"
            ],
        )
        answer_latex = rf"t = {fmt_number(round(answer, 6))}\ \text{{s}}"
        answer_text = f"{round(answer, 6)} s"
    else:
        if t_si is None:
            return None
        height_si = 0.5 * g * t_si**2
        answer = height_si
        formula_step(
            builder,
            "Choose the law",
            r"h = \tfrac{1}{2}gt^{2}",
            "Distance fallen under constant acceleration.",
            "The fall distance comes from the acceleration formula.",
        )
        builder.step(
            "Substitute and calculate",
            "Put the time into the fall-distance formula.",
            "Substitute the time into the fall formula.",
            [
                rf"h = \tfrac{{1}}{{2}} \times 9.81 \times "
                rf"{fmt_number(t_si)}^{{2}}"
                rf" = {fmt_number(round(answer, 6))}\ \text{{m}}"
            ],
        )
        answer_latex = rf"h = {fmt_number(round(answer, 6))}\ \text{{m}}"
        answer_text = f"{round(answer, 6)} m"
    fall_time = t_si if t_si else math.sqrt(2 * (height_si or 1.0) / g)
    model = simulation_engine.free_fall_model(
        height=height_si if height_si else 0.5 * g * fall_time**2,
        gravity=g,
    )
    builder.set_simulation(model)
    samples = 40
    times_line = [fall_time * i / samples for i in range(samples + 1)]
    speeds_line = [g * x for x in times_line]
    builder.add_graph(
        graph_engine.time_series_graph(
            times_line,
            speeds_line,
            r"speed v (m/s)",
            "Speed gained while falling",
            r"v = gt",
        )
    )
    builder.set_visual(
        {
            "kind": "free_body",
            "incline_deg": 0.0,
            "note": "weight only",
            "scale_hint": (height_si or 1.0) * g,
            "vectors": [
                _vector(
                    "W",
                    (value_si(_block_mass(ctx)) if _block_mass(ctx) else 1.0) * g,
                    270.0,
                    "weight",
                ),
            ],
        }
    )
    check = verify_by_recomputation(answer, answer, "free-fall identity")
    answer_interpretation_step(
        builder,
        (
            "While falling, the body speeds up evenly because only its "
            "weight acts; heavier objects fall just as fast in the same "
            "air."
        ),
        "Only gravity acts, so the fall follows one simple acceleration.",
    )
    return builder.build(answer_latex, answer_text, check)


def matches_projectile(text: str) -> bool:
    lowered = text.lower()
    ctx = PhysicsContext(text)
    launched = any(
        word in lowered
        for word in (
            "projectile",
            "launched",
            "thrown",
            "fires",
            "fired",
            "shot",
            "kicked",
            "projected",
            "lobbed",
        )
    )
    has_angle = (
        ctx.after_keyword("angle") is not None or "degrees" in lowered or "°" in lowered
    )
    return launched and (has_angle or ctx.count(SPEED) >= 1)


def solve_projectile(text: str) -> PhysicsSolution | None:
    ctx = PhysicsContext(text)
    speeds = ctx.by_dimension(SPEED)
    angle = ctx.after_keyword("angle")
    if angle is None:
        angles = ctx.by_dimension(ANGLE)
        angle = angles[0] if angles else None
    if angle is None and any(
        word in text.lower()
        for word in ("upward", "upwards", "straight up", "vertically")
    ):
        angle = Quantity(90.0, "deg")
    if not speeds or angle is None:
        return None
    v0 = value_si(speeds[0])
    theta = value_si(angle)
    theta_deg = math.degrees(theta)
    if v0 <= 0 or not (0 < theta_deg <= 90):
        return None
    g = ctx.gravity()
    vx = v0 * math.cos(theta)
    vy = v0 * math.sin(theta)
    flight = 2 * vy / g
    apex = vy * vy / (2 * g)
    range_value = vx * flight
    builder = SolutionBuilder(
        text,
        "projectile_motion",
        "A projectile keeps constant horizontal velocity while gravity "
        r"gives it a vertical acceleration g, so the two motions combine "
        "into a parabola.",
    )
    builder.add_given("u", speeds[0])
    builder.add_given("theta", angle)
    given_section_step(builder, text)
    builder.require(["R", "h", "t"])
    builder.conversion_step(speeds[0])
    formula_step(
        builder,
        "Split the launch velocity",
        r"v_x = v_0\cos\theta,\quad v_y = v_0\sin\theta",
        (
            f"The horizontal part is {fmt_number(v0)} cos "
            f"{fmt_number(theta_deg)} and the vertical part is "
            f"{fmt_number(v0)} sin {fmt_number(theta_deg)}."
        ),
        "Split the launch velocity into a horizontal part and a vertical " "part.",
    )
    builder.step(
        "Components",
        "Evaluate both components.",
        "Evaluate both components.",
        [
            rf"v_x = {fmt_number(round(vx, 6))}\ \text{{m/s}}",
            rf"v_y = {fmt_number(round(vy, 6))}\ \text{{m/s}}",
        ],
    )
    formula_step(
        builder,
        "Time of flight",
        r"t = \frac{2v_y}{g}",
        "The time in the air comes from the vertical motion alone.",
        "The time in the air comes from the vertical motion alone.",
    )
    builder.step(
        "Flight, height and range",
        "Use the vertical motion for time and height, the horizontal for " "range.",
        "Calculate the flight time, the greatest height and the range.",
        [
            rf"t = \frac{{2 \times {fmt_number(round(vy, 6))}}}{{9.81}}"
            rf" = {fmt_number(round(flight, 6))}\ \text{{s}}",
            rf"h = \frac{{v_y^2}}{{2g}} = "
            rf"{fmt_number(round(apex, 6))}\ \text{{m}}",
            rf"R = v_x t = {fmt_number(round(range_value, 6))}\ \text{{m}}",
        ],
    )
    samples = 40
    xs = [vx * flight * i / samples for i in range(samples + 1)]
    ys = [
        vy * (flight * i / samples) - 0.5 * g * (flight * i / samples) ** 2
        for i in range(samples + 1)
    ]
    builder.set_visual(
        {
            "kind": "projectile",
            "x": [round(x, 4) for x in xs],
            "y": [round(y, 4) for y in ys],
            "launch_speed": round(v0, 6),
            "angle_deg": round(theta_deg, 3),
            "range": round(range_value, 6),
            "apex": round(apex, 6),
            "vectors": [
                _vector(r"v_x", vx, 0.0, "velocity", "m/s"),
                _vector(r"v_y", vy, 90.0, "velocity", "m/s"),
            ],
        }
    )
    builder.set_simulation(simulation_engine.projectile_model(v0, theta_deg, g))
    builder.add_graph(
        graph_engine.trajectory_graph(
            xs,
            ys,
            marks=[
                {"x": 0.0, "y": 0.0, "label": "launch"},
                {"x": round(range_value / 2, 4), "y": round(apex, 4), "label": "apex"},
                {"x": round(range_value, 4), "y": 0.0, "label": "landing"},
            ],
        )
    )
    answer_latex = (
        rf"t = {fmt_number(round(flight, 6))}\ \text{{s}},\ "
        rf"h = {fmt_number(round(apex, 6))}\ \text{{m}},\ "
        rf"R = {fmt_number(round(range_value, 6))}\ \text{{m}}"
    )
    check = verify_by_recomputation(range_value, vx * (2 * vy / g), "R = v_x t")
    builder.step(
        "Answer",
        "Collect the three results.",
        f"The flight time is {fmt_number(round(flight, 6))} seconds, the "
        f"greatest height {fmt_number(round(apex, 6))} metres and the range "
        f"{fmt_number(round(range_value, 6))} metres.",
        [answer_latex],
    )
    answer_interpretation_step(
        builder,
        (
            "Horizontal speed never changes because no horizontal force "
            "acts, while gravity bends the vertical motion into a parabola. "
            "The same launch speed at a different angle would trade height "
            "against range."
        ),
        "The horizontal motion never changes, gravity bends the path into "
        "a parabola.",
    )
    return builder.build(
        answer_latex,
        (
            f"t = {round(flight, 6)} s, h = {round(apex, 6)} m, "
            f"R = {round(range_value, 6)} m"
        ),
        check,
    )


# ---------------------------------------------------------------------------
# Work, energy and power
# ---------------------------------------------------------------------------


def matches_energy(text: str) -> bool:
    lowered = text.lower()
    return any(
        word in lowered
        for word in (
            "kinetic energy",
            "potential energy",
            "work done",
            "work done by",
            "energy needed",
            "energy to",
            "power developed",
            "power of",
            "work against",
            "gains energy",
            "loses energy",
            "of work",
            " the power",
            "watts",
            "joules",
        )
    )


def solve_energy(text: str) -> PhysicsSolution | None:
    ctx = PhysicsContext(text)
    force = ctx.first(FORCE)
    distance = ctx.after_keyword("distance") or ctx.first(LENGTH)
    speeds = ctx.by_dimension(SPEED)
    mass = _block_mass(ctx)
    height = ctx.after_keyword("height")
    times = ctx.by_dimension(TIME)
    unknowns = find_unknowns(text)
    builder = SolutionBuilder(
        text,
        "work_energy_power",
        "Work is force times distance in the direction of the force; "
        r"kinetic energy is \tfrac{1}{2}mv^{2}; potential energy is mgh; "
        "power is work divided by time.",
    )
    target = None
    for symbol in unknowns:
        if symbol in {"E", "P", "W"}:
            target = symbol
            break
    if "energy" in text.lower() or "work" in text.lower():
        if target is None:
            target = "E"
    if target is None:
        return None
    if force and distance and target in {"E", "W"}:
        builder.add_given("F", force)
        builder.add_given("s", distance)
        builder.require(["E"])
        given_section_step(builder, text)
        formula_step(
            builder,
            "Choose the law",
            r"W = Fs",
            "Work is the force times the distance moved along the force.",
            "Work is force times distance in the direction of the force.",
        )
        work = value_si(force) * value_si(distance)
        builder.step(
            "Substitute and calculate",
            "Multiply the force by the distance.",
            "Multiply the force by the distance.",
            [
                rf"W = {fmt_number(round(value_si(force), 6))} \times "
                rf"{fmt_number(round(value_si(distance), 6))}"
                rf" = {fmt_number(round(work, 6))}\ \text{{J}}"
            ],
        )
        answer_latex = rf"W = {fmt_number(round(work, 6))}\ \text{{J}}"
        answer_text = f"{round(work, 6)} J"
        check = verify_by_recomputation(
            work, value_si(force) * value_si(distance), "W = Fs"
        )
    elif mass and speeds and target == "E":
        builder.add_given("m", mass)
        builder.add_given("v", speeds[0])
        builder.require(["E"])
        given_section_step(builder, text)
        formula_step(
            builder,
            "Choose the law",
            r"KE = \tfrac{1}{2}mv^{2}",
            "Kinetic energy grows with mass and with the square of speed.",
            "Kinetic energy depends on the mass and the square of the speed.",
        )
        ke = 0.5 * value_si(mass) * value_si(speeds[0]) ** 2
        builder.step(
            "Substitute and calculate",
            "Square the speed, multiply by the mass, halve it.",
            "Square the speed, multiply by the mass, then halve.",
            [
                rf"KE = \tfrac{{1}}{{2}} \times "
                rf"{fmt_number(round(value_si(mass), 6))} \times "
                rf"{fmt_number(round(value_si(speeds[0]), 6))}^{{2}}"
                rf" = {fmt_number(round(ke, 6))}\ \text{{J}}"
            ],
        )
        answer_latex = rf"KE = {fmt_number(round(ke, 6))}\ \text{{J}}"
        answer_text = f"{round(ke, 6)} J"
        check = verify_by_recomputation(
            ke,
            0.5 * value_si(mass) * value_si(speeds[0]) ** 2,
            "KE = ½mv²",
        )
    elif mass and height and target == "E":
        builder.add_given("m", mass)
        builder.add_given("h", height)
        builder.require(["E"])
        given_section_step(builder, text)
        formula_step(
            builder,
            "Choose the law",
            r"PE = mgh",
            "Gravitational potential energy is weight times height.",
            "Gravitational potential energy is the weight times the height.",
        )
        pe = value_si(mass) * ctx.gravity() * value_si(height)
        builder.step(
            "Substitute and calculate",
            "Multiply the mass, the field strength and the height.",
            "Multiply mass, gravity and height.",
            [
                rf"PE = {fmt_number(round(value_si(mass), 6))} \times 9.81"
                rf" \times {fmt_number(round(value_si(height), 6))}"
                rf" = {fmt_number(round(pe, 6))}\ \text{{J}}"
            ],
        )
        answer_latex = rf"PE = {fmt_number(round(pe, 6))}\ \text{{J}}"
        answer_text = f"{round(pe, 6)} J"
        check = verify_by_recomputation(
            pe, value_si(mass) * ctx.gravity() * value_si(height), "PE = mgh"
        )
    elif force and distance and times and target == "P":
        builder.add_given("F", force)
        builder.add_given("s", distance)
        builder.add_given("t", times[0])
        builder.require(["P"])
        given_section_step(builder, text)
        work = value_si(force) * value_si(distance)
        power_value = work / value_si(times[0]) if value_si(times[0]) else 0
        formula_step(
            builder,
            "Choose the law",
            r"P = \frac{W}{t} = \frac{Fs}{t}",
            "Power is how fast work is done.",
            "Power is the work done divided by the time taken.",
        )
        builder.step(
            "Substitute and calculate",
            "Work out the work, then divide by the time.",
            "Find the work first, then divide by the time.",
            [
                rf"P = \frac{{{fmt_number(round(work, 6))}}}"
                rf"{{{fmt_number(round(value_si(times[0]), 6))}}}"
                rf" = {fmt_number(round(power_value, 6))}\ \text{{W}}"
            ],
        )
        answer_latex = rf"P = {fmt_number(round(power_value, 6))}\ \text{{W}}"
        answer_text = f"{round(power_value, 6)} W"
        check = verify_by_recomputation(
            power_value, work / value_si(times[0]), "P = W/t"
        )
    elif target == "P" and times and ctx.by_dimension(ENERGY):
        energy = ctx.by_dimension(ENERGY)[0]
        work = value_si(energy)
        period = value_si(times[0])
        if period <= 0:
            return _invalid(text, "Time must be positive.")
        builder.add_given("W", energy)
        builder.add_given("t", times[0])
        builder.require(["P"])
        given_section_step(builder, text)
        power_value = work / period
        formula_step(
            builder,
            "Choose the law",
            r"P = \frac{W}{t}",
            "Power is the work done divided by the time it took.",
            "Divide the work by the time taken.",
        )
        builder.step(
            "Substitute and calculate",
            "Divide the energy by the time.",
            "Divide the work by the time.",
            [
                rf"P = \frac{{{fmt_number(round(work, 6))}}}"
                rf"{{{fmt_number(round(period, 6))}}}"
                rf" = {fmt_number(round(power_value, 6))}\ \text{{W}}"
            ],
        )
        answer_latex = rf"P = {fmt_number(round(power_value, 6))}\ \text{{W}}"
        answer_text = f"{round(power_value, 6)} W"
        check = verify_by_recomputation(power_value, work / period, "P = W/t")
    else:
        return None
    builder.step(
        "Answer",
        "The calculated quantity with its SI unit.",
        f"The answer is {answer_text}.",
        [answer_latex],
    )
    answer_interpretation_step(
        builder,
        (
            "Energy and work share the joule because work is simply the "
            "transfer of energy; power adds the clock, measuring how fast "
            "the transfer happens."
        ),
        "Work transfers energy, and power measures how fast that happens.",
    )
    return builder.build(answer_latex, answer_text, check)


# ---------------------------------------------------------------------------
# Momentum and collisions
# ---------------------------------------------------------------------------


def matches_momentum(text: str) -> bool:
    lowered = text.lower()
    return any(
        word in lowered
        for word in (
            "momentum",
            "collide",
            "collision",
            "impact",
            "explosion",
            "recoil",
            "before and after",
        )
    )


def solve_momentum(text: str) -> PhysicsSolution | None:
    ctx = PhysicsContext(text)
    masses = ctx.by_dimension(MASS)
    speeds = ctx.by_dimension(SPEED)
    if len(masses) < 1 or len(speeds) < 1:
        return None
    unknowns = find_unknowns(text)
    m1 = value_si(masses[0])
    u1 = value_si(speeds[0])
    m2 = value_si(masses[1]) if len(masses) > 1 else None
    u2 = value_si(speeds[1]) if len(speeds) > 1 else None
    if (
        m2 is not None
        and u2 is None
        and ctx.mentions("stationary", "at rest", "standstill")
    ):
        u2 = 0.0
    v1 = None
    v2 = None
    after_speeds = [q for q in speeds[1:]]
    elastic = ctx.mentions("elastic")
    builder = SolutionBuilder(
        text,
        "momentum_collisions",
        "Total momentum is conserved in every collision because no "
        "external resultant force acts; kinetic energy is conserved only "
        "in elastic collisions.",
    )
    builder.add_given("m", masses[0])
    builder.add_given("u", speeds[0])
    if m2 is not None:
        builder.add_given("M", masses[1])
    if len(speeds) > 1:
        builder.add_given("v", speeds[1])
    elif u2 is not None:
        builder.add_given("v", Quantity(0.0, "m/s"))
    given_section_step(builder, text)
    p_before = m1 * u1 + (m2 * u2 if m2 is not None and u2 is not None else 0.0)
    if (
        m2 is not None
        and u2 is not None
        and ("v" in unknowns or (after_speeds and "elastic" in text.lower()))
    ):
        if elastic:
            v1 = ((m1 - m2) * u1 + 2 * m2 * u2) / (m1 + m2)
            v2 = ((m2 - m1) * u2 + 2 * m1 * u1) / (m1 + m2)
            builder.require(["v"])
            formula_step(
                builder,
                "Two conservation laws",
                r"m_1u_1 + m_2u_2 = m_1v_1 + m_2v_2",
                (
                    "Momentum is conserved and, because the collision is "
                    "elastic, kinetic energy is conserved too."
                ),
                "In an elastic collision both momentum and kinetic energy "
                "are conserved.",
            )
            builder.step(
                "Solve together",
                "Solving the two conservation equations at once gives both "
                "final velocities.",
                "Solving both equations together gives the two final " "velocities.",
                [
                    rf"v_1 = {fmt_number(round(v1, 6))}\ \text{{m/s}}",
                    rf"v_2 = {fmt_number(round(v2, 6))}\ \text{{m/s}}",
                ],
            )
            answer_latex = (
                rf"v_1 = {fmt_number(round(v1, 6))}\ \text{{m/s}},\ "
                rf"v_2 = {fmt_number(round(v2, 6))}\ \text{{m/s}}"
            )
            answer_text = f"v1 = {round(v1, 6)} m/s, v2 = {round(v2, 6)} m/s"
            check = verify_by_recomputation(
                m1 * v1 + m2 * v2, p_before, "momentum conservation"
            )
        else:
            shared = p_before / (m1 + m2)
            builder.require(["v"])
            formula_step(
                builder,
                "Perfectly inelastic collision",
                r"m_1u_1 + m_2u_2 = (m_1 + m_2)v",
                ("The bodies stick together, so they share one final " "velocity."),
                "The bodies stick together and move with one common " "velocity.",
            )
            builder.step(
                "Substitute and divide",
                "Add the momenta, then divide by the total mass.",
                "Add the momenta, then divide by the total mass.",
                [
                    rf"v = \frac{{{fmt_number(round(p_before, 6))}}}"
                    rf"{{{fmt_number(round(m1 + m2, 6))}}}"
                    rf" = {fmt_number(round(shared, 6))}\ \text{{m/s}}"
                ],
            )
            answer_latex = rf"v = {fmt_number(round(shared, 6))}\ \text{{m/s}}"
            answer_text = f"{round(shared, 6)} m/s"
            check = verify_by_recomputation(
                shared * (m1 + m2), p_before, "momentum conservation"
            )
            builder.warn(
                "Kinetic energy is not conserved in this collision; some "
                "becomes heat and sound."
            )
    elif "p" in unknowns or len(speeds) == 1:
        momentum = m1 * u1
        builder.require(["p"])
        formula_step(
            builder,
            "Choose the law",
            r"p = mv",
            "Momentum is mass times velocity.",
            "Momentum is the mass times the velocity.",
        )
        builder.step(
            "Substitute and calculate",
            "Multiply the mass by the velocity.",
            "Multiply the mass by the velocity.",
            [
                rf"p = {fmt_number(m1)} \times {fmt_number(u1)}"
                rf" = {fmt_number(round(momentum, 6))}\ \text{{kg m/s}}"
            ],
        )
        answer_latex = rf"p = {fmt_number(round(momentum, 6))}\ \text{{kg m/s}}"
        answer_text = f"{round(momentum, 6)} kg m/s"
        check = verify_by_recomputation(momentum, m1 * u1, "p = mv")
    else:
        return None
    if m2 is not None and u2 is not None:
        builder.set_simulation(
            simulation_engine.collision_model(m1, u1, m2, u2, elastic)
        )
    builder.step(
        "Answer",
        "The momentum result with its unit.",
        f"The answer is {answer_text}.",
        [answer_latex],
    )
    answer_interpretation_step(
        builder,
        (
            "Momentum is conserved because during the collision the forces "
            "between the bodies are equal and opposite and act for the same "
            "time, so they change the momenta by equal and opposite amounts."
        ),
        "The forces between the bodies are equal and opposite, so the total "
        "momentum never changes.",
    )
    return builder.build(answer_latex, answer_text, check)


# ---------------------------------------------------------------------------
# Circular motion and gravitation
# ---------------------------------------------------------------------------


def matches_circular(text: str) -> bool:
    lowered = text.lower()
    return any(
        word in lowered
        for word in (
            "circular",
            "centripetal",
            "round a circle",
            "in a circle",
            "orbit",
            "rotates",
            "revolves",
            "whirl",
        )
    )


def solve_circular(text: str) -> PhysicsSolution | None:
    ctx = PhysicsContext(text)
    speeds = ctx.by_dimension(SPEED)
    radius = ctx.after_keyword("radius")
    if radius is None:
        lengths = ctx.by_dimension(LENGTH)
        radius = lengths[0] if lengths else None
    mass = _block_mass(ctx)
    times = ctx.by_dimension(TIME)
    if radius is None:
        return None
    r = value_si(radius)
    if r <= 0:
        return _invalid(text, "A circle needs a positive radius.")
    builder = SolutionBuilder(
        text,
        "circular_motion",
        "An object moving in a circle needs a resultant force towards the "
        r"centre; that centripetal force equals \frac{mv^{2}}{r}.",
    )
    builder.add_given("r", radius)
    if mass:
        builder.add_given("m", mass)
    if speeds:
        builder.add_given("v", speeds[0])
    given_section_step(builder, text)
    if speeds and mass:
        builder.require(["F"])
        speed = value_si(speeds[0])
        m = value_si(mass)
        force_value = m * speed**2 / r
        formula_step(
            builder,
            "Choose the law",
            r"F = \frac{mv^{2}}{r}",
            "The centripetal force keeps the body on its circular path.",
            "The centripetal force keeps the body going round the circle.",
        )
        builder.step(
            "Substitute and calculate",
            "Square the speed, multiply by the mass, divide by the radius.",
            "Square the speed, multiply by the mass, divide by the radius.",
            [
                rf"F = \frac{{{fmt_number(m)} \times "
                rf"{fmt_number(round(speed, 6))}^{{2}}}}"
                rf"{{{fmt_number(round(r, 6))}}}"
                rf" = {fmt_number(round(force_value, 6))}\ \text{{N}}"
            ],
        )
        answer_latex = rf"F = {fmt_number(round(force_value, 6))}\ \text{{N}}"
        answer_text = f"{round(force_value, 6)} N"
        check = verify_by_recomputation(force_value, m * speed**2 / r, "F = mv²/r")
    elif speeds and times:
        builder.require(["r"])
        speed = value_si(speeds[0])
        period = value_si(times[0])
        radius_value = speed * period / (2 * math.pi)
        formula_step(
            builder,
            "Choose the law",
            r"v = \frac{2\pi r}{T}",
            "One lap is the circumference travelled in one period.",
            "One lap is the circumference travelled in one period.",
        )
        builder.step(
            "Rearrange and calculate",
            "Multiply the speed by the period and divide by 2 pi.",
            "Multiply the speed by the period and divide by 2 pi.",
            [
                rf"r = \frac{{{fmt_number(round(speed, 6))} \times "
                rf"{fmt_number(round(period, 6))}}}{{2\pi}}"
                rf" = {fmt_number(round(radius_value, 6))}\ \text{{m}}"
            ],
        )
        answer_latex = rf"r = {fmt_number(round(radius_value, 6))}\ \text{{m}}"
        answer_text = f"{round(radius_value, 6)} m"
        check = verify_by_recomputation(
            radius_value, speed * period / (2 * math.pi), "v = 2πr/T"
        )
    elif speeds and mass is None:
        return clarification(
            text,
            "What is the mass of the object moving around the circle?",
        )
    else:
        return None
    builder.step(
        "Answer",
        "The circular-motion quantity with its unit.",
        f"The answer is {answer_text}.",
        [answer_latex],
    )
    answer_interpretation_step(
        builder,
        (
            "The centripetal force is not a new kind of force; it is the "
            "name for whatever real force (tension, gravity, friction) "
            "points at the centre and bends the path."
        ),
        "The centripetal force is just the real force that points at the "
        "centre of the circle.",
    )
    return builder.build(answer_latex, answer_text, check)


def matches_gravitation(text: str) -> bool:
    lowered = text.lower()
    return (
        any(
            word in lowered
            for word in (
                "gravitational force",
                "gravitation",
                "attracts",
                "attraction",
                "weight of",
            )
        )
        and "projectile" not in lowered
    )


def solve_gravitation(text: str) -> PhysicsSolution | None:
    ctx = PhysicsContext(text)
    mass = _block_mass(ctx)
    masses = ctx.by_dimension(MASS)
    lengths = ctx.by_dimension(LENGTH)
    if "weight" in text.lower() and mass:
        g = ctx.gravity()
        builder = SolutionBuilder(
            text,
            "weight",
            "Weight is the gravitational force the Earth pulls with: " r"W = mg.",
        )
        builder.add_given("m", mass)
        builder.require(["W"])
        given_section_step(builder, text)
        weight = value_si(mass) * g
        formula_step(
            builder,
            "Choose the law",
            r"W = mg",
            "Weight is mass times the gravitational field strength.",
            "Weight is the mass times the gravitational field strength.",
        )
        builder.step(
            "Substitute and calculate",
            "Multiply the mass by 9.81.",
            "Multiply the mass by 9.81.",
            [
                rf"W = {fmt_number(round(value_si(mass), 6))} \times 9.81"
                rf" = {fmt_number(round(weight, 6))}\ \text{{N}}"
            ],
        )
        answer_latex = rf"W = {fmt_number(round(weight, 6))}\ \text{{N}}"
        answer_text = f"{round(weight, 6)} N"
        check = verify_by_recomputation(weight, value_si(mass) * g, "W = mg")
        builder.set_visual(
            {
                "kind": "free_body",
                "incline_deg": 0.0,
                "note": "weight",
                "scale_hint": weight,
                "vectors": [
                    _vector("W", weight, 270.0, "weight"),
                    _vector("N", weight, 90.0, "normal"),
                ],
            }
        )
        builder.step(
            "Answer",
            "The weight with its unit.",
            f"The weight is {answer_text}.",
            [answer_latex],
        )
        answer_interpretation_step(
            builder,
            (
                "Weight is a force, so it changes with the local field "
                "strength, while the mass of the object never changes."
            ),
            "Weight changes from planet to planet; mass does not.",
        )
        return builder.build(answer_latex, answer_text, check)
    if len(masses) >= 2 and len(lengths) >= 1:
        m1 = value_si(masses[0])
        m2 = value_si(masses[1])
        r = value_si(lengths[0])
        if r <= 0:
            return _invalid(text, "Separation must be positive.")
        builder = SolutionBuilder(
            text,
            "gravitational_force",
            "Every mass attracts every other mass with a force given by "
            "Newton's law of gravitation.",
        )
        builder.add_given("m", masses[0])
        builder.add_given("M", masses[1])
        builder.add_given("r", lengths[0])
        builder.require(["F"])
        given_section_step(builder, text)
        force_value = GRAVITATIONAL_CONSTANT * m1 * m2 / r**2
        formula_step(
            builder,
            "Choose the law",
            r"F = G\frac{m_1 m_2}{r^{2}}",
            "The universal gravitational constant scales the product of "
            "the masses by the inverse square of the separation.",
            "Newton's law of gravitation uses the product of the masses "
            "over the square of the distance.",
        )
        builder.step(
            "Substitute and calculate",
            "Multiply the masses, divide by the square of the separation "
            "and scale by G.",
            "Substitute into Newton's law of gravitation.",
            [
                rf"F = 6.674 \times 10^{{-11}}"
                rf" \times \frac{{{fmt_number(m1)} \times {fmt_number(m2)}}}"
                rf"{{{fmt_number(round(r, 6))}^{{2}}}}"
                rf" = {force_value:.4g}\ \text{{N}}"
            ],
        )
        answer_latex = rf"F = {force_value:.4g}\ \text{{N}}"
        answer_text = f"{force_value:.4g} N"
        check = verify_by_recomputation(
            force_value,
            GRAVITATIONAL_CONSTANT * m1 * m2 / r**2,
            "F = G m1 m2 / r²",
        )
        builder.step(
            "Answer",
            "The gravitational attraction with its unit.",
            f"The force is {answer_text}.",
            [answer_latex],
        )
        answer_interpretation_step(
            builder,
            (
                "Gravitational force weakens with the square of the "
                "distance, so doubling the separation quarters the pull."
            ),
            "Move twice as far apart and the gravitational pull drops to a " "quarter.",
        )
        return builder.build(answer_latex, answer_text, check)
    return None


# ---------------------------------------------------------------------------
# Hooke's law and simple harmonic motion
# ---------------------------------------------------------------------------


def matches_spring(text: str) -> bool:
    lowered = text.lower()
    return (
        any(
            word in lowered
            for word in (
                "spring",
                "hooke",
                "extension",
                "stretched by",
                "compressed by",
            )
        )
        and "oscillat" not in lowered
        and "period" not in lowered
    )


def solve_spring(text: str) -> PhysicsSolution | None:
    ctx = PhysicsContext(text)
    k_match = re.search(
        r"(?:spring constant|stiffness|k)\s*(?:of|=|is)?\s*"
        r"(\d+(?:\.\d+)?)\s*(N/m|N/m)?",
        text,
        re.IGNORECASE,
    )
    extension = ctx.after_keyword("extension")
    if extension is None:
        lengths = ctx.by_dimension(LENGTH)
        extension = lengths[0] if lengths else None
    force = ctx.first(FORCE)
    k_value = float(k_match.group(1)) if k_match else None
    if extension is None:
        return None
    x = value_si(extension)
    builder = SolutionBuilder(
        text,
        "hookes_law",
        "Within its limit a spring's restoring force is proportional to "
        r"the extension: F = kx.",
    )
    builder.add_given("x", extension)
    if k_value is not None:
        builder.add_given_number("k", k_value, "N/m")
    if force:
        builder.add_given("F", force)
    given_section_step(builder, text)
    if k_value is not None:
        builder.require(["F"])
        force_value = k_value * x
        formula_step(
            builder,
            "Choose the law",
            r"F = kx",
            "The spring constant tells how many newtons each metre of "
            "extension needs.",
            "Hooke's law multiplies the spring constant by the extension.",
        )
        builder.step(
            "Substitute and calculate",
            "Multiply the spring constant by the extension.",
            "Multiply the spring constant by the extension.",
            [
                rf"F = {fmt_number(k_value)} \times "
                rf"{fmt_number(round(x, 6))}"
                rf" = {fmt_number(round(force_value, 6))}\ \text{{N}}"
            ],
        )
        answer_latex = rf"F = {fmt_number(round(force_value, 6))}\ \text{{N}}"
        answer_text = f"{round(force_value, 6)} N"
        check = verify_by_recomputation(force_value, k_value * x, "F = kx")
    elif force:
        if x == 0:
            return _invalid(text, "A zero extension cannot find a spring " "constant.")
        builder.require(["k"])
        k_found = value_si(force) / x
        formula_step(
            builder,
            "Rearrange Hooke's law",
            r"k = \frac{F}{x}",
            "Divide the force by the extension to get the spring constant.",
            "Divide the force by the extension to find the spring constant.",
        )
        builder.step(
            "Substitute and calculate",
            "Divide the force by the extension.",
            "Divide the force by the extension.",
            [
                rf"k = \frac{{{fmt_number(round(value_si(force), 6))}}}"
                rf"{{{fmt_number(round(x, 6))}}}"
                rf" = {fmt_number(round(k_found, 6))}\ \text{{N/m}}"
            ],
        )
        answer_latex = rf"k = {fmt_number(round(k_found, 6))}\ \text{{N/m}}"
        answer_text = f"{round(k_found, 6)} N/m"
        k_value = k_found
        check = verify_by_recomputation(k_found, value_si(force) / x, "k = F/x")
    else:
        return None
    builder.step(
        "Answer",
        "The Hooke's-law quantity with its unit.",
        f"The answer is {answer_text}.",
        [answer_latex],
    )
    builder.set_simulation(
        simulation_engine.spring_model(
            mass=1.0
            if not ctx.by_dimension(MASS)
            else value_si(ctx.by_dimension(MASS)[0]),
            spring_constant=k_value if k_value else 1.0,
            extension=abs(x),
        )
    )
    answer_interpretation_step(
        builder,
        (
            "A stiffer spring needs more force for the same stretch; the "
            "energy stored grows with the square of the extension."
        ),
        "Stiffer springs need more force, and the stored energy grows with "
        "the square of the stretch.",
    )
    return builder.build(answer_latex, answer_text, check)


def matches_shm(text: str) -> bool:
    lowered = text.lower()
    return any(
        word in lowered
        for word in (
            "pendulum",
            "simple harmonic",
            "oscillat",
            "vibrat",
            "period of",
            "time period",
        )
    )


def solve_shm(text: str) -> PhysicsSolution | None:
    ctx = PhysicsContext(text)
    g = ctx.gravity()
    if "pendulum" in text.lower():
        lengths = ctx.by_dimension(LENGTH)
        length = ctx.after_keyword("length")
        if length is None and lengths:
            length = lengths[0]
        if length is None:
            return None
        ell = value_si(length)
        if ell <= 0:
            return _invalid(text, "A pendulum needs a positive length.")
        period = 2 * math.pi * math.sqrt(ell / g)
        builder = SolutionBuilder(
            text,
            "pendulum_period",
            "A simple pendulum's period depends only on its length and the "
            r"field strength: T = 2\pi\sqrt{\frac{L}{g}}.",
        )
        builder.add_given("s", length)
        builder.require(["T"])
        given_section_step(builder, text)
        formula_step(
            builder,
            "Choose the law",
            r"T = 2\pi\sqrt{\frac{L}{g}}",
            "Longer pendulums swing more slowly; a stronger field speeds " "them up.",
            "The period of a pendulum depends on its length and on gravity.",
        )
        builder.step(
            "Substitute and calculate",
            "Put the length over the field strength, take the root, "
            "multiply by 2 pi.",
            "Substitute the length and gravity and calculate.",
            [
                rf"T = 2\pi\sqrt{{\frac{{{fmt_number(round(ell, 6))}}}"
                rf"{{9.81}}}}"
                rf" = {fmt_number(round(period, 6))}\ \text{{s}}"
            ],
        )
        answer_latex = rf"T = {fmt_number(round(period, 6))}\ \text{{s}}"
        answer_text = f"{round(period, 6)} s"
        check = verify_by_recomputation(
            period, 2 * math.pi * math.sqrt(ell / g), "T = 2π√(L/g)"
        )
        builder.set_simulation(simulation_engine.pendulum_model(ell, g))
        samples = 60
        times_line = [period * 2 * i / samples for i in range(samples + 1)]
        angles = [
            math.radians(10.0) * math.cos(2 * math.pi * t / period) for t in times_line
        ]
        builder.add_graph(
            graph_engine.time_series_graph(
                times_line,
                [round(math.degrees(a), 4) for a in angles],
                r"angle θ (degrees)",
                "Oscillation of the pendulum",
                r"θ = θ_0 cos(2πt/T)",
            )
        )
    else:
        masses = ctx.by_dimension(MASS)
        k_match = re.search(
            r"(?:spring constant|stiffness|k)\s*(?:of|=|is)?\s*" r"(\d+(?:\.\d+)?)",
            text,
            re.IGNORECASE,
        )
        if not masses or not k_match:
            return None
        m = value_si(masses[0])
        k = float(k_match.group(1))
        if m <= 0 or k <= 0:
            return _invalid(text, "Mass and spring constant must be " "positive.")
        period = 2 * math.pi * math.sqrt(m / k)
        builder = SolutionBuilder(
            text,
            "shm_spring",
            "A mass on a spring oscillates with " r"T = 2\pi\sqrt{\frac{m}{k}}.",
        )
        builder.add_given("m", masses[0])
        builder.add_given_number("k", k, "N/m")
        builder.require(["T"])
        given_section_step(builder, text)
        formula_step(
            builder,
            "Choose the law",
            r"T = 2\pi\sqrt{\frac{m}{k}}",
            "Bigger masses oscillate more slowly; stiffer springs faster.",
            "The period of a spring mass depends on the mass and the "
            "spring constant.",
        )
        builder.step(
            "Substitute and calculate",
            "Divide the mass by the spring constant, take the root, "
            "multiply by 2 pi.",
            "Substitute and calculate the period.",
            [
                rf"T = 2\pi\sqrt{{\frac{{{fmt_number(round(m, 6))}}}"
                rf"{{{fmt_number(k)}}}}}"
                rf" = {fmt_number(round(period, 6))}\ \text{{s}}"
            ],
        )
        answer_latex = rf"T = {fmt_number(round(period, 6))}\ \text{{s}}"
        answer_text = f"{round(period, 6)} s"
        check = verify_by_recomputation(
            period, 2 * math.pi * math.sqrt(m / k), "T = 2π√(m/k)"
        )
        builder.set_simulation(simulation_engine.spring_model(m, k))
    builder.step(
        "Answer",
        "The period with its unit.",
        f"The period is {answer_text}.",
        [answer_latex],
    )
    answer_interpretation_step(
        builder,
        (
            "Simple harmonic motion is symmetric: the restoring force "
            "grows with the displacement, so the oscillation is a smooth "
            "sine curve and the period does not depend on the amplitude."
        ),
        "The restoring force grows with displacement, so the swing is a "
        "smooth sine wave.",
    )
    return builder.build(answer_latex, answer_text, check)
