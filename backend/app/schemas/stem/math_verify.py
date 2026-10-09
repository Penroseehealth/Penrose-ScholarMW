import re

from pydantic import BaseModel

# Greek names, longest first so ``\Delta`` is not shadowed by a shorter entry.
_GREEK = {
    r"\alpha": "alpha",
    r"\beta": "beta",
    r"\gamma": "gamma",
    r"\delta": "delta",
    r"\epsilon": "epsilon",
    r"\theta": "theta",
    r"\lambda": "lambda",
    r"\mu": "mu",
    r"\pi": "pi",
    r"\sigma": "sigma",
    r"\phi": "phi",
    r"\omega": "omega",
    r"\Delta": "Delta",
    r"\Sigma": "Sigma",
    r"\Omega": "Omega",
}

# Named functions SymPy understands under their bare name.
_FUNCTIONS = {
    r"\sin": "sin",
    r"\cos": "cos",
    r"\tan": "tan",
    r"\sec": "sec",
    r"\csc": "csc",
    r"\cot": "cot",
    r"\log": "log",
    r"\ln": "log",
    r"\exp": "exp",
    r"\sinh": "sinh",
    r"\cosh": "cosh",
    r"\tanh": "tanh",
    r"\arcsin": "asin",
    r"\arccos": "acos",
    r"\arctan": "atan",
}


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
    for opener, closer in (("$$", "$$"), ("$", "$"), (r"\(", r"\)"), (r"\[", r"\]")):
        if (
            s.startswith(opener)
            and s.endswith(closer)
            and len(s) > len(opener) + len(closer) - 1
        ):
            s = s[len(opener) : len(s) - len(closer)].strip()
            break

    # Braces become parentheses only once the multi-argument commands have been
    # consumed, otherwise ``\frac{1}{2}`` loses the slash that joins them.
    s = _expand_nested_fractions(s)
    s = re.sub(r"\\d?frac\{([^{}]+)\}\{([^{}]+)\}", r"((\1)/(\2))", s)
    s = re.sub(r"\\sqrt\[(\d+)\]\{([^{}]+)\}", r"((\2)**(1/\1))", s)
    s = re.sub(r"\\sqrt\[(\d+)\]\(([^()]+)\)", r"((\2)**(1/\1))", s)
    s = re.sub(r"\\sqrt\{([^{}]+)\}", r"sqrt(\1)", s)
    s = re.sub(r"\\sqrt\(([^()]+)\)", r"sqrt(\1)", s)

    for latex_cmd, name in _GREEK.items():
        s = s.replace(latex_cmd, name)
    s = s.replace(r"\%", "/100")

    s = s.replace("\\times", "*").replace("\\cdot", "*")
    s = s.replace("\\div", "/")
    s = s.replace("\\pm", "+")
    s = s.replace("\\leq", "<=").replace("\\geq", ">=")
    s = s.replace("\\neq", "!=")
    s = s.replace("\\approx", "==")

    # Named functions must survive the generic command strip below.
    for latex_cmd, name in _FUNCTIONS.items():
        s = s.replace(latex_cmd, name)

    # Braced exponents must be rewritten before the generic command strip, or
    # ``(x+1)^{2}`` loses its opening parenthesis.
    s = re.sub(r"\^\{([^{}]+)\}", r"**(\1)", s)
    s = re.sub(r"\^\(([^()]+)\)", r"**(\1)", s)

    s = re.sub(r"\\sum_\{([^}]+)\}\^\{([^}]+)\}", r"Sum(s, \1, \2)", s)
    s = re.sub(r"\\int_\{([^}]+)\}\^\{([^}]+)\}", r"Integral(s, \1, \2)", s)

    s = re.sub(r"\\[a-zA-Z]+\{([^}]+)\}", r"\1", s)
    s = re.sub(r"\\[a-zA-Z]+", "", s)

    s = s.replace("^", "**")
    s = s.replace("{", "(").replace("}", ")")

    return _insert_implicit_multiplication(s.strip())


_NESTED_FRAC = re.compile(r"\\d?frac\{([^{}]*)\}\{([^{}]*)\}")


def _expand_nested_fractions(text: str) -> str:
    """Reduce the innermost ``\\frac{a}{b}`` pairs until none are left.

    A single regex pass cannot match ``\\frac{\\frac{1}{2}}{3}`` because the
    braces nest, so the innermost pair is rewritten repeatedly until the string
    stops changing.
    """
    previous = None
    while previous != text:
        previous = text
        text = _NESTED_FRAC.sub(r"((\1)/(\2))", text)
    return text


# A digit or closing bracket immediately followed by a letter or opening
# bracket means multiplication: ``2x`` is ``2*x`` and ``(x+1)(x-1)`` is a product.
# A Greek or named constant followed by whitespace and a letter is a product too,
# as in ``\\pi r^2``.
_IMPLICIT_MUL = re.compile(r"(?<=[0-9)\]\.])" r"(?=[a-zA-Z(\[])")

# A coefficient written apart from its variable, as in ``2 \\pi`` or ``3 x``.
_IMPLICIT_MUL_SPACED = re.compile(r"(?<=[0-9)\]\.])" r"(?=\s+[a-zA-Z(])")

_IMPLICIT_MUL_NAMED = re.compile(r"(?<=[a-zA-Z])" r"(?=\s+[a-zA-Z])")


def _insert_implicit_multiplication(text: str) -> str:
    """Insert the ``*`` that students leave out when writing algebra.

    Sympify rejects ``2x + 3x`` outright, which is exactly how school work is
    written, so this runs before parsing.
    """
    text = _IMPLICIT_MUL_SPACED.sub("*", text)
    text = _IMPLICIT_MUL.sub("*", text)
    return re.sub(r"\*\s+", "*", _IMPLICIT_MUL_NAMED.sub("*", text))


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
        sympy_expr = sympify(
            _latex_to_sympy(req.expression), locals={req.variable: var}
        )
        steps.append(
            MathStep(description="Parsed expression", expression=str(sympy_expr))
        )
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
            steps.append(
                MathStep(description="Expanded", expression=str(expanded_form))
            )
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
            expected = sympify(
                _latex_to_sympy(req.expected_simplified), locals={req.variable: var}
            )
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
            steps.append(
                MathStep(
                    description="Could not verify against expected", expression=str(e)
                )
            )

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
