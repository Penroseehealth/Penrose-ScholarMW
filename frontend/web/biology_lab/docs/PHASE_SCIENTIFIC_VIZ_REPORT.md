# Scientific Visualisation Engine — Evidence Report (P6-002)

Implements the phases in `scientific_visualization_engine_enforcement_prompt.csv`
inside the **existing** lab at `frontend/web/biology_lab/`. No existing scene,
viewer, loader or provider was replaced or redesigned; the engine is added as new,
isolated, pure-JS modules plus one DOM/SVG viewer.

## Status legend

- **IMPLEMENTED** — code exists, is exercised by automated tests.
- **TESTED** — covered by an automated suite in `npm test` (unit and/or browser).
- **LIVE** — a real network endpoint was reached during this work (transport only,
  never treated as scientific ground truth).
- **MOCKED** — exercised only with an injected fake (network unavailable or to keep
  the test deterministic).
- **BLOCKED** — cannot be completed here; reason stated.

## Phase gates

| Suite | Checks | Result |
|---|---|---|
| themes_test | 20 | PASS |
| phase1_unit | 53 | PASS |
| phase2_unit | 54 | PASS |
| phase3_unit | 41 | PASS |
| phase4_unit | 87 | PASS |
| phase5_unit | 40 | PASS |
| phase6_unit | 62 | PASS |
| phase7_unit | 99 | PASS |
| phase8_unit | 64 | PASS |
| **phase10_unit** (P1 registry + licence) | **34** | **PASS** |
| **phase11_unit** (P1 provider adapters, mocked) | **35** | **PASS** |
| **phase12_unit** (P2 lesson planner) | **29** | **PASS** |
| **phase13_unit** (P4 Krebs science) | **48** | **PASS** |
| **phase14_unit** (P5 reliability) | **19** | **PASS** |
| smoke (`?krebstest=1` browser acceptance) | 18 | PASS (0 page errors) |

Commands (cwd `frontend/web/biology_lab/`):

```
npm test                    # themes + phase1..8 + phase10..14 + smoke
npm run test:assets         # P1-001/3 registry + licence
npm run test:providers      # P1-002 adapters (mocked fetch)
npm run test:planner        # P2-001/2 lesson spec
npm run test:krebs          # P4-001/2 Krebs science
npm run test:reliability    # P5-001 caching/retry/rate-limit
npm run test:providers-live # live reachability probe (non-asserting)
```

> Pre-existing bug fixed: `package.json` referenced `scripts/phase9_unit.mjs`,
> which never existed, so `npm test` was already broken. It now runs every real
> unit suite (phase1..8 + phase10..14) plus smoke — strictly more coverage.

## Phase-by-phase

### P0-002 Repository inspection — IMPLEMENTED
Confirmed the lab is the target: `package.json` (own test scripts), vendored
Three.js `vendor/three.core.js` with `REVISION='172'` (unchanged), existing
provider/cache pattern in `js/model_catalogue.js`, overlay-viewer pattern in
`js/kidney_viewer.js`. Three.js r172 verified untouched.

### P1-001 Asset registry — IMPLEMENTED/TESTED
`js/asset_registry.js` + `js/asset_seed.js`. Canonical schema (id, scientific
name, synonyms, category, topic, provider, source URL, source id, retrieval
timestamp, format, licence, licence id, attribution, redistribution, validation,
preview, renderer). Validation, search with keyword scoring + filters, facets,
and explicit `redistributable()` / `needsReview()` views. Seed includes 8 real,
source-linked records across all six providers, deliberately including one
restricted (CC-BY-NC) and one unverified record so those paths are real.

### P1-002 Provider adapters — IMPLEMENTED/TESTED (LIVE transport)
`js/providers.js`: Bioicons, Reactome, PubChem PUG REST, RCSB PDB, Servier
Medical Art, Cell Image Library. Each declares capabilities, a per-asset licence
note, a pure `buildRequest`, and a pure `map` to registry records; `fetch` adds a
timeout + normalised error envelope and **never fabricates** results.
- **LIVE**: Reactome, RCSB PDB, PubChem endpoints all reachable; a real
  end-to-end fetch returned live records (Reactome R-HSA-71403, PubChem CID 311,
  RCSB entries). This surfaced a real bug — Reactome wraps matched terms in
  `<span class="highlighting">` markup — now stripped (regression test added).
- Bioicons / Servier / Cell Image Library expose **no public JSON index**; their
  adapters return a documented `curated` state rather than a fake result.
  **MOCKED** for mapping only.

### P1-003 Licence / provenance gate — IMPLEMENTED/TESTED
`js/licence.js`: per-asset classification into open / attribution / restricted /
unverified; `redistributable` requires a known licence and (for attribution)
non-empty attribution; unverified is never represented as unrestricted. Every
registry record carries a provenance line. King's rule honoured: terms are
evaluated **per asset**, never per platform.

### P2-001 Query → lesson spec — IMPLEMENTED/TESTED
`js/lesson_planner.js`: classifies a request into match / ambiguous /
needs-clarification; unknown concepts return clarification candidates and
**never a fabricated lesson**; a missing curated model returns an error, not
invented science. Produces a validated `LessonSpec` with interactive flags.

### P2-002 Verified science vs generative styling — IMPLEMENTED/TESTED
The spec's `science` half is copied verbatim from the curated model and is only
marked `verified` when the model explicitly declares `curated: true` **and** names
a source (a hole where verifiedness was assumed was found by a test and fixed).
The `styling` half holds only presentational keys (theme/layout/animation/colour)
and a validation guard rejects any styling key that collides with a science field.

### P3-001 Rendering — IMPLEMENTED/TESTED
2D: the Krebs lesson renders as SVG (no WebGL dependency), with a documented
fallback story (curated model always available offline). 3D remains Three.js r172
(existing scenes untouched). Small molecules: PubChem adapter maps real compound
records (formula/weight/SMILES) from live data.
- **Mol\*: BLOCKED/uncertain.** Compatibility with this repo's r172 vendored build
  is unverified; no Mol\* bundle was imported. Records are tagged
  `renderer: 'molstar'` so a Mol\* host could consume them, but the engine does
  not yet mount a Mol\* viewer — documented limitation, not claimed as done.

### P3-002 Accessibility — IMPLEMENTED/TESTED
`js/krebs_viewer.js`: real `<button>`s with `aria-label`, keyboard-operable stage
nodes (`tabindex`, Enter/Space), `role="img"` SVG with `<title>`/`<desc>`,
`aria-live` progress, responsive SVG `viewBox`, `prefers-reduced-motion` respected.
Asserted in the browser test (every control labelled, diagram exposes title/desc).

### P4-001 Krebs cycle lesson — IMPLEMENTED/TESTED
`js/krebs.js` + `js/krebs_viewer.js`. Eight reactions in canonical order with
enzymes, direction, carbon counts, CO2/NADH/FADH2/GTP; acetyl-CoA entry modelled
as a **separate link reaction** (not a 9th cycle step); OAA regenerated at stage
8; succinyl-CoA → succinate substrate-level phosphorylation highlighted; per-turn
balance 3 NADH / 1 FADH2 / 1 GTP / 2 CO2. viewer: step highlight, narration,
pause/replay/step-through, quiz. Wired to `?krebs=1`, `?krebstest=1`, and a
`Krebs cycle` button; heavy rig skipped for these flags.

### P4-002 Krebs science verified — IMPLEMENTED/TESTED
`phase13_unit.mjs` checks the model against an **independent** reference table
(reaction order, enzymes, intermediates, products) written separately from the
data, plus carbon-flow continuity, cofactor balance, the energy step, the link
reaction, and honesty notes (organism scope, GTP/ATP and enzyme-synonym caveats).

### P5-001 Caching / retries / rate-limit / errors — IMPLEMENTED/TESTED
`js/registry_service.js`: TTL cache (localStorage with in-memory fallback,
mirroring `model_catalogue.js`), bounded retries with exponential backoff + jitter
**only for transient failures**, terminal 403 (no retry), rate-limit (429) →
`rate-limited` status with backoff, stale-cache fallback after exhausted retries,
distinct `empty` vs `error` states, and per-provider fan-out aggregation
(`ok` / `partial` / `error`) with dedupe.

### P6-001 Build + test + regression — IMPLEMENTED/TESTED
All unit suites pass (0 failures); the browser `krebstest` passes 18/18 with no
page errors; existing lab suites (themes, phase1..8) unchanged and green.
`index.html` passes `tools/validate_html_js.py` (braces/parens/brackets/scope/HR).

### P6-002 Evidence report — this file.

## Bugs found and fixed during this work

1. **Reactome markup leak** — live names arrived as `<span class="highlighting">…`;
   stripped in `map` (would have corrupted labels/narration). Regression test added.
2. **Assumed verifiedness** — the planner marked any model's science `verified`;
   now requires an explicit curated+source declaration. Test added.
3. **Word-boundary styling parse** — "slowly"/"quietly" failed `\bslow\b`; fixed.
4. **Provider licence-note guard** — two providers' notes lacked an explicit
   licence keyword; notes corrected so the no-blanket-licence assertion holds.
5. **Broken pre-existing `npm test`** — referenced non-existent
   `phase9_unit.mjs`; corrected to run all real suites.
6. **Test-only**: case-sensitive enzyme comparison in phase13; corrected.

## Blocked / honest limitations

- **Mol\* viewer** — not mounted (compatibility with the vendored r172 build
  unverified). Records tagged for a Mol\* host; no Mol\* rendering claimed.
- **Bioicons / Servier / Cell Image Library** — no public JSON index, so live
  search is unavailable; only curated mapping is implemented (clearly marked).
- **Live network** — reachability was confirmed once; CI/offline runs use mocked
  fetch in phase11_unit, so the suite is deterministic without network.
- **3D small-molecule rendering** — realcoordinates are mapped from PubChem, but
  the engine renders molecules as data/SVG, not as a WebGL molecule viewer.

## Files added

| File | Purpose |
|---|---|
| `js/licence.js` | P1-003 licence/provenance gate |
| `js/asset_registry.js` | P1-001 registry + search + validation |
| `js/asset_seed.js` | P1-001 curated seed records |
| `js/providers.js` | P1-002 six provider adapters |
| `js/lesson_planner.js` | P2-001/002 query → lesson spec |
| `js/krebs.js` | P4-001 curated Krebs model + verifier |
| `js/krebs_viewer.js` | P3/P4 SVG lesson viewer |
| `js/registry_service.js` | P5-001 reliability layer |
| `scripts/phase10_unit.mjs` … `phase14_unit.mjs` | unit suites |
| `scripts/providers_live_probe.mjs` | non-asserting live probe |

## Files changed

| File | Change |
|---|---|
| `index.html` | imports; `?krebs`/`?krebstest` flags; `startKrebsViewer`/`runKrebsTest`; `Krebs cycle` button |
| `package.json` | test suite corrected + extended |
| `scripts/smoke.mjs` | `?krebstest=1` pass (report parsed like kidneytest) |
