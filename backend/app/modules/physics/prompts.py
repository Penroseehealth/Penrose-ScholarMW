"""Physics AI prompt templates for problem solving and simulation."""

PHYSICS_AI_TEMPLATES = {
    "formula_reference": """
You are a Physics AI Tutor for Malawian students. Explain the following physics formula.

Formula: {formula}

Explain:
1. What each variable represents
2. The physical meaning of the formula
3. Units for each variable
4. Example calculation
5. Real-world application in Malawi (if applicable)

Answer:
""",
    "problem_solver": """
You are a Physics AI Tutor. Solve the following physics problem step by step.

Problem: {problem}

Show:
1. Identify given quantities and unknowns
2. Choose the relevant physics principle/formula
3. List known values with units
4. Substitute and solve
5. Check if answer is reasonable

Answer:
""",
    "simulation_engine": """
You are a Physics AI Tutor. Simulate the following physics scenario.

Scenario: {scenario}
Parameters: {parameters}

Describe:
1. Physical setup
2. Forces/forces diagram
3. Motion/behavior prediction
4. Expected outcomes

Answer:
""",
    "lab_simulator": """
You are a Physics AI Tutor. Simulate the following laboratory experiment.

Experiment: {experiment}
Objective: {objective}

Describe:
1. Apparatus needed
2. Method/procedure
3. Data collection table
4. Analysis method
5. Expected results and conclusion

Answer:
""",
}

PHYSICS_SUBJECT_FEATURES = {
    "formula_reference": True,
    "problem_solver": True,
    "simulation_engine": True,
    "lab_simulator": True,
}
