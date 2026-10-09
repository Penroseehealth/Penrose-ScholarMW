# Biology Lab 3D — Flutter ↔ Three.js Integration

> Mirrors `lib/modules/chemistry_lab/docs/INTEGRATION.md`. Read that first for
> the shared philosophy: Flutter owns navigation, UI, science content and
> state; JavaScript owns the 3D scene, camera, picking and rendering.

## Architecture

```
Flutter/Dart  ── commands (JSON) ──▶  bio-scene.js (ES module)  ──▶  three.js
     ▲                                  │                    └──▶  Mol* iframe (molecular level)
     └────────── events (JSON) ─────────┘
```

- **Flutter** owns the biological asset registry, hierarchy navigation,
  lesson/practical content, assessment scoring, and UI chrome.
- **JavaScript** owns the 3D viewport: renderer, camera, OrbitControls-style
  interaction, object picking, HTML labels with leader lines, animation
  interpolation, and the Mol* molecular-viewer iframe.
- The only coupling is the abstract `BioLabBridge` interface in
  `bridge/bio_lab_bridge.dart`. No other app code imports `dart:js_interop`
  or `package:web` for this module.

## Lazy loading

`biology_lab/bio-scene.js` (with its static import `three.module.min.js`,
MIT — vendored copy, see `THREE-LICENSE.txt`) is injected as a
`<script type="module">` ONLY when the `/bio-3d-lab` route opens. The Mol*
runtime (`biology_lab/molstar/`, ~5 MB) is fetched only when the user enters
the molecular level. Nothing 3D loads at app startup.

## Command contract (Dart → JS)

Single entry: `window.PenroseBioLab.handle(jsonString)`. Every command is
`{"cmd": "...", ...}`.

| cmd | payload | effect |
|---|---|---|
| `init` | `{hostId}` | create renderer inside host element; emits `ready` |
| `dispose` | — | release renderer, geometries, materials, listeners |
| `loadScene` | `{spec}` | rebuild scene from spec (below) |
| `selectObject` | `{id}` | programmatic selection; `null` clears |
| `setLabelsVisible` | `{visible}` | toggle HTML label overlay |
| `setVisibility` | `{groups:{name:bool}}` | toggle named object groups |
| `setTransparency` | `{value}` | 0–1 global ghost mode on all non-selected objects |
| `focusObject` | `{id}` | smooth camera transition to an object |
| `resetCamera` | — | return to the scene's default camera |
| `loadAnimation` | `{id}` | select an animation defined in the scene spec |
| `play` / `pause` / `resume` / `restart` | — | playback control |
| `setSpeed` | `{value}` | 0.25–8× multiplier |
| `setTimeline` | `{t}` | scrub: absolute progress 0.0–1.0 |
| `showTransition` | `{text, scaleLabel}` | display the multiscale transition overlay |
| `showMolecule` | `{pdb, label}` | swap viewport to the Mol* iframe (offline local PDB) |
| `hideMolecule` | — | remove the Mol* iframe, restore the Three.js scene |

## Event contract (JS → Dart)

Registered by Dart before script load:
`window.__penroseBioLabEvent(type, json)` and load notification
`window.__penroseBioLabEngineLoaded()`.

| event | payload |
|---|---|
| `engineLoaded` | `{}` — API object is ready |
| `ready` | `{}` — renderer initialised |
| `error` | `{message}` — recoverable engine error |
| `stateChanged` | `{state}` — `idle | running | paused | molecular` |
| `selection` | `{id, name}` or `{id: null}` |
| `progress` | `{value, message}` — load progress 0–1 |
| `time` | `{t}` — animation timeline position 0–1 (throttled) |
| `stepChanged` | `{index}` |
| `molecule` | `{type: ready|error, message}` — Mol* iframe events |

## Scene spec

```json
{
  "sceneId": "bacterial-cell",
  "camera": {"position": [x,y,z], "target": [x,y,z], "background": "#0b1220"},
  "scaleInfo": {"label": "~1 µm × 500,000", "note": "educational reconstruction"},
  "groups": ["wall", "membrane", "genetic", "motility", "ribosomes"],
  "objects": [
    {"id": "cell-wall", "name": "Cell wall", "type": "capsuleShell",
     "group": "wall", "params": {"radius": 1.0, "length": 2.2, "thickness": 0.08},
     "position": [0,0,0], "rotation": [0,0,0], "scale": 1,
     "color": "#8fa3b8", "opacity": 0.9, "roughness": 0.7, "metalness": 0.0,
     "selectable": true, "label": "Cell wall — rigid peptidoglycan layer",
     "labelOffset": [0, 1.3, 0]}
  ],
  "animations": [
    {"id": "flagellar-motion", "title": "Flagellar motion (schematic)",
     "duration": 4.0,
     "tracks": [{"objectId": "flagellum", "property": "rotation",
                 "keyframes": [{"t": 0.0, "value": [0,0,0]}, {"t": 1.0, "value": [0,0,12.56]}]}]}
  ]
}
```

Object geometry types: `sphere`, `sphereBlob` (deformed ellipsoid),
`capsule`, `capsuleShell` (hollow, open ends), `cylinder`, `tube` (curve
through `params.points`), `helix` (double helix with `params.turns`),
`torus`, `box`, `cone`, `disc`.

**Important honesty rule (enforced in Dart, respected in JS):** every scene
is an *educational reconstruction* built from textbook morphology — the
models are clearly labelled as such, with `scaleInfo.note`. They are never
presented as experimentally determined structures. Molecular level scenes
use Mol* with real, locally-vendored PDB entries (1BNA, 1HHO — RCSB PDB,
free use with attribution).

## Selection & labels

- Raycast picking on pointer up (not during orbit drag). Selected object
  gets an emissive highlight; the scene emits `selection`.
- Labels are HTML divs with SVG leader lines from the anchor point to the
  projected 3D position of `labelOffset` relative to the object. Occlusion
  is NOT computed (labels always visible; acceptable for education).
- Labels collapse into dots when pointing off-screen or behind the camera.

## Animation model

Keyframe interpolation with cubic ease-in-out per track. The timeline `t`
is the single source of truth: `play` advances `t` by speed/duration,
`setTimeline` evaluates tracks at absolute `t`, `pause` stops advancing,
`restart` resets `t=0`. All interpolation is visual-only; no physics.
