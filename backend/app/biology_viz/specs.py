"""Structured Biological Specification.

The visualization engine never sends free-form drawing instructions to the
renderer. Instead it produces a structured spec that a deterministic renderer
interprets. This module defines that spec contract (Pydantic) plus the curated
Cell Biology knowledge base used to construct it.
"""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field

# ── Supported categories (Phase 1 focuses on cell biology; others scaffolded) ──

CELL_APPS: dict[str, str] = {
    "plant_cell": "Plant Cell",
    "animal_cell": "Animal Cell",
    "bacterial_cell": "Bacterial Cell",
    "fungal_cell": "Fungal Cell",
}

_APP_ALIAS_MAP: dict[str, str] = {
    "plant": "plant_cell",
    "animal": "animal_cell",
    "bacterial": "bacterial_cell",
    "bacterium": "bacterial_cell",
    "bacteria": "bacterial_cell",
    "fungal": "fungal_cell",
    "fungus": "fungal_cell",
    "fungi": "fungal_cell",
}


def app_from_alias(value: str | None) -> str:
    """Resolve a loose alias to a canonical cell app key."""
    if value in CELL_APPS:
        return value
    if value:
        key = value.lower().replace("-", "_").replace(" ", "_")
        for k, v in _APP_ALIAS_MAP.items():
            if k in key:
                return v
        if "prokaryo" in key:
            return "bacterial_cell"
    return "plant_cell"


# Curated Cell Biology knowledge base: which organelles belong to which cell
# type. This is the authoritative set the renderer validates against.
_CELL_ORGANELLES: dict[str, dict[str, list[str]]] = {
    "plant_cell": {
        "present": [
            "cell wall",
            "cell membrane",
            "nucleus",
            "cytoplasm",
            "chloroplasts",
            "vacuole",
            "mitochondria",
            "ribosomes",
            "endoplasmic reticulum",
            "golgi apparatus",
        ],
        "absent": ["centrioles", "lysosomes"],
    },
    "animal_cell": {
        "present": [
            "cell membrane",
            "nucleus",
            "cytoplasm",
            "mitochondria",
            "ribosomes",
            "endoplasmic reticulum",
            "golgi apparatus",
            "lysosomes",
            "centrioles",
        ],
        "absent": ["cell wall", "chloroplasts", "large central vacuole"],
    },
    "bacterial_cell": {
        "present": [
            "cell wall",
            "cell membrane",
            "capsule",
            "nucleoid (dna)",
            "ribosomes",
            "flagellum",
            "pili",
            "plasmid",
            "cytoplasm",
        ],
        "absent": ["nucleus", "mitochondria", "chloroplasts", "endoplasmic reticulum"],
    },
    "fungal_cell": {
        "present": [
            "cell wall",
            "cell membrane",
            "nucleus",
            "cytoplasm",
            "vacuole",
            "mitochondria",
            "ribosomes",
            "endoplasmic reticulum",
            "golgi apparatus",
        ],
        "absent": ["chloroplasts"],
    },
}

_LABELS: dict[str, list[str]] = {
    "plant_cell": [
        "Cell wall",
        "Cell membrane",
        "Nucleus",
        "Cytoplasm",
        "Chloroplasts",
        "Large vacuole",
        "Mitochondria",
        "Ribosomes",
        "Endoplasmic reticulum",
        "Golgi apparatus",
    ],
    "animal_cell": [
        "Cell membrane",
        "Nucleus",
        "Cytoplasm",
        "Mitochondria",
        "Ribosomes",
        "Endoplasmic reticulum",
        "Golgi apparatus",
        "Lysosomes",
        "Centrioles",
    ],
    "bacterial_cell": [
        "Cell wall",
        "Cell membrane",
        "Capsule",
        "Nucleoid (DNA)",
        "Ribosomes",
        "Flagellum",
        "Pili",
        "Plasmid",
        "Cytoplasm",
    ],
    "fungal_cell": [
        "Cell wall",
        "Cell membrane",
        "Nucleus",
        "Cytoplasm",
        "Vacuole",
        "Mitochondria",
        "Ribosomes",
        "Endoplasmic reticulum",
        "Golgi apparatus",
    ],
}


class StructureSpec(BaseModel):
    id: str
    name: str
    kind: str = "component"  # membrane, organelle, wall, appendage, region, label
    present: bool = True


class LabelSpec(BaseModel):
    id: str
    text: str
    x: float = 0.0
    y: float = 0.0


class ProcessNode(BaseModel):
    """A single labelled object in a process/cycle diagram.

    `shape` selects from a small set of deterministic scientific primitives:
    box, circle, leaf (producer), sun (energy input), arrow_label, input, output.
    """

    id: str
    label: str
    shape: str = "box"
    detail: str = ""
    required: bool = True


class ProcessEdge(BaseModel):
    """A directed relationship between two process nodes."""

    from_: str = Field(alias="from")
    to: str
    label: str = ""

    model_config = {"populate_by_name": True}


class BiologySpec(BaseModel):
    """Structured spec that a deterministic renderer interprets.

    `kind` discriminates the diagram family:
      * "cell"    — biological structure (cell wall -> membrane -> cytoplasm ->
                    organelles), rendered by the CellDiagramRenderer.
      * "process" — a biological flow, cycle, branched process or life cycle,
                    rendered by the ProcessDiagramRenderer from `nodes`/`edges`.
    """

    category: str = "cell"
    app: str = "plant_cell"
    kind: str = "cell"
    layout: str = "cycle"  # process family: cycle | flow | branched | grid
    title: str = "Plant Cell"
    style: str = "educational"
    form: int = 1
    topic: str = ""
    subtopic: str = ""
    diagram_type: str = "labelled_diagram"
    background: str = "white"
    labels_shown: bool = True
    quality_level: str = "standard"
    structures: list[StructureSpec] = Field(default_factory=list)
    labels: list[str] = Field(default_factory=list)
    nodes: list[ProcessNode] = Field(default_factory=list)
    edges: list[ProcessEdge] = Field(default_factory=list)
    arrows: list[dict[str, Any]] = Field(default_factory=list)
    annotations: list[str] = Field(default_factory=list)
    dimensions: dict[str, Any] = Field(default_factory=dict)
    syllabus_reference: str | None = None


# Organelles that must never be marked present for a given app, regardless of any
# include/exclude override. This enforces morphological accuracy (e.g. a
# prokaryotic bacterial cell can never contain a membrane-bound nucleus or
# mitochondria).
_IMMUTABLE_ABSENT: dict[str, set[str]] = {
    "plant_cell": {"centrioles", "lysosomes"},
    "animal_cell": {"cell_wall", "chloroplasts", "large_central_vacuole", "vacuole"},
    "bacterial_cell": {
        "nucleus",
        "nucleoli",
        "mitochondria",
        "chloroplasts",
        "endoplasmic_reticulum",
        "golgi_apparatus",
        "vacuole",
        "lysosomes",
        "centrioles",
    },
    "fungal_cell": {"chloroplasts", "centrioles"},
}

# Slug aliases -> canonical ids, so users can write "central vacuole" or "vacuole".
_SLUG_ALIASES: dict[str, str] = {
    "central_vacuole": "vacuole",
    "large_central_vacuole": "vacuole",
    "cell_wall": "cell_wall",
    "plasma_membrane": "cell_membrane",
    "dna": "nucleoid_dna",
    "nucleoid": "nucleoid_dna",
}


def _canonical_id(entry: str) -> str:
    slug = "".join(c if c.isalnum() else "_" for c in entry.lower()).strip("_")
    return _SLUG_ALIASES.get(slug, slug)


def _norm_id(entry: str) -> str:
    """Plural-insensitive key: 'chloroplast' and 'chloroplasts' compare equal."""
    s = _canonical_id(entry)
    return s[:-1] if s.endswith("s") and len(s) > 4 else s


def build_cell_spec(
    app: str,
    *,
    title: str | None = None,
    form: int = 1,
    topic: str = "",
    subtopic: str = "",
    background: str = "white",
    labels_shown: bool = True,
    quality_level: str = "standard",
    syllabus_reference: str | None = None,
    exclude: set[str] | None = None,
) -> BiologySpec:
    """Deterministically build a Cell Biology spec from curated knowledge.

    `exclude` lets a caller drop specific organelles (e.g. "plant cell without a
    central vacuole"). Structures that are biologically impossible for the cell
    type are always kept absent via `_IMMUTABLE_ABSENT`, so the spec stays
    scientifically accurate even when the prompt asks for impossible content.
    """
    app = app if app in CELL_APPS else "plant_cell"
    organelles = _CELL_ORGANELLES[app]
    immutable_absent = {_norm_id(e) for e in _IMMUTABLE_ABSENT.get(app, set())}
    drop: set[str] = {
        _norm_id(e) for e in (exclude or set()) if _norm_id(e) not in immutable_absent
    }
    structures: list[StructureSpec] = []
    for name in organelles["present"]:
        sid = _slug(name)
        structures.append(
            StructureSpec(
                id=sid,
                name=name_clean(name),
                kind=_kind_of(name),
                present=_norm_id(sid) not in drop,
            )
        )
    for name in organelles["absent"]:
        structures.append(
            StructureSpec(
                id=_slug(name),
                name=name_clean(name),
                kind=_kind_of(name),
                present=False,
            )
        )
    labels = _LABELS[app]
    return BiologySpec(
        category="cell",
        app=app,
        title=title or CELL_APPS[app],
        form=form,
        topic=topic,
        subtopic=subtopic,
        background=background,
        labels_shown=labels_shown,
        quality_level=quality_level,
        structures=structures,
        labels=labels,
        dimensions={"view": "2d", "orientation": "landscape"},
        syllabus_reference=syllabus_reference,
    )


def name_clean(name: str) -> str:
    """Tidy organelle names for display ('cell wall' -> 'Cell Wall')."""
    common = {
        "cell wall": "Cell wall",
        "cell membrane": "Cell membrane",
        "large central vacuole": "Large central vacuole",
        "nucleoid (dna)": "Nucleoid (DNA)",
    }
    if name in common:
        return common[name]
    return name.strip().title()


def _kind_of(name: str) -> str:
    n = name.lower()
    if "wall" in n or "capsule" in n:
        return "wall"
    if "membrane" in n:
        return "membrane"
    if n in ("flagellum", "pili", "plasmid"):
        return "appendage"
    if n in ("cytoplasm", "nucleoid (dna)"):
        return "region"
    return "organelle"


def _slug(name: str) -> str:
    return "".join(c if c.isalnum() else "_" for c in name.lower()).strip("_")


# ─────────────────────────────────────────────────────────────────────────
# Process / cycle knowledge base
# ─────────────────────────────────────────────────────────────────────────
# Each entry is a deterministic node/edge network for a classic Malawi biology
# process diagram. The ProcessDiagramRenderer lays the nodes out automatically
# (cycle ring, left-to-right flow, or branched tree) and never delegates to an
# image model.

_PROCESS_DEFS: dict[str, dict[str, Any]] = {
    "photosynthesis": {
        "title": "Photosynthesis",
        "layout": "flow",
        "topic": "Nutrition in plants",
        "nodes": [
            {"id": "sun", "label": "Sunlight", "shape": "sun"},
            {"id": "water", "label": "Water (H\u2082O)", "shape": "input"},
            {"id": "co2", "label": "Carbon dioxide (CO\u2082)", "shape": "input"},
            {"id": "chloroplast", "label": "Chloroplast in leaf", "shape": "leaf"},
            {"id": "glucose", "label": "Glucose", "shape": "output"},
            {"id": "oxygen", "label": "Oxygen (O\u2082)", "shape": "output"},
        ],
        "edges": [
            {"from": "sun", "to": "chloroplast", "label": "light energy"},
            {"from": "water", "to": "chloroplast", "label": ""},
            {"from": "co2", "to": "chloroplast", "label": ""},
            {"from": "chloroplast", "to": "glucose", "label": ""},
            {"from": "chloroplast", "to": "oxygen", "label": ""},
        ],
    },
    "aerobic_respiration": {
        "title": "Aerobic Respiration",
        "layout": "flow",
        "topic": "Respiration",
        "nodes": [
            {"id": "glucose", "label": "Glucose", "shape": "input"},
            {"id": "oxygen", "label": "Oxygen (O\u2082)", "shape": "input"},
            {
                "id": "mitochondria",
                "label": "Mitochondria\n(energy release)",
                "shape": "box",
            },
            {"id": "co2", "label": "Carbon dioxide (CO\u2082)", "shape": "output"},
            {"id": "water", "label": "Water (H\u2082O)", "shape": "output"},
            {"id": "atp", "label": "Energy (ATP)", "shape": "output"},
        ],
        "edges": [
            {"from": "glucose", "to": "mitochondria"},
            {"from": "oxygen", "to": "mitochondria"},
            {"from": "mitochondria", "to": "co2"},
            {"from": "mitochondria", "to": "water"},
            {"from": "mitochondria", "to": "atp"},
        ],
    },
    "anaerobic_respiration": {
        "title": "Anaerobic Respiration (Fermentation)",
        "layout": "flow",
        "topic": "Respiration",
        "nodes": [
            {"id": "glucose", "label": "Glucose", "shape": "input"},
            {"id": "cell", "label": "No oxygen (O\u2082 deficient)", "shape": "box"},
            {
                "id": "ethanol",
                "label": "Ethanol + CO\u2082\n(yeast)",
                "shape": "output",
            },
            {"id": "lactate", "label": "Lactic acid\n(muscles)", "shape": "output"},
            {"id": "atp", "label": "Energy (ATP)", "shape": "output"},
        ],
        "edges": [
            {"from": "glucose", "to": "cell"},
            {"from": "cell", "to": "ethanol"},
            {"from": "cell", "to": "lactate"},
            {"from": "cell", "to": "atp"},
        ],
    },
    "carbon_cycle": {
        "title": "The Carbon Cycle",
        "layout": "cycle",
        "topic": "Ecology",
        "nodes": [
            {"id": "co2", "label": "Atmospheric\nCO\u2082", "shape": "circle"},
            {"id": "plants", "label": "Producers\n(photosynthesis)", "shape": "circle"},
            {"id": "animals", "label": "Consumers\n(feeding)", "shape": "circle"},
            {"id": "decomposers", "label": "Decomposers\n(decay)", "shape": "circle"},
            {"id": "fossils", "label": "Fossil fuels\n+ combustion", "shape": "circle"},
        ],
        "edges": [
            {"from": "co2", "to": "plants", "label": "photosynthesis"},
            {"from": "plants", "to": "animals", "label": "feeding"},
            {"from": "animals", "to": "decomposers", "label": "death & decay"},
            {"from": "decomposers", "to": "co2", "label": "respiration / decay"},
            {"from": "plants", "to": "fossils", "label": "millions of years"},
            {"from": "fossils", "to": "co2", "label": "combustion"},
            {"from": "animals", "to": "co2", "label": "respiration"},
        ],
    },
    "nitrogen_cycle": {
        "title": "The Nitrogen Cycle",
        "layout": "cycle",
        "topic": "Ecology",
        "nodes": [
            {"id": "n2", "label": "Atmospheric\nN\u2082", "shape": "circle"},
            {"id": "nitrates", "label": "Nitrates in soil", "shape": "circle"},
            {"id": "plants", "label": "Plants", "shape": "circle"},
            {"id": "animals", "label": "Animals", "shape": "circle"},
            {"id": "ammonia", "label": "Ammonia /\namino acids", "shape": "circle"},
        ],
        "edges": [
            {"from": "n2", "to": "nitrates", "label": "nitrogen fixation"},
            {"from": "nitrates", "to": "plants", "label": "uptake"},
            {"from": "plants", "to": "animals", "label": "feeding"},
            {"from": "animals", "to": "ammonia", "label": "excretion / decay"},
            {"from": "ammonia", "to": "nitrates", "label": "nitrification"},
            {"from": "plants", "to": "ammonia", "label": "decay"},
            {"from": "nitrates", "to": "n2", "label": "denitrification"},
        ],
    },
    "water_cycle": {
        "title": "The Water Cycle",
        "layout": "cycle",
        "topic": "Ecology",
        "nodes": [
            {"id": "ocean", "label": "Seas & lakes", "shape": "circle"},
            {"id": "evap", "label": "Evaporation", "shape": "circle"},
            {"id": "clouds", "label": "Clouds (water vapour)", "shape": "circle"},
            {
                "id": "precip",
                "label": "Precipitation\n(rain & snow)",
                "shape": "circle",
            },
            {"id": "ground", "label": "Ground water /\nrun-off", "shape": "circle"},
        ],
        "edges": [
            {"from": "ocean", "to": "evap", "label": "heat energy"},
            {"from": "evap", "to": "clouds", "label": "condensation"},
            {"from": "clouds", "to": "precip", "label": ""},
            {"from": "precip", "to": "ground", "label": ""},
            {"from": "ground", "to": "ocean", "label": "run-off / seepage"},
        ],
    },
    "mitosis": {
        "title": "Mitosis (Cell Division)",
        "layout": "flow",
        "topic": "Cell division",
        "nodes": [
            {
                "id": "interphase",
                "label": "Interphase\n(DNA replicates)",
                "shape": "box",
            },
            {
                "id": "prophase",
                "label": "Prophase\n(chromosomes condense)",
                "shape": "box",
            },
            {
                "id": "metaphase",
                "label": "Metaphase\n(chromosomes align)",
                "shape": "box",
            },
            {
                "id": "anaphase",
                "label": "Anaphase\n(sister chromatids split)",
                "shape": "box",
            },
            {"id": "telophase", "label": "Telophase\n(nuclei reform)", "shape": "box"},
            {
                "id": "daughter",
                "label": "Two daughter cells\n(each 2n)",
                "shape": "output",
            },
        ],
        "edges": [
            {"from": "interphase", "to": "prophase"},
            {"from": "prophase", "to": "metaphase"},
            {"from": "metaphase", "to": "anaphase"},
            {"from": "anaphase", "to": "telophase"},
            {"from": "telophase", "to": "daughter"},
        ],
    },
    "meiosis": {
        "title": "Meiosis (Gamete Formation)",
        "layout": "branched",
        "topic": "Cell division",
        "nodes": [
            {"id": "diploid", "label": "Diploid parent cell (2n)", "shape": "box"},
            {
                "id": "div1",
                "label": "Meiosis I\n(halves chromosome number)",
                "shape": "box",
            },
            {
                "id": "div2",
                "label": "Meiosis II\n(sister chromatids separate)",
                "shape": "box",
            },
            {"id": "gamete1", "label": "Gamete (n)", "shape": "output"},
            {"id": "gamete2", "label": "Gamete (n)", "shape": "output"},
            {"id": "gamete3", "label": "Gamete (n)", "shape": "output"},
            {"id": "gamete4", "label": "Gamete (n)", "shape": "output"},
        ],
        "edges": [
            {"from": "diploid", "to": "div1"},
            {"from": "div1", "to": "div2"},
            {"from": "div2", "to": "gamete1"},
            {"from": "div2", "to": "gamete2"},
            {"from": "div2", "to": "gamete3"},
            {"from": "div2", "to": "gamete4"},
        ],
    },
    "food_chain": {
        "title": "A Food Chain",
        "layout": "flow",
        "topic": "Ecology",
        "nodes": [
            {"id": "sun", "label": "Sun", "shape": "sun"},
            {"id": "grass", "label": "Grass\n(producer)", "shape": "leaf"},
            {"id": "insect", "label": "Insect\n(primary consumer)", "shape": "box"},
            {"id": "frog", "label": "Frog\n(secondary consumer)", "shape": "box"},
            {"id": "snake", "label": "Snake\n(tertiary consumer)", "shape": "box"},
            {"id": "eagle", "label": "Eagle\n(top predator)", "shape": "box"},
        ],
        "edges": [
            {"from": "sun", "to": "grass", "label": ""},
            {"from": "grass", "to": "insect", "label": "eaten by"},
            {"from": "insect", "to": "frog", "label": "eaten by"},
            {"from": "frog", "to": "snake", "label": "eaten by"},
            {"from": "snake", "to": "eagle", "label": "eaten by"},
        ],
    },
    "plant_life_cycle": {
        "title": "Life Cycle of a Flowering Plant",
        "layout": "cycle",
        "topic": "Reproduction in plants",
        "nodes": [
            {"id": "seed", "label": "Seed", "shape": "circle"},
            {"id": "germ", "label": "Germination", "shape": "circle"},
            {"id": "seedling", "label": "Seedling", "shape": "circle"},
            {"id": "plant", "label": "Mature plant", "shape": "circle"},
            {"id": "flower", "label": "Flowering", "shape": "circle"},
            {"id": "fruit", "label": "Fruit & seeds", "shape": "circle"},
        ],
        "edges": [
            {"from": "seed", "to": "germ", "label": ""},
            {"from": "germ", "to": "seedling", "label": ""},
            {"from": "seedling", "to": "plant", "label": ""},
            {"from": "plant", "to": "flower", "label": ""},
            {"from": "flower", "to": "fruit", "label": ""},
            {"from": "fruit", "to": "seed", "label": "dispersal"},
        ],
    },
}

_PROCESS_ALIASES: dict[str, set[str]] = {
    "photosynthesis": {"photosynth"},
    "aerobic_respiration": {"aerobic respiration", "respiration"},
    "anaerobic_respiration": {"anaerobic", "fermentation"},
    "carbon_cycle": {"carbon cycle", "carbon"},
    "nitrogen_cycle": {"nitrogen cycle", "nitrogen"},
    "water_cycle": {"water cycle", "hydrological"},
    "mitosis": {"mitosis"},
    "meiosis": {"meiosis"},
    "food_chain": {"food chain", "food web"},
    "plant_life_cycle": {"life cycle", "lifecycle"},
}


def process_from_prompt(prompt: str) -> str | None:
    """Return the process key inferred from a prompt, or None if not a process."""
    lowered = (" " + prompt.lower() + " ").replace("-", " ")
    best: tuple[int, str] | None = None
    for key, aliases in _PROCESS_ALIASES.items():
        for alias in aliases:
            if alias in lowered:
                score = len(alias)
                if best is None or score > best[0]:
                    best = (score, key)
    return best[1] if best else None


def build_process_spec(
    key: str,
    *,
    form: int = 1,
    background: str = "white",
    labels_shown: bool = True,
    quality_level: str = "standard",
    topic: str = "",
    subtopic: str = "",
    syllabus_reference: str | None = None,
) -> BiologySpec:
    """Deterministically build a process/cycle spec from curated knowledge."""
    data = _PROCESS_DEFS[key]
    nodes = [ProcessNode(**n) for n in data["nodes"]]
    edges = [
        ProcessEdge(from_=e["from"], to=e["to"], label=e.get("label", ""))
        for e in data["edges"]
    ]
    labels = [n["label"].split("\n")[0] for n in data["nodes"]]
    return BiologySpec(
        category="process",
        app=key,
        kind="process",
        layout=data["layout"],
        title=data["title"],
        form=form,
        topic=topic or data["topic"],
        subtopic=subtopic,
        background=background,
        labels_shown=labels_shown,
        quality_level=quality_level,
        nodes=nodes,
        edges=edges,
        labels=labels,
        dimensions={"view": "2d", "orientation": "landscape"},
        syllabus_reference=syllabus_reference,
    )
