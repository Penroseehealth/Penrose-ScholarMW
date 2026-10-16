# Chemistry Laboratory. Photo Match

The `/chem-lab` route opens an orbitable Three.js approximation of the whole
visible laboratory: room shell, windows, blue bench and cabinets, fume hood,
sink, shelving, glassware, microscope, burner and stool. Drag to orbit, scroll
to zoom, and right-drag to pan. The reset-camera button restores the initial
view. The construction is real 3D geometry; it is not the reference photo
mapped onto a plane.

The sharp source photograph remains bundled at
`assets/chemistry_lab/reference/chemi_lab.jpeg` and is available from the photo
button in the app bar. On platforms without browser WebGL, the screen displays
the reference photo instead. The room's unseen sides are plausible
approximations because a single photograph cannot specify hidden geometry.

## Scene and runtime

| Concern | File |
|---|---|
| Flutter screen and reference toggle | `lib/modules/chemistry_lab/screens/chemistry_lab_screen.dart` |
| Platform view and lifecycle bridge | `lib/modules/chemistry_lab/viewport/` and `lib/modules/chemistry_lab/bridge/chemistry_lab_scene_bridge*` |
| Runtime 3D geometry, renderer and orbit controls | `web/chemistry_lab/chemistry-scene.js` |
| Shared Three.js runtime | `web/vendor/three.module.min.js` |
| Original sharp reference | `assets/chemistry_lab/reference/chemi_lab.jpeg` |
| Blender source generator | `assets/chemistry_lab/blender/build_labspace.py` |
| Focused Flutter widget test | `test/chemistry_lab/chemistry_lab_screen_test.dart` |

The browser runtime builds the room from named Three.js meshes and initializes
only after Flutter has attached the viewport element. It releases the WebGL
renderer, event handlers, geometries and materials when leaving the route.

## Generate an editable Blender scene

Blender can independently generate an editable approximation and a GLB export
for inspection or reuse. These exports do not replace the browser's runtime
scene:

```powershell
blender --background --python frontend/assets/chemistry_lab/blender/build_labspace.py
```

The default output directory is
`frontend/assets/chemistry_lab/generated/`. Add `-- --render-preview` to render
a quick half-resolution PNG from the configured reference viewpoint, or use
`-- --output-dir <path>` to choose another output folder.

Run the focused widget test with:

```powershell
cd frontend
flutter test test/chemistry_lab/chemistry_lab_screen_test.dart
```
