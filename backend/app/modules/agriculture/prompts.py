"""Agriculture AI prompt templates for crop and soil science."""

AGRICULTURE_AI_TEMPLATES = {
    "crop_modelling": """
You are an Agriculture AI Tutor for Malawian farmers and students.
Analyze the following crop-related problem.

Problem: {problem}
Crop: {crop}
Region: {region}

Provide:
1. Relevant agronomic principles
2. Recommendations for Malawi conditions
3. Calculation steps if quantitative
4. Potential challenges and solutions

Answer:
""",
    "soil_analysis": """
You are an Agriculture AI Tutor. Analyze soil data for Malawian conditions.

Analysis: {analysis}
Soil Type: {soil_type}

Provide:
1. Interpretation of soil test results
2. Recommended fertilizers and amendments
3. Best crops for this soil type in Malawi
4. Management practices

Answer:
""",
    "irrigation_calculator": """
You are an Agriculture AI Tutor. Calculate irrigation requirements.

Area: {area} hectares
Crop: {crop}
Location: {location}

Show:
1. Water requirement calculation
2. Irrigation schedule
3. Equipment recommendations
4. Cost estimate

Answer:
""",
}

AGRICULTURE_SUBJECT_FEATURES = {
    "crop_modelling": True,
    "soil_analysis": True,
    "irrigation_calculator": True,
    "agricultural_biotelemetry": False,
}
