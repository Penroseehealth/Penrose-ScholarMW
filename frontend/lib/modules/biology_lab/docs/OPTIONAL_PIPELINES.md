# Optional Scientific Pipelines (Blender / VTK)

These are **authoring/processing** pipelines, not runtime dependencies. The
Biology Lab works fully without them.

## Blender → GLB workflow (optional)

For richer models than the procedural scenes, author in Blender and export
as glTF-Binary (.glb):

1. Model in Blender ( metres, −Z forward / +Y up as glTF expects).
2. Export glTF 2.0: `File → Export → glTF 2.0 (.glb)`, enable
   *Draco compression* if size matters (the loader must then include the
   Draco decoder).
3. Drop the file in `frontend/web/biology_lab/models/<asset-id>.glb`.
4. Register it in `bio_lab_registry.dart` by extending the asset with a
   `modelUrl` field and wiring `bridge` command `loadModel {url, objectId}`
   — the JS engine slot is already prepared next to the geometry builders
   in `bio-scene.js`.
5. Update this register + `ASSET_REGISTRY.md` with source and license.
6. Add `BioLabRegistry.validate()` coverage for the new field.

**No Blender-authored GLB has been imported yet.** The bridge intentionally
errors (`model-loader-unavailable`) rather than silently failing.

## Python + VTK workflow (optional)

For real microscopy/medical volumes:

1. `pip install vtk` in the backend venv (`backend/.venv`).
2. Place processing under `backend/app/biology_viz/` — the FastAPI router
   (`/api/v1/...`) is already registered in `backend/app/main.py`.
3. Recommended job shape: upload/point to a segmented volume → surface
   reconstruction (`vtkMarchingCubes` / `vtkDiscreteMarchingCubes`) →
   decimate → export `.glb` → vendored into `frontend/web/biology_lab/models/`.
4. The frontend then treats the result like any Blender GLB above.

**No VTK endpoint is implemented in this release** — there are no
volume datasets in the repo to justify one, and per the honesty rule none
was invented. The `backend/app/biology_viz/` module (existing) is the
natural home when such data arrives.

## Adding new data to the molecular level

1. Pick an entry from RCSB PDB (https://www.rcsb.org) and check its license
   (wwPDB data are free for use in the public interest).
2. Download the `.pdb` into `frontend/web/biology_lab/data/`.
3. Register a new `BioLabAsset` with
   `verification: BioVerification.validatedStructure`, the DOI-bearing
   citation, `moleculePdb: 'biology_lab/data/<id>.pdb'`.
4. The existing Mol* page (`molstar/molecule-viewer.html`) loads it offline
   with no further changes.
