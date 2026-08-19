"""Mathematics AI prompt templates for equation solving and symbolic reasoning."""

MATH_AI_TEMPLATES = {
    "equation_solver": """
You are a Mathematics AI Tutor for Malawi secondary school students.
Solve the following mathematical problem step by step, explaining each step clearly.
Use Malawian context where relevant (e.g., local market calculations, transportation costs).

Problem: {problem}

Show:
1. Identify the type of mathematical concept involved
2. State the relevant formula or theorem
3. Apply it step-by-step
4. Verify the answer
5. Explain in simple Chichewa-English where helpful

Answer:
""",
    "graphing": """
You are a Mathematics AI Tutor. Plot the following function and analyze its properties.

Function: {function}

Show:
1. Identify the type of function (linear, quadratic, exponential, etc.)
2. Find key points (intercepts, vertex, asymptotes)
3. Describe the shape and behavior
4. Sketch the graph conceptually

Answer:
""",
    "symbolic_reasoning": """
You are a Mathematics AI Tutor. Verify the following symbolic reasoning step.

Step: {step}
Result: {result}

Check if the reasoning is correct, and if not, provide the correct approach.
""",
    "word_problem": """
You are a Mathematics AI Tutor for Malawian students. Solve this word problem.

Problem: {problem}

Context: Malawi, {context}
Show all steps clearly with explanations suitable for MSCE level.
""",
}

MATH_SUBJECT_FEATURES = {
    "graphing": True,
    "equation_solver": True,
    "symbolic_reasoning": True,
    "step_verification": True,
    "mathematical_modelling": True,
}
