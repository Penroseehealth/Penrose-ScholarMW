# Penrose-ScholarMW — Audit Report (2026-11-12)

**Repository:** `C:\Users\AMINILOGY\Documents\Default Project\Penrose-ScholarMW`
**Audit window:** 2026-11-12
**Auditor:** automated coding agent (evidence-based; every claim below is reproducible from the commands listed)
**Scope:** Flutter frontend (`frontend/`), FastAPI backend (`backend/`), OpenVoice sidecar (`sidecar/`)

---

## 1. Executive summary

| Area | Baseline | After this audit |
|---|---|---|
| Flutter `analyze` | 455 issues (453 info, 2 warnings, 0 errors) | **441 issues (441 info, 0 warnings, 0 errors)** |
| Backend `ruff check app` | 36 findings (incl. 3 real `F821` bugs) | **0 findings** |
| Backend `ruff format --check app` | 17 files unformatted | **0 files unformatted** |
| Flutter test suite | 120 passed / 12 failed | **132 passed / 0 failed** |
| Backend targeted tests | mixed (see §5) | **98 passed / 0 failed** in sequential groups |
| `dart:html` / `avoid_web_libraries_in_flutter` | 2 files | **0** |
| Deprecated Flutter APIs found | 2 | **0** |
| Unclosed sinks (`close_sinks`) | 1 | **0** |
| DB integrity / schema | ok / at head | **ok / at head** |
| Web release build | not re-verified this window | **`√ Built build\web` (see §5.7)** |

The reported **“45,000+ issues” is not a defect count**. No single tool in the
repository emits 45,000 findings, and no evidence was found of 45,000 distinct
defects. It is an aggregate of historical/duplicated diagnostic logs
(`analysis.txt`, CI logs, repeated analyzer runs). The authoritative counts for
this commit are the four rows above. This report does **not** claim that
“45,000+ issues were resolved”.

Three genuine runtime bugs (`NameError` at request time) were found and fixed in
the backend, plus a class of web-platform defects that broke the Flutter test
suite and any non-web compilation of shared screens. Twelve failing widget tests
were traced to stale test expectations and one genuine hang, and all were fixed
without weakening any assertion.

---

## 2. Method

1. **Recon before mutation.** Confirmed the working tree was clean on `main`
   (`2071f27`), recorded toolchain versions, then ran the analyzers/test suites to
   obtain a fresh baseline rather than trusting checked-in logs.
2. **Reconciled the headline number** against fresh tool output (§1, §8).
3. **Static analysis triage.** Separated errors/warnings from style infos.
   Backend `F821` (undefined name) findings were treated as production bugs and
   fixed first; style-only findings were deferred unless trivially safe.
4. **Targeted verification.** Every fix was re-checked with a compiler, an
   analyzer, a unit test, or a runtime import — not by inspection alone.
5. **No destructive operations.** No `git reset --hard`, `git clean -fd`,
   checkout of tracked changes, file deletion, DB migration, or credential use.
   Uncommitted user work and untracked evidence files were preserved.
6. **Sequential backend testing.** `backend/tests/conftest.py` uses one shared
   file-backed SQLite DB (`sqlite+aiosqlite:///./test.db`) and drops/creates
   tables per test, so parallel pytest processes corrupt each other. All backend
   runs in this audit were sequential. The false “no such table”/UNIQUE errors
   seen in an earlier parallel run disappeared when re-run sequentially.

---

## 3. Repository inventory

| Metric | Value |
|---|---|
| Tracked files | 1,288 |
| Flutter library files (`frontend/lib/**/*.dart`) | 336 |
| Flutter test files (`frontend/test/**/*_test.dart`) | 27 |
| Backend app modules (`backend/app/**/*.py`) | 269 |
| Backend test files (`backend/tests/test_*.py`) | 38 |
| Mounted FastAPI routers (`include_router` in `app/main.py`) | 72 |
| FastAPI routes registered at import | 567 |
| OpenVoice sidecar modules | 1 (`sidecar/openvoice_sidecar/app.py`) |
| Alembic head / current | `f1a2b3c4d5e6` / `f1a2b3c4d5e6` |
| SQLite integrity | `ok`, 120 tables |

**Toolchain:** Flutter 3.47.2 / Dart 3.13.2; backend venv Python 3.14.7
(`backend/.venv`); no Python 3.10/3.12 interpreter installed on this machine.

**Entry points inspected**

- Frontend: `frontend/lib/main.dart`, `frontend/lib/router/app_router.dart`,
  `MaterialApp.router` builder mounting `FloatingChatbot.wrap`.
- Backend: `backend/run.py` → `app.main:app`; `app/main.py` mounts 72 routers and
  serves the Flutter SPA from `frontend/build/web`.
- Sidecar: `sidecar/openvoice_sidecar/app.py` (FastAPI, `/health`,
  `/clone`, `/synthesize`), local CPU configuration.

**API contract checks**

- Frontend base URL: `http://localhost:8000/api/v1` in debug, `/api/v1` in
  release (`frontend/lib/core/constants/api_constants.dart`).
- Verified backend routes exist for the paths the frontend calls:
  `/api/v1/auth/login`, `/auth/me`, `/courses/`, `/presentations/generate`,
  `/presentations/outline`, `/livekit/session-token`.
- Voice contract matches: backend returns `voice` / `voice_id`
  (`app/speech/clone_service.py`), frontend reads `voice_key` / `voice_id`
  (`voice_library_controller.dart`, `vtc_controller.dart`).

---

## 4. Baseline diagnostics (fresh, before changes)

### 4.1 Flutter

`flutter analyze --no-pub` on `2071f27`:

```
455 issues found
  453 info
    2 warning
    0 error
```

The checked-in `frontend/analysis.txt` was stale (398 findings, including 2
errors that had already been fixed). It was not used as evidence.

### 4.2 Backend

`python -m ruff check app` on `2071f27`: **36 findings**, including:

- `F821 undefined name 'AccessToken'` / `'VideoGrants'` — `app/livekit/router.py`
- `F821 undefined name 'select'` — `app/presentation_session/router.py`
- `F821 undefined name 'AI_AWAITING'` — `app/presentation_session/service.py`
- unused imports/variables (`F401`, `F841`) across presentation modules.

`python -m ruff format --check app`: 17 files would be reformatted.

### 4.3 Tests (baseline)

- Flutter: `120 passed, 12 failed`.
- Backend: full `pytest` hangs at ~27 % and exceeds 20 minutes (see §7). Targeted
  groups are reliable when run sequentially.

---

## 5. Fixes applied (with verification)

Full details and per-item verification are in
[`01_CORRECTION_REPORT.md`](01_CORRECTION_REPORT.md); the machine-readable
register is [`05_CORRECTION_REGISTER.md`](05_CORRECTION_REGISTER.md).

### 5.1 Backend runtime bugs (commit `4d87b88`)

| ID | File | Defect | Verification |
|---|---|---|---|
| B-01 | `backend/app/livekit/router.py` | `AccessToken` / `VideoGrants` used without import → `NameError` on every token request | JWT construction executed: `JWT_OK True`; router imports |
| B-02 | `backend/app/presentation_session/router.py` | `select` used without import → `NameError` when listing sessions | Router imports; presentation test group passes |
| B-03 | `backend/app/presentation_session/service.py` | `AI_AWAITING` undefined → `NameError` on state transition | State-machine tests pass |

### 5.2 Backend hygiene (commit `4d87b88` + formatting batch)

- Removed unused imports/variables (`F401`, `F841`) reported by Ruff.
- `ruff check app` → **0**.
- `ruff format app` → 17 files reformatted (whitespace/line-wrapping only);
  `ruff format --check app` → **269 files already formatted**.
- `python -m compileall -q app` → exit 0.
- `python -c "import app.main"` → `IMPORT_OK 567`.

### 5.3 Flutter deprecations and resource leaks

| ID | File | Defect | Fix |
|---|---|---|---|
| F-01 | `lib/features/audio_input/vtc/voice_training_center_page.dart` | `DropdownButtonFormField.value` deprecated after v3.33 | `initialValue` + `ValueKey` so external style changes still rebuild |
| F-02 | `lib/widgets/math_viz/editable_data_grid.dart` | `DataTable.dataRowHeight` deprecated | `dataRowMinHeight` / `dataRowMaxHeight: 36` |
| F-03 | `lib/modules/chemistry_lab/bridge/chemistry_lab_scene_bridge_stub.dart` | `close_sinks`: `StreamController` never closed | `dispose()` closes `_events` |

### 5.4 Web platform layer (new, replaces `dart:html`)

`dart:html` is deprecated and does not compile for the Dart VM, so every widget
test that transitively imported those screens failed to load. Replacing it with
`package:web` alone is not sufficient: `package:web` is web-only and also fails
to compile on the VM. The repository already uses conditional imports for web
code (`web_speech_service.dart`, `tts_audio_player.dart`, lab bridges), so the
same pattern was applied and the four duplicated browser implementations were
consolidated:

- **New:** `lib/services/web_browser.dart` (conditional export),
  `web_browser_stub.dart` (VM fallback), `web_browser_web.dart` (`package:web`).
- **Refactored:** `lib/services/export_service.dart`,
  `lib/screens/biology/biology_visualization_screen.dart`,
  `lib/screens/stem/analytics_export_screen.dart`,
  `lib/screens/student/knowledge_vault.dart`.

Result: 0 `dart:html`, 0 `avoid_web_libraries_in_flutter`, 0 duplicated blob
code; shared screens compile on the VM and on web.

**Dependency:** `web` 1.1.1 → **1.1.2**. Version 1.1.1's
`lib/src/helpers/http.dart` is missing `import 'dart:js_interop'`, so it fails
to compile with Dart 3.13 (`toJS`/`jsify` undefined). 1.1.2 was already in the
local pub cache; the lockfile now pins it. `pubspec.yaml` constraint
(`^1.1.1`) already allowed it.

### 5.5 Flutter logic defects (AI visual pipeline)

`lib/widgets/math_viz/ai_visual_parser.dart`:

| ID | Defect | Fix |
|---|---|---|
| F-04 | `<visual>` and `<!--visual:-->` blocks were parsed in two passes, so block order was not preserved (`line_chart` emitted before an earlier `bar_chart`) | Collect both syntaxes with their offsets, sort by position |
| F-05 | `{"type":"shape","shape":"triangle"}` resolved to `VisualType.unknown` | Derive the type from `shape`/`shapeType` when `type` is unknown |
| F-06 | Natural-language fallback never ran for block-less responses | Fallback for short responses (≤200 chars) only, so ordinary prose mentioning a shape does not render a visual |

Verified by `test/widgets/math_viz/ai_visual_parser_test.dart`: **17/17 pass**
(was 11/17 with 6 failures).

### 5.6 Test-suite repairs (assertions preserved)

| ID | File | Root cause | Fix |
|---|---|---|---|
| T-01..T-03 | `test/floating_chatbot_test.dart`, `floating_chatbot_mount_test.dart`, `floating_chatbot_voice_test.dart` | `pumpAndSettle` can never settle: the bubble's brand mark has an intentional infinite ripple (`_waveCtrl.repeat()`); tests also targeted a removed `Icons.chat_bubble_rounded` and a stale default mute state | Bounded pumps; target `FloatingChatbot`/`textContaining`; assert the real default (`volume_up`) and toggle to `volume_off`. All original assertions retained. |
| T-04 | `test/mathsdrill_layout_test.dart` | (a) imported `dart:html`/`package:web` transitively → compile failure; (b) app shell runs a continuous animation → `pumpAndSettle` timeout | Conditional web layer fixes (a); bounded pumps fix (b). Routing assertions unchanged. |
| T-05 | `test/widgets/penrose_render_test.dart` | (a) wrote to a hardcoded `C:\Users\zispaas\...` path; (b) `toImage`/`toByteData` futures never complete under the fake-async test clock → 10-minute timeout | `tester.runAsync` for rasterisation; write to `Directory.systemTemp`; assert non-empty PNG; delete in teardown. |

**Full suite after fixes: 132 passed, 0 failed.** See
`frontend/flutter_test_full_after_20261112.txt`.

### 5.7 Web release build

`flutter build web --release --no-pub` was run to compile the real browser
target (the VM test runner cannot validate `dart:js_interop` code).

**Result: `√ Built build\web`** (compile time 327.3 s, `main.dart.js` emitted).
The only warnings were Wasm *dry-run* incompatibilities inside the third-party
`flutter_secure_storage_web` package (`dart:html`, `dart:js_util`, `package:js`)
— none originate from this repository's code, and the JavaScript build (the
supported target here) completed successfully. Full log:
`frontend/flutter_build_web_20261112.txt`.

---

## 6. Database and schema

- `PRAGMA integrity_check` → `ok`.
- 120 tables present.
- `alembic heads` → `f1a2b3c4d5e6 (head)`; `alembic current` →
  `f1a2b3c4d5e6 (head)`. No migration was created or applied.
- No destructive DB operation was executed.

---

## 7. Constraints and environment limitations

1. **Full backend suite is not runnable to completion here.** It stalls at
   ~27 % for >20 minutes. Targeted groups run sequentially are reliable.
   Root cause is not proven; the shared `test.db` fixture makes parallel runs
   unsafe and is the most likely contributor to the earlier spurious failures.
2. **OpenVoice sidecar is not running.** `http://127.0.0.1:8011/health` is
   unreachable and no Python 3.10/3.12 interpreter is installed (the backend
   venv is 3.14.7). Clone/synthesis end-to-end behaviour is therefore
   **unverified**; the local/CPU sidecar configuration was left intact.
3. **LiveKit / AI provider E2E** needs running services and credentials; only
   construction/import-level checks were possible.
4. **Dependency alerts.** GitHub reports 124 Dependabot vulnerabilities on the
   default branch (7 critical, 54 high, 53 moderate, 10 low) as recorded for
   this audit. They are not fixed in this batch; see outstanding issues.
5. No paid service, credential, or large architectural rewrite was introduced.

---

## 8. Reconciliation of the “45,000+” claim

| Source | Findings | Notes |
|---|---|---|
| Fresh `flutter analyze` at baseline | 455 | 453 info + 2 warnings |
| Stale `frontend/analysis.txt` | 398 | Predates fixes; contains 2 already-fixed errors |
| Fresh `ruff check app` at baseline | 36 | 3 were real bugs |
| Full Flutter suite failures | 12 | 1 genuine hang, 4 stale UI targets, 6 parser defects |
| Sum of the above | 901 | Still three orders of magnitude below 45,000 |

No log, CI artifact, or tool output in the repository contains 45,000 findings.
The plausible explanation is aggregation of repeated/stale runs across many
files, not 45,000 independent defects. The defensible statement is:
**all errors (0), all warnings (0), all backend lint findings (0), all Flutter
test failures (0), and the verified runtime bugs are resolved; 441 informational
style lints remain.**

---

## 9. Deliverables

- [`00_AUDIT_REPORT.md`](00_AUDIT_REPORT.md) — this report
- [`01_CORRECTION_REPORT.md`](01_CORRECTION_REPORT.md) — what changed and how it was verified
- [`02_OUTSTANDING_ISSUES.md`](02_OUTSTANDING_ISSUES.md) — known remaining risks and unverified areas
- [`03_HEALTH_ASSESSMENT.md`](03_HEALTH_ASSESSMENT.md) — per-area health and risk register
- [`04_GIT_REPORT.md`](04_GIT_REPORT.md) — baseline, commits, push state, exclusions
- [`05_CORRECTION_REGISTER.md`](05_CORRECTION_REGISTER.md) — per-item register with evidence

## 10. Evidence index

| Evidence | Path |
|---|---|
| Flutter analyze after fixes | `frontend/analysis_after_second_batch_20261112.txt` |
| Flutter full suite before fixes | `frontend/flutter_test_full_20261112.txt` |
| Flutter full suite after fixes | `frontend/flutter_test_full_after_20261112.txt` |
| Flutter web release build | `frontend/flutter_build_web_20261112.txt` |
| Backend Ruff before/after | `backend/ruff_fresh_20261112.txt`, `backend/ruff_after_fix_20261112.txt` |
| Backend tests (presentation/internal security) | `backend/pytest_presentation_20261112.txt` |
| Backend tests (auth/neuron/mathsdrill) | `backend/pytest_remaining_sequential_20261112.txt` |
| Backend tests (voice/AI/courses) | `backend/pytest_voice_ai_courses_sequential_20261112.txt` |
| Backend tests after formatting | `backend/pytest_after_format_20261112.txt` |

Evidence logs are deliberately **not committed** (they are machine-specific and
untracked); they remain in the working tree for inspection.
