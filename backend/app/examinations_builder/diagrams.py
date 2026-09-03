"""Diagram / graph / graph-paper generation for examination papers.

Produces matplotlib PNGs for question attachments (line/bar/scatter graphs,
histograms, coordinate grids, distance/velocity-time graphs and labelled
schematic diagrams). Graph paper and working (grid) areas are generated as
full-page or region images. All figures are sized for high-resolution print.

Public API
----------
- ``render_diagram(spec: dict) -> bytes`` — render the diagram described by a
  ``spec`` dict and return PNG bytes.
- ``paper_specs(diagram) / graph_spec(name)`` — convenience builders.

A diagram ``spec`` is a dict with keys:
``kind`` (line|bar|scatter|histogram|grid|diagram), ``title``, ``x_label``,
``y_label``, ``series`` (list of ``{label, points: [[x,y],...]}``), ``grid``
(bool), ``width``/``height`` (inches), ``dpi``, ``axis`` (bool), ``points``
(for grid kinds) and ``shape`` for the schematic ``diagram`` kind.
"""

from __future__ import annotations

import io

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import Circle, Rectangle  # noqa: E402

GRID_COLOR = (0.75, 0.75, 0.75)


def render_diagram(spec: dict) -> bytes:
    """Render a diagram spec to high-resolution PNG bytes."""
    kind = spec.get("kind", "line")
    width = float(spec.get("width", 6.0))
    height = float(spec.get("height", 4.0))
    dpi = int(spec.get("dpi", 200))

    fig, ax = plt.subplots(figsize=(width, height), dpi=dpi)
    try:
        if kind == "graph_paper":
            _draw_graph_paper(ax, spec)
        elif kind == "grid":
            _draw_grid(ax, spec)
        elif kind == "bar":
            _draw_bar(ax, spec)
        elif kind == "scatter":
            _draw_scatter(ax, spec)
        elif kind == "histogram":
            _draw_histogram(ax, spec)
        elif kind == "diagram":
            _draw_diagram(ax, spec)
        else:
            _draw_line(ax, spec)
        _finish(ax, spec)
        buf = io.BytesIO()
        fig.savefig(buf, format="png", dpi=dpi, bbox_inches="tight")
        buf.seek(0)
        return buf.getvalue()
    finally:
        plt.close(fig)


def _finish(ax: plt.Axes, spec: dict) -> None:
    title = spec.get("title")
    if title:
        ax.set_title(title, fontsize=11)
    if spec.get("axis", True):
        ax.set_xlabel(spec.get("x_label") or ("" if spec.get("axis") is False else ""))
        ax.set_ylabel(spec.get("y_label") or "")
    if spec.get("axis") is False:
        ax.set_xticks([])
        ax.set_yticks([])
    if spec.get("legend"):
        ax.legend(fontsize=9, frameon=False)
    if not spec.get("axis", True):
        ax.axis("off")


def _draw_line(ax: plt.Axes, spec: dict) -> None:
    for series in spec.get("series", []):
        pts = series.get("points", [])
        if not pts:
            continue
        x = [p[0] for p in pts]
        y = [p[1] for p in pts]
        ax.plot(
            x,
            y,
            marker=series.get("marker", "o"),
            label=series.get("label"),
            linewidth=1.8,
        )
    if spec.get("grid", False) or spec.get("gridlines", False):
        ax.grid(True, color=GRID_COLOR)


def _draw_bar(ax: plt.Axes, spec: dict) -> None:
    labels = spec.get("labels", [])
    values = spec.get("values", [])
    color = spec.get("color", "#4c6ef5")
    ax.bar(labels, values, color=color, edgecolor="black", linewidth=0.6)
    if spec.get("grid", False):
        ax.grid(True, axis="y", color=GRID_COLOR)


def _draw_scatter(ax: plt.Axes, spec: dict) -> None:
    for series in spec.get("series", []):
        pts = series.get("points", [])
        if not pts:
            continue
        x = [p[0] for p in pts]
        y = [p[1] for p in pts]
        ax.scatter(
            x, y, s=18, label=series.get("label"), color=series.get("color", "#e8590c")
        )
    if spec.get("grid", False):
        ax.grid(True, color=GRID_COLOR)


def _draw_histogram(ax: plt.Axes, spec: dict) -> None:
    data = spec.get("data", [])
    bins = int(spec.get("bins", 8))
    ax.hist(data, bins=bins, color="#40c057", edgecolor="black", linewidth=0.6)
    if spec.get("grid", False):
        ax.grid(True, axis="y", color=GRID_COLOR)


def _draw_grid(ax: plt.Axes, spec: dict) -> None:
    limit = float(spec.get("limit", 10.0))
    ax.set_xlim(-limit, limit)
    ax.set_ylim(-limit, limit)
    ax.set_xticks(range(-int(limit), int(limit) + 1))
    ax.set_yticks(range(-int(limit), int(limit) + 1))
    ax.grid(True, color=GRID_COLOR, linewidth=0.5)
    for axis in ("top", "right"):
        ax.spines[axis].set_visible(False)
    ax.axhline(0, color="black", linewidth=1.0)
    ax.axvline(0, color="black", linewidth=1.0)


def _draw_graph_paper(ax: plt.Axes, spec: dict) -> None:
    # Light grid fill for a working area (coordinate grid or plain graph paper).
    rows = int(spec.get("rows", 20))
    cols = int(spec.get("cols", 26))
    ax.set_xlim(0, cols)
    ax.set_ylim(0, rows)
    ax.set_xticks(range(0, cols + 1))
    ax.set_yticks(range(0, rows + 1))
    ax.grid(True, color=GRID_COLOR, linewidth=0.4)
    for axis in ("top", "right", "left", "bottom"):
        ax.spines[axis].set_visible(True)
    ax.spines["left"].set_visible(spec.get("axes", False))
    ax.spines["bottom"].set_visible(spec.get("axes", False))
    if spec.get("axes"):
        ax.axhline(rows / 2, color="black", linewidth=1.2)
        ax.axvline(cols / 2, color="black", linewidth=1.2)


def _draw_diagram(ax: plt.Axes, spec: dict) -> None:
    """Draw a simple labelled schematic (e.g. a plant cell or apparatus)."""
    ax.set_xlim(-5.5, 5.5)
    ax.set_ylim(-5.5, 5.5)
    ax.set_aspect("equal")
    kind = spec.get("shape", "cell")
    labels = spec.get("labels", {})
    if kind == "cell":
        _draw_cell(ax, labels)
    elif kind == "circuit":
        _draw_circuit(ax, labels)
    else:
        rect = Rectangle((-5, -5), 10, 10, fill=False, edgecolor="black", linewidth=1.2)
        ax.add_patch(rect)
    for axis in ax.spines.values():
        axis.set_visible(False)


def _draw_cell(ax: plt.Axes, labels: dict) -> None:
    cell = Circle((0, 0), 4.6, fill=False, edgecolor="black", linewidth=1.6)
    ax.add_patch(cell)
    membrane = Circle(
        (0, 0), 4.0, fill=False, edgecolor="black", linewidth=0.6, linestyle=":"
    )
    ax.add_patch(membrane)
    for pos, lab in in_labels(labels):
        ax.annotate(lab, xy=pos, ha="center")


def _draw_circuit(ax: plt.Axes, labels: dict) -> None:
    from matplotlib.lines import Line2D

    ax.add_line(Line2D([-4, 4], [2, 2], color="black", linewidth=1.4))
    ax.add_line(Line2D([-4, 4], [-2, -2], color="black", linewidth=1.4))
    ax.add_line(Line2D([-4, -4], [-2, 2], color="black", linewidth=1.4))
    ax.add_line(Line2D([4, 4], [-2, 2], color="black", linewidth=1.4))
    ax.add_patch(Circle((0, 2), 0.5, fill=False, edgecolor="black", linewidth=1.0))
    ax.annotate(labels.get("battery", "Battery"), xy=(0, 3), ha="center")


def in_labels(labels: dict) -> list:
    defaults = {"(-3.5, 0)": "A", "(3.5, 0)": "B"}
    merged = {**defaults, **{str(k): v for k, v in labels.items()}}
    out = []
    for key, val in merged.items():
        try:
            x, y = (float(p) for p in key.replace("(", "").replace(")", "").split(","))
        except ValueError:
            continue
        out.append(((x, y), val))
    return out
