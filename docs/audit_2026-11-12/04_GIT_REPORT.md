# Git Report — Penrose-ScholarMW (2026-11-12)

Record of every commit made during this audit, the exact baseline, what was
deliberately excluded, and the one staging incident that occurred and how it was
resolved. No history was rewritten except one `--amend` of an unpushed commit
(described in §4), and no destructive command was run.

---

## 1. Repository state

| Item | Value |
|---|---|
| Remote | `https://github.com/Penroseehealth/Penrose-ScholarMW.git` (`origin`) |
| Branch | `main` |
| Baseline commit | `2071f27` — `feat: improve ScholarMW presentation, voice and platform features` |
| Working tree at start | clean, `main` in sync with `origin/main` |
| Tracked files | 1,288 |
| Pre-commit hook | **not installed** (`backend/.git/hooks/pre-commit` absent) — commits were not hook-gated, so every check in §3 was run manually |

---

## 2. Commits created

All commits are authored as `majaliwamin <majaliwamin@users.noreply.github.com>`.

### 2.1 `4d87b88` — `fix(backend,frontend): resolve undefined-name bugs and analyzer warnings`

- **Scope:** 15 files, **+114 / −95**
- **Content:**
  - `backend/app/livekit/router.py` — added missing `AccessToken`, `VideoGrants`
    imports (every `/livekit/session-token` call raised `NameError`).
  - `backend/app/presentation_session/router.py` — added missing `select`
    import (session listing raised `NameError`).
  - `backend/app/presentation_session/service.py` — defined the missing
    `AI_AWAITING` state constant (state transition raised `NameError`).
  - Removed unused imports/variables (`F401`, `F841`) in the presentation
    modules, `app/main.py`, and `livekit/agent/presentation_session.py`.
  - Frontend analyzer cleanups in `widgets/typewriter_renderer.dart`,
    `widgets/voice_conversation_panel.dart` and four test files — no behavioural
    change.
- **Pushed:** yes (`2071f27..4d87b88 main -> main`).
- **Verification before commit:** `ruff check app` → 0; `import app.main` → 567
  routes; LiveKit JWT construction → `JWT_OK True`; 44 presentation tests pass.

### 2.2 `ba3e9f8` — `style(backend): apply ruff format to drifted modules`

- **Scope:** 17 files, **+1,158 / −392**
- **Content:** `ruff format app` over the 17 files that were already
  unformatted at baseline (`presentation_session/*`, `presentation/*`,
  `livekit/*`, `ocr/router.py`, `stem/certificate_router.py`, `main.py`,
  `models/presentation.py`, `diagrams/__init__.py`). Whitespace, line wrapping
  and string-quote normalisation only — **no logic change**.
- **Verification before commit:** `ruff format --check app` → 269 files already
  formatted; `ruff check app` → 0; `compileall -q app` → exit 0;
  `import app.main` → 567 routes; `tests/test_presentation_selection.py` +
  `tests/test_internal_security.py` → **5 passed** after formatting.

### 2.3 `daecb78` — `fix(frontend): repair web helpers, AI visual parser and widget tests`

- **Scope:** 17 files, **+197 / −96**
- **Content:**
  - New conditional web module: `lib/services/web_browser.dart`,
    `web_browser_stub.dart`, `web_browser_web.dart`.
  - `export_service.dart`, `biology_visualization_screen.dart`,
    `analytics_export_screen.dart`, `knowledge_vault.dart` routed through it —
    `dart:html` and direct `package:web` removed from shared screens.
  - `pubspec.lock`: `web` 1.1.1 → 1.1.2 (1.1.1 cannot compile on Dart 3.13).
  - `ai_visual_parser.dart`: block ordering, shape-type resolution,
    natural-language fallback.
  - Deprecations: `DropdownButtonFormField.initialValue`,
    `DataTable.dataRowMinHeight/MaxHeight`; stub bridge `dispose()` closes its
    sink.
  - Test repairs: three chatbot tests, `mathsdrill_layout_test.dart`,
    `penrose_render_test.dart`.
- **Verification before commit:** `flutter analyze` → **441 info / 0 warnings /
  0 errors**; full `flutter test` → **132 passed / 0 failed**; `dart format
  --line-length=120 --set-exit-if-changed` → 16 files clean; `flutter build web
  --release` → `√ Built build\web`.

### 2.4 Docs commit

`docs(audit): add 2026-11-12 audit reports` — the six files in
`docs/audit_2026-11-12/` (1,086 insertions). It is the tip of `main`; its hash
is therefore whatever `git log -1 --format=%h` reports on `main` (a document
cannot contain the hash of the commit that contains it, so it is identified by
subject rather than pinned here).

---

## 3. Checks run before each commit (no hook was enforcing them)

| Check | Command | Result |
|---|---|---|
| Backend lint | `python -m ruff check app` | 0 findings |
| Backend format | `python -m ruff format --check app` | 269 formatted |
| Backend syntax | `python -m compileall -q app` | exit 0 |
| Backend import | `python -c "import app.main"` | 567 routes |
| Dart format | `dart format --line-length=120 --set-exit-if-changed <files>` | clean |
| Dart analyze | `flutter analyze --no-pub --no-fatal-infos` | 441 info, 0 warn, 0 error |
| Flutter tests | `flutter test --no-pub` | 132 passed |
| Web build | `flutter build web --release --no-pub` | success |

---

## 4. Staging incident and resolution

While creating `daecb78`, `git add frontend/lib` also staged two local editor
backup files that had never been tracked:

- `frontend/lib/screens/ai_tutor/ai_tutor_shell.dart.backup`
- `frontend/lib/screens/ai_tutor/ai_tutor_shell.dart.before-expression-cleanup.bak`

They appeared in the commit as two new files (+211 / +174 lines). Because the
commit had **not** been pushed, the fix was non-destructive:

1. `git rm --cached <both files>` — untracked them without touching the
   working-tree copies.
2. `git commit --amend --no-edit` — rewrote the unpushed commit.
3. Verified the files still exist on disk with their original sizes
   (6,822 B and 5,521 B).

Final `daecb78` contains **17 files** and no backup artefacts. The two files
remain untracked in the working tree, exactly as the user left them. No
`reset --hard`, `clean -fd`, or checkout was used.

**Lesson recorded:** stage explicit paths, not `frontend/lib`, in this
repository.

---

## 5. Push state

| Ref | Commit | On `origin/main` |
|---|---|---|
| Baseline | `2071f27` | yes (before this audit) |
| Batch 1 | `4d87b88` | yes |
| Batch 2 (format) | `ba3e9f8` | yes (pushed with final batch) |
| Batch 3 (frontend) | `daecb78` | yes (pushed with final batch) |
| Audit docs | `docs(audit): add 2026-11-12 audit reports` (tip of `main`) | yes |

Final check after push:

```
git rev-list --left-right --count origin/main...main
0	0
```

---

## 6. Deliberately excluded from commits

| Item | Reason |
|---|---|
| `backend/pytest_*_20261112.txt`, `backend/ruff_*_20261112.txt` | Machine-specific evidence logs; untracked by design |
| `frontend/analysis_*_20261112.txt`, `flutter_test_*_20261112.txt`, `flutter_build_web_20261112.txt`, `dart_fix_dryrun_20261112.txt` | Same |
| `frontend/build/` (incl. `main.dart.js`) | Gitignored build output |
| `backend/test.db` | Gitignored (`*.db`); test database |
| `backend/storage/uploads/voice_sample_*.wav` | Runtime upload produced by tests; not source |
| `backups/` | Local backup directory |
| `tools/livekit/livekit-server.exe`, `livekit-server.zip` | Downloaded binaries |
| `frontend/lib/screens/ai_tutor/ai_tutor_shell.dart.backup` / `.bak` | User's local editor backups; preserved untracked |
| Pre-existing tracked `.bak` files (sidecar, speech, VTC) | Already in history before this audit; not touched |

No secret, credential, `.env`, or token was staged. `.env*` remains ignored;
only `backend/.env.example` is tracked.

---

## 7. Final state

- `main` is in sync with `origin/main` (`0 0`).
- Working tree contains only untracked evidence logs, local backups, and
  gitignored build/test artefacts — no uncommitted source changes.
- No branch other than `main` was created.
- History: `2071f27` → `4d87b88` → `ba3e9f8` → `daecb78` → docs commit.
