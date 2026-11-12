# Outstanding Issues — Penrose-ScholarMW (2026-11-12)

Everything below is **known to be unresolved or unverified** at the end of this
audit. Nothing in this list is claimed as fixed.

---

## 1. Priority summary

| ID | Priority | Issue | Impact | Owner action |
|---|---|---|---|---|
| O-01 | High | Full backend pytest suite does not complete | Unknown regressions in ~73 % of backend tests | Investigate the hanging test(s) with `-x --timeout`; fix the shared DB fixture |
| O-02 | High | OpenVoice sidecar is not running; no Python 3.10/3.12 installed | Voice cloning/synthesis unverified end-to-end | Install Python 3.10 (or 3.12) and start `sidecar/openvoice_sidecar`; run the voice E2E |
| O-03 | High | 124 Dependabot vulnerabilities (7 critical, 54 high) | Security exposure on the default branch | Triage critical/high first; upgrade with regression tests |
| O-04 | Medium | 441 informational Flutter lints | Maintainability/noise, no functional risk | Optional bulk `dart fix` (≈425 fixes/74 files) as an isolated style commit |
| O-05 | Medium | LiveKit and AI-provider E2E unverified | Token minting compiles, but rooms/LLM calls not exercised | Provide credentials/services and run integration checks |
| O-06 | Medium | Presentation/PPTX/OCR/admin flows not E2E tested | Unknown integration defects | Add or run API-level integration tests with a running backend |
| O-07 | Medium | Web-only code paths are compile-verified, not runtime-verified | `web_browser_web.dart`, speech/TTS web shims | Manual browser smoke test of export, print, vault preview, voice |
| O-08 | Low | Backend venv is Python 3.14.7 while sidecar needs 3.10 | Two interpreters to maintain | Pin/document both toolchains |
| O-09 | Low | Evidence logs are untracked and machine-specific | No shared audit trail | Attach key logs to the PR/issue if needed |
| O-10 | Low | No CI evidence that pre-commit hooks run | Format/lint drift can return | Wire `.pre-commit-config.yaml` into CI |

---

## 2. Details

### O-01 Full backend suite hangs

- Observed: `pytest` reaches ~27 % and exceeds 20 minutes, twice.
- Targeted groups run sequentially and pass:
  - presentation phases 1/2/3/6 + selection + internal security: **44 passed**
  - auth + neuron-viz + mathsdrill: **28 passed**
  - voice delivery + default clone narration + AI tutor + courses: **26 passed**
  - selection + internal security re-run after formatting: **5 passed**
- Root cause: not proven. `backend/tests/conftest.py` uses a single shared
  `sqlite+aiosqlite:///./test.db` and drops/creates all tables per test. This
  makes parallel runs unsafe and is a plausible source of the hang and of the
  earlier spurious “no such table”/UNIQUE failures.
- Recommended: add per-worker/per-test database URLs, a per-test timeout
  (`pytest-timeout`), and run with `-x` to identify the first hanging test.

### O-02 OpenVoice sidecar

- `http://127.0.0.1:8011/health` → connection refused.
- `py -3.10` → “No suitable Python runtime found”; `python3.10` not on PATH;
  system `python` is 3.14.7.
- Consequence: clone creation, embedding persistence, and synthesis are
  **unverified**. The local/CPU configuration and code were not modified.
- Recommended: create a dedicated Python 3.10/3.12 venv from
  `sidecar/openvoice_sidecar/requirements.txt`, download the local model assets,
  start the sidecar, then exercise `/health` → `/clone` → `/synthesize` through
  the backend.

### O-03 Dependency vulnerabilities

Recorded for this audit from GitHub Dependabot on the default branch:

| Severity | Count |
|---|---|
| Critical | 7 |
| High | 54 |
| Moderate | 53 |
| Low | 10 |
| **Total** | **124** |

No automatic upgrades were applied. `web` was the only dependency change, and it
was required to make the code compile. Upgrades must respect the “no paid
services / no large rewrites” constraint and be regression-tested.

### O-04 Remaining informational lints (441)

No errors and no warnings remain. The 441 infos are style rules:

| Rule | Count |
|---|---|
| `prefer_expression_function_bodies` | 170 |
| `prefer_const_constructors` | 86 |
| `avoid_redundant_argument_values` | 75 |
| `curly_braces_in_flow_control_structures` | 32 |
| `unnecessary_const` | 22 |
| `directives_ordering` | 10 |
| `unnecessary_parenthesis` | 10 |
| `unnecessary_brace_in_string_interps` | 9 |
| others | 27 |

`dart fix --dry-run` proposes ≈425 fixes across ≈74 files. Deferred to avoid
mixing a large mechanical diff with behavioural fixes. If adopted, do it as a
single `style(frontend)` commit and re-run the full suite.

### O-05 LiveKit / AI providers

- `AccessToken`/`VideoGrants` construction now works (`JWT_OK True`) and the
  router imports cleanly.
- No LiveKit server, API key/secret, or AI provider credentials were available,
  so room join, webhooks, and real LLM/streaming calls were not exercised.
- The AI client supports provider fallback (`app/config/ai_client.py`) but no
  provider was called.

### O-06 Untested integration flows

No end-to-end run was possible because the backend and sidecar were not running.
Not verified:

- presentation outline/generate/quality/regenerate and PPTX export;
- document upload and storage;
- OCR routes;
- admin dashboards and role-gated routes;
- notification/email/LiveKit side effects;
- payment/plan gating (no paid service was used).

Router existence and import correctness were verified; behaviour was not.

### O-07 Web-only runtime paths

The new `web_browser_web.dart` and the existing `*_web.dart` shims are selected
only on the web. They are:

- type-checked by `flutter analyze`;
- compiled by `flutter build web --release`;
- **not executed** by the VM test suite.

Manual browser checks still needed: PNG/CSV/Markdown/SVG download, biology
print preview, knowledge-vault blob preview, microphone speech input, TTS
playback, and the floating chatbot's voice stack.

### O-08 Interpreter split

Backend venv: Python 3.14.7. Sidecar requires 3.10/3.12 (OpenVoice/MeloTTS
dependencies). Document both in the developer setup and keep them isolated.

### O-09 / O-10 Operational

- Evidence logs (`*.txt` in `backend/` and `frontend/`) are untracked by design
  and remain in the working tree. They contain no secrets.
- `.pre-commit-config.yaml` exists but there is no evidence it runs in CI.
  Without it, the 441 lints and formatting drift will return.

---

## 3. Explicit non-issues (checked, no action)

| Item | Evidence |
|---|---|
| Undefined names in backend | `ruff check app` → 0 |
| Unclosed sinks | `close_sinks` → 0 |
| `dart:html` / web-only library lint | 0 occurrences |
| Deprecated Flutter APIs (`value`, `dataRowHeight`) | 0 `deprecated_member_use` |
| Flutter test failures | 132/132 pass |
| Backend syntax/imports | `compileall` exit 0; `app.main` imports, 567 routes |
| DB integrity / schema drift | `ok`; Alembic head = current = `f1a2b3c4d5e6` |
| Secrets in tracked files | Only `backend/.env.example`; `.env*` ignored |
| API path mismatch | Frontend paths verified against backend routes |
| Voice id contract mismatch | `voice`/`voice_id` verified on both sides |
