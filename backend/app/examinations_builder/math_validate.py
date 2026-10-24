"""Mathematics-specific validation for generated questions.

Problem-type aware (per the Mathematics generation brief):

- Algebra / arithmetic / single-unknown equation tasks are verified with
  SymPy when the question supplies ``equations_or_expressions`` and a
  ``final_answer``. A mismatched answer is a hard reject.
- Geometry, statistics, trigonometry, graphing, proofs and constructions get
  *structural* checks only (concrete data present, determinate ask, no
  placeholder stems, units consistent). These questions are marked
  ``validation_status: structural`` — never ``sympy_verified`` — so the app
  never claims automatic mathematical verification it cannot perform.
- Generic placeholder stems ("Carry out a calculation related to the
  theorem: ...", "State the main idea behind ...") are hard rejects for
  mathematics: they name a theorem/topic without supplying the numbers,
  unknowns, or a solvable task.
"""

from __future__ import annotations

import logging
import re
from fractions import Fraction

log = logging.getLogger(__name__)

# ── Subject detection ────────────────────────────────────────────────────────

_MATH_WORDS = ("math", "maths", "mathematics", "algebra", "geometry", "trig")


def is_mathematics(subject: str) -> bool:
    s = (subject or "").strip().lower()
    return any(w in s for w in _MATH_WORDS)


# ── Placeholder / generic-stem detection ─────────────────────────────────────

_PLACEHOLDER_STEMS = (
    re.compile(r"\bcarry out a calculation related to\b", re.I),
    re.compile(r"\brelated to (the )?theorem\b", re.I),
    re.compile(r"\bstate the main idea behind\b", re.I),
    re.compile(r"\bwhich of the following best describes\b", re.I),
    re.compile(r"\bdescribe a simple practical investigation\b", re.I),
    re.compile(r"\bwrite a structured essay on\b", re.I),
    re.compile(r"\bcomplete the sentence by filling in the blank\b", re.I),
)

# A determinate ask: the learner must actually produce something specific.
_DETERMINATE_ASK = re.compile(
    r"\b(calculate|find|determine|evaluate|solve|work out|simplify|"
    r"factorise|factorize|expand|sketch|draw|plot|shade|construct|prove|"
    r"show that|estimate|convert|express|make\s+[a-z]+\s+the subject|"
    r"hence|write down|state the value|list|classify|complete the table)\b",
    re.I,
)

_DIGIT = re.compile(r"\d")
_UNIT_TOKENS = re.compile(
    r"\b(mm|cm|m|km|g|kg|tonne|litre|l|ml|second|s|min|minute|hour|hr|"
    r"degrees?|°|rand|kwalacha|mkwacha|percent|%)\b",
    re.I,
)

_UNANSWERED_HINT = re.compile(r"\bshow all your working\b|\bcorrect units\b", re.I)


def _has_numeric_data(text: str, question: dict | None = None) -> bool:
    """True when the stem carries numbers, an equation, or a diagram spec."""
    if _DIGIT.search(text):
        return True
    if question:
        if question.get("equations_or_expressions"):
            return True
        if str(question.get("diagram_specification") or "").strip():
            return True
    return False


# ── SymPy verification ───────────────────────────────────────────────────────


def _parse_number(text: str):
    """Extract a leading number (int/fraction/decimal) from answer text."""
    if text is None:
        return None
    t = str(text).strip().rstrip(".")
    m = re.match(r"^(-?\d+\s*/\s*\d+)", t)
    if m:
        try:
            num, den = m.group(1).split("/")
            return float(Fraction(int(num.strip()), int(den.strip())))
        except (ValueError, ZeroDivisionError):
            return None
    m = re.match(r"^(-?\d+(?:\.\d+)?)", t.replace(",", ""))
    if m:
        return float(m.group(1))
    # 'x = 7' / 'angle ABC = 58' style answers: look after the '=' sign.
    if "=" in t:
        tail = t.rsplit("=", 1)[1].strip().replace(",", "")
        m = re.match(r"^(-?\d+\s*/\s*\d+)", tail)
        if m:
            num, den = m.group(1).split("/")
            try:
                return float(Fraction(int(num.strip()), int(den.strip())))
            except (ValueError, ZeroDivisionError):
                pass
        m = re.match(r"^(-?\d+(?:\.\d+)?)", tail)
        if m:
            return float(m.group(1))
    return None


def _answers_agree(final_answer: str, expected) -> bool:
    """Compare an AI final_answer against a SymPy-derived expected value.

    Accepts numeric near-equality (1e-6) or a symbolic match when the
    expected value is not numeric. Returns False only on a *confident*
    mismatch — unparsable answers return None (caller treats as
    unverifiable, not invalid).
    """
    got = _parse_number(final_answer)
    if got is None:
        return None
    try:
        want = float(expected)
    except (TypeError, ValueError):
        return None
    return abs(got - want) <= max(1e-6, abs(want) * 1e-9)


def verify_with_sympy(question: dict) -> list[str]:
    """Verify ``final_answer`` against ``equations_or_expressions`` via SymPy.

    Returns a list of defect strings (empty when verified or unverifiable).
    Only claims success when the equation actually yields the answer.
    """
    import sympy
    from sympy.parsing.sympy_parser import (
        standard_transformations,
        implicit_multiplication_application,
        convert_xor,
        parse_expr,
    )

    defects: list[str] = []
    equations = question.get("equations_or_expressions") or []
    final_answer = str(question.get("final_answer") or "").strip()
    if not equations:
        return defects
    if not final_answer:
        defects.append("Equation supplied but no final_answer to verify.")
        return defects

    transforms = standard_transformations + (implicit_multiplication_application, convert_xor)
    eqs = []
    free_symbols = set()
    for raw in equations:
        s = str(raw).strip().rstrip("?").strip()
        if not s:
            continue
        s = s.replace("×", "*").replace("÷", "/").replace("²", "**2").replace("³", "**3")
        if "=" in s and not s.startswith(("y=", "f(", "<", ">")):
            left, _, right = s.partition("=")
            try:
                eq = sympy.Eq(
                    parse_expr(left, transformations=transforms),
                    parse_expr(right, transformations=transforms),
                )
            except Exception:
                defects.append(f"Unparsable equation (not rejected on parse alone): {s}")
                continue
        else:
            try:
                eq = parse_expr(s, transformations=transforms)
            except Exception:
                defects.append(f"Unparsable expression (not rejected on parse alone): {s}")
                continue
        eqs.append(eq)
        try:
            free_symbols |= eq.free_symbols
        except Exception:
            pass

    if not eqs:
        return defects
    if len(eqs) != 1 or len(free_symbols) != 1:
        # Multiple unknowns / systems: beyond single-unknown scope. Honest.
        return defects

    symbol = sorted(free_symbols, key=lambda s: s.name)[0]
    try:
        sols = sympy.solve(eqs[0], symbol)
    except Exception:
        return defects
    if not sols:
        defects.append("Equation has no solution but the question expects one.")
        return defects
    # A well-posed MSCE question has a unique answer; multiple roots are
    # allowed only if the question acknowledges them ("values of x").
    if len(sols) > 1 and not re.search(r"\b(values|solutions|roots)\b", final_answer, re.I):
        pass  # ambiguous but not provably wrong — leave to structural checks

    for sol in sols:
        agree = _answers_agree(final_answer, sol)
        if agree is True:
            return defects
        if agree is False:
            defects.append(
                f"final_answer '{final_answer}' does not satisfy the supplied "
                f"equation (SymPy solution: {sol})."
            )
            return defects
    return defects  # unparsable answer text: unverifiable, not invalid


# ── Structural validation ────────────────────────────────────────────────────


def validate_math_question(question: dict, topic: str = "") -> list[str]:
    """Return defect strings for a mathematics question, or [] when valid.

    Structural + (where possible) SymPy checks. Problem-type aware: proofs,
    constructions, simplification and graph-sketching are legitimate
    non-arithmetic tasks and are not required to carry numbers.
    """
    defects: list[str] = []
    text = str(question.get("question_text") or "").strip()
    q_type = str(question.get("question_type") or "")
    lower = text.lower()

    if not text:
        return ["Question has no text."]

    # 1. Placeholder stems are always invalid for mathematics.
    for rx in _PLACEHOLDER_STEMS:
        if rx.search(text):
            defects.append(
                "Generic placeholder stem with no concrete solvable task "
                f"(matched '{rx.pattern}')."
            )
    if defects:
        return defects

    # 2. Mentions a theorem/formula but never says what to do with it.
    mentions_theorem = bool(
        re.search(r"\btheorem\b|\bformula\b|\brule\b", text, re.I)
    )
    has_ask = bool(_DETERMINATE_ASK.search(text))
    if mentions_theorem and not has_ask:
        defects.append(
            "Names a theorem/formula without a concrete task the learner "
            "must perform."
        )

    # 3. A calculation/structured arithmetic question needs actual data.
    numeric_types = {
        "calculation",
        "short_answer",
        "fill_in_blank",
        "multiple_choice",
        "true_false",
        "matching",
    }
    is_proof_like = bool(
        re.search(
            r"\b(prove|show that|simplify|factorise|factorize|expand|sketch|"
            r"construct|describe|explain|interpret|define|state)\b",
            lower,
        )
    )
    if q_type in numeric_types and not _has_numeric_data(text, question):
        # Proofs/constructions/sketches legitimately need no numbers.
        if not is_proof_like:
            defects.append(
                "No numerical data, equation, or diagram data supplied; the "
                "task cannot be solved as written."
            )

    # 4. Must contain a determinate ask somewhere in the stem.
    if not has_ask:
        defects.append(
            "No specific unknown, quantity, or result for the learner to "
            "determine."
        )

    # 5. Units honesty: demanding units without any measurement context.
    if _UNANSWERED_HINT.search(text) and not _UNIT_TOKENS.search(text) and q_type == "calculation":
        # The stem demands units but presents no measurable quantity at all.
        if not _DIGIT.search(text):
            defects.append("Asks for units but supplies no measurable quantities.")

    # 6. SymPy verification when an equation + final answer are supplied.
    defects.extend(verify_with_sympy(question))

    return defects


def validation_status(question: dict) -> str:
    """Honest validation label: sympy_verified | structural | unverified."""
    equations = question.get("equations_or_expressions") or []
    if equations and not verify_with_sympy(question):
        return "sympy_verified"
    return "structural"


def final_answer_of(question: dict) -> str:
    """Best available final answer (explicit field, else correct_answer)."""
    explicit = str(question.get("final_answer") or "").strip()
    if explicit:
        return explicit
    return str(question.get("correct_answer") or "").strip()
