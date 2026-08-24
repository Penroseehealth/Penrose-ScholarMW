import re

from pydantic import BaseModel


class MathVerifyRequest(BaseModel):
    expression: str
    variable: str = "x"
    expected_simplified: str | None = None


class MathStep(BaseModel):
    description: str
    expression: str


class MathVerifyResponse(BaseModel):
    valid: bool
    original: str
    simplified: str
    latex: str
    steps: list[MathStep]
    error: str | None = None
    domain_restrictions: list[str] = []


def _latex_to_sympy(expr: str) -> str:
    """Convert common LaTeX notation to sympy-parseable strings."""
    s = expr.strip()
    s = s.strip("$")
    s = s.strip("\\(").strip("\\)")
    s = s.strip("\\[").strip("\\]")

    s = re.sub(r"\\frac\{([^}]+)\}\{([^}]+)\}", r"(\1)/(\2)", s)
    s = re.sub(r"\\sqrt\{([^}]+)\}", r"sqrt(\1)", s)
    s = re.sub(r"\\sqrt\[(\d+)\]\{([^}]+)\}", r"(\2)**(1/\1)", s)
    s = re.sub(r"\\sqrt\[(\d+)\]\(([^)]+)\)", r"(\2)**(1/\1)", s)
    s = re.sub(r"\\sqrt\(([^)]+)\)", r"sqrt(\1)", s)

    greek = {
        r"\\alpha": "alpha",
        r"\\beta": "beta",
        r"\\gamma": "gamma",
        r"\\delta": "delta",
        r"\\epsilon": "epsilon",
        r"\\theta": "theta",
        r"\\lambda": "lambda",
        r"\\mu": "mu",
        r"\\pi": "pi",
        r"\\sigma": "sigma",
        r"\\phi": "phi",
        r"\\omega": "omega",
        r"\\Delta": "Delta",
        r"\\Sigma": "Sigma",
        r"\\Omega": "Omega",
    }
    for latex_cmd, name in greek.items():
        s = s.replace(latex_cmd, name)

    s = s.replace("\\times", "*").replace("\\cdot", "*")
    s = s.replace("\\div", "/")
    s = s.replace("\\pm", "+")
    s = s.replace("\\leq", "<=").replace("\\geq", ">=")
    s = s.replace("\\neq", "!=")
    s = s.replace("\\approx", "==")

    s = re.sub(r"\\sum_\{([^}]+)\}\^\{([^}]+)\}", r"Sum(s, \1, \2)", s)
    s = re.sub(r"\\int_\{([^}]+)\}\^\{([^}]+)\}", r"Integral(s, \1, \2)", s)

    s = re.sub(r"\\[a-zA-Z]+\{([^}]+)\}", r"\1", s)
    s = re.sub(r"\\[a-zA-Z]+", "", s)

    s = s.replace("^", "**")
    s = s.replace("{", "(").replace(")", ")")

    return s.strip()


def _detect_restrictions(expr: str) -> list[str]:
    restrictions = []
    if re.search(r"\\frac\{[^}]*\}\{[^}]*\}", expr) or "/" in expr:
        restrictions.append("Denominator must not be zero")
    if "sqrt" in expr.lower() or "\\sqrt" in expr:
        restrictions.append("Expression under root must be non-negative")
    if "log" in expr.lower() or "ln" in expr.lower():
        restrictions.append("Argument of logarithm must be positive")
    return restrictions


async def verify_math_expression(req: MathVerifyRequest) -> MathVerifyResponse:
    from sympy import (
        Symbol,
        expand,
        factor,
        latex,
        simplify,
        sympify,
    )

    var = Symbol(req.variable)
    steps: list[MathStep] = []

    try:
        sympy_expr = sympify(_latex_to_sympy(req.expression), locals={req.variable: var})
        steps.append(MathStep(description="Parsed expression", expression=str(sympy_expr)))
    except Exception as e:
        return MathVerifyResponse(
            valid=False,
            original=req.expression,
            simplified="",
            latex="",
            steps=[],
            error=f"Parse error: {e}",
        )

    try:
        simplified = simplify(sympy_expr)
        steps.append(MathStep(description="Simplified", expression=str(simplified)))
    except Exception:
        simplified = sympy_expr

    try:
        expanded_form = expand(sympy_expr)
        if str(expanded_form) != str(simplified):
            steps.append(MathStep(description="Expanded", expression=str(expanded_form)))
    except Exception:
        pass

    try:
        factored = factor(sympy_expr)
        if str(factored) != str(simplified):
            steps.append(MathStep(description="Factored", expression=str(factored)))
    except Exception:
        pass

    if req.expected_simplified:
        try:
            expected = sympify(_latex_to_sympy(req.expected_simplified), locals={req.variable: var})
            diff = simplify(simplified - expected)
            if diff == 0:
                steps.append(
                    MathStep(
                        description="Verified equal to expected",
                        expression=str(simplified),
                    )
                )
            else:
                steps.append(
                    MathStep(
                        description="NOT equal to expected",
                        expression=f"Got: {simplified}, Expected: {expected}",
                    )
                )
        except Exception as e:
            steps.append(MathStep(description="Could not verify against expected", expression=str(e)))

    latex_str = latex(sympy_expr)
    restrictions = _detect_restrictions(req.expression)

    return MathVerifyResponse(
        valid=True,
        original=req.expression,
        simplified=str(simplified),
        latex=latex_str,
        steps=steps,
        domain_restrictions=restrictions,
    )
