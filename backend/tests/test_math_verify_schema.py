"""Tests for the STEM maths verification endpoint's LaTeX handling."""

import pytest
import sympy

from app.schemas.stem.math_verify import (
    MathVerifyRequest,
    _latex_to_sympy,
    verify_math_expression,
)


@pytest.mark.parametrize(
    ("latex", "expected"),
    [
        (r"2x + 3x - 5", "5*x - 5"),
        (r"5x^2 + 3x", "5*x**2 + 3*x"),
        (r"x^{2} + 2x + 1", "x**2 + 2*x + 1"),
        (r"(x+1)^{2}", "(x + 1)**2"),
        (r"2(x + 1)", "2*x + 2"),
        (r"(x+1)(x-1)", "x**2 - 1"),
        (r"\frac{x+1}{2}", "x/2 + 1/2"),
        (r"\frac{1}{2}x + 3", "x/2 + 3"),
        (r"\frac{\frac{1}{2}}{3}", "1/6"),
        (r"\sqrt[3]{8}", "2"),
        (r"2\sqrt{x} + 1", "2*sqrt(x) + 1"),
        (r"\pi r^2", "pi*r**2"),
        (r"2 \pi", "2*pi"),
        (r"50\%", "1/2"),
        (r"\sin(x) + 1", "sin(x) + 1"),
        (r"\cos(2x)", "cos(2*x)"),
        (r"\ln(x)", "log(x)"),
        (r"\arcsin(x)", "asin(x)"),
    ],
)
def test_latex_converts_to_sympy(latex, expected):
    """The converted form must parse to an expression equal to *expected*.

    Compared through ``simplify`` so that an unexpanded product still matches
    its expanded equivalent, which is what students actually check by hand.
    """
    actual = sympy.sympify(_latex_to_sympy(latex))
    assert sympy.simplify(actual - sympy.sympify(expected)) == 0


def test_school_notation_is_accepted():
    """``2x`` is how students write; it must not be a parse error."""
    assert "2*x" in _latex_to_sympy("2x + 3x")


def test_lone_variable_unchanged():
    assert _latex_to_sympy("x") == "x"


@pytest.mark.asyncio
async def test_verify_reports_school_notation_as_valid():
    response = await verify_math_expression(
        MathVerifyRequest(expression="2x + 3x - 5", variable="x")
    )

    assert response.valid is True
    assert response.error is None
    assert response.simplified == "5*x - 5"
    assert response.latex


@pytest.mark.asyncio
async def test_verify_confirms_expected_simplification():
    response = await verify_math_expression(
        MathVerifyRequest(
            expression="2x + 3x - 5",
            variable="x",
            expected_simplified="5*x - 5",
        )
    )

    assert response.valid is True
    assert any(
        step.description == "Verified equal to expected" for step in response.steps
    )


@pytest.mark.asyncio
async def test_verify_rejects_wrong_expected_simplification():
    response = await verify_math_expression(
        MathVerifyRequest(
            expression="2x + 3x - 5",
            variable="x",
            expected_simplified="6*x - 5",
        )
    )

    assert any(step.description == "NOT equal to expected" for step in response.steps)


@pytest.mark.asyncio
async def test_verify_reports_domain_restrictions():
    response = await verify_math_expression(
        MathVerifyRequest(expression=r"\frac{1}{x - 2}", variable="x")
    )

    assert response.domain_restrictions
