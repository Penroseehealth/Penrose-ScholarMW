"""Dimensional analysis for the physics engine.

Two jobs, both mandatory before an answer is shown:

* reject physically meaningless operations such as adding a length to a time,
  in plain language the student can act on; and
* confirm that the quantity a solver computed really has the dimension the
  physical law demands, which catches unit slips that arithmetic alone misses.
"""

from __future__ import annotations

from app.physics.units import Dimension, Quantity, unit_latex


class DimensionalError(ValueError):
    """Raised when an operation mixes incompatible physical quantities."""


def describe(quantity: Quantity) -> str:
    """Human description of a quantity: ``20 N (force)``."""
    name = quantity.dimension.word
    if not quantity.unit:
        return f"{quantity.value:g} ({name})"
    return f"{quantity.latex} ({name})"


def compatible(left: Quantity, right: Quantity) -> bool:
    return left.dimension == right.dimension


def require_compatible(left: Quantity, right: Quantity, operation: str) -> None:
    """Raise :class:`DimensionalError` unless the two quantities may combine."""
    if not compatible(left, right):
        raise DimensionalError(
            f"You cannot {operation} {describe(left)} and "
            f"{describe(right)}: {left.dimension.word} and "
            f"{right.dimension.word} are different physical quantities."
        )


def require_dimension(
    quantity_value: Quantity, expected: Dimension, law: str, symbol: str
) -> None:
    """Raise unless *quantity_value* carries the dimension *law* requires."""
    if quantity_value.dimension != expected:
        raise DimensionalError(
            f"{symbol} should be a {expected.word} for {law}, but "
            f"{describe(quantity_value)} is a "
            f"{quantity_value.dimension.word}."
        )


def check_result(result: Quantity, expected: Dimension, law: str) -> tuple[bool, str]:
    """Verdict used by the verification layer: does the answer fit the law?"""
    if result.dimension == expected:
        return True, f"{law}: the answer has the correct dimensions."
    return False, (
        f"{law}: the answer came out as a {result.dimension.word}, but "
        f"{law} produces a {expected.word}."
    )


def latex_with_conversion(quantity_value: Quantity) -> list[str]:
    """LaTeX lines showing the SI conversion of *quantity_value*."""
    si = quantity_value.to_si()
    lines = [
        f"{quantity_value.latex} = {si.latex}"
        if quantity_value.unit != si.unit
        else quantity_value.latex
    ]
    return lines


def conversion_note(quantity_value: Quantity) -> str:
    """Spoken conversion, e.g. ``72 km/h is 20 metres per second``."""
    si = quantity_value.to_si()
    if quantity_value.unit == si.unit:
        return f"{quantity_value.value:g} {quantity_value.unit}".strip()
    return (
        f"{quantity_value.value:g} {quantity_value.unit} is "
        f"{si.value:g} {unit_latex(si.unit)}"
    )
