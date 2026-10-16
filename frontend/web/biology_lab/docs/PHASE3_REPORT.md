# Phase 3 Report — Equipment Catalogue & Per-Object Actions (biology lab)

Date: 2026-10-15
Branch: `phase1-teacher-nav` (on top of Phase 2 commit `8805b92`)
Scope: CSV upgrade plan Phase 3 only — reusable per-object action interface,
equipment-catalogue interactions (microscope objective/focus/illumination,
taps, drawers, balance) and equipment state consistency. Phase 4+ not started.

## What shipped

| File | Role |
|---|---|
| `js/objects.js` | Action catalogue on the world store: `defineAction/action/actionsFor/checkPre/actionSteps` (pre = declarative `check` object or `fn(world,opts)`; steps = step array or `fn(world,opts)`; verify = declarative or fn; optional sound + priority). `actionSteps` appends a VERIFY step and the sound emit, so every action is verify-gated before it can complete. Plus `wireBalance(itemId,balanceId,opts)` — a pure store coupling that updates a balance's readout when a registered item is released onto (or lifted off) the pan. |
| `js/behaviour.js` | `behav.interact(objId, actionName, opts)` — submits a task built from a world-registered action; fails fast with `no-world` / `no-action:<id>:<name>` / `precondition:<id>:<name>` / `no-steps` without ever entering the queue; otherwise delegates to `behav.submit` at the action's priority (or an override). |
| `index.html` | Microscope part tagging (`userData.part` = lamp/stage/nosepiece/rheostat/focusKnob, `userData.mag` on objectives; `addBenchMicroscopes` now returns the placed black scopes; the front-bench scope is captured as `frontScope`). Two-way tap sync (`toggleTap` writes `tap.front.running` back to the world when the user clicks the tap; the world mirror drives `ref.target` + the status line). New `buildPhase3` IIFE: locates the front-bench tap + nearest room-side bench drawer in the live scene, builds a top-loading balance prop (base, pillar, pan, canvas-texture display, hit target) at (−1.05, H, −2.9), registers `micro.front` / `tap.front` / `balance` / `benchFront.drawer` (plus jar `massG:128.5`), defines the action catalogue (microscope illuminate/darken/select-objective/focus, tap open/close, bench drawer open/close, balance tare), wires `wireBalance`, captures live microscope parts (per-instance lamp material clone + PointLight), mirrors world→mesh (lamp emissive + light, nosepiece objective slot-swap + settle nod, stage xz + focus height + knob spin, tap water target, balance display redraw, drawer open + `playDrawer`), composes the three scenarios from `actionSteps` (microscope/tap) and plain steps (weigh), exposes `phase3.trigger/interact/wireSounds/frame`, sets `teacherDiag.equipment`. New audio `playWater` / `playMicroClick`, wired via `behav.on` in `attachTeacher`. `frame()` eases the nosepiece settle; `teacherInfo` reports `equipment` + `ready`. `?scenario=microscope\|tap\|weigh` works through the existing generic trigger; `?behavtest=1` gained 29 Phase-3 checks. |
| `scripts/phase3_unit.mjs` | 41 Node checks (no THREE/DOM): action-registry semantics (declarative + fn pre/steps/verify, verify+sound append, unknown-action null), microscope scenario + state + stats mirror + precondition blocks (re-illuminate, invalid mag, re-darken), tap scenario + interact open/close + mirror + re-open block, bench drawer open/close via catalogue + re-open block, lying action fails its VERIFY, drawer-retrieve then weigh (balance reads 128.5 g via `wireBalance`, jar world pos at pan, carried, tare blocked on occupied pan, readout clears when the jar is removed, tare completes when empty), interact interruption of a long walk + resume, unknown action fails fast. Mirrors the host registrations/actions/scenarios against the real nav grid + real Phase-1 controller + real behaviour module with the fake rig. |
| `scripts/smoke.mjs` | Extended: the `?diag=1` pass additionally asserts `teacher.equipment === 4 && teacher.ready === true`; every new behavtest check is auto-asserted. **143/143** (was 113). |

## Architecture notes

- **One action contract for every object**: an action is data attached to a
  world-registered object — `{pre, steps, verify, sound, priority}`. Preconditions
  are checked before the task starts (declarative world paths or parameterised
  functions like `select-objective`'s mag whitelist); completion conditions run
  as a VERIFY step appended by `actionSteps`, so an action can never report
  success for a state that did not actually change (unit-tested with a
  deliberately lying action). `behav.interact` is the single entry point and
  fails fast on unknown actions or unmet preconditions.
- **Scenarios compose from the catalogue**: the microscope scenario is
  `goto/align` + `actionSteps('illuminate')` + `actionSteps('select-objective',{mag:10})`
  + `actionSteps('focus',{to:.72})` — the same action data that `interact` uses,
  so manual and scripted interactions share one definition.
- **State consistency (CSV)**: microscope illumination/objective/focus/stage are
  world state; the host mirror applies them synchronously to the live scope
  (lamp emissive + PointLight, objective groups re-slotted onto the optical
  axis, movable stage offset, knob rotation) with a cosmetic settle-nod eased in
  `frame()`. The balance updates when the jar is released on the pan
  (`wireBalance`, a pure store rule shared with the unit tests) and clears when
  it is lifted; the canvas display redraws from world state. Tap `running` is
  two-way: behaviour sets it and the existing water animation follows; a user
  click on the tap writes back through `toggleTap`. Bench-drawer open/close
  state persists through the world store and drives the mesh + sound; the jar's
  Phase-2 drawer sync is untouched. Held objects still follow the hand
  (`attachToHand` snap) and released objects stay at the release point (jar
  world pos asserted at the pan within 5 cm).
- **Equipment, not decoration**: the four registered catalogue objects each
  expose 1–4 meaningful actions with real preconditions; `balance.tare` is
  blocked while a specimen is on the pan; re-opening a running tap or an open
  drawer is blocked. The catalogue count and readiness surface in the diag dump
  (`teacher.equipment`, `teacher.ready`).
- **Walkable approach points** (verified by driving the real grid in
  behavtest/unit): microscope (0.5, −1.9), tap (0, −1.9), balance (−0.5, −1.9),
  bench drawer (−0.584, −1.9) — all on the clear strip between the front bench
  and the left island's inflation.

## Verification

| Gate | Result |
|---|---|
| `node scripts/phase1_unit.mjs` | 53/53 |
| `node scripts/phase2_unit.mjs` | 54/54 |
| `node scripts/phase3_unit.mjs` | 41/41 |
| `node scripts/smoke.mjs` | 143/143 (diag + navtest + behavtest; behavtest zero failures, no page errors) |

Behavtest Phase-3 highlights (all asserted by smoke): catalogue objects +
actions present; microscope scenario → illumination true / objective 10 /
focus 0.72 with visuals mirrored; re-illuminate and invalid-mag blocked;
objective switch to 4x via interact; tap scenario opens then closes with the
mirror in step (toggles counted); tap open/close via interact; re-open blocked;
bench drawer opens/closes via the catalogue and persists; weigh carries the jar
to the pan → balance reads 128.5 g, jar world pos at the pan, attach count
grew; tare blocked while occupied; unknown action fails fast with `no-action`.

## Notes / non-goals

- Only the front-bench black microscope is fully wired (lamp/nosepiece/stage);
  the other scopes keep the tagged parts for future wiring but no per-scope
  lights (avoids 15 extra point lights).
- The pre-existing slight overlap of the phone base with the front-bench
  microscope base (both Phase-2-era placements, ~7 cm in x) was left as-is —
  out of Phase 3 scope.
- Balance display is a live canvas texture redrawn on world events (not in
  `frame()`), so behavtest sees it without the render loop.
