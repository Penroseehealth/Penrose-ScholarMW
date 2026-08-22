"""STEM notation-to-speech converter.

Converts LaTeX and scientific notation into speech-friendly text
for accessible text-to-speech output.
"""

from __future__ import annotations

import re

GREEK_MAP = {
    "alpha": "alpha",
    "beta": "beta",
    "gamma": "gamma",
    "delta": "delta",
    "epsilon": "epsilon",
    "zeta": "zeta",
    "eta": "eta",
    "theta": "theta",
    "iota": "iota",
    "kappa": "kappa",
    "lambda": "lambda",
    "mu": "mu",
    "nu": "nu",
    "xi": "xi",
    "pi": "pi",
    "rho": "rho",
    "sigma": "sigma",
    "tau": "tau",
    "upsilon": "upsilon",
    "phi": "phi",
    "chi": "chi",
    "psi": "psi",
    "omega": "omega",
    "Alpha": "Alpha",
    "Beta": "Beta",
    "Gamma": "Gamma",
    "Delta": "Delta",
    "Theta": "Theta",
    "Lambda": "Lambda",
    "Sigma": "Sigma",
    "Omega": "Omega",
    "Phi": "Phi",
    "Psi": "Psi",
    "Pi": "Pi",
}

SUPERSCRIPT_MAP = {
    "0": " superscript 0",
    "1": " superscript 1",
    "2": " squared",
    "3": " cubed",
    "4": " superscript 4",
    "5": " superscript 5",
    "6": " superscript 6",
    "7": " superscript 7",
    "8": " superscript 8",
    "9": " superscript 9",
    "n": " superscript n",
    "m": " superscript m",
    "x": " superscript x",
    "+": " superscript plus",
    "-": " superscript minus",
}

SUBSCRIPT_MAP = {
    "0": " subscript 0",
    "1": " subscript 1",
    "2": " subscript 2",
    "3": " subscript 3",
    "4": " subscript 4",
    "5": " subscript 5",
    "a": " a",
    "e": " e",
    "i": " i",
    "n": " n",
    "o": " o",
    "x": " x",
}

UNIT_MAP = {
    "m/s": "meters per second",
    "m/s^2": "meters per second squared",
    "kg": "kilograms",
    "g": "grams",
    "mol": "moles",
    "L": "liters",
    "mL": "milliliters",
    "Hz": "hertz",
    "N": "Newtons",
    "J": "Joules",
    "W": "Watts",
    "Pa": "Pascals",
    "V": "Volts",
    "A": "Amperes",
    "ohm": "Ohms",
    "C": "Coulombs",
    "eV": "electron Volts",
}

CHEMICAL_MAP = {
    "H2O": "H two O",
    "CO2": "C O two",
    "O2": "O two",
    "N2": "N two",
    "H2": "H two",
    "NaCl": "Na Cl",
    "Fe2O3": "F e two O three",
    "CaCO3": "Ca C O three",
    "NaOH": "Na O H",
    "HCl": "H Cl",
    "H2SO4": "H two S O four",
    "Ca(OH)2": "Ca O H two",
}


def latex_to_speech(latex: str, language: str = "en") -> str:
    if language != "en":
        return _generic_speech(latex)

    s = latex.strip()
    s = s.strip("$").strip("\\(").strip("\\)").strip("\\[").strip("\\]")

    if s in CHEMICAL_MAP:
        return CHEMICAL_MAP[s]

    s = _process_fractions(s)
    s = _process_roots(s)
    s = _process_integrals(s)
    s = _process_sums(s)
    s = _process_lims(s)
    s = _process_greek(s)
    s = _process_superscripts(s)
    s = _process_subscripts(s)
    s = _process_operators(s)
    s = _process_units(s)
    s = _clean_latex(s)

    s = re.sub(r"\s+", " ", s).strip()
    return s


def _process_fractions(s: str) -> str:
    pattern = r"\\frac\{([^{}]+)\}\{([^{}]+)\}"

    def replacer(m):
        num = m.group(1)
        den = m.group(2)
        return f"{num} over {den}"

    return re.sub(pattern, replacer, s)


def _process_roots(s: str) -> str:
    s = re.sub(r"\\sqrt\[3\]\{([^{}]+)\}", r"cube root of \1", s)
    s = re.sub(r"\\sqrt\{([^{}]+)\}", r"square root of \1", s)
    s = re.sub(r"\\sqrt\[n\]\{([^{}]+)\}", r"nth root of \1", s)
    return s


def _process_integrals(s: str) -> str:
    def integral_replacer(m):
        lower = m.group(1) if m.group(1) else ""
        upper = m.group(2) if m.group(2) else ""
        if lower and upper:
            return f"integral from {lower} to {upper}"
        return "integral"

    s = re.sub(r"\\int_\{?([^{}]*)\}?\s*\^\{?([^{}]*)\}?", integral_replacer, s)
    s = s.replace("\\int", "integral")
    return s


def _process_sums(s: str) -> str:
    def sum_replacer(m):
        lower = m.group(1) if m.group(1) else ""
        upper = m.group(2) if m.group(2) else ""
        if lower and upper:
            return f"summation from {lower} to {upper}"
        return "summation"

    s = re.sub(r"\\sum_\{?([^{}]*)\}?\s*\^\{?([^{}]*)\}?", sum_replacer, s)
    s = s.replace("\\sum", "summation")
    return s


def _process_lims(s: str) -> str:
    s = re.sub(r"\\lim_\{([^{}]+)\}", r"limit as \1", s)
    s = s.replace("\\to", "to")
    return s


def _process_greek(s: str) -> str:
    for cmd, name in GREEK_MAP.items():
        s = s.replace(f"\\{cmd}", name)
    return s


def _process_superscripts(s: str) -> str:
    def sup_replacer(m):
        content = m.group(1)
        if content in SUPERSCRIPT_MAP:
            return SUPERSCRIPT_MAP[content]
        if content.isdigit():
            word = {
                0: "zero",
                1: "one",
                2: "two",
                3: "three",
                4: "four",
                5: "five",
                6: "six",
                7: "seven",
                8: "eight",
                9: "nine",
            }.get(int(content), content)
            return f" to the {word}"
        return f" to the {content}"

    s = re.sub(r"\^\{([^}]+)\}", sup_replacer, s)
    s = re.sub(r"\^(\d)", sup_replacer, s)
    return s


def _process_subscripts(s: str) -> str:
    def sub_replacer(m):
        content = m.group(1)
        if content in SUBSCRIPT_MAP:
            return SUBSCRIPT_MAP[content]
        return f" subscript {content}"

    s = re.sub(r"_\{([^}]+)\}", sub_replacer, s)
    s = re.sub(r"_(\w)", sub_replacer, s)
    return s


def _process_operators(s: str) -> str:
    replacements = {
        r"\times": "times",
        r"\cdot": "times",
        r"\div": "divided by",
        r"\pm": "plus or minus",
        r"\mp": "minus or plus",
        r"\leq": "less than or equal to",
        r"\geq": "greater than or equal to",
        r"\neq": "not equal to",
        r"\approx": "approximately equal to",
        r"\in": "in",
        r"\notin": "not in",
        r"\subset": "is a subset of",
        r"\cup": "union",
        r"\cap": "intersection",
        r"\infty": "infinity",
        r"\partial": "partial",
        r"\nabla": "nabla",
        r"\forall": "for all",
        r"\exists": "there exists",
        r"\neg": "not",
        r"\land": "and",
        r"\lor": "or",
        r"\rightarrow": "maps to",
        r"\leftarrow": "from",
        r"\Rightarrow": "implies",
        r"\Leftarrow": "is implied by",
        r"\leftrightarrow": "if and only if",
    }
    for latex_cmd, speech in replacements.items():
        s = s.replace(latex_cmd, speech)
    return s


def _process_units(s: str) -> str:
    for unit, spoken in UNIT_MAP.items():
        s = s.replace(unit, spoken)
    return s


def _clean_latex(s: str) -> str:
    s = re.sub(r"\\text\{([^}]+)\}", r"\1", s)
    s = re.sub(r"\\mathrm\{([^}]+)\}", r"\1", s)
    s = re.sub(r"\\mathbf\{([^}]+)\}", r"\1", s)
    s = re.sub(r"\\begin\{[^}]+\}", "", s)
    s = re.sub(r"\\end\{[^}]+\}", "", s)
    s = re.sub(r"\\[a-zA-Z]+\{([^}]+)\}", r"\1", s)
    s = re.sub(r"\\[a-zA-Z]+", "", s)
    s = s.replace("{", "").replace("}", "")
    s = s.replace("\\,", " ").replace("\\;", " ")
    s = s.replace("\\\\", " ")
    s = re.sub(r"\s+", " ", s)
    return s.strip()


def _generic_speech(s: str) -> str:
    s = re.sub(r"\\[a-zA-Z]+\{([^}]+)\}", r"\1", s)
    s = re.sub(r"\\[a-zA-Z]+", "", s)
    s = s.replace("{", "").replace("}", "")
    s = re.sub(r"\s+", " ", s)
    return s.strip()
