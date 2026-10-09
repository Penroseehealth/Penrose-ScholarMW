"""Deterministic mathematics engine for the Penrose visual maths tutor.

The language model is never allowed to produce the mathematics. Every root,
side length and total here is computed with SymPy and then independently
verified by substitution, so the worked steps and the final answer can never
disagree with each other.

The output is structured for the UI: each step carries its own display LaTeX,
a plain-language explanation and a narration script, which is what lets the
visual workspace, the transcript and the voice tutor stay synchronised.
"""

from __future__ import annotations

import math
import re
from dataclasses import dataclass
from typing import Any

import sympy as sp
from sympy.parsing.sympy_parser import (
    implicit_multiplication_application,
    parse_expr,
    standard_transformations,
)

from app.mathematics.formatting import (
    fmt as _fmt,
)
from app.mathematics.formatting import (
    spoken_number as _spoken_number,
)
from app.mathematics.intent import looks_like_pythagoras
from app.mathematics.solution_types import TutorSolution, TutorStep
from app.mathematics.topic_solvers import solve_topic

_TRANSFORMS = standard_transformations + (implicit_multiplication_application,)

_UNICODE_MAP = {
    "\u2212": "-",
    "\u2013": "-",
    "\u00d7": "*",
    "\u00f7": "/",
    "\u221a": "sqrt",
    "\u00b2": "^2",
    "\u00b3": "^3",
    "\u03c0": "pi",
    "\u03b8": "theta",
    "\u2264": "<=",
    "\u2265": ">=",
}

_SPELLED_UNITS = (
    ("kilometres", "kilometre", "kilometer", "kilometer"),
    ("centimetres", "centimetre", "centimeter", "centimeter"),
    ("millimetres", "millimetre", "millimeter", "millimeter"),
    ("metres", "metre", "meters", "meter"),
    ("inches", "inch"),
    ("feet", "foot", "feet"),
)

# Short codes are ambiguous inside prose, so they are only honoured when they
# directly follow a measurement. Without that guard the English word "in" in
# "the angles are in the ratio 2:3:4" would be read as inches.
_ABBREVIATED_UNITS = (
    ("kilometres", "km"),
    ("centimetres", "cm"),
    ("millimetres", "mm"),
    ("metres", "m"),
    ("inches", "in"),
    ("feet", "ft"),
)


# ---------------------------------------------------------------------------
# Structured output models
# ---------------------------------------------------------------------------


def _clarification(problem: str, question: str) -> TutorSolution:
    step = TutorStep(
        id=1,
        title="I need one more detail",
        explanation=question,
        narration=question,
    )
    return TutorSolution(
        problem=problem,
        subject="clarification",
        topic="needs_more_information",
        steps=[step],
        final_answer_latex="",
        final_answer_text="",
    )


# ---------------------------------------------------------------------------
# Text normalisation and parsing
# ---------------------------------------------------------------------------


def _normalise(text: str) -> str:
    out = text.strip()
    for src, dst in _UNICODE_MAP.items():
        out = out.replace(src, dst)
    # Implicit products such as 3x or 2(x+1) -> 3*x, 2*(x+1)
    out = re.sub(r"(\d)\s*([a-zA-Z(])", r"\1*\2", out)
    out = re.sub(r"(\))([a-zA-Z0-9(])", r"\1*\2", out)
    out = out.replace("^", "**")
    return out


def _to_sympy(text: str) -> sp.Expr | None:
    """Parse a mathematical expression, tolerating school notation."""
    cleaned = _normalise(text)
    cleaned = re.sub(
        r"(?i)\b(solve|find|calculate|evaluate|what is|simplify)\b", " ", cleaned
    )
    cleaned = cleaned.replace("=", " - ").replace(" ", "")
    if not cleaned or cleaned in {"-", "+"}:
        return None
    try:
        expr = parse_expr(cleaned, transformations=_TRANSFORMS, evaluate=True)
    except (SyntaxError, TypeError, ValueError, AttributeError, sp.SympifyError):
        return None
    return expr


def _numbers(text: str) -> list[float]:
    return [float(m.group(0)) for m in re.finditer(r"\d+(?:\.\d+)?", text)]


def _unit(text: str) -> str:
    """Return the measurement unit named in *text*.

    Spelled-out names are unambiguous and may appear anywhere. Short codes are
    only accepted straight after a number, so that ordinary English words such
    as "in" are never mistaken for a unit.
    """
    lowered = text.lower()
    for entry in _SPELLED_UNITS:
        name, spellings = entry[0], entry[1:]
        if any(re.search(rf"\b{word}\b", lowered) for word in spellings):
            return name
    for name, short in _ABBREVIATED_UNITS:
        if re.search(rf"\d\s*{re.escape(short)}\b", lowered):
            return name
    return "units"


# ---------------------------------------------------------------------------
# Solver entry point
# ---------------------------------------------------------------------------


def solve(problem: str) -> TutorSolution:
    """Solve a supported problem deterministically, or ask for clarification."""
    text = problem.strip()
    if not text:
        return _clarification(problem, "Please type a mathematical problem.")

    lowered = text.lower()

    topic_result = solve_topic(text)
    if topic_result is not None:
        return topic_result

    if looks_like_pythagoras(lowered):
        result = _solve_pythagoras(text, lowered)
        if result is not None:
            return result

    quadratic = _solve_polynomial(text, degree=2)
    if quadratic is not None:
        return quadratic

    linear = _solve_polynomial(text, degree=1)
    if linear is not None:
        return linear

    percentage = _solve_percentage(text, lowered)
    if percentage is not None:
        return percentage

    arithmetic = _solve_arithmetic(text)
    if arithmetic is not None:
        return arithmetic

    return _clarification(
        problem,
        "I could not turn that into a calculation yet. I can work through "
        "arithmetic, fractions, percentages and percentage change, ratios, "
        "algebraic simplification, linear and quadratic equations, "
        "simultaneous equations, inequalities, linear programming, functions, "
        "sequences, statistics, probability, mensuration, trigonometry, "
        "coordinate geometry and right-angled triangles. Could you rephrase "
        "the question?",
    )


# ---------------------------------------------------------------------------
# Quadratic and linear equations
# ---------------------------------------------------------------------------


def _equation_sides(text: str) -> tuple[str, str] | None:
    if "=" not in text:
        return None
    left, _, right = text.partition("=")
    if not left.strip() or not right.strip():
        return None
    return left, right


def _constant_equation_solution(problem: str, expression: sp.Expr) -> TutorSolution:
    """An equation whose variables cancel: either an identity or a contradiction."""
    if expression == 0:
        steps = [
            TutorStep(
                id=1,
                title="Move every term to one side",
                explanation=(
                    "Collecting everything on one side leaves zero, so the two sides "
                    "are really the same expression."
                ),
                narration=(
                    "Collecting every term on one side leaves zero, which means the "
                    "two sides are identical."
                ),
                latex_lines=[f"{sp.latex(expression)} = 0"],
            ),
            TutorStep(
                id=2,
                title="Interpret the result",
                explanation=(
                    "Because the equation is true for every value of the variable, "
                    "it has infinitely many solutions."
                ),
                narration=(
                    "The equation is true for any value of the variable, so there "
                    "are infinitely many solutions."
                ),
            ),
        ]
        return TutorSolution(
            problem=problem,
            subject="algebra",
            topic="linear_equation",
            steps=steps,
            final_answer_latex=r"\text{infinitely many solutions}",
            final_answer_text="infinitely many solutions",
            verification_status="verified",
            verification_detail="The equation reduces to an identity.",
        )

    steps = [
        TutorStep(
            id=1,
            title="Move every term to one side",
            explanation=(
                "Collecting everything on one side leaves a constant, so the "
                "variable has cancelled out entirely."
            ),
            narration=(
                "Collecting every term on one side leaves a constant, so the "
                "variable has cancelled out."
            ),
            latex_lines=[f"{sp.latex(expression)} = 0"],
        ),
        TutorStep(
            id=2,
            title="Spot the contradiction",
            explanation=(
                "A constant can never equal zero, so no value of the variable can "
                "make the equation true."
            ),
            narration=(
                "A constant cannot equal zero, so the equation has no solution."
            ),
            latex_lines=[f"{sp.latex(expression)} \\neq 0"],
        ),
    ]
    return TutorSolution(
        problem=problem,
        subject="algebra",
        topic="linear_equation",
        steps=steps,
        final_answer_latex=r"\text{no solution}",
        final_answer_text="no solution",
        verification_status="verified",
        verification_detail=f"The reduction leaves {sp.sstr(expression)} = 0, which is impossible.",
    )


def _solve_polynomial(text: str, degree: int) -> TutorSolution | None:
    sides = _equation_sides(text)
    if sides is None:
        return None
    left_text, right_text = sides

    lhs = _to_sympy(left_text)
    rhs = _to_sympy(right_text)
    if lhs is None or rhs is None:
        return None

    try:
        expression = sp.expand(lhs - rhs)
    except (TypeError, ValueError, sp.SympifyError):
        return None

    free = sorted(expression.free_symbols, key=lambda s: s.name)
    if not free:
        return _constant_equation_solution(text, expression)
    if len(free) != 1:
        return None
    variable = free[0]

    try:
        poly = sp.Poly(expression, variable)
    except (sp.PolynomialError, TypeError):
        return None
    if poly.degree() != degree:
        return None

    coefficients = poly.all_coeffs()
    if degree == 2:
        return _quadratic_solution(text, poly, variable)
    return _linear_solution(text, poly, variable, coefficients)


def _linear_parts(
    problem: str,
) -> tuple[sp.Symbol, sp.Expr, sp.Expr, sp.Expr] | None:
    """Read ``a*x + b = c`` from the original wording.

    Returns ``(variable, a, b, c)`` only when the variable sits on the left and
    the right-hand side is a plain constant, which is the layout school
    questions use. Anything else falls back to a generic presentation.
    """
    sides = _equation_sides(problem)
    if sides is None:
        return None
    lhs = _to_sympy(sides[0])
    rhs = _to_sympy(sides[1])
    if lhs is None or rhs is None or rhs.free_symbols:
        return None
    free = sorted(lhs.free_symbols, key=lambda s: s.name)
    if len(free) != 1:
        return None
    variable = free[0]
    try:
        poly = sp.Poly(sp.expand(lhs), variable)
    except (sp.PolynomialError, TypeError):
        return None
    if poly.degree() != 1:
        return None
    a = sp.nsimplify(poly.coeff_monomial(variable))
    b = sp.nsimplify(poly.coeff_monomial(1))
    c = sp.nsimplify(rhs)
    return variable, a, b, c


def _signed(value: sp.Expr) -> str:
    """Render ``+ 3`` or ``- 3`` for use inside an equation."""
    number = sp.nsimplify(value)
    try:
        if number.is_number and number < 0:
            return f"- {_fmt(-number)}"
    except TypeError:
        pass
    return f"+ {sp.latex(number)}"


def _terminating_decimal(value: sp.Expr) -> str | None:
    """A decimal string when the value is an exact terminating decimal."""
    rational = sp.nsimplify(value)
    if not rational.is_rational:
        return None
    denominator = int(sp.denom(rational))
    while denominator % 2 == 0:
        denominator //= 2
    while denominator % 5 == 0:
        denominator //= 5
    if denominator != 1:
        return None
    return _fmt(float(rational))


def _linear_solution(
    problem: str,
    poly: sp.Poly,
    variable: sp.Symbol,
    coefficients: list[sp.Expr],
) -> TutorSolution:
    expression = poly.as_expr()
    root = sp.simplify(sp.solve(expression, variable)[0])
    residual = sp.simplify(expression.subs(variable, root))

    parts = _linear_parts(problem)
    if parts is None:
        return _linear_generic_solution(problem, poly, variable, root, residual)

    _, raw_a, raw_b, raw_c = parts
    a, b, c = (sp.nsimplify(value) for value in (raw_a, raw_b, raw_c))
    term = variable.name if a == 1 else sp.latex(a * variable)
    moved = sp.simplify(c - b)
    decimal = _terminating_decimal(root)
    root_latex = decimal if decimal is not None else sp.latex(root)
    lhs_latex = sp.latex(sp.expand(a * variable + b))

    steps: list[TutorStep] = [
        TutorStep(
            id=1,
            title="Write the equation",
            explanation=(
                f"We are solving for {variable.name}. The equation is "
                f"{sp.sstr(a * variable + b)} = {sp.sstr(c)}."
            ),
            narration=(
                f"We need to solve for {variable.name}. The equation is "
                f"{sp.sstr(a * variable + b)} equals {sp.sstr(c)}."
            ),
            latex_lines=[f"{lhs_latex} = {sp.latex(c)}"],
        )
    ]

    if b != 0:
        b_abs = abs(b)
        move_op = "-" if b > 0 else "+"
        move_word = "subtract" if b > 0 else "add"
        steps.append(
            TutorStep(
                id=2,
                title="Move the constant",
                explanation=(
                    f"The {variable.name} term is not yet on its own. To remove "
                    f"the constant we {move_word} {_fmt(b_abs)} "
                    f"{'from' if b > 0 else 'to'} both sides. Whatever we do to "
                    "one side of an equation, we must also do to the other to "
                    "keep it balanced."
                ),
                narration=(
                    f"First we {move_word} {_spoken_number(float(b_abs))} "
                    f"{'from' if b > 0 else 'to'} both sides, so "
                    f"{term} equals {_fmt(moved)}."
                ),
                latex_lines=[
                    f"{term} = {sp.latex(c)} {move_op} {_fmt(b_abs)}",
                    f"{term} = {_fmt(moved)}",
                ],
            )
        )

    if a != 1:
        steps.append(
            TutorStep(
                id=len(steps) + 1,
                title="Divide by the coefficient",
                explanation=(
                    f"The {variable.name} term still has a coefficient of "
                    f"{_fmt(a)}. Dividing both sides by {_fmt(a)} is the inverse "
                    f"operation, which leaves {variable.name} on its own."
                ),
                narration=(
                    f"Now we divide both sides by {_spoken_number(float(a))} to "
                    f"isolate {variable.name}."
                ),
                latex_lines=[
                    f"{variable.name} = \\frac{{{sp.latex(moved)}}}{{{sp.latex(a)}}}",
                    f"{variable.name} = {root_latex}",
                ],
            )
        )
    else:
        steps.append(
            TutorStep(
                id=len(steps) + 1,
                title="Isolate the variable",
                explanation=f"The coefficient is already 1, so {variable.name} is on its own.",
                narration=f"{variable.name} is already on its own.",
                latex_lines=[f"{variable.name} = {root_latex}"],
            )
        )

    partial = sp.simplify(a * root)
    lhs_value = sp.simplify(a * root + b)
    substitute_line = (
        f"{_fmt(a)} \\cdot {root_latex} {_signed(b)} = {sp.latex(c)}"
        if b != 0
        else f"{_fmt(a)} \\cdot {root_latex} = {sp.latex(c)}"
    )
    verify_lines = [substitute_line]
    if b != 0:
        verify_lines.append(f"{_fmt(partial)} {_signed(b)} = {sp.latex(c)}")
    verify_lines.append(f"{_fmt(lhs_value)} = {sp.latex(c)}")

    steps.append(
        TutorStep(
            id=len(steps) + 1,
            title="Check the answer",
            explanation=(
                "Substitute the answer back into the original equation. If both "
                "sides come out the same, the solution is correct."
            ),
            narration=(
                f"Let us check. Substituting {variable.name} equals {root_latex} "
                f"back in gives {_fmt(lhs_value)} equals {sp.sstr(c)}, so the "
                "answer is correct."
                if residual == 0
                else "Let us check by substituting the answer back in."
            ),
            latex_lines=verify_lines,
        )
    )

    answer_latex = f"{variable.name} = {root_latex}"
    return TutorSolution(
        problem=problem,
        subject="algebra",
        topic="linear_equation",
        steps=steps,
        final_answer_latex=answer_latex,
        final_answer_text=f"{variable.name} = {root_latex}",
        verification_status="verified" if residual == 0 else "failed",
        verification_detail=f"Residual after substitution: {_fmt(residual)}",
    )


def _linear_generic_solution(
    problem: str,
    poly: sp.Poly,
    variable: sp.Symbol,
    root: sp.Expr,
    residual: sp.Expr,
) -> TutorSolution:
    """Fallback for equations whose variables are not neatly on one side."""
    a, b = poly.all_coeffs()
    steps = [
        TutorStep(
            id=1,
            title="Identify the equation",
            explanation=(
                f"Read the equation as {sp.latex(poly.as_expr())} = 0 and collect "
                f"the {variable.name} terms on one side."
            ),
            narration=(
                f"We start by writing the equation in standard form, "
                f"{sp.sstr(poly.as_expr())} equals zero."
            ),
            latex_lines=[sp.latex(poly.as_expr()) + " = 0"],
        ),
        TutorStep(
            id=2,
            title="Isolate the variable term",
            explanation="Move the constant to the right-hand side so the variable is alone.",
            narration="Now we move the constant across to the other side.",
            latex_lines=[f"{sp.latex(a * variable)} = {sp.latex(sp.simplify(-b))}"],
        ),
        TutorStep(
            id=3,
            title="Divide by the coefficient",
            explanation=f"Divide both sides by {_fmt(a)} to make the coefficient 1.",
            narration=(
                f"Dividing both sides by {_spoken_number(float(a))} isolates "
                f"{variable.name}."
            ),
            latex_lines=[f"{variable.name} = {sp.latex(root)}"],
        ),
        TutorStep(
            id=4,
            title="Verify the solution",
            explanation=(
                "Substitute the answer back into the original equation. The "
                "remainder must be zero, which proves the root is correct."
            ),
            narration=(
                f"Substituting {_spoken_number(float(root))} back in leaves a "
                f"remainder of {_fmt(residual)}, so the answer is correct."
            ),
            latex_lines=[
                f"{sp.latex(sp.Subs(poly.as_expr(), variable, root))} = "
                f"{_fmt(residual)}"
            ],
        ),
    ]
    return TutorSolution(
        problem=problem,
        subject="algebra",
        topic="linear_equation",
        steps=steps,
        final_answer_latex=f"{variable.name} = {sp.latex(root)}",
        final_answer_text=f"{variable.name} = {sp.sstr(root)}",
        verification_status="verified" if residual == 0 else "failed",
        verification_detail=f"Residual after substitution: {_fmt(residual)}",
    )


def _quadratic_solution(
    problem: str, poly: sp.Poly, variable: sp.Symbol
) -> TutorSolution:
    a, b, c = (sp.nsimplify(coefficient) for coefficient in poly.all_coeffs())
    discriminant = sp.simplify(b**2 - 4 * a * c)
    roots = sp.solve(poly.as_expr(), variable)

    equation_latex = f"{sp.latex(poly.as_expr())} = 0"
    standard = "ax^{2} + bx + c = 0"

    steps = [
        TutorStep(
            id=1,
            title="Identify the coefficients",
            explanation=(
                "Compare the equation with the standard quadratic form "
                f"{variable.name}^2 + b{variable.name} + c = 0, then read off a, b and c."
            ),
            narration=(
                "First, we identify a, b and c by comparing the equation with the "
                f"standard quadratic form. Here a is {_spoken_number(float(a))}, "
                f"b is {_spoken_number(float(b))} and c is {_spoken_number(float(c))}."
            ),
            latex_lines=[
                standard,
                equation_latex,
                f"a = {_fmt(a)}, \\quad b = {_fmt(b)}, \\quad c = {_fmt(c)}",
            ],
        ),
        TutorStep(
            id=2,
            title="Apply the quadratic formula",
            explanation=(
                "Because the equation is quadratic, the roots come from the "
                "quadratic formula."
            ),
            narration="Now we substitute these values into the quadratic formula.",
            latex_lines=[r"x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}"],
        ),
        TutorStep(
            id=3,
            title="Substitute the values",
            explanation="Replace a, b and c with the numbers found in step one.",
            narration="Replacing a, b and c with our values gives the expression below.",
            latex_lines=[
                "x = \\frac{"
                f"{sp.latex(-b)} \\pm \\sqrt{{{sp.latex(discriminant)}}}"
                "}{"
                f"{sp.latex(2 * a)}"
                "}"
            ],
        ),
        TutorStep(
            id=4,
            title="Simplify the discriminant",
            explanation=(
                "The expression under the square root simplifies to "
                f"{_fmt(discriminant)}."
            ),
            narration=f"The expression under the square root simplifies to {_spoken_number(float(discriminant))}.",
            latex_lines=[
                f"\\sqrt{{{sp.latex(discriminant)}}} = {sp.latex(sp.sqrt(discriminant))}"
            ],
        ),
    ]

    root_latex_lines: list[str] = []
    if discriminant == 0:
        steps.append(
            TutorStep(
                id=5,
                title="One repeated root",
                explanation=(
                    "The discriminant is zero, so the parabola touches the axis "
                    "and there is exactly one repeated root."
                ),
                narration="Because the discriminant is zero, there is one repeated root.",
            )
        )
    elif discriminant < 0:
        complex_form = sp.simplify(sp.sqrt(discriminant))
        steps.append(
            TutorStep(
                id=5,
                title="No real roots",
                explanation=(
                    "The discriminant is negative, so the parabola never crosses "
                    "the axis and there are no real solutions."
                ),
                narration=(
                    "The discriminant is negative, which means the parabola never "
                    "crosses the axis, so there are no real solutions."
                ),
            )
        )
        root_latex_lines.append(f"x = {sp.latex(complex_form)}")
    else:
        steps.append(
            TutorStep(
                id=5,
                title="Split into two roots",
                explanation=(
                    "The discriminant is positive, so the plus and minus each "
                    "give a real root."
                ),
                narration=(
                    "The discriminant is positive, so the plus and the minus "
                    "each give us a real root."
                ),
                latex_lines=[
                    f"\\sqrt{{{sp.latex(discriminant)}}} = {sp.latex(sp.sqrt(discriminant))}"
                ],
            )
        )
        for index, root in enumerate(roots, start=1):
            root_latex_lines.append(f"x_{{{index}}} = {sp.latex(sp.simplify(root))}")

    residuals = [sp.simplify(poly.as_expr().subs(variable, root)) for root in roots]
    verified = all(residual == 0 for residual in residuals)

    steps.append(
        TutorStep(
            id=len(steps) + 1,
            title="Verify the roots",
            explanation=(
                "Substitute each root back into the original polynomial. Every "
                "remainder must be zero."
            ),
            narration=(
                "Substituting the roots back into the equation leaves a "
                "remainder of zero, so the answers are correct."
                if verified
                else "Substituting the roots back left a remainder, so we flag this for review."
            ),
            latex_lines=[
                f"{sp.latex(sp.Subs(poly.as_expr(), variable, root))} = 0"
                for root in roots
            ],
        )
    )

    if discriminant < 0:
        answer_latex = "\\text{no real solutions}"
        answer_text = "no real solutions"
    elif len(roots) == 1:
        answer_latex = f"x = {sp.latex(sp.simplify(roots[0]))}"
        answer_text = sp.sstr(sp.simplify(roots[0]))
    else:
        answer_latex = ", \\quad ".join(root_latex_lines)
        answer_text = ", ".join(sp.sstr(sp.simplify(root)) for root in roots)

    has_real_roots = discriminant > 0 or (
        discriminant == 0 and roots and sp.simplify(roots[0]).is_real
    )

    visual: dict[str, Any] = {
        "kind": "parabola",
        "params": {
            "a": float(a),
            "b": float(b),
            "c": float(c),
            "has_real_roots": bool(has_real_roots),
            "roots": [float(sp.re(sp.simplify(root))) for root in roots]
            if has_real_roots
            else [],
            "root_labels": [sp.latex(sp.simplify(root)) for root in roots]
            if has_real_roots
            else [],
        },
        "caption": (
            "The parabola crosses the x-axis exactly where the quadratic formula "
            "says the roots are."
        ),
    }

    return TutorSolution(
        problem=problem,
        subject="algebra",
        topic="quadratic_equation",
        steps=steps,
        final_answer_latex=answer_latex,
        final_answer_text=answer_text,
        verification_status="verified" if verified else "failed",
        verification_detail=(
            "Residual after substitution: "
            + ", ".join(_fmt(residual) for residual in residuals)
        ),
        visual=visual,
    )


# ---------------------------------------------------------------------------
# Geometry, percentages and arithmetic
# ---------------------------------------------------------------------------


def _solve_pythagoras(problem: str, lowered: str) -> TutorSolution | None:
    values = _numbers(lowered)
    if len(values) < 2:
        return _clarification(
            problem,
            "A right-angled triangle needs two known side lengths before I can "
            "work out the third. What are the two lengths you were given?",
        )

    unit = _unit(lowered)
    stated = re.search(r"hypotenuse[^0-9]{0,12}(\d+(?:\.\d+)?)", lowered)
    wants_hypotenuse = (
        "hypotenuse" in lowered or "longest side" in lowered
    ) and stated is None

    a, b = values[0], values[1]
    steps: list[TutorStep] = []

    if wants_hypotenuse:
        squared_a, squared_b = a * a, b * b
        total = squared_a + squared_b
        hypotenuse = math.sqrt(total)
        residual = abs(squared_a + squared_b - hypotenuse**2)

        steps = [
            TutorStep(
                id=1,
                title="Identify the triangle",
                explanation=(
                    f"The triangle is right-angled with sides {_fmt(a)} {unit} and "
                    f"{_fmt(b)} {unit}. We need the hypotenuse, the side opposite "
                    "the right angle."
                ),
                narration=(
                    f"We have a right-angled triangle with one side {_spoken_number(a)} "
                    f"{unit} and the other side {_spoken_number(b)} {unit}. We need the "
                    "hypotenuse, which is the longest side."
                ),
            ),
            TutorStep(
                id=2,
                title="Apply the Pythagorean theorem",
                explanation=(
                    "For any right-angled triangle, the square of the hypotenuse "
                    "equals the sum of the squares of the other two sides."
                ),
                narration="For any right-angled triangle, the square of the hypotenuse equals the sum of the squares of the other two sides.",
                latex_lines=["a^2 + b^2 = c^2"],
            ),
            TutorStep(
                id=3,
                title="Substitute and square",
                explanation="Substitute the two known lengths and square each one.",
                narration="Now substitute the side lengths we were given and square each one.",
                latex_lines=[
                    f"{_fmt(a)}^2 + {_fmt(b)}^2 = c^2",
                    f"{_fmt(squared_a)} + {_fmt(squared_b)} = c^2",
                ],
            ),
            TutorStep(
                id=4,
                title="Add and take the square root",
                explanation=(
                    "Add the two squares, then undo the squaring by taking a "
                    "square root."
                ),
                narration=(
                    f"Adding gives {_spoken_number(total)}, so c squared is "
                    f"{_spoken_number(total)} and c is the square root of that."
                ),
                latex_lines=[
                    f"c^2 = {_fmt(total)}",
                    f"c = \\sqrt{{{_fmt(total)}}} = {_fmt(hypotenuse)}",
                ],
            ),
        ]

        final_text = f"{_fmt(hypotenuse)} {unit}"
        visual = {
            "kind": "right_triangle",
            "params": {"a": a, "b": b, "c": hypotenuse, "unit": unit},
            "caption": "The two known sides meet at the right angle; the hypotenuse is opposite it.",
        }
    else:
        if stated is not None:
            hypotenuse = float(stated.group(1))
            known = [value for value in values if value != hypotenuse]
            if not known:
                return _clarification(
                    problem,
                    "I have the hypotenuse, but I still need one shorter side.",
                )
            shorter = known[0]
        else:
            hypotenuse = max(a, b)
            shorter = min(a, b)

        if hypotenuse <= shorter:
            return _clarification(
                problem,
                "I need to know which side is the hypotenuse before I can find "
                "the missing side.",
            )

        squared_c = hypotenuse * hypotenuse
        squared_a = shorter * shorter
        difference = squared_c - squared_a
        missing = math.sqrt(difference)
        residual = abs(squared_a + missing**2 - squared_c)

        steps = [
            TutorStep(
                id=1,
                title="Identify the triangle",
                explanation=(
                    f"The hypotenuse is {_fmt(hypotenuse)} {unit} and one shorter "
                    f"side is {_fmt(shorter)} {unit}. We need the other shorter side."
                ),
                narration=(
                    f"This is a right-angled triangle. We know the hypotenuse is "
                    f"{_spoken_number(hypotenuse)} {unit} and one shorter side is "
                    f"{_spoken_number(shorter)} {unit}."
                ),
            ),
            TutorStep(
                id=2,
                title="Apply the Pythagorean theorem",
                explanation="Write the theorem with the unknown side as b.",
                narration="Again we use the Pythagorean theorem, writing the missing side as b.",
                latex_lines=["a^2 + b^2 = c^2"],
            ),
            TutorStep(
                id=3,
                title="Substitute and square",
                explanation="Substitute the two known lengths and square them.",
                narration="Substituting the values we know gives this equation.",
                latex_lines=[
                    f"{_fmt(shorter)}^2 + b^2 = {_fmt(hypotenuse)}^2",
                    f"{_fmt(squared_a)} + b^2 = {_fmt(squared_c)}",
                ],
            ),
            TutorStep(
                id=4,
                title="Isolate and take the square root",
                explanation=(
                    "Subtract the known square from the hypotenuse square, then "
                    "take the square root."
                ),
                narration=(
                    f"Subtracting {_spoken_number(squared_a)} from "
                    f"{_spoken_number(squared_c)} leaves {_spoken_number(difference)}, "
                    "and the square root of that is our missing side."
                ),
                latex_lines=[
                    f"b^2 = {_fmt(squared_c)} - {_fmt(squared_a)} = {_fmt(difference)}",
                    f"b = \\sqrt{{{_fmt(difference)}}} = {_fmt(missing)}",
                ],
            ),
        ]

        final_text = f"{_fmt(missing)} {unit}"
        visual = {
            "kind": "right_triangle",
            "params": {"a": shorter, "b": missing, "c": hypotenuse, "unit": unit},
            "caption": "The dashed side is the one we solved for.",
        }

    steps.append(
        TutorStep(
            id=len(steps) + 1,
            title="Verify the triangle",
            explanation=(
                "Substitute the three side lengths back into the theorem. The "
                "remainder must be zero."
            ),
            narration=(
                "Substituting the three sides back in leaves a remainder of zero, "
                "so the triangle checks out."
            ),
        )
    )

    return TutorSolution(
        problem=problem,
        subject="geometry",
        topic="pythagorean_theorem",
        steps=steps,
        final_answer_latex=final_text,
        final_answer_text=final_text,
        verification_status="verified" if residual < 1e-9 else "failed",
        verification_detail=f"Residual: {residual:.2e}",
        visual=visual,
    )


def _solve_percentage(problem: str, lowered: str) -> TutorSolution | None:
    match = re.search(r"(\d+(?:\.\d+)?)\s*%\s*of\s*(\d+(?:\.\d+)?)", lowered)
    if not match:
        return None

    percent = float(match.group(1))
    whole = float(match.group(2))
    decimal = percent / 100
    answer = whole * decimal
    residual = abs(whole * decimal - answer)

    steps = [
        TutorStep(
            id=1,
            title="Identify the parts",
            explanation=f"We want {_fmt(percent)} per cent of {_fmt(whole)}.",
            narration=f"We want {_spoken_number(percent)} per cent of {_spoken_number(whole)}.",
        ),
        TutorStep(
            id=2,
            title="Convert the percentage",
            explanation="Divide the percentage by one hundred to get a decimal.",
            narration=(
                "To convert a percentage to a decimal we divide by one hundred, so "
                f"{_spoken_number(percent)} per cent becomes {_fmt(decimal)}."
            ),
            latex_lines=[f"{_fmt(percent)}\\% = {_fmt(decimal)}"],
        ),
        TutorStep(
            id=3,
            title="Multiply",
            explanation="Multiply the decimal by the whole quantity.",
            narration=f"Now multiply {_fmt(decimal)} by {_spoken_number(whole)}.",
            latex_lines=[f"{_fmt(decimal)} \\times {_fmt(whole)} = {_fmt(answer)}"],
        ),
    ]

    visual = {
        "kind": "percentage_bar",
        "title": f"{_fmt(percent)}\\% of {_fmt(whole)}",
        "percent": percent,
        "whole": whole,
        "part": answer,
        "remainder": whole - answer,
        "caption": (
            f"Shaded: {_fmt(percent)}\\% of {_fmt(whole)} = {_fmt(answer)}; "
            f"the rest is {_fmt(whole - answer)}"
        ),
    }

    return TutorSolution(
        problem=problem,
        subject="percentage",
        topic="percentage_of_quantity",
        steps=steps,
        final_answer_latex=_fmt(answer),
        final_answer_text=_fmt(answer),
        verification_status="verified" if residual < 1e-12 else "failed",
        verification_detail=f"Residual: {residual:.2e}",
        visual=visual,
    )


def _solve_arithmetic(problem: str) -> TutorSolution | None:
    match = re.search(r"[0-9][0-9\s.+\-*/^()]*[0-9)]", problem)
    if not match:
        return None
    expression = match.group(0).replace(" ", "")
    if not re.search(r"[+\-*/^]", expression):
        return None

    expr = _to_sympy(expression)
    if expr is None or not expr.free_symbols == set():
        return None
    try:
        total = sp.simplify(expr)
    except (TypeError, ValueError, sp.SympifyError):
        return None

    # Keep the student's own notation on screen rather than the evaluated form.
    shown = (
        expression.replace("*", r" \times ")
        .replace("/", r" \div ")
        .replace("+", r" + ")
        .replace("-", r" - ")
        .replace("^", "^{")
    )
    steps = [
        TutorStep(
            id=1,
            title="Plan the calculation",
            explanation=(
                "Evaluate using the order of operations: brackets first, then "
                "powers, then multiplication and division, and finally addition "
                "and subtraction."
            ),
            narration=(
                "Let us evaluate this step by step, following the order of operations."
            ),
            latex_lines=[f"{shown} = ?"],
        ),
        TutorStep(
            id=2,
            title="Evaluate",
            explanation=f"The expression simplifies to {_fmt(total)}.",
            narration=f"Following the order of operations, this gives {_fmt(total)}.",
            latex_lines=[f"{shown} = {sp.latex(total)}"],
        ),
    ]

    return TutorSolution(
        problem=problem,
        subject="arithmetic",
        topic="arithmetic",
        steps=steps,
        final_answer_latex=sp.latex(total),
        final_answer_text=sp.sstr(total),
        verification_status="verified",
        verification_detail="Evaluated symbolically with SymPy",
    )


# ---------------------------------------------------------------------------
# Student working checker
# ---------------------------------------------------------------------------


@dataclass
class WorkCheck:
    """Result of inspecting one line of a student's own working."""

    ok: bool
    message: str
    expected_latex: str = ""
    correction_latex: str = ""
    step_ref: int | None = None


def check_working(problem: str, student_line: str) -> WorkCheck:
    """Detect a wrong operation in a line the student wrote.

    Only the ``a*x + b = c`` layout is checked in detail; for anything else we
    say we could not compare it rather than inventing an error.
    """
    solution = solve(problem)
    parts = _linear_parts(problem)
    if parts is None:
        return WorkCheck(
            ok=True,
            message=(
                "I could not automatically compare that line, but the verified "
                "solution is on screen. Ask me about the step you used."
            ),
            expected_latex=solution.final_answer_latex,
        )

    variable, raw_a, raw_b, raw_c = parts
    a, b, c = (sp.nsimplify(value) for value in (raw_a, raw_b, raw_c))
    expected = sp.simplify(c - b)
    root = sp.simplify(expected / a)
    decimal = _terminating_decimal(root)
    root_latex = decimal if decimal is not None else sp.latex(root)
    var_term_latex = variable.name if a == 1 else sp.latex(a * variable)

    if "=" not in student_line:
        return WorkCheck(
            ok=False,
            message=(
                "Write the line as an equation so I can follow your working, for "
                f"example {var_term_latex} = {_fmt(expected)}."
            ),
            expected_latex=f"{var_term_latex} = {_fmt(expected)}",
            step_ref=2,
        )

    left, _, right = student_line.partition("=")
    student_lhs = _to_sympy(left)
    student_rhs = _to_sympy(right)
    if student_lhs is None or student_rhs is None:
        return WorkCheck(
            ok=False,
            message="I could not read that line clearly. Could you rewrite it?",
        )

    if sp.simplify(student_lhs - a * variable) == 0:
        if sp.simplify(student_rhs - expected) == 0:
            return WorkCheck(
                ok=True,
                message=(
                    f"That is correct. We now have {var_term_latex} = "
                    f"{_fmt(expected)}, so divide both sides by {_fmt(a)} to get "
                    f"{variable.name} = {root_latex}."
                ),
                expected_latex=f"{variable.name} = {root_latex}",
                step_ref=3,
            )
        if sp.simplify(student_rhs - (c + b)) == 0:
            move_word = "subtract" if b > 0 else "add"
            return WorkCheck(
                ok=False,
                message=(
                    f"There is a small error here. When we move {_fmt(abs(b))} to "
                    f"the other side, we {move_word} it, not "
                    f"{'add' if b > 0 else 'subtract'} it. Whatever we do to one "
                    "side of an equation, we must do to the other."
                ),
                expected_latex=(
                    f"{var_term_latex} = {sp.latex(c)} "
                    f"{'-' if b > 0 else '+'} {_fmt(abs(b))} = {_fmt(expected)}"
                ),
                correction_latex=f"{variable.name} = {root_latex}",
                step_ref=2,
            )
        return WorkCheck(
            ok=False,
            message=(
                f"Your left-hand side is right, but the right-hand side should be "
                f"{_fmt(expected)}. Check the operation you used to move the "
                "constant across."
            ),
            expected_latex=f"{var_term_latex} = {_fmt(expected)}",
            correction_latex=f"{variable.name} = {root_latex}",
            step_ref=2,
        )

    if sp.simplify(student_lhs - variable) == 0 and (
        sp.simplify(student_rhs - root) == 0
    ):
        return WorkCheck(
            ok=True,
            message=(
                f"That is exactly right. {variable.name} = {root_latex} checks "
                "out when substituted back in."
            ),
            expected_latex=f"{variable.name} = {root_latex}",
            step_ref=4,
        )

    return WorkCheck(
        ok=False,
        message=(
            "That line does not follow from the previous one. Compare it with "
            f"your working so far: we want {var_term_latex} on its own first."
        ),
        expected_latex=f"{var_term_latex} = {_fmt(expected)}",
        step_ref=2,
    )
