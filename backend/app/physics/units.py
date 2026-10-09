"""Unit-aware physical quantities for the physics engine.

Every number the physics engine computes carries a unit. Internally all
quantities are held in SI base units, while the original unit is remembered so
the worked solution can show the student's own notation and display the
conversion (``72 km/h -> 20 m/s``) as an explicit step.

Compound units such as ``m/s``, ``m/s^2``, ``N/m`` and ``J/(kg K)`` are parsed
from their symbol strings, so a solver never needs a bespoke entry for every
law it uses.
"""

from __future__ import annotations

import math
import re
from dataclasses import dataclass
from typing import Iterator

# Base dimensions: length, mass, time, current, temperature, amount, luminous.
_DIMENSION_WORDS = {
    (1, 0, 0, 0, 0, 0, 0): "length",
    (0, 1, 0, 0, 0, 0, 0): "mass",
    (0, 0, 1, 0, 0, 0, 0): "time",
    (0, 0, 0, 1, 0, 0, 0): "electric current",
    (0, 0, 0, 0, 1, 0, 0): "temperature",
    (0, 0, 0, 0, 0, 1, 0): "amount of substance",
    (0, 0, 0, 0, 0, 0, 1): "luminous intensity",
    (0, 0, 0, 0, 0, 0, 0): "a dimensionless quantity",
    (2, 0, 0, 0, 0, 0, 0): "area",
    (3, 0, 0, 0, 0, 0, 0): "volume",
    (1, 0, -1, 0, 0, 0, 0): "speed",
    (1, 0, -2, 0, 0, 0, 0): "acceleration",
    (2, 1, -2, 0, 0, 0, 0): "energy",
    (2, 1, -3, 0, 0, 0, 0): "power",
    (1, 1, -2, 0, 0, 0, 0): "force",
    (0, 1, -2, 0, 0, 0, 0): "pressure",
    (1, 1, -1, 0, 0, 0, 0): "momentum",
    (0, 0, 1, 1, 0, 0, 0): "charge",
    (2, 1, -3, -1, 0, 0, 0): "voltage",
    (2, 1, -3, -2, 0, 0, 0): "resistance",
    (-2, -1, 4, 2, 0, 0, 0): "capacitance",
    (0, 0, -1, 0, 0, 0, 0): "frequency",
    (0, 1, -2, -1, 0, 0, 0): "magnetic field",
    (2, 1, -2, -1, 0, 0, 0): "magnetic flux",
}


@dataclass(frozen=True, order=True)
class Dimension:
    """Exponents of the seven SI base dimensions."""

    length: int = 0
    mass: int = 0
    time: int = 0
    current: int = 0
    temperature: int = 0
    amount: int = 0
    luminous: int = 0

    @property
    def key(self) -> tuple[int, ...]:
        return (
            self.length,
            self.mass,
            self.time,
            self.current,
            self.temperature,
            self.amount,
            self.luminous,
        )

    @property
    def is_dimensionless(self) -> bool:
        return self.key == (0, 0, 0, 0, 0, 0, 0)

    @property
    def word(self) -> str:
        return _DIMENSION_WORDS.get(self.key, "a compound quantity")

    def __mul__(self, other: Dimension) -> Dimension:
        return Dimension(*(a + b for a, b in zip(self.key, other.key, strict=True)))

    def __truediv__(self, other: Dimension) -> Dimension:
        return Dimension(*(a - b for a, b in zip(self.key, other.key, strict=True)))

    def __pow__(self, exponent: int) -> Dimension:
        return Dimension(*(a * exponent for a in self.key))


DIMENSIONLESS = Dimension()
LENGTH = Dimension(length=1)
MASS = Dimension(mass=1)
TIME = Dimension(time=1)
AREA = LENGTH**2
VOLUME = LENGTH**3
SPEED = LENGTH / TIME
ACCELERATION = SPEED / TIME
FORCE = MASS * ACCELERATION
ENERGY = FORCE * LENGTH
POWER = ENERGY / TIME
PRESSURE = FORCE / AREA
CHARGE = Dimension(current=1) * TIME
CURRENT = Dimension(current=1)
VOLTAGE = ENERGY / CHARGE
RESISTANCE = VOLTAGE / Dimension(current=1)
CAPACITANCE = CHARGE / VOLTAGE
FREQUENCY = TIME**-1
MAGNETIC_FIELD = FORCE / (Dimension(current=1) * LENGTH)
MAGNETIC_FLUX = VOLTAGE * TIME
MOMENTUM = MASS * SPEED
DENSITY = MASS / VOLUME
TEMPERATURE = Dimension(temperature=1)
ANGLE = DIMENSIONLESS


@dataclass(frozen=True)
class _UnitDef:
    factor: float
    dimension: Dimension
    latex: str
    offset: float = 0.0


_UNITS: dict[str, _UnitDef] = {}


def _register(
    symbol: str,
    factor: float,
    dimension: Dimension,
    latex: str,
    offset: float = 0.0,
) -> None:
    _UNITS[symbol] = _UnitDef(
        factor=factor, dimension=dimension, latex=latex, offset=offset
    )


for _symbol, _factor, _dim, _latex in (
    ("km", 1000.0, LENGTH, r"\text{km}"),
    ("m", 1.0, LENGTH, r"\text{m}"),
    ("cm", 0.01, LENGTH, r"\text{cm}"),
    ("mm", 0.001, LENGTH, r"\text{mm}"),
    ("nm", 1e-9, LENGTH, r"\text{nm}"),
    ("ft", 0.3048, LENGTH, r"\text{ft}"),
    ("in", 0.0254, LENGTH, r"\text{in}"),
    ("mi", 1609.344, LENGTH, r"\text{mi}"),
    ("kg", 1.0, MASS, r"\text{kg}"),
    ("g", 0.001, MASS, r"\text{g}"),
    ("mg", 1e-6, MASS, r"\text{mg}"),
    ("t", 1000.0, MASS, r"\text{t}"),
    ("lb", 0.45359237, MASS, r"\text{lb}"),
    ("s", 1.0, TIME, r"\text{s}"),
    ("ms", 0.001, TIME, r"\text{ms}"),
    ("min", 60.0, TIME, r"\text{min}"),
    ("h", 3600.0, TIME, r"\text{h}"),
    ("hr", 3600.0, TIME, r"\text{h}"),
    ("day", 86400.0, TIME, r"\text{day}"),
    ("year", 31557600.0, TIME, r"\text{year}"),
    ("m/s", 1.0, SPEED, r"\text{m/s}"),
    ("cm/s", 0.01, SPEED, r"\text{cm/s}"),
    ("km/h", 1.0 / 3.6, SPEED, r"\text{km/h}"),
    ("km/hr", 1.0 / 3.6, SPEED, r"\text{km/h}"),
    ("mph", 0.44704, SPEED, r"\text{mph}"),
    ("m/s^2", 1.0, ACCELERATION, r"\text{m/s}^2"),
    ("cm/s^2", 0.01, ACCELERATION, r"\text{cm/s}^2"),
    ("N", 1.0, FORCE, r"\text{N}"),
    ("kN", 1000.0, FORCE, r"\text{kN}"),
    ("MN", 1e6, FORCE, r"\text{MN}"),
    ("dyne", 1e-5, FORCE, r"\text{dyne}"),
    ("J", 1.0, ENERGY, r"\text{J}"),
    ("kJ", 1000.0, ENERGY, r"\text{kJ}"),
    ("MJ", 1e6, ENERGY, r"\text{MJ}"),
    ("cal", 4.184, ENERGY, r"\text{cal}"),
    ("kcal", 4184.0, ENERGY, r"\text{kcal}"),
    ("eV", 1.602176634e-19, ENERGY, r"\text{eV}"),
    ("kWh", 3.6e6, ENERGY, r"\text{kWh}"),
    ("W", 1.0, POWER, r"\text{W}"),
    ("kW", 1000.0, POWER, r"\text{kW}"),
    ("MW", 1e6, POWER, r"\text{MW}"),
    ("hp", 745.699872, POWER, r"\text{hp}"),
    ("Pa", 1.0, PRESSURE, r"\text{Pa}"),
    ("kPa", 1000.0, PRESSURE, r"\text{kPa}"),
    ("MPa", 1e6, PRESSURE, r"\text{MPa}"),
    ("bar", 1e5, PRESSURE, r"\text{bar}"),
    ("atm", 101325.0, PRESSURE, r"\text{atm}"),
    ("mmHg", 133.322, PRESSURE, r"\text{mmHg}"),
    ("psi", 6894.757, PRESSURE, r"\text{psi}"),
    ("C", 1.0, CHARGE, r"\text{C}"),
    ("mC", 1e-3, CHARGE, r"\text{mC}"),
    ("uC", 1e-6, CHARGE, r"\mu\text{C}"),
    ("nC", 1e-9, CHARGE, r"\text{nC}"),
    ("V", 1.0, VOLTAGE, r"\text{V}"),
    ("mV", 1e-3, VOLTAGE, r"\text{mV}"),
    ("kV", 1000.0, VOLTAGE, r"\text{kV}"),
    ("A", 1.0, Dimension(current=1), r"\text{A}"),
    ("mA", 1e-3, Dimension(current=1), r"\text{mA}"),
    ("uA", 1e-6, Dimension(current=1), r"\mu\text{A}"),
    ("ohm", 1.0, RESISTANCE, r"\Omega"),
    ("Ω", 1.0, RESISTANCE, r"\Omega"),
    ("kohm", 1000.0, RESISTANCE, r"\text{k}\Omega"),
    ("kΩ", 1000.0, RESISTANCE, r"\text{k}\Omega"),
    ("Mohm", 1e6, RESISTANCE, r"\text{M}\Omega"),
    ("MΩ", 1e6, RESISTANCE, r"\text{M}\Omega"),
    ("F", 1.0, CAPACITANCE, r"\text{F}"),
    ("mF", 1e-3, CAPACITANCE, r"\text{mF}"),
    ("uF", 1e-6, CAPACITANCE, r"\mu\text{F}"),
    ("nF", 1e-9, CAPACITANCE, r"\text{nF}"),
    ("pF", 1e-12, CAPACITANCE, r"\text{pF}"),
    ("Hz", 1.0, FREQUENCY, r"\text{Hz}"),
    ("kHz", 1e3, FREQUENCY, r"\text{kHz}"),
    ("MHz", 1e6, FREQUENCY, r"\text{MHz}"),
    ("GHz", 1e9, FREQUENCY, r"\text{GHz}"),
    ("T", 1.0, MAGNETIC_FIELD, r"\text{T}"),
    ("mT", 1e-3, MAGNETIC_FIELD, r"\text{mT}"),
    ("G", 1e-4, MAGNETIC_FIELD, r"\text{G}"),
    ("Wb", 1.0, MAGNETIC_FLUX, r"\text{Wb}"),
    ("mWb", 1e-3, MAGNETIC_FLUX, r"\text{mWb}"),
    ("kg/m^3", 1.0, DENSITY, r"\text{kg/m}^3"),
    ("g/cm^3", 1000.0, DENSITY, r"\text{g/cm}^3"),
    ("kg m/s", 1.0, MOMENTUM, r"\text{kg m/s}"),
    ("N/m", 1.0, FORCE / LENGTH, r"\text{N/m}"),
    ("J/kg", 1.0, ENERGY / MASS, r"\text{J/kg}"),
    ("J/(kg K)", 1.0, ENERGY / MASS / TEMPERATURE, r"\text{J/(kg K)}"),
    ("K", 1.0, TEMPERATURE, r"\text{K}"),
    ("rad", 1.0, ANGLE, r"\text{rad}"),
    ("deg", math.pi / 180.0, ANGLE, r"^{\circ}"),
    ("°", math.pi / 180.0, ANGLE, r"^{\circ}"),
    ("%", 0.01, DIMENSIONLESS, r"\%"),
    ("m^3", 1.0, VOLUME, r"\text{m}^3"),
    ("cm^3", 1e-6, VOLUME, r"\text{cm}^3"),
    ("mL", 1e-6, VOLUME, r"\text{mL}"),
    ("L", 1e-3, VOLUME, r"\text{L}"),
    ("m^2", 1.0, AREA, r"\text{m}^2"),
    ("cm^2", 1e-4, AREA, r"\text{cm}^2"),
    ("mm^2", 1e-6, AREA, r"\text{mm}^2"),
):
    _register(_symbol, _factor, _dim, _latex)

_register("°C", 1.0, TEMPERATURE, r"^{\circ}\text{C}", 273.15)

_ALIASES = {
    "metre": "m",
    "metres": "m",
    "meter": "m",
    "meters": "m",
    "kilometre": "km",
    "kilometres": "km",
    "kilometer": "km",
    "kilometers": "km",
    "centimetre": "cm",
    "centimetres": "cm",
    "centimeter": "cm",
    "centimeters": "cm",
    "millimetre": "mm",
    "millimetres": "mm",
    "millimeter": "mm",
    "millimeters": "mm",
    "kilogram": "kg",
    "kilograms": "kg",
    "gram": "g",
    "grams": "g",
    "second": "s",
    "seconds": "s",
    "minute": "min",
    "minutes": "min",
    "hour": "h",
    "hours": "h",
    "newton": "N",
    "newtons": "N",
    "joule": "J",
    "joules": "J",
    "watt": "W",
    "watts": "W",
    "pascal": "Pa",
    "pascals": "Pa",
    "volt": "V",
    "volts": "V",
    "amps": "A",
    "ampere": "A",
    "amperes": "A",
    "ohms": "ohm",
    "farad": "F",
    "farads": "F",
    "hertz": "Hz",
    "tesla": "T",
    "teslas": "T",
    "weber": "Wb",
    "webers": "Wb",
    "coulomb": "C",
    "coulombs": "C",
    "microcoulomb": "uC",
    "microcoulombs": "uC",
    "millicoulomb": "mC",
    "millicoulombs": "mC",
    "nanocoulomb": "nC",
    "nanocoulombs": "nC",
    "microampere": "uA",
    "microamperes": "uA",
    "microamps": "uA",
    "milliampere": "mA",
    "milliamperes": "mA",
    "milliamps": "mA",
    "millivolt": "mV",
    "millivolts": "mV",
    "kilovolt": "kV",
    "kilovolts": "kV",
    "microfarad": "uF",
    "microfarads": "uF",
    "millifarad": "mF",
    "millifarads": "mF",
    "nanofarad": "nF",
    "nanofarads": "nF",
    "kiloohm": "kohm",
    "kiloohms": "kohm",
    "megaohm": "Mohm",
    "megaohms": "Mohm",
    "kelvin": "K",
    "liter": "L",
    "liters": "L",
    "litre": "L",
    "litres": "L",
    "degree": "deg",
    "degrees": "deg",
    "celsius": "°C",
    "Celsius": "°C",
    "J/(kgK)": "J/(kg K)",
    "μC": "uC",
    "μF": "uF",
    "μA": "uA",
}

_UNIT_TOKEN_RE = re.compile(
    r"(?:"
    r"km/(?:h|hr)|m/s(?:\^?[2²])?|cm/s(?:\^?[2²])?|"
    r"kg/m\^?3|g/cm\^?3|kg\s*m/s|N/m|J/\(kg\s*(?:K|°C)\)|J/kg|"
    r"m\^?[2³]|cm\^?[2³]|m\^?3|mm\^?2|"
    r"[A-Za-zμΩ°]+[²³]?"
    r")"
)

_NUMBER_RE = re.compile(r"-?\d+(?:\.\d+)?")

_SI_SYMBOLS = {
    (1, 0, 0, 0, 0, 0, 0): "m",
    (0, 1, 0, 0, 0, 0, 0): "kg",
    (0, 0, 1, 0, 0, 0, 0): "s",
    (0, 0, 0, 1, 0, 0, 0): "A",
    (0, 0, 0, 0, 1, 0, 0): "K",
    (1, 0, -1, 0, 0, 0, 0): "m/s",
    (1, 0, -2, 0, 0, 0, 0): "m/s^2",
    (1, 1, -2, 0, 0, 0, 0): "N",
    (2, 1, -2, 0, 0, 0, 0): "J",
    (2, 1, -3, 0, 0, 0, 0): "W",
    (0, 1, -2, 0, 0, 0, 0): "Pa",
    (0, 0, 1, 1, 0, 0, 0): "C",
    (2, 1, -3, -1, 0, 0, 0): "V",
    (2, 1, -3, -2, 0, 0, 0): "ohm",
    (-2, -1, 4, 2, 0, 0, 0): "F",
    (0, 0, -1, 0, 0, 0, 0): "Hz",
    (0, 1, -2, -1, 0, 0, 0): "T",
    (2, 1, -2, -1, 0, 0, 0): "Wb",
    (1, 1, -1, 0, 0, 0, 0): "kg m/s",
}


@dataclass(frozen=True)
class Quantity:
    """A measured value together with its unit."""

    value: float
    unit: str

    @property
    def definition(self) -> _UnitDef | None:
        return _UNITS.get(self.unit)

    @property
    def dimension(self) -> Dimension:
        definition = self.definition
        return definition.dimension if definition else DIMENSIONLESS

    @property
    def si_factor(self) -> float:
        definition = self.definition
        return definition.factor if definition else 1.0

    @property
    def si_offset(self) -> float:
        definition = self.definition
        return definition.offset if definition else 0.0

    @property
    def si_value(self) -> float:
        return self.value * self.si_factor + self.si_offset

    @property
    def latex(self) -> str:
        return f"{fmt_number(self.value)}\\ {unit_latex(self.unit)}"

    def to_si(self) -> Quantity:
        """Return the same measurement expressed in coherent SI units."""
        return convert(self, si_symbol(self.dimension))

    def to(self, unit: str) -> Quantity:
        return convert(self, unit)


def fmt_number(value: float) -> str:
    """Compact display form used in steps, LaTeX and narration."""
    if abs(value - round(value)) < 1e-12:
        return str(int(round(value)))
    return f"{round(value, 6):g}"


def spoken(value: float) -> str:
    """Number as it should appear in a narration script."""
    if abs(value - round(value)) < 1e-12:
        return str(int(round(value)))
    return f"{value:.2f}".rstrip("0").rstrip(".")


def si_symbol(dimension: Dimension) -> str:
    """Preferred SI display unit for *dimension*."""
    return _SI_SYMBOLS.get(dimension.key, "units")


def lookup_unit(symbol: str) -> _UnitDef | None:
    return _UNITS.get(symbol)


def unit_latex(symbol: str) -> str:
    definition = _UNITS.get(symbol)
    if definition:
        return definition.latex
    if not symbol:
        return ""
    try:
        _, _, latex = parse_compound_unit(symbol)
        return latex
    except ValueError:
        return r"\text{" + symbol + "}"


def convert(quantity: Quantity, target_unit: str) -> Quantity:
    """Convert *quantity* into *target_unit*, checking dimensional fit."""
    target = _UNITS.get(target_unit)
    if target is None:
        raise ValueError(f"Unknown unit: {target_unit}")
    if quantity.dimension != target.dimension:
        raise ValueError(
            f"Cannot convert {quantity.unit} ({quantity.dimension.word}) "
            f"into {target_unit} ({target.dimension.word})."
        )
    value = (quantity.si_value - target.offset) / target.factor
    return Quantity(value=value, unit=target_unit)


def quantity(value: float, unit: str) -> Quantity:
    if not unit or unit in _UNITS:
        return Quantity(value=value, unit=unit)
    factor, dimension, _ = parse_compound_unit(unit)
    return Quantity(value=value * factor, unit=si_symbol(dimension))


def is_known_unit(symbol: str) -> bool:
    return symbol in _UNITS


def normalise_unit_token(token: str) -> str:
    """Fold common spellings and unicode onto the registry's symbol."""
    cleaned = token.strip().replace(" ", "")
    cleaned = cleaned.replace("²", "^2").replace("³", "^3")
    if cleaned in _UNITS:
        return cleaned
    if cleaned in _ALIASES:
        return _ALIASES[cleaned]
    lowered = cleaned.lower()
    if lowered in _ALIASES:
        return _ALIASES[lowered]
    if lowered in _UNITS:
        return lowered
    return cleaned


def extract_measurements(text: str) -> list[Quantity]:
    """All number-and-unit measurements in *text*, in reading order.

    A unit only counts when it directly follows a number, so ordinary English
    words such as the "in" in "in the ratio" are never read as inches.
    """
    measurements: list[Quantity] = []
    for match in _UNIT_TOKEN_RE.finditer(text):
        start = match.start()
        prefix = text[:start].rstrip()
        number_match = None
        for candidate in _NUMBER_RE.finditer(prefix):
            number_match = candidate
        if number_match is None or prefix[number_match.end() :].strip():
            continue
        value = float(number_match.group(0))
        symbol = normalise_unit_token(match.group(0))
        if symbol in _UNITS:
            measurements.append(Quantity(value=value, unit=symbol))
            continue
        try:
            factor, dimension, _ = parse_compound_unit(symbol)
        except ValueError:
            continue
        measurements.append(Quantity(value=value * factor, unit=si_symbol(dimension)))
    return measurements


def parse_compound_unit(symbol: str) -> tuple[float, Dimension, str]:
    """Resolve a compound unit symbol into ``(factor, dimension, latex)``.

    Handles products and quotients such as ``m/s``, ``kg m/s``, ``N/m``,
    ``m/s^2`` and ``J/(kg K)``. Raises ``ValueError`` for unknown parts.
    """
    tokens = list(_tokenise_unit(symbol))
    if not tokens:
        raise ValueError(f"Empty unit: {symbol}")
    position = 0

    def parse_expression() -> tuple[float, Dimension, str]:
        nonlocal position
        factor, dimension, latex = parse_product()
        while position < len(tokens) and tokens[position] in {"*", "·"}:
            position += 1
            right_factor, right_dimension, right_latex = parse_product()
            factor *= right_factor
            dimension = dimension * right_dimension
            latex = latex + r"\cdot" + right_latex
        return factor, dimension, latex

    def parse_product() -> tuple[float, Dimension, str]:
        nonlocal position
        factor, dimension, latex = parse_atom()
        while position < len(tokens):
            token = tokens[position]
            if token == "/":
                position += 1
                right_factor, right_dimension, right_latex = parse_atom()
                factor /= right_factor
                dimension = dimension / right_dimension
                if r"\cdot" in right_latex:
                    right_latex = r"\left(" + right_latex + r"\right)"
                latex = latex + r"/" + right_latex
                continue
            if token == "*":
                position += 1
                right_factor, right_dimension, right_latex = parse_atom()
                factor *= right_factor
                dimension = dimension * right_dimension
                latex = latex + r"\cdot" + right_latex
                continue
            if token in _UNITS or token == "(":
                right_factor, right_dimension, right_latex = parse_atom()
                factor *= right_factor
                dimension = dimension * right_dimension
                latex = latex + r"\cdot" + right_latex
                continue
            break
        return factor, dimension, latex

    def parse_atom() -> tuple[float, Dimension, str]:
        nonlocal position
        if position >= len(tokens):
            raise ValueError(f"Dangling operator in unit: {symbol}")
        token = tokens[position]
        if token == "(":
            position += 1
            factor, dimension, latex = parse_expression()
            if position >= len(tokens) or tokens[position] != ")":
                raise ValueError(f"Unbalanced brackets in unit: {symbol}")
            position += 1
            return factor, dimension, latex
        if token not in _UNITS:
            raise ValueError(f"Unknown unit part: {token}")
        definition = _UNITS[token]
        position += 1
        exponent = 1
        if position < len(tokens) and tokens[position] == "^":
            position += 1
            if position >= len(tokens) or not tokens[position].lstrip("-").isdigit():
                raise ValueError(f"Bad exponent in unit: {symbol}")
            exponent = int(tokens[position])
            position += 1
        latex = definition.latex
        if abs(exponent) > 1:
            latex = f"{latex}^{{{exponent}}}"
        return (
            definition.factor**exponent,
            definition.dimension**exponent,
            latex,
        )

    factor, dimension, latex = parse_expression()
    if position != len(tokens):
        raise ValueError(f"Could not fully parse unit: {symbol}")
    return factor, dimension, latex


def _tokenise_unit(symbol: str) -> Iterator[str]:
    cleaned = symbol.replace(" ", "").replace("·", "*")
    cleaned = cleaned.replace("²", "^2").replace("³", "^3")
    index = 0
    known = sorted(_UNITS, key=len, reverse=True)
    while index < len(cleaned):
        char = cleaned[index]
        if char in "()*/^":
            yield char
            index += 1
            continue
        if char.isdigit() or (char == "-" and index + 1 < len(cleaned)):
            end = index + 1
            while end < len(cleaned) and cleaned[end].isdigit():
                end += 1
            yield cleaned[index:end]
            index = end
            continue
        for entry in known:
            if cleaned.startswith(entry, index):
                yield entry
                index += len(entry)
                break
        else:
            raise ValueError(f"Unknown unit part at {cleaned[index:]!r}")
