"""Asymptote diagram service.

Real compiler execution with controlled templates:

* executable discovery (explicit env override, per-user official install,
  Program Files, then PATH) — never an assumed path;
* ``.asy`` source generated only from validated parameters;
* safe subprocess (argv list, no shell, fixed output directory, timeout);
* hash-keyed cache of source + SVG + a full execution log;
* honest failure reporting — success is claimed only when the compiler exits 0
  and the SVG file exists, is non-empty and contains ``<svg``.
"""

from __future__ import annotations

import ast
import hashlib
import math
import os
import re
import shutil
import subprocess
import time
from pathlib import Path
from typing import Any, Callable

from . import templates
from .schemas import (
    CircleParams,
    EnergyProfileParams,
    FunctionPlotParams,
    RightTriangleParams,
    VectorParams,
)

CACHE_DIR = Path(__file__).resolve().parents[2] / "generated" / "diagrams"
DEFAULT_TIMEOUT_S = 25.0
_ASSET_NAME = re.compile(r"^[0-9a-f]{64}$")

_DISCOVERY: dict[str, Any] = {}
_SMOKE: dict[str, Any] = {}

_SAFE_EXPR_FUNCS: dict[str, Callable[..., float]] = {
    "sin": math.sin,
    "cos": math.cos,
    "tan": math.tan,
    "sqrt": math.sqrt,
    "log": math.log,
    "exp": math.exp,
    "abs": abs,
}
_SAFE_EXPR_NAMES = {"x", "pi", "e"}


def reset_discovery() -> None:
    """Forget cached executable/smoke results (used by tests and health probes)."""
    _DISCOVERY.clear()
    _SMOKE.clear()


def _normalise_expr(expr: str) -> str:
    """Lesson input uses ``^`` for powers; Python's AST would read it as XOR."""
    return expr.replace("^", "**")


def validate_function(expr: str) -> None:
    """Reject anything outside a tiny arithmetic whitelist (AST-checked)."""
    try:
        tree = ast.parse(_normalise_expr(expr), mode="eval")
    except SyntaxError as exc:
        raise ValueError(f"invalid expression: {exc.msg}") from exc
    for node in ast.walk(tree):
        if isinstance(node, ast.Expression):
            continue
        if isinstance(node, (ast.operator, ast.unaryop, ast.expr_context)):
            continue  # operator/context nodes are visited separately
        if isinstance(node, ast.BinOp) and isinstance(
            node.op, (ast.Add, ast.Sub, ast.Mult, ast.Div, ast.Pow, ast.Mod)
        ):
            continue
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.UAdd, ast.USub)):
            continue
        if isinstance(node, ast.Constant):
            if isinstance(node.value, bool) or not isinstance(node.value, (int, float)):
                raise ValueError("only numeric literals are allowed")
            continue
        if isinstance(node, ast.Name):
            if node.id not in _SAFE_EXPR_NAMES and node.id not in _SAFE_EXPR_FUNCS:
                raise ValueError(f"unknown name '{node.id}'")
            continue  # whitelisted function names are also checked via ast.Call
        if isinstance(node, ast.Call):
            if (
                not isinstance(node.func, ast.Name)
                or node.func.id not in _SAFE_EXPR_FUNCS
            ):
                raise ValueError("only whitelisted functions are allowed")
            if len(node.args) != 1 or node.keywords:
                raise ValueError("functions take exactly one argument")
            continue
        raise ValueError(f"unsupported syntax: {type(node).__name__}")


def sample_function(
    expr: str, xmin: float, xmax: float, samples: int
) -> list[tuple[float, float]]:
    """Evaluate the whitelisted expression at `samples` points (failures skip)."""
    expr = _normalise_expr(expr)
    validate_function(expr)
    code = compile(expr, "<diagram>", "eval")
    env = {"x": 0.0, "pi": math.pi, "e": math.e, **_SAFE_EXPR_FUNCS}
    pts: list[tuple[float, float]] = []
    for i in range(samples):
        x = xmin + (xmax - xmin) * i / (samples - 1)
        env["x"] = x
        try:
            y = eval(code, {"__builtins__": {}}, env)  # noqa: S307 — AST-whitelisted only
        except Exception:  # noqa: BLE001 — domain errors skip a sample, not the run
            continue
        if isinstance(y, (int, float)) and math.isfinite(y):
            pts.append((x, float(y)))
    if len(pts) < 2:
        raise ValueError("expression produced no plottable values in the range")
    return pts


def _candidate_paths() -> list[str]:
    out: list[str] = []
    local = os.environ.get("LOCALAPPDATA")
    if local:
        out.append(str(Path(local) / "Programs" / "Asymptote" / "asy.exe"))
    pf = os.environ.get("PROGRAMFILES")
    if pf:
        out.append(str(Path(pf) / "Asymptote" / "asy.exe"))
    which = shutil.which("asy")
    if which:
        out.append(which)
    return out


def find_asy_executable() -> str | None:
    """First existing candidate; result cached until reset_discovery().

    An explicit ASY_EXECUTABLE override is authoritative: if it is set but the
    file does not exist, discovery reports missing instead of silently falling
    back to a different installation.
    """
    if "path" in _DISCOVERY:
        return _DISCOVERY["path"]
    env = os.environ.get("ASY_EXECUTABLE")
    if env:
        p = Path(env)
        _DISCOVERY["path"] = str(p.resolve()) if p.is_file() else None
        return _DISCOVERY["path"]
    for cand in _candidate_paths():
        p = Path(cand)
        if p.is_file() and p.suffix.lower() == ".exe":
            _DISCOVERY["path"] = str(p.resolve())
            return _DISCOVERY["path"]
        if p.is_file() and os.name != "nt":  # extension-less POSIX binary
            _DISCOVERY["path"] = str(p.resolve())
            return _DISCOVERY["path"]
    _DISCOVERY["path"] = None
    return None


def _run(
    argv: list[str], cwd: Path, timeout: float
) -> tuple[int | None, str, str, int]:
    started = time.monotonic()
    try:
        proc = subprocess.run(  # noqa: S603 — fixed argv, no shell
            argv,
            cwd=str(cwd),
            capture_output=True,
            text=True,
            timeout=timeout,
            env=os.environ.copy(),
            check=False,
        )
        dur = int((time.monotonic() - started) * 1000)
        return proc.returncode, proc.stdout, proc.stderr, dur
    except subprocess.TimeoutExpired as exc:
        dur = int((time.monotonic() - started) * 1000)
        out = (
            (exc.stdout or b"").decode("utf-8", "replace")
            if isinstance(exc.stdout, bytes)
            else (exc.stdout or "")
        )
        err = (
            (exc.stderr or b"").decode("utf-8", "replace")
            if isinstance(exc.stderr, bytes)
            else (exc.stderr or "")
        )
        return None, out, err + f"\nTIMEOUT after {timeout}s", dur
    except OSError as exc:
        dur = int((time.monotonic() - started) * 1000)
        return None, "", f"OS error starting compiler: {exc}", dur


def asy_version(executable: str) -> str | None:
    if _DISCOVERY.get("version_for") == executable:
        return _DISCOVERY.get("version")
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    rc, out, err, _ = _run([executable, "--version"], CACHE_DIR, 10.0)
    line = ((out or err) or "").strip().splitlines()
    version = None
    if rc == 0 and line:
        m = re.search(r"[Vv]ersion\s+([0-9][0-9.]*)", line[0])
        version = m.group(1) if m else line[0][:80]
    _DISCOVERY["version_for"] = executable
    _DISCOVERY["version"] = version
    return version


def build_source(kind: str, params: dict[str, Any]) -> tuple[str, dict[str, Any]]:
    """Validate params for the kind and return (asy source, normalised params)."""
    if kind == "right_triangle":
        p = RightTriangleParams.model_validate(params)
        return templates.right_triangle(p.a, p.b, p.unit), p.model_dump()
    if kind == "circle":
        p = CircleParams.model_validate(params)
        return templates.circle_diagram(p.radius, p.show_axes), p.model_dump()
    if kind == "function_plot":
        p = FunctionPlotParams.model_validate(params)
        pts = sample_function(p.fn, p.xmin, p.xmax, p.samples)
        return templates.function_plot(pts, p.xmin, p.xmax), p.model_dump()
    if kind == "vectors":
        p = VectorParams.model_validate(params)
        return templates.vectors(p.u, p.v), p.model_dump()
    if kind == "energy_profile":
        p = EnergyProfileParams.model_validate(params)
        # exothermic/endothermic and the ΔH sign must agree — the sign is
        # enforced, never re-derived from user text
        dh = p.dh_kj
        if p.exothermic and dh > 0:
            dh = -abs(dh)
        if not p.exothermic and dh < 0:
            dh = abs(dh)
        normalised = p.model_dump()
        normalised["dh_kj"] = dh
        return templates.energy_profile(dh, p.exothermic, p.title), normalised
    raise ValueError(f"unsupported diagram kind: {kind}")


def render_diagram(
    kind: str, params: dict[str, Any], timeout_s: float | None = None
) -> dict[str, Any]:
    """Generate (or serve from cache) an SVG; never claims success unverified."""
    started = time.monotonic()
    executable = find_asy_executable()
    if not executable:
        return {
            "kind": kind,
            "exit_code": None,
            "ok": False,
            "params": dict(params or {}),
            "svg_url": None,
            "sha256": None,
            "source_path": None,
            "stdout": "",
            "stderr": "",
            "cached": False,
            "error": "executable_missing",
            "detail": "No Asymptote executable found (set ASY_EXECUTABLE or install "
            "%LOCALAPPDATA%\\Programs\\Asymptote).",
            "duration_ms": 0,
        }
    try:
        source, normalised = build_source(kind, params)
    except ValueError as exc:
        return {
            "kind": kind,
            "exit_code": None,
            "ok": False,
            "params": dict(params or {}),
            "svg_url": None,
            "sha256": None,
            "source_path": None,
            "stdout": "",
            "stderr": "",
            "cached": False,
            "error": "invalid_params",
            "detail": str(exc),
            "duration_ms": 0,
            "asy_executable": executable,
            "asy_version": asy_version(executable),
        }

    sha = hashlib.sha256(source.encode("utf-8")).hexdigest()
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    src_path = CACHE_DIR / f"{sha}.asy"
    out_base = CACHE_DIR / sha  # asy appends ".svg" itself
    svg_path = CACHE_DIR / f"{sha}.svg"
    log_path = CACHE_DIR / f"{sha}.log"

    cached = svg_path.is_file() and svg_path.stat().st_size > 0
    exit_code: int | None = None
    stdout = ""
    stderr = ""
    dur_ms = 0

    if not cached:
        src_path.write_text(source, encoding="utf-8")
        argv = [
            executable,
            "-nobatchView",
            "-f",
            "svg",
            "-o",
            str(out_base),
            str(src_path),
        ]
        exit_code, stdout, stderr, dur_ms = _run(
            argv, CACHE_DIR, timeout_s or DEFAULT_TIMEOUT_S
        )
        if svg_path.exists() and exit_code != 0:
            # a partial/invalid output must never be served
            svg_path.unlink(missing_ok=True)
        log_path.write_text(
            "argv: %r\nexit: %s\nduration_ms: %s\n--- stdout ---\n%s\n--- stderr ---\n%s\n"
            % (argv, exit_code, dur_ms, stdout, stderr),
            encoding="utf-8",
        )

    ok = False
    error = None
    detail = None
    if cached:
        ok = True
        exit_code = 0
    elif exit_code is None:
        error = "timeout"
        detail = stderr.strip()[-500:] or "compilation timed out"
    elif exit_code != 0:
        error = "compile_failed"
        detail = (stderr.strip() or stdout.strip())[-500:]
    elif not svg_path.is_file() or svg_path.stat().st_size == 0:
        error = "output_missing"
        detail = "compiler exited 0 but no non-empty SVG was produced"
    else:
        head = svg_path.read_bytes()[:512]
        if b"<svg" not in head:
            error = "output_invalid"
            detail = "output file is not an SVG document"
        else:
            ok = True

    if not ok and svg_path.exists():
        svg_path.unlink(missing_ok=True)

    return {
        "ok": ok,
        "kind": kind,
        "params": normalised,
        "svg_url": f"/api/v1/diagrams/assets/{sha}.svg" if ok else None,
        "sha256": sha if ok or src_path.is_file() else None,
        "cached": cached,
        "duration_ms": dur_ms or int((time.monotonic() - started) * 1000),
        "exit_code": exit_code,
        "stdout": stdout[-4000:],
        "stderr": stderr[-4000:],
        "asy_executable": executable,
        "asy_version": asy_version(executable),
        "source_path": str(src_path) if src_path.is_file() else None,
        "error": error,
        "detail": detail,
    }


def asset_path(sha: str) -> Path | None:
    """Resolve a validated asset hash to its file, or None."""
    if not _ASSET_NAME.match(sha):
        return None
    path = (CACHE_DIR / f"{sha}.svg").resolve()
    if path.parent != CACHE_DIR.resolve() or not path.is_file():
        return None
    return path


_SMOKE_SOURCE = (
    templates._HEAD  # noqa: SLF001 — shared generation header
    + "size(120);\ndraw((0,0)--(1,0)--(0,1)--cycle,blue);\n"
    + 'label("$t$",(0.5,0.5));\n'
)


def health() -> dict[str, Any]:
    """Discover the compiler and prove label capability with a smoke compile."""
    executable = find_asy_executable()
    if not executable:
        return {
            "ok": False,
            "asy_executable": None,
            "asy_version": None,
            "label_capable": False,
            "smoke_sha256": None,
            "smoke_error": "executable_missing",
            "cache_dir": str(CACHE_DIR),
        }
    version = asy_version(executable)
    key = executable
    now = time.time()
    if key in _SMOKE and now - _SMOKE[key]["at"] < 60:
        return {**_SMOKE[key]["result"], "cache_dir": str(CACHE_DIR)}
    sha = hashlib.sha256(_SMOKE_SOURCE.encode("utf-8")).hexdigest()
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    src = CACHE_DIR / f"{sha}.asy"
    svg = CACHE_DIR / f"{sha}.svg"
    if not svg.is_file():
        src.write_text(_SMOKE_SOURCE, encoding="utf-8")
        argv = [
            executable,
            "-nobatchView",
            "-f",
            "svg",
            "-o",
            str(CACHE_DIR / sha),
            str(src),
        ]
        rc, out, err, _ = _run(argv, CACHE_DIR, DEFAULT_TIMEOUT_S)
        valid = (
            svg.is_file()
            and svg.stat().st_size > 0
            and b"<svg" in svg.read_bytes()[:512]
        )
        label_capable = rc == 0 and valid
        smoke_error = (
            None if label_capable else ((err or out).strip()[-400:] or "smoke failed")
        )
    else:
        label_capable = True
        smoke_error = None
    result = {
        "ok": label_capable,
        "asy_executable": executable,
        "asy_version": version,
        "label_capable": label_capable,
        "smoke_sha256": sha if label_capable else None,
        "smoke_error": smoke_error,
    }
    _SMOKE[key] = {"at": now, "result": result}
    return {**result, "cache_dir": str(CACHE_DIR)}
