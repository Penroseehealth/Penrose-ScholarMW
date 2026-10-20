# PHASE 0 — AUDIT (advanced neuronal visualization)

## Objective
Upgrade the neuron/synapse visualization into a scientifically grounded,
interactive, animated neuronal visualization. Preserve the existing app.
Build in controlled phases; verify each phase.

## Where the neuron code actually lives
The phased prompt was written for a "Three.js r172 + Vite" app. In this repo
there are **two** neuron implementations, plus a separate standalone Three.js
lab with no neuron code yet:

| # | Engine | Location | Tech | Role |
|---|--------|----------|------|------|
| 1 | Interactive animated module | `frontend/lib/screens/biology/neuron/` | Flutter `CustomPainter` (2D) | 9-stage animated two-neuron communication, driven by reusable `ProcessSimulationViewer` |
| 2 | Static AI diagram renderer | `frontend/lib/screens/biology/visualization/` | Flutter → SVG string | `NeuronDiagramRenderer` emits SVG from a `BiologySpec` |
| 3 | Standalone 3D lab | `biology-lab/` (mirrors `Penrose-ScholarMW/frontend/web/biology_lab/`) | Three.js r172 (vendored) + vanilla JS | 3D virtual lab; **no neuron model exists** |

The prompt's "neurone generation and its animation" maps to engine **#1** for 2D
and to engine **#3** for 3D.

## Files audited
- `frontend/lib/screens/biology/neuron/neuron_scene.dart` — scene params + `NeuronPalette`.
- `frontend/lib/screens/biology/neuron/neuron_painter.dart` — the 478-line CustomPainter drawing everything (dendrites, soma, nucleus, axon, myelin, nodes, boutons, vesicles, cleft, neurotransmitters, postsynaptic membrane, receptors, ions, legend, 12 leader labels).
- `frontend/lib/screens/biology/neuron/neuron_communication_screen.dart` — the screen + the 9 `SimulationStage`s.
- `frontend/lib/screens/biology/neuron/process_simulation.dart` — `SimulationStage` / `SimulationFrame` / `TeachStep` + `buildTeachSteps`.
- `frontend/lib/screens/biology/neuron/process_simulation_viewer.dart` — generic player (play/pause/restart/step/speed/labels/explanations/zoom/fullscreen/teach-mode).
- `frontend/lib/screens/biology/visualization/neuron_diagram_renderer.dart` — SVG renderer (duplicates anatomy + palette).
- `frontend/lib/screens/biology/visualization/diagram_renderer.dart` — `kind`-based facade.
- `frontend/lib/models/biology_visualization.dart` — `BiologySpec`, `StructureSpec`.
- `frontend/lib/router/app_router.dart` — routes `/biology/*`.
- `biology-lab/js/science.js`, `objects.js`, `model_catalogue.js`, `index.html` — pure-JS module pattern + Three.js host.
- AGENTS.md validation rules.

## Structure coverage vs. the required list

| Required structure | Engine #1 (painter) | Engine #2 (SVG) |
|---|---|---|
| Dendrites connected to soma | yes | yes |
| Soma + nucleus inside | yes | yes |
| Axon hillock / initial segment | **MISSING** | **MISSING** |
| Continuous axon | yes (single straight line) | yes |
| Myelin segments | yes | yes |
| Nodes of Ranvier (exposed gaps) | partial (one dashed marker only) | partial |
| Presynaptic terminal/bouton | yes | yes |
| Synaptic vesicles inside terminal | yes | yes |
| Neurotransmitters | yes | yes |
| Synaptic cleft as real gap | yes | yes |
| Postsynaptic membrane (separate cell) | yes | yes |
| Receptors facing cleft | yes | yes |
| Postsynaptic dendrite/soma fragment | yes | yes |
| Direction-of-signal cue | animation pulse only | none (static) |
| Single source of truth for labels | **NO** (strings duplicated) | **NO** |

## Baseline checks
- `dart format --line-length=120` on neuron + visualization dirs: **0 changed** (formatted).
- `flutter analyze`: not yet run in this session (repo has many pre-existing infos elsewhere).
- No existing unit/widget tests touch the neuron module (nearest tests are math/chemistry/handwriting).

## Risks
- Geometry changes in `neuron_painter.dart` can desync the fixed `_drawLabels`
  anchor array (hand-tuned on a 1200×744 canvas).
- `ProcessSimulationViewer` is shared/generic — must stay intact for future sims.
- The prompt asks for **Three.js r172 3D**; the Flutter engine is 2D CustomPaint.
  3D must be delivered in the separate `biology-lab/` Three.js app, not in Flutter.

## Implementation plan (in prompt order, smallest safe change first)
1. **Phase 1** — `neuron_anatomy.dart`: single source of truth (ids, names,
   short+detailed function, signal role, "what to observe", anchor zone). Painter,
   SVG renderer, screen and stages read from it. Add missing `axon_hillock`.
2. **Phase 2** — polish 2D painter: hillock, drawn node gaps, persistent
   direction arrow, label zones / responsive structure list, legend, no clipping.
3. **Phase 4** — tap + keyboard structure selection with an info panel wrapping
   the existing painter.
4. **Phase 5** — map the existing 9-stage timeline onto teaching Modes A/B/C and
   expose explicit mode controls.
5. **Phase 3 (3D)** — new pure-JS `biology-lab/js/neuron_model.js` (anatomy +
   signal timeline, Node-testable) and a Three.js builder/animator in the lab
   host, with 2D fallback. Separate deliverable (different deploy surface).

## Acceptance gate (Phase 0)
Existing app unchanged and runnable; plan above is explicit; target engines
agreed (Flutter 2D + separate Three.js 3D).

## Next phase
Phase 1 — single source of truth for neuron anatomy + labels.

---

## Phase log

### Phase 1 — anatomy catalogue (done)
`neuron_anatomy.dart` is the single source of truth: 13 `NeuronStructure`
entries (id, name, shortName, region, signal, function, detail,
roleInTransmission, observe, colour-independent marker, shared anchor/label
coords), `NeuronRegion`/`NeuronSignal` enums, `neuronStructureById` /
`neuronMarkerFor`. Added the previously-missing `axon_hillock`. The CustomPainter
and the SVG renderer now read labels/anatomy from it (no duplicated strings).
Tests: `test/biology/neuron_anatomy_test.dart` → 7 passing.

### Phase 2 — 2D painter polish (done)
Persistent direction-of-signal overlay (dashed electrical path
dendrites→soma→hillock→axon→terminal and chemical path
terminal→cleft→receptors), drawn node-of-Ranvier gaps, hillock cone, marker
glyphs in leader labels, and a "Schematic — real neurones vary" note. Painters
and SVG renderer `dart analyze` clean.

### Phase 4 — structure selection (done)
`NeuronScene.selectedId`, `NeuronPainter.hitTestStructure`, tap selection, a
responsive `NeuronStructureList`, and a `NeuronInfoPanel`. Tests:
`test/biology/neuron_interaction_test.dart` → 5 passing.

### Phase 5 — teaching modes (done)
`SimulationMode` added to `process_simulation.dart`; the viewer shows a mode
selector and scopes the timeline to a mode's stage slice while still reporting
the true global stage index to the painter. The neuron screen defines Mode A
(electrical), Mode B (chemical, flagged simplified) and Mode C (guided lesson).
Tests: `test/biology/neuron_modes_test.dart` → 3 passing. Full biology suite: 15.

### Phase 3 — Three.js 3D neurone (done)
Separate deliverable inside the standalone `biology-lab/` (Three.js r172, no
React). `js/neuron_model.js` is pure data + rules (no THREE/DOM): the 13
structures (ids match the Flutter catalogue), the 9-stage timeline, teaching
modes, accuracy disclaimers, `buildNeuronGeometry()` and a deterministic
`frameAt(stage, progress)` animation state. `js/neuron_viewer.js` is the host
overlay: builds meshes from the geometry spec, orbit rig, projected labels,
raycast pick/highlight, stage/mode toolbar. Wired into `index.html` via
`?neuron=1` and a `?neutrontest=1` headless acceptance harness; added to the
smoke runner (`scripts/smoke.mjs`) and `npm test`.
Tests: `scripts/phase9_unit.mjs` → 57 passing (catalogue, timeline, modes,
geometry, mesh-count contract, animation frames).

Note: the browser smoke (`?neutrontest=1` via `smoke.mjs`) is wired but could
not be executed in this sandbox — Edge/Chrome headless produce no `--dump-dom`
output here. The pure model layer is fully unit-tested in Node; the viewer is
`syntax-checked and served correctly (200, all modules resolve).

