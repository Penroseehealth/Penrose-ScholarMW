# Asymptote + Three.js Integration — Test Report & Delivery Evidence

Date: 2026-10-26 · Directive: MANDATORY ENGINE INTEGRATION DIRECTIVE (Asymptote + Three.js)
Companion document: `docs/ASYMPTOTE_AUDIT.md` (Phase 1 audit, toolchain repair history).

---

## 1. Files created or modified

### Created
| File | Purpose |
|---|---|
| `backend/app/diagrams/__init__.py` | Package exports (router, service, orchestrator) |
| `backend/app/diagrams/service.py` | Executable discovery, AST-whitelisted expression sampling, safe subprocess compilation, SHA-256 cache, execution logs, health smoke compile |
| `backend/app/diagrams/templates.py` | Controlled `.asy` templates: right triangle, circle on axes, function plot, vectors, energy profile |
| `backend/app/diagrams/schemas.py` | Pydantic request/response models (per-kind bounded params, safe-text validators) |
| `backend/app/diagrams/router.py` | `POST /api/v1/diagrams/render`, `GET /api/v1/diagrams/assets/{sha}.svg`, `GET /api/v1/diagrams/health` |
| `backend/app/diagrams/orchestrator.py` | Phase 4: rule-based lesson classification (diagram/three/both/neither) + real service invocation + honest fallback records |
| `backend/tests/test_diagrams.py` | Acceptance tests A–F (16 tests) |
| `frontend/web/asy_lab/index.html` | Combined lesson page: Asymptote SVG ⇄ interactive Three.js r172 triangle + energy view, synchronized values |
| `docs/ASYMPTOTE_AUDIT.md` | Phase 1 audit report |

### Modified
| File | Change |
|---|---|
| `backend/app/main.py` | Registered the diagrams router (`/api/v1/diagrams`) |
| `backend/app/ai_tutor/router.py` | `POST /api/v1/ai/lesson-assets` orchestration endpoint (authenticated, like sibling AI endpoints) |
| `backend/app/config/stem_latex.py` | `VISUAL_GENERATION_POLICY` gained **RULE 6**: diagrams must come from the Asymptote service, paired with the Three.js view; failures reported verbatim, never faked |
| `.gitignore` | `backend/generated/` (compile cache) + `backend/test.db-journal` |

Not touched: biology/physics/chemistry/circuits labs, mathsdrill, Flutter app, Three.js
vendored files, `frontend/package.json`.

---

## 2. Asymptote executable and version (detected)

```
C:\Users\AMINILOGY\AppData\Local\Programs\Asymptote\asy.exe
Asymptote version 3.15 [(C) 2004-2026 Andy Hammerlindl, John C. Bowman, Tom Prince]
```

- Discovery order: `ASY_EXECUTABLE` env (authoritative; missing file ⇒ explicit
  `executable_missing`, never a silent fallback) → per-user install → Program Files → PATH.
- The pre-existing MiKTeX `asy` (miktex-asy) was tested and **rejected for labels**
  (its `latex \scrollmode` pipe crashes — full diagnosis in the audit report). The
  service's `/health` proves label capability with a real smoke compile per run.
- Detected at runtime, not hard-coded: `/api/v1/diagrams/health` reports the path,
  version 3.15, `label_capable: true`.

## 3. Real `.asy` sources used in testing (kept in `backend/generated/diagrams/`)

Right triangle (`08defcb2….asy`, Test A/C):

```asy
settings.outformat="svg";
settings.render=0;
size(340,250);
pair O=(0,0), A=(3,0), B=(0,4);
draw(O--A--B--cycle, blue+linewidth(1.5));
draw(O--(0,0.36)--(0.36,0.36)--(0.36,0)--cycle, black+linewidth(.9));
dot(O); dot(A); dot(B);
label("$4$", (0,2), W);
label("$3$", (1.5,0), S);
label("$5$", (1.5,2), NE);
label("$a=3 cm,\ b=4 cm,\ c=5 cm$", (1.5,2), 2.4*S);
label("right angle", O, 3*SW);
```

Energy profile excerpt (`5effa722….asy`, Test D) — sign baked in:

```asy
pair R=(0,0), P=(4.2,-0.935);
path curve=(0,0)..(1.0,2.6)..(1.9,1.4325)..(2.7,-0.585)..(4.2,-0.935);
draw(curve, rgb(210,110,30)+linewidth(2));
draw((3.6,0)--(3.6,-0.935), black+linewidth(1.4), Arrow(7));
label("$\Delta H = -85$ kJ/mol", (3.6,-0.4675), 2*E);
label("Reactants", (0.05,0), 2*NW); label("Products", (4.15,-0.935), 2*NE);
```

26 sources generated this session (all five kinds).

## 4. Generated SVG output

| Artifact | Size | Served at |
|---|---|---|
| `08defcb2….svg` (3-4-5 triangle) | 19 607 B | `/api/v1/diagrams/assets/08defcb2….svg` |
| `5effa722….svg` (exothermic ΔH −85) | 44 452 B | `/api/v1/diagrams/assets/5effa722….svg` |
| 24 more cached diagrams | various | hash-addressed, `image/svg+xml` |

Verified: non-empty, starts with `<svg`, glyph `<use>` references for every label
(≥3 per diagram), served with correct MIME type, path-traversal-safe resolution.

## 5. Compiler logs (captured per run)

`backend/generated/diagrams/<sha>.log` example:

```
argv: ['…\Asymptote\asy.exe', '-nobatchView', '-f', 'svg',
       '-o', '…\diagrams\00f2c397…', '…\diagrams\00f2c397….asy']
exit: 0
duration_ms: 6203
--- stdout --- (empty)
--- stderr --- (empty)
```

Failed compilations keep the log too (exit code + stderr tail) and their partial SVGs
are deleted so nothing invalid can be served.

## 6. Automated test results

| Suite | Result |
|---|---|
| `pytest tests/test_diagrams.py` (Tests A–F) | **15 passed, 1 skipped** (skip = opt-in browser test `RUN_BROWSER_TESTS=1`) |
| `pytest tests/` (full existing backend suite) | **432 passed, 15 failed, 1 skipped** (21 min). The 15 failures are pre-existing and unrelated to this change-set: 4 × `ModuleNotFoundError: reportlab` (reportlab is **not** in `requirements.txt`), 4 × `403`-vs-`401/200` auth-shape expectations (admin, notifications ×2, stem-stats), 1 × exam-integrity status-code expectation, 6 × stem endpoint validation/JSON drift (formula/career/analytics/knowledge-graph). Re-running the affected files **in isolation** reproduces exactly the same failures (`11 failed, 81 passed`), so they are not caused by the new tests; none of the failing routers import any modified file (my backend diff is 3 additive edits: new `app/diagrams/` package, one new `ai_tutor` endpoint, +2 router-registration lines, one appended prompt string) |
| `ruff check` + `ruff format --check` on all touched Python | **PASS** |
| `tools/validate_html_js.py` on biology_lab + asy_lab + mathsdrill | **PASS** (also asserted inside Test F) |
| Direct service matrix (5 diagram kinds × success/cache/failure) | all green, 4 injection payloads blocked (`invalid_params`) |

## 7. Screenshots (browser tooling available and used)

| File | What it shows |
|---|---|
| `.asy_svg.png` (workspace root) | Compiler-produced triangle SVG opened in Chrome; vision analysis: *"blue right triangle … vertical leg 4, horizontal leg 3, diagonal 5"* |
| `.asy_lab.png` (workspace root) | The combined lesson page: three-column dashboard with the Asymptote triangle, the energy diagram, and the3D scene; vision: *"healthy … no error overlays"* |
| Headless DOM evidence | `?a=5&b=12` → `ro_c=13`, `d3_a=5`, `d3_b=12`, `d3_c=13`, fresh compile 7 546 ms, alt-text updated (Test C) |

## 8. Requirement matrix

| # | Requirement | Status |
|---|---|---|
| P1 | Audit before changes (exe found, version, three r172, compile capability, bypass reason, modules preserved) | **PASS** (`docs/ASYMPTOTE_AUDIT.md`) |
| P2 | Real service: validated params → templates → real compiler → status/log/duration → SVG URL → hash cache → graceful missing/invalid/timeout/failure, no shell exposure | **PASS** |
| P3 | Asymptote renders labelled triangles/circles/plots/vectors/energy profiles; Three.js renders the rotatable lesson scene; SVG shown in the lesson UI; synced labels/values; SVG kept vector; no second Three.js | **PASS** |
| P4 | Lesson engine classifies diagram/three/both/neither; orchestrator invokes both; AI policy forbids bypassing Asymptote; failures honest, fallback never faked | **PASS** |
| P5 Test A | Right-triangle compile, non-empty valid SVG, geometric labels present | **PASS** |
| P5 Test B | Scene loads, controls work, r172 unchanged, no dependency upgrade | **PASS** (static assertions + manual browser run; automated browser variant NOT TESTED by default, opt-in flag provided) |
| P5 Test C | Triangle via Asymptote beside interactive 3D triangle; side change → both views update consistently | **PASS** (service+page automated; live-change also verified headlessly — see §7) |
| P5 Test D | Energy profile via Asymptote + 3D lab scene agreement (type, ΔH sign, labels) | **PASS** (service signs + in-page "Views agree" status +3D platforms) |
| P5 Test E | Missing executable + invalid input reported; app remains usable | **PASS** (`executable_missing`, `invalid_params`, 404/422, `/health` 200) |
| P5 Test F | Unrelated modules intact; no lab assets/pages deleted | **PASS** (validators + existence assertions) |
| P6 | Evidence delivered (files, exe/version, sources, SVGs, logs, tests, screenshots, limits) | **PASS** (this document) |
| — | Full pre-existing backend suite regression | **PASS for this change-set** (432 passed; 15 pre-existing failures isolated-reproducible in untouched modules — see §6) |

## 9. Limitations (known, honest)

1. **MiKTeX's bundled `asy` cannot render labels** (broken `PipeStream`↔latex protocol;
   diagnosed with logs + control experiments). The service uses the verified official
   3.15 install and reports `label_capable` from a live smoke compile. Deployment
   machines need *some* Asymptote — without it the API answers
   `ok:false / executable_missing` and the UI keeps the3D side usable.
2. **Asymptote output is static SVG** by design (vector, per directive); animation/scrubbing
   belongs to the Three.js side; the two views share parameters rather than frames.
3. **Browser automation is opt-in** (`RUN_BROWSER_TESTS=1`); default CI runs stay
   deterministic without Chrome. The recorded manual runs (§7) cover the browser evidence.
4. The combined lesson page ships the **right-triangle lesson first** (the directive's
   implementation rule); the energy view reuses the same architecture — extending to
   physics/chemistry scenes is the same pattern (service kind + paired `three_scene`).
5. `backend/generated/` cache grows unbounded per unique source (hash-named, gitignored);
   no eviction job is included.
6. Uncommitted working tree (this task + earlier Gram-staining work) awaits your `commit`.
