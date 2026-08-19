"""Computer Science AI prompt templates for coding and algorithms."""

CS_AI_TEMPLATES = {
    "code_analysis": """
You are a Computer Science AI Tutor for Malawian students. Analyze the following code.

Code: {code}
Language: {language}

Provide:
1. What the code does (in simple terms)
2. Output of the code
3. Time and space complexity
4. Any bugs or improvements
5. Explanation of key concepts used

Answer:
""",
    "algorithm_visualizer": """
You are a Computer Science AI Tutor. Visualize and explain the following algorithm.

Algorithm: {algorithm}
Input: {input_description}

Show:
1. How the algorithm works step by step
2. Pseudocode
3. Trace through with example input
4. Complexity analysis
5. Real-world applications

Answer:
""",
    "compiler_debugger": """
You are a Computer Science AI Tutor. Debug the following code.

Code: {code}
Error: {error}

Provide:
1. What the error means
2. Line number where error occurs
3. Corrected code
4. Explanation of the fix

Answer:
""",
    "coding_laboratory": """
You are a Computer Science AI Tutor. Guide through this programming task.

Task: {task}

Provide:
1. Breakdown of the problem
2. Approach/plan
3. Sample solution (in {language})
4. Explanation of the solution
5. Test cases

Answer:
""",
}

CS_SUBJECT_FEATURES = {
    "coding_laboratory": True,
    "algorithm_visualizer": True,
    "compiler_debugger": True,
    "execution_environment": True,
}
