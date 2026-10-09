# Chemistry Lab — Flutter ↔ Three.js Integration

## Architecture

```
Flutter/Dart  ── commands (JSON) ──▶  lab-scene.js (ES module)  ──▶  three.js
     ▲                                  │
     └────────── events (JSON) ─────────┘
```

- **Flutter** owns navigation, UI, experiment workflow, all chemistry math,
  state, and accessibility.
- **JavaScript** owns 3D scene, camera, rendering, picking, visual
  interpolation. It never computes chemistry.
- The only coupling is the abstract `LabBridge` interface in
  `bridge/lab_bridge.dart`. The rest of the app never imports
  `dart:js_interop` or `package:web` for lab purposes.

## Lazy loading

`chemistry_lab/lab-scene.js` (and its static import
`three.module.min.js`, MIT-licensed, vendored from three.js 0.169.0) is
**only** fetched when the `/chem-lab` route opens: `WebLabBridge._ensureScript`
injects a `<script type="module">` tag once per page load. Nothing 3D loads
at app startup. There is no npm/package.json/build step — static files in
`frontend/web/` are served as-is by the existing backend SPA handler.

## Command contract (Dart → JS)

Single entry point: `window.PenroseChemLab.handle(jsonString)`.

| cmd | payload | effect |
|---|---|---|
| `init` | `{hostId}` | create renderer in host element; emits `ready` |
| `dispose` | — | release renderer, geometries, materials, listeners |
| `loadExperiment` | `{spec}` | rebuild scene from spec (see below) |
| `loadModel` | `{url, objectId}` | Stage 6 (GLB/GLTF); currently errors `model-loader-unavailable` |
| `play` / `pause` / `resume` | — | start/stop parameter interpolation |
| `reset` | — | restore all objects to initial transform/colour |
| `replay` | — | `reset` + `play` |
| `setSpeed` | `{value}` | 0.25–8× multiplier |
| `setLabelsVisible` | `{visible}` | toggle HTML label overlay |
| `updateParams` | `{params:{objects:{id:{…}}}}` | queue visual targets |
| `selectObject` | `{id}` | programmatic selection (`null` clears) |

### Scene spec

```json
{ "camera": {"position":[x,y,z], "target":[x,y,z], "background":"#hex"},
  "objects": [
    {"id":"burette","name":"Burette","type":"cylinder",
     "kind":"apparatus|reagent|furniture",
     "params":{"radius":0.16,"height":5.6},
     "position":[x,y,z], "rotation":[x,y,z], "scale":1|[x,y,z],
     "color":"#hex","opacity":0.35,"roughness":0.5,"metalness":0.05,
     "doubleSided":true,"selectable":true,
     "label":"…","labelOffset":[x,y,z]} ] }
```

Types: `box | cylinder | sphere | cone | torus`.

## Event contract (JS → Dart)

Dart installs `window.__penroseChemLabEvent(type, jsonPayload)` before
injecting the script.

| event | payload | meaning |
|---|---|---|
| `ready` | `{version}` | init succeeded |
| `progress` | `{value 0–1, message}` | load progress |
| `stateChanged` | `{state: ready\|running\|paused}` | engine playback state |
| `selection` | `{id, name, kind}` | viewport pick (`id:null` = cleared) |
| `error` | `{code, message}` | see error codes below |

### Error codes

`no-webgl`, `host-missing`, `renderer-failed`, `script-load-failed`,
`init-timeout`, `context-lost`, `unsupported-platform` are **fatal** → the
provider enters `LabPhase.error` and the screen shows the static fallback.
Everything else (e.g. `model-loader-unavailable`) is non-fatal: reported but
the session stays live.

## Accuracy tiers (scientific integrity)

Every displayed quantity is one of:

1. **Validated** — authored constants/equations vetted against established
   chemistry (equation strings, atomic weights, indicator ranges).
2. **Calculated** — deterministic Dart outputs from those inputs
   (`chemistry/stoichiometry.dart`, `simulation/titration_controller.dart`):
   pH curve, moles, titre, concentrations.
3. **Illustrative animation** — the 3D picture (liquid levels, indicator
   colour tween). Interpolated visuals must follow the calculated values,
   never lead them.
4. **AI-generated explanation** — none at present; any future AI text must
   be labelled as such in the UI.

The lab never presents itself as a substitute for supervised practical
work; the disclaimer appears in the idle panel and safety brief.

## Lifecycle & disposal

1. Route opens → `ChemistryLabProvider` created (bridge constructed, event
   subscription installed). WebGL probed; unsupported → immediate fallback.
2. `LabViewport` creates the host `<div>` (`HtmlElementView.fromTagName`,
   styled via conditional import `host_styling_web.dart`), then
   `bridge.init(hostId)` runs. Script injected once per page load.
3. Scene loads for the current mode (idle bench or experiment).
4. Route closes → provider disposes: subscription cancelled,
   `bridge.dispose()` sends `dispose` → JS cancels the RAF loop, unbinds
   input, disconnects `ResizeObserver`, disposes geometries/materials,
   frees the renderer context, removes canvas + labels from the DOM.
5. Reopening re-inits cleanly (JS `init` self-disposes any prior state).

`LabViewport` does **not** dispose the bridge — the provider owns it, so
each resource has exactly one owner.

## Threading the needle: what lives where

| Concern | File |
|---|---|
| pH, moles, stoichiometry | `chemistry/stoichiometry.dart` (pure Dart, unit-tested) |
| Equation parsing/balance checks | `chemistry/equations.dart` |
| Workflow state, endpoints | `simulation/titration_controller.dart` |
| Experiment content/safety/questions | `experiments/*.dart` |
| Scene JSON | `scenes/*.dart` |
| Rendering, picking, camera | `web/chemistry_lab/lab-scene.js` |

## Tests

- `test/chemistry_lab/stoichiometry_test.dart` — pH curve incl. equivalence
- `test/chemistry_lab/equations_test.dart` — formula + balance parsing
- `test/chemistry_lab/experiment_catalogue_test.dart` — completeness gate
- `test/chemistry_lab/chemistry_lab_provider_test.dart` — state machine via
  fake bridge
- `test/chemistry_lab/titration_controller_test.dart` — quantitative run,
  reset/replay
- `test/chemistry_lab/chemistry_lab_screen_test.dart` — fallback UI

Run: `cd frontend && flutter test test/chemistry_lab/`

## Accessibility

- Canvas host has `aria-label` with keyboard instructions; arrow keys orbit,
  `+`/`-` zoom, `Esc` clears selection.
- All controls are standard Flutter widgets (focusable, semantic labels).
- Labels in the 3D view are mirrored by the Flutter selection readout.
- Without WebGL the entire workflow remains usable via the static fallback.

## Licensing

`web/chemistry_lab/three.module.min.js` — three.js, MIT License, see
`web/chemistry_lab/THREE-LICENSE.txt`. Vendored once from an existing local
install; no npm dependency was added to this repository.
