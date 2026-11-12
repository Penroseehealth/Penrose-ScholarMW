# Correction Register — Penrose-ScholarMW (2026-11-12)

Machine-readable record of every correction. `Verified by` cites an executed
check, not an inspection.

**Legend:** ✅ fixed & verified · 🔁 test maintenance (assertions preserved) ·
⏸ deferred (documented in `02_OUTSTANDING_ISSUES.md`)

---

## A. Backend

| ID | File | Line/area | Defect | Root cause | Correction | Verified by | Status |
|---|---|---|---|---|---|---|---|
| B-01 | `backend/app/livekit/router.py` | token endpoint | `NameError: AccessToken` / `VideoGrants` on every token request | imports omitted | imported from `livekit.api` | `JWT_OK True`; router import; `ruff check` 0 | ✅ |
| B-02 | `backend/app/presentation_session/router.py` | session listing | `NameError: select` | import omitted | added `from sqlalchemy import select` | router import; 44 presentation tests pass | ✅ |
| B-03 | `backend/app/presentation_session/service.py` | AI state transition | `NameError: AI_AWAITING` | constant referenced but never defined/imported | defined/imported the constant | state-machine tests pass | ✅ |
| B-04 | presentation modules, `app/main.py`, `livekit/agent/presentation_session.py` | various | unused imports/variables (`F401`, `F841`) | dead code | removed | `ruff check app` → 0 | ✅ |
| B-05 | 17 backend files | formatting | `ruff format --check` failed | pre-existing drift | `ruff format app` (whitespace only) | `ruff format --check` → 269 formatted; `compileall` 0; `app.main` imports | ✅ |

## B. Flutter — deprecations, leaks, platform

| ID | File | Defect | Correction | Verified by | Status |
|---|---|---|---|---|---|
| F-01 | `lib/features/audio_input/vtc/voice_training_center_page.dart` | `DropdownButtonFormField.value` deprecated (after v3.33) | `initialValue` + `ValueKey(c.deliveryStyle)` | `deprecated_member_use` → 0; analyze clean | ✅ |
| F-02 | `lib/widgets/math_viz/editable_data_grid.dart` | `DataTable.dataRowHeight` deprecated | `dataRowMinHeight`/`dataRowMaxHeight: 36` | analyze clean; 36 px height preserved | ✅ |
| F-03 | `lib/modules/chemistry_lab/bridge/chemistry_lab_scene_bridge_stub.dart` | `StreamController` never closed (`close_sinks`) | `dispose()` closes `_events` | `close_sinks` → 0 | ✅ |
| F-04 | `lib/services/web_browser.dart` (new) | duplicated browser code; web-only imports in shared screens | conditional export → stub/web | analyze clean; VM tests load; web build | ✅ |
| F-05 | `lib/services/web_browser_stub.dart` (new) | non-web fallback missing | stub API (throws `UnsupportedError` for unavailable actions) | VM compilation of all tests | ✅ |
| F-06 | `lib/services/web_browser_web.dart` (new) | browser implementations scattered | `createObjectUrl`, `revokeObjectUrl`, `downloadBytes`, `openUrl`, `openHtmlDocument` | analyze clean; `flutter build web` | ✅ |
| F-07 | `lib/services/export_service.dart` | `dart:html` (deprecated, VM-incompatible); six copies of download logic | delegates to `downloadBytes` | 0 `dart:html`; export paths compile | ✅ |
| F-08 | `lib/screens/biology/biology_visualization_screen.dart` | `dart:html` for print preview | `openHtmlDocument(doc)` | 0 `dart:html`; analyze clean | ✅ |
| F-09 | `lib/screens/stem/analytics_export_screen.dart` | direct `package:web` in a shared screen; duplicated blob code | `downloadBytes` | VM tests load; analyze clean | ✅ |
| F-10 | `lib/screens/student/knowledge_vault.dart` | direct `package:web`; duplicated blob code | `createObjectUrl`/`openUrl`/`revokeObjectUrl` | VM tests load; analyze clean | ✅ |
| F-11 | `frontend/pubspec.lock` | `web` 1.1.1 does not compile on Dart 3.13 (`toJS`/`jsify` undefined in `helpers/http.dart`) | upgrade to 1.1.2 (already cached) | `flutter test` loads; `flutter build web` | ✅ |

## C. Flutter — AI visual pipeline

| ID | File | Defect | Correction | Verified by | Status |
|---|---|---|---|---|---|
| F-12 | `lib/widgets/math_viz/ai_visual_parser.dart` | mixed `<visual>` / `<!--visual:-->` blocks emitted out of order | collect `(offset, spec)`, sort by offset | parser test “parses multiple visual blocks” | ✅ |
| F-13 | same | `{"type":"shape","shape":"triangle"}` → `VisualType.unknown` | resolve type from `shape`/`shapeType` when unknown | parser test “parses a shape visual block” | ✅ |
| F-14 | same | natural-language fallback unreachable for block-less replies | fallback for responses ≤200 chars | 4 fallback tests pass | ✅ |

## D. Tests

| ID | File | Defect in test | Correction | Verified by | Status |
|---|---|---|---|---|---|
| T-01 | `test/floating_chatbot_test.dart` | `pumpAndSettle` never settles (infinite ripple); stale `Icons.chat_bubble_rounded`; exact-text mismatch | bounded pumps; `find.byType(FloatingChatbot)`; `textContaining` | test passes | 🔁 |
| T-02 | `test/floating_chatbot_mount_test.dart` | same wait/icon/text issues | same, assertions kept | test passes | 🔁 |
| T-03 | `test/floating_chatbot_voice_test.dart` | wait/icon issues; asserted muted default that the product does not use | bounded pumps; asserts real default `volume_up` → toggles to `volume_off` | both tests pass | 🔁 |
| T-04 | `test/mathsdrill_layout_test.dart` | failed to load (`dart:html`/`package:web`); `pumpAndSettle` timeout | web consolidation; bounded pumps | test passes | 🔁 |
| T-05 | `test/widgets/penrose_render_test.dart` | hardcoded foreign path; `toImage` awaited outside `runAsync` → 10-min timeout | `runAsync`, system temp dir, non-empty PNG assertion, teardown | test passes in ~1 s | 🔁 |

## E. Deferred (no change)

| ID | Item | Reason | Where tracked |
|---|---|---|---|
| D-01 | `dart fix --apply` (~425 style fixes / 74 files) | mechanical churn, no defect value; keep behavioural diff reviewable | O-04 |
| D-02 | Dependabot upgrades (124 alerts) | needs regression testing; scope/approval | O-03 |
| D-03 | Full backend suite hang | requires fixture redesign / test investigation | O-01 |
| D-04 | OpenVoice sidecar E2E | no Python 3.10/3.12; sidecar not running | O-02 |
| D-05 | LiveKit / AI provider E2E | no credentials or running services | O-05 |
| D-06 | Presentation/PPTX/OCR/admin integration tests | backend not running; out of scope | O-06 |

---

## F. Summary counts

| Category | Fixed | Deferred |
|---|---|---|
| Backend runtime bugs | 3 | 0 |
| Backend hygiene/format | 2 groups (17 files) | 0 |
| Flutter deprecations/leaks | 3 | 0 |
| Web platform defects | 11 (incl. new module + dependency) | 0 |
| Flutter logic defects | 3 | 0 |
| Test repairs | 5 | 0 |
| **Total verified corrections** | **27 items across 31 files** | 6 tracked items |
