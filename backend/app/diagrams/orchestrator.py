"""Lesson-asset orchestration (Phase 4 of the Asymptote integration).

Deterministic classification of what a student question needs — a scientific
diagram (Asymptote), an interactive 3D scene (Three.js), both, or neither —
followed by real invocation of the Asymptote service when a diagram is planned.

Design notes:
* classification is rule-based and auditable (no LLM in the decision path), so
  it is reproducible in tests and cannot "decide" to skip Asymptote for
  convenience;
* a failed compilation is surfaced verbatim (``ok=False`` + error code) and
  recorded in ``fallback`` with ``recorded_as_asy_success=False`` — a fallback
  is never reported as successful Asymptote execution;
* the Three.js branch returns the presentation workflow (the ``/asy_lab/``
  scene entry point plus the synchronised parameters), which is what the
  frontend needs to show the paired interactive view.
"""

from __future__ import annotations

import re
from typing import Any

from . import service

# Ordered: first match wins. (keywords, diagram kind, three scene)
_RULES: list[tuple[tuple[str, ...], str | None, str | None]] = [
    (
        (
            "exothermic",
            "endothermic",
            "enthalpy",
            "energy profile",
            "reaction profile",
            "activation energy",
            "bond energy",
            "combustion",
        ),
        "energy_profile",
        "energy_platforms",
    ),
    (
        (
            "triangle",
            "pythagoras",
            "pythagorean",
            "hypotenuse",
            "right angle",
            "trigonometr",
            "sine rule",
            "cosine rule",
        ),
        "right_triangle",
        "triangle3d",
    ),
    (
        (
            "circle",
            "circumference",
            "radius",
            "sector of a circle",
            "tangent to the circle",
        ),
        "circle",
        None,
    ),
    (
        (
            "vector",
            "resultant force",
            "magnitude and direction",
            "column vector",
        ),
        "vectors",
        None,
    ),
    (
        (
            "graph of",
            "plot the",
            "sketch the curve",
            "parabola",
            "quadratic graph",
            "gradient of the curve",
            "f(x)",
        ),
        "function_plot",
        None,
    ),
]

_THREE_ONLY = ("3d model", "three-dimensional", "rotate the model", "molecular model")

_LEG_RE = re.compile(
    r"(?:legs?|sides?|a\s*=|b\s*=)\s*(\d+(?:\.\d+)?)\s*(?:and|,|&|x|by)\s*(\d+(?:\.\d+)?)",
    re.I,
)
_DH_RE = re.compile(r"(-?\d+(?:\.\d+)?)\s*kJ", re.I)
_FN_RE = re.compile(r"(?:y\s*=\s*|plot\s+|graph of\s+)([A-Za-z0-9^()+\-*/. ]{2,60})")


def classify_lesson_need(question: str) -> dict[str, Any]:
    """Decide {'decision', 'diagram_kind', 'three_scene', 'reason', 'params'}."""
    q = (question or "").strip()
    low = q.lower()
    for keywords, diagram, three in _RULES:
        hit = next((k for k in keywords if k in low), None)
        if hit:
            return {
                "decision": "both" if (diagram and three) else "diagram",
                "diagram_kind": diagram,
                "three_scene": three,
                "reason": f"matched '{hit}'",
                "params": _extract_params(diagram, q),
            }
    if any(k in low for k in _THREE_ONLY):
        # only scenes that actually exist may be promised; anything else is
        # reported as unpaired rather than mislabelled with an existing scene
        if "triangle" in low:
            scene, why = (
                "triangle3d",
                "3D interaction requested (triangle scene available)",
            )
        elif any(
            k in low
            for k in ("enthalpy", "energy", "exothermic", "endothermic", "reaction")
        ):
            scene, why = (
                "energy_platforms",
                "3D interaction requested (energy scene available)",
            )
        else:
            scene = None
            why = (
                "3D interaction requested; no paired scene implemented yet "
                "(supported: triangle3d, energy_platforms)"
            )
        return {
            "decision": "three",
            "diagram_kind": None,
            "three_scene": scene,
            "reason": why,
            "params": {},
        }
    return {
        "decision": "neither",
        "diagram_kind": None,
        "three_scene": None,
        "reason": "no diagram or 3D model indicated",
        "params": {},
    }


def _extract_params(kind: str | None, q: str) -> dict[str, Any]:
    params: dict[str, Any] = {}
    if kind == "right_triangle":
        m = _LEG_RE.search(q)
        if m:
            params = {"a": float(m.group(1)), "b": float(m.group(2))}
        else:
            params = {"a": 3, "b": 4}
    elif kind == "function_plot":
        m = _FN_RE.search(q)
        if m:
            params = {"fn": m.group(1).strip().rstrip(",."), "xmin": -5, "xmax": 5}
        else:
            params = {"fn": "x^2 - 2", "xmin": -3, "xmax": 3}
    elif kind == "energy_profile":
        m = _DH_RE.search(q)
        dh = float(m.group(1)) if m else -85.0
        exo = "endothermic" not in q
        if exo and dh > 0:
            dh = -dh
        if not exo and dh < 0:
            dh = abs(dh)
        params = {
            "dh_kj": dh,
            "exothermic": exo,
            "title": "Endothermic profile" if not exo else "Exothermic profile",
        }
    elif kind == "circle":
        m = re.search(r"radius\s*(?:of\s*)?(\d+(?:\.\d+)?)", q, re.I)
        params = {"radius": float(m.group(1)) if m else 2.5}
    elif kind == "vectors":
        params = {"u": [3, 2], "v": [1, 3]}
    return params


def build_lesson_assets(
    question: str, params_override: dict[str, Any] | None = None
) -> dict[str, Any]:
    """Full orchestration: classify → (maybe) compile → pair with3D workflow."""
    plan = classify_lesson_need(question)
    override = params_override or {}
    merged = {**plan["params"], **override} if plan["diagram_kind"] else dict(override)

    diagram: dict[str, Any] | None = None
    fallback: dict[str, Any] | None = None
    asy_executed = False

    if plan["diagram_kind"]:
        diagram = service.render_diagram(plan["diagram_kind"], merged)
        asy_executed = bool(diagram.get("ok"))
        if not asy_executed:
            fallback = {
                "used": True,
                "reason": f"Asymptote unavailable or failed: {diagram.get('error')}",
                "recorded_as_asy_success": False,
            }
    elif override:
        # explicit parameters without a recognised kind: be honest, do not compile
        fallback = {
            "used": False,
            "reason": "no diagram kind recognised for these parameters",
            "recorded_as_asy_success": False,
        }

    three: dict[str, Any] | None = None
    if plan["three_scene"]:
        if plan["diagram_kind"] == "right_triangle":
            a = float(merged.get("a", 3))
            b = float(merged.get("b", 4))
            launch = f"/asy_lab/?a={_num(a)}&b={_num(b)}"
            sync = {"a": a, "b": b, "c": round((a * a + b * b) ** 0.5, 4)}
        elif plan["diagram_kind"] == "energy_profile":
            launch = "/asy_lab/#energy"
            sync = {
                "dh_kj": merged.get("dh_kj", -85),
                "exothermic": merged.get("exothermic", True),
            }
        else:
            launch = "/asy_lab/"
            sync = dict(merged)
        three = {
            "scene": plan["three_scene"],
            "launch_url": launch,
            "sync_params": sync,
            "workflow": "load the shared Three.js r172 scene and apply sync_params "
            "so labels/measurements match the Asymptote SVG",
        }

    return {
        "plan": plan,
        "diagram": diagram,
        "three": three,
        "fallback": fallback,
        "asy_executed": asy_executed,
    }


def _num(v: float) -> str:
    return str(int(v)) if float(v).is_integer() else str(v)
