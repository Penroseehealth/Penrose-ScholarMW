"""Question intent guards for the mathematics tutor.

The dispatcher in :mod:`app.mathematics.tutor` tries one topic solver after
another, so every solver needs a cheap test that says "this question really is
mine" before it starts computing. Without that test a broad keyword such as
"triangle" captures questions it cannot answer and the tutor returns a
confidently wrong result instead of asking.
"""

from __future__ import annotations

# Phrases that only ever describe a right-angled triangle, so their presence is
# enough on its own.
_STRONG_PYTHAGORAS_SIGNALS = (
    "pythagor",
    "right angle",
    "right-angled",
    "right angled",
    "hypotenuse",
)

# Triangle questions that Pythagoras cannot answer. If one of these shows up we
# must not reach for a side-length calculation.
_OTHER_TRIANGLE_TOPICS = (
    "angle",
    "ratio",
    "area",
    "perimeter",
    "circumference",
    "similar",
    "congruent",
    "isosceles",
    "equilateral",
    "scalene",
    "acute",
    "obtuse",
    "median",
    "bisector",
    "incentre",
    "inradius",
    "incircle",
    "exterior",
    "interior",
)

# Topics that are never Pythagoras even when a triangle is mentioned.
_NON_GEOMETRY_HINTS = (
    "probability",
    "mean",
    "median of",
    "mode",
    "sequence",
    "series",
    "function",
    "gradient",
    "probability",
)


def mentions(lowered: str, *needles: str) -> bool:
    """True when any of *needles* appears in the already-lowercased text."""
    return any(needle in lowered for needle in needles)


def looks_like_pythagoras(lowered: str) -> bool:
    """True only when the question genuinely asks about a right-angled triangle.

    ``"The angles of a triangle are in the ratio 2:3:4"`` mentions a triangle but
    asks for angles, so it must reach the triangle-angles solver rather than the
    Pythagorean one.
    """
    if any(signal in lowered for signal in _STRONG_PYTHAGORAS_SIGNALS):
        return True
    if "triangle" not in lowered:
        return False
    if any(topic in lowered for topic in _OTHER_TRIANGLE_TOPICS):
        return False
    if any(hint in lowered for hint in _NON_GEOMETRY_HINTS):
        return False
    return True
