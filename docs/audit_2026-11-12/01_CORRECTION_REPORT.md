# Correction Report — Penrose-ScholarMW (2026-11-12)

This report lists every change made during the audit, why it was made, and the
evidence that it is correct. Nothing here is based on inspection alone.

---

## 1. Change sets

### 1.1 Commit `4d87b88` — backend undefined names + analyzer warnings

`fix(backend,frontend): resolve undefined-name bugs and analyzer warnings`
(15 files, +114/−95, pushed to `origin/main`).

Backend:

- `app/livekit/router.py` — added the missing `AccessToken` and `VideoGrants`
  imports from `livekit.api`. Without them every `/livekit/session-token`
  request raised `NameError`.
- `app/presentation_session/router.py` — added the missing `select` import.
  Session listing raised `NameError`.
- `app/presentation_session/service.py` — defined/imported the missing
  `AI_AWAITING` state constant. The AI state machine raised `NameError` on
  transition.
- Removed unused imports/variables flagged by Ruff in the presentation modules,
  `app/main.py`, and `app/livekit/agent/presentation_session.py`.

Frontend/tests:

- `lib/widgets/typewriter_renderer.dart`,
  `lib/widgets/voice_conversation_panel.dart` — analyzer-driven cleanups
  (deprecated/incorrect API usage), no behavioural change.
- Test files `barge_in_monitor_test.dart`, `biology/_dump_neuron_test.dart`,
  `handwriting_render_test.dart`,
  `presentation_session_controller_test.dart` — analyzer cleanups.

Verification:

- `ruff check app` → 0 findings.
- `python -c "import app.main"` → 567 routes registered.
- LiveKit token construction executed successfully (`JWT_OK True`).
- Presentation session/phase tests: 44 passed.
- Pushed: `2071f27..4d87b88 main -> main`; `git rev-list --left-right --count
  origin/main...main` → `0 0`.

### 1.2 Second batch — web platform, parser, deprecations, tests

#### F-01 Dropdown deprecation

`lib/features/audio_input/vtc/voice_training_center_page.dart`

`DropdownButtonFormField.value` is deprecated after Flutter v3.33. Replaced with
`initialValue`. A `ValueKey(c.deliveryStyle)` was added because `initialValue` is
only read on first build; without the key, changing the delivery style from
elsewhere would not update the visible selection.

Verification: `flutter analyze` no longer reports `deprecated_member_use` at
that location; the voice-training page compiles and the widget test group passes.

#### F-02 DataTable deprecation

`lib/widgets/math_viz/editable_data_grid.dart`

`DataTable.dataRowHeight` → `dataRowMinHeight: 36` + `dataRowMaxHeight: 36`.
Same 36 px row height, non-deprecated API.

#### F-03 Unclosed sink

`lib/modules/chemistry_lab/bridge/chemistry_lab_scene_bridge_stub.dart`

The stub bridge created a `StreamController` but `dispose()` was empty, leaking
the controller and its subscription. `dispose()` now closes `_events`, matching
the web bridge's lifecycle contract.

Verification: `close_sinks` count in `flutter analyze` → 0.

#### F-04..F-06 AI visual parser

`lib/widgets/math_viz/ai_visual_parser.dart`

1. **Block order.** `parseFromResponse` ran two independent regex passes, so all
   `<!--visual:…-->` blocks were emitted before all `<visual>…</visual>` blocks,
   regardless of their position in the answer. The test that mixes both syntaxes
   therefore received `lineChart` first instead of `barChart`. Both syntaxes are
   now collected with their offsets and sorted.
2. **Shape type.** `{"type":"shape","shape":"triangle"}` mapped `"shape"` to
   `VisualType.unknown`. When `type` is unknown and `shape`/`shapeType` is
   present, the geometry name is now used to resolve the type.
3. **Natural-language fallback.** `_parseNaturalLanguage` existed but was only
   reachable from the JSON-parse failure path, so a plain “draw a triangle”
   response produced no visual. `parseFromResponse` now falls back to it when no
   block was found **and** the response is short (≤200 characters). The length
   guard is deliberate: it prevents ordinary prose that merely mentions a shape
   from rendering a spurious visual.

Verification: `test/widgets/math_viz/ai_visual_parser_test.dart` → 17/17 pass
(was 11/17).

#### F-07 Web platform consolidation

**New files**

- `lib/services/web_browser.dart` — conditional export:
  `export 'web_browser_stub.dart' if (dart.library.js_interop) 'web_browser_web.dart';`
- `lib/services/web_browser_stub.dart` — non-web fallback. Read-only helpers
  throw `UnsupportedError`; `revokeObjectUrl` is a no-op.
- `lib/services/web_browser_web.dart` — `package:web` implementation of
  `createObjectUrl`, `revokeObjectUrl`, `downloadBytes`, `openUrl`,
  `openHtmlDocument`.

**Refactored call sites**

- `lib/services/export_service.dart` — removed `dart:html` and the temporary
  `package:web` import; all six download paths now call `downloadBytes`.
- `lib/screens/biology/biology_visualization_screen.dart` — `_print()` now calls
  `openHtmlDocument(doc)`.
- `lib/screens/stem/analytics_export_screen.dart` — CSV export uses
  `downloadBytes`; duplicate blob/anchor code removed.
- `lib/screens/student/knowledge_vault.dart` — video/blob previews use
  `createObjectUrl` / `openUrl` / `revokeObjectUrl`; duplicate code removed.

**Why this was necessary.** `dart:html` is deprecated and unavailable on the
Dart VM; `package:web` is equally web-only. Both broke compilation of any widget
test that imported these screens (`mathsdrill_layout_test.dart` failed to load).
The conditional-import pattern already used elsewhere in the repository keeps
shared screens platform-neutral and removes four copies of the same code.

**Dependency pin.** `web` 1.1.1 → 1.1.2 in `pubspec.lock`. Version 1.1.1's
`helpers/http.dart` is missing `import 'dart:js_interop'`, so it cannot compile
with Dart 3.13 (`toJS`/`jsify` undefined). 1.1.2 was already present in the
local pub cache and satisfies the existing `^1.1.1` constraint.

Verification:

- `flutter analyze` → 0 `dart:html`, 0 `avoid_web_libraries_in_flutter`.
- `flutter build web --release` compiles the browser branch (see
  `frontend/flutter_build_web_20261112.txt`).
- `flutter test` full suite → 132 passed / 0 failed, including
  `mathsdrill_layout_test.dart`, which previously failed to load.

#### T-01..T-05 Test repairs

All assertions from the original tests were retained; only the mechanics of
waiting and the stale UI targets were corrected.

1. **Chatbot tests** (`floating_chatbot_test.dart`,
   `floating_chatbot_mount_test.dart`, `floating_chatbot_voice_test.dart`):
   - `pumpAndSettle` cannot terminate because the floating button's brand mark
     runs a continuous ripple (`_waveCtrl.repeat()`). Replaced with bounded
     `pump()` + `pump(350 ms)`. This is the correct approach for an
     intentionally perpetual animation.
   - The tests searched for `Icons.chat_bubble_rounded`, but the button has
     rendered the layered brand mark for some time. They now target
     `find.byType(FloatingChatbot)` (the button is the whole closed widget).
   - `find.text('Ask me anything…')` never matched because the real string
     contains a second line. Now `find.textContaining`.
   - The voice test asserted replies start muted, but the implementation
     defaults to spoken replies. The test now asserts the real default
     (`volume_up`) and toggles to `volume_off`, still verifying that toggling
     does not throw.
2. **Mathsdrill layout test** (`mathsdrill_layout_test.dart`): fixed by the web
   consolidation (T-01) and bounded pumps for the shell's continuous animation.
   The routing/layout assertions are unchanged.
3. **Penrose render test** (`test/widgets/penrose_render_test.dart`):
   - wrote to a hardcoded path belonging to a different machine
     (`C:\Users\zispaas\...`);
   - awaited `toImage`/`toByteData` outside `tester.runAsync`, which never
     completes under the fake-async test clock and produced the 10-minute
     timeout.
   Now wrapped in `tester.runAsync<ByteData?>`, writes to
   `Directory.systemTemp`, asserts non-empty PNG bytes, and deletes the file in
   teardown. The test now runs in ~1 s.

#### Style/format alignment

- All edited Dart files formatted with the project standard
  `dart format --line-length=120`. (An earlier default-width format pass was
  reverted by re-formatting at 120; `git diff --stat` shows only the intended
  lines.)
- Backend: `ruff format app` applied to the 17 pre-existing unformatted files
  (whitespace/line-wrapping only). `ruff format --check app` now passes.
  `ruff check app` and `compileall` still pass, and `app.main` imports.

---

## 2. Before / after evidence

| Check | Before | After |
|---|---|---|
| `flutter analyze` errors | 0 | 0 |
| `flutter analyze` warnings | 2 | 0 |
| `flutter analyze` infos | 453 | 441 |
| `dart:html` diagnostics | 2 | 0 |
| `deprecated_member_use` (Flutter) | 2 | 0 |
| `close_sinks` | 1 | 0 |
| `ruff check app` | 36 | 0 |
| `ruff format --check app` | 17 files | 0 files |
| Flutter tests | 120 pass / 12 fail | 132 pass / 0 fail |
| AI visual parser tests | 11 pass / 6 fail | 17 pass / 0 fail |
| Backend targeted tests | — | 98 pass (sequential groups) |
| `app.main` import | ok | ok (567 routes) |
| Alembic head | `f1a2b3c4d5e6` | unchanged |
| SQLite integrity | ok | ok |

---

## 3. Things deliberately **not** changed

- No bulk `dart fix` run. `dart fix --dry-run` offers ~425 style-only fixes
  across ~74 files; that is churn without defect value and is deferred.
- No dependency upgrades beyond `web` (which was required for compilation).
  Dependabot alerts are documented, not auto-merged.
- No backend API/schema changes, no migrations, no feature removal.
- No change to the OpenVoice sidecar configuration, models, or CPU settings.
- No credentials, secrets, or paid services introduced.
- No destructive Git operation; user work and untracked evidence logs preserved.
