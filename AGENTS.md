# AGENTS.md — Auto-Debug Workflow

## Mandatory Post-Edit Validation

### Flutter/Dart (frontend/lib/**/*.dart)

After **every** edit to any `.dart` file, you MUST run:

```bash
# Format (must be 0 issues)
dart format --line-length=120 --output=none --set-exit-if-changed frontend/lib/
# ...or just the files you changed:
dart format --line-length=120 --output=none --set-exit-if-changed frontend/lib/path/to/file.dart

# Analyze (must be 0 issues)
cd frontend && flutter analyze --no-fatal-infos --no-fatal-warnings
```

- `analysis_options.yaml` enforces: `strict-casts`, `strict-raw-types`, `strict-inference`, prefer_const, avoid_print, and 100+ lint rules.
- `dart format --line-length=120` is the project standard.
- If `flutter analyze` reports any error or warning, fix it before proceeding.

### HTML/JS (frontend/index.html)

After **every** edit to `frontend/index.html`, you MUST run:

```bash
python tools/validate_html_js.py
```

Checks: brace/paren/bracket balance, function scope, HR reference integrity, inline handler quote balance.

### Backend (backend/**/*.py)

After **every** edit to `backend/**` (Python), you MUST run:

```bash
python -m ruff check backend/app
python -m ruff format --check backend/app
```

- Lint config lives in `backend/pyproject.toml` (line-length 88). Rules: `F` (pyflakes), `E4/E7/E9` (core style), `I` (import sorting). `E701/E702/E711/E712` ignored (SQLAlchemy `== True`/`!= None` is deliberate).
- Auto-fix: `python -m ruff check --fix backend/app`
- Format: `python -m ruff format backend/app`

## Quick Validation (all in one)

```bash
# Frontend dart
cd frontend && flutter analyze --no-fatal-infos --no-fatal-warnings

# Backend python
python -m ruff check backend/app && python -m ruff format --check backend/app

# HTML/JS
python tools/validate_html_js.py
```

## Pre-commit Hooks

`.pre-commit-config.yaml` runs all checks on `git commit`:

| Hook | What it checks | On |
|------|---------------|-----|
| `ruff` + `ruff-format` | Python lint & format (uses `backend/pyproject.toml`, 88 chars) | `backend/**`, `tools/**`, `scripts/**` |
| `dart-format` | Dart formatting (120 chars) | `**/*.dart` |
| `flutter-analyze` | Dart static analysis (0 issues) | `**/*.dart` |
| `validate-html-js` | HTML/JS structural integrity | `frontend/index.html` |

Setup once:
```bash
pip install pre-commit
pre-commit install
```

Run manually:
```bash
pre-commit run --files frontend/lib/path/to/file.dart
pre-commit run --files backend/app/path/to/file.py
```

## Editor Settings

- `.vscode/settings.json` — format-on-save for Dart (flutter extension) and Python (ruff extension; Python rules at 88, Dart at 120)
- `.vscode/extensions.json` — recommended extensions (Flutter, Ruff, Prettier, EditorConfig)
- `.editorconfig` — cross-editor consistency (2-space indent for Dart/JSON, 4-space for Python)

## File Locations

- Main Flutter file: `frontend/lib/` (multi-file architecture)
- Legacy HTML: `frontend/index.html` (~52K lines)
- Validator: `tools/validate_html_js.py`
- Dart format checker: `tools/dart_format.py`
- Flutter analyze checker: `tools/flutter_analyze.py`
- Ruff check wrapper: `tools/ruff_check.py`
- Backend: `backend/app/` (FastAPI, Python)
- Server: `backend\.venv\Scripts\python.exe backend\run.py` (port 8000, cwd `backend/`)
  - Use the venv interpreter. The system `python` has no `sqlalchemy` and fails at import.
  - Startup takes ~10s; `/health` and `/docs` are the readiness checks.
  - `backend/app/main.py` serves the Flutter SPA from `frontend/build/web` and requires
    `main.dart.js` to exist. Run `flutter build web --release` (cwd `frontend/`) if the web
    build is missing or `main.dart.js` is absent, otherwise the app fails to import.
- Local dev proxy: `tools/penrose_web_proxy.py` (port 8080, serves `tools/build/web`, forwards `/api/*` to :8000, timeout 60s)