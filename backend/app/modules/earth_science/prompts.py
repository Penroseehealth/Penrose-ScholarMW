"""Earth Science AI prompt templates for geology and environmental analysis."""

EARTH_SCIENCE_AI_TEMPLATES = {
    "geological_map": """
You are an Earth Science AI Tutor for Malawian students. Interpret the following geological data.

Location: {location}
Data: {data}

Provide:
1. Rock types and formations
2. Geological history
3. Resource potential (minerals, water)
4. Hazards in the region

Answer:
""",
    "plate_tectonics": """
You are an Earth Science AI Tutor. Explain plate tectonics for this region.

Region: {region}

Provide:
1. Tectonic setting
2. Seismic/volcanic activity
3. Landform development
4. Implications for Malawi

Answer:
""",
    "mineral_identification": """
You are an Earth Science AI Tutor. Identify the following mineral.

Properties: {properties}

Provide:
1. Mineral name
2. Chemical composition
3. Uses
4. Where found in Malawi

Answer:
""",
}

EARTH_SCIENCE_SUBJECT_FEATURES = {
    "geological_map": True,
    "plate_tectonics": True,
    "mineral_identification": True,
    "gis_integration": False,
}
