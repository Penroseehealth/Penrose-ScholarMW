"""Graph generation for physics solutions.

Graphs are returned as plain point series plus axis metadata rather than
images, so the Flutter workspace paints them with its own CustomPainter,
keeps them crisp at any zoom and stays consistent with the numbers on the
board. Every solver attaches graphs through this module, so axis labels,
units and marked points are produced the same way everywhere.
"""

from __future__ import annotations

from typing import Any

_MAX_POINTS = 80


def _round(value: float) -> float:
    return round(value, 6)


def _sample(xs: list[float], ys: list[float]) -> tuple[list[float], list[float]]:
    if len(xs) <= _MAX_POINTS:
        return [_round(v) for v in xs], [_round(v) for v in ys]
    step = len(xs) / _MAX_POINTS
    indices = sorted({int(i * step) for i in range(_MAX_POINTS)} | {len(xs) - 1})
    return [_round(xs[i]) for i in indices], [_round(ys[i]) for i in indices]


def line_graph(
    xs: list[float],
    ys: list[float],
    xlabel: str,
    ylabel: str,
    title: str,
    marks: list[dict[str, Any]] | None = None,
    x_equation: str = "",
) -> dict[str, Any]:
    """One series with labelled, unit-carrying axes."""
    sampled_x, sampled_y = _sample(xs, ys)
    return {
        "kind": "line_graph",
        "title": title,
        "xlabel": xlabel,
        "ylabel": ylabel,
        "x_equation": x_equation,
        "series": [{"x": sampled_x, "y": sampled_y}],
        "marks": marks or [],
    }


def scatter_marks(
    points: list[tuple[float, float, str]],
    xlabel: str,
    ylabel: str,
    title: str,
) -> dict[str, Any]:
    """A graph whose meaning lives entirely in its labelled points."""
    return {
        "kind": "line_graph",
        "title": title,
        "xlabel": xlabel,
        "ylabel": ylabel,
        "x_equation": "",
        "series": [],
        "marks": [
            {"x": _round(x), "y": _round(y), "label": label} for x, y, label in points
        ],
    }


def trajectory_graph(
    x_samples: list[float],
    y_samples: list[float],
    marks: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    return line_graph(
        x_samples,
        y_samples,
        "horizontal distance x (m)",
        "height y (m)",
        "Trajectory",
        marks=marks,
    )


def time_series_graph(
    times: list[float],
    values: list[float],
    quantity_label: str,
    title: str,
    equation: str = "",
) -> dict[str, Any]:
    return line_graph(
        times,
        values,
        "time t (s)",
        quantity_label,
        title,
        x_equation=equation,
    )
