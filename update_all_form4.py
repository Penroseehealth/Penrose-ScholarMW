"""Replace all 8 Form 4 topics with detailed syllabus content."""
import re

with open("backend/app/mathematics/seed_math_syllabus.py", "r", encoding="utf-8") as f:
    content = f.read()

count = 0

# ── 1. Travel Graphs (Form 4) ──────────────────────────────────────────
old = '''                {
                    "title": "Travel Graphs",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Interpreting Travel Graphs",
                            "description": "Reading and interpreting distance-time and speed-time (travel) graphs.",
                            "learning_objectives": [
                                {
                                    "objective": "Interpret speed-time graphs to determine acceleration, deceleration and distance travelled",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Graphical activities",
                                },
                                {
                                    "objective": "Calculate distance from the area under a speed-time graph",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Graph paper", "type": "equipment"},
                    ],
                },'''
new = '''                {
                    "title": "Travel Graphs",
                    "year_level": 4,
                    "description": "Outcome: Solve problems involving motion.",
                    "subtopics": [
                        {
                            "title": "Velocity-Time Graphs",
                            "description": "Defining speed, velocity and acceleration, describing the relationship between velocity, speed, time and acceleration, drawing velocity-time graphs.",
                            "learning_objectives": [
                                {
                                    "objective": "Define speed, velocity and acceleration",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Demonstration, problem solving, question and answer",
                                },
                                {
                                    "objective": "Describe the relationship between velocity, speed, time and acceleration",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, explanation, demonstration",
                                },
                                {
                                    "objective": "Draw velocity-time graphs from given information",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work, group work",
                                },
                            ],
                        },
                        {
                            "title": "Interpreting Velocity-Time Graphs",
                            "description": "Interpreting velocity-time graphs, calculating acceleration/deceleration, calculating distance using average velocity, calculating the area under a velocity-time graph.",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the motion depicted by velocity-time graphs",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, explanation, demonstration",
                                },
                                {
                                    "objective": "Calculate acceleration and deceleration from velocity-time graphs",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work, group work",
                                },
                                {
                                    "objective": "Calculate distance by using average velocity and time",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving, written exercises, projects",
                                },
                                {
                                    "objective": "Calculate the area under a velocity-time graph",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work, group work",
                                },
                                {
                                    "objective": "Establish the relationship between distance covered and the area under the velocity-time graph",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, demonstration, explanation",
                                },
                                {
                                    "objective": "Solve problems involving velocity-time graphs",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving, written exercises, projects",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Charts", "type": "equipment"},
                        {"text": "Graph paper", "type": "equipment"},
                        {"text": "Mathematical instruments", "type": "equipment"},
                        {"text": "Rulers", "type": "equipment"},
                        {"text": "Graph boards", "type": "equipment"},
                        {"text": "Graphic calculators", "type": "equipment"},
                        {"text": "Computers", "type": "equipment"},
                    ],
                },'''
if old in content:
    content = content.replace(old, new, 1)
    count += 1
    print("1. Travel Graphs updated")
else:
    print("1. ERROR: Travel Graphs not found")

# ── 2. Trigonometry (Form 4) — the one with "Trigonometric Ratios of Any Angle" ──
old = '''                {
                    "title": "Trigonometry",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Trigonometric Ratios of Any Angle",
                            "description": "Extending sine, cosine and tangent to angles beyond 0\u00b0\u201390\u00b0 using the unit circle.",
                            "learning_objectives": [
                                {
                                    "objective": "Define trigonometric ratios for angles of any magnitude using the unit circle",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, graphical activities",
                                },
                                {
                                    "objective": "Determine the sign of trigonometric ratios in each quadrant",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Graphs of Trigonometric Functions",
                            "description": "Sketching and interpreting graphs of y = sin x, y = cos x, y = tan x and their transformations.",
                            "learning_objectives": [
                                {
                                    "objective": "Sketch graphs of y = sin x, y = cos x and y = tan x",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Graphical activities",
                                },
                                {
                                    "objective": "Solve trigonometric equations within a given range",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Trigonometric Identities",
                            "description": "Using the identity sin\u00b2\u03b8 + cos\u00b2\u03b8 = 1 and tan \u03b8 = sin \u03b8 / cos \u03b8.",
                            "learning_objectives": [
                                {
                                    "objective": "Apply the identity sin\u00b2\u03b8 + cos\u00b2\u03b8 = 1 to simplify expressions",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Prove simple trigonometric identities",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Scientific calculators", "type": "equipment"},
                        {"text": "Graph paper", "type": "equipment"},
                    ],
                },'''
new = '''                {
                    "title": "Trigonometry",
                    "year_level": 4,
                    "description": "Outcome: Use trigonometric rules to calculate unknown sides and angles in triangles.",
                    "subtopics": [
                        {
                            "title": "Sine and Cosine Rules",
                            "description": "Deriving the sine rule, calculating sides and angles using sine rule, deriving the cosine rule, calculating sides and angles using cosine rule.",
                            "learning_objectives": [
                                {
                                    "objective": "Derive the sine rule for any triangle",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, demonstration, explanation, question and answer",
                                },
                                {
                                    "objective": "Calculate a side and an angle using the sine rule",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, peer assessment, group assessment, pair work",
                                },
                                {
                                    "objective": "Derive the cosine rule for any triangle",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, demonstration, explanation, written exercises",
                                },
                                {
                                    "objective": "Calculate a side and an angle using the cosine rule",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, peer assessment, group assessment, pair work",
                                },
                            ],
                        },
                        {
                            "title": "Solving Problems with Sine and Cosine Rules",
                            "description": "Sketching diagrams from given information, calculating bearings, calculating distances using sine and cosine rules.",
                            "learning_objectives": [
                                {
                                    "objective": "Sketch diagrams from given information to apply sine and cosine rules",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion, demonstration, practical work, pair work",
                                },
                                {
                                    "objective": "Calculate the bearing of a point using sine and cosine rules",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, peer assessment, group assessment",
                                },
                                {
                                    "objective": "Calculate the distance between two points using cosine and sine rules",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, problem solving, practical work",
                                },
                            ],
                        },
                        {
                            "title": "Area Rule",
                            "description": "Discussing the area rule of a triangle, calculating the area and angles of a triangle using area rule.",
                            "learning_objectives": [
                                {
                                    "objective": "Discuss and apply the area rule of a triangle",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration, explanation, question and answer",
                                },
                                {
                                    "objective": "Calculate the area of a triangle using the area rule",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, peer assessment, group assessment, practical work",
                                },
                                {
                                    "objective": "Calculate angles of a triangle using the area rule",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work, practical work",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Charts", "type": "equipment"},
                        {"text": "Mathematical sets", "type": "equipment"},
                        {"text": "Geoboards", "type": "equipment"},
                        {"text": "Calculators", "type": "equipment"},
                    ],
                },'''
if old in content:
    content = content.replace(old, new, 1)
    count += 1
    print("2. Trigonometry (sine/cosine/area rule) updated")
else:
    print("2. ERROR: Trigonometry not found")

# ── 3. Polynomials (Form 4) ──
old = '''                {
                    "title": "Polynomials",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Operations with Polynomials",
                            "description": "Addition, subtraction and multiplication of polynomials.",
                            "learning_objectives": [
                                {
                                    "objective": "Perform addition, subtraction and multiplication of polynomials",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Factor Theorem and Remainder Theorem",
                            "description": "Using the factor theorem and remainder theorem to factorise and evaluate polynomials.",
                            "learning_objectives": [
                                {
                                    "objective": "Apply the factor theorem to factorise polynomials",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Use the remainder theorem to find the remainder when a polynomial is divided by a linear expression",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Solving Polynomial Equations",
                            "description": "Solving cubic and higher-degree polynomial equations.",
                            "learning_objectives": [
                                {
                                    "objective": "Solve cubic equations given one rational root",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Sketch graphs of polynomial functions",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Graphical activities",
                                },
                            ],
                        },
                    ],
                    "resources": [],
                },'''
new = '''                {
                    "title": "Polynomials",
                    "year_level": 4,
                    "description": "Outcome: Solve problems involving polynomials.",
                    "subtopics": [
                        {
                            "title": "Dividing Polynomials and Remainder Theorem",
                            "description": "Discussing polynomials, dividing a polynomial of higher degree by one of lower degree, discussing the remainder theorem, finding the remainder using long division and the remainder theorem.",
                            "learning_objectives": [
                                {
                                    "objective": "Discuss polynomials and their terminology",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, question and answer",
                                },
                                {
                                    "objective": "Divide a polynomial of higher degree by a polynomial of lower degree",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work",
                                },
                                {
                                    "objective": "Find the remainder using long division",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, written exercises, pair work",
                                },
                                {
                                    "objective": "Find the remainder using the remainder theorem",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, written exercises, pair work",
                                },
                                {
                                    "objective": "Use the remainder theorem to solve problems involving polynomials",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving, written exercises",
                                },
                            ],
                        },
                        {
                            "title": "Factorising Polynomials",
                            "description": "Discussing the factor theorem, factorising polynomials, using the factor theorem to solve problems involving polynomials.",
                            "learning_objectives": [
                                {
                                    "objective": "Discuss the factor theorem and its relationship to the remainder theorem",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, question and answer",
                                },
                                {
                                    "objective": "Factorise polynomials using the factor theorem",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work",
                                },
                                {
                                    "objective": "Use the factor theorem to solve problems involving polynomials",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving, written exercises",
                                },
                            ],
                        },
                        {
                            "title": "Solving Polynomial Equations and Identical Polynomials",
                            "description": "Solving polynomial equations of third degree, discussing identical polynomials, finding coefficients in identical polynomials.",
                            "learning_objectives": [
                                {
                                    "objective": "Describe polynomial equations of third degree",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, question and answer",
                                },
                                {
                                    "objective": "Solve polynomial equations of third degree",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work",
                                },
                                {
                                    "objective": "Discuss identical polynomials",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, explanation",
                                },
                                {
                                    "objective": "Find coefficients in identical polynomials",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, problem solving",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Charts", "type": "equipment"},
                    ],
                },'''
if old in content:
    content = content.replace(old, new, 1)
    count += 1
    print("3. Polynomials updated")
else:
    print("3. ERROR: Polynomials not found")

# ── 4. Probability (Form 4) ──
old = '''                {
                    "title": "Probability",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Combined Events",
                            "description": "Calculating probabilities of combined events using addition and multiplication rules.",
                            "learning_objectives": [
                                {
                                    "objective": "Apply the addition rule P(A \u222a B) = P(A) + P(B) \u2212 P(A \u2229 B)",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Apply the multiplication rule P(A \u2229 B) = P(A) \u00d7 P(B|A)",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Mutually Exclusive and Independent Events",
                            "description": "Understanding and distinguishing between mutually exclusive and independent events.",
                            "learning_objectives": [
                                {
                                    "objective": "Determine whether events are mutually exclusive or independent",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, examples",
                                },
                                {
                                    "objective": "Calculate probabilities involving mutually exclusive and independent events",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving",
                                },
                            ],
                        },
                    ],
                    "resources": [],
                },'''
new = '''                {
                    "title": "Probability",
                    "year_level": 4,
                    "description": "Outcome: Solve practical problems involving probability.",
                    "subtopics": [
                        {
                            "title": "Probability Space and Experiments",
                            "description": "Performing experiments involving two or more events, listing all possible and favourable outcomes, defining probability space/sample space.",
                            "learning_objectives": [
                                {
                                    "objective": "Perform experiments involving two or more events (e.g. tossing coins, die, picking cards)",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical experiments, group work, demonstration",
                                },
                                {
                                    "objective": "List all possible outcomes in two or more events",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, group assessment, observation",
                                },
                                {
                                    "objective": "List favourable outcomes in two or more events",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, question and answer",
                                },
                                {
                                    "objective": "Define probability space/sample space",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, explanation, demonstration",
                                },
                                {
                                    "objective": "List outcomes in a probability space",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, written exercises, projects",
                                },
                            ],
                        },
                        {
                            "title": "Calculating Probability of Two or More Events",
                            "description": "Calculating probability of two or more events, determining experimental probabilities, discussing independent and mutually exclusive events, representing events in tree diagrams, using probability to make inference.",
                            "learning_objectives": [
                                {
                                    "objective": "Calculate the probability of two or more events",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, group work, question and answer",
                                },
                                {
                                    "objective": "Determine experimental probabilities of events",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Experiments, practical work, group assessment",
                                },
                                {
                                    "objective": "Discuss independent and mutually exclusive events",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, explanation, observation",
                                },
                                {
                                    "objective": "Calculate the probability of two events (independent, mutually exclusive)",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, problem solving, group assessment",
                                },
                                {
                                    "objective": "Represent events in tree diagrams",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, written exercises, pair work",
                                },
                                {
                                    "objective": "Calculate the probability using a tree diagram",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, group work, question and answer",
                                },
                                {
                                    "objective": "Use probability to make inference",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Problem solving, discussion, projects",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Coins", "type": "equipment"},
                        {"text": "Die", "type": "equipment"},
                        {"text": "Standard packs of cards", "type": "equipment"},
                        {"text": "Branches of trees", "type": "equipment"},
                        {"text": "Balls, marbles, beans", "type": "equipment"},
                    ],
                },'''
if old in content:
    content = content.replace(old, new, 1)
    count += 1
    print("4. Probability updated")
else:
    print("4. ERROR: Probability not found")

# ── 5. Vectors (Form 4) ──
old = '''                {
                    "title": "Vectors",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Describing and Representing Vectors",
                            "description": "Defining vectors, column notation and geometric representation.",
                            "learning_objectives": [
                                {
                                    "objective": "Define a vector and give real-life examples",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, examples",
                                },
                                {
                                    "objective": "Represent vectors using column notation",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Draw vectors on a grid and identify equal vectors",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                            ],
                        },
                        {
                            "title": "Vector Addition and Subtraction",
                            "description": "Adding and subtracting vectors geometrically and algebraically.",
                            "learning_objectives": [
                                {
                                    "objective": "Add vectors using the triangle and parallelogram laws",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                                {
                                    "objective": "Subtract vectors and interpret the result",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Scalar Multiplication",
                            "description": "Multiplying vectors by a scalar and interpreting the effect.",
                            "learning_objectives": [
                                {
                                    "objective": "Multiply a vector by a scalar and interpret the result geometrically",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Solving Problems with Vectors",
                            "description": "Using vectors to solve geometric and real-world problems.",
                            "learning_objectives": [
                                {
                                    "objective": "Use vectors to solve problems involving displacement and position",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving",
                                },
                                {
                                    "objective": "Apply vectors to prove geometric properties",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Graph paper", "type": "equipment"},
                    ],
                },'''
new = '''                {
                    "title": "Vectors",
                    "year_level": 4,
                    "description": "Outcome: Solve geometric problems involving the use of vectors.",
                    "subtopics": [
                        {
                            "title": "Describing Vectors",
                            "description": "Describing vectors, presenting vectors in different notations, drawing vectors using squared paper, labelling vectors, writing vectors in column form, describing zero/null and position vectors, identifying parallel vectors.",
                            "learning_objectives": [
                                {
                                    "objective": "Describe vectors and present them in different notations",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration, explanation, question and answer",
                                },
                                {
                                    "objective": "Draw vectors using squared paper",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, written exercises, peer assessment",
                                },
                                {
                                    "objective": "Write vectors in column form and label them",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, group assessment",
                                },
                                {
                                    "objective": "Describe zero/null vectors and position vectors",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration, explanation",
                                },
                                {
                                    "objective": "Identify parallel vectors",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work, practical work",
                                },
                            ],
                        },
                        {
                            "title": "Vector Operations",
                            "description": "Adding vectors, subtracting vectors, multiplying a vector by a scalar, calculating the magnitude of a vector, finding the mid-point of a vector.",
                            "learning_objectives": [
                                {
                                    "objective": "Describe and perform vector addition",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, explanation, written exercises, peer assessment",
                                },
                                {
                                    "objective": "Describe and perform vector subtraction",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, explanation, written exercises, pair work",
                                },
                                {
                                    "objective": "Discuss and perform scalar multiplication of a vector",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, explanation, written exercises, group assessment",
                                },
                                {
                                    "objective": "Calculate the magnitude of a vector",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work, practical work",
                                },
                                {
                                    "objective": "Find the mid-point of a vector",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, peer assessment, group assessment",
                                },
                            ],
                        },
                        {
                            "title": "Solving Problems with Vectors",
                            "description": "Showing that points are collinear using the vector method, describing parallelogram and triangle laws, adding and subtracting vectors using these laws, solving problems by applying a parallelogram law.",
                            "learning_objectives": [
                                {
                                    "objective": "Discuss the meaning of a collinear point",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration, explanation",
                                },
                                {
                                    "objective": "Show that points are collinear using the vector method",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, practical work, pair work",
                                },
                                {
                                    "objective": "Describe parallelogram and triangle laws of vector addition",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration, explanation, question and answer",
                                },
                                {
                                    "objective": "Add and subtract vectors using triangle and parallelogram laws",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, peer assessment, group assessment",
                                },
                                {
                                    "objective": "Solve problems by applying a parallelogram law",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving, written exercises, practical work",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Squared paper", "type": "equipment"},
                        {"text": "Charts", "type": "equipment"},
                        {"text": "Graph paper", "type": "equipment"},
                        {"text": "Pegboards", "type": "equipment"},
                        {"text": "Geoboards", "type": "equipment"},
                    ],
                },'''
if old in content:
    content = content.replace(old, new, 1)
    count += 1
    print("5. Vectors updated")
else:
    print("5. ERROR: Vectors not found")

# ── 6. Linear Programming (Form 4) ──
old = '''                {
                    "title": "Linear Programming",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Formulating Inequalities",
                            "description": "Translating word problems into linear inequalities.",
                            "learning_objectives": [
                                {
                                    "objective": "Formulate linear inequalities from real-life constraints",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving",
                                },
                            ],
                        },
                        {
                            "title": "Feasible Region and Optimisation",
                            "description": "Graphing the feasible region and finding the optimal solution.",
                            "learning_objectives": [
                                {
                                    "objective": "Graph the feasible region defined by a set of linear inequalities",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                                {
                                    "objective": "Find the maximum or minimum value of an objective function at the vertices",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Graph paper", "type": "equipment"},
                    ],
                },'''
new = '''                {
                    "title": "Linear Programming",
                    "year_level": 4,
                    "description": "Outcome: Solve linear programming problems.",
                    "subtopics": [
                        {
                            "title": "Formulating Inequalities",
                            "description": "Identifying constraints, identifying variables, formulating inequalities from given information.",
                            "learning_objectives": [
                                {
                                    "objective": "Identify constraints and variables from a given problem",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Group work, demonstration, discussion",
                                },
                                {
                                    "objective": "Formulate inequalities from given information",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, question and answer, pair work",
                                },
                            ],
                        },
                        {
                            "title": "Solving Linear Programming Problems",
                            "description": "Identifying the feasible region, finding vertices, formulating objective functions, finding maximum or minimum value of the objective function.",
                            "learning_objectives": [
                                {
                                    "objective": "Identify the feasible region from a set of linear inequalities",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises, individual work, discussions",
                                },
                                {
                                    "objective": "Find the vertices of the feasible region",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work",
                                },
                                {
                                    "objective": "Formulate objective functions",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Group work, demonstration",
                                },
                                {
                                    "objective": "Find the maximum or minimum value of the objective function",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, problem solving",
                                },
                                {
                                    "objective": "Find solutions of linear programming problems",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving, study tour, written exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Calculators", "type": "equipment"},
                        {"text": "Rulers", "type": "equipment"},
                        {"text": "Computers", "type": "equipment"},
                        {"text": "Chart paper", "type": "equipment"},
                        {"text": "Graph paper", "type": "equipment"},
                        {"text": "Graph boards", "type": "equipment"},
                        {"text": "Markers", "type": "equipment"},
                    ],
                },'''
if old in content:
    content = content.replace(old, new, 1)
    count += 1
    print("6. Linear Programming updated")
else:
    print("6. ERROR: Linear Programming not found")

# ── 7. Mensuration (Form 4) ──
old = '''                {
                    "title": "Mensuration",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Surface Area and Volume of Solids",
                            "description": "Calculating surface area and volume of pyramids, cones, spheres and frustums.",
                            "learning_objectives": [
                                {
                                    "objective": "Calculate the surface area and volume of pyramids",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Calculate the surface area and volume of cones",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Calculate the surface area and volume of spheres",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },'''
new = '''                {
                    "title": "Mensuration",
                    "year_level": 4,
                    "description": "Outcome: Solve problems involving area and volume of geometric shapes.",
                    "subtopics": [
                        {
                            "title": "Surface Area and Volume of 3-D Shapes",
                            "description": "Discussing and sketching 3-D shapes, finding surface areas and volumes of cubes, cuboids, cylinders, pyramids, cones, spheres, prisms and composite solids.",
                            "learning_objectives": [
                                {
                                    "objective": "Discuss and sketch 3-D shapes",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration, explanation, question and answer",
                                },
                                {
                                    "objective": "Find surface areas of cubes, cuboids, cylinders, pyramids, cones, spheres and prisms",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, peer assessment, group assessment, practical work",
                                },
                                {
                                    "objective": "Find surface areas of composite solids",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work, practical work",
                                },
                                {
                                    "objective": "Find volumes of cubes, cuboids, pyramids, cones, spheres, prisms and cylinders",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, peer assessment, group assessment, pair work",
                                },
                                {
                                    "objective": "Sketch composite 3-D shapes and find their volumes",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, demonstration, written exercises",
                                },
                            ],
                        },'''
if old in content:
    content = content.replace(old, new, 1)
    count += 1
    print("7. Mensuration updated")
else:
    print("7. ERROR: Mensuration not found")

# Now also update the Mensuration subtopic that follows (Segment Area -> angles/lengths in 3D)
old_mens2 = '''                        {
                            "title": "Segment Area",
                            "description": "Calculating the area of a segment of a circle.",
                            "learning_objectives": [
                                {
                                    "objective": "Calculate the area of a segment of a circle",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "3D models of pyramids, cones and spheres",
                            "type": "equipment",
                        },
                    ],
                },'''
new_mens2 = '''                        {
                            "title": "Angles and Lengths in 3-D Shapes",
                            "description": "Identifying and calculating angles between lines, planes, and between a plane and a line, identifying and calculating lengths of sides in 3-D shapes.",
                            "learning_objectives": [
                                {
                                    "objective": "Identify angles between lines, planes, and between a plane and a line",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration, explanation",
                                },
                                {
                                    "objective": "Calculate angles between lines and between planes in 3-D shapes",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, practical work, pair work",
                                },
                                {
                                    "objective": "Calculate the angle between a plane and a line",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, demonstration, group assessment",
                                },
                                {
                                    "objective": "Identify and calculate lengths of sides in 3-D shapes",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, peer assessment, pair work",
                                },
                            ],
                        },
                        {
                            "title": "Word Problems on Surface Area and Volume",
                            "description": "Sketching diagrams from given problems, solving word problems involving surface areas and volumes.",
                            "learning_objectives": [
                                {
                                    "objective": "Sketch diagrams from given problems involving 3-D shapes",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, demonstration, pair work",
                                },
                                {
                                    "objective": "Solve word problems involving surface areas and volumes",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving, written exercises, peer assessment, group assessment",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Charts", "type": "equipment"},
                        {"text": "Mathematical sets", "type": "equipment"},
                        {"text": "Models of cuboids, cubes, cones and prisms", "type": "equipment"},
                        {"text": "Calculators", "type": "equipment"},
                    ],
                },'''
if old_mens2 in content:
    content = content.replace(old_mens2, new_mens2, 1)
    count += 1
    print("7b. Mensuration second half updated")
else:
    print("7b. ERROR: Mensuration second half not found")

# ── 8. Cubic Graphs (Form 4) ──
old = '''                {
                    "title": "Cubic Graphs",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Sketching Cubic Curves",
                            "description": "Sketching graphs of cubic functions and identifying key features.",
                            "learning_objectives": [
                                {
                                    "objective": "Sketch graphs of cubic functions of the form y = ax\u00b3 + bx\u00b2 + cx + d",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Graphical activities",
                                },
                                {
                                    "objective": "Identify the turning points and x-intercepts of cubic graphs",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Graph paper", "type": "equipment"},
                    ],
                },'''
new = '''                {
                    "title": "Cubic Graphs",
                    "year_level": 4,
                    "description": "Outcome: Work out problems involving cubic functions.",
                    "subtopics": [
                        {
                            "title": "Drawing Graphs of Cubic Functions",
                            "description": "Constructing tables of values and drawing graphs of cubic functions.",
                            "learning_objectives": [
                                {
                                    "objective": "Construct tables of values for cubic functions",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, question and answer, written exercises, pair and group work",
                                },
                                {
                                    "objective": "Draw graphs of cubic functions from tables of values",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, explanations, discussions, written exercises",
                                },
                            ],
                        },
                        {
                            "title": "Solving Cubic Equations and Simultaneous Equations Graphically",
                            "description": "Solving cubic equations graphically and solving simultaneous linear and cubic equations graphically.",
                            "learning_objectives": [
                                {
                                    "objective": "Solve cubic equations graphically",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving, written exercises, oral exercises",
                                },
                                {
                                    "objective": "Solve simultaneous linear and cubic equations graphically",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving, pair and group work, written exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Charts", "type": "equipment"},
                        {"text": "Graph paper", "type": "equipment"},
                        {"text": "Mathematical instruments", "type": "equipment"},
                        {"text": "Rulers", "type": "equipment"},
                        {"text": "Graph board", "type": "equipment"},
                        {"text": "Observation checklists", "type": "equipment"},
                        {"text": "Graphic calculators", "type": "equipment"},
                        {"text": "Computers", "type": "equipment"},
                    ],
                },'''
if old in content:
    content = content.replace(old, new, 1)
    count += 1
    print("8. Cubic Graphs updated")
else:
    print("8. ERROR: Cubic Graphs not found")

print(f"\nTotal replacements: {count}/8")

with open("backend/app/mathematics/seed_math_syllabus.py", "w", encoding="utf-8") as f:
    f.write(content)
