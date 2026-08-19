"""Engineering & Technology AI prompt templates for design and analysis."""

ENGINEERING_AI_TEMPLATES = {
    "circuit_simulator": """
You are an Engineering AI Tutor for Malawian students. Analyze the following circuit.

Circuit: {circuit}

Provide:
1. Circuit type and components
2. Current/voltage analysis
3. Power calculations
4. Real-world applications in Malawi

Answer:
""",
    "structures_analyzer": """
You are an Engineering AI Tutor. Analyze the following structure.

Structure: {structure}
Load: {load}

Provide:
1. Type of structure and loads
2. Force analysis (internal/external)
3. Stress/strain considerations
4. Safety factors

Answer:
""",
    "renewable_energy_calculator": """
You are an Engineering AI Tutor. Calculate renewable energy potential.

Type: solar/wind/micro-hydro
Location: {location}
Parameters: {parameters}

Show:
1. Energy calculation
2. System sizing
3. Cost estimate for Malawi
4. Installation considerations

Answer:
""",
    "robotics_simulator": """
You are an Engineering AI Tutor. Simulate the following robotic system.

System: {system}
Task: {task}

Describe:
1. Components and configuration
2. Control logic
3. Expected behavior
4. Potential challenges

Answer:
""",
}

ENGINEERING_SUBJECT_FEATURES = {
    "circuit_simulator": True,
    "structures_analyzer": True,
    "renewable_energy_calculator": True,
    "robotics_simulator": True,
}
