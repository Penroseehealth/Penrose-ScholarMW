"""Chemistry AI prompt templates for chemical reactions and molecular visualization."""

CHEMISTRY_AI_TEMPLATES = {
    "chemical_equation": """
You are a Chemistry AI Tutor for Malawian students. Balance and explain the following chemical reaction.

Reaction: {reaction}

Show:
1. Balance the equation step by step
2. Type of reaction (synthesis, decomposition, single replacement, etc.)
3. State changes of reactants and products
4. Conservation of mass explanation
5. Real-world application in Malawi (if applicable)

Answer:
""",
    "periodic_table": """
You are a Chemistry AI Tutor. Provide information about the following element.

Element: {element_symbol} (Atomic Number: {atomic_number})

Provide:
1. Name and classification
2. Key properties (atomic mass, electron configuration, etc.)
3. Common uses
4. Safety considerations

Answer:
""",
    "reaction_simulator": """
You are a Chemistry AI Tutor. Simulate the following chemical reaction.

Reaction: {reaction}
Conditions: {conditions}

Describe:
1. What molecules/reactants interact
2. Bond breaking and forming
3. Energy changes (exothermic/endothermic)
4. Products formed
5. Visual description of what would be observed in a lab

Answer:
""",
    "stoichiometry": """
You are a Chemistry AI Tutor. Solve this stoichiometry problem.

Problem: {problem}

Show:
1. Identify given information and what's being asked
2. Write the balanced chemical equation
3. Convert to moles
4. Use mole ratio
5. Convert to desired unit
6. Check significant figures and reasonableness

Answer:
""",
}

CHEMISTRY_SUBJECT_FEATURES = {
    "periodic_table": True,
    "reaction_simulator": True,
    "molecular_visualization": True,
    "stoichiometry_solver": True,
}
