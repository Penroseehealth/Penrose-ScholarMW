"""Independent answer verification for the mathematics tutor.

A solver may only report ``verified`` when a *second*, independent computation
agrees with the answer it is about to present. Two kinds of check are used:

* :func:`verify_by_substitution` puts a candidate answer back into the original
  equation and measures the residual, which catches algebraic mistakes.
* :func:`verify_by_recomputation` recomputes the quantity by a different route
  than the solver walked, which catches arithmetic and unit slips.

Both are deliberately cheap and deterministic. Nothing here trusts the step
narrations, so a wrong explanation cannot make a wrong answer look correct.
"""

from __future__ import annotations

from dataclasses import dataclass

import sympy as sp

DEFAULT_TOLERANCE = 1e-9


@dataclass(frozen=True)
class Verification:
    """Outcome of an independent check."""

    status: str
    detail: str

    @property
    def verified(self) -> bool:
        return self.status == "verified"


def verified(detail: str) -> Verification:
    return Verification(status="verified", detail=detail)


def unverified(detail: str) -> Verification:
    return Verification(status="unverified", detail=detail)


def numeric_close(
    left: float, right: float, tolerance: float = DEFAULT_TOLERANCE
) -> bool:
    """Compare two floats with an absolute-then-relative tolerance."""
    if left == right:
        return True
    if left != left or right != right:  # NaN
        return False
    return abs(left - right) <= tolerance * max(1.0, abs(left), abs(right))


def verify_by_substitution(
    expression: sp.Expr,
    answer: sp.Expr,
    tolerance: float = 1e-9,
) -> Verification:
    """Substitute *answer* for every symbol in *expression* and check it vanishes.

    ``expression`` is expected to be the difference between the two sides of the
    original equation, so a correct answer drives it to zero.
    """
    symbols = sorted(expression.free_symbols, key=lambda s: s.name)
    if not symbols:
        return unverified("Nothing to substitute: the expression has no unknowns.")
    if answer.free_symbols:
        return unverified("The proposed answer still contains unknowns.")

    try:
        residual = sp.simplify(expression.subs({s: answer for s in symbols}))
    except (TypeError, ValueError, sp.SympifyError, ZeroDivisionError):
        return unverified("The answer could not be substituted back into the question.")

    numeric = complex(sp.N(residual))
    if abs(numeric) <= tolerance:
        return verified(f"Residual after substitution: {sp.nsimplify(residual)}")
    return unverified(
        f"Substituting the answer left a residual of {sp.nsimplify(residual)}, "
        "so the working does not return to the original question."
    )


def verify_by_recomputation(
    expected: float,
    recomputed: float,
    what: str,
    tolerance: float = 1e-9,
) -> Verification:
    """Compare the solver's answer against a second, independent computation."""
    if numeric_close(expected, recomputed, tolerance):
        return verified(f"{what} confirmed by an independent calculation.")
    return unverified(
        f"{what} does not match an independent calculation "
        f"({expected} against {recomputed})."
    )


def verify_equality(
    left: sp.Expr,
    right: sp.Expr,
    what: str,
) -> Verification:
    """Symbolic equality check used when both sides are exact expressions."""
    try:
        difference = sp.simplify(sp.expand(left - right))
    except (TypeError, ValueError, sp.SympifyError):
        return unverified(f"{what} could not be simplified for comparison.")
    if difference == 0:
        return verified(f"{what} confirmed symbolically.")
    return unverified(f"{what} does not simplify to a match (left over: {difference}).")


def verify_range(
    value: float,
    low: float,
    high: float,
    what: str,
) -> Verification:
    """Check a value satisfies an interval, e.g. a probability or an angle."""
    if low - 1e-9 <= value <= high + 1e-9:
        return verified(f"{what} lies in the valid range.")
    return unverified(f"{what} = {value} falls outside the valid range.")


def verification_fields(check: Verification) -> dict[str, str]:
    """Shape a :class:`Verification` for ``TutorSolution``."""
    return {"verification_status": check.status, "verification_detail": check.detail}
