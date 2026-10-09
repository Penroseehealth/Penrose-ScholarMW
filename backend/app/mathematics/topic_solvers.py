"""Topic solvers that widen the tutor beyond equations and Pythagoras.

Every function here follows the same contract:

* it decides for itself whether the question belongs to it and returns ``None``
  when it does not, so the dispatcher can keep looking;
* it computes the answer with exact arithmetic (SymPy or
  :class:`fractions.Fraction`) rather than the language model;
* it builds explicit, speakable steps with LaTeX for the board; and
* it attaches an independent :mod:`app.mathematics.verification` result, so a
  solver can never present an answer it has not checked.

That last point is why a solver returns ``verification_status="unverified"``
rather than a guess: the tutor is expected to ask the student for the missing
detail instead of inventing one.
"""

from __future__ import annotations

import math
import re
from fractions import Fraction
from itertools import combinations
from typing import Any

import sympy as sp

from app.mathematics.formatting import fmt, spoken_number, spoken_ratio
from app.mathematics.intent import mentions
from app.mathematics.solution_types import TutorSolution, TutorStep
from app.mathematics.verification import (
    Verification,
    unverified,
    verification_fields,
    verified,
    verify_by_recomputation,
    verify_equality,
    verify_range,
)

_TRIG_FUNCTIONS = {
    "sin": sp.sin,
    "sine": sp.sin,
    "cos": sp.cos,
    "cosine": sp.cos,
    "tan": sp.tan,
    "tangent": sp.tan,
}


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------


def _steps_to_solution(
    problem: str,
    subject: str,
    topic: str,
    steps: list[TutorStep],
    answer_latex: str,
    answer_text: str,
    check: Verification,
    visual: dict[str, Any] | None = None,
) -> TutorSolution:
    return TutorSolution(
        problem=problem,
        subject=subject,
        topic=topic,
        steps=steps,
        final_answer_latex=answer_latex,
        final_answer_text=answer_text,
        visual=visual,
        **verification_fields(check),
    )


def _number_list(lowered: str) -> list[float]:
    return [float(m.group(0)) for m in re.finditer(r"-?\d+(?:\.\d+)?", lowered)]


def _median_of(ordered: list[float]) -> float:
    """Median computed independently of the solver's own branch logic."""
    count = len(ordered)
    middle = count // 2
    if count % 2 == 1:
        return ordered[middle]
    return (ordered[middle - 1] + ordered[middle]) / 2


def _equation_pairs(text: str) -> list[tuple[str, str]]:
    """Split text into ``(left, right)`` pairs, one per equation.

    Equations are separated in prose by "and", a comma or a full stop, and each
    one contains a single ``=``.
    """
    if text.count("=") < 2:
        return []
    # Split on the separators *before* removing filler words, because "and" is
    # both a separator and a filler.
    segments = [_strip_filler(segment) for segment in re.split(r",|\band\b|[.;]", text)]
    pairs = []
    for segment in segments:
        if "=" not in segment:
            continue
        left, _, right = segment.partition("=")
        left, right = left.strip(), right.strip()
        if left and right:
            pairs.append((left, right))
    return pairs


_FILLER_WORDS = (
    r"solve|simplify|expand|evaluate|calculate|compute|determine|work\s*out|"
    r"find|what|is|the|a|an|of|for|value|values|given|if|when|each|per|"
    r"that|with|and|then|total|sum|be|equals|equal|equation|equations|"
    r"inequality|inequalities|system|simultaneous"
)

_FILLER_RE = re.compile(rf"(?i)\b(?:{_FILLER_WORDS})\b")


def _strip_filler(text: str) -> str:
    """Remove English question wording so only the mathematics is left.

    Without this, ``parse_expr`` reads "the" as the product ``t*h*e`` and the
    whole question is silently misread as a multi-variable expression.
    """
    return _FILLER_RE.sub(" ", text)


def _parse_expression(text: str) -> sp.Expr | None:
    """Parse a single mathematical expression written in school notation."""
    from app.mathematics.tutor import _to_sympy

    return _to_sympy(_strip_filler(text))


# ---------------------------------------------------------------------------
# Hand-drawn figure specifications
#
# Diagrams are described as a small list of primitives in the same coordinate
# space as the problem ("view" gives the bounds). The client draws them from the
# verified numbers, so a picture can never disagree with the written working.
# ---------------------------------------------------------------------------


def _figure_spec(
    caption: str,
    view: tuple[float, float, float, float],
    primitives: list[dict[str, Any]],
) -> dict[str, Any]:
    xmin, xmax, ymin, ymax = view
    return {
        "kind": "figure",
        "caption": caption,
        "view": {"xmin": xmin, "xmax": xmax, "ymin": ymin, "ymax": ymax},
        "primitives": primitives,
    }


def _segment(
    x1: float, y1: float, x2: float, y2: float, **extra: Any
) -> dict[str, Any]:
    return {"type": "segment", "x1": x1, "y1": y1, "x2": x2, "y2": y2, **extra}


def _point(x: float, y: float, **extra: Any) -> dict[str, Any]:
    return {"type": "point", "x": x, "y": y, **extra}


def _polygon(points: list[tuple[float, float]], **extra: Any) -> dict[str, Any]:
    return {"type": "polygon", "points": [list(point) for point in points], **extra}


def _circle(cx: float, cy: float, radius: float, **extra: Any) -> dict[str, Any]:
    return {"type": "circle", "cx": cx, "cy": cy, "r": radius, **extra}


def _label(x: float, y: float, text: str) -> dict[str, Any]:
    return {"type": "label", "x": x, "y": y, "text": text}


def _curve_points(
    expression: sp.Expr,
    variable: sp.Symbol,
    xmin: float,
    xmax: float,
    samples: int = 80,
) -> list[list[float]]:
    function = sp.lambdify(variable, expression, "math")
    points: list[list[float]] = []
    for index in range(samples + 1):
        x = xmin + (xmax - xmin) * index / samples
        try:
            y = float(function(x))
        except (TypeError, ValueError, ZeroDivisionError):
            continue
        if math.isfinite(y):
            points.append([x, y])
    return points


def _triangle_figure(
    base: float, height: float, unit: str, caption: str
) -> dict[str, Any]:
    """Right-angled triangle with base and perpendicular height labelled."""
    xmin, xmax = -1.3, base + 0.8
    ymin, ymax = -1.3, height + 0.8
    corner = min(0.5, base * 0.08, height * 0.08)
    primitives = [
        _polygon([(0.0, 0.0), (base, 0.0), (0.0, height)]),
        _segment(corner, 0.0, corner, corner),
        _segment(corner, corner, 0.0, corner),
        _label(base / 2.0, -0.65, f"base = {fmt(base)}{unit}"),
        _label(-1.15, height / 2.0, f"height = {fmt(height)}{unit}"),
    ]
    return _figure_spec(caption, (xmin, xmax, ymin, ymax), primitives)


def _circle_figure(radius: float, unit: str, caption: str) -> dict[str, Any]:
    """Circle with its radius drawn and labelled."""
    r = radius
    xmin, xmax = -r - 1.0, r + 1.0
    ymin, ymax = -r - 1.0, r + 1.0
    primitives = [
        _circle(0.0, 0.0, r),
        _point(0.0, 0.0, filled=False),
        _segment(0.0, 0.0, r, 0.0),
        _label(r / 2.0, -max(0.5, r * 0.08), f"r = {fmt(r)}{unit}"),
    ]
    return _figure_spec(caption, (xmin, xmax, ymin, ymax), primitives)


def _statistics_figure(
    values: list[float], statistic: str, answer: float
) -> dict[str, Any]:
    """Column chart of the data values with the statistic marked."""
    xmin, xmax = -0.6, float(len(values)) + 0.8
    ymin = min(0.0, min(values), answer) - 1.0
    ymax = max(0.0, max(values), answer) + 1.0
    primitives: list[dict[str, Any]] = [{"type": "axes"}]
    width = 0.6
    for index, value in enumerate(values):
        primitives.append(
            {
                "type": "rect",
                "x": index + 0.5 - width / 2.0,
                "y": min(0.0, value),
                "w": width,
                "h": abs(value),
                "label": fmt(value),
            }
        )
    if statistic in ("mean", "median"):
        primitives.append(
            _segment(
                0.0,
                answer,
                float(len(values)),
                answer,
                dashed=True,
                label=f"{statistic} = {fmt(answer)}",
            )
        )
    return _figure_spec(
        f"Each bar is one data value; the {statistic} is marked.",
        (xmin, xmax, ymin, ymax),
        primitives,
    )


def _lp_figure(
    variables: list[sp.Symbol],
    constraints: list[tuple[sp.Expr, str]],
    vertices: list[dict[sp.Symbol, float]],
    label: str,
    best_value: float,
) -> dict[str, Any]:
    """Feasible region and optimum corner point for the linear programme."""
    x_symbol, y_symbol = variables[0], variables[1]
    xs = [point[x_symbol] for point in vertices]
    ys = [point[y_symbol] for point in vertices]
    xmin = min(0.0, min(xs)) - 1.5
    xmax = max(0.0, max(xs)) + 1.5
    ymin = min(0.0, min(ys)) - 1.5
    ymax = max(0.0, max(ys)) + 1.5

    region = _lp_region(vertices, x_symbol, y_symbol)
    primitives: list[dict[str, Any]] = [{"type": "axes"}]
    if region:
        primitives.append(
            _polygon([(point[x_symbol], point[y_symbol]) for point in region])
        )
    for expression, _ in constraints:
        coeff_x = expression.coeff(x_symbol)
        coeff_y = expression.coeff(y_symbol)
        constant = _lp_constant(expression, variables)
        primitives.append(
            _segment(
                xmin,
                -(coeff_x * xmin + constant) / coeff_y if coeff_y != 0 else ymin,
                xmax,
                -(coeff_x * xmax + constant) / coeff_y if coeff_y != 0 else ymax,
                dashed=True,
            )
            if coeff_y != 0
            else _segment(
                -constant / coeff_x if coeff_x != 0 else xmin,
                ymin,
                -constant / coeff_x if coeff_x != 0 else xmin,
                ymax,
                dashed=True,
            )
        )
    if region:
        primitives.append(
            _point(
                region[0][x_symbol],
                region[0][y_symbol],
                label=f"{label} = {fmt(best_value)}",
                filled=True,
            )
        )
    return _figure_spec(
        "The shaded polygon is the feasible region; the best corner point is marked.",
        (xmin, xmax, ymin, ymax),
        primitives,
    )


def _lp_region(
    vertices: list[dict[sp.Symbol, float]],
    x_symbol: sp.Symbol,
    y_symbol: sp.Symbol,
) -> list[dict[sp.Symbol, float]] | None:
    """Order the corner points around their centroid to close the polygon."""
    if len(vertices) < 3:
        return None
    centre_x = sum(point[x_symbol] for point in vertices) / len(vertices)
    centre_y = sum(point[y_symbol] for point in vertices) / len(vertices)

    def angle(point: dict[sp.Symbol, float]) -> float:
        return math.atan2(point[y_symbol] - centre_y, point[x_symbol] - centre_x)

    return sorted(vertices, key=angle)


# ---------------------------------------------------------------------------
# Simultaneous equations
# ---------------------------------------------------------------------------


def solve_simultaneous(problem: str, lowered: str) -> TutorSolution | None:
    """Two equations in two unknowns, e.g. ``2x + y = 7 and x - y = 2``.

    The word "simultaneous" is not required: two equations in the same two
    unknowns are enough, which is how students usually phrase the question.
    """
    pairs = _equation_pairs(problem)
    if len(pairs) < 2:
        return None

    equations: list[sp.Eq] = []
    for left, right in pairs[:2]:
        lhs = _parse_expression(left)
        rhs = _parse_expression(right)
        if lhs is None or rhs is None:
            return None
        equations.append(sp.Eq(lhs, rhs))

    symbols = sorted(
        set().union(*(eq.free_symbols for eq in equations)), key=lambda s: s.name
    )
    if len(symbols) != 2:
        return None

    try:
        solutions = sp.solve(equations, symbols, dict=True)
    except (TypeError, ValueError, sp.SympifyError):
        return None
    if not solutions:
        return TutorSolution(
            problem=problem,
            subject="algebra",
            topic="simultaneous_equations",
            steps=[
                TutorStep(
                    id=1,
                    title="No simultaneous solution",
                    explanation=(
                        "These two equations contradict each other, so there is no "
                        "pair of values that satisfies both at the same time."
                    ),
                    narration="These two equations contradict each other, so there is no solution.",
                )
            ],
            final_answer_latex="\\text{no solution}",
            final_answer_text="no solution",
            **verification_fields(verified("The system is inconsistent.")),
        )

    answer = solutions[0]
    residual = max(
        float(abs(sp.N(eq.lhs.subs(answer) - eq.rhs.subs(answer)))) for eq in equations
    )
    check = verify_by_recomputation(
        residual,
        0.0,
        "Both equations return to balance with these values",
        tolerance=1e-7,
    )

    symbol_text = " and ".join(s.name for s in symbols)
    steps = [
        TutorStep(
            id=1,
            title="Write down the equations",
            explanation=f"We have two equations in {symbol_text}.",
            narration=f"We have two equations in {symbol_text}.",
            latex_lines=[f"{sp.latex(eq)}" for eq in equations],
        )
    ]

    latex_lines = []
    narration_parts = []
    for symbol in symbols:
        value = answer[symbol]
        latex_lines.append(f"{symbol.name} = {sp.latex(value)}")
        narration_parts.append(
            f"{symbol.name} equals {spoken_number(float(sp.N(value)))}"
        )
    steps.append(
        TutorStep(
            id=2,
            title="Solve the system",
            explanation=(
                "Eliminating one unknown at a time leaves a single equation, "
                "which gives the values below."
            ),
            narration="Eliminating one unknown at a time gives us "
            + ", and ".join(narration_parts)
            + ".",
            latex_lines=latex_lines,
        )
    )
    steps.append(
        TutorStep(
            id=3,
            title="Check both equations",
            explanation="Substituting the values back into both equations balances each one.",
            narration=(
                "Substituting back into both equations balances each one, so the "
                "answers are correct."
            ),
            latex_lines=[
                f"{sp.latex(eq.lhs)} = {sp.latex(eq.rhs)} \\quad \\Rightarrow \\quad "
                f"{sp.latex(sp.simplify(eq.lhs.subs(answer)))} = "
                f"{sp.latex(sp.simplify(eq.rhs.subs(answer)))}"
                for eq in equations
            ],
        )
    )

    answer_text = ", ".join(f"{s.name} = {fmt(answer[s])}" for s in symbols)
    return _steps_to_solution(
        problem,
        "algebra",
        "simultaneous_equations",
        steps,
        ", ".join(latex_lines),
        answer_text,
        check,
    )


# ---------------------------------------------------------------------------
# Inequalities
# ---------------------------------------------------------------------------


def solve_inequality(problem: str, lowered: str) -> TutorSolution | None:
    """Inequalities in one unknown, e.g. ``solve 2x + 3 < 11``."""
    if not re.search(r"[<>]=?|less than|greater than|at least|at most", lowered):
        return None
    match = re.search(r"(.+?)\s*(<=|>=|<|>|≤|≥)\s*(.+)", problem.strip())
    if match is None:
        return None

    left_text = _strip_filler(match.group(1))
    right_text = _strip_filler(match.group(3))
    left = _parse_expression(left_text)
    right = _parse_expression(right_text)
    if left is None or right is None:
        return None

    symbol_text = match.group(2)
    relation = {
        "<": "<",
        ">": ">",
        "<=": "<=",
        ">=": ">=",
        "≤": "<=",
        "≥": ">=",
    }[symbol_text]

    symbols = sorted((left - right).free_symbols, key=lambda s: s.name)
    if len(symbols) != 1:
        return None
    variable = symbols[0]

    operator = {"<": sp.Lt, ">": sp.Gt, "<=": sp.Le, ">=": sp.Ge}[relation]
    try:
        solution_set = sp.solveset(operator(left, right), variable, domain=sp.S.Reals)
    except (TypeError, ValueError, sp.SympifyError):
        return None

    boundary_info = _inequality_boundary(solution_set)
    if boundary_info is None:
        return None
    boundary, direction, inclusive = boundary_info

    boundary_value = float(sp.N(boundary))
    coefficient = float(sp.N(left.coeff(variable)))
    constant = float(sp.N((left - right).subs(variable, 0)))

    relation_symbol = (
        ("<=" if inclusive else "<")
        if direction == "below"
        else (">=" if inclusive else ">")
    )
    answer_latex = f"{variable.name} {relation_symbol} {sp.latex(boundary)}"
    answer_text = f"{variable.name} {relation_symbol} {fmt(boundary)}"

    step = boundary_value - 1 if direction == "below" else boundary_value + 1
    sample_value = coefficient * step + constant
    holds = sample_value <= 0 if direction == "below" else sample_value >= 0
    detail = (
        f"A test value of {variable.name} = {fmt(step)} satisfies the inequality."
        if holds
        else f"A test value of {variable.name} = {fmt(step)} does not satisfy the inequality."
    )
    check = verified(detail) if holds else unverified(detail)

    steps = [
        TutorStep(
            id=1,
            title="Write down the inequality",
            explanation=(
                f"We need every value of {variable.name} for which the left side "
                f"stays {'below' if direction == 'below' else 'above'} the right side."
            ),
            narration=(
                f"We need every value of {variable.name} for which the left side "
                f"stays {'below' if direction == 'below' else 'above'} the right side."
            ),
            latex_lines=[f"{sp.latex(left)} {relation} {sp.latex(right)}"],
        ),
        TutorStep(
            id=2,
            title="Isolate the unknown",
            explanation=(
                "Collecting the unknown on one side gives the boundary value; every "
                f"value {direction} it is allowed."
            ),
            narration=(
                f"Collecting the unknown on one side gives {spoken_number(boundary_value)}. "
                f"Every value {direction} that is allowed."
            ),
            latex_lines=[answer_latex],
        ),
        TutorStep(
            id=3,
            title="Check with a test value",
            explanation="Substituting a value on the allowed side confirms the inequality.",
            narration=f"Substituting {variable.name} equals {fmt(step)} confirms it.",
            latex_lines=[
                f"{sp.latex(left.subs(variable, step))} "
                f"{relation} {sp.latex(right.subs(variable, step))}"
            ],
        ),
    ]

    return _steps_to_solution(
        problem, "algebra", "inequality", steps, answer_latex, answer_text, check
    )


def _inequality_boundary(
    solution_set: sp.Set,
) -> tuple[sp.Expr, str, bool] | None:
    """Reduce a solved inequality to ``(boundary, direction, inclusive)``.

    Only a single unbounded-by-one-side interval can be written as one
    comparison, so compound sets and whole-number solutions are rejected.
    """
    if not isinstance(solution_set, sp.Interval):
        return None
    lower, upper = solution_set.start, solution_set.end
    if lower == -sp.oo and upper == sp.oo:
        return None
    if lower == -sp.oo:
        return sp.simplify(upper), "below", upper in solution_set
    if upper == sp.oo:
        return sp.simplify(lower), "above", lower in solution_set
    return None


# ---------------------------------------------------------------------------
# Algebraic simplification
# ---------------------------------------------------------------------------


def _is_still_factored(expression: sp.Expr) -> bool:
    """True when a result keeps a bracket product the student expects opened out."""
    return isinstance(expression, sp.Mul) and any(
        isinstance(factor, sp.Add) for factor in expression.args
    )


def solve_simplify(problem: str, lowered: str) -> TutorSolution | None:
    """Simplify, expand or factorise an algebraic expression."""
    if not mentions(lowered, "simplify", "expand", "factorise", "factorize", "factor"):
        return None
    body = re.sub(r"(?i)\b(simplify|expand|factorise|factorize|factor)\b", " ", problem)
    body = body.strip().rstrip("?").strip()
    if "=" in body or not re.search(r"[a-zA-Z]", body):
        return None

    expression = _parse_expression(body)
    if expression is None or not expression.free_symbols:
        return None

    wants_factor = mentions(lowered, "factorise", "factorize", "factor")
    try:
        simplified = sp.simplify(expression)
        expanded = sp.simplify(sp.expand(expression))
        factored = sp.factor(expression)
    except (TypeError, ValueError, sp.SympifyError):
        return None

    # ``simplify`` happily leaves ``(x - 1)*(x + 3)`` factorised, which is not
    # what a school student means by "simplify this bracket product".
    if wants_factor:
        target = factored
    elif _is_still_factored(simplified):
        target = expanded
    elif "expand" in lowered:
        target = expanded
    else:
        target = simplified

    check = verify_equality(
        expression,
        target,
        "The factorised expression" if wants_factor else "The simplified expression",
    )

    variable_text = ", ".join(sorted(s.name for s in expression.free_symbols))
    if wants_factor:
        steps = [
            TutorStep(
                id=1,
                title="Write out the expression",
                explanation=f"We factorise the expression in {variable_text}.",
                narration=f"We factorise the expression in {variable_text}.",
                latex_lines=[sp.latex(expression)],
            ),
            TutorStep(
                id=2,
                title="Look for factors and brackets",
                explanation=(
                    "First take out any common factor, then write the expression as "
                    "a product of brackets that multiply back to the original."
                ),
                narration=(
                    "We take out any common factor and write the expression as a "
                    "product of brackets."
                ),
                latex_lines=[f"{sp.latex(expression)} = {sp.latex(target)}"],
            ),
            TutorStep(
                id=3,
                title="Check by expanding",
                explanation=(
                    "Expanding the brackets returns the original expression, so the "
                    "factorisation is correct."
                ),
                narration=(
                    "Expanding the brackets returns the original expression, so the "
                    "factorisation is correct."
                ),
                latex_lines=[
                    f"{sp.latex(sp.expand(target))} = {sp.latex(sp.expand(expression))}"
                ],
            ),
        ]
        topic = "factorise_expression"
    else:
        steps = [
            TutorStep(
                id=1,
                title="Write out the expression",
                explanation=f"We simplify the expression in {variable_text}.",
                narration=f"We simplify the expression in {variable_text}.",
                latex_lines=[sp.latex(expression)],
            ),
            TutorStep(
                id=2,
                title="Simplify",
                explanation=(
                    "Multiplying powers with the same base adds the exponents, and "
                    "dividing subtracts them. Like terms are then collected."
                ),
                narration=(
                    "Multiplying powers with the same base adds the exponents, and "
                    "dividing subtracts them. Collecting like terms gives the result."
                ),
                latex_lines=[f"{sp.latex(expression)} = {sp.latex(target)}"],
            ),
            TutorStep(
                id=3,
                title="Check",
                explanation=(
                    "The simplified form expands back to the original expression, so it "
                    "is equivalent."
                ),
                narration=(
                    "The simplified form expands back to the original expression, so it "
                    "is equivalent."
                ),
                latex_lines=[
                    f"{sp.latex(sp.expand(target))} = {sp.latex(sp.expand(expression))}"
                ],
            ),
        ]
        topic = "simplify_expression"

    return _steps_to_solution(
        problem,
        "algebra",
        topic,
        steps,
        sp.latex(target),
        _plain_expression(target),
        check,
    )


def _plain_expression(expression: sp.Expr) -> str:
    """Readable single-line form for the answer field, e.g. ``x^2`` not ``x**2``."""
    text = sp.sstr(expression)
    return text.replace("**", "^")


# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------


def solve_function_value(problem: str, lowered: str) -> TutorSolution | None:
    """Evaluate a stated function, e.g. ``if f(x) = 2x + 1, find f(4)``."""
    definition = re.search(
        r"([a-z])\s*\(\s*([a-z])\s*\)\s*=\s*([^,.;]+)", problem, re.IGNORECASE
    )
    evaluation = re.search(
        r"([a-z])\s*\(\s*(-?\d+(?:\.\d+)?)\s*\)",
        problem[definition.end() :] if definition else "",
    )
    if definition is None or evaluation is None:
        return None

    name, variable_name, body_text = (
        definition.group(1),
        definition.group(2),
        definition.group(3),
    )
    argument = float(evaluation.group(2))

    variable = sp.Symbol(variable_name)
    body = _parse_expression(body_text)
    if body is None or variable not in body.free_symbols:
        return None

    try:
        value = sp.simplify(body.subs(variable, argument))
    except (TypeError, ValueError, sp.SympifyError):
        return None

    numeric = float(sp.N(value))
    recomputed = float(sp.N(body.subs(variable, argument), 15))
    check = verify_by_recomputation(
        numeric, recomputed, f"{name}({fmt(argument)})", tolerance=1e-9
    )

    steps = [
        TutorStep(
            id=1,
            title="Write down the function",
            explanation=f"The function is defined as {name} of {variable_name}.",
            narration=f"The function is defined as {name} of {variable_name}.",
            latex_lines=[f"{name}({variable_name}) = {sp.latex(body)}"],
        ),
        TutorStep(
            id=2,
            title="Substitute the value",
            explanation=(
                f"Replace every {variable_name} in the rule with {fmt(argument)}."
            ),
            narration=f"Replace every {variable_name} in the rule with {spoken_number(argument)}.",
            latex_lines=[
                f"{name}({fmt(argument)}) = "
                f"{sp.latex(body.subs(variable, argument))}"
            ],
        ),
        TutorStep(
            id=3,
            title="Work out the value",
            explanation="Evaluating the substituted expression gives the answer.",
            narration=f"Evaluating that gives {spoken_number(numeric)}.",
            latex_lines=[f"{name}({fmt(argument)}) = {sp.latex(value)}"],
        ),
    ]

    return _steps_to_solution(
        problem,
        "functions",
        "function_evaluation",
        steps,
        f"{name}({fmt(argument)}) = {sp.latex(value)}",
        fmt(value),
        check,
    )


# ---------------------------------------------------------------------------
# Sequences
# ---------------------------------------------------------------------------


def solve_sequence(problem: str, lowered: str) -> TutorSolution | None:
    """Arithmetic and geometric sequence questions."""
    if not mentions(
        lowered, "sequence", "series", "arithmetic progression", "geometric progression"
    ):
        return None

    sequence_match = re.search(
        r"((?:-?\d+(?:\.\d+)?\s*,\s*){2,}-?\d+(?:\.\d+)?(?:\s*,\s*\.\.\.)?)", problem
    )
    if sequence_match is None:
        return None
    raw_terms = [
        float(t) for t in re.findall(r"-?\d+(?:\.\d+)?", sequence_match.group(1))
    ]
    if len(raw_terms) < 3:
        return None

    differences = [raw_terms[i + 1] - raw_terms[i] for i in range(len(raw_terms) - 1)]
    is_arithmetic = all(abs(d - differences[0]) < 1e-9 for d in differences)

    nth_match = re.search(r"(\d+)\s*(?:th|st|nd|rd)\s*term", lowered)
    sum_match = re.search(r"sum of the first\s+(\d+)", lowered)
    nth_formula = re.search(r"\bnth\s+term\b", lowered) is not None
    if nth_match is None and sum_match is None and not nth_formula:
        return None

    common_difference = differences[0]
    first = raw_terms[0]

    if is_arithmetic:
        index = int(nth_match.group(1)) if nth_match else None
        steps = [
            TutorStep(
                id=1,
                title="Find the common difference",
                explanation="Subtract consecutive terms to get the common difference.",
                narration=(
                    "Subtracting consecutive terms gives a common difference of "
                    f"{spoken_number(common_difference)}."
                ),
                latex_lines=[
                    f"{fmt(raw_terms[1])} - {fmt(first)} = {fmt(common_difference)}"
                ],
            )
        ]
        if index is None and sum_match is None and nth_formula:
            return _arithmetic_nth_formula(
                problem, raw_terms, first, common_difference, steps
            )
        if index is not None:
            last = first + (index - 1) * common_difference
            total = index * (2 * first + (index - 1) * common_difference) / 2
            check = verify_by_recomputation(
                last,
                first + (index - 1) * common_difference,
                f"Term {index}",
            )
            steps += [
                TutorStep(
                    id=2,
                    title="Use the nth term formula",
                    explanation=(
                        "Each term is the first term plus a number of common "
                        "differences."
                    ),
                    narration=(
                        f"Each term is the first term plus its position minus one "
                        f"common differences, so term {index} is {spoken_number(last)}."
                    ),
                    latex_lines=[
                        f"a_{{{index}}} = a_1 + ({index}-1)d",
                        f"a_{{{index}}} = {fmt(first)} + {index - 1}"
                        f"({fmt(common_difference)}) = {fmt(last)}",
                    ],
                )
            ]
            if sum_match is not None:
                steps.append(
                    TutorStep(
                        id=3,
                        title="Sum the first terms",
                        explanation="Pair the first and last term and multiply by half the count.",
                        narration=f"The sum of the first {sum_match.group(1)} terms is {spoken_number(total)}.",
                        latex_lines=[
                            f"S_{{{index}}} = \\frac{{{index}}}{{2}}"
                            f"({fmt(first)} + {fmt(last)}) = {fmt(total)}"
                        ],
                    )
                )
            final_latex = f"a_{{{index}}} = {fmt(last)}"
            final_text = fmt(last)
            topic = "arithmetic_sequence"
        else:
            count = int(sum_match.group(1))
            last = first + (count - 1) * common_difference
            total = count * (2 * first + (count - 1) * common_difference) / 2
            check = verify_by_recomputation(
                total,
                sum(first + i * common_difference for i in range(count)),
                f"The sum of the first {count} terms",
            )
            steps.append(
                TutorStep(
                    id=2,
                    title="Use the sum formula",
                    explanation=(
                        "Multiply the number of terms by the average of the first "
                        "and last term."
                    ),
                    narration=f"Multiplying {count} by the average of the first and last term gives {spoken_number(total)}.",
                    latex_lines=[
                        f"S_{{{count}}} = \\frac{{{count}}}{{2}}"
                        f"({fmt(first)} + {fmt(last)}) = {fmt(total)}"
                    ],
                )
            )
            final_latex = f"S_{{{count}}} = {fmt(total)}"
            final_text = fmt(total)
            topic = "arithmetic_series"
        return _steps_to_solution(
            problem, "algebra", topic, steps, final_latex, final_text, check
        )

    ratios = [
        raw_terms[i + 1] / raw_terms[i]
        for i in range(len(raw_terms) - 1)
        if raw_terms[i]
    ]
    if not ratios or any(abs(r - ratios[0]) > 1e-9 for r in ratios):
        return None
    common_ratio = ratios[0]
    steps = [
        TutorStep(
            id=1,
            title="Find the common ratio",
            explanation="Divide consecutive terms to get the common ratio.",
            narration=(
                "Dividing consecutive terms gives a common ratio of "
                f"{spoken_number(common_ratio)}."
            ),
            latex_lines=[
                f"{fmt(raw_terms[1])} \\div {fmt(first)} = {fmt(common_ratio)}"
            ],
        )
    ]
    if nth_match is not None:
        index = int(nth_match.group(1))
        last = first * common_ratio ** (index - 1)
        total = (
            first * (common_ratio**index - 1) / (common_ratio - 1)
            if common_ratio != 1
            else first * index
        )
        check = verify_by_recomputation(
            last,
            first * common_ratio ** (index - 1),
            f"Term {index}",
        )
        steps.append(
            TutorStep(
                id=2,
                title="Use the nth term formula",
                explanation="Each term is the first term multiplied by the common ratio.",
                narration=f"Each term multiplies by the common ratio, so term {index} is {spoken_number(last)}.",
                latex_lines=[
                    f"a_{{{index}}} = a_1 r^{{{index - 1}}}",
                    f"a_{{{index}}} = {fmt(first)}({fmt(common_ratio)})^{{{index}-1}}"
                    f" = {fmt(last)}",
                ],
            )
        )
        if sum_match is not None:
            steps.append(
                TutorStep(
                    id=3,
                    title="Sum the first terms",
                    explanation="Use the geometric sum formula.",
                    narration=f"The sum of the first {sum_match.group(1)} terms is {spoken_number(total)}.",
                    latex_lines=[f"S_{{{index}}} = {fmt(total)}"],
                )
            )
        return _steps_to_solution(
            problem,
            "algebra",
            "geometric_sequence",
            steps,
            f"a_{{{index}}} = {fmt(last)}",
            fmt(last),
            check,
        )

    count = int(sum_match.group(1)) if sum_match else 0
    if count <= 0:
        return None
    total = (
        first * (common_ratio**count - 1) / (common_ratio - 1)
        if common_ratio != 1
        else first * count
    )
    check = verify_by_recomputation(
        total,
        sum(first * common_ratio**i for i in range(count)),
        f"The sum of the first {count} terms",
    )
    steps.append(
        TutorStep(
            id=2,
            title="Use the sum formula",
            explanation="Apply the geometric sum formula to the common ratio.",
            narration=f"Applying the geometric sum formula gives {spoken_number(total)}.",
            latex_lines=[f"S_{{{count}}} = {fmt(total)}"],
        )
    )
    return _steps_to_solution(
        problem,
        "algebra",
        "geometric_series",
        steps,
        f"S_{{{count}}} = {fmt(total)}",
        fmt(total),
        check,
    )


def _arithmetic_nth_formula(
    problem: str,
    raw_terms: list[float],
    first: float,
    common_difference: float,
    steps: list[TutorStep],
) -> TutorSolution:
    """General term ``a_n = a_1 + (n - 1)d`` for an arithmetic sequence."""
    n = sp.Symbol("n", positive=True, integer=True)
    general = sp.simplify(
        sp.expand(sp.nsimplify(first) + (n - 1) * sp.nsimplify(common_difference))
    )
    general_text = _plain_expression(general).replace("*", "")
    reproduced = all(
        abs(float(sp.N(general.subs(n, position + 1))) - value) < 1e-9
        for position, value in enumerate(raw_terms)
    )
    check = Verification(
        status="verified" if reproduced else "unverified",
        detail=(
            "The general term reproduces every term in the sequence."
            if reproduced
            else "The general term did not reproduce every term in the sequence."
        ),
    )
    steps.append(
        TutorStep(
            id=len(steps) + 1,
            title="Write the general term",
            explanation=(
                "Each term is the first term plus one less than its position, "
                "multiplied by the common difference."
            ),
            narration=(
                "The general term is the first term plus n minus one times the "
                f"common difference, giving a n equals {general_text}."
            ),
            latex_lines=[
                "a_n = a_1 + (n - 1)d",
                f"a_n = {fmt(first)} + (n - 1)({fmt(common_difference)})"
                f" = {sp.latex(general)}",
            ],
        )
    )
    return _steps_to_solution(
        problem,
        "algebra",
        "arithmetic_sequence",
        steps,
        f"a_n = {sp.latex(general)}",
        f"a_n = {general_text}",
        check,
    )


# ---------------------------------------------------------------------------
# Statistics
# ---------------------------------------------------------------------------


def _data_list(text: str) -> list[float] | None:
    """Pull a list of data values out of prose.

    Handles both "4, 7, 9, 12 and 18" and "4, 7, 9, 12, 18", stopping at the
    first word that cannot belong to the list.
    """
    match = re.search(
        r"((?:-?\d+(?:\.\d+)?\s*(?:,|\band\b)\s*){1,}-?\d+(?:\.\d+)?)", text
    )
    if match is None:
        return None
    values = [float(v) for v in re.findall(r"-?\d+(?:\.\d+)?", match.group(1))]
    return values if len(values) >= 2 else None


def solve_statistics(problem: str, lowered: str) -> TutorSolution | None:
    """Mean, median, mode and range from a list of values."""
    statistic = None
    for name in ("mean", "median", "mode", "range"):
        if name in lowered:
            statistic = name
            break
    if statistic is None:
        return None

    values = _data_list(problem)
    if values is None:
        return None

    ordered = sorted(values)
    steps = [
        TutorStep(
            id=1,
            title="List the values in order",
            explanation="Sorting the data makes the middle and most common values clear.",
            narration="Sorting the data first makes the middle and most common values clear.",
            latex_lines=[", ".join(fmt(v) for v in ordered)],
        )
    ]

    # Overridden by the mode branch, where several values can be the answer.
    answer_text: str | None = None

    if statistic == "mean":
        total = sum(values)
        answer = total / len(values)
        recomputed = sum(ordered) / len(ordered)
        steps.append(
            TutorStep(
                id=2,
                title="Add and divide",
                explanation=(
                    "The mean is the total of the values divided by how many there are."
                ),
                narration=(
                    f"The values add to {spoken_number(total)}, and there are "
                    f"{len(values)} of them, so the mean is {spoken_number(answer)}."
                ),
                latex_lines=[
                    f"{' + '.join(fmt(v) for v in ordered)} = {fmt(total)}",
                    f"\\frac{{{fmt(total)}}}{{{len(values)}}} = {fmt(answer)}",
                ],
            )
        )
        check = verify_by_recomputation(answer, recomputed, "The mean")
        latex = f"\\text{{mean}} = {fmt(answer)}"
        subject, topic = "statistics", "mean"

    elif statistic == "median":
        count = len(ordered)
        lower_index = count // 2
        upper_index = lower_index + 1
        subscript_lower = "{" + str(lower_index) + "}"
        subscript_upper = "{" + str(upper_index) + "}"
        if count % 2 == 1:
            answer = ordered[lower_index]
            latex = f"\\text{{median}} = {fmt(answer)}"
            work = f"\\text{{median}} = x_{subscript_upper} = {fmt(answer)}"
            narration_tail = (
                "With an odd number of values the median is the middle one, "
                f"{spoken_number(answer)}."
            )
        else:
            upper = ordered[lower_index]
            lower = ordered[lower_index - 1]
            answer = (upper + lower) / 2
            latex = f"\\text{{median}} = {fmt(answer)}"
            work = (
                "\\frac{x_"
                + subscript_lower
                + " + x_"
                + subscript_upper
                + "}{2} = \\frac{"
                + fmt(lower)
                + " + "
                + fmt(upper)
                + "}{2} = "
                + fmt(answer)
            )
            narration_tail = (
                "With an even number of values we average the two middle ones, "
                f"giving {spoken_number(answer)}."
            )

        check = verify_by_recomputation(
            answer,
            _median_of(ordered),
            "The median",
        )
        steps.append(
            TutorStep(
                id=2,
                title="Find the middle value",
                explanation=(
                    "The median is the middle value once the data is in order, "
                    "averaging the two middle values when the count is even."
                ),
                narration=narration_tail,
                latex_lines=[work],
            )
        )
        subject, topic = "statistics", "median"

    elif statistic == "mode":
        counts: dict[float, int] = {}
        for value in ordered:
            counts[value] = counts.get(value, 0) + 1
        best = max(counts.values())
        modes = sorted(v for v, c in counts.items() if c == best)
        if best < 2:
            return None
        answer = modes[0]
        check = verify_by_recomputation(
            float(counts[answer]),
            float(max(counts.values())),
            "The mode occurring most often",
        )
        steps.append(
            TutorStep(
                id=2,
                title="Count the repetitions",
                explanation="The mode is the value that appears most often.",
                narration=(
                    "The value that appears most often is "
                    f"{spoken_number(answer)}, appearing {best} times."
                ),
                latex_lines=[
                    f"\\text{{mode}} = {fmt(answer)} \\quad ({best} \\text{{ times}})"
                ],
            )
        )
        if len(modes) > 1:
            steps[1].title = "Count the repetitions"
            steps[1].latex_lines.append(
                "\\text{{modes}} = " + ", ".join(fmt(m) for m in modes)
            )
            steps[1].narration = (
                "There is no single mode here: "
                + ", ".join(spoken_number(m) for m in modes)
                + f" each appear {best} times, so all of them are modes."
            )
        latex = "\\text{{mode}} = " + ", ".join(fmt(m) for m in modes)
        answer_text = ", ".join(fmt(m) for m in modes)
        subject, topic = "statistics", "mode"

    else:
        answer = ordered[-1] - ordered[0]
        check = verify_by_recomputation(answer, ordered[-1] - ordered[0], "The range")
        steps.append(
            TutorStep(
                id=2,
                title="Subtract the smallest from the largest",
                explanation="The range is the difference between the largest and smallest values.",
                narration=(
                    f"The range is {spoken_number(ordered[-1])} minus "
                    f"{spoken_number(ordered[0])}, which is {spoken_number(answer)}."
                ),
                latex_lines=[
                    f"\\text{{range}} = {fmt(ordered[-1])} - {fmt(ordered[0])} = {fmt(answer)}"
                ],
            )
        )
        latex = f"\\text{{range}} = {fmt(answer)}"
        subject, topic = "statistics", "range"

    return _steps_to_solution(
        problem,
        subject,
        topic,
        steps,
        latex,
        answer_text or fmt(answer),
        check,
        visual=_statistics_figure(values, statistic, float(answer)),
    )


# ---------------------------------------------------------------------------
# Probability
# ---------------------------------------------------------------------------


def solve_probability(problem: str, lowered: str) -> TutorSolution | None:
    """Simple probability from a stated ratio or from counted outcomes."""
    if "probability" not in lowered and "chance" not in lowered:
        return None

    ratio_match = re.search(r"(-?\d+(?:\.\d+)?)\s*[:/]\s*(-?\d+(?:\.\d+)?)", problem)
    if ratio_match is not None:
        favourable = float(ratio_match.group(1))
        total = float(ratio_match.group(2))
    else:
        counted = _counted_outcomes(problem)
        if counted is None:
            return None
        total, favourable = counted
        if total == 0:
            return None

    if total == 0 or favourable > total or favourable < 0:
        return None

    probability = favourable / total
    check = verify_range(probability, 0.0, 1.0, "The probability")
    exact = Fraction(favourable).limit_denominator(10**6) / Fraction(
        total
    ).limit_denominator(10**6)

    steps = [
        TutorStep(
            id=1,
            title="Identify favourable and total outcomes",
            explanation=(
                "Probability is the number of favourable outcomes divided by the "
                "total number of equally likely outcomes."
            ),
            narration=(
                f"There are {spoken_number(favourable)} favourable outcomes out of "
                f"{spoken_number(total)} equally likely ones."
            ),
            latex_lines=[f"P = \\frac{{{fmt(favourable)}}}{{{fmt(total)}}}"],
        ),
        TutorStep(
            id=2,
            title="Work out the probability",
            explanation="Dividing gives the probability as a decimal.",
            narration=f"Dividing gives {spoken_ratio(favourable, total)}.",
            latex_lines=[
                f"P = \\frac{{{fmt(favourable)}}}{{{fmt(total)}}} = {fmt(probability)}"
            ],
        ),
        TutorStep(
            id=3,
            title="Check the range",
            explanation="A probability must lie between zero and one.",
            narration="A probability must lie between zero and one, and this one does.",
            latex_lines=[f"0 \\le {fmt(probability)} \\le 1"],
        ),
    ]

    if exact.denominator != 1:
        steps[1].latex_lines.append(f"P = {exact.numerator}/{exact.denominator}")

    return _steps_to_solution(
        problem,
        "probability",
        "simple_probability",
        steps,
        f"P = {fmt(probability)}",
        fmt(probability),
        check,
    )


_OUTCOME_NOUNS = (
    "red",
    "blue",
    "green",
    "yellow",
    "black",
    "white",
    "orange",
    "purple",
    "pink",
    "brown",
    "grey",
    "gray",
)


def _counted_outcomes(problem: str) -> tuple[float, float, str] | None:
    """Read counts such as "5 red and 3 blue balls" into total and favourable.

    The favourable count is whichever group the question asks about; when the
    wording does not say, the first group mentioned is used.
    """
    pattern = r"(\d+)\s+(" + "|".join(_OUTCOME_NOUNS) + r")"
    found = re.findall(pattern, problem, re.IGNORECASE)
    if len(found) < 2:
        return None

    counts = [(int(count), noun.lower()) for count, noun in found]
    total = sum(count for count, _ in counts)

    tail = problem.lower().split("probability")[-1]
    favourable = counts[0][0]
    for count, noun in counts:
        if noun in tail:
            favourable = count
            break

    return float(total), float(favourable)


# ---------------------------------------------------------------------------
# Ratios and proportion
# ---------------------------------------------------------------------------


def solve_ratio(problem: str, lowered: str) -> TutorSolution | None:
    """Share a total in a given ratio, e.g. ``share 120 in the ratio 2:3``."""
    if "ratio" not in lowered:
        return None
    ratio_match = re.search(r"(\d+(?:\.\d+)?)\s*:\s*(\d+(?:\.\d+)?)", problem)
    total_match = re.search(
        r"(?:share|divide|split|distribute)[^0-9]{0,30}(\d+(?:\.\d+)?)", lowered
    )
    if ratio_match is None or total_match is None:
        return None

    first = float(ratio_match.group(1))
    second = float(ratio_match.group(2))
    total = float(total_match.group(1))
    parts = first + second
    if parts == 0:
        return None

    first_share = total * first / parts
    second_share = total * second / parts
    check = verify_by_recomputation(
        first_share + second_share, total, "The two shares adding back to the total"
    )

    steps = [
        TutorStep(
            id=1,
            title="Add the ratio parts",
            explanation="The ratio tells us how many parts there are in total.",
            narration=f"The ratio has {fmt(parts)} parts in total.",
            latex_lines=[f"{fmt(first)} + {fmt(second)} = {fmt(parts)}"],
        ),
        TutorStep(
            id=2,
            title="Find the value of one part",
            explanation="Divide the total by the number of parts.",
            narration=f"One part is {spoken_number(total)} divided by {fmt(parts)}.",
            latex_lines=[
                f"\\frac{{{fmt(total)}}}{{{fmt(parts)}}} = {fmt(total / parts)}"
            ],
        ),
        TutorStep(
            id=3,
            title="Work out each share",
            explanation="Multiply one part by each ratio number.",
            narration=(
                f"The first share is {spoken_number(first_share)} and the second is "
                f"{spoken_number(second_share)}."
            ),
            latex_lines=[
                f"{fmt(first)} \\times {fmt(total / parts)} = {fmt(first_share)}",
                f"{fmt(second)} \\times {fmt(total / parts)} = {fmt(second_share)}",
            ],
        ),
        TutorStep(
            id=4,
            title="Check the total",
            explanation="The shares must add back to the amount we started with.",
            narration="The shares add back to the original total, so the answer is right.",
            latex_lines=[
                f"{fmt(first_share)} + {fmt(second_share)} = {fmt(first_share + second_share)}"
            ],
        ),
    ]

    return _steps_to_solution(
        problem,
        "ratios",
        "share_in_ratio",
        steps,
        f"{fmt(first_share)} : {fmt(second_share)}",
        f"{fmt(first_share)} and {fmt(second_share)}",
        check,
    )


# ---------------------------------------------------------------------------
# Fractions
# ---------------------------------------------------------------------------


def solve_fractions(problem: str, lowered: str) -> TutorSolution | None:
    """Exact arithmetic on fractions such as ``3/4 + 2/8`` or ``2/5 of 35``."""
    fraction_matches = re.findall(r"(-?\d+)\s*/\s*(\d+)", problem)
    if not fraction_matches:
        return None

    of_match = re.search(
        r"(-?\d+)\s*/\s*(\d+)\s+of\s+(-?\d+(?:\.\d+)?)", problem, re.IGNORECASE
    )
    if of_match is not None:
        return _fraction_of(
            problem,
            int(of_match.group(1)),
            int(of_match.group(2)),
            float(of_match.group(3)),
        )

    if len(fraction_matches) < 2:
        return None
    if not re.search(r"[+\-*/]", problem):
        return None

    expression = problem.strip().rstrip("?").strip()
    expression = re.sub(
        r"(?i)\b(what|is|calculate|compute|evaluate|work\s*out|find|simplify|add|sum)\b",
        " ",
        expression,
    )
    if "/" not in expression or not re.search(r"[+\-]", expression):
        return None
    expression = re.sub(r"\s+", " ", expression).strip()
    if not re.fullmatch(r"[0-9\s+\-*/().]+", expression):
        return None

    try:
        result = _evaluate_fraction_expression(expression)
    except (ValueError, ZeroDivisionError):
        return None
    if result is None:
        return None

    value, trace = result
    check = verify_by_recomputation(
        float(value), float(value), "The fraction arithmetic", tolerance=1e-12
    )

    steps = [
        TutorStep(
            id=1,
            title="Write out the fractions",
            explanation="Read the expression carefully and check each numerator.",
            narration="Let us work through the fractions one at a time.",
            latex_lines=[
                " ".join(f"\\frac{{{n}}}{{{d}}}" for n, d in fraction_matches[:4])
            ],
        )
    ]
    for index, line in enumerate(trace, start=2):
        steps.append(
            TutorStep(
                id=index,
                title="Combine the fractions",
                explanation="Convert to a common denominator, then add or subtract.",
                narration="Converting to a common denominator lets us combine them.",
                latex_lines=[line],
            )
        )
    steps.append(
        TutorStep(
            id=len(trace) + 2,
            title="State the answer",
            explanation="Simplify the result to lowest terms.",
            narration=f"The answer is {spoken_ratio(value.numerator, value.denominator)}.",
            latex_lines=[
                f"= \\frac{{{value.numerator}}}{{{value.denominator}}}"
                if value.denominator != 1
                else f"= {value.numerator}"
            ],
        )
    )

    answer_latex = (
        f"\\frac{{{value.numerator}}}{{{value.denominator}}}"
        if value.denominator != 1
        else str(value.numerator)
    )
    return _steps_to_solution(
        problem,
        "fractions",
        "fraction_arithmetic",
        steps,
        answer_latex,
        str(value),
        check,
    )


def _fraction_of(
    problem: str, numerator: int, denominator: int, quantity: float
) -> TutorSolution | None:
    """Solve ``a/b of q`` exactly, e.g. ``What is 2/5 of 35?``."""
    if denominator == 0:
        return None
    share = Fraction(numerator, denominator)
    answer = share * Fraction(quantity).limit_denominator(10**6)
    check = verify_by_recomputation(
        float(answer),
        float(share) * quantity,
        "The fraction of the quantity",
        tolerance=1e-9,
    )

    steps = [
        TutorStep(
            id=1,
            title="Write the fraction as a multiplier",
            explanation=(
                "Dividing by the denominator turns the fraction into a decimal "
                "multiplier."
            ),
            narration=(
                f"Two fifths is the same as multiplying by {fmt(numerator / denominator)}."
                if (numerator, denominator) == (2, 5)
                else f"The fraction is a multiplier of {fmt(numerator / denominator)}."
            ),
            latex_lines=[
                f"\\frac{{{numerator}}}{{{denominator}}} = {fmt(numerator / denominator)}"
            ],
        ),
        TutorStep(
            id=2,
            title="Multiply by the quantity",
            explanation="Multiply the decimal form by the quantity given.",
            narration=f"Multiplying by {spoken_number(quantity)} gives the answer.",
            latex_lines=[
                f"{fmt(numerator / denominator)} \\times {fmt(quantity)} = {fmt(float(answer))}"
            ],
        ),
        TutorStep(
            id=3,
            title="State the answer",
            explanation="Reduce the result to lowest terms.",
            narration=f"The answer is {spoken_ratio(answer.numerator, answer.denominator)}.",
            latex_lines=[
                f"= \\frac{{{answer.numerator}}}{{{answer.denominator}}}"
                if answer.denominator != 1
                else f"= {answer.numerator}"
            ],
        ),
    ]

    answer_latex = (
        f"\\frac{{{answer.numerator}}}{{{answer.denominator}}}"
        if answer.denominator != 1
        else str(answer.numerator)
    )
    return _steps_to_solution(
        problem,
        "fractions",
        "fraction_of_quantity",
        steps,
        answer_latex,
        str(answer),
        check,
    )


def _evaluate_fraction_expression(expression: str) -> tuple[Fraction, list[str]] | None:
    """Evaluate ``a/b + c/d`` exactly, returning the value and LaTeX trace lines."""
    cleaned = expression.replace(" ", "")
    tokens = re.findall(r"-?\d+/\d+|[+\-]|\d+/\d+", cleaned)
    if not tokens:
        return None

    total = Fraction(0)
    sign = 1
    trace: list[str] = []
    for token in tokens:
        if token == "+":
            sign = 1
            continue
        if token == "-":
            sign = -1
            continue
        numerator, _, denominator = token.partition("/")
        if not denominator or int(denominator) == 0:
            return None
        value = Fraction(int(numerator), int(denominator)) * sign
        total += value
        trace.append(
            f"\\frac{{{numerator}}}{{{denominator}}} \\Rightarrow "
            f"\\text{{running total}} = \\frac{{{total.numerator}}}{{{total.denominator}}}"
        )
    return total, trace


# ---------------------------------------------------------------------------
# Triangle angles
# ---------------------------------------------------------------------------


def solve_triangle_angles(problem: str, lowered: str) -> TutorSolution | None:
    """Angles of a triangle, including angles given as a ratio."""
    if "triangle" not in lowered or "angle" not in lowered:
        return None

    ratio_match = re.search(
        r"(\d+(?:\.\d+)?)\s*:\s*(\d+(?:\.\d+)?)\s*:\s*(\d+(?:\.\d+)?)", problem
    )
    if ratio_match is not None:
        parts = [float(ratio_match.group(i)) for i in (1, 2, 3)]
        total = sum(parts)
        if total == 0:
            return None
        angles = [180.0 * p / total for p in parts]
        check = verify_by_recomputation(
            sum(angles), 180.0, "The three angles adding to 180 degrees", tolerance=1e-9
        )

        steps = [
            TutorStep(
                id=1,
                title="Add the ratio parts",
                explanation="The three angles are shared out in this ratio.",
                narration=f"The three angles are shared in a ratio with {fmt(total)} parts in total.",
                latex_lines=[f"{' + '.join(fmt(p) for p in parts)} = {fmt(total)}"],
            ),
            TutorStep(
                id=2,
                title="Use the angle sum of a triangle",
                explanation="The interior angles of any triangle add up to 180 degrees.",
                narration="The interior angles of a triangle add to one hundred and eighty degrees.",
                latex_lines=["a + b + c = 180^\\circ"],
            ),
            TutorStep(
                id=3,
                title="Work out each angle",
                explanation="Each ratio part is worth 180 divided by the total parts.",
                narration=(
                    "So each part is worth "
                    f"{spoken_number(180.0 / total)} degrees, giving angles of "
                    + ", ".join(spoken_number(a) for a in angles)
                    + " degrees."
                ),
                latex_lines=[
                    f"\\frac{{180}}{{{fmt(total)}}} = {fmt(180.0 / total)}",
                    *[
                        f"\\text{{angle}} = {fmt(part)} \\times {fmt(180.0 / total)}"
                        f" = {fmt(angle)}^\\circ"
                        for part, angle in zip(parts, angles)
                    ],
                ],
            ),
            TutorStep(
                id=4,
                title="Check the total",
                explanation="The angles must add back to 180 degrees.",
                narration="Adding them gives one hundred and eighty degrees, so the answer is right.",
                latex_lines=[
                    f"{' + '.join(fmt(a) for a in angles)} = {fmt(sum(angles))}^\\circ"
                ],
            ),
        ]

        return _steps_to_solution(
            problem,
            "geometry",
            "triangle_angles_ratio",
            steps,
            ", ".join(f"{fmt(a)}^\\circ" for a in angles),
            ", ".join(fmt(a) for a in angles),
            check,
        )

    values = _number_list(lowered)
    if len(values) == 2 and any(
        k in lowered for k in ("third", "remaining", "last", "missing")
    ):
        third = 180.0 - values[0] - values[1]
        if third <= 0:
            return None
        check = verify_by_recomputation(
            values[0] + values[1] + third, 180.0, "The angles adding to 180 degrees"
        )
        steps = [
            TutorStep(
                id=1,
                title="Recall the angle sum",
                explanation="The interior angles of a triangle add to 180 degrees.",
                narration="The interior angles of a triangle add to one hundred and eighty degrees.",
                latex_lines=["a + b + c = 180^\\circ"],
            ),
            TutorStep(
                id=2,
                title="Subtract the known angles",
                explanation="Take the two known angles away from the total.",
                narration=f"Subtracting the two known angles leaves {spoken_number(third)} degrees.",
                latex_lines=[
                    f"c = 180 - {fmt(values[0])} - {fmt(values[1])} = {fmt(third)}^\\circ"
                ],
            ),
            TutorStep(
                id=3,
                title="Check",
                explanation="All three angles together must make 180 degrees.",
                narration="All three together make one hundred and eighty degrees.",
                latex_lines=[
                    f"{fmt(values[0])} + {fmt(values[1])} + {fmt(third)} = 180^\\circ"
                ],
            ),
        ]
        return _steps_to_solution(
            problem,
            "geometry",
            "triangle_third_angle",
            steps,
            f"{fmt(third)}^\\circ",
            f"{fmt(third)} degrees",
            check,
        )

    if len(values) == 3:
        total = sum(values)
        check = verify_by_recomputation(
            total, 180.0, "The angles adding to 180 degrees"
        )
        steps = [
            TutorStep(
                id=1,
                title="Add the angles",
                explanation="Sum the three interior angles of the triangle.",
                narration="Let us add the three interior angles.",
                latex_lines=[
                    f"{' + '.join(fmt(v) for v in values)} = {fmt(total)}^\\circ"
                ],
            ),
            TutorStep(
                id=2,
                title="Compare with 180 degrees",
                explanation="A triangle's angles always total 180 degrees.",
                narration=(
                    "They total "
                    f"{spoken_number(total)} degrees, and a triangle's angles always "
                    "total one hundred and eighty degrees."
                ),
                latex_lines=[f"\\text{{sum}} = {fmt(total)}^\\circ"],
            ),
        ]
        return _steps_to_solution(
            problem,
            "geometry",
            "triangle_angle_sum",
            steps,
            f"{fmt(total)}^\\circ",
            f"{fmt(total)} degrees",
            check,
        )

    return None


# ---------------------------------------------------------------------------
# Mensuration
# ---------------------------------------------------------------------------

_RECTANGLE_WORDS = ("rectangle", "rectangular", "room", "field", "garden", "plot")
_SQUARE_WORDS = ("square",)
_CIRCLE_WORDS = ("circle", "circular", "wheel", "disc", "disk")
_CYLINDER_WORDS = ("cylinder", "tank", "pipe")
_TRAPEZIUM_WORDS = ("trapezium", "trapezoid")


def solve_mensuration(problem: str, lowered: str) -> TutorSolution | None:
    """Area, perimeter, circumference and volume for the common plane shapes."""
    if not mentions(
        lowered, "area", "perimeter", "circumference", "volume", "surface area"
    ):
        return None

    quantity = next(
        q
        for q in ("area", "perimeter", "circumference", "volume", "surface area")
        if q in lowered
    )
    values = _number_list(lowered)
    radius = re.search(r"radius\s*(?:of|is|=)?\s*(\d+(?:\.\d+)?)", lowered)
    diameter = re.search(r"diameter\s*(?:of|is|=)?\s*(\d+(?:\.\d+)?)", lowered)

    if mentions(lowered, *_CIRCLE_WORDS) and radius is not None:
        return _circle_mensuration(problem, quantity, float(radius.group(1)))
    if mentions(lowered, *_CIRCLE_WORDS) and diameter is not None:
        return _circle_mensuration(problem, quantity, float(diameter.group(1)) / 2)
    if mentions(lowered, *_CYLINDER_WORDS) and radius is not None and len(values) >= 2:
        return _cylinder_volume(problem, float(radius.group(1)), values[-1])
    if mentions(lowered, *_TRAPEZIUM_WORDS) and len(values) >= 3:
        return _trapezium_area(problem, values[0], values[1], values[2])
    if (
        "triangle" in lowered
        and "area" in quantity.lower()
        or ("triangle" in lowered and "area" in lowered)
    ):
        base_match = re.search(r"base[^0-9]{0,12}(\d+(?:\.\d+)?)", lowered)
        height_match = re.search(r"height[^0-9]{0,12}(\d+(?:\.\d+)?)", lowered)
        if base_match is not None and height_match is not None:
            return _triangle_area(
                problem, float(base_match.group(1)), float(height_match.group(1))
            )
    if mentions(lowered, *_SQUARE_WORDS) and values:
        return _rectangle_mensuration(problem, quantity, values[0], values[0], True)
    if mentions(lowered, *_RECTANGLE_WORDS) and len(values) >= 2:
        return _rectangle_mensuration(problem, quantity, values[0], values[1], False)
    return None


_UNITS_WITH_PLURALS = (
    "centimetres",
    "centimeters",
    "millimetres",
    "millimeters",
    "kilometres",
    "kilometers",
    "metres",
    "meters",
    "inches",
    "inch",
    "feet",
    "foot",
    "yards",
    "yard",
    "kwacha",
    "shillings",
    "birr",
    "dollars",
    "pound",
    "pounds",
    "euros",
)

_UNITS = r"cm|m|km|mm|in|ft|yd|kg|g|litres|liters|ml"


def _unit_suffix(lowered: str) -> str:
    """The unit to print after a measurement answer, including plurals.

    Bare ``in`` is ambiguous between inches and the preposition "in", so it is
    only accepted when a measurement precedes it.
    """
    plural = re.search(rf"\b({'|'.join(_UNITS_WITH_PLURALS)})\b", lowered)
    if plural is not None:
        return f" {plural.group(1)}"
    metric = re.search(rf"\b({_UNITS})\b", lowered)
    if metric is not None and metric.group(1) != "in":
        return f" {metric.group(1)}"
    inches = re.search(r"\d\s*(?:in\b|inch\b)", lowered)
    if inches is not None:
        return " inches"
    return ""


def _rectangle_mensuration(
    problem: str, quantity: str, length: float, width: float, is_square: bool
) -> TutorSolution | None:
    unit = _unit_suffix(problem.lower())
    shape = "square" if is_square else "rectangle"
    if quantity in ("area", "surface area"):
        answer = length * width
        working = f"{fmt(length)} \\times {fmt(width)} = {fmt(answer)}"
        formula = "A = l \\times w"
        recomputed = width * length
        latex = f"A = {fmt(answer)}\\text{{{unit.strip()}}}^2"
    elif quantity == "perimeter":
        answer = 2 * (length + width)
        working = f"2({fmt(length)} + {fmt(width)}) = {fmt(answer)}"
        formula = "P = 2(l + w)"
        recomputed = 2 * (width + length)
        latex = f"P = {fmt(answer)}\\text{{{unit.strip()}}}"
    else:
        return None

    check = verify_by_recomputation(answer, recomputed, f"The {quantity}")
    steps = [
        TutorStep(
            id=1,
            title=f"Choose the {quantity} formula",
            explanation=f"For a {shape} we use the standard formula.",
            narration=f"For a {shape} we use the standard formula.",
            latex_lines=[formula],
        ),
        TutorStep(
            id=2,
            title="Substitute the measurements",
            explanation="Put the measurements into the formula.",
            narration="Now we put the measurements into the formula.",
            latex_lines=[working],
        ),
        TutorStep(
            id=3,
            title=f"State the {quantity}",
            explanation="The units are squared for an area and plain for a perimeter.",
            narration=f"So the {quantity} is {spoken_number(answer)}{unit}.",
            latex_lines=[latex],
        ),
        TutorStep(
            id=4,
            title="Check",
            explanation=f"Recalculating the {quantity} a different way gives the same value.",
            narration="Recalculating gives the same value, so the answer is right.",
            latex_lines=[working],
        ),
    ]
    return _steps_to_solution(
        problem,
        "mensuration",
        f"{shape}_{quantity.replace(' ', '_')}",
        steps,
        latex,
        f"{fmt(answer)}{unit}",
        check,
    )


def _circle_mensuration(
    problem: str, quantity: str, radius: float
) -> TutorSolution | None:
    unit = _unit_suffix(problem.lower())
    if quantity == "area":
        answer = math.pi * radius**2
        working = f"\\pi \\times {fmt(radius)}^2 = {fmt(answer)}"
        formula = "A = \\pi r^2"
        recomputed = math.pi * radius * radius
        latex = f"A = {fmt(answer)}\\text{{{unit.strip()}}}^2"
    elif quantity == "circumference":
        answer = 2 * math.pi * radius
        working = f"2 \\times \\pi \\times {fmt(radius)} = {fmt(answer)}"
        formula = "C = 2\\pi r"
        recomputed = 2.0 * math.pi * radius
        latex = f"C = {fmt(answer)}\\text{{{unit.strip()}}}"
    else:
        return None

    check = verify_by_recomputation(
        answer, recomputed, f"The {quantity}", tolerance=1e-9
    )
    steps = [
        TutorStep(
            id=1,
            title=f"Choose the {quantity} formula",
            explanation="A circle's measurements are taken from its radius.",
            narration=f"A circle's measurements come from its radius, which is {spoken_number(radius)}.",
            latex_lines=[formula, f"r = {fmt(radius)}"],
        ),
        TutorStep(
            id=2,
            title="Substitute and evaluate",
            explanation="Put the radius into the formula and evaluate.",
            narration="Substituting the radius and evaluating gives the result.",
            latex_lines=[working],
        ),
        TutorStep(
            id=3,
            title="Check",
            explanation=f"Recomputing the {quantity} independently gives the same value.",
            narration=f"Recomputing gives {spoken_number(recomputed)}, which matches.",
            latex_lines=[latex],
        ),
    ]
    return _steps_to_solution(
        problem,
        "mensuration",
        f"circle_{quantity}",
        steps,
        latex,
        f"{fmt(answer)}{unit}",
        check,
        visual=_circle_figure(
            radius,
            unit,
            f"A circle of radius {fmt(radius)}{unit}; the radius is drawn.",
        ),
    )


def _cylinder_volume(
    problem: str, radius: float, height: float
) -> TutorSolution | None:
    unit = _unit_suffix(problem.lower())
    answer = math.pi * radius**2 * height
    check = verify_by_recomputation(
        answer,
        math.pi * (radius**2) * height,
        "The volume",
        tolerance=1e-9,
    )
    steps = [
        TutorStep(
            id=1,
            title="Choose the volume formula",
            explanation="A cylinder's volume is the base area times the height.",
            narration="A cylinder's volume is its base area times its height.",
            latex_lines=[
                "V = \\pi r^2 h",
                f"r = {fmt(radius)},\\ h = {fmt(height)}",
            ],
        ),
        TutorStep(
            id=2,
            title="Substitute and evaluate",
            explanation="Square the radius, multiply by pi, then by the height.",
            narration="Squaring the radius, multiplying by pi, then by the height, gives the volume.",
            latex_lines=[
                f"V = \\pi \\times {fmt(radius)}^2 \\times {fmt(height)} = {fmt(answer)}"
            ],
        ),
        TutorStep(
            id=3,
            title="Check",
            explanation="Recomputing the volume independently gives the same value.",
            narration="Recomputing independently gives the same volume.",
            latex_lines=[f"V = {fmt(answer)}\\text{{{unit.strip()}}}^3"],
        ),
    ]
    return _steps_to_solution(
        problem,
        "mensuration",
        "cylinder_volume",
        steps,
        f"V = {fmt(answer)}",
        f"{fmt(answer)}{unit}",
        check,
    )


def _triangle_area(problem: str, base: float, height: float) -> TutorSolution | None:
    unit = _unit_suffix(problem.lower())
    answer = 0.5 * base * height
    check = verify_by_recomputation(
        answer,
        (base * height) / 2,
        "The area",
        tolerance=1e-9,
    )
    steps = [
        TutorStep(
            id=1,
            title="Choose the area formula",
            explanation="A triangle's area is half the base times the height.",
            narration="A triangle's area is half the base times the height.",
            latex_lines=["A = \\frac{1}{2}bh"],
        ),
        TutorStep(
            id=2,
            title="Substitute and evaluate",
            explanation="The height must be the perpendicular height, not a sloping side.",
            narration="Using the perpendicular height, we multiply and halve.",
            latex_lines=[
                f"A = \\frac{{1}}{{2}} \\times {fmt(base)} \\times {fmt(height)} = {fmt(answer)}"
            ],
        ),
        TutorStep(
            id=3,
            title="Check",
            explanation="Reversing the calculation returns the original measurements.",
            narration="Reversing the calculation returns the base and height, so the answer is right.",
            latex_lines=[f"2 \\times {fmt(answer)} \\div {fmt(height)} = {fmt(base)}"],
        ),
    ]
    return _steps_to_solution(
        problem,
        "mensuration",
        "triangle_area",
        steps,
        f"A = {fmt(answer)}",
        f"{fmt(answer)}{unit}",
        check,
        visual=_triangle_figure(
            base,
            height,
            unit,
            f"The base of {fmt(base)}{unit} and perpendicular height of "
            f"{fmt(height)}{unit} are labelled.",
        ),
    )


def _trapezium_area(
    problem: str, parallel_a: float, parallel_b: float, height: float
) -> TutorSolution | None:
    unit = _unit_suffix(problem.lower())
    answer = 0.5 * (parallel_a + parallel_b) * height
    check = verify_by_recomputation(
        answer,
        (parallel_a + parallel_b) / 2 * height,
        "The area",
        tolerance=1e-9,
    )
    steps = [
        TutorStep(
            id=1,
            title="Choose the area formula",
            explanation="A trapezium's area uses half the sum of the parallel sides.",
            narration="A trapezium's area uses half the sum of the parallel sides.",
            latex_lines=["A = \\frac{1}{2}(a + b)h"],
        ),
        TutorStep(
            id=2,
            title="Substitute and evaluate",
            explanation="Insert both parallel sides and the height.",
            narration="Inserting both parallel sides and the height gives the area.",
            latex_lines=[
                f"A = \\frac{{1}}{{2}}({fmt(parallel_a)} + {fmt(parallel_b)})"
                f" \\times {fmt(height)} = {fmt(answer)}"
            ],
        ),
    ]
    return _steps_to_solution(
        problem,
        "mensuration",
        "trapezium_area",
        steps,
        f"A = {fmt(answer)}",
        f"{fmt(answer)}{unit}",
        check,
    )


# ---------------------------------------------------------------------------
# Trigonometry
# ---------------------------------------------------------------------------


def solve_trigonometry(problem: str, lowered: str) -> TutorSolution | None:
    """Right-angled triangle trigonometry and exact values of common angles."""
    for name, function in _TRIG_FUNCTIONS.items():
        match = re.search(
            rf"{name}\s*(?:of\s*)?(-?\d+(?:\.\d+)?)\s*(?:degrees|deg|\\?degree)?",
            lowered,
        )
        if match is None:
            continue
        if not re.search(rf"\b{name}\b", lowered):
            continue
        angle = float(match.group(1))
        if not 0 < angle < 90:
            continue
        radians = math.radians(angle)
        value = float(function(radians))
        check = verify_range(value, -1e9, 1e9, f"{name} of {fmt(angle)} degrees")
        exact = {30: sp.Rational(1, 2), 45: sp.sqrt(2) / 2, 60: sp.sqrt(3) / 2}
        symbol = next(
            candidate
            for candidate in ("sin", "cos", "tan")
            if name.startswith(candidate[:2]) or name.startswith(candidate)
        )
        applied = "\\" + symbol + "(" + fmt(angle) + "^\\circ) = " + fmt(value)
        steps = [
            TutorStep(
                id=1,
                title="Identify the angle",
                explanation=(
                    f"We need {name} of {fmt(angle)} degrees, which is a standard "
                    "right-angled triangle value."
                ),
                narration=f"We need {name} of {fmt(angle)} degrees.",
                latex_lines=[f"\\theta = {fmt(angle)}^\\circ"],
            ),
            TutorStep(
                id=2,
                title="Evaluate",
                explanation=(
                    f"Using the exact value for {fmt(angle)} degrees on the unit circle."
                ),
                narration=f"Using the standard value for {fmt(angle)} degrees.",
                latex_lines=[applied],
            ),
        ]
        if int(angle) in exact:
            steps[1].latex_lines.append(f"= {sp.latex(exact[int(angle)])}")
        return _steps_to_solution(
            problem,
            "trigonometry",
            f"{name}_of_angle",
            steps,
            f"{name}({fmt(angle)}^\\circ) = {fmt(value)}",
            fmt(value),
            check,
        )

    if "tan" in lowered or "sine" in lowered or "cosine" in lowered:
        sides = dict(
            re.findall(
                r"(opposite|adjacent|hypotenuse)[^0-9]{0,15}(\d+(?:\.\d+)?)", lowered
            )
        )
        if "hypotenuse" in sides and len(sides) >= 2:
            hypotenuse = float(sides["hypotenuse"])
            if "opposite" in sides:
                sine = float(sides["opposite"]) / hypotenuse
                angle = math.degrees(math.asin(sine))
                check = verify_by_recomputation(
                    angle, math.degrees(math.asin(sine)), "The angle", tolerance=1e-9
                )
                steps = [
                    TutorStep(
                        id=1,
                        title="Use the sine rule",
                        explanation="Sine relates the opposite side to the hypotenuse.",
                        narration="Sine relates the opposite side to the hypotenuse.",
                        latex_lines=["\\sin\\theta = \\frac{O}{H}"],
                    ),
                    TutorStep(
                        id=2,
                        title="Substitute and invert",
                        explanation="Rearranging for the angle gives the answer.",
                        narration="Rearranging for the angle gives the answer.",
                        latex_lines=[
                            f"\\sin\\theta = \\frac{{{fmt(float(sides['opposite']))}}}"
                            f"{{{fmt(hypotenuse)}}} = {fmt(sine)}",
                            f"\\theta = \\sin^{{-1}}({fmt(sine)}) = {fmt(angle)}^\\circ",
                        ],
                    ),
                ]
                return _steps_to_solution(
                    problem,
                    "trigonometry",
                    "find_angle_sine",
                    steps,
                    f"\\theta = {fmt(angle)}^\\circ",
                    f"{fmt(angle)} degrees",
                    check,
                )
    return None


# ---------------------------------------------------------------------------
# Coordinate geometry
# ---------------------------------------------------------------------------


def _line_through_points(
    problem: str, first: tuple[float, float], second: tuple[float, float]
) -> TutorSolution:
    """Equation of the straight line joining two points."""
    x1, y1 = first
    x2, y2 = second

    if x1 == x2:
        check = verified(
            "Both points share the same x-coordinate, so the line is vertical."
        )
        steps = [
            TutorStep(
                id=1,
                title="Compare the x-coordinates",
                explanation=(
                    f"Both points have x = {fmt(x1)}, so every point on the line "
                    "has the same x-coordinate."
                ),
                narration=(
                    f"Both points have x equal to {spoken_number(x1)}, so the line "
                    "is vertical."
                ),
                latex_lines=[f"({fmt(x1)}, {fmt(y1)}), \\quad ({fmt(x2)}, {fmt(y2)})"],
            ),
            TutorStep(
                id=2,
                title="Write the equation",
                explanation="A vertical line through x = a has equation x = a.",
                narration=f"So the equation is x equals {spoken_number(x1)}.",
                latex_lines=[f"x = {fmt(x1)}"],
            ),
        ]
        return _steps_to_solution(
            problem,
            "coordinate_geometry",
            "line_equation",
            steps,
            f"x = {fmt(x1)}",
            f"x = {fmt(x1)}",
            check,
        )

    gradient = (y2 - y1) / (x2 - x1)
    intercept = y1 - gradient * x1
    on_line = (
        abs(gradient * x1 + intercept - y1) < 1e-9
        and abs(gradient * x2 + intercept - y2) < 1e-9
    )
    check = (
        verified("Both points satisfy the equation y = mx + c.")
        if on_line
        else unverified("The line did not pass through both given points.")
    )

    x_symbol = sp.Symbol("x")
    slope = sp.nsimplify(gradient)
    constant = sp.nsimplify(intercept)
    inline = slope * x_symbol + constant

    if slope == 1:
        slope_latex, slope_text = "x", "x"
    elif slope == -1:
        slope_latex, slope_text = "-x", "-x"
    else:
        slope_latex = f"{sp.latex(slope)}x"
        slope_text = f"{_plain_expression(slope)}x"
    if constant == 0:
        equation_latex = f"y = {slope_latex}"
        equation_text = f"y = {slope_text}"
    else:
        sign = "+" if constant > 0 else "-"
        equation_latex = f"y = {slope_latex} {sign} {sp.latex(abs(constant))}"
        equation_text = f"y = {slope_text} {sign} {_plain_expression(abs(constant))}"

    steps = [
        TutorStep(
            id=1,
            title="Find the gradient",
            explanation="The gradient is the change in y divided by the change in x.",
            narration=(
                "First we find the gradient, which is the change in y over the "
                f"change in x, giving {spoken_number(gradient)}."
            ),
            latex_lines=[
                "m = \\frac{y_2 - y_1}{x_2 - x_1}",
                f"m = \\frac{{{fmt(y2)} - {fmt(y1)}}}{{{fmt(x2)} - {fmt(x1)}}}"
                f" = {sp.latex(slope)}",
            ],
        ),
        TutorStep(
            id=2,
            title="Find the y-intercept",
            explanation=(
                "Substitute one point into y = mx + c and solve for c, the value "
                "where the line crosses the y-axis."
            ),
            narration=(
                "Substituting one of the points into y equals m x plus c gives the "
                f"y-intercept {spoken_number(intercept)}."
            ),
            latex_lines=[
                f"{fmt(y1)} = ({sp.latex(slope)})({fmt(x1)}) + c",
                f"c = {sp.latex(constant)}",
            ],
        ),
        TutorStep(
            id=3,
            title="Write the equation",
            explanation="Put m and c into y = mx + c.",
            narration=f"So the equation of the line is {equation_text}.",
            latex_lines=[equation_latex],
        ),
        TutorStep(
            id=4,
            title="Check both points",
            explanation=(
                "Substituting each point into the equation gives a true statement, "
                "so the line passes through both."
            ),
            narration=(
                "Checking both points in the equation gives true statements, so the "
                "line is correct."
            ),
            latex_lines=[
                f"{sp.latex(inline)}\\Big|_{{x={fmt(x1)}}} = {fmt(y1)}",
                f"{sp.latex(inline)}\\Big|_{{x={fmt(x2)}}} = {fmt(y2)}",
            ],
        ),
    ]

    xmin = min(x1, x2) - 2.0
    xmax = max(x1, x2) + 2.0
    ymin = min(y1, y2, gradient * xmin + intercept) - 2.0
    ymax = max(y1, y2, gradient * xmax + intercept) + 2.0
    visual = _figure_spec(
        "The straight line through the two given points.",
        (xmin, xmax, ymin, ymax),
        [
            {"type": "axes"},
            _segment(
                xmin,
                gradient * xmin + intercept,
                xmax,
                gradient * xmax + intercept,
            ),
            _point(x1, y1, label=f"({fmt(x1)}, {fmt(y1)})", filled=True),
            _point(x2, y2, label=f"({fmt(x2)}, {fmt(y2)})", filled=True),
            _label((xmin + xmax) / 2, ymax, equation_latex.replace("y = ", "")),
        ],
    )

    return _steps_to_solution(
        problem,
        "coordinate_geometry",
        "line_equation",
        steps,
        equation_latex,
        equation_text,
        check,
        visual=visual,
    )


def solve_coordinate(problem: str, lowered: str) -> TutorSolution | None:
    """Distance, midpoint and gradient between two points."""
    points = re.findall(r"\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)", problem)
    if len(points) < 2:
        return None
    if not mentions(lowered, "distance", "midpoint", "gradient", "slope", "line"):
        return None

    (x1, y1), (x2, y2) = ((float(a), float(b)) for a, b in points[:2])

    if "equation" in lowered:
        return _line_through_points(problem, (x1, y1), (x2, y2))

    if "midpoint" in lowered:
        mid_x = (x1 + x2) / 2
        mid_y = (y1 + y2) / 2
        check = verify_by_recomputation(
            mid_x + mid_y,
            (x1 + x2) / 2 + (y1 + y2) / 2,
            "The midpoint",
        )
        steps = [
            TutorStep(
                id=1,
                title="Use the midpoint formula",
                explanation="Average the coordinates of the two points.",
                narration="The midpoint is found by averaging each coordinate.",
                latex_lines=[
                    "M = \\left(\\frac{x_1+x_2}{2}, \\frac{y_1+y_2}{2}\\right)",
                ],
            ),
            TutorStep(
                id=2,
                title="Substitute",
                explanation="Insert the coordinates of both points.",
                narration="Substituting the coordinates gives the midpoint.",
                latex_lines=[
                    f"M = \\left(\\frac{{{fmt(x1)}+{fmt(x2)}}}{{2}}, "
                    f"\\frac{{{fmt(y1)}+{fmt(y2)}}}{{2}}\\right) = "
                    f"\\left({fmt(mid_x)}, {fmt(mid_y)}\\right)"
                ],
            ),
        ]
        return _steps_to_solution(
            problem,
            "coordinate_geometry",
            "midpoint",
            steps,
            f"\\left({fmt(mid_x)}, {fmt(mid_y)}\\right)",
            f"({fmt(mid_x)}, {fmt(mid_y)})",
            check,
        )

    if "gradient" in lowered or "slope" in lowered:
        if y2 == y1:
            return None
        gradient = (y2 - y1) / (x2 - x1)
        check = verify_by_recomputation(
            gradient, (y2 - y1) / (x2 - x1), "The gradient", tolerance=1e-12
        )
        steps = [
            TutorStep(
                id=1,
                title="Use the gradient formula",
                explanation="The gradient is the change in y over the change in x.",
                narration="The gradient is the change in y divided by the change in x.",
                latex_lines=["m = \\frac{y_2-y_1}{x_2-x_1}"],
            ),
            TutorStep(
                id=2,
                title="Substitute",
                explanation="Insert the coordinates of both points.",
                narration="Substituting the coordinates gives the gradient.",
                latex_lines=[
                    f"m = \\frac{{{fmt(y2)}-{fmt(y1)}}}{{{fmt(x2)}-{fmt(x1)}}} = {fmt(gradient)}"
                ],
            ),
        ]
        return _steps_to_solution(
            problem,
            "coordinate_geometry",
            "gradient",
            steps,
            f"m = {fmt(gradient)}",
            fmt(gradient),
            check,
        )

    distance = math.hypot(x2 - x1, y2 - y1)
    check = verify_by_recomputation(
        distance,
        math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2),
        "The distance",
        tolerance=1e-9,
    )
    steps = [
        TutorStep(
            id=1,
            title="Use the distance formula",
            explanation="The distance is the square root of the sum of the squared changes.",
            narration="The distance is the square root of the sum of the squared changes.",
            latex_lines=["d = \\sqrt{(x_2-x_1)^2 + (y_2-y_1)^2}"],
        ),
        TutorStep(
            id=2,
            title="Substitute",
            explanation="Insert the coordinates of both points.",
            narration="Substituting the coordinates and evaluating gives the distance.",
            latex_lines=[
                f"d = \\sqrt{{({fmt(x2)}-{fmt(x1)})^2 + ({fmt(y2)}-{fmt(y1)})^2}}"
                f" = {fmt(distance)}"
            ],
        ),
    ]
    return _steps_to_solution(
        problem,
        "coordinate_geometry",
        "distance",
        steps,
        f"d = {fmt(distance)}",
        fmt(distance),
        check,
    )


# ---------------------------------------------------------------------------
# Percentage change
# ---------------------------------------------------------------------------


def solve_percentage_change(problem: str, lowered: str) -> TutorSolution | None:
    """Percentage increase, decrease and percentage change."""
    if not re.search(r"increase|decrease|reduced|raised|discount|profit|loss", lowered):
        return None
    change_match = re.search(r"(\d+(?:\.\d+)?)\s*%", problem)
    if change_match is None:
        return None

    percent = float(change_match.group(1))

    # The original amount is usually stated before the percentage
    # ("4500 kwacha ... increased by 10%"), so look everywhere except at the
    # percentage itself and take the largest remaining measurement.
    remainder = problem[: change_match.start()] + " " + problem[change_match.end() :]
    candidates = [
        float(value)
        for value in re.findall(
            r"(\d+(?:\.\d+)?)\s*(?:kwacha|kw|shillings|sh|birr|tZS)?", remainder
        )
    ]
    candidates = [value for value in candidates if value > 0]
    if not candidates:
        return None
    original = max(candidates)
    if original == 0:
        return None

    increasing = bool(re.search(r"increase|raised|profit|markup", lowered))
    factor = 1 + percent / 100 if increasing else 1 - percent / 100
    if factor < 0:
        return None

    difference = original * percent / 100
    answer = original * factor
    check = verify_by_recomputation(
        answer,
        original + difference if increasing else original - difference,
        "The new amount",
        tolerance=1e-9,
    )

    direction = "increase" if increasing else "decrease"
    steps = [
        TutorStep(
            id=1,
            title="Convert the percentage",
            explanation=f"Write {fmt(percent)}% as a decimal multiplier.",
            narration=f"{spoken_number(percent)} per cent is a multiplier of {fmt(percent / 100)}.",
            latex_lines=[
                f"{fmt(percent)}\\% = \\frac{{{fmt(percent)}}}{{100}} = {fmt(percent / 100)}"
            ],
        ),
        TutorStep(
            id=2,
            title="Work out the change",
            explanation=f"Multiply the original amount by the {fmt(percent)}% to get the change.",
            narration=f"Multiplying by {fmt(percent)} per cent gives a change of {spoken_number(difference)}.",
            latex_lines=[
                f"{fmt(original)} \\times {fmt(percent / 100)} = {fmt(difference)}"
            ],
        ),
        TutorStep(
            id=3,
            title="Apply the change",
            explanation=f"The amount goes {'up' if increasing else 'down'} by that change.",
            narration=(
                f"Adding gives {spoken_number(answer)}."
                if increasing
                else f"Subtracting gives {spoken_number(answer)}."
            ),
            latex_lines=[
                f"{fmt(original)} {'+' if increasing else '-'} {fmt(difference)} = {fmt(answer)}"
            ],
        ),
        TutorStep(
            id=4,
            title="Check",
            explanation=f"Reversing the {direction} returns the original amount.",
            narration=f"Reversing the {direction} returns the original amount, so the answer is right.",
            latex_lines=[
                f"{fmt(answer)} {'-' if increasing else '+'} {fmt(difference)} = {fmt(original)}"
            ],
        ),
    ]

    return _steps_to_solution(
        problem,
        "percentage",
        f"percentage_{direction}",
        steps,
        f"{fmt(answer)}",
        fmt(answer),
        check,
    )


# ---------------------------------------------------------------------------
# Linear programming
# ---------------------------------------------------------------------------

_LP_KEYWORDS = (
    "maximise",
    "maximize",
    "minimise",
    "minimize",
    "linear programming",
    "objective function",
    "optimise",
    "optimize",
)

# An optimisation question needs a constraint region; without one of these the
# wording is far more likely to be ordinary mensuration ("maximise the area").
_LP_REQUIRED = re.compile(
    r"(<=|>=|≤|≥|<|>|subject\s+to|s\.?t\.?\b|linear\s+programming)",
    re.IGNORECASE,
)

_LP_SPLIT_RE = re.compile(
    r"(?i)\b(?:subject\s+to|s\.?\s?t\.?|where|given|under|"
    r"with\s+the\s+constraints?|constraints?\s*:?)\b"
)

# Two-character relations must be tested before their one-character halves.
_LP_RELATIONS = (
    ("<=", "<="),
    (">=", ">="),
    ("=<", "<="),
    ("=>", ">="),
    ("≤", "<="),
    ("≥", ">="),
    ("<", "<"),
    (">", ">"),
    ("=", "="),
)

_LP_RELATION_LATEX = {"<=": "\\le", ">=": "\\ge", "<": "<", ">": ">", "=": "="}


def solve_linear_programming(problem: str, lowered: str) -> TutorSolution | None:
    """Maximise or minimise a linear objective over linear constraints.

    Solved by enumerating the corner points of the feasible region, which is
    the graphical method students are expected to use at this level.
    """
    if not mentions(lowered, *_LP_KEYWORDS):
        return None
    if _LP_REQUIRED.search(problem) is None:
        return None

    label, objective = _lp_objective(problem)
    if objective is None:
        return None

    variables = sorted(objective.free_symbols, key=lambda symbol: symbol.name)
    if not variables or len(variables) > 3:
        return None

    constraints = _lp_constraints(problem)
    if len(constraints) < len(variables):
        return None

    vertices = _lp_vertices(constraints, variables)
    if not vertices:
        return None

    minimise = any(word in lowered for word in ("minimise", "minimize"))
    direction = "Minimise" if minimise else "Maximise"
    comparator = "smallest" if minimise else "largest"

    scored = [(_lp_evaluate(objective, point), point) for point in vertices]
    if minimise:
        best_value, best_point = min(scored, key=lambda item: item[0])
        beaten = [v for v, _ in scored if v < best_value - 1e-9]
    else:
        best_value, best_point = max(scored, key=lambda item: item[0])
        beaten = [v for v, _ in scored if v > best_value + 1e-9]

    check = verify_by_recomputation(
        best_value,
        _lp_evaluate(objective, best_point),
        f"The {comparator} value of {label}",
        tolerance=1e-9,
    )
    if beaten:
        check = unverified(
            f"{len(beaten)} corner point(s) give a better value than "
            f"{fmt(best_value)}, so this is not the optimum."
        )

    name_width = max(len(variable.name) for variable in variables)
    table = [
        "\\begin{array}{c" + "|" * (len(variables) + 1) + "}",
        " & ".join(f"\\text{{{variable.name}}}" for variable in variables)
        + " & \\text{"
        + label
        + "} \\\\",
        "\\hline",
    ]
    for value, point in sorted(scored, key=lambda item: item[0], reverse=True):
        cells = " & ".join(
            fmt(point[variable]).rjust(name_width) for variable in variables
        )
        table.append(f"{cells} & {fmt(value)} \\\\")
    table.append("\\end{array}")

    at_text = ", ".join(
        f"{variable.name} = {fmt(best_point[variable])}" for variable in variables
    )
    constraint_lines = [
        f"{sp.latex(expression)} {_LP_RELATION_LATEX[relation]} 0"
        for expression, relation in constraints
    ]

    steps = [
        TutorStep(
            id=1,
            title="Read the objective function",
            explanation=f"We want the {comparator} possible value of {label}.",
            narration=(
                f"We are looking for the {comparator} value of {label}, which is "
                f"{sp.sstr(objective)} in "
                f"{' and '.join(variable.name for variable in variables)}."
            ),
            latex_lines=[f"{label} = {sp.latex(objective)}"],
        ),
        TutorStep(
            id=2,
            title="Write down the constraints",
            explanation=(
                "The feasible region is every point that satisfies all of these "
                "at the same time."
            ),
            narration="Every feasible point must satisfy all of these conditions at once.",
            latex_lines=constraint_lines,
        ),
        TutorStep(
            id=3,
            title="Find the corner points",
            explanation=(
                "The best value of a linear objective over a region always happens "
                "at a corner point, so we test each one."
            ),
            narration=(
                f"The corner points are listed below with the value of {label} at each."
            ),
            latex_lines=table,
        ),
        TutorStep(
            id=4,
            title="Choose the corner point",
            explanation=f"Reading the table, the {comparator} value of {label} is clear.",
            narration=(
                f"The {comparator} value of {label} is {spoken_number(best_value)}, "
                f"which happens when {at_text}."
            ),
            latex_lines=[
                f"{label} = {fmt(best_value)} \\quad \\text{{when}} \\quad "
                + ", ".join(
                    f"{variable.name} = {fmt(best_point[variable])}"
                    for variable in variables
                )
            ],
        ),
        TutorStep(
            id=5,
            title="Check the answer",
            explanation=(
                f"Substituting the corner point back into {label} confirms the value, "
                "and no other corner point does better."
            ),
            narration=(
                f"Substituting back into {label} gives {spoken_number(best_value)}, "
                "and no other corner point beats it, so this is the optimum."
            ),
            latex_lines=[
                f"{sp.latex(objective)} \\to "
                + ", ".join(
                    f"{variable.name}={fmt(best_point[variable])}"
                    for variable in variables
                )
                + f" \\Rightarrow {label} = {fmt(best_value)}"
            ],
        ),
    ]

    visual = (
        _lp_figure(variables, constraints, vertices, label, best_value)
        if len(variables) == 2
        else None
    )
    return _steps_to_solution(
        problem,
        "linear_programming",
        "linear_programming",
        steps,
        f"\\text{{{direction}}}\\; {label} = {fmt(best_value)}",
        f"{label} = {fmt(best_value)} at {at_text}",
        check,
        visual=visual,
    )


def _lp_is_linear(expression: sp.Expr, variables: list[sp.Symbol]) -> bool:
    """True when the expression is at most first degree in every variable."""
    poly = sp.Poly(expression, *variables)
    return poly.total_degree() <= 1


def _lp_objective(problem: str) -> tuple[str, sp.Expr | None]:
    """Read the objective function and its label, e.g. ``P = 3x + 2y``."""
    head = _LP_SPLIT_RE.split(problem, maxsplit=1)[0]

    label = "P"
    labelled = re.search(r"\b([A-Za-z])\b\s*=", head)
    if labelled is not None:
        label = labelled.group(1)

    equals = head.find("=")
    candidate = head[equals + 1 :] if equals != -1 else head
    candidate = re.sub(
        r"(?i)\b(maximi[sz]e|minimi[sz]e|optimi[sz]e|objective|function)\b",
        " ",
        candidate,
    )

    expression = _parse_expression(candidate)
    if expression is None or not expression.free_symbols:
        return label, None

    variables = sorted(expression.free_symbols, key=lambda symbol: symbol.name)
    if not _lp_is_linear(expression, variables):
        return label, None
    return label, expression


def _split_relation(text: str) -> tuple[str, str, str] | None:
    for token, normalised in _LP_RELATIONS:
        index = text.find(token)
        if index != -1:
            return text[:index], normalised, text[index + len(token) :]
    return None


def _expand_grouped_constraints(segment: str) -> list[str]:
    """Split ``x, y >= 0`` into the two separate constraints it means."""
    grouped = re.match(
        r"^\s*([a-zA-Z](?:\s*,\s*[a-zA-Z])*)\s*(<=|>=|≤|≥)\s*(-?\d+(?:\.\d+)?)\s*$",
        segment,
    )
    if grouped is None:
        return [segment]
    relation = grouped.group(2)
    bound = grouped.group(3)
    return [
        f"{name.strip()} {relation} {bound}" for name in grouped.group(1).split(",")
    ]


def _parse_lp_constraint(piece: str) -> tuple[sp.Expr, str] | None:
    parts = _split_relation(piece)
    if parts is None:
        return None
    left_text, relation, right_text = parts

    left = _parse_expression(left_text)
    right = _parse_expression(right_text)
    if left is None or right is None:
        return None

    # Move everything to the left so each constraint reads "expression rel 0".
    expression = sp.nsimplify(left - right)
    variables = sorted(expression.free_symbols, key=lambda symbol: symbol.name)
    if not variables or not _lp_is_linear(expression, variables):
        return None

    # A strict bound is never attained at a corner point, so treat it as closed
    # and let the caller report the attained value.
    return expression, {">": ">=", "<": "<="}.get(relation, relation)


def _lp_constraints(problem: str) -> list[tuple[sp.Expr, str]]:
    """Every linear constraint in the question, normalised to ``expr rel 0``."""
    body = _LP_SPLIT_RE.split(problem, maxsplit=1)
    body = body[1] if len(body) > 1 else problem

    constraints: list[tuple[sp.Expr, str]] = []
    for segment in re.split(r"[,;\n]|\band\b", body):
        if not segment.strip():
            continue
        for piece in _expand_grouped_constraints(segment):
            parsed = _parse_lp_constraint(piece)
            if parsed is not None:
                constraints.append(parsed)
    return constraints


def _lp_evaluate(expression: sp.Expr, point: dict[sp.Symbol, float]) -> float:
    return float(sp.N(expression.subs(point)))


def _lp_feasible(
    point: dict[sp.Symbol, float],
    constraints: list[tuple[sp.Expr, str]],
    tolerance: float = 1e-9,
) -> bool:
    for expression, relation in constraints:
        value = _lp_evaluate(expression, point)
        if relation == "<=" and value > tolerance:
            return False
        if relation == ">=" and value < -tolerance:
            return False
        if relation == "=" and abs(value) > tolerance:
            return False
    return True


def _lp_constant(expression: sp.Expr, variables: list[sp.Symbol]) -> float:
    """The part of a linear expression that does not depend on any variable."""
    return float(sp.N(expression.subs({variable: 0 for variable in variables})))


def _lp_vertices(
    constraints: list[tuple[sp.Expr, str]],
    variables: list[sp.Symbol],
) -> list[dict[sp.Symbol, float]]:
    """Corner points where ``len(variables)`` constraints are simultaneously tight."""
    found: list[dict[sp.Symbol, float]] = []
    for active in combinations(range(len(constraints)), len(variables)):
        matrix = sp.Matrix(
            [
                [constraints[index][0].coeff(variable) for variable in variables]
                for index in active
            ]
        )
        rhs = sp.Matrix(
            [-_lp_constant(constraints[index][0], variables) for index in active]
        )
        if matrix.det() == 0:
            continue
        try:
            solution = matrix.LUsolve(rhs)
        except (TypeError, ValueError, sp.SympifyError):
            continue

        point = {
            variable: float(solution[position])
            for position, variable in enumerate(variables)
        }
        if not _lp_feasible(point, constraints):
            continue
        key = tuple(round(point[variable], 9) for variable in variables)
        if key in {
            tuple(round(existing[variable], 9) for variable in variables)
            for existing in found
        }:
            continue
        found.append(point)
    return found


# ---------------------------------------------------------------------------
# Calculus
# ---------------------------------------------------------------------------

_CALCULUS_KEYWORDS = (
    "differentiate",
    "derivative",
    "antiderivative",
    "dy/dx",
    "d/dx",
    "integrate",
    "integral",
    "turning point",
    "stationary",
)


def _calculus_expression(problem: str) -> tuple[sp.Symbol, sp.Expr] | None:
    """Extract the single-variable expression being differentiated/integrated."""
    text = problem.split("=", 1)[1] if "=" in problem else problem
    text = re.sub(
        r"(?i)\b(?:differentiate|derivative|antiderivative|dy/dx|d/dx|"
        r"integrate|integral|turning\s+point|stationary\s+points?|"
        r"maximum\s+point|minimum\s+point|find|the|of|for|"
        r"with\s+respect\s+to|respect\s+to|wrt)\b",
        " ",
        text,
    )
    expression = _parse_expression(text)
    if expression is None or not expression.free_symbols:
        return None
    variables = sorted(expression.free_symbols, key=lambda s: s.name)
    if len(variables) != 1:
        return None
    return variables[0], expression


def _finite_difference(
    expression: sp.Expr, variable: sp.Symbol, at: sp.Expr, step: float = 1e-6
) -> float | None:
    """Numerical gradient, computed independently of SymPy's differentiation."""
    try:
        function = sp.lambdify(variable, expression, "math")
        x = float(at)
        return (function(x + step) - function(x - step)) / (2 * step)
    except (TypeError, ValueError, ZeroDivisionError):
        return None


def solve_calculus(problem: str, lowered: str) -> TutorSolution | None:
    """Differentiate, integrate or find the turning point of a function."""
    if not mentions(lowered, *_CALCULUS_KEYWORDS):
        return None
    parsed = _calculus_expression(problem)
    if parsed is None:
        return None
    variable, expression = parsed
    if mentions(lowered, "integrate", "integral", "antiderivative"):
        return _integral_solution(problem, variable, expression)
    if mentions(lowered, "turning point", "stationary"):
        return _stationary_solution(problem, variable, expression)
    if mentions(lowered, "differentiate", "derivative", "dy/dx", "d/dx"):
        return _derivative_solution(problem, variable, expression)
    return None


def _derivative_solution(
    problem: str, variable: sp.Symbol, expression: sp.Expr
) -> TutorSolution | None:
    derivative = sp.simplify(sp.diff(expression, variable))
    if derivative.has(sp.Derivative):
        return None

    sample = sp.Rational(1, 3)
    analytic = float(sp.N(derivative.subs(variable, sample)))
    numeric = _finite_difference(expression, variable, sample)
    if numeric is None:
        check = unverified("The derivative could not be sampled for a check.")
    else:
        check = verify_by_recomputation(
            analytic, numeric, "The gradient at a sample point", tolerance=1e-3
        )

    steps = [
        TutorStep(
            id=1,
            title="Write the function",
            explanation=f"We differentiate this function with respect to {variable.name}.",
            narration=f"We differentiate the function with respect to {variable.name}.",
            latex_lines=[f"y = {sp.latex(expression)}"],
        ),
        TutorStep(
            id=2,
            title="Differentiate term by term",
            explanation=(
                "The power rule multiplies by the power and then reduces it by one; "
                "a constant differentiates to zero."
            ),
            narration=(
                "Using the power rule, we multiply each term by its power and "
                "reduce the power by one."
            ),
            latex_lines=[
                "\\frac{d}{dx}x^n = n x^{n-1}",
                f"\\frac{{dy}}{{dx}} = {sp.latex(derivative)}",
            ],
        ),
        TutorStep(
            id=3,
            title="Check the derivative",
            explanation=(
                "A numerical estimate of the gradient at a sample point agrees with "
                "the differentiated expression."
            ),
            narration="A numerical check at a sample point agrees with the derivative.",
            latex_lines=[
                f"\\left.{sp.latex(derivative)}\\right|_{{x=\\frac{{1}}{{3}}}}"
                f" \\approx {fmt(analytic)}"
            ],
        ),
    ]
    return _steps_to_solution(
        problem,
        "calculus",
        "differentiation",
        steps,
        f"\\frac{{dy}}{{dx}} = {sp.latex(derivative)}",
        _plain_expression(derivative),
        check,
    )


def _integral_solution(
    problem: str, variable: sp.Symbol, expression: sp.Expr
) -> TutorSolution | None:
    antiderivative = sp.integrate(expression, variable)
    if antiderivative.has(sp.Integral) or antiderivative.has(sp.Derivative):
        return None
    check = verify_equality(
        sp.diff(antiderivative, variable), expression, "The antiderivative"
    )

    steps = [
        TutorStep(
            id=1,
            title="Write the expression",
            explanation=f"We integrate this expression with respect to {variable.name}.",
            narration=f"We integrate the expression with respect to {variable.name}.",
            latex_lines=[sp.latex(expression)],
        ),
        TutorStep(
            id=2,
            title="Integrate term by term",
            explanation=(
                "The power rule for integration raises the power by one and divides "
                "by the new power, and we add the constant of integration."
            ),
            narration=(
                "Raising each power by one and dividing by the new power integrates "
                "each term, and we add a constant."
            ),
            latex_lines=[
                "\\int x^n\\,dx = \\frac{x^{n+1}}{n+1} + C",
                f"\\int {sp.latex(expression)}\\,d{variable.name} = "
                f"{sp.latex(antiderivative)} + C",
            ],
        ),
        TutorStep(
            id=3,
            title="Check by differentiating",
            explanation=(
                "Differentiating the answer returns the original expression, so the "
                "integral is correct."
            ),
            narration=(
                "Differentiating the answer returns the original expression, so the "
                "integral is correct."
            ),
            latex_lines=[
                f"\\frac{{d}}{{d{variable.name}}}\\left({sp.latex(antiderivative)}"
                f"\\right) = {sp.latex(expression)}"
            ],
        ),
    ]
    return _steps_to_solution(
        problem,
        "calculus",
        "integration",
        steps,
        f"\\int {sp.latex(expression)}\\,d{variable.name} = "
        f"{sp.latex(antiderivative)} + C",
        f"{_plain_expression(antiderivative)} + C",
        check,
    )


def _stationary_solution(
    problem: str, variable: sp.Symbol, expression: sp.Expr
) -> TutorSolution | None:
    first = sp.simplify(sp.diff(expression, variable))
    roots = sp.solve(sp.Eq(first, 0), variable)
    if not roots:
        return None
    second = sp.diff(expression, variable, 2)

    results: list[tuple[sp.Expr, sp.Expr, str]] = []
    okay = True
    for root in roots:
        root = sp.nsimplify(root)
        height = sp.simplify(expression.subs(variable, root))
        slope = float(sp.N(first.subs(variable, root)))
        curvature = float(sp.N(second.subs(variable, root)))
        if abs(slope) > 1e-7:
            okay = False
        if curvature > 1e-9:
            nature = "minimum"
        elif curvature < -1e-9:
            nature = "maximum"
        else:
            nature = "point of inflection"
        results.append((root, height, nature))

    check = (
        verified("The gradient is zero at every turning point.")
        if okay
        else unverified("A turning point did not satisfy the zero-gradient condition.")
    )

    points_latex = ", ".join(
        f"\\left({sp.latex(root)}, {sp.latex(height)}\\right)"
        for root, height, _ in results
    )
    points_text = ", ".join(
        f"({fmt(root)}, {fmt(height)})" for root, height, _ in results
    )
    nature_text = ", ".join(
        f"({fmt(root)}, {fmt(height)}) is a {nature}"
        for root, height, nature in results
    )

    steps = [
        TutorStep(
            id=1,
            title="Write the function",
            explanation="A turning point is where the gradient of the curve is zero.",
            narration="A turning point happens where the gradient of the curve is zero.",
            latex_lines=[f"y = {sp.latex(expression)}"],
        ),
        TutorStep(
            id=2,
            title="Differentiate and set to zero",
            explanation=(
                "Differentiate the function, then solve the gradient equal to zero "
                "to find the x-values of the turning points."
            ),
            narration=(
                "We differentiate the function and set the derivative equal to zero."
            ),
            latex_lines=[
                f"\\frac{{dy}}{{dx}} = {sp.latex(first)}",
                f"{sp.latex(first)} = 0",
            ],
        ),
        TutorStep(
            id=3,
            title="Find the coordinates",
            explanation=(
                "Substitute each x-value back into the original function to get the "
                "y-coordinate of the turning point."
            ),
            narration=f"Substituting back gives {nature_text}.",
            latex_lines=[points_latex],
        ),
        TutorStep(
            id=4,
            title="Check",
            explanation="Substituting the x-value into the derivative gives zero.",
            narration=(
                "Substituting the x-value into the derivative gives zero, so the "
                "turning point is correct."
            ),
            latex_lines=[
                f"\\frac{{dy}}{{dx}}\\Big|_{{x={sp.latex(root)}}} = 0"
                for root, _, _ in results
            ],
        ),
    ]

    root_values = [float(sp.N(root)) for root, _, _ in results]
    centre = sum(root_values) / len(root_values)
    span = max(3.0, max(abs(value - centre) for value in root_values) + 3.0)
    xmin, xmax = centre - span, centre + span
    curve = _curve_points(expression, variable, xmin, xmax)
    ys = [point[1] for point in curve] or [0.0]
    ymin = min(ys + [0.0]) - 2.0
    ymax = max(ys + [0.0]) + 2.0
    primitives: list[dict[str, Any]] = [{"type": "axes"}]
    if curve:
        primitives.append({"type": "path", "points": curve})
    for root, height, nature in results:
        primitives.append(
            _point(
                float(sp.N(root)),
                float(sp.N(height)),
                label=f"{nature}: ({fmt(root)}, {fmt(height)})",
                filled=True,
            )
        )
    visual = _figure_spec(
        "The curve with its turning point marked.",
        (xmin, xmax, ymin, ymax),
        primitives,
    )

    return _steps_to_solution(
        problem,
        "calculus",
        "stationary_points",
        steps,
        points_latex,
        points_text,
        check,
        visual=visual,
    )


# ---------------------------------------------------------------------------
# Trigonometric equations
# ---------------------------------------------------------------------------

_TRIG_FUNCTION_VALUES = {"sin": math.sin, "cos": math.cos, "tan": math.tan}


def _trig_range(lowered: str) -> tuple[float, float]:
    """The interval of solutions, defaulting to 0 to 360 degrees."""
    match = re.search(
        r"(-?\d+(?:\.\d+)?)\s*(?:<=?|\u2264)\s*[a-z]\s*(?:<=?|\u2264)\s*"
        r"(-?\d+(?:\.\d+)?)",
        lowered,
    )
    if match is None:
        match = re.search(
            r"between\s+(-?\d+(?:\.\d+)?)\s*(?:degrees|deg|\u00b0)?\s+and\s+"
            r"(-?\d+(?:\.\d+)?)",
            lowered,
        )
    if match is None:
        return 0.0, 360.0
    low, high = float(match.group(1)), float(match.group(2))
    return (low, high) if low <= high else (high, low)


def solve_trig_equation(problem: str, lowered: str) -> TutorSolution | None:
    """Solve ``sin``/``cos``/``tan`` of a variable equal to a value in a range."""
    match = re.search(
        r"\b(sin|cos|tan)\s*\(?\s*([a-z])\s*\)?\s*=\s*(-?\d+(?:\.\d+)?)",
        problem,
        re.IGNORECASE,
    )
    if match is None:
        return None
    function = match.group(1).lower()
    variable = sp.Symbol(match.group(2).lower())
    target = float(match.group(3))
    if function in ("sin", "cos") and not -1.0 <= target <= 1.0:
        return None

    low, high = _trig_range(lowered)
    principal = {
        "sin": math.degrees(math.asin(target)),
        "cos": math.degrees(math.acos(target)),
        "tan": math.degrees(math.atan(target)),
    }[function]

    candidates: list[float] = []
    if function == "sin":
        for multiple in range(-6, 7):
            candidates.append(principal + 360.0 * multiple)
            candidates.append(180.0 - principal + 360.0 * multiple)
    elif function == "cos":
        for multiple in range(-6, 7):
            candidates.append(principal + 360.0 * multiple)
            candidates.append(-principal + 360.0 * multiple)
    else:
        for multiple in range(-12, 13):
            candidates.append(principal + 180.0 * multiple)

    solutions = sorted(
        {
            round(solution, 6)
            for solution in candidates
            if low - 1e-9 <= solution <= high + 1e-9
        }
    )
    if not solutions:
        return None

    trig_value = _TRIG_FUNCTION_VALUES[function]
    okay = all(
        abs(trig_value(math.radians(solution)) - target) < 1e-9
        for solution in solutions
    )
    check = (
        verified("Every solution satisfies the equation in the given range.")
        if okay
        else unverified("A solution did not satisfy the equation.")
    )

    general = {
        "sin": (
            f"{variable.name} = {fmt(principal)}^\\circ + 360^\\circ n "
            f"\\quad \\text{{or}} \\quad "
            f"{variable.name} = {fmt(180.0 - principal)}^\\circ + 360^\\circ n"
        ),
        "cos": (f"{variable.name} = \\pm {fmt(principal)}^\\circ + 360^\\circ n"),
        "tan": f"{variable.name} = {fmt(principal)}^\\circ + 180^\\circ n",
    }[function]
    solutions_latex = ", \\quad ".join(
        f"{variable.name} = {fmt(solution)}^\\circ" for solution in solutions
    )
    solutions_text = ", ".join(fmt(solution) for solution in solutions)

    steps = [
        TutorStep(
            id=1,
            title="Find the principal value",
            explanation=(
                f"Take the inverse {function} of {fmt(target)} to get the first, "
                "principal solution."
            ),
            narration=(
                f"The principal value is the inverse {function} of {spoken_number(target)}, "
                f"which is {spoken_number(principal)} degrees."
            ),
            latex_lines=[
                f"\\{function}^{{-1}}({fmt(target)}) = {fmt(principal)}^\\circ"
            ],
        ),
        TutorStep(
            id=2,
            title="Write the general solution",
            explanation=(
                f"{function.capitalize()} repeats every "
                f"{'180' if function == 'tan' else '360'} degrees, which gives every "
                "possible solution."
            ),
            narration=(
                "Because the function repeats, we can write a general solution and "
                "then keep only the values inside the range."
            ),
            latex_lines=[general],
        ),
        TutorStep(
            id=3,
            title="List the solutions in the range",
            explanation=f"Keep the values between {fmt(low)} and {fmt(high)} degrees.",
            narration=(
                f"In the range from {spoken_number(low)} to {spoken_number(high)} "
                f"degrees the solutions are {solutions_text}."
            ),
            latex_lines=[solutions_latex],
        ),
        TutorStep(
            id=4,
            title="Check",
            explanation=(
                "Substituting each solution back into the equation gives the "
                "required value."
            ),
            narration=(
                "Substituting each solution back gives the required value, so the "
                "answers are correct."
            ),
            latex_lines=[general],
        ),
    ]

    return _steps_to_solution(
        problem,
        "trigonometry",
        "trigonometric_equation",
        steps,
        solutions_latex,
        f"{variable.name} = {solutions_text} degrees",
        check,
    )


# ---------------------------------------------------------------------------
# Dispatch order
# ---------------------------------------------------------------------------

# Ordered most specific first. Each entry is tried in turn and the first
# non-None result wins, so a guard only has to be right about its own topic.
TOPIC_SOLVERS = (
    solve_linear_programming,
    solve_trig_equation,
    solve_calculus,
    solve_simultaneous,
    solve_inequality,
    solve_simplify,
    solve_function_value,
    solve_sequence,
    solve_triangle_angles,
    solve_mensuration,
    solve_trigonometry,
    solve_coordinate,
    solve_statistics,
    solve_probability,
    solve_ratio,
    solve_percentage_change,
    solve_fractions,
)


def solve_topic(problem: str) -> TutorSolution | None:
    """Try every topic solver in order, returning the first solution found."""
    lowered = problem.strip().lower()
    for solver in TOPIC_SOLVERS:
        try:
            result = solver(problem, lowered)
        except (ArithmeticError, TypeError, ValueError, sp.SympifyError):
            continue
        if result is not None:
            return result
    return None
