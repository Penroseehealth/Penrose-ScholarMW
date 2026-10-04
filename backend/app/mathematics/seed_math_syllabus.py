"""Seed the official Malawi Mathematics syllabus (MoEST, Forms 1 to 4).

Exact reproduction of the official Mathematics Syllabus scope chart (Forms 1–4)
and detailed teaching syllabus. Run from lifespan in main.py.
Idempotent — skips if subject already exists.
"""

from sqlalchemy import select

from app.database.engine import async_session
from app.models.stem import (
    SyllabusCoreElement,
    SyllabusLearningObjective,
    SyllabusResource,
    SyllabusSubject,
    SyllabusSubtopic,
    SyllabusTopic,
    SyllabusVersion,
)

MATH_SYLLABUS = {
    "subject": {
        "name": "Mathematics",
        "slug": "mathematics",
        "description": "Malawi MSCE Mathematics Syllabus — MoEST Forms 1 to 4",
        "icon": "calculate_rounded",
        "color": "#8B5CF6",
    },
    "version": {
        "version_name": "MoEST Forms 1 to 4",
        "year_effective": 2018,
        "examination_board": "Malawi National Examinations Board (MANEB)",
        "description": (
            "Official Mathematics syllabus for Malawi School Certificate of Education "
            "(MSCE), covering Forms 1 to 4. Published by the Ministry of Education, "
            "Science and Technology through the Malawi Institute of Education (MIE)."
        ),
    },
    # ═══════════════════════════════════════════════════════════════════════════
    # CORE ELEMENT 1 — NUMBER AND NUMERATION
    # ═══════════════════════════════════════════════════════════════════════════
    "core_elements": [
        {
            "number": 1,
            "name": "Number and Numeration",
            "description": "Number systems, algebra, commercial arithmetic, equations, and patterns across Forms 1–4.",
            "topics": [
                # ── FORM 1 ─────────────────────────────────────────────────
                {
                    "title": "Number Systems",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Natural Numbers, Whole Numbers and Integers",
                            "description": "Place value, ordering, rounding, and operations with whole numbers.",
                            "learning_objectives": [
                                {
                                    "objective": "Identify and classify natural numbers, whole numbers and integers",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Demonstration, discussion",
                                },
                                {
                                    "objective": "Use place value to read and write large numbers",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                                {
                                    "objective": "Round numbers to a given degree of accuracy",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Fractions, Decimals and Percentages",
                            "description": "Conversion and operations with fractions, decimals and percentages.",
                            "learning_objectives": [
                                {
                                    "objective": "Convert between fractions, decimals and percentages",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Add, subtract, multiply and divide fractions",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                            ],
                        },
                        {
                            "title": "Rational Numbers",
                            "description": "Operations with rational numbers including negative fractions and decimals.",
                            "learning_objectives": [
                                {
                                    "objective": "Perform operations with rational numbers on the number line",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Number line activities",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Number line charts", "type": "equipment"},
                        {"text": "Calculators", "type": "equipment"},
                    ],
                },
                {
                    "title": "Algebraic Expressions",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Variables, Constants and Coefficients",
                            "description": "Introduction to algebraic notation and terminology.",
                            "learning_objectives": [
                                {
                                    "objective": "Identify variables, constants, coefficients and terms in algebraic expressions",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, examples",
                                },
                                {
                                    "objective": "Simplify algebraic expressions by collecting like terms",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Substitution",
                            "description": "Evaluating algebraic expressions by substituting given values.",
                            "learning_objectives": [
                                {
                                    "objective": "Substitute numerical values into algebraic expressions",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Chalkboard", "type": "equipment"},
                        {"text": "Exercise books", "type": "equipment"},
                    ],
                },
                {
                    "title": "Simple Algebraic Fractions",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Simplifying Algebraic Fractions",
                            "description": "Reducing algebraic fractions to lowest terms.",
                            "learning_objectives": [
                                {
                                    "objective": "Simplify algebraic fractions by cancelling common factors",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Operations with Algebraic Fractions",
                            "description": "Addition and subtraction of simple algebraic fractions.",
                            "learning_objectives": [
                                {
                                    "objective": "Add and subtract simple algebraic fractions",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Chalkboard", "type": "equipment"},
                        {"text": "Exercise books", "type": "equipment"},
                    ],
                },
                {
                    "title": "Approximations and Estimations",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Rounding and Estimation",
                            "description": "Rounding to significant figures and decimal places; estimation in calculations.",
                            "learning_objectives": [
                                {
                                    "objective": "Round numbers to a given number of significant figures",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Use estimation to check the reasonableness of answers",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Problem solving",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Calculators", "type": "equipment"},
                    ],
                },
                {
                    "title": "HCF and LCM",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Highest Common Factor (HCF)",
                            "description": "Finding the HCF of a set of numbers using prime factorisation and listing.",
                            "learning_objectives": [
                                {
                                    "objective": "Find the HCF of two or more numbers using prime factorisation",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Lowest Common Multiple (LCM)",
                            "description": "Finding the LCM of a set of numbers using prime factorisation and listing.",
                            "learning_objectives": [
                                {
                                    "objective": "Find the LCM of two or more numbers using prime factorisation",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Factor tree diagrams", "type": "equipment"},
                    ],
                },
                {
                    "title": "Factorisation",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Common Factors",
                            "description": "Taking out common factors from algebraic expressions.",
                            "learning_objectives": [
                                {
                                    "objective": "Factorise algebraic expressions by taking out common factors",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Difference of Two Squares",
                            "description": "Factorising expressions of the form a² − b².",
                            "learning_objectives": [
                                {
                                    "objective": "Factorise expressions using the difference of two squares identity",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Simple Quadratic Expressions",
                            "description": "Factorising quadratic expressions of the form x² + bx + c.",
                            "learning_objectives": [
                                {
                                    "objective": "Factorise quadratic expressions of the form x² + bx + c",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Chalkboard", "type": "equipment"},
                        {"text": "Exercise books", "type": "equipment"},
                    ],
                },
                {
                    "title": "Commercial Arithmetic",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Profit, Loss and Discount",
                            "description": "Calculating profit, loss, percentage profit, percentage loss and discount.",
                            "learning_objectives": [
                                {
                                    "objective": "Calculate profit, loss, percentage profit and percentage loss",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Real-life problems",
                                },
                                {
                                    "objective": "Calculate discount and selling price after discount",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Real-life problems",
                                },
                            ],
                        },
                        {
                            "title": "Simple Interest",
                            "description": "Calculating simple interest and total amount using I = PRt/100.",
                            "learning_objectives": [
                                {
                                    "objective": "Calculate simple interest using the formula I = PRt/100",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Hire Purchase",
                            "description": "Calculating hire purchase price including deposit and instalments.",
                            "learning_objectives": [
                                {
                                    "objective": "Calculate the total hire purchase price and compare with cash price",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Real-life problems",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Price lists and catalogues", "type": "equipment"},
                    ],
                },
                {
                    "title": "Linear Equation",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Setting Up Linear Equations",
                            "description": "Translating word problems into linear equations in one variable.",
                            "learning_objectives": [
                                {
                                    "objective": "Formulate linear equations from word problems",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving",
                                },
                            ],
                        },
                        {
                            "title": "Solving Linear Equations",
                            "description": "Solving linear equations in one variable.",
                            "learning_objectives": [
                                {
                                    "objective": "Solve linear equations in one variable",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Verify solutions by substitution",
                                    "cognitive_level": "Verification",
                                    "teaching_method": "Practical exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Chalkboard", "type": "equipment"},
                        {"text": "Exercise books", "type": "equipment"},
                    ],
                },
                {
                    "title": "Number Patterns",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Identifying Patterns",
                            "description": "Recognising and describing number patterns including linear sequences.",
                            "learning_objectives": [
                                {
                                    "objective": "Identify and describe linear number patterns",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Pattern activities",
                                },
                                {
                                    "objective": "Find the nth term of a linear sequence",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Chalkboard", "type": "equipment"},
                        {"text": "Exercise books", "type": "equipment"},
                    ],
                },
                # ── FORM 2 ─────────────────────────────────────────────────
                {
                    "title": "Number Patterns",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Linear and Quadratic Sequences",
                            "description": "Generating and describing linear and quadratic number patterns.",
                            "learning_objectives": [
                                {
                                    "objective": "Generate terms of a sequence from the nth term rule",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Find the nth term rule for quadratic sequences",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Pattern activities",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Chalkboard", "type": "equipment"},
                        {"text": "Exercise books", "type": "equipment"},
                    ],
                },
                {
                    "title": "Algebraic Expressions",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Expanding Brackets",
                            "description": "Expanding single and double brackets.",
                            "learning_objectives": [
                                {
                                    "objective": "Expand expressions involving single brackets",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Expand the product of two linear expressions",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Factorising Expressions",
                            "description": "Factorising algebraic expressions including common factors and simple quadratics.",
                            "learning_objectives": [
                                {
                                    "objective": "Factorise algebraic expressions by taking out the highest common factor",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Chalkboard", "type": "equipment"},
                        {"text": "Exercise books", "type": "equipment"},
                    ],
                },
                {
                    "title": "Linear Simultaneous Equations",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Solving by Substitution",
                            "description": "Solving pairs of linear simultaneous equations using the substitution method.",
                            "learning_objectives": [
                                {
                                    "objective": "Solve linear simultaneous equations using substitution",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Solving by Elimination",
                            "description": "Solving pairs of linear simultaneous equations using the elimination method.",
                            "learning_objectives": [
                                {
                                    "objective": "Solve linear simultaneous equations using elimination",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Word Problems",
                            "description": "Forming and solving simultaneous equations from real-life situations.",
                            "learning_objectives": [
                                {
                                    "objective": "Formulate simultaneous equations from word problems",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Chalkboard", "type": "equipment"},
                        {"text": "Exercise books", "type": "equipment"},
                    ],
                },
                {
                    "title": "Proportion",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Direct Proportion",
                            "description": "Understanding and solving problems involving direct proportion.",
                            "learning_objectives": [
                                {
                                    "objective": "Solve problems involving direct proportion",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Real-life problems",
                                },
                            ],
                        },
                        {
                            "title": "Inverse Proportion",
                            "description": "Understanding and solving problems involving inverse proportion.",
                            "learning_objectives": [
                                {
                                    "objective": "Solve problems involving inverse proportion",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Real-life problems",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Chalkboard", "type": "equipment"},
                        {"text": "Exercise books", "type": "equipment"},
                    ],
                },
                {
                    "title": "Mixtures",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Mixture Problems",
                            "description": "Solving problems involving mixtures using ratio and proportion.",
                            "learning_objectives": [
                                {
                                    "objective": "Solve problems involving mixtures using ratio and proportion",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Chalkboard", "type": "equipment"},
                        {"text": "Exercise books", "type": "equipment"},
                    ],
                },
                {
                    "title": "Indices",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Laws of Indices",
                            "description": "Applying the laws of indices to simplify expressions with integer exponents.",
                            "learning_objectives": [
                                {
                                    "objective": "Apply the laws of indices to simplify expressions",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Evaluate expressions involving zero, negative and fractional indices",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Chalkboard", "type": "equipment"},
                        {"text": "Exercise books", "type": "equipment"},
                    ],
                },
                {
                    "title": "Standard Form",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Converting to Standard Form",
                            "description": "Expressing numbers in standard form a × 10^n.",
                            "learning_objectives": [
                                {
                                    "objective": "Express large and small numbers in standard form",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Perform calculations with numbers in standard form",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Calculator activities",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Calculators", "type": "equipment"},
                    ],
                },
                {
                    "title": "Logarithms",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Definition and Laws of Logarithms",
                            "description": "Understanding logarithms as indices and applying the laws of logarithms.",
                            "learning_objectives": [
                                {
                                    "objective": "Define logarithms and convert between指数 and logarithmic form",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, examples",
                                },
                                {
                                    "objective": "Apply the laws of logarithms to simplify expressions",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Using Log Tables and Calculators",
                            "description": "Using logarithm tables and calculators to find logarithms.",
                            "learning_objectives": [
                                {
                                    "objective": "Use logarithm tables to find the logarithm of a number",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Logarithm tables", "type": "equipment"},
                        {"text": "Calculators", "type": "equipment"},
                    ],
                },
                {
                    "title": "Quadratic Equations",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Solving by Factorisation",
                            "description": "Solving quadratic equations by factorising.",
                            "learning_objectives": [
                                {
                                    "objective": "Solve quadratic equations by factorising",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Solving by Completing the Square",
                            "description": "Solving quadratic equations by completing the square.",
                            "learning_objectives": [
                                {
                                    "objective": "Solve quadratic equations by completing the square",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Nature of Roots",
                            "description": "Using the discriminant to determine the nature of roots.",
                            "learning_objectives": [
                                {
                                    "objective": "Use the discriminant to determine the nature of roots of a quadratic equation",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, examples",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Chalkboard", "type": "equipment"},
                        {"text": "Exercise books", "type": "equipment"},
                    ],
                },
                # ── FORM 3 ─────────────────────────────────────────────────
                # Outcome: Demonstrate understanding of number systems and their
                # properties and apply them in solving problems in everyday life.
                {
                    "title": "Quadratic Equations",
                    "year_level": 3,
                    "description": "Assessment standard: solve problems involving quadratic equations.",
                    "subtopics": [
                        {
                            "title": "Factorising Quadratic Expressions",
                            "description": "Discussing, factorising and solving quadratic expressions.",
                            "learning_objectives": [
                                {
                                    "objective": "Discuss and identify quadratic expressions of the form ax² + bx + c",
                                    "cognitive_level": "Knowledge",
                                    "teaching_activity": "Discussing quadratic expressions",
                                    "teaching_method": "Discussion, question and answer",
                                },
                                {
                                    "objective": "Factorise quadratic expressions by inspection, common factors and difference of two squares",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Factorising quadratic expressions",
                                    "teaching_method": "Guided practice, written exercises",
                                },
                            ],
                        },
                        {
                            "title": "Solving Quadratic Equations",
                            "description": "Solving quadratic equations by factorisation and completing the square.",
                            "learning_objectives": [
                                {
                                    "objective": "Solve quadratic equations by factorisation",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Solving quadratic equations by factorisation",
                                    "teaching_method": "Problem solving, written exercises",
                                },
                                {
                                    "objective": "Complete the square of quadratic expressions of the form x² + bx + c",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Completing the square of quadratic expressions",
                                    "teaching_method": "Guided practice, pair work",
                                },
                                {
                                    "objective": "Solve quadratic equations by completing the square",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Solving quadratic equations by completing the square",
                                    "teaching_method": "Guided practice, written exercises",
                                },
                            ],
                        },
                        {
                            "title": "The Quadratic Formula and Applications",
                            "description": "Deriving and applying the quadratic formula; formulating quadratic equations from practical problems.",
                            "learning_objectives": [
                                {
                                    "objective": "Derive the quadratic formula from the general quadratic equation by completing the square",
                                    "cognitive_level": "Analysis",
                                    "teaching_activity": "Deriving the quadratic formula",
                                    "teaching_method": "Discussion, demonstration",
                                },
                                {
                                    "objective": "Solve quadratic equations using the quadratic formula x = (-b ± √(b² - 4ac)) / 2a",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Solving quadratic equations using the formula",
                                    "teaching_method": "Guided practice, written exercises",
                                },
                                {
                                    "objective": "Formulate quadratic equations from practical (everyday life) problems and solve them",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Formulating quadratic equations from practical problems",
                                    "teaching_method": "Problem solving, discussion, pair work",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Charts", "type": "equipment"},
                    ],
                },
                {
                    "title": "Irrational Numbers",
                    "year_level": 3,
                    "description": "Assessment standard: carry out basic operations involving irrational numbers.",
                    "subtopics": [
                        {
                            "title": "Recognising Irrational Numbers",
                            "description": "Describing, identifying and discussing irrational numbers and surds.",
                            "learning_objectives": [
                                {
                                    "objective": "Describe and identify irrational numbers as numbers that cannot be expressed as a fraction p/q",
                                    "cognitive_level": "Knowledge",
                                    "teaching_activity": "Describing irrational numbers, identifying irrational numbers",
                                    "teaching_method": "Discussion, demonstration",
                                },
                                {
                                    "objective": "Discuss surds and their properties",
                                    "cognitive_level": "Knowledge",
                                    "teaching_activity": "Discussing surds",
                                    "teaching_method": "Discussion, question and answer",
                                },
                            ],
                        },
                        {
                            "title": "Operations with Surds",
                            "description": "Simplifying, adding, subtracting, multiplying, dividing surds, conjugate surds and rationalising denominators.",
                            "learning_objectives": [
                                {
                                    "objective": "Express surds in their simplest form",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Expressing surds in their simplest form",
                                    "teaching_method": "Guided practice, written exercises",
                                },
                                {
                                    "objective": "Add and subtract surds",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Adding surds, subtracting surds",
                                    "teaching_method": "Guided practice, written exercises",
                                },
                                {
                                    "objective": "Multiply and divide surds",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Multiplying surds, dividing surds",
                                    "teaching_method": "Guided practice, written exercises",
                                },
                                {
                                    "objective": "Write conjugate surds and expand conjugate surds",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Writing conjugate surds, expanding conjugate surds",
                                    "teaching_method": "Guided practice, pair work",
                                },
                                {
                                    "objective": "Rationalise surd denominators",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Rationalising surd denominators",
                                    "teaching_method": "Guided practice, written exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Charts", "type": "equipment"},
                    ],
                },
                {
                    "title": "Algebraic Fractions with Linear or Quadratic Denominators",
                    "year_level": 3,
                    "description": "Assessment standard: carry out basic operations on algebraic expressions.",
                    "subtopics": [
                        {
                            "title": "Simplifying Algebraic Fractions",
                            "description": "Identifying common factors and expressing algebraic fractions into lowest terms.",
                            "learning_objectives": [
                                {
                                    "objective": "Identify common factors in the numerator and denominator of algebraic fractions",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Identifying common factors",
                                    "teaching_method": "Discussion, guided practice",
                                },
                                {
                                    "objective": "Reduce fractions to their lowest term and express algebraic fractions into their lowest terms",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Reducing fractions to their lowest term, expressing algebraic fractions into their lowest terms",
                                    "teaching_method": "Guided practice, written exercises",
                                },
                            ],
                        },
                        {
                            "title": "Operations with Algebraic Fractions",
                            "description": "Finding common denominators, adding, subtracting, multiplying and dividing algebraic fractions.",
                            "learning_objectives": [
                                {
                                    "objective": "Find the common denominator of algebraic fractions",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Finding the common denominator of algebraic fractions",
                                    "teaching_method": "Guided practice, written exercises",
                                },
                                {
                                    "objective": "Add and subtract algebraic fractions",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Adding algebraic fractions, subtracting algebraic fractions",
                                    "teaching_method": "Guided practice, written exercises, pair work",
                                },
                                {
                                    "objective": "Multiply and divide algebraic fractions",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Multiplying algebraic fractions, dividing algebraic fractions",
                                    "teaching_method": "Guided practice, written exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Charts", "type": "equipment"},
                    ],
                },
                {
                    "title": "Subject of the Formulae",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Changing the Subject",
                            "description": "Rearranging formulae to make a different variable the subject.",
                            "learning_objectives": [
                                {
                                    "objective": "Make a specified variable the subject of a formula",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Substitute values into rearranged formulae",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Chalkboard", "type": "equipment"},
                        {"text": "Exercise books", "type": "equipment"},
                    ],
                },
                {
                    "title": "Exponential and Logarithmic Equations",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Solving Exponential Equations",
                            "description": "Solving equations where the unknown appears as an index.",
                            "learning_objectives": [
                                {
                                    "objective": "Solve exponential equations using logarithms",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Solving Logarithmic Equations",
                            "description": "Solving equations involving logarithms.",
                            "learning_objectives": [
                                {
                                    "objective": "Solve equations involving logarithms",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Apply logarithmic laws to simplify and solve equations",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Problem solving",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Chalkboard", "type": "equipment"},
                        {"text": "Exercise books", "type": "equipment"},
                    ],
                },
                # ── FORM 4 ─────────────────────────────────────────────────
                {
                    "title": "Matrices",
                    "year_level": 4,
                    "description": "Outcome: Solve problems involving matrices.",
                    "subtopics": [
                        {
                            "title": "Describing Matrices",
                            "description": "Defining a matrix, presenting information in matrix form, identifying the order of a matrix, identifying types of matrices (square, row, column, zero).",
                            "learning_objectives": [
                                {
                                    "objective": "Define a matrix and present information in matrix form",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration, explanation, question and answer",
                                },
                                {
                                    "objective": "Identify the order of a matrix (rows and columns)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Demonstration, explanation, written exercises",
                                },
                                {
                                    "objective": "Identify types of matrices: square matrix, row matrix, column matrix, zero matrix",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration, peer assessment, group assessment",
                                },
                            ],
                        },
                        {
                            "title": "Basic Operations Involving Matrices",
                            "description": "Adding matrices, subtracting matrices, multiplying a matrix by a scalar, multiplying 2×2 matrices.",
                            "learning_objectives": [
                                {
                                    "objective": "Add matrices of the same order",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, peer assessment, group assessment",
                                },
                                {
                                    "objective": "Subtract matrices of the same order",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, peer assessment, group assessment",
                                },
                                {
                                    "objective": "Multiply a matrix by a scalar",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work",
                                },
                                {
                                    "objective": "Multiply two compatible 2×2 matrices",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, peer assessment, group assessment",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Bottle tops", "type": "equipment"},
                        {"text": "Seeds", "type": "equipment"},
                        {"text": "Tables of frequencies", "type": "equipment"},
                        {
                            "text": "Arrays of prices and frequencies",
                            "type": "equipment",
                        },
                        {"text": "Squared paper", "type": "equipment"},
                    ],
                },
                {
                    "title": "Simultaneous Linear and Quadratic Equations",
                    "year_level": 4,
                    "description": "Outcome: Solve simultaneous linear and quadratic equations and practical problems involving them.",
                    "subtopics": [
                        {
                            "title": "Solving Simultaneous Linear and Quadratic Equations",
                            "description": "Discussing and solving simultaneous equations involving one linear and one quadratic equation.",
                            "learning_objectives": [
                                {
                                    "objective": "Discuss simultaneous linear and quadratic equations and their solution methods",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, question and answer",
                                },
                                {
                                    "objective": "Solve simultaneous linear and quadratic equations algebraically and graphically",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work",
                                },
                            ],
                        },
                        {
                            "title": "Practical Problems Involving Simultaneous Equations",
                            "description": "Formulating and solving simultaneous linear and quadratic equations from practical problems.",
                            "learning_objectives": [
                                {
                                    "objective": "Formulate simultaneous linear and quadratic equations from practical problems",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving, discussion",
                                },
                                {
                                    "objective": "Solve practical problems involving simultaneous linear and quadratic equations",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Charts", "type": "equipment"},
                    ],
                },
                {
                    "title": "Progressions",
                    "year_level": 4,
                    "description": "Outcome: Solve practical problems involving progressions.",
                    "subtopics": [
                        {
                            "title": "Arithmetic Progression (AP)",
                            "description": "Recognising APs, finding common difference, finding terms, generating and using the nth term formula, sum of AP, applications.",
                            "learning_objectives": [
                                {
                                    "objective": "Recognise an arithmetic progression (AP)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Problem solving, discussion, question and answer",
                                },
                                {
                                    "objective": "Calculate the common difference of an AP",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work",
                                },
                                {
                                    "objective": "Find terms of an arithmetic progression",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, demonstration",
                                },
                                {
                                    "objective": "Generate the formula for the nth term of an AP",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Problem solving, discussion, demonstration",
                                },
                                {
                                    "objective": "Use the formula for the nth term of an AP to calculate the common difference, the number of terms, and terms of the AP",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work, oral exercises",
                                },
                                {
                                    "objective": "Generate the formula for finding the sum of an AP",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Problem solving, discussion, demonstration",
                                },
                                {
                                    "objective": "Calculate the sum of an AP",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work",
                                },
                                {
                                    "objective": "Discuss the application of APs in real-life situations and solve problems involving AP",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving, group work, discussion",
                                },
                            ],
                        },
                        {
                            "title": "Geometric Progression (GP)",
                            "description": "Recognising GPs, finding common ratio, finding terms, generating and using the nth term formula, sum of GP, applications.",
                            "learning_objectives": [
                                {
                                    "objective": "Recognise a geometric progression (GP)",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Problem solving, discussion, question and answer",
                                },
                                {
                                    "objective": "Calculate the common ratio of a GP",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work",
                                },
                                {
                                    "objective": "Find terms of a geometric progression",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, demonstration",
                                },
                                {
                                    "objective": "Generate the formula for the nth term of a GP and use it to calculate the common ratio, the number of terms, and terms of the GP",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Problem solving, discussion, demonstration, pair work",
                                },
                                {
                                    "objective": "Generate the formula for finding the sum of a GP and calculate the sum",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work",
                                },
                                {
                                    "objective": "Discuss the application of GPs in real-life situations and solve problems involving GP",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving, group work, discussion",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Bottle tops", "type": "equipment"},
                        {"text": "Match sticks", "type": "equipment"},
                        {"text": "Match boxes", "type": "equipment"},
                    ],
                },
                {
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
                },
                {
                    "title": "Subject of the Formulae",
                    "year_level": 4,
                    "description": "Outcome: Solve equations by changing the subject of literal equations and formulae involving powers and roots.",
                    "subtopics": [
                        {
                            "title": "Changing the Subject of Literal Equations",
                            "description": "Identifying the subject of a formula, changing the subject of a formula.",
                            "learning_objectives": [
                                {
                                    "objective": "Identify the subject of a formula",
                                    "cognitive_level": "Knowledge",
                                    "teaching_activity": "Identifying the subject of formula",
                                    "teaching_method": "Discussion, explanation, question and answer, written exercises",
                                },
                                {
                                    "objective": "Change the subject of a literal equation to make a specified variable the subject",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Changing the subject of a formula",
                                    "teaching_method": "Demonstration, written exercises, pair work",
                                },
                            ],
                        },
                        {
                            "title": "Changing the Subject Involving Powers and Roots",
                            "description": "Transposing formulae involving powers and roots to change the subject.",
                            "learning_objectives": [
                                {
                                    "objective": "Identify the subject of a formula involving powers and roots",
                                    "cognitive_level": "Knowledge",
                                    "teaching_activity": "Identifying subject of the formula",
                                    "teaching_method": "Explanation, question and answer",
                                },
                                {
                                    "objective": "Transpose formulae involving powers and roots to make a different variable the subject",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Transposing formula involving powers and roots",
                                    "teaching_method": "Demonstration, written exercises, pair work, group work",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Charts", "type": "equipment"},
                        {"text": "Calculators", "type": "equipment"},
                        {"text": "Strings", "type": "equipment"},
                    ],
                },
                {
                    "title": "Exponential and Logarithmic Equations",
                    "year_level": 4,
                    "description": "Outcome: Work out problems involving exponential and logarithmic equations.",
                    "subtopics": [
                        {
                            "title": "Solving Exponential Equations",
                            "description": "Expressing numbers as powers of given bases, modelling exponential equations, solving exponential equations.",
                            "learning_objectives": [
                                {
                                    "objective": "Express numbers as powers of given bases",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Expressing numbers as powers of given bases",
                                    "teaching_method": "Demonstration, explanation, written exercises, oral exercises",
                                },
                                {
                                    "objective": "Model exponential equations from practical situations",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Modelling exponential equations",
                                    "teaching_method": "Problem solving, discussion, pair work",
                                },
                                {
                                    "objective": "Solve exponential equations using logarithms",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Solving exponential equations",
                                    "teaching_method": "Guided practice, written exercises, pair work",
                                },
                            ],
                        },
                        {
                            "title": "Solving Logarithmic Equations",
                            "description": "Deriving the rules of logarithms, simplifying logarithms of numbers to a given base, formulating logarithmic equations from exponential equations and vice versa, simplifying logarithmic expressions, solving logarithmic equations using rules of logarithms.",
                            "learning_objectives": [
                                {
                                    "objective": "Derive the rules of logarithms (product, quotient and power rules)",
                                    "cognitive_level": "Analysis",
                                    "teaching_activity": "Deriving the rules of logarithms",
                                    "teaching_method": "Discussion, demonstration, explanation, written exercises",
                                },
                                {
                                    "objective": "Simplify logarithms of numbers to a given base",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Simplifying logarithm of numbers to a given base",
                                    "teaching_method": "Written exercises, pair work",
                                },
                                {
                                    "objective": "Formulate logarithmic equations from exponential equations and vice versa",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Formulating logarithmic equations from exponential equations and vice versa",
                                    "teaching_method": "Discussion, guided practice, group work",
                                },
                                {
                                    "objective": "Simplify logarithmic expressions using the laws of logarithms",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Simplifying logarithmic expressions",
                                    "teaching_method": "Written exercises, pair work",
                                },
                                {
                                    "objective": "Solve logarithmic equations using rules of logarithms",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Solving logarithmic equations using rules of logarithms",
                                    "teaching_method": "Problem solving, written exercises, group work",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Charts", "type": "equipment"},
                        {"text": "Calculators", "type": "equipment"},
                        {"text": "Strings", "type": "equipment"},
                    ],
                },
            ],
        },
        # ═══════════════════════════════════════════════════════════════════════
        # CORE ELEMENT 2 — STRUCTURE
        # ═══════════════════════════════════════════════════════════════════════
        {
            "number": 2,
            "name": "Structure",
            "description": "Sets, transformations and vectors across Forms 1–4.",
            "topics": [
                # ── FORM 1 ─────────────────────────────────────────────────
                {
                    "title": "Sets",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Set Notation and Types of Sets",
                            "description": "Describing sets using set notation, identifying universal set, empty set, subsets, etc.",
                            "learning_objectives": [
                                {
                                    "objective": "Use set notation to describe sets of objects",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, examples",
                                },
                                {
                                    "objective": "Identify types of sets: universal, empty, finite, infinite, subsets",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion",
                                },
                            ],
                        },
                        {
                            "title": "Venn Diagrams",
                            "description": "Representing sets and operations using Venn diagrams.",
                            "learning_objectives": [
                                {
                                    "objective": "Draw Venn diagrams to represent sets and their relationships",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                                {
                                    "objective": "Use Venn diagrams to solve problems involving sets",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving",
                                },
                            ],
                        },
                        {
                            "title": "Set Operations",
                            "description": "Union, intersection, complement and number of elements in sets.",
                            "learning_objectives": [
                                {
                                    "objective": "Perform union, intersection and complement operations on sets",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Use the formula n(A ∪ B) = n(A) + n(B) − n(A ∩ B)",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Venn diagram templates", "type": "equipment"},
                    ],
                },
                {
                    "title": "Transformation",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Types of Transformations",
                            "description": "Identifying translations, reflections, rotations and enlargements.",
                            "learning_objectives": [
                                {
                                    "objective": "Identify and describe translations, reflections, rotations and enlargements",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Demonstration, practical activities",
                                },
                            ],
                        },
                        {
                            "title": "Combining Transformations",
                            "description": "Performing two or more transformations in sequence.",
                            "learning_objectives": [
                                {
                                    "objective": "Perform combinations of transformations on shapes",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical activities",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Mirror lines and tracing paper", "type": "equipment"},
                        {"text": "Graph paper", "type": "equipment"},
                    ],
                },
                # ── FORM 3 ─────────────────────────────────────────────────
                # Outcome: Describe sets of numbers including properties of vectors,
                # rotation, reflection, translation and matrices.
                # Assessment standard: solve problems involving sets.
                {
                    "title": "Sets",
                    "year_level": 3,
                    "description": "Describing elements of sets, set operations, algebra of sets and Venn diagrams.",
                    "subtopics": [
                        {
                            "title": "Describing Elements of a Set",
                            "description": "Using set builder notation, identifying universal sets, complements, unions and intersections.",
                            "learning_objectives": [
                                {
                                    "objective": "Describe sets using set builder notation",
                                    "cognitive_level": "Knowledge",
                                    "teaching_activity": "Describing set builder notation",
                                    "teaching_method": "Discussion, explanation",
                                },
                                {
                                    "objective": "Describe a universal set for a given problem context",
                                    "cognitive_level": "Knowledge",
                                    "teaching_activity": "Describing a universal set",
                                    "teaching_method": "Discussion, question and answer",
                                },
                                {
                                    "objective": "Identify elements of a complement of a set",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Identifying elements of a complement of a set",
                                    "teaching_method": "Guided practice, written exercises",
                                },
                                {
                                    "objective": "Identify elements of a union of two or three sets",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Identifying elements of a union of two or three sets",
                                    "teaching_method": "Guided practice, written exercises",
                                },
                                {
                                    "objective": "Identify elements of an intersection of two or three sets",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Identifying elements of an intersection of two or three sets",
                                    "teaching_method": "Guided practice, written exercises",
                                },
                            ],
                        },
                        {
                            "title": "Representing Sets in Venn Diagrams",
                            "description": "Drawing Venn diagrams to illustrate set operations and solving problems using Venn diagrams.",
                            "learning_objectives": [
                                {
                                    "objective": "Draw Venn diagrams to illustrate the union of two or three sets",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Drawing Venn diagrams to illustrate the union of two or three sets",
                                    "teaching_method": "Practical work, peer assessment",
                                },
                                {
                                    "objective": "Draw a Venn diagram to illustrate the intersection of two or three sets",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Drawing a Venn diagram to illustrate the intersection of two or three sets",
                                    "teaching_method": "Practical work, peer assessment",
                                },
                                {
                                    "objective": "Solve problems involving sets using Venn diagrams",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Solving problems involving sets using Venn diagrams",
                                    "teaching_method": "Problem solving, group assessment",
                                },
                            ],
                        },
                        {
                            "title": "Algebra of Sets",
                            "description": "Applying set laws (commutative, associative, distributive, De Morgan's) to simplify expressions.",
                            "learning_objectives": [
                                {
                                    "objective": "Apply the commutative, associative and distributive laws of sets",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice, written exercises",
                                },
                                {
                                    "objective": "Use De Morgan's laws to find complements of union and intersection",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, examples, pair work",
                                },
                            ],
                        },
                        {
                            "title": "Sets and Probability",
                            "description": "Using sets to solve probability problems.",
                            "learning_objectives": [
                                {
                                    "objective": "Use set notation to describe events in probability",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Natural environment", "type": "equipment"},
                        {"text": "Charts of the number line", "type": "equipment"},
                        {"text": "Playing cards", "type": "equipment"},
                        {"text": "Number cards", "type": "equipment"},
                    ],
                },
                {
                    "title": "Transformations",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Enlargement with Negative Scale Factor",
                            "description": "Enlargement with negative scale factors and combined transformations.",
                            "learning_objectives": [
                                {
                                    "objective": "Perform enlargement with negative scale factors",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical activities",
                                },
                                {
                                    "objective": "Describe combined transformations as a single transformation",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Graphical activities",
                                },
                            ],
                        },
                        {
                            "title": "Matrix Transformations",
                            "description": "Representing transformations using column vectors and matrices.",
                            "learning_objectives": [
                                {
                                    "objective": "Represent translations, reflections and rotations using matrices",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Find the matrix representing a combination of transformations",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Graph paper", "type": "equipment"},
                        {"text": "Geometric software", "type": "equipment"},
                    ],
                },
                # ── FORM 4 ─────────────────────────────────────────────────
                {
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
                },
                {
                    "title": "Transformations",
                    "year_level": 4,
                    "description": "Outcome: The students will be able to describe sets of numbers including properties of vectors, rotation, reflection, translation and matrices in terms of quantity, structure, and space.",
                    "subtopics": [
                        {
                            "title": "Rotation",
                            "description": "Drawing rotations using squared paper, describing rotations using directions and angles.",
                            "learning_objectives": [
                                {
                                    "objective": "Draw rotations of simple plane figures about a given point through a given angle clockwise or anticlockwise",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Drawing rotations using squared paper",
                                    "teaching_method": "Discussion, demonstration, explanation, question and answer, written exercises, practical work",
                                },
                                {
                                    "objective": "Describe rotations using directions and angles",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Describing rotations using directions and angles",
                                    "teaching_method": "Discussion, demonstration, explanation, written exercises",
                                },
                            ],
                        },
                        {
                            "title": "Translation",
                            "description": "Describing translation, drawing a translation, writing down coordinates of a translation in column vectors.",
                            "learning_objectives": [
                                {
                                    "objective": "Describe translation of a plane figure",
                                    "cognitive_level": "Knowledge",
                                    "teaching_activity": "Describing translation",
                                    "teaching_method": "Explanation, demonstration, question and answer",
                                },
                                {
                                    "objective": "Draw a translation of a simple plane figure",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Drawing a translation",
                                    "teaching_method": "Practical work, written exercises",
                                },
                                {
                                    "objective": "Write down coordinates of a translation in column vectors",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Writing down coordinates of a translation in column vectors",
                                    "teaching_method": "Written exercises, pair work",
                                },
                                {
                                    "objective": "Translate shapes using column vectors",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Translating shapes using column vectors",
                                    "teaching_method": "Practical work, peer assessment, group assessment",
                                },
                            ],
                        },
                        {
                            "title": "Enlargement",
                            "description": "Defining enlargement, finding the scale factor and centre of enlargement, enlarging shapes by positive whole number and fractional scale factors.",
                            "learning_objectives": [
                                {
                                    "objective": "Define the term 'enlargement'",
                                    "cognitive_level": "Knowledge",
                                    "teaching_activity": "Defining the term 'enlargement'",
                                    "teaching_method": "Discussion, explanation, question and answer",
                                },
                                {
                                    "objective": "Find the scale factor of an enlargement",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Finding the scale factor of an enlargement",
                                    "teaching_method": "Demonstration, written exercises",
                                },
                                {
                                    "objective": "Find the centre of an enlargement",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Finding the centre of an enlargement",
                                    "teaching_method": "Demonstration, practical work, pair work",
                                },
                                {
                                    "objective": "Enlarge shapes by a positive whole number scale factor",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Enlarging shapes by a positive whole number scale factor",
                                    "teaching_method": "Practical work, written exercises, peer assessment",
                                },
                                {
                                    "objective": "Enlarge shapes by a fractional scale factor",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Enlarging shapes by a fractional scale factor",
                                    "teaching_method": "Practical work, written exercises, group assessment",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Charts", "type": "equipment"},
                        {"text": "Mathematical sets", "type": "equipment"},
                        {"text": "Squared paper", "type": "equipment"},
                        {"text": "Graph paper", "type": "equipment"},
                        {"text": "Interlocking blocks", "type": "equipment"},
                        {
                            "text": "Crayons (coloured pencils/chalk)",
                            "type": "equipment",
                        },
                        {"text": "Computers", "type": "equipment"},
                        {"text": "Pictures", "type": "equipment"},
                        {"text": "Magnifying glasses", "type": "equipment"},
                        {"text": "Geoboards", "type": "equipment"},
                    ],
                },
            ],
        },
        # ═══════════════════════════════════════════════════════════════════════
        # CORE ELEMENT 3 — SPACE, SHAPE AND MEASUREMENT
        # ═══════════════════════════════════════════════════════════════════════
        {
            "number": 3,
            "name": "Space, Shape and Measurement",
            "description": "Geometry, trigonometry, mensuration and circle theorems across Forms 1–4.",
            "topics": [
                # ── FORM 1 ─────────────────────────────────────────────────
                {
                    "title": "Lines and Angles",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Types of Angles",
                            "description": "Identifying acute, obtuse, right, reflex, straight and revolution angles.",
                            "learning_objectives": [
                                {
                                    "objective": "Identify and classify angles as acute, obtuse, right, reflex, straight or revolution",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration",
                                },
                            ],
                        },
                        {
                            "title": "Angle Properties",
                            "description": "Angles on a straight line, at a point, vertically opposite, and angles formed by parallel lines and a transversal.",
                            "learning_objectives": [
                                {
                                    "objective": "Calculate angles on a straight line and at a point",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Identify and use properties of corresponding, alternate and co-interior angles",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical activities",
                                },
                            ],
                        },
                        {
                            "title": "Polygons",
                            "description": "Properties of triangles, quadrilaterals and other polygons including interior and exterior angles.",
                            "learning_objectives": [
                                {
                                    "objective": "Calculate the sum of interior angles of a polygon",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Calculate each interior and exterior angle of a regular polygon",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Protractors", "type": "equipment"},
                        {"text": "Rulers and set squares", "type": "equipment"},
                    ],
                },
                {
                    "title": "Triangles and Polygons",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Properties of Triangles",
                            "description": "Classification of triangles and properties of isosceles, equilateral and scalene triangles.",
                            "learning_objectives": [
                                {
                                    "objective": "Classify triangles by sides and angles",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, practical activities",
                                },
                                {
                                    "objective": "Apply properties of triangles to find unknown angles and sides",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Angle Sum Property",
                            "description": "Proving and using the fact that the angle sum of a triangle is 180°.",
                            "learning_objectives": [
                                {
                                    "objective": "Apply the angle sum property of triangles to find unknown angles",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Chalkboard", "type": "equipment"},
                        {"text": "Exercise books", "type": "equipment"},
                    ],
                },
                {
                    "title": "Geometric Constructions",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Construction of Angles and Bisectors",
                            "description": "Constructing given angles, bisecting angles and lines using a compass and ruler.",
                            "learning_objectives": [
                                {
                                    "objective": "Construct angles of a given size using a protractor",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical activities",
                                },
                                {
                                    "objective": "Bisect a given angle using a compass and straightedge",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical activities",
                                },
                                {
                                    "objective": "Construct the perpendicular bisector of a line segment",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical activities",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Compasses", "type": "equipment"},
                        {"text": "Rulers", "type": "equipment"},
                        {"text": "Protractors", "type": "equipment"},
                    ],
                },
                # ── FORM 2 ─────────────────────────────────────────────────
                {
                    "title": "Pythagoras Theorem",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Statement and Proof",
                            "description": "Understanding and proving the Pythagoras theorem.",
                            "learning_objectives": [
                                {
                                    "objective": "State the Pythagoras theorem: a² + b² = c²",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration",
                                },
                                {
                                    "objective": "Use Pythagoras theorem to find an unknown side of a right-angled triangle",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Applications",
                            "description": "Solving real-life problems using the Pythagoras theorem.",
                            "learning_objectives": [
                                {
                                    "objective": "Apply Pythagoras theorem to solve real-life distance and measurement problems",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Chalkboard", "type": "equipment"},
                        {"text": "Exercise books", "type": "equipment"},
                    ],
                },
                {
                    "title": "Congruent Triangles",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Conditions for Congruence",
                            "description": "SSS, SAS, ASA and RHS conditions for triangle congruence.",
                            "learning_objectives": [
                                {
                                    "objective": "State the conditions for triangle congruence: SSS, SAS, ASA, RHS",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, practical activities",
                                },
                                {
                                    "objective": "Prove that two triangles are congruent using the appropriate condition",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Cut-out triangles", "type": "equipment"},
                    ],
                },
                {
                    "title": "Quadrilaterals",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Properties of Quadrilaterals",
                            "description": "Properties of parallelograms, rectangles, rhombuses, squares and trapeziums.",
                            "learning_objectives": [
                                {
                                    "objective": "State and apply the properties of parallelograms, rectangles, rhombuses, squares and trapeziums",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion, practical activities",
                                },
                            ],
                        },
                        {
                            "title": "Angle Properties of Quadrilaterals",
                            "description": "Using angle properties to find unknown angles in quadrilaterals.",
                            "learning_objectives": [
                                {
                                    "objective": "Calculate unknown angles in quadrilaterals using their properties",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Chalkboard", "type": "equipment"},
                        {"text": "Exercise books", "type": "equipment"},
                    ],
                },
                {
                    "title": "Similar Triangles",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Conditions for Similarity",
                            "description": "AAA, SSS and SAS conditions for triangle similarity.",
                            "learning_objectives": [
                                {
                                    "objective": "State the conditions for triangle similarity: AAA, SSS, SAS",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, examples",
                                },
                                {
                                    "objective": "Use properties of similar triangles to find unknown lengths",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Chalkboard", "type": "equipment"},
                        {"text": "Exercise books", "type": "equipment"},
                    ],
                },
                {
                    "title": "Mensuration",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Perimeter and Area",
                            "description": "Calculating perimeter and area of triangles, parallelograms, trapeziums and composite shapes.",
                            "learning_objectives": [
                                {
                                    "objective": "Calculate the perimeter and area of triangles, parallelograms and trapeziums",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Calculate the area of composite shapes",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving",
                                },
                            ],
                        },
                        {
                            "title": "Surface Area and Volume",
                            "description": "Calculating surface area and volume of prisms, cylinders and composite solids.",
                            "learning_objectives": [
                                {
                                    "objective": "Calculate the surface area and volume of prisms and cylinders",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {
                            "text": "3D models of prisms and cylinders",
                            "type": "equipment",
                        },
                        {"text": "Measuring tapes", "type": "equipment"},
                    ],
                },
                {
                    "title": "Geometric Construction",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Construction of Triangles and Quadrilaterals",
                            "description": "Constructing triangles and quadrilaterals given specific conditions using compass and ruler.",
                            "learning_objectives": [
                                {
                                    "objective": "Construct triangles given three sides, two sides and the included angle, or two angles and the included side",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical activities",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Compasses", "type": "equipment"},
                        {"text": "Rulers", "type": "equipment"},
                    ],
                },
                # ── FORM 3 ─────────────────────────────────────────────────
                # Outcome: Solve problems involving shape, size, spaces and
                # relationships between sides and angles of triangles, Pythagoras
                # theorem and trigonometric functions.
                # Assessment standard: solve problems involving circles.
                {
                    "title": "Circle Geometry (Chord Properties)",
                    "year_level": 3,
                    "description": "Identifying parts of a circle, describing chord properties and applying them to solve problems.",
                    "subtopics": [
                        {
                            "title": "Parts of a Circle and Chord Properties",
                            "description": "Identifying parts of a circle (chord, radius, sector, segment, diameter, arc) and describing chord properties theorems.",
                            "learning_objectives": [
                                {
                                    "objective": "Identify parts of a circle: chord, radius, sector, segment, diameter and arc",
                                    "cognitive_level": "Knowledge",
                                    "teaching_activity": "Identifying parts of the circle such as chord, radius, sector, segment, diameter, arc",
                                    "teaching_method": "Discussion, demonstration, explanation",
                                },
                                {
                                    "objective": "Describe chord properties of a circle",
                                    "cognitive_level": "Knowledge",
                                    "teaching_activity": "Describing chord properties of a circle",
                                    "teaching_method": "Discussion, explanation, question and answer",
                                },
                                {
                                    "objective": "Discuss the theorem: the perpendicular to a chord from the centre bisects the chord and its converse",
                                    "cognitive_level": "Knowledge",
                                    "teaching_activity": "Discussing the theorem on perpendicular bisector of a chord",
                                    "teaching_method": "Discussion, demonstration, written exercises",
                                },
                                {
                                    "objective": "Discuss the theorem: equal chords of a circle are equidistant from the centre and its converse",
                                    "cognitive_level": "Knowledge",
                                    "teaching_activity": "Discussing the theorem on equal chords equidistant from the centre",
                                    "teaching_method": "Discussion, demonstration, written exercises",
                                },
                            ],
                        },
                        {
                            "title": "Applying Chord Properties",
                            "description": "Calculating lengths and distances involving chords and solving practical problems.",
                            "learning_objectives": [
                                {
                                    "objective": "Calculate the length of a chord given the radius and distance from the centre",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Calculating the length of the chord given radius and distance from the centre",
                                    "teaching_method": "Guided practice, written exercises, pair work",
                                },
                                {
                                    "objective": "Calculate the distance from the centre given the length of a chord and radius",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Calculating the distance from the centre given the length of a chord and radius",
                                    "teaching_method": "Guided practice, written exercises",
                                },
                                {
                                    "objective": "Calculate the radius given the length of a chord and distance from the centre",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Calculating radius given length of a chord and distance from the centre",
                                    "teaching_method": "Guided practice, written exercises, pair work",
                                },
                                {
                                    "objective": "Solve practical problems involving chords of a circle",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Solving practical problems involving chords",
                                    "teaching_method": "Problem solving, group assessment, practical work",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Charts", "type": "equipment"},
                        {"text": "Mathematical sets", "type": "equipment"},
                        {"text": "Geoboards", "type": "equipment"},
                        {"text": "Models of circles", "type": "equipment"},
                    ],
                },
                {
                    "title": "Circle Geometry (Angle Properties)",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Angle at the Centre and Circumference",
                            "description": "Angle at the centre is twice the angle at the circumference; angles in the same segment are equal.",
                            "learning_objectives": [
                                {
                                    "objective": "Apply the theorem: angle at the centre is twice the angle at the circumference",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Apply the theorem: angles in the same segment are equal",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving",
                                },
                            ],
                        },
                        {
                            "title": "Cyclic Quadrilaterals",
                            "description": "Opposite angles of a cyclic quadrilateral sum to 180°; exterior angle equals the interior opposite angle.",
                            "learning_objectives": [
                                {
                                    "objective": "Apply the property that opposite angles of a cyclic quadrilateral sum to 180°",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Angles in a Semicircle",
                            "description": "The angle subtended by a diameter at the circumference is 90°.",
                            "learning_objectives": [
                                {
                                    "objective": "Apply the theorem: the angle in a semicircle is a right angle",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Chalkboard", "type": "equipment"},
                        {"text": "Exercise books", "type": "equipment"},
                    ],
                },
                {
                    "title": "Trigonometry",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Trigonometric Ratios",
                            "description": "Defining sine, cosine and tangent of acute angles in a right-angled triangle.",
                            "learning_objectives": [
                                {
                                    "objective": "Define sin θ, cos θ and tan θ as ratios of sides in a right-angled triangle",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, examples",
                                },
                                {
                                    "objective": "Calculate unknown sides and angles using trigonometric ratios",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Sine and Cosine Rules",
                            "description": "Applying the sine rule and cosine rule to solve problems involving non-right-angled triangles.",
                            "learning_objectives": [
                                {
                                    "objective": "Apply the sine rule to find unknown sides and angles",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Apply the cosine rule to find unknown sides and angles",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Calculate the area of a triangle using ½ab sin C",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Bearings",
                            "description": "Understanding and calculating true bearings.",
                            "learning_objectives": [
                                {
                                    "objective": "Understand and calculate three-figure bearings",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Scientific calculators", "type": "equipment"},
                    ],
                },
                {
                    "title": "Similarity",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Scale Factor",
                            "description": "Using the scale factor to find lengths, areas and volumes of similar figures.",
                            "learning_objectives": [
                                {
                                    "objective": "Use the scale factor to find unknown lengths in similar figures",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Apply the relationship between scale factor, area ratio and volume ratio",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Problem solving",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Chalkboard", "type": "equipment"},
                        {"text": "Exercise books", "type": "equipment"},
                    ],
                },
                # ── FORM 4 ─────────────────────────────────────────────────
                {
                    "title": "Circle Geometry (Angle Properties)",
                    "year_level": 4,
                    "description": "Outcome: The students will be able to solve problems involving shape, size, spaces relationships between the sides and the angles of triangles, Pythagoras theorem and trigonometric functions.",
                    "subtopics": [
                        {
                            "title": "Angle Properties of a Circle",
                            "description": "Describing angle properties of a circle: angle at the centre is twice the angle at the circumference, angle in a semicircle is a right angle, angles subtended by the same arc/chord are equal.",
                            "learning_objectives": [
                                {
                                    "objective": "Establish that the angle at the centre is twice the angle at the circumference subtended by the same arc",
                                    "cognitive_level": "Knowledge",
                                    "teaching_activity": "Establishing that the angle at the centre is twice the angle at the circumference",
                                    "teaching_method": "Question and answer, demonstration, explanations, discussions, pair and group work",
                                },
                                {
                                    "objective": "Establish that the angle in a semicircle is a right angle",
                                    "cognitive_level": "Knowledge",
                                    "teaching_activity": "Establishing that angle in a semicircle is a right angle",
                                    "teaching_method": "Question and answer, demonstration, explanations, discussions",
                                },
                                {
                                    "objective": "Prove that angles subtended by the same arc/chord are equal",
                                    "cognitive_level": "Knowledge",
                                    "teaching_activity": "Proving that angles subtended by the same arc/chord are equal",
                                    "teaching_method": "Question and answer, demonstration, explanations, discussions, written exercises",
                                },
                            ],
                        },
                        {
                            "title": "Proving Theorems Involving Angle Properties",
                            "description": "Discussing formal proofs of theorems: angle at the centre is twice the angle at the circumference, angle in a semicircle is a right angle, angles subtended by the same arc/chord are equal.",
                            "learning_objectives": [
                                {
                                    "objective": "Give a formal proof that the angle at the centre is twice the angle at the circumference",
                                    "cognitive_level": "Analysis",
                                    "teaching_activity": "Discussing formal proofs of theorems: angle at the centre is twice the angle at the circumference",
                                    "teaching_method": "Discussion, demonstration, explanations, written exercises",
                                },
                                {
                                    "objective": "Give a formal proof that the angle in a semicircle is a right angle",
                                    "cognitive_level": "Analysis",
                                    "teaching_activity": "Discussing formal proofs of theorems: angle in a semicircle is a right angle",
                                    "teaching_method": "Discussion, demonstration, explanations, written exercises",
                                },
                                {
                                    "objective": "Give a formal proof that angles subtended by the same arc/chord are equal",
                                    "cognitive_level": "Analysis",
                                    "teaching_activity": "Discussing formal proofs of theorems: angles subtended by the same arc/chord are equal",
                                    "teaching_method": "Discussion, demonstration, explanations, written exercises",
                                },
                            ],
                        },
                        {
                            "title": "Cyclic Quadrilaterals",
                            "description": "Describing a cyclic quadrilateral, discussing its properties, proving opposite angles are supplementary, exterior angle equals interior opposite angle, showing points are concyclic and showing a quadrilateral is cyclic.",
                            "learning_objectives": [
                                {
                                    "objective": "Describe a cyclic quadrilateral and discuss its properties",
                                    "cognitive_level": "Knowledge",
                                    "teaching_activity": "Describing a cyclic quadrilateral, discussing properties of a cyclic quadrilateral",
                                    "teaching_method": "Discussion, demonstration, explanation, question and answer",
                                },
                                {
                                    "objective": "Prove that opposite angles of a cyclic quadrilateral are supplementary",
                                    "cognitive_level": "Analysis",
                                    "teaching_activity": "Proving that opposite angles of a cyclic quadrilateral are supplementary",
                                    "teaching_method": "Discussion, demonstration, written exercises, peer assessment",
                                },
                                {
                                    "objective": "Prove that the exterior angle of a cyclic quadrilateral is equal to the interior opposite angle",
                                    "cognitive_level": "Analysis",
                                    "teaching_activity": "Proving that the exterior angle of cyclic quadrilateral is equal to the interior opposite angle",
                                    "teaching_method": "Discussion, demonstration, written exercises, peer assessment",
                                },
                                {
                                    "objective": "Show that given points are concyclic",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Showing that points are concyclic",
                                    "teaching_method": "Written exercises, problem solving, group assessment",
                                },
                                {
                                    "objective": "Show that a given quadrilateral is cyclic",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Showing that a given quadrilateral is cyclic",
                                    "teaching_method": "Written exercises, problem solving, practical work",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Charts", "type": "equipment"},
                        {"text": "Mathematical sets", "type": "equipment"},
                        {"text": "Geoboards", "type": "equipment"},
                        {"text": "Models of circles", "type": "equipment"},
                    ],
                },
                {
                    "title": "Trigonometric Ratios",
                    "year_level": 4,
                    "description": "Outcome: Use trigonometric ratios of acute angles to calculate the unknown sides and angles in triangles.",
                    "subtopics": [
                        {
                            "title": "Trigonometric Ratios of Right-Angled Triangles",
                            "description": "Identifying the hypotenuse, adjacent and opposite sides, defining sine, cosine and tangent, finding the three ratios, using a calculator for trigonometry.",
                            "learning_objectives": [
                                {
                                    "objective": "Identify the hypotenuse, adjacent and opposite side of a given angle in a right-angled triangle",
                                    "cognitive_level": "Knowledge",
                                    "teaching_activity": "Identifying the hypotenuse of a triangle, identifying an adjacent and opposite side of a given angle",
                                    "teaching_method": "Discussion, demonstration, explanation, question and answer",
                                },
                                {
                                    "objective": "Define the sine, cosine and tangent of an angle",
                                    "cognitive_level": "Knowledge",
                                    "teaching_activity": "Defining the sine, cosine and tangent of an angle",
                                    "teaching_method": "Explanation, demonstration, question and answer",
                                },
                                {
                                    "objective": "Find the three trigonometric ratios of given angles",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Finding the three ratios of given angles",
                                    "teaching_method": "Written exercises, pair work",
                                },
                                {
                                    "objective": "Use a calculator to work out problems involving trigonometry",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Discussing how to use a calculator to work out problems involving trigonometry",
                                    "teaching_method": "Practical work, demonstration",
                                },
                                {
                                    "objective": "Calculate angles and sides of right-angled triangles using trigonometric ratios",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Finding angles and sides of given triangle",
                                    "teaching_method": "Written exercises, peer assessment, group assessment, practical work",
                                },
                            ],
                        },
                        {
                            "title": "Fractional Trigonometric Ratios of Special Angles",
                            "description": "Deriving the fractional trigonometric ratios of 30°, 45°, 60° and 90°, solving problems involving fractional trigonometric ratios without using a calculator.",
                            "learning_objectives": [
                                {
                                    "objective": "Derive the fractional trigonometric ratios of 30°, 45°, 60° and 90°",
                                    "cognitive_level": "Analysis",
                                    "teaching_activity": "Deriving the fractional trigonometric ratios of 30°, 45°, 60° and 90°",
                                    "teaching_method": "Discussion, demonstration, explanation, written exercises",
                                },
                                {
                                    "objective": "Solve problems involving fractional trigonometric ratios without using a calculator",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Solving problems involving fractional trigonometric ratios without using a calculator",
                                    "teaching_method": "Written exercises, pair work, group assessment",
                                },
                            ],
                        },
                        {
                            "title": "Practical Problems Involving Trigonometry",
                            "description": "Finding the angle of elevation and depression, calculating the bearing of a point relative to a given point using trigonometric ratios.",
                            "learning_objectives": [
                                {
                                    "objective": "Find the angle of elevation and depression in practical situations",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Finding the angle of elevation and depression",
                                    "teaching_method": "Practical work, problem solving, demonstration",
                                },
                                {
                                    "objective": "Calculate the bearing of a point relative to a given point using trigonometric ratios",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Calculating the bearing of a point relative to a given point using trigonometric ratios",
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
                },
                {
                    "title": "Tangents to Circles",
                    "year_level": 4,
                    "description": "Outcome: Solve problems involving tangents to circles.",
                    "subtopics": [
                        {
                            "title": "Properties of Tangents to Circles",
                            "description": "Defining a tangent, establishing tangent-radius relationship, tangents from an external point, formal proofs.",
                            "learning_objectives": [
                                {
                                    "objective": "Define a tangent to a circle",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration, explanation, question and answer",
                                },
                                {
                                    "objective": "Establish the relationship between a tangent and the radius of a circle at the point of contact",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration, explanation, written exercises, pair work",
                                },
                                {
                                    "objective": "Establish that tangents from an external point are equal in length",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration, explanation, written exercises, peer assessment",
                                },
                                {
                                    "objective": "Give a formal proof that tangents from an external point are equal in length",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, demonstration, explanation, written exercises, pair work",
                                },
                                {
                                    "objective": "Establish that the line joining an external point to the centre of a circle bisects the angle between the tangents",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration, explanation, written exercises, practical work",
                                },
                                {
                                    "objective": "Give a formal proof that the line joining an external point to the centre of a circle bisects the angle between the tangents",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, demonstration, explanation, written exercises, pair work",
                                },
                                {
                                    "objective": "Establish that the angle between a chord and a tangent is equal to the angle subtended by the chord in the alternate segment",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration, explanation, written exercises, peer assessment, group assessment",
                                },
                                {
                                    "objective": "Give a formal proof of the alternate segment theorem",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, demonstration, explanation, written exercises, practical work",
                                },
                            ],
                        },
                        {
                            "title": "Applying Tangent Properties",
                            "description": "Solving problems involving tangents to circles, using properties to prove sides or angles are equal.",
                            "learning_objectives": [
                                {
                                    "objective": "Solve problems involving tangents to circles",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, peer assessment, group assessment, pair work",
                                },
                                {
                                    "objective": "Use properties of tangents to circles to prove that sides or angles are equal",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, demonstration, written exercises, practical work",
                                },
                            ],
                        },
                        {
                            "title": "Construction of Tangents",
                            "description": "Constructing a tangent to a circle and tangents from an external point to a circle.",
                            "learning_objectives": [
                                {
                                    "objective": "Construct a tangent to a circle at a given point",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, demonstration, pair work",
                                },
                                {
                                    "objective": "Construct tangents from an external point to a circle",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, demonstration, written exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Charts", "type": "equipment"},
                        {"text": "Mathematical sets", "type": "equipment"},
                        {"text": "Geoboards", "type": "equipment"},
                    ],
                },
                {
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
                },
                {
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
                        },
                        {
                            "title": "Arc Length and Sector Area",
                            "description": "Calculating arc length and area of a sector of a circle.",
                            "learning_objectives": [
                                {
                                    "objective": "Calculate the arc length of a sector",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Calculate the area of a sector of a circle",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
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
                        {
                            "text": "Models of cuboids, cubes, cones and prisms",
                            "type": "equipment",
                        },
                        {"text": "Calculators", "type": "equipment"},
                    ],
                },
                {
                    "title": "Similarity",
                    "year_level": 4,
                    "description": "Outcome: The students will be able to solve problems involving shape, size, spaces relationships between the sides and the angles of triangles, Pythagoras theorem and trigonometric functions.",
                    "subtopics": [
                        {
                            "title": "Similarity — Areas of Similar Figures",
                            "description": "Applying the ratio of areas to calculate areas and sides of similar figures.",
                            "learning_objectives": [
                                {
                                    "objective": "Identify a scale factor between two similar figures",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration, explanation, question and answer",
                                },
                                {
                                    "objective": "Find the area factor from a given linear scale factor",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, explanation, written exercises",
                                },
                                {
                                    "objective": "Calculate ratios of areas of similar solids",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, peer assessment, group assessment",
                                },
                                {
                                    "objective": "Calculate areas of similar shapes using the area ratio",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, written exercises",
                                },
                                {
                                    "objective": "Find the lengths of sides of similar shapes using the area factor",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, problem solving, practical work",
                                },
                            ],
                        },
                        {
                            "title": "Similarity — Volumes of Similar Solids",
                            "description": "Applying the ratio of volumes to calculate volumes and sides of similar solids.",
                            "learning_objectives": [
                                {
                                    "objective": "Find the volume scale factor from a given linear scale factor",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, explanation, written exercises",
                                },
                                {
                                    "objective": "Calculate ratios of volumes of similar solids",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, peer assessment, group assessment",
                                },
                                {
                                    "objective": "Calculate volumes of similar solids using the volume ratio",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, written exercises",
                                },
                                {
                                    "objective": "Find the lengths of sides of similar shapes using the volume factor",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, problem solving, practical work",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Charts", "type": "equipment"},
                        {"text": "Mathematical sets", "type": "equipment"},
                        {"text": "Strings", "type": "equipment"},
                        {"text": "Pieces of paper", "type": "equipment"},
                        {"text": "Models of similar shapes", "type": "equipment"},
                    ],
                },
            ],
        },
        # ═══════════════════════════════════════════════════════════════════════
        # CORE ELEMENT 4 — PATTERN, RELATIONS, FUNCTIONS AND CHANGE
        # ═══════════════════════════════════════════════════════════════════════
        {
            "number": 4,
            "name": "Pattern, Relations, Functions and Change",
            "description": "Coordinate geometry, graphs, functions, variations, inequalities and programming across Forms 1–4.",
            "topics": [
                # ── FORM 1 ─────────────────────────────────────────────────
                {
                    "title": "Coordinate Geometry",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "The Cartesian Plane",
                            "description": "Plotting points on the Cartesian plane and identifying quadrants.",
                            "learning_objectives": [
                                {
                                    "objective": "Plot points on the Cartesian plane and identify the four quadrants",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                            ],
                        },
                        {
                            "title": "Linear Graphs",
                            "description": "Drawing and interpreting linear graphs from equations of the form y = mx + c.",
                            "learning_objectives": [
                                {
                                    "objective": "Draw linear graphs from equations of the form y = mx + c",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                                {
                                    "objective": "Identify the gradient and y-intercept from a linear equation",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Find the equation of a straight line given two points",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Graph paper", "type": "equipment"},
                        {"text": "Rulers", "type": "equipment"},
                    ],
                },
                # ── FORM 2 ─────────────────────────────────────────────────
                {
                    "title": "Graphs: Simultaneous Equations",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Solving Simultaneous Equations Graphically",
                            "description": "Using graphs to solve pairs of simultaneous linear equations.",
                            "learning_objectives": [
                                {
                                    "objective": "Solve simultaneous equations graphically by finding the point of intersection",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Graph paper", "type": "equipment"},
                    ],
                },
                {
                    "title": "Inequalities",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Linear Inequalities",
                            "description": "Solving and representing linear inequalities on a number line.",
                            "learning_objectives": [
                                {
                                    "objective": "Solve linear inequalities in one variable",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Represent the solution of a linear inequality on a number line",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Number line charts", "type": "equipment"},
                    ],
                },
                {
                    "title": "Distance–Time Graphs",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Interpreting Distance-Time Graphs",
                            "description": "Reading and interpreting distance-time graphs including finding speed from gradient.",
                            "learning_objectives": [
                                {
                                    "objective": "Interpret distance-time graphs to determine speed and total distance",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Graphical activities",
                                },
                                {
                                    "objective": "Draw distance-time graphs from given information",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Graph paper", "type": "equipment"},
                    ],
                },
                # ── FORM 3 ─────────────────────────────────────────────────
                {
                    "title": "Mapping and Functions",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Concept of a Function",
                            "description": "Understanding functions as mappings from a domain to a codomain.",
                            "learning_objectives": [
                                {
                                    "objective": "Define a function as a special type of mapping",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, examples",
                                },
                                {
                                    "objective": "Identify the domain, codomain and range of a function",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion",
                                },
                            ],
                        },
                        {
                            "title": "Function Notation",
                            "description": "Using f(x) notation to represent and evaluate functions.",
                            "learning_objectives": [
                                {
                                    "objective": "Use function notation f(x) to represent and evaluate functions",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Types of Functions",
                            "description": "One-to-one, many-to-one, into and onto functions.",
                            "learning_objectives": [
                                {
                                    "objective": "Classify functions as one-to-one or many-to-one",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, examples",
                                },
                                {
                                    "objective": "Determine whether a given function is one-to-one",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Chalkboard", "type": "equipment"},
                        {"text": "Exercise books", "type": "equipment"},
                    ],
                },
                {
                    "title": "Coordinate Geometry",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Equation of a Line",
                            "description": "Finding the equation of a line given gradient and a point, or two points.",
                            "learning_objectives": [
                                {
                                    "objective": "Find the equation of a line using the point-gradient formula",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Find the equation of a line given two points",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Parallel and Perpendicular Lines",
                            "description": "Using gradients to identify and construct parallel and perpendicular lines.",
                            "learning_objectives": [
                                {
                                    "objective": "Determine whether two lines are parallel or perpendicular from their equations",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Graph paper", "type": "equipment"},
                    ],
                },
                {
                    "title": "Variations",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Direct and Inverse Variation",
                            "description": "Expressing direct and inverse variation as equations and solving problems.",
                            "learning_objectives": [
                                {
                                    "objective": "Write equations for direct variation y = kx and inverse variation y = k/x",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Solve problems involving joint variation",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Chalkboard", "type": "equipment"},
                        {"text": "Exercise books", "type": "equipment"},
                    ],
                },
                {
                    "title": "Inequalities",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Linear Inequalities in Two Variables",
                            "description": "Solving and graphing linear inequalities in two variables.",
                            "learning_objectives": [
                                {
                                    "objective": "Graph linear inequalities in two variables on the Cartesian plane",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Graph paper", "type": "equipment"},
                    ],
                },
                {
                    "title": "Graphs of Quadratic Functions",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Sketching Parabolas",
                            "description": "Sketching graphs of quadratic functions y = ax² + bx + c and identifying key features.",
                            "learning_objectives": [
                                {
                                    "objective": "Sketch parabolas and identify the vertex, axis of symmetry and intercepts",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Graphical activities",
                                },
                                {
                                    "objective": "Determine the maximum or minimum value of a quadratic function",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Graph paper", "type": "equipment"},
                    ],
                },
                # ── FORM 4 ─────────────────────────────────────────────────
                {
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
                },
                {
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
                },
                {
                    "title": "Mapping and Functions",
                    "year_level": 4,
                    "description": "Outcome: The students will be able to demonstrate an understanding of graphs, charts, relations and functions and use them effectively in different contexts.",
                    "subtopics": [
                        {
                            "title": "Defining Mapping and Functions",
                            "description": "Defining mapping and functions, identifying functions, writing functions in different forms (notation of functions), drawing arrow diagrams.",
                            "learning_objectives": [
                                {
                                    "objective": "Define mapping and distinguish between a relation and a function",
                                    "cognitive_level": "Knowledge",
                                    "teaching_activity": "Defining mapping and functions",
                                    "teaching_method": "Question and answer, demonstration, explanations, discussions",
                                },
                                {
                                    "objective": "Identify functions from given mappings, tables, graphs and arrow diagrams",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Identifying functions",
                                    "teaching_method": "Pair and group work, written exercises",
                                },
                                {
                                    "objective": "Write functions in different forms of notation (e.g. f(x) notation, set notation, mapping notation)",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Writing functions in different forms (ie notation of functions)",
                                    "teaching_method": "Demonstration, explanations, written exercises",
                                },
                                {
                                    "objective": "Draw arrow diagrams to represent functions",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Drawing arrow diagrams",
                                    "teaching_method": "Practical work, pair work",
                                },
                            ],
                        },
                        {
                            "title": "Range and Domain of Functions",
                            "description": "Finding the range given the domain, finding the domain given the range, and solving real-life problems involving functions (causal-effect problems).",
                            "learning_objectives": [
                                {
                                    "objective": "Find the range of a function given its domain",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Finding the range given the domain",
                                    "teaching_method": "Written exercises, problem solving",
                                },
                                {
                                    "objective": "Find the domain of a function given its range",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Finding the domain given the range",
                                    "teaching_method": "Written exercises, problem solving",
                                },
                                {
                                    "objective": "Solve real-life problems involving functions (causal-effect problems)",
                                    "cognitive_level": "Application",
                                    "teaching_activity": "Solving real life problems involving functions (causal-effect problems)",
                                    "teaching_method": "Problem solving, discussion, pair and group work",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Chart paper", "type": "equipment"},
                        {
                            "text": "Input and output machine models",
                            "type": "equipment",
                        },
                    ],
                },
                {
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
                },
                {
                    "title": "Coordinate Geometry",
                    "year_level": 4,
                    "description": "Outcome: The students will be able to demonstrate an understanding of graphs, charts, relations and functions and use them effectively in different contexts.",
                    "subtopics": [
                        {
                            "title": "Distance Between Two Points",
                            "description": "Calculating the distance between two points on a straight line using Pythagoras' theorem.",
                            "learning_objectives": [
                                {
                                    "objective": "Calculate the distance between two points on a straight line using Pythagoras' theorem",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion, demonstration, explanation, question and answer, written exercises, pair work",
                                },
                            ],
                        },
                        {
                            "title": "Equation of a Straight Line",
                            "description": "Writing the equation of a straight line in the form y = mx + c, relating the gradient to the tangent of an angle, using the relationship to find the gradient of a line, formulating the equation of a line with a given gradient through a given point.",
                            "learning_objectives": [
                                {
                                    "objective": "Write the equation of a straight line in the form y = mx + c",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, explanation, written exercises",
                                },
                                {
                                    "objective": "Relate the gradient to the tangent of an angle of inclination",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration, explanation",
                                },
                                {
                                    "objective": "Find the gradient of a line given two points or its equation",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, peer assessment, group assessment",
                                },
                                {
                                    "objective": "Formulate the equation of a line with a given gradient through a given point",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work, practical work",
                                },
                                {
                                    "objective": "Find the equation of a line passing through two given points",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, peer assessment, group assessment",
                                },
                                {
                                    "objective": "Find the equation of a line from a graph",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Graphical activities, pair work",
                                },
                            ],
                        },
                        {
                            "title": "Parallel Lines",
                            "description": "Describing the condition for two lines to be parallel, finding equations of parallel lines.",
                            "learning_objectives": [
                                {
                                    "objective": "Explain the relationship between gradients of parallel lines",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration, explanation",
                                },
                                {
                                    "objective": "Calculate gradients of parallel lines",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work",
                                },
                                {
                                    "objective": "Find the equation of a line through a given point and parallel to a given line",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, peer assessment, group assessment",
                                },
                            ],
                        },
                        {
                            "title": "Mid-Point of a Line Segment",
                            "description": "Deriving and applying the formula for the mid-point of a line segment.",
                            "learning_objectives": [
                                {
                                    "objective": "Derive the formula for the mid-point of a line segment",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration, explanation",
                                },
                                {
                                    "objective": "Find the mid-point of a line segment",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Graph paper", "type": "equipment"},
                        {"text": "Graph boards", "type": "equipment"},
                    ],
                },
                {
                    "title": "Variations",
                    "year_level": 4,
                    "description": "Outcome: Work out problems involving variations.",
                    "subtopics": [
                        {
                            "title": "Direct Variation",
                            "description": "Modelling direct variation, deriving general equations involving direct variation, finding constant of variation, developing a table of values, presenting direct variation graphically, solving direct variation problems.",
                            "learning_objectives": [
                                {
                                    "objective": "Model direct variation situations and derive the general equation y = kx",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving, discussion, demonstration",
                                },
                                {
                                    "objective": "Find the constant of variation in a direct variation relationship",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercise, group work, individual exercises",
                                },
                                {
                                    "objective": "Develop a table of values for a direct variation relationship",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, oral questions",
                                },
                                {
                                    "objective": "Present a direct variation relationship graphically",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, graphical activities",
                                },
                                {
                                    "objective": "Solve direct variation problems in real-life contexts",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving, discussion, written exercises",
                                },
                            ],
                        },
                        {
                            "title": "Inverse Variation",
                            "description": "Modelling inverse variation, deriving general equations involving inverse variation, finding constant of variation, presenting inverse variation graphically, solving inverse variation problems.",
                            "learning_objectives": [
                                {
                                    "objective": "Model inverse variation situations and derive the general equation y = k/x",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, explanation, problem solving",
                                },
                                {
                                    "objective": "Find the constant of variation in an inverse variation relationship",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, group work",
                                },
                                {
                                    "objective": "Present an inverse variation relationship graphically",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, graphical activities",
                                },
                                {
                                    "objective": "Solve inverse variation problems in real-life contexts",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving, written exercises, observation",
                                },
                            ],
                        },
                        {
                            "title": "Joint Variation",
                            "description": "Deriving general equations involving joint variation, finding constant of variation, solving joint variation problems.",
                            "learning_objectives": [
                                {
                                    "objective": "Derive general equations involving joint variation",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, explanation, question and answer",
                                },
                                {
                                    "objective": "Find the constant of variation in a joint variation relationship",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, problem solving",
                                },
                                {
                                    "objective": "Solve joint variation problems in real-life contexts",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Group work, written exercises, projects",
                                },
                            ],
                        },
                        {
                            "title": "Partial Variation",
                            "description": "Formulating general equations involving partial variation, finding constants of variation, presenting partial variation graphically, solving partial variation problems.",
                            "learning_objectives": [
                                {
                                    "objective": "Formulate general equations involving partial variation",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion, demonstration, question and answer, explanation",
                                },
                                {
                                    "objective": "Find the constants of variation in a partial variation relationship",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving, group work, written exercises",
                                },
                                {
                                    "objective": "Present a partial variation relationship graphically",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, oral exercises",
                                },
                                {
                                    "objective": "Solve partial variation problems in real-life contexts",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving, tests, written exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Calculators", "type": "equipment"},
                        {"text": "Graph paper", "type": "equipment"},
                        {"text": "Graph boards", "type": "equipment"},
                        {"text": "Rulers", "type": "equipment"},
                        {"text": "Mathematical instruments", "type": "equipment"},
                        {"text": "Checklists", "type": "equipment"},
                        {"text": "Charts", "type": "equipment"},
                        {"text": "Computers", "type": "equipment"},
                    ],
                },
                {
                    "title": "Inequalities",
                    "year_level": 4,
                    "description": "Outcome: Sketch the graphs of the regions described by the inequalities on the xy-plane.",
                    "subtopics": [
                        {
                            "title": "Graphical Representation of Inequalities",
                            "description": "Sketching graphs to show regions represented by single linear inequalities on the xy-plane.",
                            "learning_objectives": [
                                {
                                    "objective": "Sketch graphs to show the region represented by inequalities of the form x > b, x >= b, y < b, y <= b",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, group work, written exercises",
                                },
                                {
                                    "objective": "Sketch graphs to show the region represented by inequalities of the form x > b or x < b, x >= b or x <= b, y > b or y < b, y >= b or y <= b",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion, pair work, individual work",
                                },
                            ],
                        },
                        {
                            "title": "Simultaneous Linear Inequalities",
                            "description": "Illustrating simultaneous linear inequalities graphically and finding the solution represented by them.",
                            "learning_objectives": [
                                {
                                    "objective": "Sketch graphs to show the region represented by simultaneous inequalities of the form x > b and x < c, x >= b and x <= c, y > b and y < c, y >= b and y <= c",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, group work, written exercises",
                                },
                                {
                                    "objective": "Write down an inequality that describes a given shaded region",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Pair work, question and answer",
                                },
                                {
                                    "objective": "Find inequalities in two variables that describe a region",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion, written exercises, pair work",
                                },
                                {
                                    "objective": "Sketch linear graphs in two variables to define regions",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, individual work",
                                },
                            ],
                        },
                        {
                            "title": "Inequalities in Two Variables",
                            "description": "Presenting inequalities in the form ax + by < c, ax + by <= c, ax + by > c, ax + by >= c and showing regions represented by simultaneous inequalities in two variables.",
                            "learning_objectives": [
                                {
                                    "objective": "Show the region represented by inequalities of the form ax + by < c, ax + by <= c, ax + by > c, ax + by >= c",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, group work, written exercises",
                                },
                                {
                                    "objective": "Show a region represented by simultaneous inequalities in two variables",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Discussion, pair work, individual work",
                                },
                                {
                                    "objective": "Write down two inequalities that describe a given region",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Question and answer, pair work",
                                },
                                {
                                    "objective": "Find the solution represented by simultaneous linear inequalities",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Problem solving, written exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Calculators", "type": "equipment"},
                        {"text": "Rulers", "type": "equipment"},
                        {"text": "Textbooks", "type": "equipment"},
                        {"text": "Computers", "type": "equipment"},
                        {"text": "Chart paper", "type": "equipment"},
                        {"text": "Graph paper", "type": "equipment"},
                        {"text": "Graph boards", "type": "equipment"},
                        {"text": "Markers", "type": "equipment"},
                    ],
                },
                {
                    "title": "Graphs of Quadratic Functions",
                    "year_level": 4,
                    "description": "Outcome: Analyse graphs of quadratic functions.",
                    "subtopics": [
                        {
                            "title": "Drawing Graphs of Quadratic Functions",
                            "description": "Constructing tables of values and drawing graphs of quadratic functions.",
                            "learning_objectives": [
                                {
                                    "objective": "Construct tables of values for quadratic functions",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, written exercises, pair work",
                                },
                                {
                                    "objective": "Draw graphs of quadratic functions from tables of values",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, graphical activities",
                                },
                            ],
                        },
                        {
                            "title": "Interpreting Graphs of Quadratic Functions",
                            "description": "Describing the effect of a, b and c on the nature of the graph of y = ax² + bx + c, finding maximum and minimum values, finding the equation of the line of symmetry.",
                            "learning_objectives": [
                                {
                                    "objective": "Describe the effect of a, b and c on the nature of the graph of y = ax² + bx + c",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, explanation, demonstration",
                                },
                                {
                                    "objective": "Find the maximum and minimum values of a quadratic function",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work, group work",
                                },
                                {
                                    "objective": "Find the equation of the line of symmetry of a quadratic graph",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, written exercises, problem solving",
                                },
                            ],
                        },
                        {
                            "title": "Solving Quadratic Equations Graphically",
                            "description": "Finding points of intersection of a quadratic graph and a horizontal line, solving quadratic equations graphically.",
                            "learning_objectives": [
                                {
                                    "objective": "Find points of intersection of a quadratic graph and any horizontal line",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Graphical activities, explanation, discussion",
                                },
                                {
                                    "objective": "Solve quadratic equations graphically",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving, written exercises, tests",
                                },
                            ],
                        },
                        {
                            "title": "Simultaneous Linear and Quadratic Equations Graphically",
                            "description": "Drawing linear and quadratic graphs on the same axes and solving simultaneous equations graphically.",
                            "learning_objectives": [
                                {
                                    "objective": "Draw linear and quadratic graphs on the same axes",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, demonstration",
                                },
                                {
                                    "objective": "Solve simultaneous linear and quadratic equations graphically",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving, written exercises, projects",
                                },
                            ],
                        },
                        {
                            "title": "Formulating Quadratic Equations from Graphs",
                            "description": "Identifying x and y intercepts and formulating quadratic equations from graphs that cut the x-axis.",
                            "learning_objectives": [
                                {
                                    "objective": "Identify x-intercepts and y-intercepts from a quadratic graph",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, explanation, question and answer",
                                },
                                {
                                    "objective": "Formulate quadratic equations from graphs that cut the x-axis",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving, written exercises, tests",
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
                        {"text": "Observation checklists", "type": "equipment"},
                        {"text": "Graphic calculators", "type": "equipment"},
                        {"text": "Computers", "type": "equipment"},
                    ],
                },
            ],
        },
        # ═══════════════════════════════════════════════════════════════════════
        # CORE ELEMENT 5 — STATISTICS
        # ═══════════════════════════════════════════════════════════════════════
        {
            "number": 5,
            "name": "Statistics",
            "description": "Data handling, probability and statistical analysis across Forms 1–4.",
            "topics": [
                # ── FORM 1 ─────────────────────────────────────────────────
                {
                    "title": "Statistics",
                    "year_level": 1,
                    "subtopics": [
                        {
                            "title": "Data Collection and Organisation",
                            "description": "Collecting, recording and organising data using tables, tally charts and frequency tables.",
                            "learning_objectives": [
                                {
                                    "objective": "Collect and organise data using frequency tables and tally charts",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical activities",
                                },
                            ],
                        },
                        {
                            "title": "Representation of Data",
                            "description": "Representing data using bar charts, pictograms, pie charts and line graphs.",
                            "learning_objectives": [
                                {
                                    "objective": "Draw and interpret bar charts, pictograms and line graphs",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                                {
                                    "objective": "Construct and interpret pie charts",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                            ],
                        },
                        {
                            "title": "Measures of Central Tendency",
                            "description": "Calculating the mean, median and mode of a set of data.",
                            "learning_objectives": [
                                {
                                    "objective": "Calculate the mean, median and mode of a set of data",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Determine which measure of central tendency best represents a data set",
                                    "cognitive_level": "Evaluation",
                                    "teaching_method": "Discussion",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Graph paper", "type": "equipment"},
                        {"text": "Rulers", "type": "equipment"},
                    ],
                },
                # ── FORM 2 ─────────────────────────────────────────────────
                {
                    "title": "Probability",
                    "year_level": 2,
                    "subtopics": [
                        {
                            "title": "Basic Probability",
                            "description": "Understanding probability as a measure of likelihood from 0 to 1.",
                            "learning_objectives": [
                                {
                                    "objective": "Define probability as the likelihood of an event occurring",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, examples",
                                },
                                {
                                    "objective": "Calculate the probability of a single event",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Experimental Probability",
                            "description": "Estimating probability from experiments and relative frequency.",
                            "learning_objectives": [
                                {
                                    "objective": "Estimate probability using relative frequency from experiments",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical activities",
                                },
                            ],
                        },
                        {
                            "title": "Tree Diagrams",
                            "description": "Using tree diagrams to list outcomes and calculate combined probabilities.",
                            "learning_objectives": [
                                {
                                    "objective": "Draw tree diagrams to list all possible outcomes",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Calculate combined probabilities using tree diagrams",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Coins and dice", "type": "equipment"},
                    ],
                },
                # ── FORM 3 ─────────────────────────────────────────────────
                {
                    "title": "Statistics",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Measures of Dispersion",
                            "description": "Calculating the range, interquartile range and standard deviation.",
                            "learning_objectives": [
                                {
                                    "objective": "Calculate the range and interquartile range of a data set",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Calculate the standard deviation of a data set",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Cumulative Frequency and Ogives",
                            "description": "Constructing cumulative frequency tables and ogive curves.",
                            "learning_objectives": [
                                {
                                    "objective": "Construct a cumulative frequency table from grouped data",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                                {
                                    "objective": "Draw an ogive curve and use it to estimate the median and quartiles",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                            ],
                        },
                        {
                            "title": "Histograms",
                            "description": "Constructing and interpreting histograms for grouped continuous data.",
                            "learning_objectives": [
                                {
                                    "objective": "Construct histograms for grouped continuous data",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                                {
                                    "objective": "Interpret histograms to estimate frequencies and medians",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Graph paper", "type": "equipment"},
                        {"text": "Rulers", "type": "equipment"},
                    ],
                },
                # ── FORM 4 ─────────────────────────────────────────────────
                {
                    "title": "Statistics",
                    "year_level": 4,
                    "description": "Outcome: Demonstrate an understanding of basic concepts of data handling procedures and apply them in everyday life.",
                    "subtopics": [
                        {
                            "title": "Organising Data",
                            "description": "Classifying grouped data, forming class intervals, determining class boundaries, finding mid-points, finding frequencies of grouped and non-grouped data.",
                            "learning_objectives": [
                                {
                                    "objective": "Classify grouped data into appropriate categories",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, projects, group work, demonstration",
                                },
                                {
                                    "objective": "Form class intervals for a given data set",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, question and answer",
                                },
                                {
                                    "objective": "Determine class boundaries and find mid-points of class intervals",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, written exercises, group assessment",
                                },
                                {
                                    "objective": "Find frequencies of grouped and non-grouped data",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, written exercises, observation",
                                },
                            ],
                        },
                        {
                            "title": "Presenting Data in Charts and Tables",
                            "description": "Presenting data in the form of frequency tables, histograms, pie charts and frequency polygons.",
                            "learning_objectives": [
                                {
                                    "objective": "Present data in the form of frequency tables",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, projects, group work, demonstration",
                                },
                                {
                                    "objective": "Draw and interpret histograms from grouped data",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, written exercises, question and answer",
                                },
                                {
                                    "objective": "Construct and interpret pie charts",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, group assessment, observation",
                                },
                                {
                                    "objective": "Draw and interpret frequency polygons",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, explanation, group assessment",
                                },
                            ],
                        },
                        {
                            "title": "Measures of Central Tendency and Spread",
                            "description": "Calculating the median of ungrouped data, mean of grouped data, mode of grouped data, and range of data.",
                            "learning_objectives": [
                                {
                                    "objective": "Calculate the median of ungrouped data",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, question and answer",
                                },
                                {
                                    "objective": "Calculate the mean of grouped data",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical work, written exercises, group assessment",
                                },
                                {
                                    "objective": "Find the mode of grouped data",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Demonstration, written exercises, peer assessment",
                                },
                                {
                                    "objective": "Calculate the range of a data set",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, pair work",
                                },
                            ],
                        },
                        {
                            "title": "Interpreting Data",
                            "description": "Interpreting data using measures of central tendency and spread.",
                            "learning_objectives": [
                                {
                                    "objective": "Interpret data using measures of central tendency and spread",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, group work, projects",
                                },
                            ],
                        },
                        {
                            "title": "Measures of Spread",
                            "description": "Discussing variance, calculating variance, discussing standard deviation, calculating standard deviation of ungrouped data.",
                            "learning_objectives": [
                                {
                                    "objective": "Discuss variance as a measure of spread",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration, explanation",
                                },
                                {
                                    "objective": "Calculate variance of ungrouped data",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, practical work, group assessment",
                                },
                                {
                                    "objective": "Discuss standard deviation as a measure of spread",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, demonstration, question and answer",
                                },
                                {
                                    "objective": "Calculate standard deviation of ungrouped data",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Written exercises, practical work, peer assessment",
                                },
                            ],
                        },
                        {
                            "title": "Interpreting Data Using Measures of Spread",
                            "description": "Interpreting data using variance and standard deviation.",
                            "learning_objectives": [
                                {
                                    "objective": "Interpret data using variance",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, group work, observation, explanation",
                                },
                                {
                                    "objective": "Interpret data using standard deviation",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, projects, written exercises, group assessment",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Charts", "type": "equipment"},
                        {"text": "Rulers", "type": "equipment"},
                        {"text": "Mathematical instruments", "type": "equipment"},
                        {"text": "Calculators", "type": "equipment"},
                        {"text": "Graph paper", "type": "equipment"},
                    ],
                },
                {
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
                },
            ],
        },
    ],
}


async def seed_math_syllabus():
    """Seed the Malawi Mathematics syllabus. Idempotent — skips if already seeded."""
    async with async_session() as db:
        existing = await db.execute(
            select(SyllabusSubject).where(SyllabusSubject.slug == "mathematics")
        )
        if existing.scalar_one_or_none():
            return

        data = MATH_SYLLABUS
        subject_data = data["subject"]
        subject = SyllabusSubject(
            name=subject_data["name"],
            slug=subject_data["slug"],
            description=subject_data.get("description", ""),
            icon=subject_data.get("icon", "calculate_rounded"),
            color=subject_data.get("color", "#8B5CF6"),
        )
        db.add(subject)
        await db.flush()

        version_data = data["version"]
        version = SyllabusVersion(
            subject_id=subject.id,
            version_name=version_data["version_name"],
            year_effective=version_data.get("year_effective"),
            examination_board=version_data.get("examination_board"),
            description=version_data.get("description", ""),
            is_current=True,
        )
        db.add(version)
        await db.flush()

        for idx, ce_data in enumerate(data.get("core_elements", [])):
            ce = SyllabusCoreElement(
                version_id=version.id,
                number=ce_data["number"],
                name=ce_data["name"],
                description=ce_data.get("description", ""),
                order_index=idx,
            )
            db.add(ce)
            await db.flush()

            for t_idx, topic_data in enumerate(ce_data.get("topics", [])):
                topic = SyllabusTopic(
                    core_element_id=ce.id,
                    title=topic_data["title"],
                    description=topic_data.get("description", ""),
                    year_level=topic_data.get("year_level", 1),
                    order_index=t_idx,
                )
                db.add(topic)
                await db.flush()

                for sub_data in topic_data.get("subtopics", []):
                    sub = SyllabusSubtopic(
                        topic_id=topic.id,
                        title=sub_data["title"],
                        description=sub_data.get("description", ""),
                        order_index=0,
                    )
                    db.add(sub)
                    await db.flush()

                    for lo_data in sub_data.get("learning_objectives", []):
                        lo = SyllabusLearningObjective(
                            subtopic_id=sub.id,
                            objective=lo_data["objective"],
                            description=lo_data.get("description", ""),
                            cognitive_level=lo_data.get("cognitive_level", "Knowledge"),
                            teaching_activity=lo_data.get("teaching_activity", ""),
                            teaching_method=lo_data.get("teaching_method", ""),
                        )
                        db.add(lo)

                for res_data in topic_data.get("resources", []):
                    res = SyllabusResource(
                        topic_id=topic.id,
                        resource_text=res_data["text"],
                        resource_type=res_data.get("type", "equipment"),
                    )
                    db.add(res)

        await db.commit()
