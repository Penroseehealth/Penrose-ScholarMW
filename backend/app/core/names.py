"""Helpers for turning a stored full name into something you can greet someone by.

The database only stores ``full_name``, but every greeting, welcome banner and
personalised reply needs a first name. Deriving it here keeps that rule in one
place instead of repeating a fragile ``split(" ")[0]`` at each call site.
"""

from __future__ import annotations

import re

# Separators seen in real sign-up forms: "Amin, J. Doe", "Amin  Doe", "Amin-Doe".
_SEPARATORS = re.compile(r"[\s,;/\-–—]+")

# Titles and honorifics that must never be mistaken for the first name.
# "Bwana" is deliberately absent: it is a common Malawian *given* name, so
# stripping it would turn "Bwana Tiwonge" into the surname.
_TITLES = frozenset(
    {
        "amb",
        "dr",
        "dr.",
        "miss",
        "miss.",
        "mr",
        "mr.",
        "mrs",
        "mrs.",
        "ms",
        "ms.",
        "prof",
        "prof.",
        "professor",
    }
)


def first_name_from(full_name: str | None) -> str:
    """Return the best available first name from ``full_name``.

    Skips any leading title so "Dr Amin J. Doe" greets as "Amin", and returns an
    empty string when there is no usable name so callers can decide on a
    fallback rather than greeting someone as "".
    """
    if not full_name:
        return ""

    parts = [part for part in _SEPARATORS.split(full_name.strip()) if part]
    while parts and parts[0].casefold() in _TITLES:
        parts.pop(0)
    return parts[0] if parts else ""


def greeting_name(full_name: str | None, fallback: str = "there") -> str:
    """A first name for a greeting, falling back when the name is unusable."""
    return first_name_from(full_name) or fallback
