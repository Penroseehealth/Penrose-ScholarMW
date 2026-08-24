from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class SubjectModule:
    slug: str
    title: str
    description: str
    icon: str
    color: str
    discipline_count: int
    ai_model: str = "gpt-4o"
    features: list[str] = field(default_factory=list)
    metadata: dict[str, Any] = field(default_factory=dict)


SUBJECT_REGISTRY: dict[str, SubjectModule] = {
    "mathematics": SubjectModule(
        slug="mathematics",
        title="Mathematics",
        description="The foundational study of quantity, structure, space, and change.",
        icon="calculate",
        color="#8B5CF6",
        discipline_count=9,
        features=[
            "graphing",
            "equation_solver",
            "symbolic_reasoning",
            "step_verification",
            "mathematical_modelling",
        ],
        metadata={"default_ai_model": "gpt-4o"},
    ),
    "biology": SubjectModule(
        slug="biology",
        title="Biology",
        description="The scientific study of life and living organisms.",
        icon="biotech",
        color="#10B981",
        discipline_count=13,
        features=[
            "virtual_laboratory",
            "diagram_labeling",
            "terminology",
            "physiological_process",
        ],
    ),
    "chemistry": SubjectModule(
        slug="chemistry",
        title="Chemistry",
        description="The study of matter, its composition, structure, and transformations.",
        icon="science",
        color="#F59E0B",
        discipline_count=14,
        features=[
            "periodic_table",
            "reaction_simulator",
            "molecular_visualization",
            "stoichiometry_solver",
        ],
    ),
    "physics": SubjectModule(
        slug="physics",
        title="Physics",
        description="The study of matter, energy, and the fundamental forces of nature.",
        icon="bolt",
        color="#3B82F6",
        discipline_count=12,
        features=[
            "formula_reference",
            "problem_solver",
            "simulation_engine",
            "lab_simulator",
        ],
    ),
    "computer-science": SubjectModule(
        slug="computer-science",
        title="Computer Science",
        description="The study of computation, information, and automation.",
        icon="computer",
        color="#6366F1",
        discipline_count=10,
        features=[
            "coding_laboratory",
            "algorithm_visualizer",
            "compiler_debugger",
            "execution_environment",
        ],
    ),
    "agriculture": SubjectModule(
        slug="agriculture",
        title="Agriculture",
        description="The science and practice of cultivating crops and raising livestock.",
        icon="agriculture",
        color="#22C55E",
        discipline_count=7,
        features=[
            "crop_modelling",
            "soil_analysis",
            "irrigation_calculator",
            "agricultural_biotelemetry",
        ],
    ),
    "environmental-science": SubjectModule(
        slug="environmental-science",
        title="Environmental Science",
        description="The interdisciplinary study of the natural environment and human impacts.",
        icon="eco",
        color="#059669",
        discipline_count=4,
        features=[
            "ecosystem_modelling",
            "climate_analysis",
            "pollution_tracking",
            "conservation_planning",
        ],
    ),
    "statistics": SubjectModule(
        slug="statistics",
        title="Statistics",
        description="The science of collecting, analyzing, and interpreting data.",
        icon="bar_chart",
        color="#0EA5E9",
        discipline_count=5,
        features=[
            "descriptive_stats",
            "hypothesis_testing",
            "regression_analysis",
            "data_visualization",
        ],
    ),
    "earth-science": SubjectModule(
        slug="earth-science",
        title="Earth & Geosciences",
        description="The study of Earth's structure, processes, and history.",
        icon="public",
        color="#A855F7",
        discipline_count=4,
        features=[
            "geological_map",
            "plate_tectonics",
            "mineral_identification",
            "gis_integration",
        ],
    ),
    "engineering-technology": SubjectModule(
        slug="engineering-technology",
        title="Engineering & Technology",
        description="Applying scientific principles to design, build, and optimize structures, machines, and systems.",
        icon="precision_manufacturing",
        color="#6366F1",
        discipline_count=5,
        features=[
            "circuit_simulator",
            "structures_analyzer",
            "renewable_energy_calculator",
            "robotics_simulator",
        ],
    ),
}

DEFAULT_ENABLED_MODULES: list[str] = list(SUBJECT_REGISTRY.keys())


def get_enabled_subjects() -> list[SubjectModule]:
    return [SUBJECT_REGISTRY[slug] for slug in DEFAULT_ENABLED_MODULES if slug in SUBJECT_REGISTRY]


def get_subject_module(slug: str) -> SubjectModule | None:
    return SUBJECT_REGISTRY.get(slug)
