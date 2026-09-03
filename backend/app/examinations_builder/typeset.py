"""Lightweight mathematical / scientific typesetting for examination papers.

Converts compact notation such as ``x^2``, ``H_2O``, ``10^-3``, ``sqrt(4)``
and ``frac(a)(b)`` into styled runs (super/subscript) without executing any
user text. The same run list is adapted to reportlab (PDF) markup and to
python-docx runs so that equations are never flattened into malformed plain
text.

Public API
----------
- ``typeset(text) -> list[Run]`` — parse notation into styled runs.
- ``runs_to_reportlab(runs) -> str`` — inline ``<super>/<sub>`` markup.
- ``runs_to_readable(runs) -> str`` — plain unicode reading (best-effort).

Notation understood
-------------------
- ``x^2`` → x with superscript 2; ``x_{n+1}`` for a multi-char exponent.
- ``H_2O`` → H with subscript 2 (chemistry); ``H_2O_2`` supported.
- ``10^-3`` → superscript "-3" on the base.
- ``sqrt(x)`` → √(x).
- ``frac(a)(b)`` → a/b (numerator/denominator spans, marked ``frac``).
- ``{}`` groups for a multi-character super/subscript.
- ``\\pi`` → π, ``\\theta`` → θ, ``\\leq`` → ≤, ``\\times`` → ×, and more.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

_SUB_DIGITS = {
    "0": "₀",
    "1": "₁",
    "2": "₂",
    "3": "₃",
    "4": "₄",
    "5": "₅",
    "6": "₆",
    "7": "₇",
    "8": "₈",
    "9": "₉",
}
_SUP_MAP = {
    "0": "⁰",
    "1": "¹",
    "2": "²",
    "3": "³",
    "4": "⁴",
    "5": "⁵",
    "6": "⁶",
    "7": "⁷",
    "8": "⁸",
    "9": "⁹",
    "+": "⁺",
    "-": "⁻",
    "=": "⁼",
    "n": "ⁿ",
    "x": "ˣ",
}

_GLYPHS = {
    "pi": "π",
    "theta": "θ",
    "alpha": "α",
    "beta": "β",
    "gamma": "γ",
    "lambda": "λ",
    "mu": "μ",
    "sigma": "σ",
    "delta": "δ",
    "Delta": "Δ",
    "omega": "ω",
    "leq": "≤",
    "geq": "≥",
    "neq": "≠",
    "pm": "±",
    "times": "×",
    "div": "÷",
    "infty": "∞",
    "approx": "≈",
    "sum": "∑",
    "int": "∫",
    "partial": "∂",
    "rightarrow": "→",
    "Rightarrow": "⇒",
    "cdot": "·",
    "deg": "°",
    "sqrt": "√",
    "right": "",
    "left": "",
}


@dataclass
class Run:
    """A single styled text fragment."""

    text: str
    style: str = "txt"  # txt | sup | sub | frac


_TOKEN_RE = re.compile(
    r"""
    [ \t]+
    | \\[a-zA-Z]+
    | frac\(
    | sqrt\(
    | \{
    | \}
    | _
    | \^
    | \(
    | \)
    | [0-9]+(?:\.[0-9]+)?
    | -
    | [^\s\\{}(\)_^]+
    """,
    re.VERBOSE,
)


def _glyph(cmd: str) -> str:
    return _GLYPHS.get(cmd, f"\\{cmd}")


def _closed_brace(tokens: list[str], start: int) -> tuple[str | None, int]:
    """Return (joined content, index-after) for ``{ ... }`` starting at ``start``."""
    depth = 0
    parts: list[str] = []
    i = start
    while i < len(tokens):
        if tokens[i] == "{":
            depth += 1
        elif tokens[i] == "}":
            depth -= 1
            if depth == 0:
                return "".join(parts), i + 1
        else:
            parts.append(tokens[i])
        i += 1
    return None, len(tokens)


def typeset(text: str) -> list[Run]:
    """Parse compact math/scientific notation into styled runs.

    Word spaces are preserved so that prose ("Which of the following ...") never
    collapses into a single run. Math/scientific tokens (``x^2``, ``H_2O``,
    ``10^-3``, ``sqrt(...)``, ``frac(a)(b)``) are turned into styled runs while
    ordinary words, numbers and punctuation keep their natural spacing.
    """
    source = (text or "").replace("->", "\\rightarrow").replace("=>", "\\Rightarrow")
    tokens = _TOKEN_RE.findall(source)
    if not tokens:
        return [Run(text or "", "txt")]

    chunks: list[Run] = []
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if tok.startswith("\\"):
            chunks.append(Run(_glyph(tok[1:]), "txt"))
            i += 1
        elif tok == "frac(":
            pieces = list(_scan_frac(tokens, i))
            if pieces and len(pieces) == 2:
                num, den = pieces
                chunks.append(Run(num, "frac"))
                chunks.append(Run("/", "txt"))
                chunks.append(Run(den, "frac"))
                i = len(tokens)
            else:
                i += 1
        elif tok == "sqrt(":
            # find the matching closing paren
            depth = 0
            inner: list[str] = []
            j = i + 1
            while j < len(tokens):
                t = tokens[j]
                if t == "(":
                    depth += 1
                elif t == ")":
                    if depth == 0:
                        break
                    depth -= 1
                if t not in ("(", ")"):
                    inner.append(t)
                j += 1
            chunks.append(Run("√", "txt"))
            if inner:
                chunks.append(Run("(", "txt"))
                chunks.extend(typeset("".join(inner)))
                chunks.append(Run(")", "txt"))
            i = j + 1 if j < len(tokens) else len(tokens)
        elif tok in ("^", "_"):
            style = "sup" if tok == "^" else "sub"
            j = i + 1
            if j < len(tokens) and tokens[j] == "{":
                content, next_i = _closed_brace(tokens, j)
                if content is not None:
                    chunks.append(Run(content, style))
                    i = next_i
                    continue
            # signed exponent/subscript: consume sign + following digits (10^-3)
            inner: list[str] = []
            if j < len(tokens) and tokens[j] in ("-", "+"):
                inner.append(tokens[j])
                j += 1
            while j < len(tokens) and re.fullmatch(r"[0-9]+", tokens[j]):
                inner.append(tokens[j])
                j += 1
            if inner:
                chunks.append(Run("".join(inner), style))
                i = j
            elif j < len(tokens):
                chunks.append(Run(tokens[j], style))
                i = j + 1
            else:
                i += 1
        elif tok == "{":
            content, next_i = _closed_brace(tokens, i)
            if content is not None:
                chunks.append(Run(content, "txt"))
                i = next_i
            else:
                i += 1
        elif tok in ("(", ")"):
            chunks.append(Run(tok, "txt"))
            i += 1
        else:
            # A plain word or a run of whitespace from the catch-all/space token.
            chunks.append(Run(tok, "txt"))
            i += 1

    return [r for r in chunks if r.text != ""] or [Run(text or "", "txt")]


def _scan_frac(tokens: list[str], start: int):
    """Yield the numerator and denominator spans of a ``frac(..)(..)`` form."""
    cur: list[str] = []
    seen = 0
    i = start + 1  # skip "frac("
    depth = 0
    while i < len(tokens) and seen < 2:
        t = tokens[i]
        if t == "(":
            depth += 1
            if depth == 1:
                cur = []
                seen += 1
            elif depth > 1:
                cur.append(t)
        elif t == ")":
            depth -= 1
            if depth <= 0:
                yield "".join(cur)
        elif depth >= 1:
            cur.append(t)
        i += 1


def runs_to_reportlab(runs: list[Run]) -> str:
    """Convert runs to inline reportlab Paragraph markup with escaping."""

    def esc(s: str) -> str:
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

    out: list[str] = []
    for r in runs:
        body = esc(r.text)
        if r.style == "sup":
            out.append(f"<super>{body}</super>")
        elif r.style == "sub":
            out.append(f"<sub>{body}</sub>")
        else:
            out.append(body)
    return "".join(out)


def runs_to_readable(runs: list[Run]) -> str:
    """Best-effort unicode reading (used by DOCX and plain text exports)."""

    def fibre(r: Run) -> str:
        if r.style == "sub":
            return "".join(_SUB_DIGITS.get(ch, ch) for ch in r.text)
        if r.style == "sup":
            return "".join(_SUP_MAP.get(ch, ch) for ch in r.text)
        return r.text

    return "".join(fibre(r) for r in runs)


def runs_to_docx_runs(runs: list[Run]) -> list[tuple[str, str]]:
    """Return ``(text, style)`` tuples for python-docx runs (txt/frac/sup/sub)."""
    return [(r.text, r.style) for r in runs if r.text]


def to_readable(text: str) -> str:
    """Convenience: parse notation then render as a readable plain string."""
    return runs_to_readable(typeset(text))
