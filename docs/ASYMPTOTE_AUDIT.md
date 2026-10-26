# Asymptote + Three.js Integration — Phase 1 Audit Report

Date: 2026-10-26 · Scope: audit before code changes (per MANDATORY ENGINE INTEGRATION
DIRECTIVE). No application code was modified before this report.

## 1. Asymptote executable — detection, failure, repair, verification

### Found
| Item | Value |
|---|---|
| Initially on PATH | `C:\Users\AMINILOGY\AppData\Local\Programs\MiKTeX\miktex\bin\x64\asy.exe` |
| Reported version (initial) | `miktex-asy version 2.88` |
| Installed library | `…\MiKTeX\asymptote\*.asy`, `version.asy` = **3.06** (dated 2026‑02‑02) |
| First real compile | **FAIL** — `plain_constants.asy:73 … no type of name 'using'` → `recursive loading of module 'plain'` |

### Root causes found (with evidence)
1. **Broken partial update**: MiKTeX repo had shipped asymptote **library 3.06** while the
   installed binary was **2.88** (lib files dated Feb 2026, exe dated Dec 2025). The 3.06
   library uses `using suffix=…` syntax the 2.88 parser rejects (0 occurrences of that
   string in the 2.88 exe).
2. **MiKTeX binary/DLL desync**: updating the `asymptote` lib package was a no-op; the
   binary lives in a separate package `miktex-asymptote-bin-x64-2.9`. After `mpm --update`
   (full tree → MiKTeX 26.5) the exe became **3.06** and imported `MiKTeX260500-*.dll`
   correctly (initially 0xC0000135 = DLL-not-found; resolved by the full update).
3. **Label pipeline crash (the real blocker)**: with a matching 3.06/3.06 pair, any
   `label()` died at `plain_Label.asy:321 … min(f), max(f)` with an empty runtime message.
   MiKTeX logs show the exact chain:
   - `asy` spawns **`latex \scrollmode`** as a *PipeStream* child;
   - `latex` (MiKTeX-PDFTEX 4.27) dies `FATAL … Invalid argument, Function: flush,
     Result: 22, C4P.h:504` (see `%LOCALAPPDATA%\MiKTeX\miktex\log\latex.log`);
   - `asy` logs `ERROR asy - MiKTeX exception caught`, the label frame stays empty,
     `min(f)` throws.
   Control experiments: (a) file-mode invocation from the same asy works
   (`latex \nonstopmode\input nolabel_.tex` → exit 0 → dvisvgm → SVG produced);
   (b) **the identical stdin-pipe protocol driven from plain Python works fine**
   (`\scrollmode` → `PIPEOK` → clean stop). Conclusion: the defect is inside
   *MiKTeX‑asy's own PipeStream*, not in latex or in pipes generally. Corroborated by
   public reports of this exact `pic.addBox … min(f) max(f)` failure with miktex‑asy
   (stackoverflow.com/q/70914651, sourceforge asymptote thread 9c431e917f, 2026 report),
   whose accepted fix is the **official standalone Asymptote**.
4. `-tex none` requires `groff` (absent) — not a viable path.

### Repair performed (environment only)
- Full `mpm --update` (MiKTeX tree → 26.5, consistent DLL family).
- Installed **official Asymptote 3.15** per-user, no elevation:
  SourceForge `asymptote-3.15-setup.exe` extracted without executing the NSIS installer
  (NSIS requires elevation; extracted with per-user **NanaZip** installed via
  `winget install M2Team.NanaZip` — MSIX, no UAC) → copied to
  **`%LOCALAPPDATA%\Programs\Asymptote`** (self-contained: `asy.exe` + its own `.asy` lib).

### Verified working
```
Asymptote version 3.15 [(C) 2004-2026 Andy Hammerlindl, John C. Bowman, Tom Prince]
```
Right-triangle test (real compiler, real labels):
`asy -f svg -o off_tri off_tri.asy` → `off_tri.svg` 4 166 bytes, exit 0, 4 `<path>`
(triangle + 3 dots), 3 `<use>` glyph references; headless-Chrome screenshot vision:
*"blue right triangle … vertical leg 4, horizontal leg 3, diagonal 5"* — labels 3/4/5
rendered.

Note: PATH still resolves the MiKTeX `asy` first; the integration therefore discovers
and uses the verified official executable explicitly (see service design) and never
assumes an `asy` is present on deployment machines.

## 2. Three.js version (preserve r172)

| Location | Version |
|---|---|
| `frontend/web/biology_lab/vendor/three.core.js` | `const REVISION = '172'` |
| `frontend/package.json` | `"three": "^0.172.0"` |
| `frontend/web/vendor/three.module.min.js` | shared minified build (no npm copy) |

**Preserve r172; no upgrade, no second installation** — new views import the existing
vendored files via relative import maps.

## 3. Existing diagram pipeline and why it bypasses Asymptote

Three current generators, **zero Asymptote usage anywhere** (repo-wide grep for
`asymptote`/`asy` finds only the mathematical word "asymptotes" in prompts):

1. **MathDrill (frontend/web/mathsdrill)** — a built Vite/React bundle
   (`assets/index-Mgx1iUcd.js`, **no source in repo**) containing a native SVG geometry
   canvas: segments/circles/arcs/vectors/axes/function plots, KaTeX-rendered labels,
   drag points, zoom/pan and a construction-animation engine.
2. **Backend `app/examinations_builder/diagrams.py`** — matplotlib → PNG for exam-paper
   attachments (graphs, grids, schematic diagrams).
3. **AI visual policy** (`app/config/stem_latex.py::VISUAL_GENERATION_POLICY`) — the tutor
   embeds visuals as structured JSON with `svg`/`mermaid`/chart formats produced by the
   model itself.

Why Asymptote is bypassed: it was never wired in — no `.asy` authoring, no compiler
service, no asset route, and the frontends draw natively in JS for convenience while the
backend rasterises with matplotlib. Nothing in the stack invokes, caches, or serves
Asymptote output.

## 4. Modules that must not be replaced

Biology lab (`frontend/web/biology_lab`), physics lab, circuits lab, chemistry lab,
MathDrill, hub Flutter app (`frontend/lib`), backend `mathematics/`, `mathsdrill/`,
`physics/`, `chemistry/`, `ai_tutor/`, `examinations_builder/` — all untouched by this
report.

## 5. Integration architecture facts (from the audit)

- Backend: FastAPI, routers registered in `app/main.py` with `prefix="/api/v1"`.
- Static SPA served from `WEB_DIR = frontend/build/web` via catch-all `FileResponse`.
- Tests: `backend/tests/` with pytest 8.3.3 + `conftest.py` fixtures.
- Mandatory gates (AGENTS.md): `python -m ruff check backend/app` and
  `python -m ruff format --check backend/app` (line length 88) after every backend edit;
  `python tools/validate_html_js.py` for HTML/JS edits.
- Subprocess precedents already exist (`ai_tutor`, `livekit`, `msce_papers`).
- The server runs with `backend/.venv/Scripts/python.exe run.py` on port 8000.

## 6. Toolchain availability summary (Phase 1.2/1.3/1.4 answers)

| Question | Answer |
|---|---|
| Asymptote executable identified & runs? | **Yes** — official 3.15 at `%LOCALAPPDATA%\Programs\Asymptote\asy.exe` (MiKTeX's 3.06 exe detected, *rejected for labels*, documented above) |
| `.asy` → SVG compilation possible? | **Yes** — verified with labelled triangle |
| Three.js version | **r172**, preserved |
| Existing pipeline bypass reason | Native JS SVG + matplotlib; no Asymptote integration existed |
