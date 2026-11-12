# Health Assessment — Penrose-ScholarMW (2026-11-12)

**Assessment type:** static analysis + targeted execution + schema/data checks
**Baseline commit:** `2071f27` · **Fixes:** `4d87b88` + second batch (see Git report)
**Overall grade: B− (functional, improving; integration verification is the gap)**

---

## 1. Scorecard

| Dimension | Grade | Evidence | Main risk |
|---|---|---|---|
| Compile/analyze health | **A** | Flutter: 0 errors, 0 warnings. Backend: `ruff` 0, `compileall` 0, `app.main` imports (567 routes) | None observed |
| Runtime defect density | **B** | 3 real backend `NameError`s and 6 parser defects found and fixed in a single pass | More may hide in untested flows |
| Test health | **B+** | Flutter 132/132 pass; backend 98 targeted passes | Full backend suite cannot complete (O-01) |
| Test coverage breadth | **C** | 27 Flutter test files for 336 lib files; 38 backend test files for 269 modules; no coverage measurement | Large untested surface (presentation, OCR, admin, LiveKit) |
| Web platform correctness | **B** | `dart:html` eliminated; `package:web` behind conditional imports; release build succeeds | Web paths compile-verified only, not runtime-verified |
| Backend architecture | **B+** | 72 routers, typed schemas, service/repository separation, Alembic at head | Shared test DB fixture; full suite hang |
| Database health | **A** | `integrity_check` ok, 120 tables, head = current | No backup/restore drill evidenced |
| Security posture | **C** | No secrets tracked; `.env*` ignored; internal routes token-gated and tested | 7 critical + 54 high dependency advisories |
| Dependency freshness | **C−** | 124 Dependabot alerts; only `web` upgraded | Supply-chain risk |
| Voice/AI integration readiness | **C** | Contracts and fallbacks present; JWT construction verified | Sidecar and providers not running; E2E unverified |
| Developer experience | **B** | Format/lint/analysis all clean; pre-commit config exists | No CI evidence; 441 style infos |
| Documentation | **B+** | `AGENTS.md`, `.env.example`, API routes, this audit pack | Runbook for sidecar/providers still thin |

---

## 2. What is demonstrably healthy

1. **The codebase compiles cleanly on both targets.**
   - Flutter: `flutter analyze` → 441 info, **0 warnings, 0 errors**.
   - Web: `flutter build web --release` completes.
   - Backend: `ruff check` and `ruff format --check` pass for all 269 modules;
     `app.main` imports with 567 routes.

2. **The Flutter test suite is fully green.**
   132 tests pass, including routing/layout contracts, smart-board state,
   handwriting rendering, chatbot mounting, voice controls, the AI visual
   parser, and PNG rasterisation. The previous 12 failures were stale tests,
   a fake-async misuse, and web-only imports — all fixed without removing an
   assertion.

3. **The backend has no undefined names or lint findings.**
   The three `F821` findings were real request-time crashes, not style issues.
   They are fixed and the affected modules import and pass their tests.

4. **The database is consistent and the schema is in sync.**
   `PRAGMA integrity_check` = `ok`, 120 tables, Alembic head = current.

5. **The API surface is coherent.**
   Frontend request paths match backend routes; the voice payload contract
   (`voice`/`voice_id`) matches on both sides; base URL differs correctly by
   build mode.

6. **Secrets hygiene is intact.**
   Only `backend/.env.example` is tracked; `.env`, `.env.prod`, and `.env.*` are
   ignored. No credential was read, printed, or committed.

7. **Web-only code follows the platform split.**
   `dart:html` is gone; `package:web` is isolated behind conditional imports, so
   shared screens stay testable on the VM and compile for the browser.

---

## 3. What limits the grade

### 3.1 Integration verification is the dominant gap

The backend and OpenVoice sidecar were not running, and no provider credentials
were available. Consequently, the following are **structurally sound but
behaviourally unproven**: presentation generation and PPTX export, OCR, admin
flows, LiveKit rooms, AI streaming/fallback, and voice cloning. The code may be
correct; the audit cannot say it is.

### 3.2 Full backend suite is not runnable end-to-end

The suite stalls at ~27 % for >20 minutes. Targeted groups are green (98 tests),
but ~73 % of backend tests are unexecuted in this window. Until the hang is
fixed, backend regressions can only be caught by targeted runs.

### 3.3 Dependency risk is material

124 advisories (7 critical, 54 high) on the default branch is the largest
quantified risk in the repository. None were introduced by this audit; none were
fixed, because upgrades need regression testing and were outside the approved
scope.

### 3.4 Coverage breadth is thin relative to surface area

336 Flutter library files vs 27 test files, and 269 backend modules vs 38 test
files. The passing suites prove the touched areas, not the whole product. No
line/branch coverage was measured.

### 3.5 Style debt is large but low-risk

441 informational lints (170 `prefer_expression_function_bodies`, 86
`prefer_const_constructors`, 75 `avoid_redundant_argument_values`). These do not
affect behaviour; bulk-fixing them is a mechanical change best done separately.

---

## 4. Risk register

| Risk | Likelihood | Impact | Score | Mitigation |
|---|---|---|---|---|
| Hidden backend regression in unrun tests | Medium | High | **High** | Fix O-01; add CI with per-test timeout |
| Critical dependency exploit | Medium | High | **High** | Patch critical/high advisories; add `pip-audit`/`npm audit`-style checks |
| Voice feature broken in production | Medium | Medium | **Medium** | Stand up Python 3.10 sidecar; run clone→synthesize E2E |
| Web export/print/vault broken at runtime | Medium | Medium | **Medium** | Manual browser smoke matrix |
| Presentation/PPTX/OCR integration defects | Medium | Medium | **Medium** | API integration tests against a live backend |
| Style drift returns | High | Low | **Low** | CI pre-commit + ratchet the lint count |
| Shared test DB corrupts results | Medium | Medium | **Medium** | Per-test DB URL; forbid parallel pytest |

---

## 5. Trend

| Signal | Baseline | Now | Direction |
|---|---|---|---|
| Analyzer errors/warnings | 0 / 2 | 0 / 0 | ▲ improved |
| Analyzer infos | 453 | 441 | ▲ improved |
| Backend lint | 36 | 0 | ▲ improved |
| Backend format drift | 17 files | 0 | ▲ improved |
| Flutter tests | 120/132 | 132/132 | ▲ improved |
| Parser tests | 11/17 | 17/17 | ▲ improved |
| Web library deprecations | 2 files | 0 | ▲ improved |
| Dependency advisories | 124 | 124 | ▬ unchanged |
| Backend suite completeness | partial | partial | ▬ unchanged |

---

## 6. Recommended next actions (in order)

1. **Fix O-01** — make the full backend suite complete. Without this, the
   backend's real health is unknown. Add `pytest-timeout`, run `-x`, isolate the
   hanging test, then replace the shared `test.db` with a per-test database.
2. **Stand up the sidecar** — Python 3.10/3.12 venv, local models, then verify
   `/health`, `/clone`, `/synthesize` through the backend. This is the only way
   to validate the voice feature the product depends on.
3. **Triage Dependabot** — critical then high. Upgrade in small batches with the
   Flutter and targeted backend suites as the gate.
4. **Browser smoke matrix** — download (PNG/CSV/MD/SVG), biology print,
   vault preview, mic input, TTS, floating chatbot voice loop.
5. **Add integration tests** for presentation/PPTX/OCR/admin with a live backend
   and seeded DB.
6. **Optional style commit** — `dart fix --apply` + `dart format`, isolated and
   fully re-tested; then enable CI pre-commit to keep the count at zero.
7. **Add coverage reporting** so future audits can quantify breadth rather than
   infer it from file counts.

---

## 7. Bottom line

The repository is in **materially better shape than at baseline**: no compile
errors, no analyzer warnings, no backend lint findings, a fully green Flutter
suite, a verified web build, a consistent database, and no secrets exposure.
The remaining risk is concentrated in **things that were not executed** — the
full backend suite, the OpenVoice sidecar, provider/LiveKit integrations, and
dependency advisories — not in known defects. That is why the grade is **B−**
rather than higher: the code that was exercised is healthy, but too much of the
product could not be exercised.
