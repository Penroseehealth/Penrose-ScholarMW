"""Wave, lens and refraction solvers for the physics tutor.

The module covers the three standard wave-optics laws of a school course:
``v = f\\lambda`` with ``T = 1/f`` for wave motion, the lens/mirror
equation ``1/f = 1/u + 1/v`` with magnification ``m = v/u``, and Snell's law
``n_1\\sin\\theta_1 = n_2\\sin\\theta_2`` for refraction.

Every solver follows the same contract as the mechanics solvers: a
``matches_*`` guard that reads the original question text, then a ``solve_*``
that returns a :class:`~app.physics.solution_types.PhysicsSolution`.
"""

from __future__ import annotations

import math
import re

from app.mathematics.verification import verify_by_recomputation
from app.physics.interpreter import PhysicsContext, find_unknowns
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
    ANGLE,
    FREQUENCY,
    LENGTH,
    SPEED,
    TIME,
    Quantity,
    fmt_number,
)

# ---------------------------------------------------------------------------
# Waves: v = f lambda and T = 1/f
# ---------------------------------------------------------------------------


def matches_waves(text: str) -> bool:
    lowered = text.lower()
    return any(
        word in lowered
        for word in ("wave", "wavelength", "frequency", "period", "hertz")
    )


def solve_waves(text: str) -> PhysicsSolution | None:
    ctx = PhysicsContext(text)
    speeds = ctx.by_dimension(SPEED)
    frequencies = ctx.by_dimension(FREQUENCY)
    lengths = ctx.by_dimension(LENGTH)
    times = ctx.by_dimension(TIME)
    speed = speeds[0] if speeds else None
    frequency = frequencies[0] if frequencies else None
    length = lengths[0] if lengths else None
    period = times[0] if times else None
    unknowns = find_unknowns(text)

    wants_period = "T" in unknowns
    wants_frequency = "f" in unknowns
    wants_wavelength = "lambda" in unknowns
    wants_speed = "v" in unknowns

    wants_T = period is not None and wants_period and frequency is not None
    wants_f = period is not None and wants_frequency and frequency is None
    if wants_T or wants_f:
        p = value_si(period)
        f = value_si(frequency) if frequency is not None else None
        if wants_T:
            if f == 0:
                return _invalid(text, "A frequency cannot be zero.")
            answer_value = 1.0 / f
            spoken = "seconds"
            check = verify_by_recomputation(answer_value, 1.0 / f, "T = 1/f")
            formula = r"T = \frac{1}{f}"
            explanation = "The period is the reciprocal of the frequency."
            narration = "Take the reciprocal of the frequency."
            builder = SolutionBuilder(text, "waves", "Waves: T = 1/f")
            builder.add_given("f", frequency)
            builder.require(["T"])
            given_section_step(builder, text)
            formula_step(builder, "Choose the law", formula, explanation, narration)
            substitution = [
                rf"T = \frac{{1}}{{{fmt_number(round(f, 6))}}}",
                rf"T = {fmt_number(round(answer_value, 6))}\ \text{{s}}",
            ]
        else:
            if p == 0:
                return _invalid(text, "A period cannot be zero.")
            answer_value = 1.0 / p
            spoken = "hertz"
            check = verify_by_recomputation(answer_value, 1.0 / p, "f = 1/T")
            formula = r"f = \frac{1}{T}"
            explanation = "The frequency is the reciprocal of the period."
            narration = "Take the reciprocal of the period."
            builder = SolutionBuilder(text, "waves", "Waves: f = 1/T")
            builder.add_given("T", period)
            builder.require(["f"])
            given_section_step(builder, text)
            formula_step(builder, "Choose the law", formula, explanation, narration)
            substitution = [
                rf"f = \frac{{1}}{{{fmt_number(round(p, 6))}}}",
                rf"f = {fmt_number(round(answer_value, 6))}\ \text{{Hz}}",
            ]
    else:
        # v = f lambda: need at least two of speed, frequency, wavelength.
        known = sum(item is not None for item in (speed, frequency, length))
        if known < 2:
            return None
        v = value_si(speed) if speed is not None else None
        f = value_si(frequency) if frequency is not None else None
        lam = value_si(length) if length is not None else None
        if (f is not None and f == 0) or (lam is not None and lam == 0):
            return _invalid(text, "Wavelength and frequency must be positive.")
        if wants_wavelength and v is not None and f is not None:
            answer_value = v / f
            spoken = "metres"
            check = verify_by_recomputation(answer_value, v / f, "lambda = v/f")
            formula = r"\lambda = \frac{v}{f}"
            explanation = "Wavelength is the wave speed divided by the frequency."
            narration = "Divide the speed by the frequency."
            builder = SolutionBuilder(text, "waves", "Waves: v = f lambda")
            builder.add_given("v", speed)
            builder.add_given("f", frequency)
            builder.require(["lambda"])
            given_section_step(builder, text)
            formula_step(builder, "Choose the law", formula, explanation, narration)
            substitution = [
                rf"\lambda = \frac{{{fmt_number(round(v, 6))}}}"
                rf"{{{fmt_number(round(f, 6))}}}",
                rf"\lambda = " rf"{fmt_number(round(answer_value, 6))}\ \text{{m}}",
            ]
        elif wants_speed and f is not None and lam is not None:
            answer_value = f * lam
            spoken = "metres per second"
            check = verify_by_recomputation(answer_value, f * lam, "v = f lambda")
            formula = r"v = f\lambda"
            explanation = "Wave speed is the frequency multiplied by the wavelength."
            narration = "Multiply frequency by wavelength."
            builder = SolutionBuilder(text, "waves", "Waves: v = f lambda")
            builder.add_given("f", frequency)
            builder.add_given("lambda", length)
            builder.require(["v"])
            given_section_step(builder, text)
            formula_step(builder, "Choose the law", formula, explanation, narration)
            substitution = [
                rf"v = {fmt_number(round(f, 6))} \times "
                rf"{fmt_number(round(lam, 6))}",
                rf"v = " rf"{fmt_number(round(answer_value, 6))}\ \text{{m/s}}",
            ]
        elif wants_frequency and v is not None and lam is not None:
            answer_value = v / lam
            spoken = "hertz"
            check = verify_by_recomputation(answer_value, v / lam, "f = v/lambda")
            formula = r"f = \frac{v}{\lambda}"
            explanation = "Frequency is the wave speed divided by the wavelength."
            narration = "Divide the speed by the wavelength."
            builder = SolutionBuilder(text, "waves", "Waves: f = v/lambda")
            builder.add_given("v", speed)
            builder.add_given("lambda", length)
            builder.require(["f"])
            given_section_step(builder, text)
            formula_step(builder, "Choose the law", formula, explanation, narration)
            substitution = [
                rf"f = \frac{{{fmt_number(round(v, 6))}}}"
                rf"{{{fmt_number(round(lam, 6))}}}",
                rf"f = {fmt_number(round(answer_value, 6))}\ \text{{Hz}}",
            ]
        else:
            return None

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
            "Frequency, wavelength and speed lock together: raise the "
            "frequency and the wavelength shrinks at a fixed speed, exactly "
            "as a smaller period means more cycles each second."
        ),
        "Frequency, wavelength and speed keep a wave's rhythm locked.",
    )
    return builder.build(
        answer_latex,
        f"{fmt_number(round(answer_value, 6))} {spoken}",
        check,
    )


# ---------------------------------------------------------------------------
# Lenses and mirrors: 1/f = 1/u + 1/v and m = v/u
# ---------------------------------------------------------------------------


def matches_optics(text: str) -> bool:
    lowered = text.lower()
    return any(
        word in lowered
        for word in (
            "lens",
            "mirror",
            "concave",
            "convex",
            "focal",
            "object distance",
            "image distance",
            "magnification",
        )
    )


def _optics_quantities(
    ctx: PhysicsContext,
) -> tuple[Quantity | None, Quantity | None, Quantity | None]:
    """Object, image and focal lengths, filling gaps from loose lengths."""
    u = ctx.after_keyword("object_distance")
    v = ctx.after_keyword("image_distance")
    f = ctx.after_keyword("focal")
    used = [quantity for quantity in (u, v, f) if quantity is not None]
    leftovers = [
        quantity for quantity in ctx.by_dimension(LENGTH) if quantity not in used
    ]
    values = {"u": u, "v": v, "f": f}
    for slot in ("u", "v", "f"):
        if values[slot] is None and leftovers:
            values[slot] = leftovers.pop(0)
    return values["u"], values["v"], values["f"]


def solve_optics(text: str) -> PhysicsSolution | None:
    ctx = PhysicsContext(text)
    lowered = text.lower()
    unknowns = find_unknowns(text)
    u_quantity, v_quantity, f_quantity = _optics_quantities(ctx)
    u = value_si(u_quantity) if u_quantity is not None else None
    v = value_si(v_quantity) if v_quantity is not None else None
    f = value_si(f_quantity) if f_quantity is not None else None

    wants_magnification = "magnification" in unknowns or "magnification" in (lowered)

    if wants_magnification and u is not None and v is not None:
        if u == 0:
            return _invalid(text, "The object distance cannot be zero.")
        answer_value = v / u
        spoken = "times"
        check = verify_by_recomputation(answer_value, v / u, "m = v/u")
        formula = r"m = \frac{v}{u}"
        explanation = (
            "Magnification is the image distance divided by the object " "distance."
        )
        narration = "Divide the image distance by the object distance."
        builder = SolutionBuilder(text, "optics", "Lenses and mirrors: m = v/u")
        builder.add_given("u_l", u_quantity)
        builder.add_given("v_l", v_quantity)
        builder.require(["magnification"])
        given_section_step(builder, text)
        formula_step(builder, "Choose the law", formula, explanation, narration)
        substitution = [
            rf"m = \frac{{{fmt_number(round(v, 6))}}}"
            rf"{{{fmt_number(round(u, 6))}}}",
            rf"m = {fmt_number(round(answer_value, 6))}",
        ]
    else:
        known = sum(item is not None for item in (u, v, f))
        if known < 2:
            return None
        if f is None:
            if u + v == 0:
                return _invalid(text, "The distances cannot sum to zero.")
            answer_value = u * v / (u + v)
            spoken = "metres"
            check = verify_by_recomputation(
                answer_value, u * v / (u + v), "1/f = 1/u + 1/v"
            )
            formula = r"\frac{1}{f} = \frac{1}{u} + \frac{1}{v}"
            explanation = (
                "The reciprocal of the focal length equals the sum of the "
                "reciprocals of object and image distances."
            )
            narration = "Use 1/f = 1/u + 1/v and invert the sum."
            builder = SolutionBuilder(
                text, "optics", "Lenses and mirrors: 1/f = 1/u + 1/v"
            )
            builder.add_given("u_l", u_quantity)
            builder.add_given("v_l", v_quantity)
            builder.require(["z"])
            given_section_step(builder, text)
            formula_step(builder, "Choose the law", formula, explanation, narration)
            substitution = [
                rf"\frac{{1}}{{f}} = "
                rf"\frac{{1}}{{{fmt_number(round(u, 6))}}}"
                rf" + \frac{{1}}{{{fmt_number(round(v, 6))}}}",
                rf"f = {fmt_number(round(answer_value, 6))}\ \text{{m}}",
            ]
        elif v is None:
            if f == u:
                return _invalid(
                    text,
                    "The image forms at infinity when the object sits at the "
                    "focal point.",
                )
            answer_value = u * f / (u - f)
            spoken = "metres"
            check = verify_by_recomputation(
                answer_value, u * f / (u - f), "1/v = 1/f - 1/u"
            )
            formula = r"\frac{1}{v} = \frac{1}{f} - \frac{1}{u}"
            explanation = (
                "Rearrange the lens equation: the reciprocal of the image "
                "distance is the reciprocal of the focal length minus that "
                "of the object distance."
            )
            narration = "Use 1/v = 1/f - 1/u and invert."
            builder = SolutionBuilder(
                text, "optics", "Lenses and mirrors: 1/f = 1/u + 1/v"
            )
            builder.add_given("u_l", u_quantity)
            builder.add_given("z", f_quantity)
            builder.require(["v_l"])
            given_section_step(builder, text)
            formula_step(builder, "Choose the law", formula, explanation, narration)
            substitution = [
                rf"\frac{{1}}{{v}} = "
                rf"\frac{{1}}{{{fmt_number(round(f, 6))}}}"
                rf" - \frac{{1}}{{{fmt_number(round(u, 6))}}}",
                rf"v = {fmt_number(round(answer_value, 6))}\ \text{{m}}",
            ]
        else:
            if f == v:
                return _invalid(
                    text,
                    "The reciprocal formula divides by zero when the object "
                    "sits at twice the focal length.",
                )
            answer_value = v * f / (v - f)
            spoken = "metres"
            check = verify_by_recomputation(
                answer_value, v * f / (v - f), "1/u = 1/f - 1/v"
            )
            formula = r"\frac{1}{u} = \frac{1}{f} - \frac{1}{v}"
            explanation = (
                "Rearrange the lens equation: the reciprocal of the object "
                "distance is the reciprocal of the focal length minus that "
                "of the image distance."
            )
            narration = "Use 1/u = 1/f - 1/v and invert."
            builder = SolutionBuilder(
                text, "optics", "Lenses and mirrors: 1/f = 1/u + 1/v"
            )
            builder.add_given("z", f_quantity)
            builder.add_given("v_l", v_quantity)
            builder.require(["u_l"])
            given_section_step(builder, text)
            formula_step(builder, "Choose the law", formula, explanation, narration)
            substitution = [
                rf"\frac{{1}}{{u}} = "
                rf"\frac{{1}}{{{fmt_number(round(f, 6))}}}"
                rf" - \frac{{1}}{{{fmt_number(round(v, 6))}}}",
                rf"u = {fmt_number(round(answer_value, 6))}\ \text{{m}}",
            ]

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
            "The lens equation ties how far an object sits from a lens to "
            "where its image lands: slide the object in towards the focal "
            "point and the image marches out towards infinity."
        ),
        "Object, image and focal distances pin down where light focuses.",
    )
    return builder.build(
        answer_latex,
        f"{fmt_number(round(answer_value, 6))} {spoken}",
        check,
    )


# ---------------------------------------------------------------------------
# Refraction: Snell's law
# ---------------------------------------------------------------------------


def matches_snell(text: str) -> bool:
    lowered = text.lower()
    return any(
        word in lowered
        for word in (
            "snell",
            "refract",
            "refractive index",
            "index of refraction",
            "angle of incidence",
            "angle of refraction",
        )
    )


def _refractive_indices(text: str) -> list[float]:
    lowered = text.lower()
    indices: list[float] = []
    pattern = re.compile(
        r"(?:n(?:1|2)?\s*=\s*|refractive\s+index\w*(?:\s+(?:of|is)\s+[a-z]+|"
        r"\s*=\s*)?|index of refraction\w*\s+of\s+[a-z]+\s*=?)\s*"
        r"(\d+(?:\.\d+)?)"
    )
    for match in pattern.finditer(lowered):
        indices.append(float(match.group(1)))
    if len(indices) >= 2:
        return indices
    bare = re.search(
        r"(\d+(?:\.\d+)?)\s*(?:\s+times)?\s*the\s+(?:refractive\s+)?index"
        r"|refractive\s+index\w*\s*(?:is|=|:)\s*(\d+(?:\.\d+)?)",
        lowered,
    )
    if bare:
        indices.append(float((bare.group(1) or bare.group(2))))
    return indices


def solve_snell(text: str) -> PhysicsSolution | None:
    ctx = PhysicsContext(text)
    angles = ctx.by_dimension(ANGLE)
    indices = _refractive_indices(text)
    if not angles or not indices:
        return None
    lowered = text.lower()
    unknowns = find_unknowns(text)
    wants_angle = "theta" in unknowns or "angle" in lowered
    wanted_index = "n" in unknowns or "index" in lowered
    if not (wants_angle or wanted_index):
        return None

    theta1 = value_si(angles[0]) if len(angles) >= 1 else None
    theta2 = value_si(angles[1]) if len(angles) >= 2 else None
    n1 = indices[0] if len(indices) >= 1 else None
    n2 = indices[1] if len(indices) >= 2 else None

    if wants_angle and len(angles) < 2 and theta1 is not None:
        if n1 is None or n2 is None or n2 == 0:
            return None
        ratio = n1 * math.sin(theta1) / n2
        if not -1.0 <= ratio <= 1.0:
            return _invalid(
                text,
                "Total internal reflection: Snell's law has no real-angle "
                "solution here.",
            )
        answer_value = math.degrees(math.asin(ratio))
        spoken = "degrees"
        check = verify_by_recomputation(
            answer_value,
            math.degrees(math.asin(ratio)),
            "Snell's law",
        )
        formula = r"n_1\sin\theta_1 = n_2\sin\theta_2"
        explanation = (
            "Snell's law: the refractive index times the sine of the angle "
            "with the normal is the same on both sides of the surface."
        )
        narration = "Rearrange the law for theta two."
        builder = SolutionBuilder(text, "refraction", "Snell's law")
        builder.add_given_number("n_1_index", n1, "")
        builder.add_given_number("n_2_index", n2, "")
        builder.add_given("theta", angles[0])
        builder.require(["theta"])
        given_section_step(builder, text)
        formula_step(builder, "Choose the law", formula, explanation, narration)
        substitution = [
            rf"\sin\theta_2 = "
            rf"\frac{{{fmt_number(round(n1, 4))} \times "
            rf"\sin({fmt_number(round(math.degrees(theta1), 2))}^{{\circ}})}}"
            rf"{{{fmt_number(round(n2, 4))}}}",
            rf"\theta_2 = {fmt_number(round(answer_value, 2))}^{{\circ}}",
        ]
    elif wanted_index and len(angles) >= 2 and len(indices) == 1:
        theta1 = value_si(angles[0])
        theta2 = value_si(angles[1])
        sin1 = math.sin(theta1)
        sin2 = math.sin(theta2)
        if sin2 == 0 or sin1 == 0:
            return _invalid(text, "A sine of zero makes the index undefined.")
        if n1 is None:
            answer_value = n2 * sin2 / sin1
            symbol = "n_1"
        else:
            answer_value = n1 * sin1 / sin2
            symbol = "n_2"
        spoken = ""
        check = verify_by_recomputation(
            answer_value,
            answer_value,
            "Snell's law",
        )
        formula = r"n_1\sin\theta_1 = n_2\sin\theta_2"
        explanation = (
            "Snell's law links the refractive index of each medium to the "
            "sine of the angle its ray makes with the normal."
        )
        narration = "Rearrange the law for the missing index."
        builder = SolutionBuilder(text, "refraction", "Snell's law")
        builder.add_given("theta", angles[0])
        builder.add_given("theta", angles[1])
        builder.add_given_number("known_index", n2 if n1 is None else n1, "")
        builder.require(["n"])
        given_section_step(builder, text)
        formula_step(builder, "Choose the law", formula, explanation, narration)
        substitution = [
            rf"{symbol} = "
            rf"\frac{{"
            rf"{fmt_number(round((n2 if n1 is None else n1), 4))} \times "
            rf"\sin({fmt_number(round(math.degrees(theta2 if n1 is None else theta1), 2))}"
            rf"^{{\circ}})}}"
            rf"{{\sin("
            rf"{fmt_number(round(math.degrees(theta1 if n1 is None else theta2), 2))}"
            rf"^{{\circ}})}}",
            rf"{symbol} = {fmt_number(round(answer_value, 6))}",
        ]
    else:
        return None

    builder.step(
        "Substitute and calculate",
        "Put the numbers into the rearranged equation.",
        "Substitute the values and evaluate.",
        substitution,
    )
    answer_latex = substitution[-1]
    narration_answer = (
        f"The answer is {fmt_number(round(answer_value, 6))}" f" {spoken}.".rstrip()
    )
    builder.step(
        "Answer",
        "The required quantity.",
        narration_answer.strip(),
        [answer_latex],
    )
    answer_interpretation_step(
        builder,
        (
            "Light bends towards the normal when it slows into a denser "
            "medium and away from it when it speeds up again, which is why "
            "a straw looks kinked in a glass of water."
        ),
        "Denser media bend light towards the normal.",
    )
    return builder.build(
        answer_latex,
        f"{fmt_number(round(answer_value, 6))} {spoken}".strip(),
        check,
    )


def solve_optics_dispatch(text: str) -> PhysicsSolution | None:
    """Entry point combining the optics and refraction solvers."""
    if matches_optics(text):
        return solve_optics(text)
    if matches_snell(text):
        return solve_snell(text)
    return clarification(text, "Which lens, mirror or refraction problem?")
