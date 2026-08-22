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
                    "resources": [],
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
                    "resources": [],
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
                    "resources": [],
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
                    "resources": [],
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
                    "resources": [],
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
                    "resources": [],
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
                    "resources": [],
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
                    "resources": [],
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
                    "resources": [],
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
                    "resources": [],
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
                    "resources": [],
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
                    "resources": [],
                },
                # ── FORM 3 ─────────────────────────────────────────────────
                {
                    "title": "Quadratic Equations",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Solving Using the Formula",
                            "description": "Solving quadratic equations using the quadratic formula x = (−b ± √(b² − 4ac)) / 2a.",
                            "learning_objectives": [
                                {
                                    "objective": "Solve quadratic equations using the quadratic formula",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Formulate quadratic equations from word problems",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving",
                                },
                            ],
                        },
                        {
                            "title": "Applications of Quadratic Equations",
                            "description": "Solving real-life problems leading to quadratic equations.",
                            "learning_objectives": [
                                {
                                    "objective": "Apply quadratic equations to solve real-life problems",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving",
                                },
                            ],
                        },
                    ],
                    "resources": [],
                },
                {
                    "title": "Irrational Numbers",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Surds",
                            "description": "Simplifying, rationalising, and operating with irrational numbers (surds).",
                            "learning_objectives": [
                                {
                                    "objective": "Simplify expressions involving surds",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Rationalise the denominator of a fraction containing surds",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Perform operations with irrational numbers",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                            ],
                        },
                    ],
                    "resources": [],
                },
                {
                    "title": "Algebraic Fractions with Linear or Quadratic Denominators",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Simplifying Algebraic Fractions",
                            "description": "Simplifying algebraic fractions with linear or quadratic denominators.",
                            "learning_objectives": [
                                {
                                    "objective": "Simplify algebraic fractions by factorising the denominator",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Operations with Algebraic Fractions",
                            "description": "Adding, subtracting, multiplying and dividing algebraic fractions.",
                            "learning_objectives": [
                                {
                                    "objective": "Add and subtract algebraic fractions with linear or quadratic denominators",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Multiply and divide algebraic fractions",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [],
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
                    "resources": [],
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
                    "resources": [],
                },
                # ── FORM 4 ─────────────────────────────────────────────────
                {
                    "title": "Matrices",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Types and Order of Matrices",
                            "description": "Identifying types, order and elements of matrices.",
                            "learning_objectives": [
                                {
                                    "objective": "Identify the order and elements of a matrix",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion, examples",
                                },
                                {
                                    "objective": "Classify matrices as row, column, square, null, identity, etc.",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion",
                                },
                            ],
                        },
                        {
                            "title": "Matrix Operations",
                            "description": "Addition, subtraction and multiplication of matrices.",
                            "learning_objectives": [
                                {
                                    "objective": "Add and subtract matrices of the same order",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Multiply matrices where compatible",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Determinants",
                            "description": "Finding the determinant of 2×2 and 3×3 matrices.",
                            "learning_objectives": [
                                {
                                    "objective": "Calculate the determinant of a 2×2 matrix",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Calculate the determinant of a 3×3 matrix",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Inverse of a Matrix",
                            "description": "Finding the inverse of a matrix and using it to solve simultaneous equations.",
                            "learning_objectives": [
                                {
                                    "objective": "Find the inverse of a 2×2 matrix",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Solve simultaneous equations using the matrix inverse method",
                                    "cognitive_level": "Application",
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
                    "title": "Simultaneous Linear and Quadratic Equations",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Solving Graphically",
                            "description": "Solving simultaneous equations involving one linear and one quadratic equation graphically.",
                            "learning_objectives": [
                                {
                                    "objective": "Solve simultaneous linear and quadratic equations graphically",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Graphical activities",
                                },
                            ],
                        },
                        {
                            "title": "Solving Algebraically",
                            "description": "Solving simultaneous equations involving one linear and one quadratic equation algebraically.",
                            "learning_objectives": [
                                {
                                    "objective": "Solve simultaneous linear and quadratic equations algebraically",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Interpret the solutions in context",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Problem solving",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Graph paper", "type": "equipment"},
                    ],
                },
                {
                    "title": "Progressions",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Arithmetic Progression (AP)",
                            "description": "Finding terms, sum of terms, and applications of arithmetic progressions.",
                            "learning_objectives": [
                                {
                                    "objective": "Find the nth term of an arithmetic progression",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Calculate the sum of the first n terms of an AP",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Apply AP to real-life problems",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving",
                                },
                            ],
                        },
                        {
                            "title": "Geometric Progression (GP)",
                            "description": "Finding terms, sum of terms, and applications of geometric progressions.",
                            "learning_objectives": [
                                {
                                    "objective": "Find the nth term of a geometric progression",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Calculate the sum of the first n terms of a GP",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Calculate the sum to infinity of a convergent GP",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [],
                },
                {
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
                {
                    "title": "Sets",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Union, Intersection and Complement",
                            "description": "Operations on sets using algebra of sets and laws (commutative, associative, distributive, De Morgan's).",
                            "learning_objectives": [
                                {
                                    "objective": "Apply the laws of set algebra to simplify expressions",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Use De Morgan's laws to find complements of union and intersection",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Discussion, examples",
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
                    "resources": [],
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
                    "resources": [],
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
                    "resources": [],
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
                    "resources": [],
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
                    "resources": [],
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
                {
                    "title": "Circle Geometry (Chord Properties)",
                    "year_level": 3,
                    "subtopics": [
                        {
                            "title": "Chord Properties",
                            "description": "Properties of chords: perpendicular from the centre bisects the chord, equal chords are equidistant from the centre, etc.",
                            "learning_objectives": [
                                {
                                    "objective": "State and apply the perpendicular bisector chord property",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Apply properties of equal chords and their distances from the centre",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving",
                                },
                            ],
                        },
                    ],
                    "resources": [
                        {"text": "Compass", "type": "equipment"},
                        {"text": "Ruler", "type": "equipment"},
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
                    "resources": [],
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
                    "resources": [],
                },
                # ── FORM 4 ─────────────────────────────────────────────────
                {
                    "title": "Tangents to Circles",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Tangent-Radius Theorem",
                            "description": "A tangent to a circle is perpendicular to the radius at the point of contact.",
                            "learning_objectives": [
                                {
                                    "objective": "State and apply the tangent-radius theorem",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                        {
                            "title": "Tangent-Chord Theorem",
                            "description": "The angle between a tangent and a chord through the point of contact equals the angle in the alternate segment.",
                            "learning_objectives": [
                                {
                                    "objective": "State and apply the alternate segment theorem",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Solve problems using tangent-chord properties",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Problem solving",
                                },
                            ],
                        },
                        {
                            "title": "Two Tangents from an External Point",
                            "description": "Tangents from an external point to a circle are equal in length.",
                            "learning_objectives": [
                                {
                                    "objective": "Apply the theorem: two tangents from an external point are equal in length",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                            ],
                        },
                    ],
                    "resources": [],
                },
                {
                    "title": "Trigonometry",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Trigonometric Ratios of Any Angle",
                            "description": "Extending sine, cosine and tangent to angles beyond 0°–90° using the unit circle.",
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
                            "description": "Using the identity sin²θ + cos²θ = 1 and tan θ = sin θ / cos θ.",
                            "learning_objectives": [
                                {
                                    "objective": "Apply the identity sin²θ + cos²θ = 1 to simplify expressions",
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
                },
                {
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
                    "resources": [],
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
                    "resources": [],
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
                },
                {
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
                },
                {
                    "title": "Cubic Graphs",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Sketching Cubic Curves",
                            "description": "Sketching graphs of cubic functions and identifying key features.",
                            "learning_objectives": [
                                {
                                    "objective": "Sketch graphs of cubic functions of the form y = ax³ + bx² + cx + d",
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
                    "subtopics": [
                        {
                            "title": "Correlation and Regression",
                            "description": "Scatter diagrams, line of best fit and correlation.",
                            "learning_objectives": [
                                {
                                    "objective": "Draw scatter diagrams to investigate the relationship between two variables",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Practical exercises",
                                },
                                {
                                    "objective": "Draw and interpret the line of best fit",
                                    "cognitive_level": "Analysis",
                                    "teaching_method": "Practical exercises",
                                },
                                {
                                    "objective": "Distinguish between positive, negative and no correlation",
                                    "cognitive_level": "Knowledge",
                                    "teaching_method": "Discussion",
                                },
                            ],
                        },
                        {
                            "title": "Measures of Location from Grouped Data",
                            "description": "Estimating the mean, median and mode from grouped frequency tables.",
                            "learning_objectives": [
                                {
                                    "objective": "Estimate the mean from a grouped frequency table",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Estimate the median from a grouped frequency table",
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
                {
                    "title": "Probability",
                    "year_level": 4,
                    "subtopics": [
                        {
                            "title": "Combined Events",
                            "description": "Calculating probabilities of combined events using addition and multiplication rules.",
                            "learning_objectives": [
                                {
                                    "objective": "Apply the addition rule P(A ∪ B) = P(A) + P(B) − P(A ∩ B)",
                                    "cognitive_level": "Application",
                                    "teaching_method": "Guided practice",
                                },
                                {
                                    "objective": "Apply the multiplication rule P(A ∩ B) = P(A) × P(B|A)",
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
        await db.commit()
        await db.refresh(subject)

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
        await db.commit()
        await db.refresh(version)

        for idx, ce_data in enumerate(data.get("core_elements", [])):
            ce = SyllabusCoreElement(
                version_id=version.id,
                number=ce_data["number"],
                name=ce_data["name"],
                description=ce_data.get("description", ""),
                order_index=idx,
            )
            db.add(ce)
            await db.commit()
            await db.refresh(ce)

            for t_idx, topic_data in enumerate(ce_data.get("topics", [])):
                topic = SyllabusTopic(
                    core_element_id=ce.id,
                    title=topic_data["title"],
                    description=topic_data.get("description", ""),
                    year_level=topic_data.get("year_level", 1),
                    order_index=t_idx,
                )
                db.add(topic)
                await db.commit()
                await db.refresh(topic)

                for sub_data in topic_data.get("subtopics", []):
                    sub = SyllabusSubtopic(
                        topic_id=topic.id,
                        title=sub_data["title"],
                        description=sub_data.get("description", ""),
                        order_index=0,
                    )
                    db.add(sub)
                    await db.commit()
                    await db.refresh(sub)

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
