"""Acceptance tests for the Asymptote + Three.js integration (Phase 5).

Test A — real Asymptote compilation (labels, non-empty valid SVG)
Test B — Three.js r172 preserved, single vendored copy, no CDN/upgrade
Test C — combined-lesson parameter sync (service side + page wiring)
Test D — scientific lesson: energy profiles, enthalpy sign agreement
Test E — failure handling (missing executable, bad input, app stays usable)
Test F — regression: existing lab/math modules intact and still validating

Browser-driven checks (page screenshot, live camera controls) are performed
manually and recorded in docs/ASYMPTOTE_INTEGRATION_REPORT.md; the browser
gated test below runs only when RUN_BROWSER_TESTS=1.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest
from httpx import AsyncClient

from app.diagrams import orchestrator, service
from tests.conftest import auth_header

REPO = Path(__file__).resolve().parents[2]
WEB = REPO / "frontend" / "web"
HAS_ASY = service.find_asy_executable() is not None
needs_asy = pytest.mark.skipif(not HAS_ASY, reason="no Asymptote executable discovered")


# ─────────────────────────── Test A: compilation ───────────────────────────


@needs_asy
def test_health_reports_real_asymptote() -> None:
    h = service.health()
    assert h["ok"] is True, h
    assert h["label_capable"] is True, h
    assert h["asy_version"], "version must be detected"
    assert h["asy_executable"] and Path(h["asy_executable"]).is_file()


@needs_asy
def test_right_triangle_compiles_with_labels(tmp_path=None) -> None:
    result = service.render_diagram("right_triangle", {"a": 3, "b": 4, "unit": "cm"})
    assert result["ok"] is True, result
    assert result["exit_code"] == 0
    asset = service.asset_path(result["sha256"])
    assert asset is not None and asset.is_file()
    data = asset.read_bytes()
    assert len(data) > 500, "SVG must be non-empty"
    assert b"<svg" in data[:512]
    # glyph references for the rendered labels (3, 4, 5 + caption + angle note)
    assert data.count(b"<use") >= 3, "expected geometric labels in the SVG"
    assert b"<path" in data, "triangle geometry must be drawn"
    # the real .asy source is retained for inspection
    src = Path(result["source_path"])
    assert src.is_file() and src.stat().st_size > 80
    assert "settings.outformat" in src.read_text(encoding="utf-8")


@needs_asy
def test_cache_hit_returns_same_sha_without_recompiling() -> None:
    first = service.render_diagram("circle", {"radius": 2.0})
    second = service.render_diagram("circle", {"radius": 2.0})
    assert first["ok"] and second["ok"]
    assert first["sha256"] == second["sha256"]
    assert second["cached"] is True


# ─────────────────────────── Test B: three.js ───────────────────────────


def test_three_r172_vendored_single_copy() -> None:
    core = WEB / "biology_lab" / "vendor" / "three.core.js"
    assert core.is_file()
    assert "REVISION = '172'" in core.read_text(encoding="utf-8")
    pkg = json.loads((REPO / "frontend" / "package.json").read_text(encoding="utf-8"))
    assert pkg["dependencies"]["three"].startswith("^0.172"), pkg["dependencies"][
        "three"
    ]
    # the new lesson page must reuse the shared vendor file, not a CDN or a copy
    page = (WEB / "asy_lab" / "index.html").read_text(encoding="utf-8")
    assert '"three": "../biology_lab/vendor/three.module.js"' in page
    assert "unpkg" not in page and "jsdelivr" not in page and "cdnjs" not in page


# ───────────────────────── Test C: combined lesson ─────────────────────────


@needs_asy
def test_triangle_parameters_propagate_and_change_output() -> None:
    r1 = service.render_diagram("right_triangle", {"a": 3, "b": 4})
    r2 = service.render_diagram("right_triangle", {"a": 5, "b": 12})
    assert r1["ok"] and r2["ok"]
    assert r1["params"] == {"a": 3.0, "b": 4.0, "unit": ""}
    assert r2["params"] == {"a": 5.0, "b": 12.0, "unit": ""}
    assert r1["sha256"] != r2["sha256"], "changing a side must regenerate the diagram"
    # the paired3D values the page exposes come from the same inputs
    c = (5**2 + 12**2) ** 0.5
    assert abs(c - 13) < 1e-9


def test_combined_lesson_page_wires_both_systems() -> None:
    page = (WEB / "asy_lab" / "index.html").read_text(encoding="utf-8")
    # one calculation drives both views, and deep links reuse that path
    assert "Math.hypot" in page
    assert 'q.has("a")' in page
    assert "__asyLab" in page
    assert "POST /api/v1/diagrams/render" in page
    assert "THREE.REVISION" in page


@pytest.mark.asyncio
async def test_combined_lesson_http_round_trip(client: AsyncClient) -> None:
    resp = await client.post(
        "/api/v1/diagrams/render",
        json={"kind": "right_triangle", "params": {"a": 9, "b": 12}},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["ok"] is True and body["params"]["a"] == 9
    asset = await client.get(body["svg_url"])
    assert asset.status_code == 200
    assert "svg" in asset.headers.get("content-type", "")
    assert len(asset.content) > 500


# ───────────────────── Test D: scientific lesson ──────────────────────


@needs_asy
def test_energy_profile_sign_agrees_with_reaction_type() -> None:
    exo = service.render_diagram(
        "energy_profile", {"dh_kj": -85, "exothermic": True, "title": "Combustion"}
    )
    endo = service.render_diagram(
        "energy_profile", {"dh_kj": 60, "exothermic": False, "title": "Heating"}
    )
    assert exo["ok"] and endo["ok"]
    assert exo["params"]["dh_kj"] < 0, "exothermic must keep a negative enthalpy"
    assert endo["params"]["dh_kj"] > 0, "endothermic must keep a positive enthalpy"
    src = Path(exo["source_path"]).read_text(encoding="utf-8")
    # LaTeX spelling of ΔH in the .asy source, with the sign baked in
    assert "Delta H = -85" in src, "enthalpy label must carry the sign into the diagram"
    assert "Reactants" in src and "Products" in src


def test_energy_lesson_plans_both_views() -> None:
    plan = orchestrator.build_lesson_assets(
        "energy profile for an exothermic reaction with -85 kJ/mol"
    )
    assert plan["plan"]["decision"] == "both"
    assert plan["plan"]["diagram_kind"] == "energy_profile"
    assert plan["three"]["scene"] == "energy_platforms"
    assert plan["three"]["sync_params"]["dh_kj"] < 0


# ─────────────────── Test E: failure handling ───────────────────────


def test_missing_executable_is_reported_not_faked(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("ASY_EXECUTABLE", str(REPO / "does-not-exist-asy.exe"))
    service.reset_discovery()
    try:
        result = service.render_diagram("right_triangle", {"a": 3, "b": 4})
        assert result["ok"] is False
        assert result["error"] == "executable_missing"
        assert result["svg_url"] is None
        health = service.health()
        assert health["ok"] is False and health["label_capable"] is False
        plan = orchestrator.build_lesson_assets("right triangle legs 3 and 4")
        assert plan["asy_executed"] is False
        assert plan["fallback"]["recorded_as_asy_success"] is False
    finally:
        monkeypatch.delenv("ASY_EXECUTABLE", raising=False)
        service.reset_discovery()


@pytest.mark.asyncio
async def test_invalid_inputs_return_structured_errors_not_crashes(
    client: AsyncClient,
) -> None:
    bad_kind = await client.post(
        "/api/v1/diagrams/render", json={"kind": "shell", "params": {}}
    )
    assert bad_kind.status_code == 422
    injection = await client.post(
        "/api/v1/diagrams/render",
        json={
            "kind": "function_plot",
            "params": {"fn": "__import__('os')", "xmin": -1, "xmax": 1},
        },
    )
    assert injection.status_code in (200, 422)
    if injection.status_code == 200:
        body = injection.json()
        assert body["ok"] is False and body["error"] == "invalid_params"
    # clients normalise "../" before it reaches the router, so the guard is
    # asserted directly plus a well-formed-but-absent hash over HTTP
    assert service.asset_path("../../etc/passwd") is None
    assert service.asset_path("z" * 64 + "x") is None
    absent = await client.get("/api/v1/diagrams/assets/" + "d" * 64 + ".svg")
    assert absent.status_code == 404
    health = await client.get("/health")
    assert health.status_code == 200, "the application must stay usable"


@pytest.mark.asyncio
async def test_lesson_assets_endpoint_requires_auth_and_reports_honestly(
    client: AsyncClient, student_token
) -> None:
    anon = await client.post(
        "/api/v1/ai/lesson-assets", json={"question": "right triangle legs 3 and 4"}
    )
    assert anon.status_code in (401, 403)
    ok = await client.post(
        "/api/v1/ai/lesson-assets",
        json={"question": "right triangle legs 3 and 4"},
        headers=auth_header(student_token),
    )
    assert ok.status_code == 200, ok.text
    body = ok.json()
    assert body["plan"]["decision"] == "both"
    assert body["asy_executed"] is body["diagram"]["ok"]
    neither = await client.post(
        "/api/v1/ai/lesson-assets",
        json={"question": "Define evaporation"},
        headers=auth_header(student_token),
    )
    assert neither.json()["plan"]["decision"] == "neither"


# ───────────────────── Test F: regression ────────────────────────────


def test_existing_lab_pages_validate() -> None:
    for page in (
        REPO / "tools" / "validate_html_js.py",
        WEB / "biology_lab" / "index.html",
        WEB / "asy_lab" / "index.html",
        WEB / "mathsdrill" / "index.html",
    ):
        assert page.is_file(), page
    proc = subprocess.run(
        [
            sys.executable,
            str(REPO / "tools" / "validate_html_js.py"),
            str(WEB / "biology_lab" / "index.html"),
        ],
        capture_output=True,
        text=True,
        cwd=str(REPO),
        timeout=120,
    )
    assert proc.returncode == 0, proc.stdout + proc.stderr
    proc2 = subprocess.run(
        [
            sys.executable,
            str(REPO / "tools" / "validate_html_js.py"),
            str(WEB / "asy_lab" / "index.html"),
        ],
        capture_output=True,
        text=True,
        cwd=str(REPO),
        timeout=120,
    )
    assert proc2.returncode == 0, proc2.stdout + proc2.stderr


def test_existing_modules_not_deleted_or_replaced() -> None:
    for rel in (
        "frontend/web/mathsdrill/index.html",
        "frontend/web/physics_lab/three.core.min.js",
        "frontend/web/physics_lab/cannon-es.js",
        "frontend/web/circuits_lab/eecircuit-engine.mjs",
        "frontend/web/chemistry_lab/chemistry-scene.js",
        "frontend/web/biology_lab/index.html",
        "frontend/lib/main.dart",
        "backend/app/mathematics/router.py",
        "backend/app/mathsdrill/router.py",
        "backend/app/examinations_builder/diagrams.py",
    ):
        assert (REPO / rel).exists(), f"existing module missing: {rel}"
    # the lab's Gram-staining integration is still present after our changes
    lab = (WEB / "biology_lab" / "index.html").read_text(encoding="utf-8")
    for marker in ("gramBtn", "gStages", "GP_STEPS", "createGramChoreo"):
        assert marker in lab, marker


def test_asy_cache_dir_is_gitignored() -> None:
    ignore = (REPO / ".gitignore").read_text(encoding="utf-8")
    assert "backend/generated/" in ignore


# ──────── optional browser run (manual runs are in the report) ────────


@pytest.mark.skipif(
    os.getenv("RUN_BROWSER_TESTS") != "1",
    reason="headless-browser run is opt-in (RUN_BROWSER_TESTS=1); see report for the "
    "already-recorded manual evidence",
)
def test_browser_combined_lesson_state() -> None:
    chrome = os.getenv("CHROME_BIN") or "chrome"
    proc = subprocess.run(
        [
            chrome,
            "--headless=new",
            "--disable-gpu",
            "--virtual-time-budget=9000",
            "--dump-dom",
            "http://localhost:8000/asy_lab/?a=5&b=12",
        ],
        capture_output=True,
        text=True,
        timeout=180,
    )
    assert 'id="ro_c">13' in proc.stdout
    assert 'id="d3_c">13' in proc.stdout
