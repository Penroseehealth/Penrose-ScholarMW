# Laboratory Themes — Implementation Report

20 selectable laboratory themes, integrated into the Settings panel of the
Bio-Lab scene (`index.html`). Themes tint the **existing shared materials**
in place — no material duplication, no scene rebuild, no extra draw calls.

## Files

| File | Role |
|---|---|
| `themes.js` | Central theme catalogue (20 coordinated palettes, 18 slots each) |
| `index.html` | Theme engine, Settings UI, persistence, `?diag` hooks |
| `scripts/themes_test.mjs` | Automated validation (`npm run test:themes`) |

## Themed slots (17)

`floor` (tints the tile texture), `wall`, `dado`, `rail`, `ceil`, `slab`
(floor slab/skirting), `top` (bench worktops), `carcass` (bench bodies),
`door` (room doors + cupboard doors + **drawer fronts**), `cab` (cabinets),
`plinth`, `dark` (board backing & dark details), `frame` (window/door
frames), `shelf`, `board` (whiteboard surface tint — stays
near-white for readability), `baseClad` (wall base cladding), `fill`
(soft cupboard fill panels; `null` = original mixed colours).

## Deliberately NOT themed (scientific realism)

- **Stools**: shiny stainless steel (chrome seat + steel pole/base/ring) —
  never recoloured.
- **Specimens & models**: heart, flowers, teacher/student avatars, slides.
- **Optics & instruments**: microscope bodies/stages/objectives.
- **Glassware & liquids**: glass, window glass, water streams, chemical
  solutions (`glass`, `winGlass`, `liquid`, stream/drop materials).
- **Safety equipment**: fire extinguisher & emergency fittings
  (`red`, `extRed`), hazard labels, tap markings, measurement scales.
- **Metal fittings**: `steel`/`chrome` (sinks, taps, board lining, rails,
  handles) keep authentic metal response; `metalRack`, fan blades.
- **Lighting**: emissive panels and lamp materials.

Changing a theme can never make steel look like painted plastic — those
materials are never touched.

## Settings UI

- **Laboratory themes** — scrollable list of all 20 themes, each row shows
  the theme name plus a 5-chip colour preview (floor / wall / worktop /
  cabinet / door). Active theme is highlighted.
- **Reset to original** — restores the classic laboratory exactly
  (including the original mixed cupboard fills).
- **Custom colours** — independent colour pickers for Walls, Floor, Bench
  tops, Cabinets & drawers and Board tint; overrides apply on top of the
  active theme.
- Persistence: `localStorage` keys `biolab.theme.v1` + `biolab.custom.v1`
  survive reload/restart. Switching theme clears custom overrides.

## Diagnostics hooks (for tests/capture)

- `window.__bioApplyTheme(i)` — apply theme by index (-1 = original).
- `window.__bioThemeState()` — current index/name, custom overrides, and
  resolved slot colours.
- `?theme=N` URL parameter — boots the lab with theme N applied
  (handy for headless capture; `?diag=1&theme=6` etc.).
- The `?diag=1` report now includes `theme` (state) and `themeProbe`
  (live hex of every themed material) for runtime verification.

## Verification

- `node scripts/themes_test.mjs` — 20 themes, structure, safety keys,
  distinctness vs Classic baseline. **PASS**
- Inline module + exit-button scripts: `node --check` clean.
- Theme switching mutates `Material.color` only; roughness/metalness/
  maps/lighting response preserved.

## Capture note

Screenshot comparison of all 20 themes can be driven through the existing
headless capture path (`?diag=1` + `window.__doShotCapture`) by looping
`__bioApplyTheme(0..19)` between captures.
