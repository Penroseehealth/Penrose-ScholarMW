"""Replace Vectors (Form 4) with detailed syllabus content."""
with open("backend/app/mathematics/seed_math_syllabus.py", "r", encoding="utf-8") as f:
    content = f.read()

old = '''                {
                    "title": "Vectors",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Vector Notation and Representation",
                            "description": "Representing vectors as column vectors, directed line segments, and unit vectors i and j.",
                            "learning_objectives": [
                                {
                                    "objective": "Represent vectors as column vectors and directed line segments",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, examples",
                                },
                                {
                                    "objective": "Express vectors in terms of unit vectors i and j",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Magnitude and Direction",
                            "description": "Calculating the magnitude of a vector and its direction.",
                            "learning_objectives": [
                                {
                                    "objective": "Calculate the magnitude of a vector",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Find the direction of a vector using trigonometry",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Vector Operations",
                            "description": "Addition, subtraction, scalar multiplication of vectors.",
                            "learning_objectives": [
                                {
                                    "objective": "Add and subtract vectors",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Multiply vectors by a scalar",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Applications of Vectors",
                            "description": "Solving problems involving displacement, velocity and force using vectors.",
                            "learning_objectives": [
                                {
                                    "objective": "Apply vectors to solve problems involving displacement, velocity and force",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving",
                                },
                                {
                                    "objective": "Prove geometric results using vectors",
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
    print("Vectors updated successfully")
else:
    print("ERROR: Vectors not found")

with open("backend/app/mathematics/seed_math_syllabus.py", "w", encoding="utf-8") as f:
    f.write(content)
