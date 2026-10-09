"""Number formatting shared by the mathematics tutor and its topic solvers.

Keeping these in one place means a value is spoken and displayed identically no
matter which solver produced it.
"""

from __future__ import annotations

import sympy as sp


def fmt(value: float | sp.Expr) -> str:
    """Compact display form: whole numbers stay whole, others lose trailing zeros."""
    if isinstance(value, sp.Expr):
        value = float(sp.nsimplify(value))
    if abs(value - round(value)) < 1e-12:
        return str(int(round(value)))
    return f"{round(value, 6):g}"


def spoken_number(value: float) -> str:
    """Spoken form used in narration scripts."""
    if abs(value - round(value)) < 1e-12:
        return str(int(round(value)))
    return f"{value:.2f}".rstrip("0").rstrip(".")


def spoken_ratio(numerator: float, denominator: float) -> str:
    """Speak a value that may be a fraction, e.g. 5/8 -> "five eighths" style text."""
    if denominator == 0:
        return spoken_number(numerator)
    if abs(denominator - 1) < 1e-12:
        return spoken_number(numerator)
    return f"{spoken_number(numerator)} over {spoken_number(denominator)}"
