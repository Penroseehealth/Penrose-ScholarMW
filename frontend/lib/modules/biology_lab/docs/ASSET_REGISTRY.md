# Biology Lab — Asset Registry & Provenance

Every registered asset lives in code at
`lib/modules/biology_lab/hierarchy/bio_lab_registry.dart` and carries its
source, license and verification status. This document is the human-readable
register; the code is the machine-readable source of truth and is validated
by unit tests (`BioLabRegistry.validate()`).

## Verification categories

| Status | Meaning |
|---|---|
| **Validated structure** | Real experimental coordinates from a public repository, rendered unmodified through Mol*. |
| **Educational reconstruction** | Procedural model built in code from textbook morphology. Scientifically grounded topology, schematic geometry. |
| **Catalogued only** | Lesson metadata exists; no 3D model yet. Never shown as if it does. |

## Registry

| Asset | Level | Status | Source | License |
|---|---|---|---|---|
| `human-organism` | Organism | Educational reconstruction | Procedural, from standard anatomy (Gray's Anatomy 1918 ed., public domain) | Code-authored (MIT) |
| `circulatory-system` | System | Educational reconstruction | Procedural | Code-authored (MIT) |
| `human-heart` | Organ | Educational reconstruction | Procedural, from standard cardiac anatomy | Code-authored (MIT) |
| `cardiac-muscle-tissue` | Tissue | Catalogued only | Standard histology (descriptive) | Code-authored (MIT) |
| `cardiac-muscle-cell` | Cell | Educational reconstruction | Procedural | Code-authored (MIT) |
| `bacterial-cell` | Cell | Educational reconstruction | Procedural, from standard bacteriology | Code-authored (MIT) |
| `mitochondrion` | Organelle | Educational reconstruction | Procedural | Code-authored (MIT) |
| `dna-1bna` | Molecule | **Validated structure** | RCSB PDB 1BNA — Drew et al. (1981) PNAS 78:2179, doi:10.1073/pnas.78.4.2179 | wwPDB free-use policy |
| `hemoglobin-1hho` | Molecule | **Validated structure** | RCSB PDB 1HHO — Fermi & Perutz (1984) JMB 175:159, doi:10.1016/0022-2836(84)90472-8 | wwPDB free-use policy |

Structure data files are vendored locally in `frontend/web/biology_lab/data/`
so the molecular viewer works offline. Mol* (MIT) is vendored at
`frontend/web/biology_lab/molstar/`; three.js (MIT) at
`frontend/web/biology_lab/three.module.min.js`.

## Known gaps (documented, not hidden)

- Only the **bacterial cell**, **human heart**, **cardiac muscle cell**,
  **mitochondrion** and **human organism** have interactive 3D scenes.
  Other registered assets are metadata-only and the UI says so.
- All procedural scenes are schematic; no Blender-authored GLB assets have
  been imported yet. The optional Blender workflow is documented in
  `OPTIONAL_PIPELINES.md` and the bridge already supports `showMolecule` /
  scene specs that a GLB loader can slot into.
- ATP is described in lesson text but has no 3D structure scene yet
  (a validated candidate is any adenylate-kinase–ATP PDB entry; not vendored
  yet).
- Practical progress is session-local; integration with the existing
  `/examinations` + `backend/app/assessments` domain is a documented future
  step — no endpoint was invented.
