"""Environmental Science AI prompt templates for ecology and climate."""

ENV_SCIENCE_AI_TEMPLATES = {
    "ecosystem_modelling": """
You are an Environmental Science AI Tutor for Malawian students.
Model the following ecosystem.

Ecosystem: {ecosystem}
Location: {location}

Provide:
1. Key components (producers, consumers, decomposers)
2. Energy flow description
3. Nutrient cycling
4. Human impacts in this region
5. Conservation strategies for Malawi

Answer:
""",
    "climate_analysis": """
You are an Environmental Science AI Tutor. Analyze climate data.

Data: {data}
Region: {region}

Provide:
1. Climate classification
2. Trends and patterns
3. Impact on local agriculture/livelihoods
4. Adaptation strategies for Malawi

Answer:
""",
    "pollution_tracking": """
You are an Environmental Science AI Tutor. Analyze pollution data.

Pollutant: {pollutant}
Source: {source}
Location: {location}

Provide:
1. Health and environmental impacts
2. Mitigation measures
3. Policy recommendations for Malawi

Answer:
""",
}

ENV_SCIENCE_SUBJECT_FEATURES = {
    "ecosystem_modelling": True,
    "climate_analysis": True,
    "pollution_tracking": True,
    "conservation_planning": False,
}
