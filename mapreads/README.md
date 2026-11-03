# Map Reading module (Penrose ScholarMW)

Standalone HTML/JS module: contour-map engine, 2D map, Three.js 3D terrain, calculations, MSCE-style practice questions, teaching tools.
Everything is plain JS (no build step). Put the whole folder in one place; `index.html` loads its sibling `.js` files.

## Files
| File | Purpose |
|---|---|
| `engine.js` | Seeded terrain (hills, ridge, escarpment, U-valley), marching-squares contours, drainage, calculations (scale, gradient, bearing, grid ref, cross-section, intervisibility). No DOM. |
| `features.js` | Chained contours, smoothed land cover, settlements and names, roads, bridges, benchmarks, boundary. |
| `questions.js` | Question/paper generator with worked answers and Markdown export. |
| `annotate.js` | Annotation store (undo/redo/clear/save) and renderer. |
| `demo.js` | Nine step-by-step demonstrations (hill, valley, ridge, gradient, bearing, distance, grid ref, cross-section, intervisibility). |
| `index.html` | The smartboard page (2D map + 3D terrain + panels). |
| `test.js` | 58 automated tests of the maths and generators (Node). |
| `smoke.js` | Headless run of the page script with a stubbed DOM (Node). |

## Commands (PowerShell, from this folder)
    node test.js            # or: npm test
    node smoke.js           # or: npm run smoke
    python -m http.server 8000     # then open http://localhost:8000
    # Dart alternative: dart pub global activate dhttpd ; dhttpd --path .

Node 16+ is enough. Open the page through a local server (not by double-clicking the file) so the scripts load.

## Notes for Flutter integration
- `index.html` loads Three.js r128 from cdnjs, so it needs internet. For offline use, save that file as `three.min.js` next to `index.html` and change the one `<script src>` line.
- Theme: open with `?theme=dark` or call `setTheme('dark')`.
- JS API on `window.MapReading`: `generate(cfg)`, `getGrid()`, `setTheme(t)`, `pick(x, y)`, `paper()`, `annotations()`, `loadAnnotations(json)`.
- Not built yet: save/open library, PDF export, DEM import, backend endpoints.
