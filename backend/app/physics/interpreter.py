"""Natural-language physics interpreter.

Turns a student's sentence into structured physics: every measurement with its
unit, the phrase that names each quantity, and the unknowns the question asks
for. The solvers never scrape the raw text themselves; they ask a
:class:`PhysicsContext` for quantities by dimension or by keyword, so the
parsing rules live in exactly one place.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

from app.physics.units import (
    ACCELERATION,
    CAPACITANCE,
    CHARGE,
    DENSITY,
    ENERGY,
    FORCE,
    FREQUENCY,
    LENGTH,
    MAGNETIC_FIELD,
    MASS,
    POWER,
    PRESSURE,
    RESISTANCE,
    SPEED,
    TEMPERATURE,
    TIME,
    VOLTAGE,
    VOLUME,
    Dimension,
    Quantity,
    extract_measurements,
)

DEFAULT_GRAVITY = 9.81
SPEED_OF_LIGHT = 3.0e8
COULOMB_CONSTANT = 8.9875517923e9
GRAVITATIONAL_CONSTANT = 6.67430e-11
GAS_CONSTANT = 8.314462618

SYMBOL_LATEX = {
    "m": "m",
    "M": "M",
    "F": "F",
    "a": "a",
    "u": "u",
    "v": "v",
    "t": "t",
    "s": "s",
    "h": "h",
    "R": "R",
    "theta": r"\theta",
    "r": "r",
    "W": "W",
    "E": "E",
    "P": "P",
    "p": "p",
    "mu": r"\mu",
    "g": "g",
    "k": "k",
    "x": "x",
    "T": "T",
    "f": "f",
    "lambda": r"\lambda",
    "V": "V",
    "I": "I",
    "R_e": "R",
    "Q": "Q",
    "C": "C",
    "B": "B",
    "l": "l",
    "d": "d",
    "n": "n",
    "rho": r"\rho",
    "N": "N",
    "A": "A",
    "q": "q",
    "z": "z",
    "u_l": "u",
    "v_l": "v",
    "magnification": "m",
    "Phi": r"\Phi",
    "N_turns": "N",
    "omega": r"\omega",
    "c": "c",
    "L": "L",
    "Delta_T": r"\Delta T",
}

_SYMBOL_WORDS = {
    "m": "mass",
    "M": "mass of the other object",
    "F": "force",
    "a": "acceleration",
    "u": "initial velocity",
    "v": "final velocity",
    "t": "time",
    "s": "distance",
    "h": "height",
    "R": "range",
    "r": "radius",
    "W": "weight",
    "E": "energy",
    "P": "power",
    "p": "pressure",
    "g": "gravitational field strength",
    "k": "spring constant",
    "x": "extension",
    "T": "period",
    "f": "frequency",
    "V": "voltage",
    "I": "current",
    "Q": "charge",
    "C": "capacitance",
    "B": "magnetic field strength",
    "l": "length of conductor",
    "d": "distance",
    "n": "amount of substance",
    "rho": "density",
    "N": "number of turns",
    "q": "charge",
    "z": "distance from lens or mirror",
    "u_l": "object distance",
    "v_l": "image distance",
    "c": "specific heat capacity",
    "L": "specific latent heat",
    "Delta_T": "temperature change",
}

_UNKNOWN_PHRASES: tuple[tuple[str, tuple[str, ...]], ...] = (
    (
        "a",
        ("acceleration", "accelerates", "accelerating", "deceleration", "retardation"),
    ),
    (
        "v",
        (
            "final velocity",
            "final speed",
            "velocity after",
            "speed after",
            "reaches",
            "attains",
        ),
    ),
    ("u", ("initial velocity", "initial speed")),
    ("v", ("velocity", "speed")),
    ("t", ("time", "how long", "takes", "duration")),
    ("s", ("distance", "how far", "displacement", "covers", "travels")),
    ("h", ("height", "how high", "vertical distance", "falls from")),
    ("R", ("range", "horizontal distance")),
    ("F", ("force", "resultant", "net force")),
    ("W", ("weight",)),
    ("E", ("kinetic energy", "energy", "work done", "work")),
    ("P", ("power",)),
    ("p", ("pressure",)),
    ("f", ("frequency",)),
    ("T", ("period",)),
    ("lambda", ("wavelength",)),
    ("V", ("voltage", "potential difference", "pd", "emf")),
    ("I", ("current",)),
    ("R_e", ("resistance",)),
    ("Q", ("charge", "quantity of charge")),
    ("C", ("capacitance",)),
    ("x", ("extension", "compression", "stretch")),
    ("k", ("spring constant", "stiffness")),
    ("r", ("radius",)),
    ("rho", ("density",)),
    ("n", ("number of moles", "moles")),
    ("z", ("image distance",)),
    ("u_l", ("object distance",)),
    ("magnification", ("magnification",)),
    ("theta", ("angle of", "angle")),
)

_DIMENSION_SYMBOL_PRIORITY: tuple[tuple[Dimension, tuple[str, ...]], ...] = (
    (MASS, ("m", "M")),
    (FORCE, ("F", "W")),
    (ACCELERATION, ("a", "g")),
    (SPEED, ("u", "v")),
    (TIME, ("t", "T")),
    (LENGTH, ("s", "h", "r", "d", "l", "R")),
    (ENERGY, ("E",)),
    (POWER, ("P",)),
    (PRESSURE, ("p",)),
    (VOLTAGE, ("V",)),
    (Dimension(current=1), ("I",)),
    (RESISTANCE, ("R_e",)),
    (CAPACITANCE, ("C",)),
    (CHARGE, ("Q", "q")),
    (FREQUENCY, ("f",)),
    (MAGNETIC_FIELD, ("B",)),
    (DENSITY, ("rho",)),
    (TEMPERATURE, ("theta",)),
    (VOLUME, ("N",)),
)

_ANCHOR_PATTERNS: dict[str, tuple[str, ...]] = {
    "mass": (r"\bmass\b", r"\bweighs?\b", r"\bof mass\b", r"\bblock of\b"),
    "force": (
        r"\bforce\b",
        r"\bpush(?:es|ed)?\b",
        r"\bpull(?:s|ed)?\b",
        r"\bapplied\b",
        r"\bweight\b",
        r"\bgravity\b",
        r"\bfriction\b",
        r"\btension\b",
        r"\breaction\b",
        r"\bnormal force\b",
    ),
    "acceleration": (
        r"\bacceleration\b",
        r"\baccelerat\w*",
        r"\bdecelerat\w*",
        r"\bretardation\b",
        r"\bg\b",
    ),
    "initial_velocity": (
        r"\binitial (?:velocity|speed)\b",
        r"\bu\b",
        r"\bstarts?\b",
        r"\bbegins?\b",
    ),
    "final_velocity": (
        r"\bfinal (?:velocity|speed)\b",
        r"\breaches?\b",
        r"\battains?\b",
        r"\bvelocity\b",
        r"\bspeed\b",
    ),
    "time": (
        r"\btime\b",
        r"\bafter\b",
        r"\bfor\b",
        r"\btakes?\b",
        r"\bin \d",
        r"\bduration\b",
        r"\bseconds?\b",
    ),
    "distance": (
        r"\bdistance\b",
        r"\btravels?\b",
        r"\bmoves?\b",
        r"\bcovers?\b",
        r"\bwalks?\b",
        r"\bdisplacement\b",
    ),
    "height": (
        r"\bheight\b",
        r"\bhigh\b",
        r"\bvertically\b",
        r"\bfalls?\b",
        r"\bdrop(?:ped|s)?\b",
        r"\babove\b",
    ),
    "range": (r"\brange\b", r"\bhorizontal distance\b"),
    "angle": (
        r"\bangle\b",
        r"\binclined\b",
        r"\bslope\b",
        r"\bhills?\b",
        r"\bat \d+ ?(?:deg|°|degrees)\b",
    ),
    "radius": (
        r"\bradius\b",
        r"\bcircular\b",
        r"\bcircle\b",
        r"\borbit\w*",
        r"\brotat\w*",
        r"\brevolv\w*",
        r"\bturns?\b",
        r"\bcentre\b",
    ),
    "spring_constant": (r"\bspring constant\b", r"\bstiffness\b"),
    "friction": (
        r"\bfriction\b",
        r"\bcoefficient of (?:friction|friction)\b",
        r"\brough\b",
        r"\bsmooth\b",
    ),
    "voltage": (
        r"\bvoltage\b",
        r"\bpotential difference\b",
        r"\bp\.d\.\b",
        r"\bemf\b",
        r"\bsupply\b",
    ),
    "current": (r"\bcurrent\b", r"\bamps?\b", r"\bamperes?\b"),
    "resistance": (r"\bresistance\b", r"\bresistor\w*\b"),
    "charge": (r"\bcharge\b", r"\bcharged\b"),
    "capacitance": (r"\bcapacitance\b", r"\bcapacitor\w*\b"),
    "frequency": (r"\bfrequency\b", r"\bfrequent\w*\b"),
    "wavelength": (r"\bwavelength\b"),
    "period": (r"\bperiod\b", r"\btime period\b"),
    "object_distance": (r"\bobject\b",),
    "image_distance": (r"\bimage\b",),
    "focal": (r"\bfocal\b",),
    "refractive_index": (
        r"\brefractive index\b",
        r"\bindex of refraction\b",
        r"\brefraction\b",
        r"\bsnell's law\b",
    ),
    "magnetic_field": (r"\bmagnetic\b", r"\bflux\b", r"\bfield\b"),
    "density": (r"\bdensity\b", r"\bdense\b"),
    "pressure": (r"\bpressure\b"),
    "temperature": (r"\btemperature\b", r"\bheat\b", r"\bthermal\b"),
}


@dataclass(frozen=True)
class Measurement:
    """One number-and-unit occurrence, kept in its textual context."""

    quantity: Quantity
    start: int
    end: int
    before: str
    after: str

    @property
    def context(self) -> str:
        return f"{self.before} {self.quantity.latex} {self.after}".strip()


class PhysicsContext:
    """All measurements of a question plus keyword-aware lookup helpers."""

    def __init__(self, text: str) -> None:
        self.text = text
        self.lowered = text.lower()
        self.measurements: list[Measurement] = []
        cursor = 0
        for quantity_value in extract_measurements(text):
            match = re.search(re.escape(_plain(quantity_value.value)), text[cursor:])
            if match:
                start = cursor + match.start()
                cursor = cursor + match.end()
            else:
                start = cursor
            self.measurements.append(
                Measurement(
                    quantity=quantity_value,
                    start=start,
                    end=start + 1,
                    before=text[:start],
                    after=text[start + 1 :],
                )
            )

    def by_dimension(self, dimension: Dimension) -> list[Quantity]:
        return [
            m.quantity for m in self.measurements if m.quantity.dimension == dimension
        ]

    def count(self, dimension: Dimension) -> int:
        return len(self.by_dimension(dimension))

    def first(self, dimension: Dimension) -> Quantity | None:
        found = self.by_dimension(dimension)
        return found[0] if found else None

    def nth(self, dimension: Dimension, index: int) -> Quantity | None:
        found = self.by_dimension(dimension)
        if 0 <= index < len(found):
            return found[index]
        return None

    def after_keyword(self, keyword: str) -> Quantity | None:
        """First measurement that follows one of the keyword's patterns."""
        patterns = _ANCHOR_PATTERNS.get(keyword, (rf"\b{re.escape(keyword)}\b",))
        best: Measurement | None = None
        best_distance = 10**9
        for pattern in patterns:
            for match in re.finditer(pattern, self.lowered):
                for measurement in self.measurements:
                    if measurement.start < match.end() - 1:
                        continue
                    distance = measurement.start - match.end()
                    if distance < best_distance and distance <= 40:
                        best = measurement
                        best_distance = distance
        return best.quantity if best else None

    def dimensionless_after(self, keyword: str) -> float | None:
        """A bare number straight after a keyword, e.g. friction coefficient."""
        match = re.search(rf"\b{re.escape(keyword)}\b", self.lowered)
        if not match:
            return None
        tail = self.text[match.end() :]
        number = re.search(r"-?\d+(?:\.\d+)?", tail[:40])
        if number and not tail[: number.start()].strip(" ,="):
            return float(number.group(0))
        return None

    def gravity(self) -> float:
        """Gravitational field strength, 9.81 m/s^2 unless stated."""
        explicit = re.search(
            r"(?:g\s*=\s*|gravity(?: field strength)?(?: is| =)?)\s*"
            r"(-?\d+(?:\.\d+)?)\s*(?:m/s\^?2|m/s²)?",
            self.text,
            re.IGNORECASE,
        )
        if explicit:
            return float(explicit.group(1))
        named = re.search(r"take\s+g\s*=\s*(-?\d+(?:\.\d+)?)", self.text, re.IGNORECASE)
        if named:
            return float(named.group(1))
        return DEFAULT_GRAVITY

    def mentions(self, *needles: str) -> bool:
        return any(needle in self.lowered for needle in needles)


def _plain(value: float) -> str:
    if abs(value - round(value)) < 1e-12:
        return str(int(round(value)))
    return f"{value:g}"


def find_unknowns(text: str) -> list[str]:
    """Symbols the question asks for, most specific first."""
    lowered = text.lower()
    question_zone = lowered
    for marker in (
        "find",
        "calculate",
        "determine",
        "work out",
        "what is",
        "what's",
        "show that",
        "compute",
        "how far",
        "how long",
        "how high",
        "how much",
    ):
        if marker in lowered:
            question_zone = lowered[lowered.index(marker) :]
            break
    found: list[str] = []
    seen: set[str] = set()
    for symbol, phrases in _UNKNOWN_PHRASES:
        for phrase in phrases:
            if phrase in question_zone and symbol not in seen:
                found.append(symbol)
                seen.add(symbol)
                break
    return found


def unknown_latex(symbol: str) -> str:
    return SYMBOL_LATEX.get(symbol, symbol)


def unknown_word(symbol: str) -> str:
    return _SYMBOL_WORDS.get(symbol, symbol)
