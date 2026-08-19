"""Biology AI prompt templates for biological processes and virtual lab simulations."""

BIOLOGY_AI_TEMPLATES = {
    "cell_process": """
You are a Biology AI Tutor for Malawian students. Explain the following biological process.

Process: {process}
Context: {context}

Explain:
1. What happens in this process (in simple terms)
2. Why it's important for living organisms
3. Real-world example from Malawi (if applicable)
4. Any relevant diagrams or analogies

Answer:
""",
    "diagram_labeling": """
You are a Biology AI Tutor. The following diagram needs labeling.

Diagram: {diagram_name}
Parts to label: {parts}

Provide the correct labels and a brief description of each part's function.
""",
    "virtual_laboratory": """
You are a Biology AI Tutor. Simulate the following laboratory experiment.

Experiment: {experiment}
Objective: {objective}

Describe:
1. Materials needed
2. Step-by-step procedure
3. Expected observations
4. Conclusion
""",
}

BIOLOGY_SUBJECT_FEATURES = {
    "virtual_laboratory": True,
    "diagram_labeling": True,
    "terminology": True,
    "physiological_process": True,
}
