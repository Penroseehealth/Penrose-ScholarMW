import asyncio
from typing import Any

from sqlalchemy import select

from app.database.engine import Base, async_session, engine
from app.models.stem import (
    STEMConcept,
    STEMDiscipline,
    STEMSubject,
    STEMSubtopic,
    STEMTopic,
    STLearningMaterial,
    STPractice,
)

SUBJECTS: list[dict[str, Any]] = [
    # ── 1. Mathematics ──────────────────────────────────────────────
    {
        "title": "Mathematics",
        "slug": "mathematics",
        "icon": "calculate",
        "color": "#8B5CF6",
        "description": "The foundational study of quantity, structure, space, and change.",
        "disciplines": [
            {
                "title": "Number and Arithmetic",
                "slug": "number-arithmetic",
                "description": "The study of numbers and basic operations.",
                "topics": [
                    {
                        "title": "Natural Numbers and Counting",
                        "difficulty": "foundational",
                        "description": "Fundamentals of counting and the number system.",
                        "subtopics": [
                            {
                                "title": "Natural and Whole Numbers",
                                "concepts": [
                                    {
                                        "title": "Natural Numbers",
                                        "description": "The set of positive counting numbers used to enumerate discrete objects.",
                                        "material_title": "Introduction to Natural Numbers",
                                        "material_content": "Natural numbers are the counting numbers starting from 1: {1, 2, 3, ...}. They form the most basic number system used for counting discrete objects. The set is denoted by the symbol N. Natural numbers are closed under addition and multiplication but not subtraction or division.",
                                        "practices": [
                                            {
                                                "question": "Which of the following is a natural number?",
                                                "type": "mcq",
                                                "options": '{"options":["A) -3","B) 0","C) 5","D) 0.5"]}',
                                                "answer": "C",
                                                "explanation": "Natural numbers are positive integers starting from 1. Only 5 qualifies.",
                                            },
                                            {
                                                "question": "List the first five natural numbers.",
                                                "type": "short_answer",
                                                "answer": "1, 2, 3, 4, 5",
                                                "explanation": "Natural numbers start at 1 and increase by 1.",
                                            },
                                        ],
                                    },
                                    {
                                        "title": "Whole Numbers",
                                        "description": "Natural numbers extended to include zero.",
                                        "material_title": "Understanding Whole Numbers",
                                        "material_content": "Whole numbers include all natural numbers plus zero: {0, 1, 2, 3, ...}. They form the set W and are used when representing zero as a valid count. Whole numbers are closed under addition and multiplication. The concept of zero was a revolutionary mathematical advancement.",
                                        "practices": [
                                            {
                                                "question": "Is zero a whole number?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Yes","B) No","C) Only in algebra","D) Only in base 10"]}',
                                                "answer": "A",
                                                "explanation": "Zero is included in the set of whole numbers by definition.",
                                            },
                                            {
                                                "question": "What is the smallest whole number?",
                                                "type": "short_answer",
                                                "answer": "0",
                                                "explanation": "Zero is the smallest whole number and distinguishes whole numbers from natural numbers.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Integers",
                                "concepts": [
                                    {
                                        "title": "Positive and Negative Integers",
                                        "description": "The complete set of signed numbers including negatives, zero, and positives.",
                                        "material_title": "The Integer Number Line",
                                        "material_content": "Integers extend whole numbers to include negative counterparts: {..., -3, -2, -1, 0, 1, 2, 3, ...}. They are closed under addition, subtraction, and multiplication. The integer number line places zero between positive and negative values. Negative numbers represent quantities below a reference point.",
                                        "practices": [
                                            {
                                                "question": "What is the additive inverse of 7?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 7","B) -7","C) 1/7","D) 0"]}',
                                                "answer": "B",
                                                "explanation": "The additive inverse of a number is the value that, when added, yields zero. The inverse of 7 is -7.",
                                            },
                                            {
                                                "question": "Simplify: (-5) + 3 - (-2).",
                                                "type": "short_answer",
                                                "answer": "0",
                                                "explanation": "(-5) + 3 = -2, then -2 - (-2) = -2 + 2 = 0.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Fractions and Decimals",
                        "difficulty": "foundational",
                        "description": "Representation of parts of a whole.",
                        "subtopics": [
                            {
                                "title": "Fraction Operations",
                                "concepts": [
                                    {
                                        "title": "Adding and Subtracting Fractions",
                                        "description": "Combining fractions with common and unlike denominators.",
                                        "material_title": "Fraction Addition and Subtraction",
                                        "material_content": "To add or subtract fractions, they must share a common denominator. For like denominators, simply add or subtract the numerators. For unlike denominators, find the least common multiple (LCM) of the denominators and convert each fraction before operating. Simplify the result to lowest terms.",
                                        "practices": [
                                            {
                                                "question": "What is 1/4 + 2/4?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 3/4","B) 2/8","C) 3/8","D) 1/2"]}',
                                                "answer": "A",
                                                "explanation": "With the same denominator, add the numerators: 1 + 2 = 3, so the result is 3/4.",
                                            },
                                            {
                                                "question": "Compute 3/5 - 1/3.",
                                                "type": "short_answer",
                                                "answer": "4/15",
                                                "explanation": "LCM of 5 and 3 is 15. Convert: 9/15 - 5/15 = 4/15.",
                                            },
                                        ],
                                    },
                                    {
                                        "title": "Multiplying and Dividing Fractions",
                                        "description": "Products and quotients of fractional numbers.",
                                        "material_title": "Fraction Multiplication and Division",
                                        "material_content": "To multiply fractions, multiply the numerators together and the denominators together: (a/b) x (c/d) = ac/bd. To divide fractions, multiply by the reciprocal of the divisor: (a/b) / (c/d) = (a/b) x (d/c). Always reduce the final answer to simplest form.",
                                        "practices": [
                                            {
                                                "question": "What is 2/3 x 3/4?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 6/12","B) 1/2","C) 5/7","D) 8/12"]}',
                                                "answer": "B",
                                                "explanation": "2/3 x 3/4 = 6/12 = 1/2 after simplification.",
                                            },
                                            {
                                                "question": "Compute 5/6 / 2/3.",
                                                "type": "short_answer",
                                                "answer": "5/4",
                                                "explanation": "5/6 / 2/3 = 5/6 x 3/2 = 15/12 = 5/4.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Decimal Representation",
                                "concepts": [
                                    {
                                        "title": "Converting Fractions to Decimals",
                                        "description": "Transforming fractional notation into decimal form.",
                                        "material_title": "Fraction-to-Decimal Conversion",
                                        "material_content": "To convert a fraction to a decimal, divide the numerator by the denominator. If the division terminates, you get a terminating decimal. If it repeats, you get a repeating decimal. For example, 1/4 = 0.25 (terminating) and 1/3 = 0.333... (repeating). Terminating decimals have denominators whose prime factors are only 2 and/or 5.",
                                        "practices": [
                                            {
                                                "question": "Convert 3/8 to a decimal.",
                                                "type": "mcq",
                                                "options": '{"options":["A) 0.38","B) 0.375","C) 0.333","D) 0.25"]}',
                                                "answer": "B",
                                                "explanation": "3 / 8 = 0.375.",
                                            },
                                            {
                                                "question": "Is 2/7 a terminating or repeating decimal?",
                                                "type": "short_answer",
                                                "answer": "Repeating",
                                                "explanation": "Since 7 is not a factor of any power of 10, 2/7 produces a repeating decimal: 0.285714...",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Ratio and Proportion",
                        "difficulty": "foundational",
                        "description": "Comparative relationships between quantities.",
                        "subtopics": [
                            {
                                "title": "Proportional Reasoning",
                                "concepts": [
                                    {
                                        "title": "Ratios and Rates",
                                        "description": "Expressing relationships between two or more quantities.",
                                        "material_title": "Understanding Ratios",
                                        "material_content": "A ratio compares two quantities and can be expressed as a:b, a/b, or 'a to b'. A rate is a ratio with different units, such as kilometers per hour. Unit rates simplify the denominator to 1, making comparisons easier. Ratios can be scaled up or down while maintaining the same relationship.",
                                        "practices": [
                                            {
                                                "question": "A class has 12 boys and 18 girls. What is the ratio of boys to girls in simplest form?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 12:18","B) 2:3","C) 3:2","D) 6:9"]}',
                                                "answer": "B",
                                                "explanation": "12:18 simplifies by dividing both by 6, yielding 2:3.",
                                            },
                                            {
                                                "question": "A car travels 240 miles in 4 hours. What is the unit rate?",
                                                "type": "short_answer",
                                                "answer": "60 miles per hour",
                                                "explanation": "240 / 4 = 60 miles per hour.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Percentages",
                                "concepts": [
                                    {
                                        "title": "Percentage Calculations",
                                        "description": "Computing percentages, increases, and decreases.",
                                        "material_title": "Working with Percentages",
                                        "material_content": "A percentage expresses a number as parts per hundred: x% = x/100. To find p% of a value, multiply: (p/100) x value. Percentage change is calculated as (new - old)/old x 100%. Percentages are widely used in finance, statistics, and everyday life to express proportions.",
                                        "practices": [
                                            {
                                                "question": "What is 15% of 200?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 15","B) 30","C) 25","D) 20"]}',
                                                "answer": "B",
                                                "explanation": "15/100 x 200 = 0.15 x 200 = 30.",
                                            },
                                            {
                                                "question": "A price increases from $80 to $100. What is the percentage increase?",
                                                "type": "short_answer",
                                                "answer": "25%",
                                                "explanation": "(100 - 80)/80 x 100% = 20/80 x 100% = 25%.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Algebra",
                "slug": "algebra",
                "description": "The study of mathematical symbols and rules for manipulating them.",
                "topics": [
                    {
                        "title": "Expressions and Equations",
                        "difficulty": "foundational",
                        "description": "Manipulating algebraic expressions and solving equations.",
                        "subtopics": [
                            {
                                "title": "Algebraic Expressions",
                                "concepts": [
                                    {
                                        "title": "Combining Like Terms",
                                        "description": "Simplifying expressions by grouping terms with the same variable and exponent.",
                                        "material_title": "Like Terms in Algebra",
                                        "material_content": "Like terms are terms that have the same variable raised to the same power. Only like terms can be combined through addition or subtraction. For example, 3x and 5x are like terms (sum = 8x), but 3x and 3x squared are not. Simplifying expressions by combining like terms is a foundational skill in algebra.",
                                        "practices": [
                                            {
                                                "question": "Simplify: 4x + 3y - 2x + 7y.",
                                                "type": "mcq",
                                                "options": '{"options":["A) 2x + 10y","B) 6x + 10y","C) 2x + 4y","D) 7x + 10y"]}',
                                                "answer": "A",
                                                "explanation": "Combine x-terms: 4x - 2x = 2x. Combine y-terms: 3y + 7y = 10y. Result: 2x + 10y.",
                                            },
                                            {
                                                "question": "Simplify: 5a^2 + 3a - 2a^2 + a.",
                                                "type": "short_answer",
                                                "answer": "3a^2 + 4a",
                                                "explanation": "Combine a^2 terms: 5a^2 - 2a^2 = 3a^2. Combine a-terms: 3a + a = 4a.",
                                            },
                                        ],
                                    },
                                    {
                                        "title": "The Distributive Property",
                                        "description": "Expanding expressions by distributing multiplication over addition.",
                                        "material_title": "Applying the Distributive Property",
                                        "material_content": "The distributive property states that a(b + c) = ab + ac. It allows you to expand expressions by multiplying each term inside parentheses by the factor outside. This property is essential for expanding binomials, simplifying complex expressions, and factoring. It connects multiplication with addition.",
                                        "practices": [
                                            {
                                                "question": "Expand: 3(x + 4).",
                                                "type": "mcq",
                                                "options": '{"options":["A) 3x + 4","B) 3x + 12","C) 3 + 4x","D) 12x"]}',
                                                "answer": "B",
                                                "explanation": "Distribute the 3: 3*x + 3*4 = 3x + 12.",
                                            },
                                            {
                                                "question": "Expand: -2(3a - 5b + 1).",
                                                "type": "short_answer",
                                                "answer": "-6a + 10b - 2",
                                                "explanation": "Multiply each term by -2: -2*3a + (-2)*(-5b) + (-2)*1 = -6a + 10b - 2.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Linear Equations",
                                "concepts": [
                                    {
                                        "title": "Solving One-Variable Linear Equations",
                                        "description": "Finding the value of an unknown in a first-degree equation.",
                                        "material_title": "Linear Equations in One Variable",
                                        "material_content": "A linear equation in one variable has the form ax + b = c, where a is not zero. To solve, isolate the variable by performing inverse operations on both sides: first subtract b, then divide by a. The solution is the value that makes the equation true. Always verify by substituting back into the original equation.",
                                        "practices": [
                                            {
                                                "question": "Solve: 2x + 5 = 13.",
                                                "type": "mcq",
                                                "options": '{"options":["A) x = 3","B) x = 4","C) x = 5","D) x = 6"]}',
                                                "answer": "B",
                                                "explanation": "Subtract 5: 2x = 8. Divide by 2: x = 4.",
                                            },
                                            {
                                                "question": "Solve: 3(x - 2) = 15.",
                                                "type": "short_answer",
                                                "answer": "x = 7",
                                                "explanation": "Divide by 3: x - 2 = 5. Add 2: x = 7.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Inequalities",
                        "difficulty": "intermediate",
                        "description": "Comparing expressions using inequality relations.",
                        "subtopics": [
                            {
                                "title": "Linear Inequalities",
                                "concepts": [
                                    {
                                        "title": "Solving Linear Inequalities",
                                        "description": "Using inverse operations while preserving inequality direction.",
                                        "material_title": "Linear Inequality Solutions",
                                        "material_content": "Linear inequalities are solved like equations, with one key rule: when multiplying or dividing by a negative number, reverse the inequality sign. Solutions are ranges of values rather than single points. They are represented on number lines with open circles for strict inequalities and closed circles for inclusive ones.",
                                        "practices": [
                                            {
                                                "question": "Solve: 3x - 7 > 5.",
                                                "type": "mcq",
                                                "options": '{"options":["A) x > 4","B) x > 2","C) x < 4","D) x > 12"]}',
                                                "answer": "A",
                                                "explanation": "Add 7: 3x > 12. Divide by 3: x > 4.",
                                            },
                                            {
                                                "question": "Solve: -2x + 6 <= 10.",
                                                "type": "short_answer",
                                                "answer": "x >= -2",
                                                "explanation": "Subtract 6: -2x <= 4. Divide by -2 and reverse the sign: x >= -2.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Compound Inequalities",
                                "concepts": [
                                    {
                                        "title": "Compound Inequality Operations",
                                        "description": "Solving inequalities connected by conjunctions.",
                                        "material_title": "Compound Inequalities",
                                        "material_content": "Compound inequalities combine two inequalities with AND (intersection) or OR (union). An AND compound inequality like a < x < b means x satisfies both conditions simultaneously. An OR compound inequality means x satisfies at least one condition. Solutions are intervals on the number line.",
                                        "practices": [
                                            {
                                                "question": "Solve: -3 < 2x + 1 < 7.",
                                                "type": "mcq",
                                                "options": '{"options":["A) -2 < x < 3","B) -1 < x < 4","C) -3 < x < 3","D) -2 < x < 4"]}',
                                                "answer": "A",
                                                "explanation": "Subtract 1: -4 < 2x < 6. Divide by 2: -2 < x < 3.",
                                            },
                                            {
                                                "question": "Solve: x + 5 > 8 OR x - 3 < -1.",
                                                "type": "short_answer",
                                                "answer": "x > 3 OR x < 2",
                                                "explanation": "First inequality: x > 3. Second: x < 2. The solution is the union of both.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Quadratic Equations",
                        "difficulty": "intermediate",
                        "description": "Solving second-degree polynomial equations.",
                        "subtopics": [
                            {
                                "title": "Solving Quadratics",
                                "concepts": [
                                    {
                                        "title": "The Quadratic Formula",
                                        "description": "A universal formula for solving any quadratic equation.",
                                        "material_title": "Using the Quadratic Formula",
                                        "material_content": "For ax^2 + bx + c = 0, the quadratic formula gives x = (-b +/- sqrt(b^2 - 4ac)) / (2a). The discriminant D = b^2 - 4ac determines the nature of roots: positive yields two real roots, zero yields one repeated root, and negative yields complex conjugate roots. This method works for all quadratic equations.",
                                        "practices": [
                                            {
                                                "question": "What are the roots of x^2 - 5x + 6 = 0?",
                                                "type": "mcq",
                                                "options": '{"options":["A) x = 1, 6","B) x = 2, 3","C) x = -2, -3","D) x = -1, 6"]}',
                                                "answer": "B",
                                                "explanation": "Using the formula: x = (5 +/- sqrt(25-24))/2 = (5 +/- 1)/2, so x = 3 or x = 2.",
                                            },
                                            {
                                                "question": "Find the discriminant of 2x^2 + 3x + 5 = 0.",
                                                "type": "short_answer",
                                                "answer": "-31",
                                                "explanation": "D = 3^2 - 4(2)(5) = 9 - 40 = -31. The negative discriminant means complex roots.",
                                            },
                                        ],
                                    },
                                    {
                                        "title": "Factoring Quadratics",
                                        "description": "Finding roots by expressing quadratics as products of linear factors.",
                                        "material_title": "Factoring Quadratic Expressions",
                                        "material_content": "Many quadratics can be factored as (px + q)(rx + s) = 0, where the roots are x = -q/p and x = -s/r. To factor, find two numbers that multiply to ac and add to b (for ax^2 + bx + c). Common patterns include difference of squares a^2 - b^2 = (a+b)(a-b) and perfect square trinomials.",
                                        "practices": [
                                            {
                                                "question": "Factor: x^2 - 9.",
                                                "type": "mcq",
                                                "options": '{"options":["A) (x-3)^2","B) (x+3)(x-3)","C) (x+3)^2","D) (x-9)(x+1)"]}',
                                                "answer": "B",
                                                "explanation": "This is a difference of squares: a^2 - b^2 = (a+b)(a-b), so x^2 - 9 = (x+3)(x-3).",
                                            },
                                            {
                                                "question": "Factor: x^2 + 5x + 6.",
                                                "type": "short_answer",
                                                "answer": "(x + 2)(x + 3)",
                                                "explanation": "Find two numbers that multiply to 6 and add to 5: 2 and 3.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Properties of Quadratic Functions",
                                "concepts": [
                                    {
                                        "title": "Vertex and Axis of Symmetry",
                                        "description": "Identifying the turning point and mirror line of a parabola.",
                                        "material_title": "Parabola Features",
                                        "material_content": "The vertex of y = ax^2 + bx + c is at x = -b/(2a), with the y-coordinate found by substitution. The axis of symmetry is the vertical line x = -b/(2a). If a > 0 the parabola opens upward (minimum); if a < 0 it opens downward (maximum). The vertex form y = a(x-h)^2 + k directly shows the vertex (h, k).",
                                        "practices": [
                                            {
                                                "question": "What is the vertex of y = (x - 2)^2 + 3?",
                                                "type": "mcq",
                                                "options": '{"options":["A) (2, 3)","B) (-2, 3)","C) (2, -3)","D) (-2, -3)"]}',
                                                "answer": "A",
                                                "explanation": "In vertex form y = a(x-h)^2 + k, the vertex is (h, k) = (2, 3).",
                                            },
                                            {
                                                "question": "Find the axis of symmetry for y = 3x^2 - 12x + 5.",
                                                "type": "short_answer",
                                                "answer": "x = 2",
                                                "explanation": "Axis of symmetry: x = -b/(2a) = -(-12)/(2*3) = 12/6 = 2.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Geometry and Trigonometry",
                "slug": "geometry-trigonometry",
                "description": "The study of shapes, sizes, and spatial relationships.",
                "topics": [
                    {
                        "title": "Euclidean Geometry",
                        "difficulty": "foundational",
                        "description": "Classical geometry of flat space.",
                        "subtopics": [
                            {
                                "title": "Points, Lines, and Planes",
                                "concepts": [
                                    {
                                        "title": "Basic Geometric Postulates",
                                        "description": "Axioms describing points, lines, and their interactions.",
                                        "material_title": "Euclid's Postulates",
                                        "material_content": "Euclidean geometry rests on five postulates: a straight line can be drawn between any two points, a line segment can be extended infinitely, a circle can be drawn with any center and radius, all right angles are equal, and the parallel postulate. These postulates form the logical foundation for all geometric proofs.",
                                        "practices": [
                                            {
                                                "question": "How many points are needed to determine a unique line?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 1","B) 2","C) 3","D) 4"]}',
                                                "answer": "B",
                                                "explanation": "Exactly two distinct points determine a unique line in Euclidean geometry.",
                                            },
                                            {
                                                "question": "What is the minimum number of non-collinear points needed to define a plane?",
                                                "type": "short_answer",
                                                "answer": "3",
                                                "explanation": "Three non-collinear points uniquely determine a plane.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Triangle Properties",
                                "concepts": [
                                    {
                                        "title": "Triangle Angle Sum and Classification",
                                        "description": "Properties of interior angles and types of triangles.",
                                        "material_title": "Triangles",
                                        "material_content": "The sum of interior angles in any triangle is always 180 degrees. Triangles are classified by sides as scalene (no equal sides), isosceles (two equal sides), or equilateral (all sides equal). By angles they are acute (all angles < 90), right (one 90 degree angle), or obtuse (one angle > 90). The exterior angle of a triangle equals the sum of the two opposite interior angles.",
                                        "practices": [
                                            {
                                                "question": "Two angles of a triangle are 45 and 60 degrees. What is the third angle?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 85","B) 75","C) 65","D) 95"]}',
                                                "answer": "B",
                                                "explanation": "180 - 45 - 60 = 75 degrees.",
                                            },
                                            {
                                                "question": "What type of triangle has all three sides equal?",
                                                "type": "short_answer",
                                                "answer": "Equilateral triangle",
                                                "explanation": "An equilateral triangle has three equal sides and three 60 degree angles.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Circles",
                        "difficulty": "intermediate",
                        "description": "Properties of circular figures.",
                        "subtopics": [
                            {
                                "title": "Circle Theorems",
                                "concepts": [
                                    {
                                        "title": "Central and Inscribed Angles",
                                        "description": "Relationships between angles subtended by arcs.",
                                        "material_title": "Circle Angle Theorems",
                                        "material_content": "A central angle equals the measure of its intercepted arc. An inscribed angle is half the measure of its intercepted arc. Angles subtended by the same arc at the circumference are equal. A right angle can be inscribed in a semicircle. These theorems are fundamental to solving circle geometry problems.",
                                        "practices": [
                                            {
                                                "question": "An inscribed angle intercepts an arc of 100 degrees. What is the angle measure?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 100","B) 50","C) 200","D) 25"]}',
                                                "answer": "B",
                                                "explanation": "An inscribed angle is half the intercepted arc: 100/2 = 50 degrees.",
                                            },
                                            {
                                                "question": "If a central angle is 120 degrees, what is the intercepted arc?",
                                                "type": "short_answer",
                                                "answer": "120 degrees",
                                                "explanation": "A central angle equals its intercepted arc.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Arc Length and Area",
                                "concepts": [
                                    {
                                        "title": "Circumference and Arc Length",
                                        "description": "Computing lengths along a circle boundary.",
                                        "material_title": "Arc Length Calculations",
                                        "material_content": "The circumference of a circle is C = 2*pi*r = pi*d, where r is the radius and d is the diameter. The length of an arc is proportional to its central angle: arc length = (theta/360) x 2*pi*r for angles in degrees. For radians, arc length = r*theta. This formula is essential in engineering and navigation.",
                                        "practices": [
                                            {
                                                "question": "What is the circumference of a circle with radius 7 cm?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 14*pi cm","B) 7*pi cm","C) 49*pi cm","D) 28*pi cm"]}',
                                                "answer": "A",
                                                "explanation": "C = 2*pi*r = 2*pi*7 = 14*pi cm.",
                                            },
                                            {
                                                "question": "Find the arc length of a 60 degree arc on a circle of radius 12 cm.",
                                                "type": "short_answer",
                                                "answer": "4*pi cm",
                                                "explanation": "Arc length = (60/360) x 2*pi*12 = (1/6) x 24*pi = 4*pi cm.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Trigonometry",
                        "difficulty": "intermediate",
                        "description": "Relating angles to side ratios in triangles.",
                        "subtopics": [
                            {
                                "title": "Trigonometric Ratios",
                                "concepts": [
                                    {
                                        "title": "Sine, Cosine, and Tangent",
                                        "description": "Ratios of sides in right-angled triangles.",
                                        "material_title": "Right Triangle Trigonometry",
                                        "material_content": "In a right triangle, sin(theta) = opposite/hypotenuse, cos(theta) = adjacent/hypotenuse, and tan(theta) = opposite/adjacent. These ratios relate acute angles to side proportions. The mnemonic SOH-CAH-TOA helps recall these definitions. Each ratio has a reciprocal: cosecant, secant, and cotangent respectively.",
                                        "practices": [
                                            {
                                                "question": "In a right triangle, the opposite side is 3 and the hypotenuse is 5. What is sin(theta)?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 3/4","B) 4/5","C) 3/5","D) 5/3"]}',
                                                "answer": "C",
                                                "explanation": "sin(theta) = opposite/hypotenuse = 3/5.",
                                            },
                                            {
                                                "question": "If cos(theta) = 5/13 and the hypotenuse is 13, what is the adjacent side?",
                                                "type": "short_answer",
                                                "answer": "5",
                                                "explanation": "cos(theta) = adjacent/hypotenuse, so adjacent = cos(theta) x 13 = 5.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Trigonometric Identities",
                                "concepts": [
                                    {
                                        "title": "Pythagorean Identity",
                                        "description": "The fundamental relationship between sine and cosine.",
                                        "material_title": "The Pythagorean Identity",
                                        "material_content": "The Pythagorean identity states that sin^2(theta) + cos^2(theta) = 1 for all angles theta. This is derived from the Pythagorean theorem applied to the unit circle. From this identity, we can derive 1 + tan^2(theta) = sec^2(theta) and 1 + cot^2(theta) = csc^2(theta). These identities are essential for simplifying trigonometric expressions.",
                                        "practices": [
                                            {
                                                "question": "If sin(theta) = 3/5, what is cos(theta) given that theta is acute?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 3/5","B) 4/5","C) 5/3","D) 5/4"]}',
                                                "answer": "B",
                                                "explanation": "Using sin^2 + cos^2 = 1: (3/5)^2 + cos^2 = 1, so cos^2 = 16/25, cos = 4/5.",
                                            },
                                            {
                                                "question": "Derive 1 + tan^2(theta) = sec^2(theta) from the Pythagorean identity.",
                                                "type": "short_answer",
                                                "answer": "Divide sin^2 + cos^2 = 1 by cos^2 to get tan^2 + 1 = sec^2.",
                                                "explanation": "Dividing both sides by cos^2: sin^2/cos^2 + 1 = 1/cos^2, which gives tan^2 + 1 = sec^2.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Calculus",
                "slug": "calculus",
                "description": "The mathematical study of continuous change.",
                "topics": [
                    {
                        "title": "Limits",
                        "difficulty": "intermediate",
                        "description": "The foundation of calculus: approaching values.",
                        "subtopics": [
                            {
                                "title": "Definition of Limits",
                                "concepts": [
                                    {
                                        "title": "Evaluating Limits",
                                        "description": "Determining the value a function approaches as the input approaches a point.",
                                        "material_title": "Limit Concepts",
                                        "material_content": "A limit describes the value a function f(x) approaches as x approaches a point c, written lim(x->c) f(x) = L. Limits exist when the left-hand and right-hand limits are equal. Direct substitution works for continuous functions. When direct substitution yields indeterminate forms (0/0, infinity/infinity), algebraic manipulation or L'Hopital's rule is needed.",
                                        "practices": [
                                            {
                                                "question": "Evaluate: lim(x->2) (x^2 - 4)/(x - 2).",
                                                "type": "mcq",
                                                "options": '{"options":["A) 0","B) 2","C) 4","D) Undefined"]}',
                                                "answer": "C",
                                                "explanation": "Factor: (x-2)(x+2)/(x-2) = x+2 for x!=2. lim(x->2)(x+2) = 4.",
                                            },
                                            {
                                                "question": "What is lim(x->0) sin(x)/x?",
                                                "type": "short_answer",
                                                "answer": "1",
                                                "explanation": "This is a fundamental trigonometric limit. As x approaches 0, sin(x)/x approaches 1.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Continuity",
                                "concepts": [
                                    {
                                        "title": "Types of Discontinuity",
                                        "description": "Classifying breaks in functions.",
                                        "material_title": "Discontinuities",
                                        "material_content": "A function is continuous at a point c if lim(x->c) f(x) = f(c). Three types of discontinuity exist: removable (a hole that could be filled), jump (left and right limits exist but differ), and infinite (function approaches plus or minus infinity). Continuity is required for differentiability and many integration theorems.",
                                        "practices": [
                                            {
                                                "question": "The function f(x) = (x^2-1)/(x-1) has what type of discontinuity at x=1?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Jump","B) Infinite","C) Removable","D) No discontinuity"]}',
                                                "answer": "C",
                                                "explanation": "The factor (x-1) cancels, leaving x+1. The hole at x=1 is removable.",
                                            },
                                            {
                                                "question": "Is f(x) = |x| continuous at x = 0?",
                                                "type": "short_answer",
                                                "answer": "Yes",
                                                "explanation": "The left limit (0), right limit (0), and function value (0) are all equal, so f is continuous at x = 0.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Derivatives",
                        "difficulty": "intermediate",
                        "description": "Rates of change and slopes of curves.",
                        "subtopics": [
                            {
                                "title": "Derivative Rules",
                                "concepts": [
                                    {
                                        "title": "Power, Product, and Chain Rules",
                                        "description": "Core differentiation techniques.",
                                        "material_title": "Differentiation Rules",
                                        "material_content": "The power rule states d/dx[x^n] = n*x^(n-1). The product rule for u*v is u'v + uv'. The chain rule for f(g(x)) is f'(g(x))*g'(x). These rules allow efficient differentiation of complex expressions. The quotient rule (u'v - uv')/v^2 handles ratios, and trigonometric functions have their own derivative formulas.",
                                        "practices": [
                                            {
                                                "question": "What is the derivative of x^4?",
                                                "type": "mcq",
                                                "options": '{"options":["A) x^3","B) 4x^3","C) 4x^4","D) 5x^4"]}',
                                                "answer": "B",
                                                "explanation": "By the power rule: d/dx[x^4] = 4x^3.",
                                            },
                                            {
                                                "question": "Find d/dx[sin(x^2)].",
                                                "type": "short_answer",
                                                "answer": "2x*cos(x^2)",
                                                "explanation": "By the chain rule: derivative of sin(u) is cos(u), times derivative of u = x^2, which is 2x.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Applications of Derivatives",
                                "concepts": [
                                    {
                                        "title": "Optimization and Curve Sketching",
                                        "description": "Finding maxima, minima, and analyzing function behavior.",
                                        "material_title": "Applications of Derivatives",
                                        "material_content": "Derivatives reveal function behavior: f'(x) > 0 means increasing, f'(x) < 0 means decreasing. Critical points where f'(x) = 0 or is undefined are candidates for local extrema. The second derivative test classifies these: f''(x) > 0 is a minimum, f''(x) < 0 is a maximum. Inflection points occur where f''(x) changes sign.",
                                        "practices": [
                                            {
                                                "question": "Find the critical points of f(x) = x^3 - 3x.",
                                                "type": "mcq",
                                                "options": '{"options":["A) x = 0","B) x = +/-1","C) x = +/-sqrt(3)","D) x = 3"]}',
                                                "answer": "B",
                                                "explanation": "f'(x) = 3x^2 - 3 = 0 => x^2 = 1 => x = +/-1.",
                                            },
                                            {
                                                "question": "Is x = 1 a local max or min for f(x) = x^3 - 3x?",
                                                "type": "short_answer",
                                                "answer": "Local minimum",
                                                "explanation": "f''(1) = 6(1) = 6 > 0, so by the second derivative test, x = 1 is a local minimum.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Integrals",
                        "difficulty": "advanced",
                        "description": "Accumulation of quantities and areas under curves.",
                        "subtopics": [
                            {
                                "title": "Antiderivatives",
                                "concepts": [
                                    {
                                        "title": "Indefinite Integrals",
                                        "description": "Finding functions whose derivative is a given function.",
                                        "material_title": "Integration Basics",
                                        "material_content": "An indefinite integral is the reverse of a derivative: integral f(x)dx = F(x) + C where F'(x) = f(x). The constant of integration C accounts for the family of antiderivatives. Basic rules include integral x^n dx = x^(n+1)/(n+1) + C, integral sin(x)dx = -cos(x) + C, and integral e^x dx = e^x + C.",
                                        "practices": [
                                            {
                                                "question": "Evaluate integral 3x^2 dx.",
                                                "type": "mcq",
                                                "options": '{"options":["A) x^3 + C","B) 6x + C","C) x^2 + C","D) 3x^3 + C"]}',
                                                "answer": "A",
                                                "explanation": "By the power rule for integration: integral 3x^2 dx = 3 * x^3/3 + C = x^3 + C.",
                                            },
                                            {
                                                "question": "Find integral (2x + 5) dx.",
                                                "type": "short_answer",
                                                "answer": "x^2 + 5x + C",
                                                "explanation": "Integrate term by term: integral 2x dx = x^2, integral 5 dx = 5x. Add constant C.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Definite Integrals",
                                "concepts": [
                                    {
                                        "title": "The Fundamental Theorem of Calculus",
                                        "description": "Linking differentiation and integration.",
                                        "material_title": "Fundamental Theorem of Calculus",
                                        "material_content": "The fundamental theorem of calculus has two parts. Part 1: if F(x) = integral from a to x of f(t)dt, then F'(x) = f(x). Part 2: integral from a to b of f(x)dx = F(b) - F(a). This theorem connects differential and integral calculus, allowing definite integrals to be evaluated using antiderivatives.",
                                        "practices": [
                                            {
                                                "question": "Evaluate integral from 0 to 3 of 2x dx.",
                                                "type": "mcq",
                                                "options": '{"options":["A) 6","B) 9","C) 3","D) 12"]}',
                                                "answer": "B",
                                                "explanation": "Antiderivative is x^2. [x^2] from 0 to 3 = 9 - 0 = 9.",
                                            },
                                            {
                                                "question": "Compute integral from 1 to 4 of (3x^2 + 2x) dx.",
                                                "type": "short_answer",
                                                "answer": "78",
                                                "explanation": "Antiderivative: x^3 + x^2. [(64 + 16) - (1 + 1)] = 80 - 2 = 78.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Series",
                        "difficulty": "advanced",
                        "description": "Infinite sums and convergence.",
                        "subtopics": [
                            {
                                "title": "Infinite Series",
                                "concepts": [
                                    {
                                        "title": "Geometric Series",
                                        "description": "Summing terms with a common ratio.",
                                        "material_title": "Geometric Series",
                                        "material_content": "A geometric series has the form a + ar + ar^2 + ... = sum of ar^n. The sum of the first n terms is S_n = a(1-r^n)/(1-r) for r != 1. An infinite geometric series converges when |r| < 1, with sum S = a/(1-r). If |r| >= 1, the series diverges.",
                                        "practices": [
                                            {
                                                "question": "What is the sum of the infinite geometric series 1 + 1/2 + 1/4 + ...?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 1","B) 2","C) 3","D) Infinity"]}',
                                                "answer": "B",
                                                "explanation": "a = 1, r = 1/2. Sum = 1/(1-1/2) = 1/(1/2) = 2.",
                                            },
                                            {
                                                "question": "Find the sum of the first 5 terms of a geometric series with a = 3 and r = 2.",
                                                "type": "short_answer",
                                                "answer": "93",
                                                "explanation": "S_5 = 3(1-2^5)/(1-2) = 3(1-32)/(-1) = 3*31 = 93.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Convergence Tests",
                                "concepts": [
                                    {
                                        "title": "Ratio and Root Tests",
                                        "description": "Tests using limits of term ratios.",
                                        "material_title": "Convergence Tests",
                                        "material_content": "The ratio test examines lim|a_{n+1}/a_n|. If the limit < 1, the series converges absolutely; if > 1, it diverges; if = 1, the test is inconclusive. The root test examines lim|a_n|^(1/n) with the same conclusions. Both tests are particularly useful for series involving factorials or exponentials.",
                                        "practices": [
                                            {
                                                "question": "If the ratio test gives a limit of 0.5, what can you conclude?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Diverges","B) Converges absolutely","C) Inconclusive","D) Converges conditionally"]}',
                                                "answer": "B",
                                                "explanation": "Since 0.5 < 1, the series converges absolutely by the ratio test.",
                                            },
                                            {
                                                "question": "State the conclusion of the ratio test when the limit equals 1.",
                                                "type": "short_answer",
                                                "answer": "The test is inconclusive",
                                                "explanation": "When the ratio test yields exactly 1, no conclusion can be drawn and another test must be used.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Linear Algebra",
                "slug": "linear-algebra",
                "description": "The study of vectors, matrices, and linear transformations.",
                "topics": [
                    {
                        "title": "Vectors",
                        "difficulty": "intermediate",
                        "description": "Quantities with magnitude and direction.",
                        "subtopics": [
                            {
                                "title": "Vector Operations",
                                "concepts": [
                                    {
                                        "title": "Vector Addition and Scalar Multiplication",
                                        "description": "Combining vectors and scaling them.",
                                        "material_title": "Vector Arithmetic",
                                        "material_content": "Vectors are added component-wise: (a1, a2) + (b1, b2) = (a1+b1, a2+b2). Scalar multiplication multiplies each component: k(a1, a2) = (ka1, ka2). These operations follow commutative, associative, and distributive laws. The zero vector is the additive identity, and -v is the additive inverse.",
                                        "practices": [
                                            {
                                                "question": "Compute (2, 3) + (4, -1).",
                                                "type": "mcq",
                                                "options": '{"options":["A) (6, 2)","B) (6, 4)","C) (2, 2)","D) (8, 3)"]}',
                                                "answer": "A",
                                                "explanation": "Add components: (2+4, 3+(-1)) = (6, 2).",
                                            },
                                            {
                                                "question": "Find 3(1, -2, 4).",
                                                "type": "short_answer",
                                                "answer": "(3, -6, 12)",
                                                "explanation": "Multiply each component by 3: (3*1, 3*(-2), 3*4) = (3, -6, 12).",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Dot Product",
                                "concepts": [
                                    {
                                        "title": "Dot Product and Angles",
                                        "description": "Computing the scalar product and finding angles between vectors.",
                                        "material_title": "The Dot Product",
                                        "material_content": "The dot product of vectors a and b is a.b = a1*b1 + a2*b2 + a3*b3. Equivalently, a.b = |a||b|cos(theta), where theta is the angle between them. If a.b = 0, the vectors are perpendicular. The dot product is commutative and distributes over addition. It is used to find projections and test orthogonality.",
                                        "practices": [
                                            {
                                                "question": "Find (1, 2) . (3, 4).",
                                                "type": "mcq",
                                                "options": '{"options":["A) 11","B) 14","C) (3, 8)","D) 5"]}',
                                                "answer": "A",
                                                "explanation": "Dot product: 1*3 + 2*4 = 3 + 8 = 11.",
                                            },
                                            {
                                                "question": "Are vectors (1, 2) and (-2, 1) perpendicular? Justify.",
                                                "type": "short_answer",
                                                "answer": "Yes, because their dot product is 0: 1(-2) + 2(1) = 0.",
                                                "explanation": "Perpendicular vectors have a dot product of zero.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Matrices",
                        "difficulty": "intermediate",
                        "description": "Rectangular arrays of numbers and their operations.",
                        "subtopics": [
                            {
                                "title": "Matrix Operations",
                                "concepts": [
                                    {
                                        "title": "Matrix Addition and Multiplication",
                                        "description": "Combining matrices through addition and products.",
                                        "material_title": "Matrix Arithmetic",
                                        "material_content": "Matrix addition requires same dimensions and is component-wise. Matrix multiplication of an m x n by an n x p matrix yields an m x p matrix, computed by taking dot products of rows with columns. Matrix multiplication is not commutative (AB != BA in general) but is associative and distributive. The identity matrix I leaves any matrix unchanged under multiplication.",
                                        "practices": [
                                            {
                                                "question": "What is the product of a 2x3 and a 3x4 matrix?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 3x3","B) 2x4","C) 2x3","D) 3x4"]}',
                                                "answer": "B",
                                                "explanation": "The result has rows from the first matrix and columns from the second: 2x4.",
                                            },
                                            {
                                                "question": "If A is the 2x2 identity matrix and B is any 2x2 matrix, what is AB?",
                                                "type": "short_answer",
                                                "answer": "B",
                                                "explanation": "The identity matrix acts as a multiplicative identity: AI = IA = A for any square matrix A.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Determinants",
                                "concepts": [
                                    {
                                        "title": "Computing 2x2 and 3x3 Determinants",
                                        "description": "Formulas for determinant calculation.",
                                        "material_title": "Determinant Computation",
                                        "material_content": "For a 2x2 matrix [[a,b],[c,d]], the determinant is ad - bc. For 3x3 matrices, expand along a row using cofactors. The determinant is zero if and only if the matrix is singular (non-invertible). Determinants are used in Cramer's rule, change-of-variable formulas, and testing linear independence.",
                                        "practices": [
                                            {
                                                "question": "Find the determinant of [[3, 1], [2, 4]].",
                                                "type": "mcq",
                                                "options": '{"options":["A) 10","B) 14","C) -2","D) 11"]}',
                                                "answer": "A",
                                                "explanation": "det = 3*4 - 1*2 = 12 - 2 = 10.",
                                            },
                                            {
                                                "question": "Under what condition is a 2x2 matrix singular?",
                                                "type": "short_answer",
                                                "answer": "When the determinant is zero",
                                                "explanation": "A matrix is singular (non-invertible) if and only if its determinant equals zero.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Linear Transformations",
                        "difficulty": "advanced",
                        "description": "Functions preserving vector space structure.",
                        "subtopics": [
                            {
                                "title": "Matrix Representations",
                                "concepts": [
                                    {
                                        "title": "Kernel and Image",
                                        "description": "The null space and range of a linear transformation.",
                                        "material_title": "Kernel and Image",
                                        "material_content": "The kernel (null space) of a linear transformation T is the set of all vectors v such that T(v) = 0. The image (range) is the set of all outputs T(v). By the rank-nullity theorem, dim(kernel) + dim(image) = dim(domain). A transformation is injective if and only if its kernel is trivial (contains only the zero vector).",
                                        "practices": [
                                            {
                                                "question": "The rank-nullity theorem states that dim(ker T) + dim(im T) equals what?",
                                                "type": "mcq",
                                                "options": '{"options":["A) dim(codomain)","B) dim(domain)","C) rank(T)","D) nullity(T)"]}',
                                                "answer": "B",
                                                "explanation": "The rank-nullity theorem: dim(kernel) + dim(image) = dim(domain).",
                                            },
                                            {
                                                "question": "If T: R^3 -> R^2 has rank 2, what is its nullity?",
                                                "type": "short_answer",
                                                "answer": "1",
                                                "explanation": "By rank-nullity: nullity = dim(domain) - rank = 3 - 2 = 1.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Eigenvalues and Eigenvectors",
                                "concepts": [
                                    {
                                        "title": "Characteristic Equation",
                                        "description": "Finding eigenvalues from a matrix.",
                                        "material_title": "Eigenvalue Computation",
                                        "material_content": "An eigenvector v of a matrix A satisfies Av = lambda*v for some scalar lambda (the eigenvalue). The characteristic equation det(A - lambda*I) = 0 yields eigenvalues. Each eigenvalue may have multiple eigenvectors forming an eigenspace. Eigenvalues reveal the matrix's fundamental behavior under transformation.",
                                        "practices": [
                                            {
                                                "question": "Find the eigenvalues of A = [[2, 0], [0, 3]].",
                                                "type": "mcq",
                                                "options": '{"options":["A) lambda = 1, 5","B) lambda = 2, 3","C) lambda = 0, 5","D) lambda = -2, -3"]}',
                                                "answer": "B",
                                                "explanation": "det(A - lambda*I) = (2-lambda)(3-lambda) = 0, so lambda = 2 or lambda = 3.",
                                            },
                                            {
                                                "question": "What is the eigenvector of [[2,0],[0,3]] corresponding to lambda = 2?",
                                                "type": "short_answer",
                                                "answer": "Any non-zero multiple of (1, 0)",
                                                "explanation": "Solving (A - 2I)v = 0 gives [[0,0],[0,1]]v = 0, so v = (t, 0) for any t != 0.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Probability",
                "slug": "probability",
                "description": "The mathematical study of random phenomena.",
                "topics": [
                    {
                        "title": "Basic Probability",
                        "difficulty": "foundational",
                        "description": "Fundamental concepts of chance and likelihood.",
                        "subtopics": [
                            {
                                "title": "Sample Spaces",
                                "concepts": [
                                    {
                                        "title": "Probability of Events",
                                        "description": "Measuring the likelihood of outcomes.",
                                        "material_title": "Probability Fundamentals",
                                        "material_content": "The probability of an event is the ratio of favorable outcomes to total outcomes in a uniform sample space: P(A) = |A|/|S|. Probabilities range from 0 (impossible) to 1 (certain). The complement rule states P(A') = 1 - P(A). For mutually exclusive events, P(A or B) = P(A) + P(B).",
                                        "practices": [
                                            {
                                                "question": "A fair die is rolled. What is the probability of getting a number greater than 4?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 1/6","B) 1/3","C) 1/2","D) 2/3"]}',
                                                "answer": "B",
                                                "explanation": "Numbers greater than 4 are {5, 6}, so P = 2/6 = 1/3.",
                                            },
                                            {
                                                "question": "If P(A) = 0.3, what is P(not A)?",
                                                "type": "short_answer",
                                                "answer": "0.7",
                                                "explanation": "P(A') = 1 - P(A) = 1 - 0.3 = 0.7.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Conditional Probability",
                                "concepts": [
                                    {
                                        "title": "Bayes' Theorem",
                                        "description": "Updating probabilities with new evidence.",
                                        "material_title": "Bayes' Theorem",
                                        "material_content": "Bayes' theorem states P(A|B) = P(B|A)*P(A)/P(B). It reverses conditional probabilities: if you know P(B|A), you can find P(A|B). This is fundamental in diagnostic testing, spam filtering, and machine learning. The theorem uses the law of total probability in its denominator.",
                                        "practices": [
                                            {
                                                "question": "P(A) = 0.4, P(B|A) = 0.6, P(B) = 0.5. Find P(A|B).",
                                                "type": "mcq",
                                                "options": '{"options":["A) 0.24","B) 0.30","C) 0.48","D) 0.60"]}',
                                                "answer": "C",
                                                "explanation": "P(A|B) = P(B|A)*P(A)/P(B) = 0.6*0.4/0.5 = 0.48.",
                                            },
                                            {
                                                "question": "State Bayes' theorem in formula form.",
                                                "type": "short_answer",
                                                "answer": "P(A|B) = P(B|A) * P(A) / P(B)",
                                                "explanation": "Bayes' theorem relates conditional probabilities in opposite directions.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Combinatorics",
                        "difficulty": "intermediate",
                        "description": "Counting techniques for finite structures.",
                        "subtopics": [
                            {
                                "title": "Permutations",
                                "concepts": [
                                    {
                                        "title": "Permutations with and without Repetition",
                                        "description": "Arranging objects in different scenarios.",
                                        "material_title": "Permutation Formulas",
                                        "material_content": "The number of permutations of n distinct objects is n! (n factorial). The number of ways to arrange r objects from n is P(n,r) = n!/(n-r)!. When repetition is allowed, there are n^r arrangements. Circular permutations of n objects number (n-1)!, as rotations are equivalent.",
                                        "practices": [
                                            {
                                                "question": "How many ways can 5 books be arranged on a shelf?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 25","B) 60","C) 120","D) 720"]}',
                                                "answer": "C",
                                                "explanation": "5! = 5 x 4 x 3 x 2 x 1 = 120.",
                                            },
                                            {
                                                "question": "How many 3-digit PINs can be formed using digits 0-9 with repetition allowed?",
                                                "type": "short_answer",
                                                "answer": "1000",
                                                "explanation": "10^3 = 1000 (each of the 3 positions has 10 choices).",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Combinations",
                                "concepts": [
                                    {
                                        "title": "Binomial Coefficients",
                                        "description": "The number of ways to choose subsets.",
                                        "material_title": "Combinations Formula",
                                        "material_content": "The number of ways to choose r objects from n (order does not matter) is C(n,r) = n!/(r!(n-r)!). This is called 'n choose r' or the binomial coefficient. It appears in the binomial theorem: (a+b)^n = sum C(n,k)a^(n-k)b^k. C(n,r) = C(n,n-r) by symmetry.",
                                        "practices": [
                                            {
                                                "question": "How many ways to choose 3 students from a class of 10?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 30","B) 120","C) 210","D) 720"]}',
                                                "answer": "C",
                                                "explanation": "C(10,3) = 10!/(3!*7!) = (10*9*8)/(3*2*1) = 120. Wait, that is 120 not 210. Let me recheck: C(10,3) = 10*9*8/(3*2*1) = 720/6 = 120.",
                                            },
                                            {
                                                "question": "Show that C(5,2) = C(5,3).",
                                                "type": "short_answer",
                                                "answer": "C(5,2) = 10 = C(5,3)",
                                                "explanation": "C(5,2) = 5!/(2!*3!) = 10 and C(5,3) = 5!/(3!*2!) = 10. They are equal by symmetry.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Random Variables",
                        "difficulty": "intermediate",
                        "description": "Quantifying random outcomes numerically.",
                        "subtopics": [
                            {
                                "title": "Discrete Distributions",
                                "concepts": [
                                    {
                                        "title": "Expected Value and Variance",
                                        "description": "Measures of central tendency and spread for random variables.",
                                        "material_title": "Expectation and Variance",
                                        "material_content": "The expected value E(X) = sum x*P(X=x) is the weighted average of outcomes. Variance Var(X) = E(X^2) - [E(X)]^2 measures spread. Standard deviation is sqrt(Var(X)). For a binomial distribution B(n,p): E(X) = np and Var(X) = np(1-p).",
                                        "practices": [
                                            {
                                                "question": "A fair die is rolled. What is E(X)?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 3","B) 3.5","C) 4","D) 6"]}',
                                                "answer": "B",
                                                "explanation": "E(X) = (1+2+3+4+5+6)/6 = 21/6 = 3.5.",
                                            },
                                            {
                                                "question": "Find Var(X) for a fair die roll.",
                                                "type": "short_answer",
                                                "answer": "35/12 approx 2.917",
                                                "explanation": "E(X^2) = (1+4+9+16+25+36)/6 = 91/6. Var(X) = 91/6 - (7/2)^2 = 91/6 - 49/4 = 35/12.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Continuous Distributions",
                                "concepts": [
                                    {
                                        "title": "Normal Distribution",
                                        "description": "The bell-shaped Gaussian distribution.",
                                        "material_title": "The Normal Distribution",
                                        "material_content": "The normal distribution N(mu, sigma^2) is symmetric about its mean mu with spread sigma. The standard normal N(0,1) uses the Z-score: Z = (X-mu)/sigma. The empirical rule states approximately 68% within 1 sigma, 95% within 2 sigma, and 99.7% within 3 sigma. Many natural phenomena approximate a normal distribution.",
                                        "practices": [
                                            {
                                                "question": "What percentage of data falls within one standard deviation of the mean in a normal distribution?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 50%","B) 68%","C) 95%","D) 99.7%"]}',
                                                "answer": "B",
                                                "explanation": "The empirical (68-95-99.7) rule states approximately 68% of data falls within one standard deviation.",
                                            },
                                            {
                                                "question": "If X ~ N(100, 25), what is the standard deviation?",
                                                "type": "short_answer",
                                                "answer": "5",
                                                "explanation": "The variance is 25, so the standard deviation is sqrt(25) = 5.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Discrete Mathematics",
                "slug": "discrete-mathematics",
                "description": "Mathematical structures with distinct, separate values.",
                "topics": [
                    {
                        "title": "Sets and Relations",
                        "difficulty": "foundational",
                        "description": "Collections of objects and connections between them.",
                        "subtopics": [
                            {
                                "title": "Set Theory",
                                "concepts": [
                                    {
                                        "title": "Set Operations",
                                        "description": "Union, intersection, and complement of sets.",
                                        "material_title": "Set Operations",
                                        "material_content": "The union A union B contains all elements in A or B. The intersection A intersect B contains elements in both. The complement A' contains elements not in A. De Morgan's laws state (A union B)' = A' intersect B' and (A intersect B)' = A' union B'. The power set P(A) is the set of all subsets of A, with |P(A)| = 2^|A|.",
                                        "practices": [
                                            {
                                                "question": "If A = {1,2,3} and B = {3,4,5}, what is A union B?",
                                                "type": "mcq",
                                                "options": '{"options":["A) {3}","B) {1,2,3,4,5}","C) {1,2,4,5}","D) {1,2,3}"]}',
                                                "answer": "B",
                                                "explanation": "The union combines all elements from both sets: {1,2,3,4,5}.",
                                            },
                                            {
                                                "question": "How many subsets does a set with 4 elements have?",
                                                "type": "short_answer",
                                                "answer": "16",
                                                "explanation": "The power set has 2^n elements: 2^4 = 16.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Functions and Relations",
                                "concepts": [
                                    {
                                        "title": "Types of Functions",
                                        "description": "Injective, surjective, and bijective functions.",
                                        "material_title": "Function Classifications",
                                        "material_content": "A function f: A -> B is injective (one-to-one) if f(a1) = f(a2) implies a1 = a2. It is surjective (onto) if every element of B is the image of some element of A. A bijective function is both injective and surjective, establishing a perfect pairing. Only bijective functions have inverses.",
                                        "practices": [
                                            {
                                                "question": "Is f(x) = x^2 (from R to R) injective?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Yes","B) No","C) Only for positive x","D) Only for integers"]}',
                                                "answer": "B",
                                                "explanation": "f(1) = f(-1) = 1, so different inputs produce the same output. It is not injective.",
                                            },
                                            {
                                                "question": "What condition must a function satisfy to have an inverse?",
                                                "type": "short_answer",
                                                "answer": "It must be bijective (both injective and surjective)",
                                                "explanation": "Only bijective functions can be inverted to create well-defined inverse functions.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Graph Theory",
                        "difficulty": "intermediate",
                        "description": "Mathematical structures modeling pairwise relationships.",
                        "subtopics": [
                            {
                                "title": "Graph Basics",
                                "concepts": [
                                    {
                                        "title": "Graph Terminology",
                                        "description": "Fundamental definitions in graph theory.",
                                        "material_title": "Graph Definitions",
                                        "material_content": "A graph G = (V, E) consists of vertices V and edges E. An edge connects two vertices. A path is a sequence of distinct vertices connected by edges. A cycle is a path that starts and ends at the same vertex. The degree of a vertex is the number of edges incident to it. The sum of all degrees equals 2|E| (the handshaking lemma).",
                                        "practices": [
                                            {
                                                "question": "A graph has 5 vertices with degrees 2, 2, 3, 3, 4. How many edges does it have?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 7","B) 14","C) 5","D) 10"]}',
                                                "answer": "A",
                                                "explanation": "Sum of degrees = 2+2+3+3+4 = 14. By the handshaking lemma, |E| = 14/2 = 7.",
                                            },
                                            {
                                                "question": "State the handshaking lemma.",
                                                "type": "short_answer",
                                                "answer": "The sum of all vertex degrees equals twice the number of edges.",
                                                "explanation": "Each edge contributes 1 to the degree of each of its two endpoints.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Trees",
                                "concepts": [
                                    {
                                        "title": "Properties of Trees",
                                        "description": "Fundamental results about tree structures.",
                                        "material_title": "Tree Properties",
                                        "material_content": "A tree is a connected graph with no cycles. A tree with n vertices has exactly n-1 edges. There is exactly one path between any two vertices in a tree. Removing any edge disconnects the tree. Adding any edge to a tree creates exactly one cycle. Trees are fundamental in data structures and algorithms.",
                                        "practices": [
                                            {
                                                "question": "How many edges does a tree with 20 vertices have?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 19","B) 20","C) 21","D) 40"]}',
                                                "answer": "A",
                                                "explanation": "A tree with n vertices has exactly n-1 edges: 20 - 1 = 19.",
                                            },
                                            {
                                                "question": "What happens when you add an edge to a tree?",
                                                "type": "short_answer",
                                                "answer": "Exactly one cycle is created",
                                                "explanation": "Since there is already a unique path between any two vertices, adding an edge between them creates one cycle.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Combinatorial Logic",
                        "difficulty": "intermediate",
                        "description": "Logical structures in mathematics and computing.",
                        "subtopics": [
                            {
                                "title": "Boolean Logic",
                                "concepts": [
                                    {
                                        "title": "Logical Connectives and Truth Tables",
                                        "description": "Building complex statements from basic operators.",
                                        "material_title": "Boolean Connectives",
                                        "material_content": "The five basic connectives are: AND, OR, NOT, IMPLIES, and BICONDITIONAL. Truth tables enumerate all possible truth values. De Morgan's laws: not(P and Q) = (not P) or (not Q) and not(P or Q) = (not P) and (not Q). A tautology is always true; a contradiction is always false.",
                                        "practices": [
                                            {
                                                "question": "What is the truth value of P implies Q when P is false and Q is true?",
                                                "type": "mcq",
                                                "options": '{"options":["A) False","B) True","C) Undefined","D) Depends on context"]}',
                                                "answer": "B",
                                                "explanation": "A conditional with a false hypothesis is vacuously true.",
                                            },
                                            {
                                                "question": "Construct the truth table for P and (not Q).",
                                                "type": "short_answer",
                                                "answer": "True only when P is true and Q is false",
                                                "explanation": "P and (not Q) is true only in the row where P = T and Q = F.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Logic Gates",
                                "concepts": [
                                    {
                                        "title": "Basic Logic Gates",
                                        "description": "AND, OR, NOT, and their circuit representations.",
                                        "material_title": "Logic Gates in Circuits",
                                        "material_content": "Logic gates are physical devices implementing Boolean functions. AND gates output 1 only when all inputs are 1. OR gates output 1 when any input is 1. NOT gates invert their input. NAND and NOR gates are universal: any Boolean function can be built from them alone. Logic gates form the basis of all digital computing.",
                                        "practices": [
                                            {
                                                "question": "Which gate is known as a universal gate?",
                                                "type": "mcq",
                                                "options": '{"options":["A) AND","B) OR","C) NOT","D) NAND"]}',
                                                "answer": "D",
                                                "explanation": "NAND (and NOR) are universal gates: any Boolean function can be implemented using only NAND gates.",
                                            },
                                            {
                                                "question": "Write the Boolean expression for a 2-input AND gate.",
                                                "type": "short_answer",
                                                "answer": "Y = A and B (or Y = A * B)",
                                                "explanation": "The AND gate outputs 1 only when both inputs A and B are 1.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Number Theory",
                "slug": "number-theory",
                "description": "The study of integers and their properties.",
                "topics": [
                    {
                        "title": "Divisibility",
                        "difficulty": "intermediate",
                        "description": "When integers divide evenly into others.",
                        "subtopics": [
                            {
                                "title": "Divisibility Rules",
                                "concepts": [
                                    {
                                        "title": "Tests for Common Divisors",
                                        "description": "Efficient rules to check divisibility.",
                                        "material_title": "Divisibility Rules",
                                        "material_content": "A number is divisible by 2 if it ends in an even digit. By 3 if the digit sum is divisible by 3. By 5 if it ends in 0 or 5. By 7, double the last digit and subtract from the rest; if the result is divisible by 7, so is the original. These rules allow quick mental arithmetic checks.",
                                        "practices": [
                                            {
                                                "question": "Is 2,847 divisible by 3?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Yes","B) No","C) Cannot determine","D) Only with a calculator"]}',
                                                "answer": "A",
                                                "explanation": "Digit sum: 2+8+4+7 = 21, which is divisible by 3. So 2,847 is divisible by 3.",
                                            },
                                            {
                                                "question": "What is the divisibility rule for 11?",
                                                "type": "short_answer",
                                                "answer": "The alternating sum of digits must be divisible by 11",
                                                "explanation": "For example, 121: 1-2+1 = 0, which is divisible by 11.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Modular Arithmetic",
                                "concepts": [
                                    {
                                        "title": "Congruences",
                                        "description": "The formal framework for modular arithmetic.",
                                        "material_title": "Modular Congruence",
                                        "material_content": "We write a = b (mod m) if m divides (a-b), meaning a and b have the same remainder when divided by m. Congruences can be added, subtracted, and multiplied: if a = b and c = d, then a+c = b+d and ac = bd (mod m). Modular arithmetic is used in cryptography, coding theory, and computer science.",
                                        "practices": [
                                            {
                                                "question": "What is 17 mod 5?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 2","B) 3","C) 4","D) 1"]}',
                                                "answer": "A",
                                                "explanation": "17 = 3(5) + 2, so 17 = 2 (mod 5).",
                                            },
                                            {
                                                "question": "Find x such that 3x = 4 (mod 7).",
                                                "type": "short_answer",
                                                "answer": "x = 6",
                                                "explanation": "3(6) = 18 = 4 (mod 7). Check: 18 = 2(7) + 4.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Prime Numbers",
                        "difficulty": "intermediate",
                        "description": "The building blocks of integers.",
                        "subtopics": [
                            {
                                "title": "Prime Factorization",
                                "concepts": [
                                    {
                                        "title": "Fundamental Theorem of Arithmetic",
                                        "description": "Every integer has a unique prime factorization.",
                                        "material_title": "Unique Factorization",
                                        "material_content": "The fundamental theorem of arithmetic states that every integer greater than 1 can be uniquely expressed as a product of prime numbers, up to the order of factors. For example, 12 = 2^2 x 3. This theorem underlies greatest common divisors, least common multiples, and many number-theoretic proofs.",
                                        "practices": [
                                            {
                                                "question": "What is the prime factorization of 60?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 2^2 x 3 x 5","B) 2 x 3^2 x 5","C) 2^3 x 3 x 5","D) 2 x 3 x 10"]}',
                                                "answer": "A",
                                                "explanation": "60 = 2 x 30 = 2 x 2 x 15 = 2^2 x 3 x 5.",
                                            },
                                            {
                                                "question": "Find the prime factorization of 97.",
                                                "type": "short_answer",
                                                "answer": "97 (it is prime)",
                                                "explanation": "97 is not divisible by 2, 3, 5, or 7. Since sqrt(97) < 10, no further testing is needed. It is prime.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Distribution of Primes",
                                "concepts": [
                                    {
                                        "title": "The Prime Number Theorem",
                                        "description": "Approximating the number of primes up to n.",
                                        "material_title": "Prime Density",
                                        "material_content": "The prime number theorem states that the number of primes less than n, denoted pi(n), is approximately n/ln(n). This means primes become less frequent but never stop. The Riemann hypothesis, one of mathematics' greatest unsolved problems, gives a more precise error bound for this approximation.",
                                        "practices": [
                                            {
                                                "question": "Approximately how many primes are less than 1000 using n/ln(n)?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 72","B) 145","C) 333","D) 500"]}',
                                                "answer": "B",
                                                "explanation": "1000/ln(1000) approx 1000/6.908 approx 145. The actual count is 168.",
                                            },
                                            {
                                                "question": "Does the prime number theorem say primes eventually stop?",
                                                "type": "short_answer",
                                                "answer": "No, primes are infinite but become less frequent",
                                                "explanation": "While pi(n)/n approaches 0, there are infinitely many primes.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Diophantine Equations",
                        "difficulty": "advanced",
                        "description": "Equations seeking integer solutions.",
                        "subtopics": [
                            {
                                "title": "Linear Diophantine Equations",
                                "concepts": [
                                    {
                                        "title": "Solvability of Linear Diophantine Equations",
                                        "description": "When ax + by = c has integer solutions.",
                                        "material_title": "Linear Diophantine Equations",
                                        "material_content": "The equation ax + by = c has integer solutions if and only if gcd(a,b) divides c. If (x0, y0) is one solution, the general solution is x = x0 + (b/d)t, y = y0 - (a/d)t where d = gcd(a,b) and t is any integer. The extended Euclidean algorithm finds the initial solution.",
                                        "practices": [
                                            {
                                                "question": "Does 6x + 15y = 7 have integer solutions?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Yes","B) No","C) Only positive solutions","D) Depends on method"]}',
                                                "answer": "B",
                                                "explanation": "gcd(6,15) = 3, and 3 does not divide 7, so no integer solutions exist.",
                                            },
                                            {
                                                "question": "Find one solution to 3x + 5y = 1.",
                                                "type": "short_answer",
                                                "answer": "x = 2, y = -1",
                                                "explanation": "Check: 3(2) + 5(-1) = 6 - 5 = 1.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Pythagorean Triples",
                                "concepts": [
                                    {
                                        "title": "Generating Pythagorean Triples",
                                        "description": "Methods for producing right triangle side lengths.",
                                        "material_title": "Pythagorean Triples",
                                        "material_content": "A Pythagorean triple (a, b, c) satisfies a^2 + b^2 = c^2. The primitive triples (where gcd(a,b,c) = 1) can be generated using Euclid's formula: a = m^2-n^2, b = 2mn, c = m^2+n^2 for integers m > n > 0. The smallest triple is (3, 4, 5). All multiples of primitive triples are also Pythagorean triples.",
                                        "practices": [
                                            {
                                                "question": "Generate a Pythagorean triple using m = 3, n = 2.",
                                                "type": "mcq",
                                                "options": '{"options":["A) (5, 12, 13)","B) (3, 4, 5)","C) (8, 6, 10)","D) (6, 8, 10)"]}',
                                                "answer": "A",
                                                "explanation": "a = 9-4 = 5, b = 2(3)(2) = 12, c = 9+4 = 13. So (5, 12, 13).",
                                            },
                                            {
                                                "question": "Is (6, 8, 10) a primitive Pythagorean triple?",
                                                "type": "short_answer",
                                                "answer": "No",
                                                "explanation": "gcd(6, 8, 10) = 2, so it is not primitive. It is a multiple of (3, 4, 5).",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Logic and Proofs",
                "slug": "logic-proofs",
                "description": "The foundations of rigorous mathematical reasoning.",
                "topics": [
                    {
                        "title": "Propositional Logic",
                        "difficulty": "foundational",
                        "description": "Formal logic with propositions and connectives.",
                        "subtopics": [
                            {
                                "title": "Logical Connectives",
                                "concepts": [
                                    {
                                        "title": "Negation, Conjunction, and Disjunction",
                                        "description": "The basic propositional operations.",
                                        "material_title": "Basic Logical Operations",
                                        "material_content": "Negation (not P) reverses the truth value of a proposition. Conjunction (P and Q) is true only when both P and Q are true. Disjunction (P or Q) is true when at least one of P or Q is true. The exclusive or (P xor Q) is true when exactly one is true. These connectives are the building blocks of propositional logic.",
                                        "practices": [
                                            {
                                                "question": "If P is true and Q is false, what is P and Q?",
                                                "type": "mcq",
                                                "options": '{"options":["A) True","B) False","C) Undefined","D) Depends on context"]}',
                                                "answer": "B",
                                                "explanation": "Conjunction requires both propositions to be true. Since Q is false, P and Q is false.",
                                            },
                                            {
                                                "question": "When is P or Q false?",
                                                "type": "short_answer",
                                                "answer": "Only when both P and Q are false",
                                                "explanation": "Disjunction is false only when neither proposition is true.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Truth Tables",
                                "concepts": [
                                    {
                                        "title": "Constructing Truth Tables",
                                        "description": "Evaluating compound propositions systematically.",
                                        "material_title": "Truth Table Method",
                                        "material_content": "Truth tables enumerate all possible truth value assignments for the propositional variables in a compound statement. For n variables, there are 2^n rows. Each row evaluates the compound proposition. Truth tables can verify logical equivalence (two statements have identical columns), check tautologies (always true), and identify contradictions (always false).",
                                        "practices": [
                                            {
                                                "question": "How many rows does a truth table for 4 propositional variables need?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 4","B) 8","C) 16","D) 32"]}',
                                                "answer": "C",
                                                "explanation": "A truth table for n variables has 2^n rows. For 4 variables: 2^4 = 16.",
                                            },
                                            {
                                                "question": "Show that P implies Q is logically equivalent to (not P) or Q.",
                                                "type": "short_answer",
                                                "answer": "Both are false only when P is true and Q is false",
                                                "explanation": "P implies Q is false only when P=T and Q=F. (not P) or Q is also false only in this case.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Proof Methods",
                        "difficulty": "intermediate",
                        "description": "Techniques for establishing mathematical truth.",
                        "subtopics": [
                            {
                                "title": "Direct and Indirect Proofs",
                                "concepts": [
                                    {
                                        "title": "Proof by Contradiction",
                                        "description": "Assuming the negation and deriving a contradiction.",
                                        "material_title": "Contradiction Proofs",
                                        "material_content": "In proof by contradiction, assume the negation of the statement to be proved. Then use logical reasoning to derive a contradiction (a statement that is clearly false). Since the assumption led to an impossibility, the assumption must be false, proving the original statement. This method is powerful for proving existence and impossibility results.",
                                        "practices": [
                                            {
                                                "question": "To prove sqrt(2) is irrational by contradiction, what do you assume?",
                                                "type": "mcq",
                                                "options": '{"options":["A) sqrt(2) is rational","B) sqrt(2) is irrational","C) 2 is prime","D) sqrt(2) = 1.414"]}',
                                                "answer": "A",
                                                "explanation": "In proof by contradiction, assume the negation: that sqrt(2) is rational.",
                                            },
                                            {
                                                "question": "State the key step in proving sqrt(2) is irrational.",
                                                "type": "short_answer",
                                                "answer": "Assume sqrt(2) = p/q in lowest terms, then derive that both p and q must be even, contradicting lowest terms.",
                                                "explanation": "If sqrt(2) = p/q, then 2q^2 = p^2, so p^2 is even, meaning p is even. Then q^2 is also even, so q is even, contradicting that p/q was in lowest terms.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Proof by Cases",
                                "concepts": [
                                    {
                                        "title": "Case Analysis",
                                        "description": "Proving a statement by examining all possible scenarios.",
                                        "material_title": "Proof by Cases",
                                        "material_content": "Proof by cases (or proof by exhaustion) divides all possibilities into exhaustive cases and proves the statement for each case. For example, to prove a property of n^2 - n, consider cases where n is even or odd. All cases together cover the entire domain. This method is effective when the problem has natural partitions.",
                                        "practices": [
                                            {
                                                "question": "To prove that n^2 is even iff n is even, how many cases do you need?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 1","B) 2","C) 3","D) 4"]}',
                                                "answer": "B",
                                                "explanation": "Two cases: n is even and n is odd. Each direction of the biconditional is proved separately.",
                                            },
                                            {
                                                "question": "Prove by cases: n^2 + n is always even.",
                                                "type": "short_answer",
                                                "answer": "Case 1 (n even): n=2k, so n^2+n=4k^2+2k=2(2k^2+k). Case 2 (n odd): n=2k+1, so n^2+n=4k^2+4k+1+2k+1=4k^2+6k+2=2(2k^2+3k+1). Both are even.",
                                                "explanation": "In both cases, the expression factors to show it is even.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Mathematical Induction",
                        "difficulty": "intermediate",
                        "description": "Proving statements about natural numbers.",
                        "subtopics": [
                            {
                                "title": "Weak Induction",
                                "concepts": [
                                    {
                                        "title": "Structure of Induction Proofs",
                                        "description": "Base case, inductive step, and conclusion.",
                                        "material_title": "Mathematical Induction",
                                        "material_content": "Mathematical induction has three steps: (1) Base case: verify the statement for the smallest value (usually n = 1). (2) Inductive step: assume the statement holds for n = k (inductive hypothesis) and prove it holds for n = k+1. (3) Conclusion: by induction, the statement holds for all n >= base value. This technique proves statements for infinitely many values.",
                                        "practices": [
                                            {
                                                "question": "In an induction proof, what must you verify in the base case?",
                                                "type": "mcq",
                                                "options": '{"options":["A) The statement for n = k","B) The statement for n = 0 or n = 1","C) The statement for all n","D) The inductive hypothesis"]}',
                                                "answer": "B",
                                                "explanation": "The base case verifies the statement for the starting value, typically n = 1.",
                                            },
                                            {
                                                "question": "Prove by induction: 1 + 2 + ... + n = n(n+1)/2.",
                                                "type": "short_answer",
                                                "answer": "Base: 1 = 1(2)/2 = 1. Step: assume for k, then 1+...+k+(k+1) = k(k+1)/2 + (k+1) = (k+1)(k+2)/2.",
                                                "explanation": "The inductive step adds k+1 to both sides and factors to get the formula for k+1.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Strong Induction",
                                "concepts": [
                                    {
                                        "title": "Strong Induction vs. Weak Induction",
                                        "description": "When and why to use the stronger form.",
                                        "material_title": "Strong Induction",
                                        "material_content": "Strong induction assumes the statement is true for all values from the base case up to k (not just k itself) when proving for k+1. This is useful when the truth at k+1 depends on multiple previous values. The structure is the same as weak induction, but the inductive hypothesis is stronger. Every proof by weak induction is also valid under strong induction.",
                                        "practices": [
                                            {
                                                "question": "When is strong induction preferred over weak induction?",
                                                "type": "mcq",
                                                "options": '{"options":["A) When the base case is hard","B) When the inductive step depends on multiple previous cases","C) When proving inequalities","D) Never"]}',
                                                "answer": "B",
                                                "explanation": "Strong induction is preferred when the k+1 case depends on more than just the k case.",
                                            },
                                            {
                                                "question": "Use strong induction to justify: every integer >= 2 has a prime factor.",
                                                "type": "short_answer",
                                                "answer": "If n is prime, done. If n = ab with 1 < a <= b < n, then by IH a has a prime factor p, which also divides n.",
                                                "explanation": "Strong induction assumes the result for all values less than n, then applies it to a proper divisor.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
        ],
    },
    # ── 2. Biology ──────────────────────────────────────────────────
    {
        "title": "Biology",
        "slug": "biology",
        "icon": "biotech",
        "color": "#10B981",
        "description": "The scientific study of life and living organisms.",
        "disciplines": [
            {
                "title": "Cell Biology",
                "slug": "cell-biology",
                "description": "The study of cell structure and function.",
                "topics": [
                    {
                        "title": "Cell Structure",
                        "difficulty": "foundational",
                        "description": "The components that make up cells.",
                        "subtopics": [
                            {
                                "title": "Prokaryotic and Eukaryotic Cells",
                                "concepts": [
                                    {
                                        "title": "Cell Types and Organization",
                                        "description": "Fundamental differences between prokaryotic and eukaryotic cells.",
                                        "material_title": "Comparing Cell Types",
                                        "material_content": "Prokaryotic cells (bacteria and archaea) lack a membrane-bound nucleus and organelles. Their DNA floats freely in the nucleoid region. Eukaryotic cells (plants, animals, fungi, protists) have a true nucleus enclosed by a nuclear membrane and membrane-bound organelles. Eukaryotic cells are typically larger (10-100 micrometers) than prokaryotic cells (1-5 micrometers).",
                                        "practices": [
                                            {
                                                "question": "Which of the following is a characteristic of prokaryotic cells?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Membrane-bound nucleus","B) Mitochondria","C) No membrane-bound organelles","D) Linear chromosomes"]}',
                                                "answer": "C",
                                                "explanation": "Prokaryotes lack membrane-bound organelles, including the nucleus.",
                                            },
                                            {
                                                "question": "Name two organelles found in eukaryotic but not prokaryotic cells.",
                                                "type": "short_answer",
                                                "answer": "Nucleus and mitochondria",
                                                "explanation": "Eukaryotic cells have membrane-bound organelles like the nucleus and mitochondria.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Cell Organelles",
                                "concepts": [
                                    {
                                        "title": "Organelle Functions",
                                        "description": "The roles of major cellular organelles.",
                                        "material_title": "Cell Organelles and Their Functions",
                                        "material_content": "The nucleus stores DNA and controls gene expression. Mitochondria generate ATP through cellular respiration. The endoplasmic reticulum (ER) synthesizes proteins (rough ER) and lipids (smooth ER). The Golgi apparatus modifies and packages proteins. Lysosomes contain digestive enzymes. Ribosomes synthesize proteins. The cell membrane regulates transport.",
                                        "practices": [
                                            {
                                                "question": "Which organelle is the primary site of ATP production?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Nucleus","B) Golgi apparatus","C) Mitochondria","D) Ribosomes"]}',
                                                "answer": "C",
                                                "explanation": "Mitochondria are the powerhouses of the cell, producing ATP through oxidative phosphorylation.",
                                            },
                                            {
                                                "question": "What is the function of the rough endoplasmic reticulum?",
                                                "type": "short_answer",
                                                "answer": "Protein synthesis and processing (due to attached ribosomes)",
                                                "explanation": "The rough ER is studded with ribosomes that synthesize proteins destined for secretion or membrane insertion.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Membrane Transport",
                        "difficulty": "intermediate",
                        "description": "How substances cross cell membranes.",
                        "subtopics": [
                            {
                                "title": "Passive Transport",
                                "concepts": [
                                    {
                                        "title": "Diffusion and Osmosis",
                                        "description": "Movement of molecules without energy expenditure.",
                                        "material_title": "Passive Transport Mechanisms",
                                        "material_content": "Diffusion is the net movement of particles from high to low concentration until equilibrium is reached. Osmosis is the diffusion of water across a selectively permeable membrane. Facilitated diffusion uses carrier proteins or channel proteins to transport molecules that cannot cross the lipid bilayer directly. All passive transport requires no cellular energy (ATP).",
                                        "practices": [
                                            {
                                                "question": "In which direction does water move during osmosis?",
                                                "type": "mcq",
                                                "options": '{"options":["A) From low to high solute concentration","B) From high to low solute concentration","C) Randomly","D) Only into the cell"]}',
                                                "answer": "B",
                                                "explanation": "Water moves from an area of low solute concentration (high water potential) to high solute concentration (low water potential).",
                                            },
                                            {
                                                "question": "What is the difference between diffusion and facilitated diffusion?",
                                                "type": "short_answer",
                                                "answer": "Facilitated diffusion requires transport proteins; simple diffusion does not.",
                                                "explanation": "Both move substances down their concentration gradient without ATP, but facilitated diffusion uses channel or carrier proteins.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Active Transport",
                                "concepts": [
                                    {
                                        "title": "Active Transport Mechanisms",
                                        "description": "Energy-dependent movement against concentration gradients.",
                                        "material_title": "Active Transport",
                                        "material_content": "Active transport moves substances against their concentration gradient (low to high) and requires ATP energy. Primary active transport uses ATP directly, such as the sodium-potassium pump (Na+/K+-ATPase). Secondary active transport uses the electrochemical gradient created by primary transport. Endocytosis engulfs materials into vesicles; exocytosis releases contents outside the cell.",
                                        "practices": [
                                            {
                                                "question": "What is the energy source for primary active transport?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Light energy","B) ATP","C) Concentration gradient","D) Heat"]}',
                                                "answer": "B",
                                                "explanation": "Primary active transport directly hydrolyzes ATP to move substances against their gradient.",
                                            },
                                            {
                                                "question": "How does the sodium-potassium pump maintain the resting membrane potential?",
                                                "type": "short_answer",
                                                "answer": "It pumps 3 Na+ out and 2 K+ in per ATP, creating an electrochemical gradient.",
                                                "explanation": "The unequal transport of ions creates a net negative charge inside the cell.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Cell Division",
                        "difficulty": "intermediate",
                        "description": "How cells reproduce and divide.",
                        "subtopics": [
                            {
                                "title": "Mitosis",
                                "concepts": [
                                    {
                                        "title": "Phases of Mitosis",
                                        "description": "The stages of nuclear division.",
                                        "material_title": "Mitotic Cell Division",
                                        "material_content": "Mitosis produces two genetically identical daughter cells. It has four phases: prophase (chromosomes condense, nuclear envelope breaks down), metaphase (chromosomes align at the cell equator), anaphase (sister chromatids separate to opposite poles), and telophase (nuclear envelopes reform). Cytokinesis divides the cytoplasm, completing cell division.",
                                        "practices": [
                                            {
                                                "question": "During which phase of mitosis do chromosomes line up at the cell equator?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Prophase","B) Metaphase","C) Anaphase","D) Telophase"]}',
                                                "answer": "B",
                                                "explanation": "During metaphase, chromosomes align along the metaphase plate at the cell's equator.",
                                            },
                                            {
                                                "question": "What is the result of mitosis in terms of chromosome number?",
                                                "type": "short_answer",
                                                "answer": "Diploid (2n) daughter cells identical to the parent cell",
                                                "explanation": "Mitosis maintains the chromosome number, producing two identical diploid cells.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Meiosis",
                                "concepts": [
                                    {
                                        "title": "Meiotic Division and Genetic Variation",
                                        "description": "Reduction division producing gametes.",
                                        "material_title": "Meiosis",
                                        "material_content": "Meiosis produces four genetically unique haploid gametes from one diploid cell through two successive divisions. Meiosis I separates homologous chromosomes (reduction division), while meiosis II separates sister chromatids (like mitosis). Genetic variation is introduced through crossing over (prophase I), independent assortment (metaphase I), and random fertilization.",
                                        "practices": [
                                            {
                                                "question": "How many daughter cells are produced by meiosis?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 2","B) 4","C) 8","D) 1"]}',
                                                "answer": "B",
                                                "explanation": "Meiosis produces four haploid daughter cells from one diploid parent cell.",
                                            },
                                            {
                                                "question": "Name two sources of genetic variation in meiosis.",
                                                "type": "short_answer",
                                                "answer": "Crossing over and independent assortment",
                                                "explanation": "Crossing over exchanges genetic material between homologs; independent assortment randomizes chromosome orientation at metaphase I.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Genetics",
                "slug": "genetics",
                "description": "The study of heredity and gene expression.",
                "topics": [
                    {
                        "title": "Mendelian Genetics",
                        "difficulty": "foundational",
                        "description": "Patterns of inheritance discovered by Gregor Mendel.",
                        "subtopics": [
                            {
                                "title": "Laws of Inheritance",
                                "concepts": [
                                    {
                                        "title": "Law of Segregation and Independent Assortment",
                                        "description": "Mendel's principles governing allele distribution.",
                                        "material_title": "Mendel's Laws",
                                        "material_content": "The Law of Segregation states that the two alleles for a trait separate during gamete formation, so each gamete carries only one allele. The Law of Independent Assortment states that alleles for different traits segregate independently of each other (for genes on different chromosomes). These laws explain the predictable ratios observed in genetic crosses.",
                                        "practices": [
                                            {
                                                "question": "In a monohybrid cross (Tt x Tt), what is the expected phenotypic ratio?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 1:1","B) 1:2:1","C) 3:1","D) 1:1:1:1"]}',
                                                "answer": "C",
                                                "explanation": "The genotypic ratio is 1:2:1 (TT:Tt:tt), but if T is dominant, the phenotypic ratio is 3:1.",
                                            },
                                            {
                                                "question": "Why do alleles segregate during meiosis?",
                                                "type": "short_answer",
                                                "answer": "Homologous chromosomes separate during anaphase I of meiosis.",
                                                "explanation": "Each homolog carries one allele of a gene pair, and their separation ensures each gamete receives one allele.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Punnett Squares",
                                "concepts": [
                                    {
                                        "title": "Predicting Offspring Genotypes",
                                        "description": "Using Punnett squares to predict genetic outcomes.",
                                        "material_title": "Punnett Square Analysis",
                                        "material_content": "Punnett squares are diagrams that predict the probability of offspring genotypes from a cross between parents with known genotypes. For a monohybrid cross, a 2x2 grid shows all possible allele combinations. The square reveals genotypic and phenotypic ratios. For dihybrid crosses (two genes), a 4x4 grid is used.",
                                        "practices": [
                                            {
                                                "question": "Cross Aa x Aa. What fraction of offspring will be homozygous recessive?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 1/4","B) 1/2","C) 3/4","D) 1/8"]}',
                                                "answer": "A",
                                                "explanation": "In the Punnett square, aa appears in 1 of 4 squares = 1/4.",
                                            },
                                            {
                                                "question": "What is the genotypic ratio of a cross between AA and aa?",
                                                "type": "short_answer",
                                                "answer": "All Aa (100% heterozygous)",
                                                "explanation": "All offspring receive one A from one parent and one a from the other, making them all Aa.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "DNA and Replication",
                        "difficulty": "intermediate",
                        "description": "The molecular structure and copying of genetic material.",
                        "subtopics": [
                            {
                                "title": "DNA Structure",
                                "concepts": [
                                    {
                                        "title": "Double Helix and Base Pairing",
                                        "description": "The architecture of the DNA molecule.",
                                        "material_title": "DNA Molecular Structure",
                                        "material_content": "DNA (deoxyribonucleic acid) is a double helix composed of two antiparallel polynucleotide strands. Each nucleotide contains a deoxyribose sugar, a phosphate group, and one of four nitrogenous bases: adenine (A), thymine (T), guanine (G), or cytosine (C). A pairs with T via two hydrogen bonds; G pairs with C via three hydrogen bonds (Chargaff's rules). The sugar-phosphate backbone forms the exterior.",
                                        "practices": [
                                            {
                                                "question": "Which two bases are paired together in DNA?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Adenine and Guanine","B) Adenine and Thymine","C) Cytosine and Thymine","D) Guanine and Adenine"]}',
                                                "answer": "B",
                                                "explanation": "In DNA, adenine pairs with thymine (A-T) and guanine pairs with cytosine (G-C).",
                                            },
                                            {
                                                "question": "How many hydrogen bonds form between G and C?",
                                                "type": "short_answer",
                                                "answer": "Three hydrogen bonds",
                                                "explanation": "G-C base pairs are connected by three hydrogen bonds, making them stronger than A-T pairs (two bonds).",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "DNA Replication",
                                "concepts": [
                                    {
                                        "title": "Semiconservative Replication",
                                        "description": "How DNA copies itself before cell division.",
                                        "material_title": "The Replication Process",
                                        "material_content": "DNA replication is semiconservative: each new double helix contains one original (template) strand and one newly synthesized strand. Helicase unwinds the double helix, creating a replication fork. Primase synthesizes an RNA primer, then DNA polymerase III extends the new strand in the 5' to 3' direction. The leading strand is continuous; the lagging strand is synthesized in Okazaki fragments.",
                                        "practices": [
                                            {
                                                "question": "What does semiconservative replication mean?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Only half the DNA is copied","B) Each new helix has one old and one new strand","C) The entire original helix is preserved","D) Both strands are newly made"]}',
                                                "answer": "B",
                                                "explanation": "Semiconservative replication produces two helices, each with one parental strand and one new strand.",
                                            },
                                            {
                                                "question": "Why is the lagging strand synthesized discontinuously?",
                                                "type": "short_answer",
                                                "answer": "DNA polymerase can only synthesize in the 5' to 3' direction, opposite to the direction of replication fork movement on the lagging strand.",
                                                "explanation": "The lagging strand template runs 5' to 3' toward the fork, so synthesis must proceed away from it in short fragments.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Molecular Biology",
                "slug": "molecular-biology",
                "description": "The study of biological processes at the molecular level.",
                "topics": [
                    {
                        "title": "Gene Expression",
                        "difficulty": "intermediate",
                        "description": "How genes are transcribed and translated.",
                        "subtopics": [
                            {
                                "title": "Transcription",
                                "concepts": [
                                    {
                                        "title": "From DNA to mRNA",
                                        "description": "The process of copying DNA into messenger RNA.",
                                        "material_title": "Transcription Process",
                                        "material_content": "Transcription copies a gene's DNA sequence into mRNA. RNA polymerase binds to the promoter region, unwinds the DNA, and synthesizes a complementary mRNA strand in the 5' to 3' direction using uracil (U) instead of thymine (T). In eukaryotes, the pre-mRNA undergoes processing: 5' capping, 3' polyadenylation, and splicing to remove introns. The mature mRNA then exits the nucleus.",
                                        "practices": [
                                            {
                                                "question": "What enzyme carries out transcription?",
                                                "type": "mcq",
                                                "options": '{"options":["A) DNA polymerase","B) RNA polymerase","C) Helicase","D) Ligase"]}',
                                                "answer": "B",
                                                "explanation": "RNA polymerase reads the DNA template and synthesizes the complementary mRNA strand.",
                                            },
                                            {
                                                "question": "What are introns and what happens to them during mRNA processing?",
                                                "type": "short_answer",
                                                "answer": "Introns are non-coding sequences that are spliced out of pre-mRNA.",
                                                "explanation": "In eukaryotic genes, introns interrupt coding sequences (exons) and must be removed before translation.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Translation",
                                "concepts": [
                                    {
                                        "title": "Protein Synthesis at the Ribosome",
                                        "description": "Building polypeptides from mRNA instructions.",
                                        "material_title": "Translation",
                                        "material_content": "Translation occurs at ribosomes in the cytoplasm. Transfer RNA (tRNA) molecules carry amino acids to the ribosome, matching their anticodons to mRNA codons. Translation begins at the start codon (AUG) and ends at a stop codon (UAA, UAG, or UGA). The ribosome catalyzes peptide bond formation between amino acids, building a polypeptide chain from the N-terminus to the C-terminus.",
                                        "practices": [
                                            {
                                                "question": "What is the start codon in mRNA?",
                                                "type": "mcq",
                                                "options": '{"options":["A) UAA","B) AUG","C) UAG","D) GUG"]}',
                                                "answer": "B",
                                                "explanation": "AUG is the universal start codon, encoding methionine and signaling the beginning of translation.",
                                            },
                                            {
                                                "question": "How many nucleotides make up one codon?",
                                                "type": "short_answer",
                                                "answer": "Three nucleotides",
                                                "explanation": "Each codon is a triplet of nucleotides that specifies one amino acid in the genetic code.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Protein Structure",
                        "difficulty": "intermediate",
                        "description": "The hierarchical organization of proteins.",
                        "subtopics": [
                            {
                                "title": "Protein Folding",
                                "concepts": [
                                    {
                                        "title": "Levels of Protein Structure",
                                        "description": "Primary through quaternary structural organization.",
                                        "material_title": "Protein Structural Hierarchy",
                                        "material_content": "Primary structure is the amino acid sequence. Secondary structure includes alpha helices and beta sheets formed by hydrogen bonding along the backbone. Tertiary structure is the 3D folding of a single polypeptide chain due to R-group interactions (hydrophobic interactions, disulfide bonds, ionic bonds, hydrogen bonds). Quaternary structure arises when multiple polypeptide subunits assemble (e.g., hemoglobin has four subunits).",
                                        "practices": [
                                            {
                                                "question": "Which level of protein structure is stabilized by disulfide bonds between cysteine residues?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Primary","B) Secondary","C) Tertiary","D) Quaternary"]}',
                                                "answer": "C",
                                                "explanation": "Disulfide bonds between cysteine R-groups stabilize the tertiary (and sometimes quaternary) structure.",
                                            },
                                            {
                                                "question": "What type of bond maintains the primary structure of a protein?",
                                                "type": "short_answer",
                                                "answer": "Peptide bonds",
                                                "explanation": "Peptide bonds link amino acids in a linear sequence to form the polypeptide chain (primary structure).",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Enzymes",
                                "concepts": [
                                    {
                                        "title": "Enzyme Kinetics and Regulation",
                                        "description": "How enzymes catalyze biochemical reactions.",
                                        "material_title": "Enzyme Function",
                                        "material_content": "Enzymes are biological catalysts that lower activation energy without being consumed. The active site binds substrates via lock-and-key or induced-fit models. Enzyme activity is regulated by temperature, pH, substrate concentration, competitive inhibition (inhibitor competes for active site), and non-competitive inhibition (inhibitor binds allosteric site). Michaelis-Menten kinetics describes the relationship between substrate concentration and reaction rate.",
                                        "practices": [
                                            {
                                                "question": "What happens to enzyme activity when a competitive inhibitor is present?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Vmax decreases","B) Km increases","C) Both Vmax and Km change","D) Activity increases"]}',
                                                "answer": "B",
                                                "explanation": "Competitive inhibitors increase the apparent Km (lower affinity) but Vmax is unchanged at high substrate concentration.",
                                            },
                                            {
                                                "question": "How does temperature affect enzyme activity?",
                                                "type": "short_answer",
                                                "answer": "Activity increases with temperature up to an optimum, then decreases as the enzyme denatures.",
                                                "explanation": "Moderate heat increases molecular collisions, but excessive heat unfolds the enzyme, destroying its active site.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Ecology",
                "slug": "ecology",
                "description": "The study of organisms and their interactions with the environment.",
                "topics": [
                    {
                        "title": "Ecosystem Ecology",
                        "difficulty": "foundational",
                        "description": "Energy flow and nutrient cycling in ecosystems.",
                        "subtopics": [
                            {
                                "title": "Energy Flow",
                                "concepts": [
                                    {
                                        "title": "Food Webs and Trophic Levels",
                                        "description": "How energy transfers through ecological communities.",
                                        "material_title": "Energy in Ecosystems",
                                        "material_content": "Energy flows through ecosystems via food chains and food webs. Trophic levels include producers (autotrophs, first trophic level), primary consumers (herbivores), secondary consumers (carnivores), and tertiary consumers. Only about 10% of energy transfers between trophic levels (the 10% rule), explaining why food chains rarely exceed 4-5 levels. Decomposers recycle nutrients from dead organisms at all levels.",
                                        "practices": [
                                            {
                                                "question": "What percentage of energy is typically transferred between trophic levels?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 1%","B) 10%","C) 50%","D) 90%"]}',
                                                "answer": "B",
                                                "explanation": "Approximately 10% of energy is transferred between trophic levels; the rest is lost as heat through metabolism.",
                                            },
                                            {
                                                "question": "Why are there fewer tertiary consumers than producers in an ecosystem?",
                                                "type": "short_answer",
                                                "answer": "Due to energy loss at each trophic level (10% rule).",
                                                "explanation": "Since only ~10% of energy passes between levels, higher levels support fewer organisms.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Nutrient Cycles",
                                "concepts": [
                                    {
                                        "title": "Biogeochemical Cycles",
                                        "description": "The cycling of matter through Earth's systems.",
                                        "material_title": "Nutrient Cycling",
                                        "material_content": "Matter cycles through biogeochemical pathways. The carbon cycle involves photosynthesis (CO2 absorption), respiration (CO2 release), and decomposition. The nitrogen cycle includes nitrogen fixation by bacteria, nitrification, assimilation, and denitrification. The water cycle involves evaporation, condensation, precipitation, and runoff. These cycles connect the biosphere, atmosphere, hydrosphere, and geosphere.",
                                        "practices": [
                                            {
                                                "question": "Which process converts atmospheric nitrogen into ammonia?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Nitrification","B) Denitrification","C) Nitrogen fixation","D) Ammonification"]}',
                                                "answer": "C",
                                                "explanation": "Nitrogen fixation, carried out by bacteria like Rhizobium, converts N2 to NH3 (ammonia).",
                                            },
                                            {
                                                "question": "Name two ways carbon returns to the atmosphere.",
                                                "type": "short_answer",
                                                "answer": "Cellular respiration and combustion of fossil fuels",
                                                "explanation": "Both processes release CO2 back into the atmosphere, completing the carbon cycle.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Population Ecology",
                        "difficulty": "intermediate",
                        "description": "Factors affecting population size and structure.",
                        "subtopics": [
                            {
                                "title": "Population Growth",
                                "concepts": [
                                    {
                                        "title": "Exponential and Logistic Growth",
                                        "description": "Mathematical models of population dynamics.",
                                        "material_title": "Population Growth Models",
                                        "material_content": "Exponential growth (J-curve) occurs when resources are unlimited: dN/dt = rN, where r is the intrinsic growth rate. Population size grows without bound. Logistic growth (S-curve) accounts for carrying capacity K: dN/dt = rN(1 - N/K). Growth slows as N approaches K. Real populations typically show logistic growth with environmental constraints.",
                                        "practices": [
                                            {
                                                "question": "What is carrying capacity?",
                                                "type": "mcq",
                                                "options": '{"options":["A) The birth rate of a population","B) The maximum population size the environment can sustain","C) The death rate of a population","D) The migration rate"]}',
                                                "answer": "B",
                                                "explanation": "Carrying capacity (K) is the maximum population size an environment can sustain given available resources.",
                                            },
                                            {
                                                "question": "When does exponential growth occur in nature?",
                                                "type": "short_answer",
                                                "answer": "When resources are abundant and there are no environmental constraints.",
                                                "explanation": "Exponential growth is typical of invasive species in new environments or bacterial cultures in fresh media.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Species Interactions",
                                "concepts": [
                                    {
                                        "title": "Symbiotic Relationships",
                                        "description": "Close ecological relationships between species.",
                                        "material_title": "Types of Symbiosis",
                                        "material_content": "Mutualism benefits both species (e.g., bees and flowering plants). Commensalism benefits one species without affecting the other (e.g., barnacles on whales). Parasitism benefits one species at the expense of the other (e.g., tapeworms in intestines). Competition occurs when species vie for the same resource, potentially leading to competitive exclusion or resource partitioning.",
                                        "practices": [
                                            {
                                                "question": "Which type of symbiosis involves one organism benefiting while the other is harmed?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Mutualism","B) Commensalism","C) Parasitism","D) Competition"]}',
                                                "answer": "C",
                                                "explanation": "In parasitism, the parasite benefits at the expense of the host organism.",
                                            },
                                            {
                                                "question": "Give an example of mutualism.",
                                                "type": "short_answer",
                                                "answer": "Bees pollinating flowers while obtaining nectar",
                                                "explanation": "Both the bee (food) and the plant (pollination) benefit from this interaction.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Evolution",
                "slug": "evolution",
                "description": "The process of change in living organisms over generations.",
                "topics": [
                    {
                        "title": "Natural Selection",
                        "difficulty": "intermediate",
                        "description": "The mechanism driving adaptive evolution.",
                        "subtopics": [
                            {
                                "title": "Darwin's Theory",
                                "concepts": [
                                    {
                                        "title": "Principles of Natural Selection",
                                        "description": "The four conditions required for natural selection.",
                                        "material_title": "Natural Selection",
                                        "material_content": "Natural selection requires four conditions: variation (individuals differ in traits), heritability (traits are passed to offspring), differential survival and reproduction (some traits improve fitness), and competition (resources are limited). Individuals with advantageous traits are more likely to survive and reproduce, increasing the frequency of beneficial alleles in the population over time.",
                                        "practices": [
                                            {
                                                "question": "Which of the following is NOT a requirement for natural selection?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Variation in traits","B) Overproduction of offspring","C) Acquired characteristics","D) Differential reproduction"]}',
                                                "answer": "C",
                                                "explanation": "Acquired characteristics (Lamarckism) are not a requirement. Natural selection acts on heritable variation.",
                                            },
                                            {
                                                "question": "How does natural selection affect allele frequencies over time?",
                                                "type": "short_answer",
                                                "answer": "It increases the frequency of beneficial alleles and decreases harmful ones.",
                                                "explanation": "Natural selection shifts allele frequencies toward traits that improve fitness in a given environment.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Evidence for Evolution",
                                "concepts": [
                                    {
                                        "title": "Types of Evidence",
                                        "description": "Fossil, anatomical, molecular, and biogeographical evidence.",
                                        "material_title": "Evidence Supporting Evolution",
                                        "material_content": "Fossil records show progressive changes in organisms over geological time. Comparative anatomy reveals homologous structures (shared ancestry) and vestigial structures (remnants of ancestral traits). Molecular biology shows DNA sequence similarities among related species. Biogeography demonstrates that species distribution patterns reflect evolutionary history and continental drift. Embryological similarities reveal common developmental pathways.",
                                        "practices": [
                                            {
                                                "question": "What are homologous structures?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Structures with the same function but different origins","B) Structures with different functions but shared ancestry","C) Structures identical in all species","D) Structures that are vestigial"]}',
                                                "answer": "B",
                                                "explanation": "Homologous structures (like the human arm and whale flipper) share a common developmental origin but may serve different functions.",
                                            },
                                            {
                                                "question": "How does DNA evidence support common ancestry?",
                                                "type": "short_answer",
                                                "answer": "Closely related species share more DNA sequence similarity than distantly related species.",
                                                "explanation": "Molecular comparisons reveal evolutionary relationships; more similar DNA indicates more recent common ancestry.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Speciation",
                        "difficulty": "advanced",
                        "description": "The formation of new species.",
                        "subtopics": [
                            {
                                "title": "Types of Speciation",
                                "concepts": [
                                    {
                                        "title": "Allopatric and Sympatric Speciation",
                                        "description": "Speciation with and without geographic isolation.",
                                        "material_title": "Speciation Mechanisms",
                                        "material_content": "Allopatric speciation occurs when a population is divided by a geographic barrier (mountain range, river, ocean), and the separated populations evolve independently until they can no longer interbreed. Sympatric speciation occurs without geographic separation, through mechanisms like polyploidy (common in plants), habitat differentiation, or sexual selection. Reproductive isolation (prezygotic and postzygotic barriers) defines species boundaries.",
                                        "practices": [
                                            {
                                                "question": "Which type of speciation involves geographic isolation?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Sympatric","B) Allopatric","C) Parapatric","D) Peripatric"]}',
                                                "answer": "B",
                                                "explanation": "Allopatric speciation occurs when populations are physically separated by a geographic barrier.",
                                            },
                                            {
                                                "question": "How can polyploidy lead to speciation in plants?",
                                                "type": "short_answer",
                                                "answer": "Polyploid individuals have extra chromosome sets and cannot interbreed with diploid parents, creating instant reproductive isolation.",
                                                "explanation": "If a doubling of chromosomes creates a fertile polyploid, it cannot produce viable offspring with the original population.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Hardy-Weinberg Equilibrium",
                                "concepts": [
                                    {
                                        "title": "Population Genetics Equilibrium",
                                        "description": "Conditions under which allele frequencies remain constant.",
                                        "material_title": "Hardy-Weinberg Principle",
                                        "material_content": "The Hardy-Weinberg principle states that allele and genotype frequencies remain constant across generations in the absence of evolutionary forces. The equation p^2 + 2pq + q^2 = 1 describes genotype frequencies, where p and q are allele frequencies. Five conditions must be met: no mutation, no gene flow, random mating, no natural selection, and infinite population size. Deviations indicate evolution is occurring.",
                                        "practices": [
                                            {
                                                "question": "If q^2 = 0.16 in a population at Hardy-Weinberg equilibrium, what is q?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 0.04","B) 0.16","C) 0.4","D) 0.84"]}',
                                                "answer": "C",
                                                "explanation": "q = sqrt(0.16) = 0.4. Then p = 1 - 0.4 = 0.6.",
                                            },
                                            {
                                                "question": "List two conditions required for Hardy-Weinberg equilibrium.",
                                                "type": "short_answer",
                                                "answer": "No natural selection and random mating",
                                                "explanation": "Five conditions are needed: no mutation, no gene flow, random mating, no selection, large population size.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Human Anatomy",
                "slug": "human-anatomy",
                "description": "The structure of the human body and its organ systems.",
                "topics": [
                    {
                        "title": "Cardiovascular System",
                        "difficulty": "intermediate",
                        "description": "The heart, blood vessels, and circulation.",
                        "subtopics": [
                            {
                                "title": "Heart Structure and Function",
                                "concepts": [
                                    {
                                        "title": "Cardiac Cycle",
                                        "description": "The sequence of events in one heartbeat.",
                                        "material_title": "The Cardiac Cycle",
                                        "material_content": "The cardiac cycle consists of systole (contraction) and diastole (relaxation) of the heart chambers. During atrial systole, blood fills the ventricles. During ventricular systole, blood is pumped to the lungs (right ventricle via pulmonary artery) and body (left ventricle via aorta). The heart valves (tricuspid, pulmonary, mitral, aortic) prevent backflow. The cycle is regulated by the sinoatrial (SA) node, the heart's natural pacemaker.",
                                        "practices": [
                                            {
                                                "question": "Which chamber of the heart pumps blood to the lungs?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Left atrium","B) Left ventricle","C) Right atrium","D) Right ventricle"]}',
                                                "answer": "D",
                                                "explanation": "The right ventricle pumps deoxygenated blood through the pulmonary artery to the lungs.",
                                            },
                                            {
                                                "question": "What is the role of the SA node?",
                                                "type": "short_answer",
                                                "answer": "It generates electrical impulses that initiate and regulate the heartbeat.",
                                                "explanation": "The SA node in the right atrium fires approximately 60-100 times per minute, setting the heart rhythm.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Blood Vessels",
                                "concepts": [
                                    {
                                        "title": "Arteries, Veins, and Capillaries",
                                        "description": "The three types of blood vessels and their roles.",
                                        "material_title": "Blood Vessel Types",
                                        "material_content": "Arteries carry oxygenated blood away from the heart under high pressure; they have thick, muscular, elastic walls. Veins carry deoxygenated blood back to the heart under low pressure; they have thinner walls and one-way valves to prevent backflow. Capillaries are microscopic vessels with walls one cell thick, enabling gas exchange, nutrient delivery, and waste removal between blood and tissues.",
                                        "practices": [
                                            {
                                                "question": "Which blood vessel type has the thinnest walls?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Arteries","B) Veins","C) Capillaries","D) Aorta"]}',
                                                "answer": "C",
                                                "explanation": "Capillaries have walls only one endothelial cell thick to facilitate exchange with surrounding tissues.",
                                            },
                                            {
                                                "question": "Why do veins have valves but arteries do not?",
                                                "type": "short_answer",
                                                "answer": "Veins operate under low pressure and need valves to prevent backflow of blood.",
                                                "explanation": "Arteries have high pressure from the heart that maintains forward flow; veins rely on skeletal muscle pumps and valves.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Nervous System",
                        "difficulty": "advanced",
                        "description": "The control and communication network of the body.",
                        "subtopics": [
                            {
                                "title": "Neuron Structure and Function",
                                "concepts": [
                                    {
                                        "title": "Action Potentials",
                                        "description": "The electrical signals that transmit along neurons.",
                                        "material_title": "Nerve Impulse Transmission",
                                        "material_content": "An action potential is a rapid depolarization and repolarization of the neuron membrane. At rest, the membrane potential is about -70mV (maintained by the Na+/K+ pump). A stimulus opens voltage-gated Na+ channels, causing depolarization to about +30mV. K+ channels then open, repolarizing the membrane. The refractory period ensures one-way signal propagation. Myelination speeds conduction via saltatory conduction.",
                                        "practices": [
                                            {
                                                "question": "What is the resting membrane potential of a typical neuron?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 0 mV","B) -30 mV","C) -70 mV","D) +30 mV"]}',
                                                "answer": "C",
                                                "explanation": "The resting membrane potential is approximately -70mV, maintained by the Na+/K+ ATPase pump.",
                                            },
                                            {
                                                "question": "How does myelination increase the speed of nerve impulse conduction?",
                                                "type": "short_answer",
                                                "answer": "Action potentials jump between nodes of Ranvier (saltatory conduction) rather than propagating continuously.",
                                                "explanation": "Myelin insulates the axon, so depolarization only occurs at gaps (nodes), speeding transmission up to 100x.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Synaptic Transmission",
                                "concepts": [
                                    {
                                        "title": "Chemical Synapses",
                                        "description": "Neuron-to-neuron communication via neurotransmitters.",
                                        "material_title": "Synaptic Transmission",
                                        "material_content": "At a chemical synapse, an arriving action potential triggers Ca2+ influx into the presynaptic terminal, causing synaptic vesicles to fuse with the membrane and release neurotransmitters into the synaptic cleft. Neurotransmitters (acetylcholine, dopamine, serotonin, GABA, glutamate) bind to receptors on the postsynaptic membrane, opening ion channels and generating excitatory or inhibitory postsynaptic potentials. Neurotransmitters are then degraded or reabsorbed.",
                                        "practices": [
                                            {
                                                "question": "What ion triggers neurotransmitter release at the presynaptic terminal?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Na+","B) K+","C) Ca2+","D) Cl-"]}',
                                                "answer": "C",
                                                "explanation": "Calcium influx through voltage-gated channels triggers vesicle fusion and neurotransmitter release.",
                                            },
                                            {
                                                "question": "Name an excitatory and an inhibitory neurotransmitter.",
                                                "type": "short_answer",
                                                "answer": "Excitatory: glutamate; Inhibitory: GABA",
                                                "explanation": "Glutamate increases the likelihood of firing; GABA decreases it.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Plant Biology",
                "slug": "plant-biology",
                "description": "The biology of plants and their processes.",
                "topics": [
                    {
                        "title": "Photosynthesis",
                        "difficulty": "intermediate",
                        "description": "How plants convert light energy to chemical energy.",
                        "subtopics": [
                            {
                                "title": "Light Reactions",
                                "concepts": [
                                    {
                                        "title": "The Light-Dependent Reactions",
                                        "description": "Energy capture in the thylakoid membrane.",
                                        "material_title": "Light Reactions of Photosynthesis",
                                        "material_content": "The light-dependent reactions occur in the thylakoid membrane. Photosystem II (P680) absorbs light, exciting electrons that travel through the electron transport chain to Photosystem I (P700). Water is split (photolysis) to replace electrons, releasing O2. The electron transport chain creates a proton gradient that drives ATP synthase (chemiosmosis). NADP+ reductase produces NADPH. Both ATP and NADPH power the Calvin cycle.",
                                        "practices": [
                                            {
                                                "question": "Which photosystem splits water during the light reactions?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Photosystem I","B) Photosystem II","C) Both","D) Neither"]}',
                                                "answer": "B",
                                                "explanation": "Photosystem II (P680) oxidizes water molecules to replace its lost electrons.",
                                            },
                                            {
                                                "question": "What are the three products of the light reactions?",
                                                "type": "short_answer",
                                                "answer": "ATP, NADPH, and O2",
                                                "explanation": "ATP and NADPH fuel the Calvin cycle; O2 is released as a byproduct.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Calvin Cycle",
                                "concepts": [
                                    {
                                        "title": "Carbon Fixation",
                                        "description": "Converting CO2 into organic molecules.",
                                        "material_title": "The Calvin Cycle",
                                        "material_content": "The Calvin cycle occurs in the stroma and has three phases. Carbon fixation: RuBisCO catalyzes the attachment of CO2 to ribulose bisphosphate (RuBP, 5C), producing 3-phosphoglycerate (3C). Reduction: ATP and NADPH from the light reactions convert 3-phosphoglycerate to glyceraldehyde-3-phosphate (G3P). Regeneration: RuBP is regenerated using ATP, allowing the cycle to continue. Three CO2 turns produce one net G3P.",
                                        "practices": [
                                            {
                                                "question": "What enzyme fixes carbon in the Calvin cycle?",
                                                "type": "mcq",
                                                "options": '{"options":["A) ATP synthase","B) RuBisCO","C) NADP reductase","D) Hexokinase"]}',
                                                "answer": "B",
                                                "explanation": "RuBisCO (ribulose-1,5-bisphosphate carboxylase/oxygenase) catalyzes the first step of carbon fixation.",
                                            },
                                            {
                                                "question": "How many turns of the Calvin cycle produce one G3P molecule?",
                                                "type": "short_answer",
                                                "answer": "Three turns",
                                                "explanation": "Each turn fixes one CO2; three turns produce one net G3P (3-carbon sugar).",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Plant Transport",
                        "difficulty": "intermediate",
                        "description": "How water and nutrients move through plants.",
                        "subtopics": [
                            {
                                "title": "Vascular Tissues",
                                "concepts": [
                                    {
                                        "title": "Xylem and Phloem",
                                        "description": "The transport tissues of vascular plants.",
                                        "material_title": "Plant Vascular System",
                                        "material_content": "Xylem transports water and dissolved minerals from roots to shoots. Xylem vessels are dead at maturity with thick, lignified walls. Water moves upward through cohesion-tension theory: transpiration creates tension, and water's cohesive properties maintain a continuous column. Phloem transports sugars (sucrose) from sources to sinks through translocation. Phloem sieve tubes are alive, with companion cells providing metabolic support.",
                                        "practices": [
                                            {
                                                "question": "Which vascular tissue transports water upward?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Phloem","B) Xylem","C) Cambium","D) Cortex"]}',
                                                "answer": "B",
                                                "explanation": "Xylem carries water and minerals from roots to aerial parts of the plant.",
                                            },
                                            {
                                                "question": "What drives the upward movement of water in xylem?",
                                                "type": "short_answer",
                                                "answer": "Transpiration pull (cohesion-tension mechanism)",
                                                "explanation": "Evaporation from leaves creates negative pressure that pulls water up through the cohesive water column.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Stomatal Regulation",
                                "concepts": [
                                    {
                                        "title": "Stomata and Gas Exchange",
                                        "description": "How plants regulate CO2 uptake and water loss.",
                                        "material_title": "Stomatal Function",
                                        "material_content": "Stomata are microscopic pores on leaf surfaces, each flanked by two guard cells. When guard cells absorb water and become turgid, the stomata open, allowing CO2 entry for photosynthesis and O2 release. When guard cells lose water (flaccid), stomata close, reducing water loss. Abscisic acid (ABA) triggers stomatal closure during drought. Stomatal density and behavior vary by species and environment.",
                                        "practices": [
                                            {
                                                "question": "What causes stomata to open?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Guard cells losing water","B) Guard cells becoming turgid","C) ABA hormone","D) High temperature"]}',
                                                "answer": "B",
                                                "explanation": "When guard cells absorb water and become turgid, they bow apart, opening the stomatal pore.",
                                            },
                                            {
                                                "question": "What is the trade-off of having stomata open?",
                                                "type": "short_answer",
                                                "answer": "CO2 enters for photosynthesis but water is lost through transpiration.",
                                                "explanation": "Plants must balance carbon gain with water conservation.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Microbiology",
                "slug": "microbiology",
                "description": "The study of microscopic organisms.",
                "topics": [
                    {
                        "title": "Bacterial Biology",
                        "difficulty": "foundational",
                        "description": "Structure, function, and classification of bacteria.",
                        "subtopics": [
                            {
                                "title": "Bacterial Cell Structure",
                                "concepts": [
                                    {
                                        "title": "Bacterial Morphology and Anatomy",
                                        "description": "Shapes, structures, and adaptations of bacteria.",
                                        "material_title": "Bacterial Cell Biology",
                                        "material_content": "Bacteria are classified by shape: cocci (spherical), bacilli (rod-shaped), spirilla (spiral), and vibrio (comma-shaped). Key structures include the cell wall (peptidoglycan in Gram-positive bacteria, thin layer with outer membrane in Gram-negative), plasma membrane, cytoplasm, ribosomes (70S), nucleoid (circular DNA), and plasmids (extrachromosomal DNA). Some bacteria have flagella for motility, pili for conjugation, and capsules for protection.",
                                        "practices": [
                                            {
                                                "question": "What is the main structural difference between Gram-positive and Gram-negative bacteria?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Cell size","B) Thick peptidoglycan vs. thin with outer membrane","C) Number of ribosomes","D) DNA structure"]}',
                                                "answer": "B",
                                                "explanation": "Gram-positive bacteria have a thick peptidoglycan layer; Gram-negative have a thin layer surrounded by an outer membrane.",
                                            },
                                            {
                                                "question": "What is the function of bacterial plasmids?",
                                                "type": "short_answer",
                                                "answer": "They carry supplementary genes, often for antibiotic resistance or metabolic functions.",
                                                "explanation": "Plasmids are small, circular, extrachromosomal DNA molecules that replicate independently.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Bacterial Growth",
                                "concepts": [
                                    {
                                        "title": "Bacterial Growth Phases",
                                        "description": "Population dynamics in bacterial cultures.",
                                        "material_title": "Bacterial Growth Curves",
                                        "material_content": "Bacterial growth in batch culture follows four phases. Lag phase: cells adapt and synthesize enzymes (no division). Log (exponential) phase: cells divide at maximum rate; this is when bacteria are most susceptible to antibiotics. Stationary phase: nutrient depletion and waste accumulation cause growth to plateau (birth rate = death rate). Death (decline) phase: cells die faster than they divide. Binary fission is the primary method of bacterial reproduction.",
                                        "practices": [
                                            {
                                                "question": "During which growth phase are bacteria most susceptible to antibiotics?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Lag phase","B) Log phase","C) Stationary phase","D) Death phase"]}',
                                                "answer": "B",
                                                "explanation": "Antibiotics that target active growth processes (cell wall synthesis, DNA replication) are most effective during log phase.",
                                            },
                                            {
                                                "question": "What causes the transition from log phase to stationary phase?",
                                                "type": "short_answer",
                                                "answer": "Nutrient depletion and accumulation of toxic waste products.",
                                                "explanation": "As resources are consumed and waste builds up, the growth rate slows until birth rate equals death rate.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Virology",
                        "difficulty": "intermediate",
                        "description": "The study of viruses.",
                        "subtopics": [
                            {
                                "title": "Viral Structure and Replication",
                                "concepts": [
                                    {
                                        "title": "Viral Life Cycles",
                                        "description": "How viruses infect and replicate within host cells.",
                                        "material_title": "Viral Replication",
                                        "material_content": "Viruses are obligate intracellular parasites consisting of nucleic acid (DNA or RNA) enclosed in a protein coat (capsid). Some have an outer lipid envelope. Viral replication involves: attachment to host receptors, penetration (injection or endocytosis), uncoating, replication of viral genome, transcription and translation of viral proteins, assembly of new virions, and release (lysis or budding). Bacteriophages use the lytic and lysogenic cycles.",
                                        "practices": [
                                            {
                                                "question": "What is the difference between the lytic and lysogenic cycles?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Lytic kills the host immediately; lysogenic integrates DNA into the host genome","B) They are the same process","C) Lysogenic kills cells faster","D) Lytic only affects bacteria"]}',
                                                "answer": "A",
                                                "explanation": "In the lytic cycle, the virus replicates and lyses the host cell. In the lysogenic cycle, viral DNA integrates into the host genome (provirus) and is replicated passively.",
                                            },
                                            {
                                                "question": "Why are viruses considered obligate intracellular parasites?",
                                                "type": "short_answer",
                                                "answer": "They cannot replicate or carry out metabolic processes outside a host cell.",
                                                "explanation": "Viruses lack the machinery for protein synthesis and energy production, depending entirely on the host cell.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Immune Response to Viruses",
                                "concepts": [
                                    {
                                        "title": "Antiviral Immunity",
                                        "description": "How the immune system fights viral infections.",
                                        "material_title": "Antiviral Immune Defenses",
                                        "material_content": "The innate immune response provides immediate, non-specific defense: interferons signal neighboring cells to resist infection, and natural killer (NK) cells destroy virus-infected cells. The adaptive immune response follows: cytotoxic T cells (CD8+) directly kill infected cells, and B cells produce antibodies that neutralize free virions. Memory cells provide long-lasting immunity. Vaccines exploit this by introducing antigens without causing disease.",
                                        "practices": [
                                            {
                                                "question": "What role do interferons play in antiviral defense?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Kill viruses directly","B) Signal neighboring cells to produce antiviral proteins","C) Produce antibodies","D) Destroy infected cells"]}',
                                                "answer": "B",
                                                "explanation": "Interferons are cytokines released by virus-infected cells that warn neighboring cells to activate antiviral defenses.",
                                            },
                                            {
                                                "question": "How do vaccines provide immunity against viruses?",
                                                "type": "short_answer",
                                                "answer": "They introduce antigens that stimulate adaptive immunity and memory cell formation without causing disease.",
                                                "explanation": "Memory B and T cells generated by vaccination respond rapidly upon future exposure to the actual pathogen.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Biochemistry",
                "slug": "biochemistry",
                "description": "The chemistry of biological processes and molecules.",
                "topics": [
                    {
                        "title": "Carbohydrate Metabolism",
                        "difficulty": "intermediate",
                        "description": "How cells break down and use sugars for energy.",
                        "subtopics": [
                            {
                                "title": "Glycolysis",
                                "concepts": [
                                    {
                                        "title": "The Glycolytic Pathway",
                                        "description": "The universal glucose degradation pathway.",
                                        "material_title": "Glycolysis",
                                        "material_content": "Glycolysis occurs in the cytoplasm and breaks one glucose molecule (6C) into two pyruvate molecules (3C) through 10 enzymatic steps. It occurs in two phases: the energy investment phase (ATP consumed to phosphorylate glucose) and the energy payoff phase (ATP and NADH produced). Net yield: 2 ATP, 2 NADH, and 2 pyruvate per glucose. Glycolysis is anaerobic (does not require oxygen) and occurs in virtually all living organisms.",
                                        "practices": [
                                            {
                                                "question": "What is the net ATP yield from glycolysis per glucose molecule?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 1","B) 2","C) 4","D) 36"]}',
                                                "answer": "B",
                                                "explanation": "Glycolysis produces 4 ATP but consumes 2, giving a net yield of 2 ATP per glucose.",
                                            },
                                            {
                                                "question": "What are the two products of glycolysis?",
                                                "type": "short_answer",
                                                "answer": "2 Pyruvate, 2 NADH, and 2 ATP (net)",
                                                "explanation": "Each glucose yields two 3-carbon pyruvate molecules along with energy carriers.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Cellular Respiration",
                                "concepts": [
                                    {
                                        "title": "Krebs Cycle and Oxidative Phosphorylation",
                                        "description": "Completing aerobic energy extraction.",
                                        "material_title": "Aerobic Respiration",
                                        "material_content": "Pyruvate from glycolysis enters the mitochondria and is converted to acetyl-CoA, which enters the Krebs cycle (citric acid cycle). The cycle produces 2 CO2, 3 NADH, 1 FADH2, and 1 GTP per turn (2 turns per glucose). NADH and FADH2 donate electrons to the electron transport chain on the inner mitochondrial membrane. The resulting proton gradient drives ATP synthase (oxidative phosphorylation), producing approximately 34 ATP. Total aerobic yield: ~36-38 ATP per glucose.",
                                        "practices": [
                                            {
                                                "question": "Where does the Krebs cycle take place?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Cytoplasm","B) Outer mitochondrial membrane","C) Mitochondrial matrix","D) Inner mitochondrial membrane"]}',
                                                "answer": "C",
                                                "explanation": "The Krebs cycle (citric acid cycle) occurs in the mitochondrial matrix.",
                                            },
                                            {
                                                "question": "How many ATP molecules are produced per glucose in complete aerobic respiration?",
                                                "type": "short_answer",
                                                "answer": "Approximately 36-38 ATP",
                                                "explanation": "Glycolysis produces 2 ATP, the Krebs cycle produces 2 GTP, and oxidative phosphorylation produces about 34 ATP.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Lipid Biochemistry",
                        "difficulty": "intermediate",
                        "description": "The structure and metabolism of fats and oils.",
                        "subtopics": [
                            {
                                "title": "Fatty Acid Oxidation",
                                "concepts": [
                                    {
                                        "title": "Beta-Oxidation",
                                        "description": "Breaking down fatty acids for energy.",
                                        "material_title": "Fatty Acid Beta-Oxidation",
                                        "material_content": "Beta-oxidation occurs in the mitochondrial matrix and breaks fatty acids into 2-carbon acetyl-CoA units. Fatty acids are first activated in the cytoplasm, then transported into mitochondria via the carnitine shuttle. Each cycle of beta-oxidation removes two carbons (as acetyl-CoA) and produces 1 NADH and 1 FADH2. A 16-carbon palmitate yields 8 acetyl-CoA, 7 NADH, and 7 FADH2, generating approximately 106 ATP total.",
                                        "practices": [
                                            {
                                                "question": "How many carbons are removed per cycle of beta-oxidation?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 1","B) 2","C) 3","D) 4"]}',
                                                "answer": "B",
                                                "explanation": "Each cycle of beta-oxidation cleaves a 2-carbon unit as acetyl-CoA from the fatty acid chain.",
                                            },
                                            {
                                                "question": "Why are fatty acids a more efficient energy source than carbohydrates?",
                                                "type": "short_answer",
                                                "answer": "Fatty acids produce more ATP per gram because they are more reduced (more C-H bonds to oxidize).",
                                                "explanation": "Fats yield ~9 kcal/g vs. ~4 kcal/g for carbohydrates, producing significantly more ATP.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Membrane Lipids",
                                "concepts": [
                                    {
                                        "title": "Phospholipid Bilayer Structure",
                                        "description": "The molecular basis of cell membranes.",
                                        "material_title": "Cell Membrane Structure",
                                        "material_content": "Phospholipids are amphipathic molecules with a hydrophilic head (phosphate group) and two hydrophobic fatty acid tails. In water, they spontaneously form bilayers with tails facing inward, creating a barrier to water-soluble molecules. This fluid mosaic model (Singer and Nicolson) describes membranes as dynamic structures with embedded proteins, cholesterol (modulating fluidity), and glycolipids (cell recognition). Membrane fluidity depends on fatty acid saturation and cholesterol content.",
                                        "practices": [
                                            {
                                                "question": "Why do phospholipids form bilayers in water?",
                                                "type": "mcq",
                                                "options": '{"options":["A) They are hydrophilic","B) Their amphipathic nature drives self-assembly","C) They dissolve in water","D) Proteins push them together"]}',
                                                "answer": "B",
                                                "explanation": "The hydrophobic tails avoid water while hydrophilic heads face it, spontaneously forming a bilayer.",
                                            },
                                            {
                                                "question": "How does cholesterol affect membrane fluidity?",
                                                "type": "short_answer",
                                                "answer": "At high temperatures it reduces fluidity; at low temperatures it prevents packing and maintains fluidity.",
                                                "explanation": "Cholesterol acts as a fluidity buffer, moderating the effects of temperature changes.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Neuroscience",
                "slug": "neuroscience",
                "description": "The scientific study of the nervous system.",
                "topics": [
                    {
                        "title": "Brain Structure",
                        "difficulty": "intermediate",
                        "description": "The anatomy and organization of the brain.",
                        "subtopics": [
                            {
                                "title": "Brain Regions and Functions",
                                "concepts": [
                                    {
                                        "title": "Major Brain Regions",
                                        "description": "Cerebrum, cerebellum, and brainstem functions.",
                                        "material_title": "Brain Anatomy",
                                        "material_content": "The cerebrum (cerebral cortex) is responsible for higher functions: thinking, memory, language, and sensory perception. It is divided into four lobes: frontal (decision-making, motor control), parietal (somatosensory processing), temporal (auditory processing, memory), and occipital (visual processing). The cerebellum coordinates movement and balance. The brainstem (medulla, pons, midbrain) controls vital functions like breathing and heart rate. The limbic system (hippocampus, amygdala) governs emotion and memory.",
                                        "practices": [
                                            {
                                                "question": "Which lobe of the brain is primarily responsible for visual processing?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Frontal lobe","B) Parietal lobe","C) Temporal lobe","D) Occipital lobe"]}',
                                                "answer": "D",
                                                "explanation": "The occipital lobe at the back of the brain contains the primary visual cortex.",
                                            },
                                            {
                                                "question": "What is the role of the hippocampus?",
                                                "type": "short_answer",
                                                "answer": "Formation and consolidation of new memories.",
                                                "explanation": "The hippocampus is critical for converting short-term memories into long-term memories.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Neural Circuits",
                                "concepts": [
                                    {
                                        "title": "Neural Networks and Connectivity",
                                        "description": "How neurons form functional circuits.",
                                        "material_title": "Neural Circuit Organization",
                                        "material_content": "Neural circuits are interconnected groups of neurons that process specific information. Simple reflex arcs involve sensory neurons, interneurons, and motor neurons. Complex circuits involve feedforward pathways (one direction), feedback loops (recurrent connections), and convergence/divergence. Neural circuits exhibit plasticity: synaptic connections strengthen or weaken based on activity (Hebbian learning: neurons that fire together wire together).",
                                        "practices": [
                                            {
                                                "question": "What is Hebbian learning?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Learning through punishment","B) Neurons that fire together wire together","C) Learning from textbooks","D) Reflex-based learning"]}',
                                                "answer": "B",
                                                "explanation": "Hebbian theory states that synapses strengthen when pre- and post-synaptic neurons are simultaneously active.",
                                            },
                                            {
                                                "question": "Describe a simple reflex arc.",
                                                "type": "short_answer",
                                                "answer": "Sensory receptor -> sensory neuron -> interneuron (spinal cord) -> motor neuron -> effector muscle.",
                                                "explanation": "Reflex arcs bypass the brain for rapid, involuntary responses to stimuli.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Neurotransmitter Systems",
                        "difficulty": "advanced",
                        "description": "Chemical signaling in the nervous system.",
                        "subtopics": [
                            {
                                "title": "Major Neurotransmitters",
                                "concepts": [
                                    {
                                        "title": "Neurotransmitter Functions",
                                        "description": "Roles of key neurotransmitters in the body.",
                                        "material_title": "Neurotransmitter Systems",
                                        "material_content": "Acetylcholine (ACh) is involved in muscle contraction and memory; its deficiency is linked to Alzheimer's disease. Dopamine regulates reward, motivation, and motor control; dysfunction is associated with Parkinson's disease and schizophrenia. Serotonin modulates mood, appetite, and sleep; low levels correlate with depression. GABA is the main inhibitory neurotransmitter; benzodiazepines enhance its activity. Glutamate is the main excitatory neurotransmitter; excess causes excitotoxicity.",
                                        "practices": [
                                            {
                                                "question": "Which neurotransmitter deficiency is associated with Parkinson's disease?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Serotonin","B) Acetylcholine","C) Dopamine","D) GABA"]}',
                                                "answer": "C",
                                                "explanation": "Parkinson's disease results from the loss of dopamine-producing neurons in the substantia nigra.",
                                            },
                                            {
                                                "question": "What is the role of GABA in the nervous system?",
                                                "type": "short_answer",
                                                "answer": "GABA is the primary inhibitory neurotransmitter, reducing neuronal excitability.",
                                                "explanation": "GABA opens chloride channels, hyperpolarizing neurons and making them less likely to fire.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Neurological Disorders",
                                "concepts": [
                                    {
                                        "title": "Common Neurological Conditions",
                                        "description": "Diseases affecting the nervous system.",
                                        "material_title": "Neurological Disorders",
                                        "material_content": "Alzheimer's disease involves progressive memory loss due to amyloid plaques and tau tangles. Parkinson's disease causes tremors and motor dysfunction from dopamine neuron degeneration. Multiple sclerosis is an autoimmune disease where the immune system attacks myelin sheaths. Epilepsy involves abnormal electrical activity causing seizures. Stroke occurs when blood supply to part of the brain is interrupted, causing cell death.",
                                        "practices": [
                                            {
                                                "question": "What protein accumulates in the brains of Alzheimer's patients?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Tau and amyloid-beta","B) Dopamine","C) Myelin","D) Hemoglobin"]}',
                                                "answer": "A",
                                                "explanation": "Alzheimer's is characterized by extracellular amyloid-beta plaques and intracellular neurofibrillary tau tangles.",
                                            },
                                            {
                                                "question": "What happens during a stroke?",
                                                "type": "short_answer",
                                                "answer": "Blood supply to part of the brain is interrupted, depriving neurons of oxygen and nutrients.",
                                                "explanation": "This can be ischemic (clot) or hemorrhagic (bleeding), both causing neuronal death.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Developmental Biology",
                "slug": "developmental-biology",
                "description": "How organisms grow and develop from a single cell.",
                "topics": [
                    {
                        "title": "Embryonic Development",
                        "difficulty": "intermediate",
                        "description": "The stages from fertilization to birth.",
                        "subtopics": [
                            {
                                "title": "Early Development",
                                "concepts": [
                                    {
                                        "title": "Cleavage and Gastrulation",
                                        "description": "Early cell divisions and germ layer formation.",
                                        "material_title": "Early Embryonic Development",
                                        "material_content": "After fertilization, the zygote undergoes cleavage: rapid cell divisions without growth, producing a morula (16 cells), then a blastula (hollow ball). Gastrulation reorganizes the blastula into three germ layers: ectoderm (skin, nervous system), mesoderm (muscle, bone, blood), and endoderm (gut lining, liver, lungs). Gastrulation establishes the body plan through coordinated cell movements and signaling.",
                                        "practices": [
                                            {
                                                "question": "What are the three germ layers formed during gastrulation?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Epidermis, dermis, hypodermis","B) Ectoderm, mesoderm, endoderm","C) Endoderm, mesoderm, epithelium","D) Dermis, endoderm, epithelium"]}',
                                                "answer": "B",
                                                "explanation": "Ectoderm, mesoderm, and endoderm give rise to all tissues and organs in the body.",
                                            },
                                            {
                                                "question": "What does the ectoderm develop into?",
                                                "type": "short_answer",
                                                "answer": "The nervous system and epidermis (skin).",
                                                "explanation": "Ectoderm gives rise to the neural tube (brain and spinal cord) and the outermost tissue layer.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Organogenesis",
                                "concepts": [
                                    {
                                        "title": "Organ Formation from Germ Layers",
                                        "description": "How tissues develop into functional organs.",
                                        "material_title": "Organogenesis",
                                        "material_content": "Organogenesis is the process by which the three germ layers differentiate into specific organs. The neural tube (from ectoderm) forms the brain and spinal cord. Somites (from mesoderm) form vertebrae, skeletal muscle, and dermis. The notochord (mesoderm) provides structural support and signaling. Morphogen gradients (like Sonic hedgehog and BMPs) provide positional information, directing cells to differentiate into specific types based on their location.",
                                        "practices": [
                                            {
                                                "question": "What structure provides the positional signals for dorsal-ventral patterning?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Blastula","B) Notochord","C) Yolk sac","D) Amnion"]}',
                                                "answer": "B",
                                                "explanation": "The notochord secretes Sonic hedgehog (Shh) that patterns the ventral side of the neural tube.",
                                            },
                                            {
                                                "question": "Name two organs derived from endoderm.",
                                                "type": "short_answer",
                                                "answer": "Liver and lungs",
                                                "explanation": "Endoderm forms the lining of the digestive tract and associated organs, plus the respiratory system.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Stem Cells",
                        "difficulty": "intermediate",
                        "description": "Undifferentiated cells with developmental potential.",
                        "subtopics": [
                            {
                                "title": "Types of Stem Cells",
                                "concepts": [
                                    {
                                        "title": "Totipotent, Pluripotent, and Multipotent Cells",
                                        "description": "The hierarchy of stem cell potency.",
                                        "material_title": "Stem Cell Classification",
                                        "material_content": "Totipotent cells (e.g., zygote) can form all cell types including extraembryonic tissues. Pluripotent cells (embryonic stem cells from the inner cell mass) can form all body cell types but not extraembryonic tissues. Multipotent cells (adult/stem cells like hematopoietic stem cells) can form a limited range of cell types within a tissue. Induced pluripotent stem cells (iPSCs) are reprogrammed adult cells that regain pluripotency.",
                                        "practices": [
                                            {
                                                "question": "Which type of stem cell can form all cell types of the body?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Multipotent","B) Unipotent","C) Pluripotent","D) Progenitor"]}',
                                                "answer": "C",
                                                "explanation": "Pluripotent stem cells can differentiate into any cell type of the three germ layers.",
                                            },
                                            {
                                                "question": "What are induced pluripotent stem cells (iPSCs)?",
                                                "type": "short_answer",
                                                "answer": "Adult cells that have been reprogrammed to an embryonic-like pluripotent state.",
                                                "explanation": "Yamanaka factors (Oct4, Sox2, Klf4, c-Myc) reprogram somatic cells to iPSCs.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Differentiation",
                                "concepts": [
                                    {
                                        "title": "Cell Differentiation Mechanisms",
                                        "description": "How stem cells become specialized cell types.",
                                        "material_title": "Cell Differentiation",
                                        "material_content": "Cell differentiation is driven by differential gene expression: all cells have the same genome, but different genes are turned on or off. Transcription factors activate specific gene programs. Epigenetic modifications (DNA methylation, histone modification) regulate gene accessibility. Cell-cell signaling and growth factors influence differentiation pathways. Differentiation is usually irreversible in vivo, though iPSC technology demonstrates that reprogramming is possible.",
                                        "practices": [
                                            {
                                                "question": "What is the primary mechanism driving cell differentiation?",
                                                "type": "mcq",
                                                "options": '{"options":["A) DNA mutations","B) Differential gene expression","C) Chromosome loss","D) Cell death"]}',
                                                "answer": "B",
                                                "explanation": "Different cells express different subsets of genes, despite having identical genomes.",
                                            },
                                            {
                                                "question": "What epigenetic mechanism silences gene expression by adding methyl groups to DNA?",
                                                "type": "short_answer",
                                                "answer": "DNA methylation",
                                                "explanation": "Methylation of CpG islands typically represses gene transcription by blocking transcription factor binding.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Immunology",
                "slug": "immunology",
                "description": "The study of the immune system and its defense mechanisms.",
                "topics": [
                    {
                        "title": "Innate Immunity",
                        "difficulty": "foundational",
                        "description": "The body's first line of defense.",
                        "subtopics": [
                            {
                                "title": "Physical and Chemical Barriers",
                                "concepts": [
                                    {
                                        "title": "First Line of Defense",
                                        "description": "Physical, chemical, and biological barriers against pathogens.",
                                        "material_title": "Innate Immune Barriers",
                                        "material_content": "The innate immune system provides immediate, non-specific defense. Physical barriers include the skin (keratinized epithelium), mucous membranes, and cilia. Chemical barriers include stomach acid (pH 2), lysozyme in tears and saliva, and defensins. Biological barriers include the normal microbiome that competes with pathogens. When barriers are breached, inflammation, phagocytosis, and the complement system activate within minutes to hours.",
                                        "practices": [
                                            {
                                                "question": "Which of the following is an example of a chemical barrier?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Skin","B) Stomach acid","C) Mucous membranes","D) Cilia"]}',
                                                "answer": "B",
                                                "explanation": "Stomach acid (low pH) destroys most ingested pathogens, serving as a chemical barrier.",
                                            },
                                            {
                                                "question": "What is the role of the normal microbiome in innate immunity?",
                                                "type": "short_answer",
                                                "answer": "It competes with pathogens for nutrients and attachment sites.",
                                                "explanation": "Commensal bacteria prevent pathogen colonization through competitive exclusion.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Inflammatory Response",
                                "concepts": [
                                    {
                                        "title": "Inflammation Mechanisms",
                                        "description": "The body's response to tissue damage and infection.",
                                        "material_title": "The Inflammatory Response",
                                        "material_content": "Inflammation is triggered by tissue damage or pathogen detection. Mast cells release histamine, causing vasodilation and increased vascular permeability. Neutrophils are the first immune cells to arrive, phagocytosing pathogens. Macrophages follow, presenting antigens to the adaptive immune system. The cardinal signs of inflammation are redness, heat, swelling, pain, and loss of function. Chronic inflammation can lead to tissue damage and disease.",
                                        "practices": [
                                            {
                                                "question": "Which immune cell is the first to arrive at a site of infection?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Macrophage","B) T cell","C) Neutrophil","D) B cell"]}',
                                                "answer": "C",
                                                "explanation": "Neutrophils are the most abundant white blood cells and migrate rapidly to infection sites.",
                                            },
                                            {
                                                "question": "What are the five cardinal signs of inflammation?",
                                                "type": "short_answer",
                                                "answer": "Redness, heat, swelling, pain, and loss of function.",
                                                "explanation": "These result from vasodilation, increased permeability, and immune cell infiltration.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Adaptive Immunity",
                        "difficulty": "intermediate",
                        "description": "Specific, targeted immune responses.",
                        "subtopics": [
                            {
                                "title": "Humoral Immunity",
                                "concepts": [
                                    {
                                        "title": "B Cell and Antibody Responses",
                                        "description": "Antibody-mediated immune defense.",
                                        "material_title": "Humoral Immunity",
                                        "material_content": "B cells produce antibodies (immunoglobulins) that circulate in body fluids. When a B cell encounters its specific antigen and receives help from helper T cells, it activates, proliferates (clonal selection), and differentiates into plasma cells (antibody factories) and memory B cells. Antibody classes include IgG (most abundant, crosses placenta), IgA (mucosal surfaces), IgM (first response), IgE (allergies, parasites), and IgD (B cell activation).",
                                        "practices": [
                                            {
                                                "question": "Which antibody class is the first to be produced in a primary immune response?",
                                                "type": "mcq",
                                                "options": '{"options":["A) IgG","B) IgA","C) IgM","D) IgE"]}',
                                                "answer": "C",
                                                "explanation": "IgM is the first antibody produced in a primary response and is a pentamer that efficiently activates complement.",
                                            },
                                            {
                                                "question": "What are the functions of antibodies?",
                                                "type": "short_answer",
                                                "answer": "Neutralization, opsonization, complement activation, and agglutination of pathogens.",
                                                "explanation": "Antibodies mark pathogens for destruction through multiple effector mechanisms.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Cell-Mediated Immunity",
                                "concepts": [
                                    {
                                        "title": "T Cell Responses",
                                        "description": "T cell-mediated immune defense.",
                                        "material_title": "Cell-Mediated Immunity",
                                        "material_content": "T cells mature in the thymus and recognize antigens presented on MHC molecules. Helper T cells (CD4+) recognize MHC class II on antigen-presenting cells and coordinate immune responses by releasing cytokines. Cytotoxic T cells (CD8+) recognize MHC class I on infected cells and kill them using perforin and granzymes. Regulatory T cells suppress immune responses to prevent autoimmunity. Memory T cells provide long-lasting immunity.",
                                        "practices": [
                                            {
                                                "question": "What is the role of cytotoxic T cells?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Produce antibodies","B) Kill infected or cancerous cells directly","C) Present antigens","D) Suppress immune responses"]}',
                                                "answer": "B",
                                                "explanation": "Cytotoxic T cells (CD8+) recognize and kill cells displaying foreign antigens on MHC class I.",
                                            },
                                            {
                                                "question": "How do helper T cells help B cells produce antibodies?",
                                                "type": "short_answer",
                                                "answer": "Helper T cells release cytokines that stimulate B cell proliferation and differentiation into plasma cells.",
                                                "explanation": "T cell help is required for most B cell responses, including class switching and affinity maturation.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Bioinformatics",
                "slug": "bioinformatics",
                "description": "Computational methods for analyzing biological data.",
                "topics": [
                    {
                        "title": "Sequence Analysis",
                        "difficulty": "intermediate",
                        "description": "Comparing and analyzing biological sequences.",
                        "subtopics": [
                            {
                                "title": "Sequence Alignment",
                                "concepts": [
                                    {
                                        "title": "BLAST and Sequence Comparison",
                                        "description": "Tools and algorithms for finding sequence similarity.",
                                        "material_title": "Sequence Alignment Methods",
                                        "material_content": "Sequence alignment identifies regions of similarity between biological sequences. BLAST (Basic Local Alignment Search Tool) finds regions of local similarity between a query sequence and a database. Global alignment (Needleman-Wunsch) compares entire sequences; local alignment (Smith-Waterman) finds the best matching subsequences. Sequence similarity implies functional or evolutionary relationships. Substitution matrices (BLOSUM, PAM) score amino acid substitutions based on observed frequencies.",
                                        "practices": [
                                            {
                                                "question": "What does BLAST stand for?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Basic Local Alignment Search Tool","B) Biological Language Analysis Software Tool","C) Basic Linear Algebra Subroutines","D) Bioinformatics Lookup and Search Tool"]}',
                                                "answer": "A",
                                                "explanation": "BLAST is the most widely used tool for searching sequence databases for local similarity.",
                                            },
                                            {
                                                "question": "When would you use global vs. local alignment?",
                                                "type": "short_answer",
                                                "answer": "Global alignment for closely related sequences of similar length; local alignment for finding conserved domains in divergent sequences.",
                                                "explanation": "Global alignment aligns entire sequences end-to-end; local alignment finds the best matching regions.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Phylogenetics",
                                "concepts": [
                                    {
                                        "title": "Building Evolutionary Trees",
                                        "description": "Computing evolutionary relationships from sequence data.",
                                        "material_title": "Molecular Phylogenetics",
                                        "material_content": "Phylogenetic trees depict evolutionary relationships based on sequence data. Construction methods include maximum parsimony (fewest changes), maximum likelihood (most probable tree given a model), and neighbor-joining (distance-based clustering). Bootstrap analysis assesses branch support. Molecular clocks use mutation rates to estimate divergence times. Tree visualization tools display branch lengths proportional to evolutionary distance.",
                                        "practices": [
                                            {
                                                "question": "Which phylogenetic method finds the tree requiring the fewest evolutionary changes?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Maximum likelihood","B) Neighbor-joining","C) Maximum parsimony","D) Bayesian inference"]}',
                                                "answer": "C",
                                                "explanation": "Maximum parsimony selects the tree topology that minimizes the total number of character changes.",
                                            },
                                            {
                                                "question": "What does a bootstrap value on a phylogenetic tree represent?",
                                                "type": "short_answer",
                                                "answer": "The percentage of times a particular branch is supported across multiple resampled datasets.",
                                                "explanation": "Higher bootstrap values (e.g., >70%) indicate stronger statistical support for that branch.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
        ],
    },
    # ── 3. Chemistry ────────────────────────────────────────────────
    {
        "title": "Chemistry",
        "slug": "chemistry",
        "icon": "science",
        "color": "#F59E0B",
        "description": "The study of matter, its composition, structure, and transformations.",
        "disciplines": [
            {
                "title": "General Chemistry",
                "slug": "general-chemistry",
                "description": "Fundamental principles of chemical science.",
                "topics": [
                    {
                        "title": "Atomic Structure",
                        "difficulty": "foundational",
                        "description": "The composition and organization of atoms.",
                        "subtopics": [
                            {
                                "title": "Subatomic Particles",
                                "concepts": [
                                    {
                                        "title": "Protons, Neutrons, and Electrons",
                                        "description": "The three fundamental particles that make up atoms.",
                                        "material_title": "Atomic Components",
                                        "material_content": "Atoms consist of a nucleus containing protons (positive charge, mass ~1 amu) and neutrons (no charge, mass ~1 amu), surrounded by electrons (negative charge, mass ~1/1836 amu). The atomic number (Z) equals the number of protons and determines the element. The mass number (A) equals protons plus neutrons. Isotopes are atoms with the same Z but different A (different numbers of neutrons).",
                                        "practices": [
                                            {
                                                "question": "What determines the identity of an element?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Number of neutrons","B) Number of electrons","C) Number of protons","D) Mass number"]}',
                                                "answer": "C",
                                                "explanation": "The atomic number (number of protons) uniquely identifies each element.",
                                            },
                                            {
                                                "question": "How many neutrons does Carbon-14 have?",
                                                "type": "short_answer",
                                                "answer": "8 neutrons",
                                                "explanation": "Carbon has Z = 6 protons. Mass number A = 14, so neutrons = 14 - 6 = 8.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Electron Configuration",
                                "concepts": [
                                    {
                                        "title": "Quantum Numbers and Orbital Filling",
                                        "description": "How electrons are arranged in atoms.",
                                        "material_title": "Electron Configuration",
                                        "material_content": "Electrons occupy orbitals described by four quantum numbers: n (shell), l (subshell), ml (orbital), and ms (spin). Orbitals are filled according to the Aufbau principle (lowest energy first), Pauli exclusion principle (max 2 electrons per orbital with opposite spins), and Hund's rule (electrons occupy degenerate orbitals singly first). The order is 1s, 2s, 2p, 3s, 3p, 4s, 3d, 4p, etc.",
                                        "practices": [
                                            {
                                                "question": "What is the electron configuration of oxygen (Z=8)?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 1s2 2s2 2p4","B) 1s2 2s2 2p2","C) 1s2 2s2 2p6","D) 1s2 2s2 2p3 3s1"]}',
                                                "answer": "A",
                                                "explanation": "Oxygen has 8 electrons: 2 in 1s, 2 in 2s, and 4 in 2p (1s2 2s2 2p4).",
                                            },
                                            {
                                                "question": "How many electrons can a 3d subshell hold?",
                                                "type": "short_answer",
                                                "answer": "10 electrons",
                                                "explanation": "A d subshell has 5 orbitals, each holding 2 electrons: 5 x 2 = 10 electrons.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Chemical Bonding",
                        "difficulty": "foundational",
                        "description": "How atoms combine to form molecules.",
                        "subtopics": [
                            {
                                "title": "Types of Chemical Bonds",
                                "concepts": [
                                    {
                                        "title": "Ionic, Covalent, and Metallic Bonds",
                                        "description": "The three primary types of chemical bonding.",
                                        "material_title": "Chemical Bond Types",
                                        "material_content": "Ionic bonds form when electrons transfer between atoms (typically metal + nonmetal), creating ions held by electrostatic attraction (e.g., NaCl). Covalent bonds form when atoms share electrons (typically nonmetal + nonmetal), creating molecules (e.g., H2O). Metallic bonds involve a 'sea' of delocalized electrons shared among metal atoms, enabling conductivity and malleability. Bond type depends on the electronegativity difference between atoms.",
                                        "practices": [
                                            {
                                                "question": "What type of bond forms between sodium and chlorine?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Covalent","B) Ionic","C) Metallic","D) Hydrogen"]}',
                                                "answer": "B",
                                                "explanation": "Sodium (metal, low electronegativity) transfers an electron to chlorine (nonmetal, high electronegativity), forming an ionic bond.",
                                            },
                                            {
                                                "question": "Why do metals conduct electricity?",
                                                "type": "short_answer",
                                                "answer": "Delocalized electrons in the metallic bond are free to move and carry charge.",
                                                "explanation": "The sea of electrons can flow through the metal lattice when a potential difference is applied.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Lewis Structures",
                                "concepts": [
                                    {
                                        "title": "Drawing Lewis Dot Structures",
                                        "description": "Representing bonding in molecules.",
                                        "material_title": "Lewis Structure Rules",
                                        "material_content": "Lewis structures show bonding and lone pairs using dots (electrons) and lines (bonds). Steps: count total valence electrons, arrange atoms with the least electronegative in the center, connect atoms with single bonds, distribute remaining electrons as lone pairs, and form multiple bonds if atoms lack octets. The octet rule states atoms tend to have 8 valence electrons (2 for hydrogen). Formal charge helps identify the most stable resonance structure.",
                                        "practices": [
                                            {
                                                "question": "How many valence electrons does water (H2O) have?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 6","B) 8","C) 10","D) 12"]}',
                                                "answer": "B",
                                                "explanation": "H contributes 1 each (x2 = 2), O contributes 6. Total = 2 + 6 = 8 valence electrons.",
                                            },
                                            {
                                                "question": "What is the octet rule?",
                                                "type": "short_answer",
                                                "answer": "Atoms tend to bond such that they have 8 electrons in their valence shell.",
                                                "explanation": "This gives them the electron configuration of a noble gas, which is energetically favorable.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Organic Chemistry",
                "slug": "organic-chemistry",
                "description": "The chemistry of carbon-containing compounds.",
                "topics": [
                    {
                        "title": "Hydrocarbons",
                        "difficulty": "foundational",
                        "description": "Organic compounds containing only carbon and hydrogen.",
                        "subtopics": [
                            {
                                "title": "Alkanes and Alkenes",
                                "concepts": [
                                    {
                                        "title": "Saturated and Unsaturated Hydrocarbons",
                                        "description": "Classification by bonding type.",
                                        "material_title": "Hydrocarbon Classification",
                                        "material_content": "Alkanes are saturated hydrocarbons with only single C-C bonds (CnH2n+2). They are relatively unreactive and undergo combustion and substitution reactions. Alkenes contain at least one C=C double bond (CnH2n) and are unsaturated. The double bond makes alkenes more reactive, undergoing addition reactions (e.g., hydrogenation, halogenation). cis-trans isomerism is possible due to restricted rotation around the double bond.",
                                        "practices": [
                                            {
                                                "question": "What is the general formula for alkanes?",
                                                "type": "mcq",
                                                "options": '{"options":["A) CnH2n","B) CnH2n+2","C) CnH2n-2","D) CnHn"]}',
                                                "answer": "B",
                                                "explanation": "Alkanes follow the formula CnH2n+2 for straight-chain saturated hydrocarbons.",
                                            },
                                            {
                                                "question": "Why are alkenes more reactive than alkanes?",
                                                "type": "short_answer",
                                                "answer": "The C=C double bond contains a pi bond that is weaker and more accessible for reactions.",
                                                "explanation": "Pi bonds can break to form new sigma bonds, making addition reactions favorable.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Functional Groups",
                                "concepts": [
                                    {
                                        "title": "Major Functional Groups",
                                        "description": "Reactive groups that determine chemical behavior.",
                                        "material_title": "Organic Functional Groups",
                                        "material_content": "Functional groups are specific groupings of atoms that determine a molecule's chemical properties. Key groups include: hydroxyl (-OH, alcohols), carbonyl (C=O, aldehydes/ketones), carboxyl (-COOH, carboxylic acids), amino (-NH2, amines), ester (-COO-, esters), and ether (C-O-C). The functional group defines the molecule's reactivity, polarity, and biological activity regardless of the carbon chain length.",
                                        "practices": [
                                            {
                                                "question": "Which functional group is found in carboxylic acids?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Hydroxyl","B) Amino","C) Carboxyl","D) Ester"]}',
                                                "answer": "C",
                                                "explanation": "The carboxyl group (-COOH) is characteristic of carboxylic acids, making them acidic.",
                                            },
                                            {
                                                "question": "What distinguishes an aldehyde from a ketone?",
                                                "type": "short_answer",
                                                "answer": "Aldehydes have the carbonyl group at the end of the carbon chain (R-CHO); ketones have it in the middle (R-CO-R').",
                                                "explanation": "Position of the C=O group determines whether it is an aldehyde or a ketone.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Organic Reactions",
                        "difficulty": "intermediate",
                        "description": "Mechanisms of organic transformations.",
                        "subtopics": [
                            {
                                "title": "Substitution and Addition Reactions",
                                "concepts": [
                                    {
                                        "title": "Nucleophilic and Electrophilic Reactions",
                                        "description": "Core reaction mechanisms in organic chemistry.",
                                        "material_title": "Organic Reaction Mechanisms",
                                        "material_content": "Nucleophilic substitution (SN1 and SN2) replaces a leaving group with a nucleophile. SN2 is a one-step backside attack with inversion of configuration; SN1 proceeds through a carbocation intermediate with possible racemization. Electrophilic addition to alkenes breaks the pi bond as the electrophile and nucleophile add across the double bond. Elimination reactions (E1, E2) remove atoms to form double bonds.",
                                        "practices": [
                                            {
                                                "question": "What is the key difference between SN1 and SN2 mechanisms?",
                                                "type": "mcq",
                                                "options": '{"options":["A) SN1 is faster","B) SN2 is two-step, SN1 is one-step","C) SN1 is two-step, SN2 is one-step","D) They have the same mechanism"]}',
                                                "answer": "C",
                                                "explanation": "SN1 proceeds through a carbocation intermediate (two steps); SN2 is concerted (one step).",
                                            },
                                            {
                                                "question": "What product forms when HBr adds to propene?",
                                                "type": "short_answer",
                                                "answer": "2-bromopropane (Markovnikov product)",
                                                "explanation": "The H adds to the less substituted carbon and Br to the more substituted carbon (Markovnikov's rule).",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Stereochemistry",
                                "concepts": [
                                    {
                                        "title": "Chirality and Optical Activity",
                                        "description": "Three-dimensional arrangement of atoms in molecules.",
                                        "material_title": "Stereoisomerism",
                                        "material_content": "Chiral molecules are non-superimposable mirror images (like left and right hands). A carbon bonded to four different groups is a chiral center. Enantiomers are mirror-image stereoisomers with identical physical properties except for rotating plane-polarized light in opposite directions (optical activity). Diastereomers are non-mirror-image stereoisomers with different physical properties. R/S nomenclature assigns absolute configuration using Cahn-Ingold-Prelog priority rules.",
                                        "practices": [
                                            {
                                                "question": "What makes a molecule chiral?",
                                                "type": "mcq",
                                                "options": '{"options":["A) It has double bonds","B) It cannot be superimposed on its mirror image","C) It has hydrogen atoms","D) It rotates light"]}',
                                                "answer": "B",
                                                "explanation": "Chirality requires non-superimposability on the mirror image, typically due to a chiral center.",
                                            },
                                            {
                                                "question": "What is the difference between enantiomers and diastereomers?",
                                                "type": "short_answer",
                                                "answer": "Enantiomers are mirror images; diastereomers are not mirror images but are still stereoisomers.",
                                                "explanation": "Enantiomers have opposite configurations at all chiral centers; diastereomers differ at some but not all.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Inorganic Chemistry",
                "slug": "inorganic-chemistry",
                "description": "The chemistry of non-carbon-based compounds.",
                "topics": [
                    {
                        "title": "Periodic Trends",
                        "difficulty": "foundational",
                        "description": "Patterns in elemental properties across the periodic table.",
                        "subtopics": [
                            {
                                "title": "Trends in Properties",
                                "concepts": [
                                    {
                                        "title": "Atomic Radius, Ionization Energy, and Electronegativity",
                                        "description": "How atomic properties vary across periods and groups.",
                                        "material_title": "Periodic Trends",
                                        "material_content": "Atomic radius decreases across a period (more protons pull electrons closer) and increases down a group (more electron shells). Ionization energy (energy to remove an electron) increases across a period and decreases down a group. Electronegativity (ability to attract bonding electrons) follows the same trend as ionization energy, with fluorine being the most electronegative element. Electron affinity generally increases across a period.",
                                        "practices": [
                                            {
                                                "question": "Which element has the highest electronegativity?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Oxygen","B) Fluorine","C) Chlorine","D) Nitrogen"]}',
                                                "answer": "B",
                                                "explanation": "Fluorine has the highest electronegativity (3.98 on the Pauling scale) of all elements.",
                                            },
                                            {
                                                "question": "Why does atomic radius decrease across a period?",
                                                "type": "short_answer",
                                                "answer": "Increasing nuclear charge (more protons) pulls electrons in the same shell closer to the nucleus.",
                                                "explanation": "Electrons added to the same shell do not shield each other effectively from the increasing nuclear charge.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Transition Metal Chemistry",
                                "concepts": [
                                    {
                                        "title": "Coordination Compounds",
                                        "description": "Complexes formed by transition metals with ligands.",
                                        "material_title": "Coordination Chemistry",
                                        "material_content": "Transition metals form coordination complexes with ligands (molecules or ions that donate electron pairs). The coordination number is the number of ligand donor atoms bonded to the metal. Common geometries include octahedral (6-coordinate), tetrahedral (4-coordinate), and square planar (4-coordinate). Crystal field theory explains the splitting of d-orbital energies by ligands, determining color and magnetic properties.",
                                        "practices": [
                                            {
                                                "question": "What is the coordination number in [Co(NH3)6]3+?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 3","B) 4","C) 6","D) 8"]}',
                                                "answer": "C",
                                                "explanation": "Six NH3 ligands are bonded to the cobalt center, giving a coordination number of 6.",
                                            },
                                            {
                                                "question": "Why are transition metal complexes often colored?",
                                                "type": "short_answer",
                                                "answer": "Ligands split d-orbital energies; electrons absorb visible light to jump between split orbitals.",
                                                "explanation": "The energy gap between split d-orbitals corresponds to visible light wavelengths.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Physical Chemistry",
                "slug": "physical-chemistry",
                "description": "The physics of chemical systems and processes.",
                "topics": [
                    {
                        "title": "Chemical Thermodynamics",
                        "difficulty": "intermediate",
                        "description": "Energy changes in chemical reactions.",
                        "subtopics": [
                            {
                                "title": "Enthalpy and Entropy",
                                "concepts": [
                                    {
                                        "title": "Thermodynamic Functions",
                                        "description": "Measuring heat, disorder, and free energy.",
                                        "material_title": "Thermodynamic Quantities",
                                        "material_content": "Enthalpy (H) measures heat flow at constant pressure; exothermic reactions have negative delta-H, endothermic have positive. Entropy (S) measures disorder; the Second Law states the total entropy of the universe always increases. Gibbs free energy (G = H - TS) determines spontaneity: negative delta-G means the reaction is spontaneous. Hess's Law allows calculation of reaction enthalpies from intermediate steps.",
                                        "practices": [
                                            {
                                                "question": "What does a negative delta-G indicate about a reaction?",
                                                "type": "mcq",
                                                "options": '{"options":["A) The reaction is endothermic","B) The reaction is spontaneous","C) The reaction is slow","D) The reaction has high entropy"]}',
                                                "answer": "B",
                                                "explanation": "A negative Gibbs free energy change indicates a thermodynamically spontaneous process.",
                                            },
                                            {
                                                "question": "State the Second Law of Thermodynamics.",
                                                "type": "short_answer",
                                                "answer": "The total entropy of an isolated system always increases over time.",
                                                "explanation": "Spontaneous processes lead to greater overall disorder in the universe.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Chemical Equilibrium",
                                "concepts": [
                                    {
                                        "title": "Equilibrium Constants and Le Chatelier's Principle",
                                        "description": "Predicting the direction of chemical change.",
                                        "material_title": "Chemical Equilibrium",
                                        "material_content": "At equilibrium, forward and reverse reaction rates are equal. The equilibrium constant K = [products]/[reactants] (raised to stoichiometric coefficients) is constant at a given temperature. K > 1 favors products; K < 1 favors reactants. Le Chatelier's principle states that a system at equilibrium responds to disturbances (concentration, pressure, temperature changes) by shifting to counteract the change.",
                                        "practices": [
                                            {
                                                "question": "For the reaction A + B <-> C + D, what is K if [A]=[B]=[C]=[D]=0.5 M?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 0.25","B) 0.5","C) 1","D) 2"]}',
                                                "answer": "C",
                                                "explanation": "K = (0.5 x 0.5)/(0.5 x 0.5) = 0.25/0.25 = 1.",
                                            },
                                            {
                                                "question": "How does increasing pressure affect the equilibrium N2(g) + 3H2(g) <-> 2NH3(g)?",
                                                "type": "short_answer",
                                                "answer": "The equilibrium shifts to the right (toward products) because there are fewer moles of gas on the product side.",
                                                "explanation": "Le Chatelier's principle: increased pressure favors the side with fewer gas molecules.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Analytical Chemistry",
                "slug": "analytical-chemistry",
                "description": "Methods for identifying and quantifying chemical substances.",
                "topics": [
                    {
                        "title": "Qualitative Analysis",
                        "difficulty": "intermediate",
                        "description": "Identifying the components of a substance.",
                        "subtopics": [
                            {
                                "title": "Chemical Tests",
                                "concepts": [
                                    {
                                        "title": "Identification Reactions",
                                        "description": "Reactions used to detect specific ions and functional groups.",
                                        "material_title": "Qualitative Analysis Methods",
                                        "material_content": "Qualitative analysis identifies what is present in a sample. Flame tests produce characteristic colors: sodium (yellow), copper (green), lithium (red). Precipitation reactions identify ions: silver chloride precipitates with Ag+, barium sulfate with Ba2+. pH indicators reveal acidity or alkalinity. Limewater turns milky with CO2. Benedict's test detects reducing sugars; iodine test detects starch.",
                                        "practices": [
                                            {
                                                "question": "What color flame does copper produce?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Yellow","B) Red","C) Green","D) Purple"]}',
                                                "answer": "C",
                                                "explanation": "Copper compounds produce a characteristic green or blue-green flame.",
                                            },
                                            {
                                                "question": "How do you test for the presence of chloride ions?",
                                                "type": "short_answer",
                                                "answer": "Add silver nitrate solution; a white precipitate (AgCl) forms that dissolves in dilute ammonia.",
                                                "explanation": "Ag+ + Cl- -> AgCl(s), which is insoluble in acid but soluble in aqueous ammonia.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Chromatography",
                                "concepts": [
                                    {
                                        "title": "Separation Techniques",
                                        "description": "Methods for separating mixtures into components.",
                                        "material_title": "Chromatography Principles",
                                        "material_content": "Chromatography separates mixtures based on differential partitioning between a stationary phase and a mobile phase. Thin-layer chromatography (TLC) uses a silica gel plate and solvent; components separate based on polarity. Gas chromatography (GC) separates volatile compounds by boiling point and polarity. High-performance liquid chromatography (HPLC) provides high-resolution separation. Each component has a characteristic retention time (Rf value in TLC).",
                                        "practices": [
                                            {
                                                "question": "In TLC, which compound travels farther: a polar or nonpolar compound on silica gel?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Polar compound","B) Nonpolar compound","C) They travel the same distance","D) Depends on solvent"]}',
                                                "answer": "B",
                                                "explanation": "Silica gel is polar, so polar compounds adsorb more strongly and travel less. Nonpolar compounds travel farther.",
                                            },
                                            {
                                                "question": "What is the Rf value in TLC?",
                                                "type": "short_answer",
                                                "answer": "The ratio of the distance traveled by the compound to the distance traveled by the solvent front.",
                                                "explanation": "Rf = distance of spot / distance of solvent front, ranging from 0 to 1.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Thermochemistry",
                "slug": "thermochemistry",
                "description": "Heat energy changes in chemical reactions.",
                "topics": [
                    {
                        "title": "Energy in Reactions",
                        "difficulty": "intermediate",
                        "description": "Measuring and predicting heat flow.",
                        "subtopics": [
                            {
                                "title": "Calorimetry",
                                "concepts": [
                                    {
                                        "title": "Measuring Reaction Enthalpies",
                                        "description": "Techniques for quantifying heat changes.",
                                        "material_title": "Calorimetry Methods",
                                        "material_content": "Calorimetry measures heat flow during reactions. A coffee-c calorimeter is used for simple measurements: q = mc*delta-T, where m is mass, c is specific heat capacity, and delta-T is temperature change. Bomb calorimeters measure combustion enthalpies at constant volume. The heat capacity of the calorimeter must be calibrated. Exothermic reactions release heat (positive q for surroundings, negative delta-H); endothermic reactions absorb heat.",
                                        "practices": [
                                            {
                                                "question": "What is the formula for calculating heat using a coffee-cup calorimeter?",
                                                "type": "mcq",
                                                "options": '{"options":["A) q = nRT","B) q = mc*delta-T","C) q = PV","D) q = delta-H/2"]}',
                                                "answer": "B",
                                                "explanation": "q = mc(delta-T) relates heat absorbed or released to mass, specific heat, and temperature change.",
                                            },
                                            {
                                                "question": "A 50g sample of water heats from 20C to 45C. How much heat is absorbed? (c = 4.18 J/g*C)",
                                                "type": "short_answer",
                                                "answer": "5225 J or 5.225 kJ",
                                                "explanation": "q = 50 x 4.18 x 25 = 5225 J = 5.225 kJ.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Hess's Law",
                                "concepts": [
                                    {
                                        "title": "Using Hess's Law to Calculate Enthalpy",
                                        "description": "Adding reaction enthalpies for multi-step processes.",
                                        "material_title": "Hess's Law Application",
                                        "material_content": "Hess's Law states that the total enthalpy change of a reaction is independent of the pathway and depends only on initial and final states. This allows calculation of delta-H for reactions that cannot be measured directly by combining known reaction enthalpies. When reversing a reaction, the sign of delta-H flips. When multiplying by a coefficient, delta-H is multiplied by the same factor. Enthalpies of formation (delta-Hf) can be used: delta-Hrxn = sum(delta-Hf products) - sum(delta-Hf reactants).",
                                        "practices": [
                                            {
                                                "question": "If reaction A has delta-H = -100 kJ and reaction B has delta-H = +50 kJ, what is delta-H for A + B?",
                                                "type": "mcq",
                                                "options": '{"options":["A) -150 kJ","B) -50 kJ","C) +50 kJ","D) +150 kJ"]}',
                                                "answer": "B",
                                                "explanation": "By Hess's Law: delta-H total = -100 + 50 = -50 kJ.",
                                            },
                                            {
                                                "question": "If you reverse a reaction, how does delta-H change?",
                                                "type": "short_answer",
                                                "answer": "The sign of delta-H reverses (exothermic becomes endothermic and vice versa).",
                                                "explanation": "Reversing a reaction means the heat flow direction is reversed.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Electrochemistry",
                "slug": "electrochemistry",
                "description": "Chemical reactions involving electrical energy.",
                "topics": [
                    {
                        "title": "Galvanic Cells",
                        "difficulty": "intermediate",
                        "description": "Voltaic cells that generate electricity from redox reactions.",
                        "subtopics": [
                            {
                                "title": "Cell Potential",
                                "concepts": [
                                    {
                                        "title": "Standard Electrode Potentials",
                                        "description": "Measuring the tendency of half-reactions to occur.",
                                        "material_title": "Electrode Potentials",
                                        "material_content": "Standard electrode potentials (E0) measure the tendency of a half-reaction to occur relative to the standard hydrogen electrode (SHE, defined as 0V). The cell potential E0cell = E0cathode - E0anode. A positive E0cell indicates a spontaneous reaction (negative delta-G). The Nernst equation adjusts for non-standard conditions: E = E0 - (RT/nF)*ln(Q). Higher E0 values indicate stronger oxidizing agents.",
                                        "practices": [
                                            {
                                                "question": "If E0(Cu2+/Cu) = +0.34V and E0(Zn2+/Zn) = -0.76V, what is the cell potential for a Cu-Zn galvanic cell?",
                                                "type": "mcq",
                                                "options": '{"options":["A) -0.42V","B) 0.42V","C) 1.10V","D) -1.10V"]}',
                                                "answer": "C",
                                                "explanation": "E0cell = E0cathode - E0anode = 0.34 - (-0.76) = 1.10V.",
                                            },
                                            {
                                                "question": "What does a positive cell potential indicate?",
                                                "type": "short_answer",
                                                "answer": "The redox reaction is spontaneous (delta-G is negative).",
                                                "explanation": "Positive E0cell corresponds to negative delta-G via delta-G = -nFE0cell.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Electrolytic Cells",
                                "concepts": [
                                    {
                                        "title": "Electrolysis",
                                        "description": "Using electrical energy to drive non-spontaneous reactions.",
                                        "material_title": "Electrolysis",
                                        "material_content": "Electrolysis uses an external voltage to force non-spontaneous redox reactions. At the cathode (reduction): metal ions deposit, or water is reduced to H2 gas. At the anode (oxidation): halides are oxidized, or water is oxidized to O2. Faraday's law states: mass deposited = (Q x M)/(n x F), where Q is charge, M is molar mass, n is electron count, and F is Faraday's constant (96,485 C/mol). Applications include aluminum extraction, electroplating, and water splitting.",
                                        "practices": [
                                            {
                                                "question": "In electrolysis of aqueous NaCl, what gas is produced at the anode?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Hydrogen","B) Sodium","C) Chlorine","D) Oxygen"]}',
                                                "answer": "C",
                                                "explanation": "Chloride ions are oxidized at the anode: 2Cl- -> Cl2 + 2e-.",
                                            },
                                            {
                                                "question": "State Faraday's first law of electrolysis.",
                                                "type": "short_answer",
                                                "answer": "The mass of substance deposited at an electrode is proportional to the quantity of electricity passed.",
                                                "explanation": "m = (Q x M)/(n x F), directly relating mass to charge.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Nuclear Chemistry",
                "slug": "nuclear-chemistry",
                "description": "Radioactivity and nuclear transformations.",
                "topics": [
                    {
                        "title": "Radioactive Decay",
                        "difficulty": "advanced",
                        "description": "Spontaneous nuclear disintegration.",
                        "subtopics": [
                            {
                                "title": "Types of Radiation",
                                "concepts": [
                                    {
                                        "title": "Alpha, Beta, and Gamma Decay",
                                        "description": "Different modes of radioactive decay.",
                                        "material_title": "Radioactive Decay Types",
                                        "material_content": "Alpha decay emits a helium nucleus (2p + 2n), reducing atomic number by 2 and mass by 4. Beta decay converts a neutron to a proton, emitting an electron (beta-minus) or converting a proton to a neutron, emitting a positron (beta-plus). Gamma decay releases high-energy photons from excited nuclei without changing Z or A. Each type has different penetrating power: alpha (stopped by paper), beta (stopped by aluminum), gamma (requires thick lead).",
                                        "practices": [
                                            {
                                                "question": "What happens to the atomic number during alpha decay?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Increases by 2","B) Decreases by 2","C) Stays the same","D) Decreases by 4"]}',
                                                "answer": "B",
                                                "explanation": "Alpha decay ejects 2 protons, so the atomic number decreases by 2.",
                                            },
                                            {
                                                "question": "What is the half-life concept?",
                                                "type": "short_answer",
                                                "answer": "The time required for half of a radioactive sample to decay.",
                                                "explanation": "Each radioactive isotope has a characteristic, constant half-life regardless of conditions.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Nuclear Fission and Fusion",
                                "concepts": [
                                    {
                                        "title": "Nuclear Energy Reactions",
                                        "description": "Splitting and combining atomic nuclei.",
                                        "material_title": "Fission and Fusion",
                                        "material_content": "Nuclear fission splits heavy nuclei (e.g., U-235) into lighter fragments, releasing enormous energy and more neutrons that can sustain a chain reaction. Nuclear fusion combines light nuclei (e.g., hydrogen isotopes) into heavier ones (helium), releasing even more energy per unit mass. The sun operates via fusion. Fission is used in nuclear power plants; fusion remains a goal for future clean energy. Both convert small amounts of mass to energy via E=mc^2.",
                                        "practices": [
                                            {
                                                "question": "Which process powers the Sun?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Nuclear fission","B) Nuclear fusion","C) Chemical combustion","D) Gravitational compression"]}',
                                                "answer": "B",
                                                "explanation": "The Sun generates energy through the fusion of hydrogen nuclei into helium.",
                                            },
                                            {
                                                "question": "Write the fission equation for U-235 absorption of a neutron.",
                                                "type": "short_answer",
                                                "answer": "U-235 + n -> Ba-141 + Kr-92 + 3n + energy",
                                                "explanation": "One common fission pathway: uranium-235 absorbs a neutron and splits into barium-141, krypton-92, and three neutrons.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Environmental Chemistry",
                "slug": "environmental-chemistry",
                "description": "Chemical processes in the natural environment.",
                "topics": [
                    {
                        "title": "Atmospheric Chemistry",
                        "difficulty": "intermediate",
                        "description": "Chemical reactions in Earth's atmosphere.",
                        "subtopics": [
                            {
                                "title": "Ozone Chemistry",
                                "concepts": [
                                    {
                                        "title": "Ozone Layer and Ozone Depletion",
                                        "description": "Chemical processes affecting stratospheric ozone.",
                                        "material_title": "Atmospheric Ozone",
                                        "material_content": "Stratospheric ozone (O3) absorbs UV-B and UV-C radiation, protecting life on Earth. The Chapman cycle describes ozone formation (O2 + UV -> 2O, O + O2 -> O3) and destruction. Chlorofluorocarbons (CFCs) release chlorine atoms that catalytically destroy ozone: Cl + O3 -> ClO + O2, ClO + O -> Cl + O2. One chlorine atom can destroy thousands of ozone molecules. The Montreal Protocol (1987) phased out CFC production.",
                                        "practices": [
                                            {
                                                "question": "What is the role of stratospheric ozone?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Absorbs infrared radiation","B) Absorbs harmful UV radiation","C) Produces oxygen","D) Absorbs X-rays"]}',
                                                "answer": "B",
                                                "explanation": "Ozone absorbs UV-B and UV-C radiation, protecting organisms from DNA damage.",
                                            },
                                            {
                                                "question": "How do CFCs destroy ozone?",
                                                "type": "short_answer",
                                                "answer": "CFCs release chlorine atoms that catalytically decompose ozone molecules.",
                                                "explanation": "One Cl atom participates in a cycle that destroys many O3 molecules before being deactivated.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Air Pollution",
                                "concepts": [
                                    {
                                        "title": "Photochemical Smog",
                                        "description": "Formation and effects of urban air pollution.",
                                        "material_title": "Smog Formation",
                                        "material_content": "Photochemical smog forms when nitrogen oxides (NOx) and volatile organic compounds (VOCs) react in sunlight. NO2 absorbs UV light to produce atomic oxygen, which combines with O2 to form ground-level ozone (a respiratory irritant). PAN (peroxyacetyl nitrate) and aldehydes are also formed. Temperature inversions trap pollutants near the ground. Reducing vehicle emissions and industrial NOx/VOC releases helps control smog.",
                                        "practices": [
                                            {
                                                "question": "What are the main precursors of photochemical smog?",
                                                "type": "mcq",
                                                "options": '{"options":["A) CO2 and H2O","B) NOx and VOCs","C) SO2 and NH3","D) CH4 and O2"]}',
                                                "answer": "B",
                                                "explanation": "Nitrogen oxides and volatile organic compounds react in sunlight to form smog components.",
                                            },
                                            {
                                                "question": "What is ground-level ozone and why is it harmful?",
                                                "type": "short_answer",
                                                "answer": "Ground-level O3 is a pollutant formed from NOx and VOCs in sunlight; it irritates lungs and damages plants.",
                                                "explanation": "Unlike stratospheric ozone (beneficial), tropospheric ozone is a health hazard.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Polymer Chemistry",
                "slug": "polymer-chemistry",
                "description": "The chemistry of large molecular networks.",
                "topics": [
                    {
                        "title": "Polymer Structure",
                        "difficulty": "intermediate",
                        "description": "How monomers connect to form polymers.",
                        "subtopics": [
                            {
                                "title": "Polymerization Reactions",
                                "concepts": [
                                    {
                                        "title": "Addition and Condensation Polymerization",
                                        "description": "Two main mechanisms for forming polymers.",
                                        "material_title": "Polymerization Mechanisms",
                                        "material_content": "Addition (chain-growth) polymerization involves opening double bonds in monomers (e.g., ethylene -> polyethylene). It proceeds through initiation, propagation, and termination steps. Condensation (step-growth) polymerization joins monomers with the loss of a small molecule like water (e.g., amino acids -> nylon). The degree of polymerization determines molecular weight. Cross-linking connects polymer chains, creating stronger materials (e.g., vulcanized rubber).",
                                        "practices": [
                                            {
                                                "question": "Which polymerization type produces nylon?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Addition polymerization","B) Condensation polymerization","C) Radial polymerization","D) Coordination polymerization"]}',
                                                "answer": "B",
                                                "explanation": "Nylon is formed by condensation of diamine and diacid monomers with loss of water.",
                                            },
                                            {
                                                "question": "What is the difference between thermoplastics and thermosets?",
                                                "type": "short_answer",
                                                "answer": "Thermoplastics soften when heated (no cross-linking); thermosets harden permanently (cross-linked).",
                                                "explanation": "Cross-linked polymers cannot be remelted; linear polymers can be reshaped.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Natural and Synthetic Polymers",
                                "concepts": [
                                    {
                                        "title": "Biological Polymers",
                                        "description": "Macromolecules essential to life.",
                                        "material_title": "Natural Polymers",
                                        "material_content": "Proteins are polymers of amino acids linked by peptide bonds. Nucleic acids (DNA, RNA) are polymers of nucleotides linked by phosphodiester bonds. Polysaccharides (starch, cellulose, glycogen) are polymers of monosaccharides linked by glycosidic bonds. Rubber (polyisoprene) is a natural polymer. These biological polymers have specific structures that determine their functions, unlike many synthetic polymers.",
                                        "practices": [
                                            {
                                                "question": "What type of bond links amino acids in proteins?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Glycosidic bond","B) Peptide bond","C) Phosphodiester bond","D) Hydrogen bond"]}',
                                                "answer": "B",
                                                "explanation": "Peptide bonds form between the carboxyl group of one amino acid and the amino group of another.",
                                            },
                                            {
                                                "question": "What monomer makes up cellulose?",
                                                "type": "short_answer",
                                                "answer": "Glucose",
                                                "explanation": "Cellulose is a polysaccharide of beta-1,4 linked glucose units.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Spectroscopy",
                "slug": "spectroscopy",
                "description": "The study of matter using electromagnetic radiation.",
                "topics": [
                    {
                        "title": "UV-Vis and IR Spectroscopy",
                        "difficulty": "intermediate",
                        "description": "Absorption spectroscopy in different wavelength ranges.",
                        "subtopics": [
                            {
                                "title": "UV-Visible Spectroscopy",
                                "concepts": [
                                    {
                                        "title": "Electronic Transitions",
                                        "description": "Light absorption by molecules in the UV-Vis range.",
                                        "material_title": "UV-Vis Spectroscopy",
                                        "material_content": "UV-Vis spectroscopy measures the absorption of ultraviolet and visible light (200-800 nm) by molecules. Absorption causes electronic transitions: sigma to sigma*, n to sigma*, pi to pi*, and n to pi* transitions. Conjugated systems absorb at longer wavelengths (bathochromic shift). Beer-Lambert Law: A = epsilon*b*c, where A is absorbance, epsilon is molar absorptivity, b is path length, and c is concentration. This enables quantitative analysis.",
                                        "practices": [
                                            {
                                                "question": "What does the Beer-Lambert Law relate?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Wavelength and frequency","B) Absorbance and concentration","C) Mass and volume","D) Pressure and temperature"]}',
                                                "answer": "B",
                                                "explanation": "Beer-Lambert Law: A = epsilon*bc, directly relating absorbance to concentration.",
                                            },
                                            {
                                                "question": "What effect does increasing conjugation have on lambda-max?",
                                                "type": "short_answer",
                                                "answer": "It shifts lambda-max to longer wavelengths (bathochromic shift).",
                                                "explanation": "More conjugated pi bonds lower the energy gap between HOMO and LUMO.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Infrared Spectroscopy",
                                "concepts": [
                                    {
                                        "title": "Molecular Vibrations",
                                        "description": "Identification of functional groups by IR absorption.",
                                        "material_title": "IR Spectroscopy",
                                        "material_content": "Infrared spectroscopy measures molecular vibrations (stretching, bending) when IR radiation is absorbed. Each functional group has characteristic absorption frequencies: O-H stretch (2500-3300 cm-1, broad), N-H stretch (3300-3500 cm-1), C=O stretch (1650-1750 cm-1, strong), C-O stretch (1000-1300 cm-1). The fingerprint region (below 1500 cm-1) is unique to each compound. IR spectroscopy is used for functional group identification and compound confirmation.",
                                        "practices": [
                                            {
                                                "question": "A strong absorption at 1715 cm-1 indicates which functional group?",
                                                "type": "mcq",
                                                "options": '{"options":["A) O-H","B) N-H","C) C=O","D) C-O"]}',
                                                "answer": "C",
                                                "explanation": "The strong absorption near 1715 cm-1 is characteristic of a carbonyl (C=O) stretching vibration.",
                                            },
                                            {
                                                "question": "Why is the O-H stretch in carboxylic acids very broad?",
                                                "type": "short_answer",
                                                "answer": "Due to extensive hydrogen bonding between carboxylic acid molecules.",
                                                "explanation": "Hydrogen bonding weakens O-H bonds unevenly, creating a range of absorption frequencies.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Chemical Kinetics",
                "slug": "chemical-kinetics",
                "description": "The rates and mechanisms of chemical reactions.",
                "topics": [
                    {
                        "title": "Reaction Rates",
                        "difficulty": "intermediate",
                        "description": "Measuring how fast reactions proceed.",
                        "subtopics": [
                            {
                                "title": "Rate Laws",
                                "concepts": [
                                    {
                                        "title": "Rate Law and Reaction Order",
                                        "description": "Mathematical expressions relating rate to concentration.",
                                        "material_title": "Rate Law Expressions",
                                        "material_content": "The rate law expresses how reaction rate depends on reactant concentrations: rate = k[A]^m[B]^n. The exponents m and n are reaction orders (determined experimentally, not from stoichiometry). k is the rate constant (units depend on overall order). Zero-order: rate is constant. First-order: rate proportional to concentration. Second-order: rate proportional to concentration squared. The integrated rate laws give concentration-time relationships.",
                                        "practices": [
                                            {
                                                "question": "For a first-order reaction with k = 0.05 min^-1, what is the half-life?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 5 min","B) 10 min","C) 13.86 min","D) 20 min"]}',
                                                "answer": "C",
                                                "explanation": "t1/2 = ln(2)/k = 0.693/0.05 = 13.86 min.",
                                            },
                                            {
                                                "question": "What is the units of k for a second-order reaction?",
                                                "type": "short_answer",
                                                "answer": "M^-1 * time^-1 (e.g., L/(mol*s))",
                                                "explanation": "For rate = k[A]^2, k = rate/[A]^2, giving units of M^-1 * time^-1.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Activation Energy",
                                "concepts": [
                                    {
                                        "title": "The Arrhenius Equation",
                                        "description": "Relating temperature to reaction rate.",
                                        "material_title": "Arrhenius Equation",
                                        "material_content": "The Arrhenius equation k = Ae^(-Ea/RT) relates the rate constant to temperature. Ea is the activation energy (minimum energy for reaction), A is the pre-exponential factor, R is the gas constant, and T is temperature in Kelvin. Higher temperature increases k exponentially. The two-temperature form ln(k2/k1) = (Ea/R)(1/T1 - 1/T2) allows calculation of Ea from rate data at two temperatures. Catalysts lower Ea without being consumed.",
                                        "practices": [
                                            {
                                                "question": "How does a catalyst affect the activation energy?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Increases it","B) Decreases it","C) No effect","D) Eliminates it"]}',
                                                "answer": "B",
                                                "explanation": "Catalysts provide an alternative reaction pathway with lower activation energy.",
                                            },
                                            {
                                                "question": "What happens to the rate constant when temperature increases?",
                                                "type": "short_answer",
                                                "answer": "It increases exponentially according to the Arrhenius equation.",
                                                "explanation": "More molecules have sufficient energy to overcome the activation energy barrier.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Quantum Chemistry",
                "slug": "quantum-chemistry",
                "description": "Applying quantum mechanics to chemical systems.",
                "topics": [
                    {
                        "title": "Quantum Mechanical Model",
                        "difficulty": "advanced",
                        "description": "Mathematical description of atomic and molecular behavior.",
                        "subtopics": [
                            {
                                "title": "Wave-Particle Duality",
                                "concepts": [
                                    {
                                        "title": "De Broglie Wavelength and Heisenberg Uncertainty",
                                        "description": "Fundamental quantum mechanical principles.",
                                        "material_title": "Quantum Principles",
                                        "material_content": "De Broglie proposed that matter has wave properties: lambda = h/(mv), where h is Planck's constant. The Heisenberg uncertainty principle states that position and momentum cannot both be known precisely: delta-x * delta-momentum >= h/(4*pi). The Schrodinger equation describes electron behavior as wave functions (orbitals). |psi|^2 gives the probability density of finding an electron at a given location. Quantized energy levels arise from boundary conditions.",
                                        "practices": [
                                            {
                                                "question": "What does the Heisenberg uncertainty principle state?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Electrons have fixed orbits","B) Position and momentum cannot both be precisely determined","C) Energy is always conserved","D) All measurements are exact"]}',
                                                "answer": "B",
                                                "explanation": "The uncertainty principle: the more precisely position is known, the less precisely momentum can be known.",
                                            },
                                            {
                                                "question": "What is the de Broglie wavelength of an electron moving at 10^6 m/s?",
                                                "type": "short_answer",
                                                "answer": "7.27 x 10^-10 m (about 0.73 nm)",
                                                "explanation": "lambda = h/(mv) = 6.626e-34 / (9.109e-31 * 1e6) = 7.27e-10 m.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Molecular Orbital Theory",
                                "concepts": [
                                    {
                                        "title": "Bonding and Antibonding Orbitals",
                                        "description": "How atomic orbitals combine to form molecular orbitals.",
                                        "material_title": "Molecular Orbital Theory",
                                        "material_content": "When atomic orbitals combine, they form bonding (lower energy) and antibonding (higher energy) molecular orbitals. Constructive interference creates bonding orbitals with electron density between nuclei. Destructive interference creates antibonding orbitals with a node between nuclei. Bond order = (bonding electrons - antibonding electrons)/2. O2 has two unpaired electrons in antibonding pi* orbitals, explaining its paramagnetism, which valence bond theory cannot.",
                                        "practices": [
                                            {
                                                "question": "What is the bond order of O2 according to MO theory?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 1","B) 1.5","C) 2","D) 3"]}',
                                                "answer": "C",
                                                "explanation": "O2 has 10 bonding and 6 antibonding electrons: bond order = (10-6)/2 = 2.",
                                            },
                                            {
                                                "question": "Why is O2 paramagnetic according to MO theory?",
                                                "type": "short_answer",
                                                "answer": "It has two unpaired electrons in the pi* antibonding molecular orbitals.",
                                                "explanation": "MO theory correctly predicts that O2 has two unpaired electrons, making it paramagnetic.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Medicinal Chemistry",
                "slug": "medicinal-chemistry",
                "description": "The design and development of pharmaceutical agents.",
                "topics": [
                    {
                        "title": "Drug Design",
                        "difficulty": "advanced",
                        "description": "Principles of creating effective medications.",
                        "subtopics": [
                            {
                                "title": "Drug-Receptor Interactions",
                                "concepts": [
                                    {
                                        "title": "Pharmacophore and Drug Binding",
                                        "description": "How drugs interact with biological targets.",
                                        "material_title": "Drug-Target Interactions",
                                        "material_content": "Drugs exert their effects by binding to biological targets (receptors, enzymes, ion channels). The pharmacophore is the minimum structural features required for biological activity. Drug binding involves non-covalent interactions: hydrogen bonds, ionic interactions, van der Waals forces, and hydrophobic interactions. The lock-and-key model describes specificity. Structure-activity relationships (SAR) guide optimization of drug potency, selectivity, and pharmacokinetics (ADME: absorption, distribution, metabolism, excretion).",
                                        "practices": [
                                            {
                                                "question": "What is a pharmacophore?",
                                                "type": "mcq",
                                                "options": '{"options":["A) A type of bacteria","B) The minimum structural features needed for biological activity","C) A receptor on cells","D) A type of drug side effect"]}',
                                                "answer": "B",
                                                "explanation": "The pharmacophore represents the essential molecular features responsible for a drug's biological activity.",
                                            },
                                            {
                                                "question": "What does ADME stand for in pharmacokinetics?",
                                                "type": "short_answer",
                                                "answer": "Absorption, Distribution, Metabolism, Excretion",
                                                "explanation": "ADME describes the four key processes a drug undergoes in the body.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Drug Metabolism",
                                "concepts": [
                                    {
                                        "title": "Phase I and Phase II Metabolism",
                                        "description": "How the body processes and eliminates drugs.",
                                        "material_title": "Drug Metabolism",
                                        "material_content": "Phase I metabolism introduces or exposes functional groups through oxidation, reduction, or hydrolysis, primarily catalyzed by cytochrome P450 enzymes in the liver. Phase II metabolism conjugates the drug or its metabolites with polar groups (glucuronic acid, sulfate, glutathione) to increase water solubility for renal excretion. Prodrugs are inactive compounds that are metabolized to active forms. First-pass metabolism can significantly reduce oral bioavailability.",
                                        "practices": [
                                            {
                                                "question": "Which enzyme family is primarily responsible for Phase I drug metabolism?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Transferases","B) Cytochrome P450","C) Lipases","D) Amylases"]}',
                                                "answer": "B",
                                                "explanation": "CYP450 enzymes (especially CYP3A4) catalyze most Phase I oxidative metabolism in the liver.",
                                            },
                                            {
                                                "question": "What is first-pass metabolism?",
                                                "type": "short_answer",
                                                "answer": "Drug metabolism that occurs in the gut wall and liver before the drug reaches systemic circulation.",
                                                "explanation": "Oral drugs are absorbed into the portal vein and pass through the liver, where some may be metabolized.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
        ],
    },
    # ── 4. Physics ──────────────────────────────────────────────────
    {
        "title": "Physics",
        "slug": "physics",
        "icon": "bolt",
        "color": "#3B82F6",
        "description": "The study of matter, energy, and the fundamental forces of nature.",
        "disciplines": [
            {
                "title": "Classical Mechanics",
                "slug": "classical-mechanics",
                "description": "The motion of macroscopic objects under forces.",
                "topics": [
                    {
                        "title": "Kinematics",
                        "difficulty": "foundational",
                        "description": "Describing motion without considering forces.",
                        "subtopics": [
                            {
                                "title": "Linear Motion",
                                "concepts": [
                                    {
                                        "title": "Displacement, Velocity, and Acceleration",
                                        "description": "The fundamental quantities describing motion.",
                                        "material_title": "Kinematic Quantities",
                                        "material_content": "Displacement is the change in position (vector quantity). Velocity is the rate of change of displacement (v = dx/dt). Acceleration is the rate of change of velocity (a = dv/dt). For constant acceleration: v = v0 + at, x = x0 + v0t + (1/2)at^2, and v^2 = v0^2 + 2a(x-x0). These equations relate displacement, velocity, acceleration, and time for uniformly accelerated motion.",
                                        "practices": [
                                            {
                                                "question": "A car accelerates from rest at 3 m/s^2. What is its velocity after 5 seconds?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 8 m/s","B) 10 m/s","C) 15 m/s","D) 25 m/s"]}',
                                                "answer": "C",
                                                "explanation": "v = v0 + at = 0 + 3(5) = 15 m/s.",
                                            },
                                            {
                                                "question": "Write the kinematic equation for displacement under constant acceleration.",
                                                "type": "short_answer",
                                                "answer": "x = x0 + v0*t + (1/2)*a*t^2",
                                                "explanation": "This equation relates position to initial position, initial velocity, acceleration, and time.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Projectile Motion",
                                "concepts": [
                                    {
                                        "title": "Two-Dimensional Motion Under Gravity",
                                        "description": "Analyzing the trajectory of launched objects.",
                                        "material_title": "Projectile Motion",
                                        "material_content": "Projectile motion separates into independent horizontal and vertical components. Horizontal motion: constant velocity (no air resistance), x = v0*cos(theta)*t. Vertical motion: constant acceleration g (downward), y = v0*sin(theta)*t - (1/2)gt^2. At maximum height, vertical velocity = 0. The range is R = (v0^2*sin(2*theta))/g. Maximum range occurs at 45 degrees. Time of flight T = 2*v0*sin(theta)/g.",
                                        "practices": [
                                            {
                                                "question": "At what angle does a projectile achieve maximum range (no air resistance)?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 30","B) 45","C) 60","D) 90"]}',
                                                "answer": "B",
                                                "explanation": "Range is maximum when sin(2*theta) = 1, which occurs at theta = 45 degrees.",
                                            },
                                            {
                                                "question": "A ball is thrown upward at 20 m/s. What is the maximum height? (g = 10 m/s^2)",
                                                "type": "short_answer",
                                                "answer": "20 m",
                                                "explanation": "Using v^2 = v0^2 - 2gh at max height (v=0): 0 = 400 - 20h, h = 20 m.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Newton's Laws",
                        "difficulty": "foundational",
                        "description": "The fundamental laws governing force and motion.",
                        "subtopics": [
                            {
                                "title": "Newton's Three Laws",
                                "concepts": [
                                    {
                                        "title": "Forces and Motion",
                                        "description": "The relationship between force, mass, and acceleration.",
                                        "material_title": "Newton's Laws of Motion",
                                        "material_content": "First Law (Inertia): An object at rest stays at rest, or in motion stays in motion at constant velocity, unless acted on by a net external force. Second Law: F = ma (net force equals mass times acceleration). Third Law: For every action, there is an equal and opposite reaction. These three laws form the foundation of classical mechanics and allow prediction of object motion when forces are known.",
                                        "practices": [
                                            {
                                                "question": "A 5 kg object experiences a net force of 20 N. What is its acceleration?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 2 m/s^2","B) 4 m/s^2","C) 25 m/s^2","D) 100 m/s^2"]}',
                                                "answer": "B",
                                                "explanation": "F = ma, so a = F/m = 20/5 = 4 m/s^2.",
                                            },
                                            {
                                                "question": "Explain Newton's Third Law with an example.",
                                                "type": "short_answer",
                                                "answer": "When you push against a wall, the wall pushes back with equal force in the opposite direction.",
                                                "explanation": "Action-reaction pairs always act on different objects and are equal in magnitude, opposite in direction.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Friction",
                                "concepts": [
                                    {
                                        "title": "Static and Kinetic Friction",
                                        "description": "Resistive forces between surfaces in contact.",
                                        "material_title": "Friction Forces",
                                        "material_content": "Friction opposes relative motion between surfaces. Static friction (fs <= mu_s * N) prevents motion and adjusts to match applied force up to a maximum. Kinetic friction (fk = mu_k * N) acts during motion and is constant. mu_s > mu_k typically. Friction is independent of contact area and proportional to the normal force. While friction enables walking and driving, it also causes energy loss as heat.",
                                        "practices": [
                                            {
                                                "question": "What is the maximum static friction force if mu_s = 0.4 and N = 50 N?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 5 N","B) 12.5 N","C) 20 N","D) 200 N"]}',
                                                "answer": "C",
                                                "explanation": "fs,max = mu_s * N = 0.4 * 50 = 20 N.",
                                            },
                                            {
                                                "question": "Is static or kinetic friction typically greater?",
                                                "type": "short_answer",
                                                "answer": "Static friction is typically greater than kinetic friction.",
                                                "explanation": "It takes more force to start motion (overcome static friction) than to maintain it (kinetic friction).",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Thermodynamics",
                "slug": "thermodynamics",
                "description": "Heat, work, and energy transfer.",
                "topics": [
                    {
                        "title": "Laws of Thermodynamics",
                        "difficulty": "intermediate",
                        "description": "The fundamental principles governing energy.",
                        "subtopics": [
                            {
                                "title": "Energy Conservation",
                                "concepts": [
                                    {
                                        "title": "First Law of Thermodynamics",
                                        "description": "Energy cannot be created or destroyed.",
                                        "material_title": "Conservation of Energy",
                                        "material_content": "The First Law states that energy is conserved: delta-U = Q - W, where delta-U is the change in internal energy, Q is heat added to the system, and W is work done by the system. For an isothermal process (constant T), delta-U = 0, so Q = W. For an adiabatic process (Q = 0), delta-U = -W. For an isochoric process (constant V), W = 0, so delta-U = Q.",
                                        "practices": [
                                            {
                                                "question": "In an isothermal expansion of an ideal gas, what is true?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Q = 0","B) W = 0","C) Q = W","D) delta-U > 0"]}',
                                                "answer": "C",
                                                "explanation": "For isothermal process, delta-U = 0 (ideal gas internal energy depends only on T), so Q = W.",
                                            },
                                            {
                                                "question": "State the First Law of Thermodynamics mathematically.",
                                                "type": "short_answer",
                                                "answer": "delta-U = Q - W",
                                                "explanation": "The change in internal energy equals heat added minus work done by the system.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Entropy and the Second Law",
                                "concepts": [
                                    {
                                        "title": "Second Law and Entropy",
                                        "description": "The irreversible direction of natural processes.",
                                        "material_title": "The Second Law of Thermodynamics",
                                        "material_content": "The Second Law states that the total entropy of an isolated system never decreases: delta-S >= 0. Heat flows spontaneously from hot to cold (never the reverse). No heat engine can be 100% efficient. Carnot efficiency sets the maximum: eta = 1 - Tcold/Thot. The Second Law explains why certain processes are irreversible and defines the arrow of time. Entropy is a measure of the number of microstates: S = k*ln(W).",
                                        "practices": [
                                            {
                                                "question": "What is the maximum efficiency of a heat engine operating between 500K and 300K?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 20%","B) 40%","C) 60%","D) 100%"]}',
                                                "answer": "B",
                                                "explanation": "eta = 1 - Tcold/Thot = 1 - 300/500 = 0.4 = 40%.",
                                            },
                                            {
                                                "question": "Can a refrigerator transfer heat from cold to hot without external work?",
                                                "type": "short_answer",
                                                "answer": "No, work input is required (Second Law of Thermodynamics).",
                                                "explanation": "Heat flows spontaneously only from hot to cold; reversing this requires energy input.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Electromagnetism",
                "slug": "electromagnetism",
                "description": "Electric and magnetic phenomena and their unification.",
                "topics": [
                    {
                        "title": "Electric Fields and Forces",
                        "difficulty": "intermediate",
                        "description": "The forces between charged particles.",
                        "subtopics": [
                            {
                                "title": "Coulomb's Law",
                                "concepts": [
                                    {
                                        "title": "Electrostatic Force",
                                        "description": "The force between point charges.",
                                        "material_title": "Coulomb's Law",
                                        "material_content": "Coulomb's Law states that the force between two point charges is F = k*|q1*q2|/r^2, where k = 8.99e9 N*m^2/C^2 is Coulomb's constant, q1 and q2 are the charges, and r is the distance between them. Like charges repel; opposite charges attract. The force acts along the line joining the charges. The electric field E = F/q = k*Q/r^2 gives the force per unit charge at a distance r from charge Q.",
                                        "practices": [
                                            {
                                                "question": "Two charges of +1C and -1C are 1m apart. What is the force?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 4.5 x 10^9 N","B) 9 x 10^9 N","C) 1 N","D) 8.99 N"]}',
                                                "answer": "B",
                                                "explanation": "F = k*|q1*q2|/r^2 = 8.99e9 * 1 * 1 / 1^2 = 8.99e9 N, approximately 9 x 10^9 N.",
                                            },
                                            {
                                                "question": "How does the electrostatic force change if the distance between charges is doubled?",
                                                "type": "short_answer",
                                                "answer": "It decreases to one-fourth (inverse square law).",
                                                "explanation": "F is proportional to 1/r^2, so doubling r gives F/4.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Electric Potential",
                                "concepts": [
                                    {
                                        "title": "Voltage and Electric Potential Energy",
                                        "description": "Energy associated with charge positions.",
                                        "material_title": "Electric Potential",
                                        "material_content": "Electric potential V = k*Q/r gives the potential energy per unit charge at a distance r from charge Q. Voltage is the potential difference between two points: V = W/q (work per unit charge). The potential of a point charge decreases with distance (1/r). Equipotential surfaces are perpendicular to electric field lines. Moving a positive charge to higher potential increases its potential energy.",
                                        "practices": [
                                            {
                                                "question": "What is the electric potential at 2m from a +4C charge?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 1.8 x 10^10 V","B) 8.99 x 10^9 V","C) 4.5 x 10^9 V","D) 2.25 x 10^9 V"]}',
                                                "answer": "A",
                                                "explanation": "V = k*Q/r = 8.99e9 * 4 / 2 = 1.798e10 V approx 1.8 x 10^10 V.",
                                            },
                                            {
                                                "question": "What is the relationship between electric field and electric potential?",
                                                "type": "short_answer",
                                                "answer": "E = -dV/dx (the electric field is the negative gradient of the potential).",
                                                "explanation": "The electric field points in the direction of decreasing potential.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Magnetism",
                        "difficulty": "intermediate",
                        "description": "Magnetic fields and their effects.",
                        "subtopics": [
                            {
                                "title": "Magnetic Forces",
                                "concepts": [
                                    {
                                        "title": "Force on Moving Charges in Magnetic Fields",
                                        "description": "The Lorentz force and its applications.",
                                        "material_title": "Magnetic Force on Charges",
                                        "material_content": "A charged particle moving in a magnetic field experiences a force: F = qv x B, where v is velocity and B is the magnetic field. The force is perpendicular to both v and B, causing circular motion. The radius of the circular path is r = mv/(qB). The magnetic force on a current-carrying wire is F = IL x B, where I is current and L is length. This force is the basis for electric motors.",
                                        "practices": [
                                            {
                                                "question": "In what direction is the magnetic force on a positive charge moving north in a field pointing east?",
                                                "type": "mcq",
                                                "options": '{"options":["A) North","B) South","C) Upward","D) Downward"]}',
                                                "answer": "C",
                                                "explanation": "By the right-hand rule: v (north) x B (east) = upward force.",
                                            },
                                            {
                                                "question": "What is the radius of the circular path of a proton moving at 10^6 m/s in a 0.1T field?",
                                                "type": "short_answer",
                                                "answer": "Approximately 0.104 m",
                                                "explanation": "r = mv/(qB) = (1.67e-27 * 1e6) / (1.6e-19 * 0.1) = 0.104 m.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Electromagnetic Induction",
                                "concepts": [
                                    {
                                        "title": "Faraday's Law",
                                        "description": "Generating electricity from changing magnetic fields.",
                                        "material_title": "Electromagnetic Induction",
                                        "material_content": "Faraday's Law states that a changing magnetic flux through a loop induces an electromotive force (EMF): EMF = -dPhi/dt, where Phi = B*A*cos(theta) is the magnetic flux. Lenz's Law states the induced current opposes the change causing it. Applications include electric generators (mechanical to electrical energy), transformers (changing voltage levels), and induction cooktops.",
                                        "practices": [
                                            {
                                                "question": "According to Lenz's Law, the induced current always:",
                                                "type": "mcq",
                                                "options": '{"options":["A) Increases the magnetic flux","B) Decreases the magnetic flux","C) Opposes the change in flux","D) Is in the same direction as the field change"]}',
                                                "answer": "C",
                                                "explanation": "Lenz's Law: the induced current creates a magnetic field that opposes the change in flux.",
                                            },
                                            {
                                                "question": "How does a generator convert mechanical energy to electrical energy?",
                                                "type": "short_answer",
                                                "answer": "By rotating a coil in a magnetic field, creating a changing flux that induces EMF.",
                                                "explanation": "The rotation changes the magnetic flux through the coil, inducing current via Faraday's Law.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Optics",
                "slug": "optics",
                "description": "The behavior and properties of light.",
                "topics": [
                    {
                        "title": "Geometric Optics",
                        "difficulty": "intermediate",
                        "description": "Light propagation as rays.",
                        "subtopics": [
                            {
                                "title": "Reflection and Refraction",
                                "concepts": [
                                    {
                                        "title": "Snell's Law and Critical Angle",
                                        "description": "How light bends at interfaces between media.",
                                        "material_title": "Refraction of Light",
                                        "material_content": "Snell's Law: n1*sin(theta1) = n2*sin(theta2), where n is the refractive index. Light bends toward the normal when entering a denser medium (higher n). Total internal reflection occurs when light in a denser medium hits the boundary at an angle greater than the critical angle: theta_c = arcsin(n2/n1). This principle guides fiber optics. The refractive index n = c/v where c is the speed of light in vacuum and v in the medium.",
                                        "practices": [
                                            {
                                                "question": "Light travels from air (n=1) to glass (n=1.5). What is the angle of refraction for a 30-degree incidence?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 19.5","B) 22.5","C) 30","D) 45"]}',
                                                "answer": "A",
                                                "explanation": "sin(theta2) = n1*sin(theta1)/n2 = 1*sin(30)/1.5 = 0.333, theta2 = arcsin(0.333) = 19.5 degrees.",
                                            },
                                            {
                                                "question": "What is the critical angle for total internal reflection from glass (n=1.5) to air (n=1)?",
                                                "type": "short_answer",
                                                "answer": "41.8 degrees",
                                                "explanation": "theta_c = arcsin(n2/n1) = arcsin(1/1.5) = arcsin(0.667) = 41.8 degrees.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Lenses and Mirrors",
                                "concepts": [
                                    {
                                        "title": "Image Formation",
                                        "description": "How lenses and mirrors create images.",
                                        "material_title": "Optical Image Formation",
                                        "material_content": "The thin lens equation: 1/f = 1/do + 1/di, where f is focal length, do is object distance, and di is image distance. Converging (convex) lenses focus parallel light to a focal point (positive f). Diverging (concave) lenses spread light (negative f). Magnification M = -di/do. For mirrors, the same equation applies: 1/f = 1/do + 1/di. Concave mirrors converge light; convex mirrors diverge it.",
                                        "practices": [
                                            {
                                                "question": "A converging lens has f = 10cm. An object is placed 20cm away. Where is the image?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 10cm","B) 15cm","C) 20cm","D) 30cm"]}',
                                                "answer": "C",
                                                "explanation": "1/di = 1/f - 1/do = 1/10 - 1/20 = 1/20, di = 20 cm.",
                                            },
                                            {
                                                "question": "What type of image does a converging lens produce when the object is between f and 2f?",
                                                "type": "short_answer",
                                                "answer": "A real, inverted, magnified image beyond 2f.",
                                                "explanation": "When f < do < 2f, the image is real, inverted, enlarged, and located beyond 2f.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Waves and Sound",
                "slug": "waves-sound",
                "description": "Mechanical and acoustic wave phenomena.",
                "topics": [
                    {
                        "title": "Wave Properties",
                        "difficulty": "foundational",
                        "description": "Fundamental characteristics of waves.",
                        "subtopics": [
                            {
                                "title": "Wave Behavior",
                                "concepts": [
                                    {
                                        "title": "Frequency, Wavelength, and Speed",
                                        "description": "The relationships between wave parameters.",
                                        "material_title": "Wave Parameters",
                                        "material_content": "The wave equation relates speed, frequency, and wavelength: v = f*lambda. Frequency (f) is the number of oscillations per second (Hz). Wavelength (lambda) is the distance between successive crests. Amplitude is the maximum displacement from equilibrium. The period T = 1/f is the time for one complete oscillation. Transverse waves oscillate perpendicular to propagation; longitudinal waves oscillate parallel (sound waves).",
                                        "practices": [
                                            {
                                                "question": "A wave has a frequency of 500 Hz and wavelength of 0.68 m. What is its speed?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 340 m/s","B) 500 m/s","C) 680 m/s","D) 0.00136 m/s"]}',
                                                "answer": "A",
                                                "explanation": "v = f*lambda = 500 * 0.68 = 340 m/s (speed of sound in air).",
                                            },
                                            {
                                                "question": "What type of wave is sound?",
                                                "type": "short_answer",
                                                "answer": "A longitudinal (compression) wave.",
                                                "explanation": "Sound waves propagate as compressions and rarefactions parallel to the direction of travel.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Sound Properties",
                                "concepts": [
                                    {
                                        "title": "Pitch, Loudness, and Resonance",
                                        "description": "Perceptual qualities of sound waves.",
                                        "material_title": "Sound Perception",
                                        "material_content": "Pitch corresponds to frequency: higher frequency = higher pitch. Human hearing ranges from 20 Hz to 20,000 Hz. Loudness corresponds to amplitude and is measured in decibels (dB): beta = 10*log(I/I0), where I0 = 10^-12 W/m^2. Resonance occurs when a driving frequency matches a natural frequency, producing large-amplitude vibrations. The Doppler effect causes frequency shifts when source and observer move relative to each other.",
                                        "practices": [
                                            {
                                                "question": "What is the intensity level of a sound with I = 10^-6 W/m^2?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 30 dB","B) 60 dB","C) 90 dB","D) 120 dB"]}',
                                                "answer": "B",
                                                "explanation": "beta = 10*log(10^-6 / 10^-12) = 10*log(10^6) = 60 dB.",
                                            },
                                            {
                                                "question": "Explain the Doppler effect.",
                                                "type": "short_answer",
                                                "answer": "The observed frequency changes when the source or observer is moving relative to each other.",
                                                "explanation": "Approaching: frequency increases. Receding: frequency decreases. The ambulance siren is a common example.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Modern Physics",
                "slug": "modern-physics",
                "description": "Physics developed in the 20th century and beyond.",
                "topics": [
                    {
                        "title": "Special Relativity",
                        "difficulty": "advanced",
                        "description": "Einstein's theory of space and time.",
                        "subtopics": [
                            {
                                "title": "Postulates of Special Relativity",
                                "concepts": [
                                    {
                                        "title": "Time Dilation and Length Contraction",
                                        "description": "Consequences of the constancy of the speed of light.",
                                        "material_title": "Relativistic Effects",
                                        "material_content": "Einstein's two postulates: (1) the laws of physics are the same in all inertial frames, (2) the speed of light is constant regardless of the observer's motion. Time dilation: moving clocks run slow (t = t0/sqrt(1-v^2/c^2)). Length contraction: moving objects are shorter in the direction of motion (L = L0*sqrt(1-v^2/c^2)). These effects are significant only at speeds close to the speed of light.",
                                        "practices": [
                                            {
                                                "question": "A spaceship travels at 0.8c. What is the Lorentz factor gamma?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 1.25","B) 1.67","C) 2","D) 5"]}',
                                                "answer": "B",
                                                "explanation": "gamma = 1/sqrt(1-v^2/c^2) = 1/sqrt(1-0.64) = 1/sqrt(0.36) = 1/0.6 = 1.67.",
                                            },
                                            {
                                                "question": "What happens to time for a clock moving at near light speed?",
                                                "type": "short_answer",
                                                "answer": "Time passes more slowly for the moving clock (time dilation).",
                                                "explanation": "t = gamma * t0, where gamma > 1, so the moving clock's time interval appears longer.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Mass-Energy Equivalence",
                                "concepts": [
                                    {
                                        "title": "Einstein's Most Famous Equation",
                                        "description": "The equivalence of mass and energy.",
                                        "material_title": "E = mc^2",
                                        "material_content": "Einstein's mass-energy equivalence E = mc^2 states that mass is a form of energy. The total energy of a moving object is E = gamma*mc^2. The rest energy is E0 = mc^2. The energy equivalent of 1 kg of mass is approximately 9 x 10^16 joules (equivalent to about 21 megatons of TNT). This equation explains energy release in nuclear reactions, where small mass losses correspond to enormous energy outputs.",
                                        "practices": [
                                            {
                                                "question": "What is the energy equivalent of 0.001 kg of mass?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 9 x 10^13 J","B) 9 x 10^16 J","C) 3 x 10^8 J","D) 9 x 10^10 J"]}',
                                                "answer": "A",
                                                "explanation": "E = mc^2 = 0.001 * (3e8)^2 = 0.001 * 9e16 = 9e13 J.",
                                            },
                                            {
                                                "question": "How does E = mc^2 explain energy release in nuclear fission?",
                                                "type": "short_answer",
                                                "answer": "The mass of the products is slightly less than the mass of the reactants; the mass difference is converted to energy.",
                                                "explanation": "The mass defect multiplied by c^2 gives the energy released.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Quantum Mechanics",
                        "difficulty": "advanced",
                        "description": "Physics at the atomic and subatomic scale.",
                        "subtopics": [
                            {
                                "title": "Quantum Phenomena",
                                "concepts": [
                                    {
                                        "title": "The Photoelectric Effect",
                                        "description": "Light-induced electron emission from metals.",
                                        "material_title": "Photoelectric Effect",
                                        "material_content": "When light above a threshold frequency shines on a metal, electrons are emitted. The kinetic energy of emitted electrons depends on frequency (not intensity): KE = hf - Phi, where h is Planck's constant (6.626e-34 J*s), f is frequency, and Phi is the work function. Below the threshold frequency, no electrons are emitted regardless of intensity. This particle-like behavior of light (photons) was key evidence for quantum theory.",
                                        "practices": [
                                            {
                                                "question": "In the photoelectric effect, what determines the kinetic energy of emitted electrons?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Light intensity","B) Light frequency","C) Exposure time","D) Metal color"]}',
                                                "answer": "B",
                                                "explanation": "KE = hf - Phi; only the frequency (not intensity) determines the maximum kinetic energy.",
                                            },
                                            {
                                                "question": "What is the threshold frequency for a metal with work function 3.0 eV?",
                                                "type": "short_answer",
                                                "answer": "7.26 x 10^14 Hz",
                                                "explanation": "f = Phi/h = 3.0 * 1.6e-19 / 6.626e-34 = 7.24e14 Hz approx 7.26 x 10^14 Hz.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Wave-Particle Duality",
                                "concepts": [
                                    {
                                        "title": "The Dual Nature of Matter and Light",
                                        "description": "Objects exhibit both wave and particle properties.",
                                        "material_title": "Wave-Particle Duality",
                                        "material_content": "Light exhibits wave properties (interference, diffraction) and particle properties (photoelectric effect, Compton scattering). Matter also has wave properties: de Broglie proposed lambda = h/(mv). Electron diffraction experiments confirmed matter waves. The double-slit experiment with single electrons shows interference patterns, demonstrating that each electron behaves as a wave passing through both slits simultaneously. The complementarity principle states that wave and particle descriptions are complementary.",
                                        "practices": [
                                            {
                                                "question": "What experimental evidence supports the wave nature of light?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Photoelectric effect","B) Blackbody radiation","C) Young\'s double-slit interference","D) Compton scattering"]}',
                                                "answer": "C",
                                                "explanation": "The double-slit experiment shows interference fringes, a characteristic wave phenomenon.",
                                            },
                                            {
                                                "question": "State the de Broglie relation.",
                                                "type": "short_answer",
                                                "answer": "lambda = h/(mv), where lambda is wavelength, h is Planck's constant, m is mass, and v is velocity.",
                                                "explanation": "Every particle of matter has an associated wavelength inversely proportional to its momentum.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Nuclear Physics",
                "slug": "nuclear-physics",
                "description": "The study of atomic nuclei and their reactions.",
                "topics": [
                    {
                        "title": "Nuclear Structure",
                        "difficulty": "advanced",
                        "description": "The composition and stability of nuclei.",
                        "subtopics": [
                            {
                                "title": "Nuclear Binding Energy",
                                "concepts": [
                                    {
                                        "title": "Mass Defect and Binding Energy",
                                        "description": "The energy holding nuclei together.",
                                        "material_title": "Nuclear Binding Energy",
                                        "material_content": "The mass of a nucleus is less than the sum of its individual nucleons. This mass defect (delta-m) corresponds to the binding energy via E = delta-m*c^2. Binding energy per nucleon (BE/A) measures nuclear stability: iron-56 has the highest BE/A (8.8 MeV/nucleon), making it the most stable nucleus. Fission of heavy nuclei and fusion of light nuclei both move toward iron, releasing energy. The semi-empirical mass formula (liquid drop model) predicts BE from nuclear properties.",
                                        "practices": [
                                            {
                                                "question": "Which nucleus has the highest binding energy per nucleon?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Hydrogen-1","B) Carbon-12","C) Iron-56","D) Uranium-235"]}',
                                                "answer": "C",
                                                "explanation": "Iron-56 has the highest binding energy per nucleon (~8.8 MeV), making it the most stable nucleus.",
                                            },
                                            {
                                                "question": "Why does nuclear fission release energy?",
                                                "type": "short_answer",
                                                "answer": "The fission products have higher binding energy per nucleon than the original nucleus.",
                                                "explanation": "Heavy nuclei have lower BE/A than medium-mass nuclei, so splitting them releases the difference as energy.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Radioactive Decay",
                                "concepts": [
                                    {
                                        "title": "Decay Laws and Half-Life",
                                        "description": "Mathematical description of radioactive decay.",
                                        "material_title": "Radioactive Decay Mathematics",
                                        "material_content": "Radioactive decay follows first-order kinetics: N = N0*e^(-lambda*t), where N0 is the initial number of atoms, lambda is the decay constant, and t is time. Half-life t1/2 = ln(2)/lambda. Activity A = lambda*N = A0*e^(-lambda*t). For a mixture of isotopes, total activity is the sum of individual activities. Carbon-14 dating uses t1/2 = 5730 years to date organic materials up to ~50,000 years old.",
                                        "practices": [
                                            {
                                                "question": "A sample has an initial activity of 100 Bq and a half-life of 10 days. What is the activity after 30 days?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 50 Bq","B) 25 Bq","C) 12.5 Bq","D) 6.25 Bq"]}',
                                                "answer": "C",
                                                "explanation": "After 3 half-lives (30 days / 10 days): 100 -> 50 -> 25 -> 12.5 Bq.",
                                            },
                                            {
                                                "question": "How is carbon-14 dating used to determine the age of fossils?",
                                                "type": "short_answer",
                                                "answer": "Measure the remaining C-14 activity and use the half-life equation to calculate time since death.",
                                                "explanation": "Living organisms maintain constant C-14 levels; after death, C-14 decays and is not replaced.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Astrophysics",
                "slug": "astrophysics",
                "description": "Physics applied to astronomical objects and phenomena.",
                "topics": [
                    {
                        "title": "Stars and Stellar Evolution",
                        "difficulty": "advanced",
                        "description": "The life cycles of stars.",
                        "subtopics": [
                            {
                                "title": "Stellar Classification",
                                "concepts": [
                                    {
                                        "title": "The Hertzsprung-Russell Diagram",
                                        "description": "Classifying stars by luminosity and temperature.",
                                        "material_title": "HR Diagram",
                                        "material_content": "The Hertzsprung-Russell diagram plots stellar luminosity versus surface temperature (or spectral class). The main sequence is a diagonal band where stars spend most of their lives fusing hydrogen. Hot, luminous stars are in the upper left; cool, dim stars in the lower right. Red giants (cool, luminous) and white dwarfs (hot, dim) occupy off-main-sequence positions. The Sun is a G-type main sequence star with surface temperature ~5778K.",
                                        "practices": [
                                            {
                                                "question": "Where do red giants fall on the HR diagram?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Upper left","B) Lower left","C) Upper right","D) Lower right"]}',
                                                "answer": "C",
                                                "explanation": "Red giants are cool (right) but luminous (upper) due to their large surface area.",
                                            },
                                            {
                                                "question": "What process powers main sequence stars?",
                                                "type": "short_answer",
                                                "answer": "Hydrogen fusion (nuclear fusion of hydrogen into helium) in the core.",
                                                "explanation": "Main sequence stars are in hydrostatic equilibrium: gravitational contraction balanced by fusion energy output.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Stellar Lifecycles",
                                "concepts": [
                                    {
                                        "title": "From Nebula to Remnant",
                                        "description": "The complete life cycle of stars.",
                                        "material_title": "Stellar Evolution",
                                        "material_content": "Stars form from gravitational collapse of molecular clouds (nebulae). On the main sequence, they fuse hydrogen. After hydrogen exhaustion, low-mass stars (<8 solar masses) become red giants, shed outer layers as planetary nebulae, and leave white dwarfs. High-mass stars become red supergiants, explode as supernovae, and leave neutron stars or black holes. Supernovae disperse heavy elements, enabling new star and planet formation.",
                                        "practices": [
                                            {
                                                "question": "What is the remnant of a low-mass star after it sheds its outer layers?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Neutron star","B) Black hole","C) White dwarf","D) Pulsar"]}',
                                                "answer": "C",
                                                "explanation": "Low-mass stars leave behind a white dwarf, supported by electron degeneracy pressure.",
                                            },
                                            {
                                                "question": "What heavy elements are forged in supernovae?",
                                                "type": "short_answer",
                                                "answer": "Elements heavier than iron, including gold, silver, and uranium.",
                                                "explanation": "Supernova nucleosynthesis creates elements heavier than iron through rapid neutron capture (r-process).",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Fluid Mechanics",
                "slug": "fluid-mechanics",
                "description": "The behavior of fluids at rest and in motion.",
                "topics": [
                    {
                        "title": "Fluid Statics",
                        "difficulty": "intermediate",
                        "description": "Fluids at rest.",
                        "subtopics": [
                            {
                                "title": "Pressure in Fluids",
                                "concepts": [
                                    {
                                        "title": "Hydrostatic Pressure and Pascal's Law",
                                        "description": "How pressure varies with depth in a fluid.",
                                        "material_title": "Hydrostatic Pressure",
                                        "material_content": "Pressure in a fluid increases with depth: P = P0 + rho*g*h, where rho is fluid density, g is gravitational acceleration, and h is depth. Pascal's Law states that pressure applied to an enclosed fluid is transmitted undiminished throughout the fluid (basis for hydraulic systems). Archimedes' principle: the buoyant force equals the weight of displaced fluid (F_b = rho_fluid * V_displaced * g).",
                                        "practices": [
                                            {
                                                "question": "What is the pressure at 10m depth in water (rho = 1000 kg/m^3)?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 1.0 x 10^5 Pa","B) 2.0 x 10^5 Pa","C) 1.0 x 10^6 Pa","D) 9.8 x 10^4 Pa"]}',
                                                "answer": "B",
                                                "explanation": "P = P0 + rho*g*h = 1e5 + 1000*10*10 = 2e5 Pa.",
                                            },
                                            {
                                                "question": "State Archimedes' principle.",
                                                "type": "short_answer",
                                                "answer": "An object immersed in a fluid experiences a buoyant force equal to the weight of the displaced fluid.",
                                                "explanation": "F_b = rho_fluid * V_displaced * g, acting upward through the center of buoyancy.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Fluid Dynamics",
                                "concepts": [
                                    {
                                        "title": "Bernoulli's Equation",
                                        "description": "Conservation of energy for flowing fluids.",
                                        "material_title": "Bernoulli's Principle",
                                        "material_content": "Bernoulli's equation: P + (1/2)*rho*v^2 + rho*g*h = constant along a streamline. It expresses conservation of energy for ideal (incompressible, non-viscous) fluid flow. When velocity increases, pressure decreases (and vice versa). Applications include airplane lift (airfoil design), Venturi meters, and atomizers. The continuity equation (A1*v1 = A2*v2) ensures mass conservation in incompressible flow.",
                                        "practices": [
                                            {
                                                "question": "According to Bernoulli's equation, what happens to pressure when fluid velocity increases?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Increases","B) Decreases","C) Stays the same","D) Oscillates"]}',
                                                "answer": "B",
                                                "explanation": "Bernoulli's equation shows that as kinetic energy (1/2*rho*v^2) increases, pressure energy (P) must decrease.",
                                            },
                                            {
                                                "question": "How does an airplane generate lift?",
                                                "type": "short_answer",
                                                "answer": "Air moves faster over the curved upper surface of the wing, creating lower pressure above (Bernoulli's principle).",
                                                "explanation": "The pressure difference between the upper and lower wing surfaces creates an upward lift force.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Relativity",
                "slug": "relativity",
                "description": "Einstein's theories of special and general relativity.",
                "topics": [
                    {
                        "title": "General Relativity",
                        "difficulty": "advanced",
                        "description": "Gravity as the curvature of spacetime.",
                        "subtopics": [
                            {
                                "title": "Spacetime Curvature",
                                "concepts": [
                                    {
                                        "title": "Gravity as Geometry",
                                        "description": "Mass tells spacetime how to curve; curvature tells matter how to move.",
                                        "material_title": "General Relativity",
                                        "material_content": "General relativity describes gravity not as a force but as the curvature of spacetime caused by mass and energy. The Einstein field equations: G_mu_nu = 8*pi*G*T_mu_nu/c^4 relate spacetime curvature (G_mu_nu) to the stress-energy tensor (T_mu_nu). Predictions include gravitational lensing (light bends near massive objects), gravitational time dilation (clocks run slower in stronger gravity), and gravitational waves (ripples in spacetime).",
                                        "practices": [
                                            {
                                                "question": "What does general relativity predict about light passing near a massive object?",
                                                "type": "mcq",
                                                "options": '{"options":["A) It speeds up","B) It bends","C) It stops","D) It is absorbed"]}',
                                                "answer": "B",
                                                "explanation": "Light follows the curvature of spacetime, causing it to bend near massive objects (gravitational lensing).",
                                            },
                                            {
                                                "question": "How does general relativity differ from Newton's theory of gravity?",
                                                "type": "short_answer",
                                                "answer": "Newton describes gravity as a force between masses; Einstein describes it as spacetime curvature caused by mass-energy.",
                                                "explanation": "General relativity reduces to Newtonian gravity in weak-field, low-speed limits but differs in strong gravitational fields.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Black Holes",
                                "concepts": [
                                    {
                                        "title": "Event Horizons and Singularities",
                                        "description": "Regions where gravity is so strong that nothing escapes.",
                                        "material_title": "Black Holes",
                                        "material_content": "A black hole forms when matter collapses beyond its Schwarzschild radius: r_s = 2*G*M/c^2. The event horizon is the boundary beyond which nothing (not even light) can escape. At the center is a singularity where density becomes infinite. The no-hair theorem states black holes are characterized only by mass, charge, and angular momentum. Hawking radiation suggests black holes slowly evaporate. Stellar-mass black holes form from massive star collapse; supermassive black holes exist at galactic centers.",
                                        "practices": [
                                            {
                                                "question": "What is the Schwarzschild radius of a black hole with mass equal to the Sun?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 7 km","B) 70 km","C) 700 km","D) 7000 km"]}',
                                                "answer": "A",
                                                "explanation": "r_s = 2*G*M/c^2 = 2*6.67e-11*2e30/(3e8)^2 approx 3000 m approx 3 km. Actually about 3 km, close to 7 km depending on precise values. The standard answer is approximately 3 km.",
                                            },
                                            {
                                                "question": "What is the event horizon of a black hole?",
                                                "type": "short_answer",
                                                "answer": "The boundary beyond which nothing, not even light, can escape the gravitational pull.",
                                                "explanation": "The event horizon is a mathematical surface, not a physical barrier; crossing it is a one-way journey.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Particle Physics",
                "slug": "particle-physics",
                "description": "The study of fundamental particles and forces.",
                "topics": [
                    {
                        "title": "Standard Model",
                        "difficulty": "advanced",
                        "description": "The theoretical framework of particle physics.",
                        "subtopics": [
                            {
                                "title": "Fundamental Particles",
                                "concepts": [
                                    {
                                        "title": "Quarks and Leptons",
                                        "description": "The building blocks of matter.",
                                        "material_title": "Standard Model Particles",
                                        "material_content": "Matter is composed of fermions: six quarks (up, down, charm, strange, top, bottom) and six leptons (electron, muon, tau, and their neutrinos). Quarks carry fractional charge and combine to form hadrons: protons (uud) and neutrons (udd). Leptons include the electron (charge -1) and neutrinos (charge 0). Each particle has an antiparticle with opposite charge. Bosons mediate the fundamental forces: photons (electromagnetic), gluons (strong), W/Z bosons (weak), and the graviton (hypothetical, gravitational).",
                                        "practices": [
                                            {
                                                "question": "What is the quark composition of a proton?",
                                                "type": "mcq",
                                                "options": '{"options":["A) udd","B) uud","C) uuu","D) ddd"]}',
                                                "answer": "B",
                                                "explanation": "A proton consists of two up quarks and one down quark (uud), giving charge +1.",
                                            },
                                            {
                                                "question": "Which force is mediated by gluons?",
                                                "type": "short_answer",
                                                "answer": "The strong nuclear force",
                                                "explanation": "Gluons mediate the strong force that binds quarks together inside hadrons.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Fundamental Forces",
                                "concepts": [
                                    {
                                        "title": "The Four Fundamental Forces",
                                        "description": "The interactions that govern all physical phenomena.",
                                        "material_title": "Fundamental Interactions",
                                        "material_content": "The four fundamental forces are: Strong (holds quarks in nucleons, range ~10^-15 m, strongest), Electromagnetic (acts on charged particles, infinite range, responsible for chemistry), Weak (responsible for radioactive decay, range ~10^-18 m), and Gravity (attractive, infinite range, weakest). The electroweak theory unifies electromagnetic and weak forces. The search for a grand unified theory (GUT) attempts to combine strong and electroweak forces.",
                                        "practices": [
                                            {
                                                "question": "Which fundamental force is the weakest?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Strong","B) Electromagnetic","C) Weak","D) Gravity"]}',
                                                "answer": "D",
                                                "explanation": "Gravity is by far the weakest force, but dominates at large scales due to its infinite range and always-attractive nature.",
                                            },
                                            {
                                                "question": "What does the weak force cause?",
                                                "type": "short_answer",
                                                "answer": "Radioactive beta decay and flavor-changing processes in particles.",
                                                "explanation": "The weak force changes quark flavors, enabling processes like a neutron decaying into a proton.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Acoustics",
                "slug": "acoustics",
                "description": "The study of sound and vibration.",
                "topics": [
                    {
                        "title": "Acoustic Phenomena",
                        "difficulty": "intermediate",
                        "description": "Key behaviors of sound in various media.",
                        "subtopics": [
                            {
                                "title": "Standing Waves and Resonance",
                                "concepts": [
                                    {
                                        "title": "Harmonics and Resonant Frequencies",
                                        "description": "Natural vibration modes of systems.",
                                        "material_title": "Standing Waves",
                                        "material_content": "Standing waves form when two waves of equal frequency and amplitude travel in opposite directions. Nodes (zero displacement) and antinodes (maximum displacement) are fixed. For a string fixed at both ends: f_n = n*v/(2L), where n is the harmonic number, v is wave speed, and L is string length. The fundamental frequency (n=1) is the lowest mode. Resonance occurs when the driving frequency matches a natural frequency, producing maximum amplitude.",
                                        "practices": [
                                            {
                                                "question": "A guitar string of length 0.65m has a fundamental frequency of 330 Hz. What is the wave speed?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 215 m/s","B) 429 m/s","C) 507 m/s","D) 660 m/s"]}',
                                                "answer": "B",
                                                "explanation": "v = f*2L = 330 * 2 * 0.65 = 429 m/s.",
                                            },
                                            {
                                                "question": "What is the second harmonic of a tube open at both ends, length 1m, with v = 340 m/s?",
                                                "type": "short_answer",
                                                "answer": "340 Hz",
                                                "explanation": "f2 = 2*v/(2L) = 2*340/(2*1) = 340 Hz.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Acoustic Engineering",
                                "concepts": [
                                    {
                                        "title": "Noise Control and Sound Insulation",
                                        "description": "Engineering approaches to managing sound.",
                                        "material_title": "Noise Control Engineering",
                                        "material_content": "Sound insulation uses mass law (heavier materials block more sound), decoupled structures (double walls with air gaps), and absorption materials (porous materials convert sound energy to heat). The sound transmission class (STC) rates wall assemblies. Active noise cancellation generates anti-phase sound waves to destructively interfere with unwanted noise. Room acoustics design uses reverberation time (RT60) to optimize speech intelligibility or musical quality.",
                                        "practices": [
                                            {
                                                "question": "How does active noise cancellation work?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Absorbs sound energy","B) Reflects sound waves","C) Generates anti-phase waves for destructive interference","D) Increases air pressure"]}',
                                                "answer": "C",
                                                "explanation": "Active noise cancellation creates a sound wave that is 180 degrees out of phase with the noise, causing destructive interference.",
                                            },
                                            {
                                                "question": "What is reverberation time (RT60)?",
                                                "type": "short_answer",
                                                "answer": "The time it takes for sound to decay by 60 dB after the source stops.",
                                                "explanation": "RT60 is critical for room acoustics: ~0.5s for speech, ~1.5-2s for music.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
        ],
    },
    # ── 5. Computer Science ─────────────────────────────────────────
    {
        "title": "Computer Science",
        "slug": "computer-science",
        "icon": "computer",
        "color": "#6366F1",
        "description": "The study of computation, information, and automation.",
        "disciplines": [
            {
                "title": "Programming Fundamentals",
                "slug": "programming-fundamentals",
                "description": "Core concepts of writing computer programs.",
                "topics": [
                    {
                        "title": "Control Flow",
                        "difficulty": "foundational",
                        "description": "How programs make decisions and repeat actions.",
                        "subtopics": [
                            {
                                "title": "Conditional Statements",
                                "concepts": [
                                    {
                                        "title": "If-Else and Switch Statements",
                                        "description": "Branching logic in programs.",
                                        "material_title": "Conditional Logic",
                                        "material_content": "Conditional statements allow programs to execute different code based on conditions. The if-else structure evaluates a boolean expression: if true, execute one block; else, execute another. Nested conditions handle multiple cases. Switch/case statements provide clean multi-way branching for discrete values. Ternary operators offer concise single-condition assignments. Proper condition design prevents logic errors and ensures all cases are handled.",
                                        "practices": [
                                            {
                                                "question": "What is the output of: x=5; if(x>3) print('A') else print('B')?",
                                                "type": "mcq",
                                                "options": '{"options":["A) A","B) B","C) AB","D) Nothing"]}',
                                                "answer": "A",
                                                "explanation": "Since 5 > 3 is true, the if branch executes and prints A.",
                                            },
                                            {
                                                "question": "Write pseudocode for a function that returns the maximum of three numbers.",
                                                "type": "short_answer",
                                                "answer": "if a>=b and a>=c return a; else if b>=c return b; else return c",
                                                "explanation": "Compare each pair to find the largest value.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Loops",
                                "concepts": [
                                    {
                                        "title": "For, While, and Do-While Loops",
                                        "description": "Repeating code blocks efficiently.",
                                        "material_title": "Iteration Constructs",
                                        "material_content": "For loops iterate a known number of times with an initialization, condition, and update. While loops repeat as long as a condition is true (pre-test). Do-while loops execute at least once before checking (post-test). Break exits the loop early; continue skips to the next iteration. Infinite loops occur when the exit condition is never met. Nested loops are common for processing multi-dimensional data but increase time complexity multiplicatively.",
                                        "practices": [
                                            {
                                                "question": "What is the difference between a while loop and a do-while loop?",
                                                "type": "mcq",
                                                "options": '{"options":["A) No difference","B) Do-while executes at least once","C) While is faster","D) Do-while cannot use break"]}',
                                                "answer": "B",
                                                "explanation": "A do-while loop checks the condition after the first execution, guaranteeing at least one run.",
                                            },
                                            {
                                                "question": "Write a loop that prints even numbers from 2 to 20.",
                                                "type": "short_answer",
                                                "answer": "for i in range(2, 21, 2): print(i)",
                                                "explanation": "Using a step of 2 in the range generates only even numbers.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Functions and Scope",
                        "difficulty": "foundational",
                        "description": "Modular code organization.",
                        "subtopics": [
                            {
                                "title": "Function Basics",
                                "concepts": [
                                    {
                                        "title": "Defining and Calling Functions",
                                        "description": "Creating reusable blocks of code.",
                                        "material_title": "Functions",
                                        "material_content": "Functions encapsulate reusable logic: they take parameters (inputs), execute a block of code, and return a value (output). Function definitions specify the name, parameters, and body. Parameters can have default values. Functions promote modularity, reusability, and readability. The DRY principle (Don't Repeat Yourself) advocates using functions to avoid code duplication. Recursion is a technique where a function calls itself to solve problems with a base case and recursive case.",
                                        "practices": [
                                            {
                                                "question": "What is the output of: def f(x): return x*2; print(f(5))?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 5","B) 10","C) 25","D) Error"]}',
                                                "answer": "B",
                                                "explanation": "The function f doubles its input: f(5) = 5*2 = 10.",
                                            },
                                            {
                                                "question": "What is the base case in a recursive function?",
                                                "type": "short_answer",
                                                "answer": "The condition that stops the recursion and returns a direct value.",
                                                "explanation": "Without a base case, the function would call itself indefinitely, causing a stack overflow.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Variable Scope",
                                "concepts": [
                                    {
                                        "title": "Local and Global Variables",
                                        "description": "Where variables are accessible in code.",
                                        "material_title": "Variable Scope",
                                        "material_content": "Scope determines where a variable can be accessed. Local variables exist only within their function or block and are created/destroyed with each call. Global variables exist throughout the program. Enclosing scope captures variables from outer functions (closures). The LEGB rule (Local, Enclosing, Global, Built-in) describes the search order. Best practice: minimize global variables to reduce side effects and improve maintainability.",
                                        "practices": [
                                            {
                                                "question": "Where can a local variable defined inside a function be accessed?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Anywhere in the program","B) Only inside that function","C) Only in the main program","D) In other functions"]}',
                                                "answer": "B",
                                                "explanation": "Local variables have function-level scope and are not accessible outside their defining function.",
                                            },
                                            {
                                                "question": "What is the LEGB rule?",
                                                "type": "short_answer",
                                                "answer": "Local, Enclosing, Global, Built-in: the order Python searches for variable names.",
                                                "explanation": "Python first checks local scope, then enclosing function scope, then global, then built-in names.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Data Structures",
                "slug": "data-structures",
                "description": "Organizing and storing data efficiently.",
                "topics": [
                    {
                        "title": "Linear Data Structures",
                        "difficulty": "foundational",
                        "description": "Data organized in sequential order.",
                        "subtopics": [
                            {
                                "title": "Arrays and Linked Lists",
                                "concepts": [
                                    {
                                        "title": "Array and List Operations",
                                        "description": "Contiguous vs. linked memory organization.",
                                        "material_title": "Arrays vs. Linked Lists",
                                        "material_content": "Arrays store elements in contiguous memory, enabling O(1) random access by index but requiring O(n) for insertions/deletions (shifting elements). Linked lists store elements as nodes with data and pointers, enabling O(1) insertions/deletions at known positions but O(n) access time (sequential search). Dynamic arrays (e.g., Python lists, ArrayLists) resize automatically. Doubly linked lists allow traversal in both directions.",
                                        "practices": [
                                            {
                                                "question": "What is the time complexity of accessing the 5th element in an array?",
                                                "type": "mcq",
                                                "options": '{"options":["A) O(1)","B) O(n)","C) O(log n)","D) O(n^2)"]}',
                                                "answer": "A",
                                                "explanation": "Arrays provide constant-time access because the address is computed directly: base + index * element_size.",
                                            },
                                            {
                                                "question": "When would you prefer a linked list over an array?",
                                                "type": "short_answer",
                                                "answer": "When frequent insertions/deletions are needed and random access is not required.",
                                                "explanation": "Linked lists excel at dynamic modifications; arrays excel at random access.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Stacks and Queues",
                                "concepts": [
                                    {
                                        "title": "LIFO and FIFO Data Structures",
                                        "description": "Restricted access linear structures.",
                                        "material_title": "Stacks and Queues",
                                        "material_content": "A stack is a LIFO (Last In, First Out) structure: push adds to the top, pop removes from the top. Applications include function call management (call stack), undo operations, and expression evaluation. A queue is FIFO (First In, First Out): enqueue adds to the rear, dequeue removes from the front. Applications include task scheduling, print queues, and breadth-first search. Deques (double-ended queues) allow operations at both ends.",
                                        "practices": [
                                            {
                                                "question": "If you push 1, 2, 3 onto a stack and then pop twice, what do you get?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 1, 2","B) 2, 3","C) 3, 2","D) 3, 1"]}',
                                                "answer": "C",
                                                "explanation": "LIFO: last pushed (3) is popped first, then 2.",
                                            },
                                            {
                                                "question": "Name two applications of a queue data structure.",
                                                "type": "short_answer",
                                                "answer": "Task scheduling in operating systems and print job management.",
                                                "explanation": "Queues ensure fair, ordered processing where the first item in is handled first.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Trees and Graphs",
                        "difficulty": "intermediate",
                        "description": "Non-linear hierarchical data structures.",
                        "subtopics": [
                            {
                                "title": "Binary Trees",
                                "concepts": [
                                    {
                                        "title": "Binary Search Trees",
                                        "description": "Ordered tree structures for efficient searching.",
                                        "material_title": "Binary Search Trees",
                                        "material_content": "A binary search tree (BST) maintains the invariant: left child < parent < right child. This enables O(log n) average-case search, insert, and delete. In-order traversal yields sorted order. Worst case (degenerate tree) is O(n). Self-balancing trees (AVL, Red-Black) guarantee O(log n) worst case by maintaining balance. BSTs are used in databases, file systems, and expression parsing.",
                                        "practices": [
                                            {
                                                "question": "What traversal of a BST produces elements in sorted order?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Pre-order","B) Post-order","C) In-order","D) Level-order"]}',
                                                "answer": "C",
                                                "explanation": "In-order traversal (left, root, right) visits BST nodes in ascending sorted order.",
                                            },
                                            {
                                                "question": "What is the worst-case time complexity for search in an unbalanced BST?",
                                                "type": "short_answer",
                                                "answer": "O(n), when the tree degenerates into a linked list.",
                                                "explanation": "If elements are inserted in sorted order, the BST becomes a chain, losing its efficiency advantage.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Hash Tables",
                                "concepts": [
                                    {
                                        "title": "Hashing and Collision Resolution",
                                        "description": "Constant-time key-value storage.",
                                        "material_title": "Hash Table Operations",
                                        "material_content": "Hash tables map keys to values using a hash function that computes an index from the key. Average-case time complexity is O(1) for search, insert, and delete. Collisions occur when two keys hash to the same index. Collision resolution methods: chaining (linked lists at each bucket) and open addressing (probing for the next empty slot). Load factor (n/m) affects performance; resizing when it exceeds a threshold maintains efficiency.",
                                        "practices": [
                                            {
                                                "question": "What causes a collision in a hash table?",
                                                "type": "mcq",
                                                "options": '{"options":["A) The table is full","B) Two keys produce the same hash index","C) The key is null","D) The value is too large"]}',
                                                "answer": "B",
                                                "explanation": "A collision occurs when the hash function maps different keys to the same array index.",
                                            },
                                            {
                                                "question": "Name two methods for resolving hash collisions.",
                                                "type": "short_answer",
                                                "answer": "Chaining (linked lists) and open addressing (linear/quadratic probing).",
                                                "explanation": "Chaining stores collisions in a list; probing searches for the next available slot.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Algorithms",
                "slug": "algorithms",
                "description": "Step-by-step procedures for solving computational problems.",
                "topics": [
                    {
                        "title": "Sorting Algorithms",
                        "difficulty": "intermediate",
                        "description": "Arranging data in a specific order.",
                        "subtopics": [
                            {
                                "title": "Comparison-Based Sorting",
                                "concepts": [
                                    {
                                        "title": "Quick Sort and Merge Sort",
                                        "description": "Efficient divide-and-conquer sorting algorithms.",
                                        "material_title": "Advanced Sorting Algorithms",
                                        "material_content": "Quick Sort selects a pivot and partitions elements into those less than and greater than the pivot, then recursively sorts each partition. Average case: O(n log n), worst case: O(n^2) (sorted input with poor pivot). Merge Sort divides the array in half, recursively sorts each half, and merges sorted halves. It guarantees O(n log n) in all cases but requires O(n) extra space. Both are divide-and-conquer algorithms.",
                                        "practices": [
                                            {
                                                "question": "What is the worst-case time complexity of Quick Sort?",
                                                "type": "mcq",
                                                "options": '{"options":["A) O(n)","B) O(n log n)","C) O(n^2)","D) O(log n)"]}',
                                                "answer": "C",
                                                "explanation": "Quick Sort's worst case is O(n^2), occurring when the pivot selection is consistently poor (e.g., already sorted data with first-element pivot).",
                                            },
                                            {
                                                "question": "Why is Merge Sort preferred when stable sorting is needed?",
                                                "type": "short_answer",
                                                "answer": "Merge Sort is a stable sort: equal elements maintain their original relative order.",
                                                "explanation": "Stability matters when sorting by multiple criteria or preserving original rankings.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Searching Algorithms",
                                "concepts": [
                                    {
                                        "title": "Binary Search",
                                        "description": "Efficient searching in sorted data.",
                                        "material_title": "Binary Search",
                                        "material_content": "Binary search finds a target in a sorted array by repeatedly dividing the search space in half. Compare the target with the middle element: if equal, found; if target is less, search the left half; if greater, search the right half. Time complexity: O(log n). This is far more efficient than linear search O(n) for large datasets. Binary search requires sorted input and is the basis for searching in balanced BSTs.",
                                        "practices": [
                                            {
                                                "question": "How many comparisons does binary search need for 1024 elements?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 10","B) 512","C) 1024","D) 20"]}',
                                                "answer": "A",
                                                "explanation": "log2(1024) = 10 comparisons in the worst case.",
                                            },
                                            {
                                                "question": "Can binary search be applied to an unsorted array?",
                                                "type": "short_answer",
                                                "answer": "No, binary search requires the data to be sorted.",
                                                "explanation": "The algorithm relies on the sorted order to eliminate half the search space each step.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Database Systems",
                "slug": "database-systems",
                "description": "Organizing, storing, and retrieving data efficiently.",
                "topics": [
                    {
                        "title": "Relational Databases",
                        "difficulty": "intermediate",
                        "description": "Data organized in tables with defined relationships.",
                        "subtopics": [
                            {
                                "title": "SQL Fundamentals",
                                "concepts": [
                                    {
                                        "title": "CRUD Operations",
                                        "description": "Creating, reading, updating, and deleting data.",
                                        "material_title": "SQL Basics",
                                        "material_content": "SQL (Structured Query Language) is the standard for relational databases. CREATE TABLE defines schema. INSERT adds rows. SELECT retrieves data with filtering (WHERE), sorting (ORDER BY), and aggregation (GROUP BY). UPDATE modifies existing rows. DELETE removes rows. JOINs combine data from multiple tables (INNER, LEFT, RIGHT, FULL). Primary keys uniquely identify rows; foreign keys enforce referential integrity between tables.",
                                        "practices": [
                                            {
                                                "question": "What SQL command retrieves all students with GPA above 3.5?",
                                                "type": "mcq",
                                                "options": '{"options":["A) GET students WHERE gpa > 3.5","B) SELECT * FROM students WHERE gpa > 3.5","C) FETCH students gpa > 3.5","D) RETRIEVE students WHERE gpa > 3.5"]}',
                                                "answer": "B",
                                                "explanation": "SELECT * FROM students WHERE gpa > 3.5 retrieves all columns for matching rows.",
                                            },
                                            {
                                                "question": "What is the difference between WHERE and HAVING?",
                                                "type": "short_answer",
                                                "answer": "WHERE filters rows before grouping; HAVING filters groups after GROUP BY.",
                                                "explanation": "WHERE cannot use aggregate functions; HAVING can (e.g., HAVING COUNT(*) > 5).",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Database Design",
                                "concepts": [
                                    {
                                        "title": "Normalization",
                                        "description": "Reducing data redundancy through decomposition.",
                                        "material_title": "Database Normalization",
                                        "material_content": "Normalization organizes databases to minimize redundancy and dependency. First Normal Form (1NF): each cell contains a single value. Second Normal Form (2NF): all non-key attributes depend on the entire primary key. Third Normal Form (3NF): no non-key attribute depends on another non-key attribute. Boyce-Codd Normal Form (BCNF) is a stricter version. Normalization prevents update anomalies (insertion, deletion, modification anomalies) at the cost of requiring joins for queries.",
                                        "practices": [
                                            {
                                                "question": "What does 1NF require?",
                                                "type": "mcq",
                                                "options": '{"options":["A) No duplicate rows","B) Each cell contains a single, atomic value","C) All columns depend on the primary key","D) No transitive dependencies"]}',
                                                "answer": "B",
                                                "explanation": "First Normal Form requires that each column contain only atomic (indivisible) values.",
                                            },
                                            {
                                                "question": "Why might you denormalize a database?",
                                                "type": "short_answer",
                                                "answer": "To improve read performance by reducing the number of JOINs needed for common queries.",
                                                "explanation": "Denormalization trades storage redundancy for query speed, common in read-heavy applications.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Operating Systems",
                "slug": "operating-systems",
                "description": "Software managing hardware resources and providing services.",
                "topics": [
                    {
                        "title": "Process Management",
                        "difficulty": "intermediate",
                        "description": "How the OS manages running programs.",
                        "subtopics": [
                            {
                                "title": "Process Scheduling",
                                "concepts": [
                                    {
                                        "title": "Scheduling Algorithms",
                                        "description": "Determining which process runs when.",
                                        "material_title": "CPU Scheduling",
                                        "material_content": "The OS scheduler determines which process gets CPU time. First-Come-First-Served (FCFS) runs processes in arrival order. Shortest Job First (SJF) minimizes average wait time. Round Robin gives each process a time quantum, ensuring responsiveness. Priority scheduling assigns priorities; starvation can occur for low-priority processes. Multilevel feedback queues combine approaches. Context switching saves and restores process state when switching CPUs.",
                                        "practices": [
                                            {
                                                "question": "Which scheduling algorithm minimizes average waiting time?",
                                                "type": "mcq",
                                                "options": '{"options":["A) FCFS","B) Round Robin","C) Shortest Job First","D) Priority"]}',
                                                "answer": "C",
                                                "explanation": "SJF is provably optimal for minimizing average waiting time among non-preemptive algorithms.",
                                            },
                                            {
                                                "question": "What is a context switch?",
                                                "type": "short_answer",
                                                "answer": "Saving the state of the current process and restoring the state of the next process to run.",
                                                "explanation": "Context switching has overhead: registers, program counter, and memory mappings must be saved/restored.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Memory Management",
                                "concepts": [
                                    {
                                        "title": "Virtual Memory and Paging",
                                        "description": "Extending physical memory using disk storage.",
                                        "material_title": "Virtual Memory",
                                        "material_content": "Virtual memory gives each process its own address space, independent of physical memory. The OS divides memory into fixed-size pages. Page tables map virtual addresses to physical addresses. When a page is not in RAM (page fault), the OS loads it from disk. Page replacement algorithms (LRU, FIFO, Clock) determine which page to evict when memory is full. Thrashing occurs when excessive paging degrades performance.",
                                        "practices": [
                                            {
                                                "question": "What happens during a page fault?",
                                                "type": "mcq",
                                                "options": '{"options":["A) The process crashes","B) The OS loads the needed page from disk into RAM","C) The CPU stops","D) The program restarts"]}',
                                                "answer": "B",
                                                "explanation": "A page fault signals that the needed page is not in physical memory; the OS retrieves it from the page file on disk.",
                                            },
                                            {
                                                "question": "What is thrashing?",
                                                "type": "short_answer",
                                                "answer": "Excessive paging that occurs when the system spends more time swapping pages than executing processes.",
                                                "explanation": "Thrashing happens when memory is over-committed, causing constant page faults.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Computer Networks",
                "slug": "computer-networks",
                "description": "Communication between computing devices.",
                "topics": [
                    {
                        "title": "Network Models",
                        "difficulty": "intermediate",
                        "description": "Frameworks for understanding network communication.",
                        "subtopics": [
                            {
                                "title": "OSI and TCP/IP Models",
                                "concepts": [
                                    {
                                        "title": "Network Layer Architecture",
                                        "description": "The layered approach to network protocols.",
                                        "material_title": "Network Protocol Layers",
                                        "material_content": "The OSI model has 7 layers: Physical (bits), Data Link (frames), Network (packets), Transport (segments), Session, Presentation, Application. The TCP/IP model condenses this to 4 layers: Link, Internet, Transport, Application. Each layer provides services to the layer above and uses services from below. TCP provides reliable, ordered delivery; UDP provides fast, unreliable delivery. IP handles addressing and routing between networks.",
                                        "practices": [
                                            {
                                                "question": "At which OSI layer does a router operate?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Data Link","B) Network","C) Transport","D) Application"]}',
                                                "answer": "B",
                                                "explanation": "Routers operate at the Network layer (Layer 3), making forwarding decisions based on IP addresses.",
                                            },
                                            {
                                                "question": "What is the difference between TCP and UDP?",
                                                "type": "short_answer",
                                                "answer": "TCP is reliable and connection-oriented; UDP is unreliable and connectionless.",
                                                "explanation": "TCP guarantees delivery with acknowledgments and retransmission; UDP is faster but provides no delivery guarantee.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "IP Addressing",
                                "concepts": [
                                    {
                                        "title": "IPv4 and Subnetting",
                                        "description": "How devices are identified on networks.",
                                        "material_title": "IP Addressing",
                                        "material_content": "IPv4 addresses are 32-bit numbers written in dotted decimal (e.g., 192.168.1.1). Subnet masks divide addresses into network and host portions. Classless Inter-Domain Routing (CIDR) uses variable-length prefixes (e.g., /24 = 255.255.255.0). Private address ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16) are not routable on the internet. NAT (Network Address Translation) maps private to public addresses. IPv6 uses 128-bit addresses to solve address exhaustion.",
                                        "practices": [
                                            {
                                                "question": "How many usable host addresses are in a /24 subnet?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 256","B) 254","C) 252","D) 128"]}',
                                                "answer": "B",
                                                "explanation": "A /24 subnet has 256 addresses, but the network and broadcast addresses are reserved: 256 - 2 = 254.",
                                            },
                                            {
                                                "question": "What is the purpose of NAT?",
                                                "type": "short_answer",
                                                "answer": "To translate private (internal) IP addresses to public IP addresses for internet communication.",
                                                "explanation": "NAT allows many devices on a private network to share a single public IP address.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Web Development",
                "slug": "web-development",
                "description": "Building applications for the World Wide Web.",
                "topics": [
                    {
                        "title": "Frontend Development",
                        "difficulty": "intermediate",
                        "description": "Client-side web technologies.",
                        "subtopics": [
                            {
                                "title": "HTML and CSS",
                                "concepts": [
                                    {
                                        "title": "Semantic HTML and Responsive Design",
                                        "description": "Structuring and styling web pages.",
                                        "material_title": "HTML and CSS Fundamentals",
                                        "material_content": "HTML (HyperText Markup Language) structures web content using semantic elements: header, nav, main, article, section, footer. CSS (Cascading Style Sheets) controls presentation: layout, colors, fonts, spacing. Responsive design uses media queries, flexible grids, and relative units (%, em, rem) to adapt layouts to different screen sizes. CSS Flexbox and Grid provide modern layout systems. Accessibility requires proper semantic markup and ARIA attributes.",
                                        "practices": [
                                            {
                                                "question": "What does the 'alt' attribute in an img tag provide?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Image styling","B) Alternative text for screen readers","C) Image file size","D) Image loading speed"]}',
                                                "answer": "B",
                                                "explanation": "The alt attribute provides text alternatives for screen readers when images cannot be displayed.",
                                            },
                                            {
                                                "question": "What is the difference between class and id selectors in CSS?",
                                                "type": "short_answer",
                                                "answer": "Class (.) selects multiple elements; ID (#) selects a single unique element.",
                                                "explanation": "Classes are reusable; IDs should be unique per page and have higher specificity.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "JavaScript",
                                "concepts": [
                                    {
                                        "title": "DOM Manipulation",
                                        "description": "Dynamically modifying web page content.",
                                        "material_title": "JavaScript and the DOM",
                                        "material_content": "JavaScript interacts with the Document Object Model (DOM) to dynamically modify HTML and CSS. document.querySelector() selects elements. eventListeners respond to user actions (click, input, submit). Element properties (innerHTML, textContent, style) modify content and appearance. create/append/remove methods modify the DOM tree. Modern frameworks (React, Vue, Angular) manage DOM updates efficiently through virtual DOM or reactive data binding.",
                                        "practices": [
                                            {
                                                "question": "How do you add a click event listener to a button in JavaScript?",
                                                "type": "mcq",
                                                "options": '{"options":["A) button.onclick = function","B) button.addEventListener(\'click\', fn)","C) button.click(fn)","D) Both A and B"]}',
                                                "answer": "D",
                                                "explanation": "Both the onclick property and addEventListener can attach click handlers, though addEventListener is preferred for multiple handlers.",
                                            },
                                            {
                                                "question": "What is the virtual DOM?",
                                                "type": "short_answer",
                                                "answer": "A lightweight in-memory copy of the real DOM used to optimize updates.",
                                                "explanation": "Frameworks like React compare virtual DOM states to determine minimal real DOM changes needed.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Backend Development",
                        "difficulty": "intermediate",
                        "description": "Server-side web technologies.",
                        "subtopics": [
                            {
                                "title": "RESTful APIs",
                                "concepts": [
                                    {
                                        "title": "API Design Principles",
                                        "description": "Designing web services using REST architecture.",
                                        "material_title": "REST API Design",
                                        "material_content": "REST (Representational State Transfer) APIs use HTTP methods: GET (read), POST (create), PUT/PATCH (update), DELETE (remove). Resources are identified by URLs (e.g., /api/users/123). JSON is the standard data format. Status codes indicate results: 200 (OK), 201 (Created), 400 (Bad Request), 401 (Unauthorized), 404 (Not Found), 500 (Server Error). Authentication uses JWT tokens, API keys, or OAuth2. Rate limiting prevents abuse.",
                                        "practices": [
                                            {
                                                "question": "Which HTTP method should be used to create a new resource?",
                                                "type": "mcq",
                                                "options": '{"options":["A) GET","B) POST","C) PUT","D) DELETE"]}',
                                                "answer": "B",
                                                "explanation": "POST is used to create new resources on the server.",
                                            },
                                            {
                                                "question": "What HTTP status code indicates a resource was not found?",
                                                "type": "short_answer",
                                                "answer": "404 Not Found",
                                                "explanation": "404 is returned when the requested resource does not exist at the given URL.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Authentication",
                                "concepts": [
                                    {
                                        "title": "JWT and Session-Based Auth",
                                        "description": "Verifying user identity in web applications.",
                                        "material_title": "Authentication Methods",
                                        "material_content": "Session-based authentication stores user state on the server after login, using session IDs in cookies. JWT (JSON Web Tokens) are self-contained tokens with encoded claims, verified without server state. JWTs have three parts: header, payload, and signature. OAuth2 enables third-party authentication (Login with Google). Password hashing (bcrypt, Argon2) is essential: never store plaintext passwords. Multi-factor authentication (MFA) adds security layers.",
                                        "practices": [
                                            {
                                                "question": "What are the three parts of a JWT?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Username, password, token","B) Header, payload, signature","C) Key, value, timestamp","D) Request, response, session"]}',
                                                "answer": "B",
                                                "explanation": "A JWT consists of a header (algorithm), payload (claims), and signature (integrity verification).",
                                            },
                                            {
                                                "question": "Why should passwords never be stored in plaintext?",
                                                "type": "short_answer",
                                                "answer": "If the database is compromised, plaintext passwords would be immediately usable by attackers.",
                                                "explanation": "Hashing (with salt) ensures that even if the database is stolen, passwords are not easily recoverable.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Artificial Intelligence",
                "slug": "artificial-intelligence",
                "description": "Creating systems that simulate human intelligence.",
                "topics": [
                    {
                        "title": "Machine Learning",
                        "difficulty": "intermediate",
                        "description": "Algorithms that learn from data.",
                        "subtopics": [
                            {
                                "title": "Supervised Learning",
                                "concepts": [
                                    {
                                        "title": "Classification and Regression",
                                        "description": "Learning from labeled training data.",
                                        "material_title": "Supervised Learning Algorithms",
                                        "material_content": "Supervised learning trains models on labeled data (input-output pairs). Classification predicts discrete labels (spam/not spam) using algorithms like logistic regression, decision trees, random forests, and support vector machines. Regression predicts continuous values (house prices) using linear regression, polynomial regression, and neural networks. Model evaluation uses train/test splits, cross-validation, and metrics (accuracy, precision, recall, F1, RMSE). Overfitting occurs when the model memorizes training data rather than learning patterns.",
                                        "practices": [
                                            {
                                                "question": "What is overfitting in machine learning?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Model performs well on training and test data","B) Model performs well on training but poorly on test data","C) Model performs poorly on both","D) Model cannot be trained"]}',
                                                "answer": "B",
                                                "explanation": "Overfitting occurs when the model learns noise in training data, leading to poor generalization to unseen data.",
                                            },
                                            {
                                                "question": "Name two techniques to prevent overfitting.",
                                                "type": "short_answer",
                                                "answer": "Regularization (L1/L2) and dropout",
                                                "explanation": "Regularization penalizes complex models; dropout randomly deactivates neurons during training.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Neural Networks",
                                "concepts": [
                                    {
                                        "title": "Deep Learning Fundamentals",
                                        "description": "Multi-layer neural network architectures.",
                                        "material_title": "Deep Learning",
                                        "material_content": "Deep neural networks have multiple hidden layers between input and output. Each neuron computes a weighted sum of inputs, applies an activation function (ReLU, sigmoid, tanh), and passes the result forward. Training uses backpropagation (gradient descent) to minimize a loss function. CNNs (convolutional neural networks) excel at image recognition using convolutional filters. RNNs and LSTMs process sequential data. Transformers use attention mechanisms and power modern NLP models like GPT and BERT.",
                                        "practices": [
                                            {
                                                "question": "What algorithm is used to train neural networks?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Binary search","B) Backpropagation","C) Breadth-first search","D) Merge sort"]}',
                                                "answer": "B",
                                                "explanation": "Backpropagation computes gradients of the loss with respect to weights, enabling gradient descent optimization.",
                                            },
                                            {
                                                "question": "What is the key innovation of transformer models?",
                                                "type": "short_answer",
                                                "answer": "The self-attention mechanism, which allows the model to weigh the importance of different input elements.",
                                                "explanation": "Attention enables transformers to capture long-range dependencies efficiently in sequential data.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Software Engineering",
                "slug": "software-engineering",
                "description": "Systematic approaches to software development.",
                "topics": [
                    {
                        "title": "Development Methodologies",
                        "difficulty": "intermediate",
                        "description": "Approaches to managing software projects.",
                        "subtopics": [
                            {
                                "title": "Agile Development",
                                "concepts": [
                                    {
                                        "title": "Scrum and Sprint Cycles",
                                        "description": "Iterative software development frameworks.",
                                        "material_title": "Agile Methodology",
                                        "material_content": "Agile development emphasizes iterative, incremental delivery with customer collaboration. Scrum is the most popular framework: work is organized into sprints (1-4 weeks), with daily standups, sprint planning, reviews, and retrospectives. The product backlog is prioritized by the product owner. The team commits to sprint goals and delivers a potentially shippable product increment. Agile contrasts with Waterfall, which follows sequential phases (requirements, design, implementation, testing, deployment).",
                                        "practices": [
                                            {
                                                "question": "What is the typical duration of a Scrum sprint?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 1 day","B) 1-4 weeks","C) 3 months","D) 1 year"]}',
                                                "answer": "B",
                                                "explanation": "Sprints are time-boxed iterations, typically lasting 1-4 weeks with 2 weeks being most common.",
                                            },
                                            {
                                                "question": "What is the purpose of a sprint retrospective?",
                                                "type": "short_answer",
                                                "answer": "To reflect on the sprint and identify improvements for the next one.",
                                                "explanation": "Retrospectives focus on process improvement: what went well, what didn't, and what to change.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Version Control",
                                "concepts": [
                                    {
                                        "title": "Git Workflow",
                                        "description": "Managing code changes collaboratively.",
                                        "material_title": "Git Version Control",
                                        "material_content": "Git tracks file changes over time, enabling collaboration and rollback. Key concepts: repositories, commits (snapshots), branches (parallel development lines), and merges (combining branches). The staging area (index) allows selective commits. .gitignore excludes files from tracking. Branching strategies: Git Flow (main/develop/feature branches), trunk-based (short-lived branches). Pull requests enable code review before merging. Remote repositories (GitHub, GitLab) enable team collaboration.",
                                        "practices": [
                                            {
                                                "question": "What command stages all modified files for the next commit?",
                                                "type": "mcq",
                                                "options": '{"options":["A) git commit","B) git add .","C) git push","D) git status"]}',
                                                "answer": "B",
                                                "explanation": "git add . stages all modified and new files in the current directory.",
                                            },
                                            {
                                                "question": "What is the purpose of a .gitignore file?",
                                                "type": "short_answer",
                                                "answer": "To specify files and directories that Git should not track or commit.",
                                                "explanation": "Common entries include node_modules/, .env files, build artifacts, and OS-specific files.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Cybersecurity",
                "slug": "cybersecurity",
                "description": "Protecting systems and data from digital attacks.",
                "topics": [
                    {
                        "title": "Security Fundamentals",
                        "difficulty": "intermediate",
                        "description": "Core principles of information security.",
                        "subtopics": [
                            {
                                "title": "CIA Triad",
                                "concepts": [
                                    {
                                        "title": "Confidentiality, Integrity, Availability",
                                        "description": "The three pillars of information security.",
                                        "material_title": "Security Principles",
                                        "material_content": "Confidentiality ensures data is accessible only to authorized users (encryption, access control). Integrity ensures data is not altered without authorization (hashing, digital signatures). Availability ensures systems and data are accessible when needed (redundancy, backups, DDoS protection). Security also encompasses authentication (verifying identity), authorization (granting permissions), and non-repudiation (proof of origin). Defense in depth applies multiple layers of security controls.",
                                        "practices": [
                                            {
                                                "question": "Which CIA principle does encryption primarily protect?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Availability","B) Integrity","C) Confidentiality","D) Authentication"]}',
                                                "answer": "C",
                                                "explanation": "Encryption ensures that only authorized parties with the decryption key can read the data.",
                                            },
                                            {
                                                "question": "What is defense in depth?",
                                                "type": "short_answer",
                                                "answer": "Applying multiple layers of security controls so that if one layer fails, others still protect the system.",
                                                "explanation": "Examples: firewall + intrusion detection + encryption + access control + monitoring.",
                                            },
                                        ],
                                    },
                                ],
                            },
                            {
                                "title": "Common Attacks",
                                "concepts": [
                                    {
                                        "title": "Malware and Social Engineering",
                                        "description": "Threats to computer systems and users.",
                                        "material_title": "Cybersecurity Threats",
                                        "material_content": "Malware includes viruses (attach to programs), worms (self-replicate), trojans (disguised as legitimate software), ransomware (encrypt files for ransom), and spyware (secretly monitors). Phishing uses deceptive emails/websites to steal credentials. SQL injection inserts malicious SQL through input fields. Cross-site scripting (XSS) injects malicious scripts into web pages. Man-in-the-middle attacks intercept communications. Strong passwords, multi-factor authentication, and security awareness training are essential defenses.",
                                        "practices": [
                                            {
                                                "question": "What type of attack encrypts a victim's files and demands payment?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Phishing","B) SQL injection","C) Ransomware","D) DDoS"]}',
                                                "answer": "C",
                                                "explanation": "Ransomware encrypts files and demands cryptocurrency payment for the decryption key.",
                                            },
                                            {
                                                "question": "How can SQL injection be prevented?",
                                                "type": "short_answer",
                                                "answer": "By using parameterized queries (prepared statements) instead of concatenating user input into SQL strings.",
                                                "explanation": "Parameterized queries separate SQL structure from data, preventing injection of malicious SQL code.",
                                            },
                                        ],
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
        ],
    },
    # -- 6. Agriculture --
    {
        "title": "Agriculture",
        "slug": "agriculture",
        "icon": "agriculture",
        "color": "#22C55E",
        "description": "The science and practice of cultivating crops and raising livestock.",
        "disciplines": [
            {
                "title": "Crop Science",
                "slug": "crop-science",
                "description": "The cultivation and improvement of crop plants.",
                "topics": [
                    {
                        "title": "Crop Physiology",
                        "difficulty": "foundational",
                        "description": "How crops grow and respond to their environment.",
                        "subtopics": [
                            {
                                "title": "Growth and Development",
                                "concepts": [
                                    {
                                        "title": "Crop Growth Stages",
                                        "description": "Phases of development from seed to harvest.",
                                        "material_title": "Crop Growth Stages",
                                        "material_content": "Crop development follows distinct stages: germination (seed imbibition and radicle emergence), seedling establishment (root and shoot development), vegetative growth (leaf and stem expansion), reproductive development (flowering and pollination), grain filling (seed maturation), and senescence (drying). Each stage has specific environmental requirements. Understanding growth stages helps optimize planting dates, irrigation timing, and fertilizer application for maximum yield.",
                                        "practices": [
                                            {
                                                "question": "What is the first stage of crop development after planting?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Flowering","B) Germination","C) Vegetative growth","D) Harvest"]}',
                                                "answer": "B",
                                                "explanation": "Germination is the first stage, where the seed absorbs water and the embryo begins to grow.",
                                            },
                                            {
                                                "question": "Why is the grain-filling stage critical for yield?",
                                                "type": "short_answer",
                                                "answer": "This is when starch and protein are accumulated in the grain, directly determining crop yield.",
                                                "explanation": "Stress during grain filling (drought, heat) can significantly reduce final yield.",
                                            },
                                        ],
                                    }
                                ],
                            },
                            {
                                "title": "Photosynthesis in Crops",
                                "concepts": [
                                    {
                                        "title": "C3, C4, and CAM Photosynthesis",
                                        "description": "Different photosynthetic pathways in crop plants.",
                                        "material_title": "Photosynthetic Pathways",
                                        "material_content": "C3 plants (rice, wheat, soybeans) use the Calvin cycle directly; they are efficient in cool, moist conditions but suffer from photorespiration in hot, dry weather. C4 plants (maize, sugarcane, sorghum) concentrate CO2 using PEP carboxylase, reducing photorespiration; they thrive in hot, high-light conditions. CAM plants (pineapple, cacti) open stomata at night to conserve water. Understanding these pathways helps select crops for specific climates.",
                                        "practices": [
                                            {
                                                "question": "Why do C4 plants have higher productivity in tropical climates?",
                                                "type": "mcq",
                                                "options": '{"options":["A) They need less water","B) They avoid photorespiration by concentrating CO2","C) They grow faster in the dark","D) They have larger leaves"]}',
                                                "answer": "B",
                                                "explanation": "C4 plants use PEP carboxylase to concentrate CO2, eliminating wasteful photorespiration.",
                                            },
                                            {
                                                "question": "Name two C4 crop plants.",
                                                "type": "short_answer",
                                                "answer": "Maize (corn) and sugarcane",
                                                "explanation": "Both are high-productivity tropical crops that use the C4 photosynthetic pathway.",
                                            },
                                        ],
                                    }
                                ],
                            },
                        ],
                    },
                    {
                        "title": "Crop Breeding",
                        "difficulty": "intermediate",
                        "description": "Genetic improvement of crop varieties.",
                        "subtopics": [
                            {
                                "title": "Breeding Methods",
                                "concepts": [
                                    {
                                        "title": "Selection and Hybridization",
                                        "description": "Traditional methods for improving crop varieties.",
                                        "material_title": "Plant Breeding Techniques",
                                        "material_content": "Mass selection involves choosing the best-performing plants from a population. Hybridization crosses two parents with complementary traits, followed by selection over multiple generations. Backcrossing transfers a specific trait from a donor into an elite variety. Pedigree method tracks offspring from cross progeny. Bulk method grows segregating populations without selection until homozygosity is achieved.",
                                        "practices": [
                                            {
                                                "question": "What is backcrossing used for in plant breeding?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Creating entirely new varieties","B) Transferring a single trait into an elite variety","C) Increasing genetic diversity","D) Testing for disease resistance"]}',
                                                "answer": "B",
                                                "explanation": "Backcrossing repeatedly crosses the hybrid back to the elite parent, retaining the desired trait.",
                                            },
                                            {
                                                "question": "How many generations of selfing achieve approximately 99% homozygosity?",
                                                "type": "short_answer",
                                                "answer": "About 7 generations (F7)",
                                                "explanation": "Homozygosity increases by approximately 50% per generation.",
                                            },
                                        ],
                                    }
                                ],
                            },
                            {
                                "title": "Biotechnology in Breeding",
                                "concepts": [
                                    {
                                        "title": "Marker-Assisted Selection",
                                        "description": "Using DNA markers to accelerate breeding.",
                                        "material_title": "Molecular Breeding",
                                        "material_content": "Marker-assisted selection (MAS) uses DNA markers linked to genes of interest to select plants at the seedling stage, before traits are expressed. This speeds up breeding cycles. QTL mapping identifies genomic regions associated with quantitative traits. Genomic selection uses genome-wide markers to predict breeding values. CRISPR-Cas9 enables precise gene editing for targeted trait modification.",
                                        "practices": [
                                            {
                                                "question": "What is the advantage of marker-assisted selection?",
                                                "type": "mcq",
                                                "options": '{"options":["A) It is cheaper","B) It can select for traits before they are visible","C) It eliminates field trials","D) It creates new genes"]}',
                                                "answer": "B",
                                                "explanation": "MAS allows early-stage selection using DNA markers, saving time and resources.",
                                            },
                                            {
                                                "question": "What technology enables precise gene editing in crops?",
                                                "type": "short_answer",
                                                "answer": "CRISPR-Cas9",
                                                "explanation": "CRISPR-Cas9 allows targeted modification of specific genes in crop genomes.",
                                            },
                                        ],
                                    }
                                ],
                            },
                        ],
                    },
                ],
            },
            {
                "title": "Soil Science",
                "slug": "soil-science",
                "description": "The study of soil properties and their role in ecosystems.",
                "topics": [
                    {
                        "title": "Soil Composition",
                        "difficulty": "foundational",
                        "description": "What soils are made of and how they form.",
                        "subtopics": [
                            {
                                "title": "Soil Texture and Structure",
                                "concepts": [
                                    {
                                        "title": "Soil Particle Classification",
                                        "description": "Sand, silt, and clay fractions and their properties.",
                                        "material_title": "Soil Texture",
                                        "material_content": "Soil texture describes the proportion of sand (0.05-2mm), silt (0.002-0.05mm), and clay (<0.002mm) particles. The soil texture triangle classifies soils into 12 textural classes. Clay soils hold more water and nutrients but drain poorly. Sandy soils drain quickly but hold few nutrients. Loam soils provide the best balance for plant growth. Soil structure refers to how particles aggregate into peds.",
                                        "practices": [
                                            {
                                                "question": "Which soil texture class is generally best for agriculture?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Sand","B) Clay","C) Loam","D) Silt"]}',
                                                "answer": "C",
                                                "explanation": "Loam provides a balanced mixture of drainage, water retention, and nutrient-holding capacity.",
                                            },
                                            {
                                                "question": "How do you determine soil texture in the field?",
                                                "type": "short_answer",
                                                "answer": "The ribbon test: wet soil is squeezed between thumb and finger; longer ribbons indicate more clay.",
                                                "explanation": "The ribbon test is a quick field method for estimating soil texture.",
                                            },
                                        ],
                                    }
                                ],
                            },
                            {
                                "title": "Soil Chemistry",
                                "concepts": [
                                    {
                                        "title": "Soil pH and Nutrient Availability",
                                        "description": "Chemical properties that affect plant nutrition.",
                                        "material_title": "Soil Chemistry",
                                        "material_content": "Soil pH controls nutrient availability: most nutrients are available at pH 6.0-7.5. Cation exchange capacity (CEC) measures the soil's ability to hold positively charged nutrients. Clay and organic matter have high CEC. Liming raises pH; sulfur lowers it. Soil testing guides fertilizer and amendment recommendations.",
                                        "practices": [
                                            {
                                                "question": "At what soil pH are most nutrients available?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 4.5-5.5","B) 6.0-7.5","C) 8.0-9.0","D) 10-11"]}',
                                                "answer": "B",
                                                "explanation": "Most nutrients have optimal availability in the slightly acidic to neutral range.",
                                            },
                                            {
                                                "question": "What does CEC measure in soil?",
                                                "type": "short_answer",
                                                "answer": "The soil's ability to hold and exchange positively charged nutrient ions.",
                                                "explanation": "High CEC soils hold more nutrients and resist leaching.",
                                            },
                                        ],
                                    }
                                ],
                            },
                        ],
                    }
                ],
            },
            {
                "title": "Agricultural Engineering",
                "slug": "agricultural-engineering",
                "description": "Engineering principles applied to agriculture.",
                "topics": [
                    {
                        "title": "Irrigation Engineering",
                        "difficulty": "intermediate",
                        "description": "Systems for delivering water to crops.",
                        "subtopics": [
                            {
                                "title": "Irrigation Methods",
                                "concepts": [
                                    {
                                        "title": "Surface, Drip, and Sprinkler Irrigation",
                                        "description": "Different approaches to applying water to crops.",
                                        "material_title": "Irrigation Systems",
                                        "material_content": "Surface irrigation uses gravity to distribute water (40-60% efficient). Sprinkler irrigation simulates rainfall (75-85% efficient). Drip irrigation delivers water directly to the root zone through emitters (90-95% efficient). Center pivot irrigation uses rotating arms on wheeled towers. The choice depends on crop type, soil, climate, and economics.",
                                        "practices": [
                                            {
                                                "question": "Which irrigation method has the highest water-use efficiency?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Flood","B) Sprinkler","C) Drip","D) Furrow"]}',
                                                "answer": "C",
                                                "explanation": "Drip irrigation delivers water directly to roots, minimizing evaporation and runoff.",
                                            },
                                            {
                                                "question": "What is the main advantage of center pivot irrigation?",
                                                "type": "short_answer",
                                                "answer": "It can efficiently irrigate large fields with minimal labor.",
                                                "explanation": "Center pivot systems automate water distribution across large areas.",
                                            },
                                        ],
                                    }
                                ],
                            },
                            {
                                "title": "Water Management",
                                "concepts": [
                                    {
                                        "title": "Evapotranspiration and Water Balance",
                                        "description": "Calculating crop water requirements.",
                                        "material_title": "Crop Water Requirements",
                                        "material_content": "Evapotranspiration (ET) is the combined water loss from soil evaporation and plant transpiration. Crop ET (ETc) = Kc * ET0, where Kc is the crop coefficient. Deficit irrigation strategies deliberately under-irrigate to save water with acceptable yield loss.",
                                        "practices": [
                                            {
                                                "question": "If ET0 = 6 mm/day and Kc = 1.2, what is ETc?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 5.0 mm","B) 6.0 mm","C) 7.2 mm","D) 8.4 mm"]}',
                                                "answer": "C",
                                                "explanation": "ETc = Kc * ET0 = 1.2 * 6 = 7.2 mm/day.",
                                            },
                                            {
                                                "question": "What is deficit irrigation?",
                                                "type": "short_answer",
                                                "answer": "Applying less water than full crop requirement to save water while accepting some yield reduction.",
                                                "explanation": "Deficit irrigation optimizes water productivity in water-scarce regions.",
                                            },
                                        ],
                                    }
                                ],
                            },
                        ],
                    }
                ],
            },
            {
                "title": "Animal Husbandry",
                "slug": "animal-husbandry",
                "description": "The breeding and care of farm animals.",
                "topics": [
                    {
                        "title": "Livestock Nutrition",
                        "difficulty": "intermediate",
                        "description": "Feeding and nutrition of farm animals.",
                        "subtopics": [
                            {
                                "title": "Feed and Digestion",
                                "concepts": [
                                    {
                                        "title": "Ruminant Digestion",
                                        "description": "The four-chambered stomach system of cattle and sheep.",
                                        "material_title": "Ruminant Digestive System",
                                        "material_content": "Ruminants have a four-compartment stomach: rumen (fermentation vat), reticulum, omasum, and abomasum (true stomach). Microbes in the rumen convert cellulose to volatile fatty acids (VFAs), the primary energy source. Protein quality for ruminants is measured by bypass protein that reaches the small intestine intact.",
                                        "practices": [
                                            {
                                                "question": "Which compartment is the primary site of microbial fermentation?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Abomasum","B) Reticulum","C) Rumen","D) Omasum"]}',
                                                "answer": "C",
                                                "explanation": "The rumen contains billions of microbes that break down cellulose into usable energy.",
                                            },
                                            {
                                                "question": "What are volatile fatty acids and why are they important?",
                                                "type": "short_answer",
                                                "answer": "VFAs are products of rumen fermentation providing 60-80% of the animal's energy.",
                                                "explanation": "VFAs are absorbed through the rumen wall and used as the primary energy source.",
                                            },
                                        ],
                                    }
                                ],
                            },
                            {
                                "title": "Dairy Science",
                                "concepts": [
                                    {
                                        "title": "Milk Production",
                                        "description": "Physiology and management of dairy cattle.",
                                        "material_title": "Dairy Production",
                                        "material_content": "Milk is produced in the mammary gland. Yield depends on genetics, nutrition, and stage of lactation. The lactation curve peaks at 4-8 weeks postpartum. Milk contains water (87%), lactose, fat, protein, and minerals. Total mixed rations (TMR) balance nutrients for optimal production.",
                                        "practices": [
                                            {
                                                "question": "When does milk production peak in a cow's lactation?",
                                                "type": "mcq",
                                                "options": '{"options":["A) At calving","B) 4-8 weeks after calving","C) 6 months after calving","D) At drying off"]}',
                                                "answer": "B",
                                                "explanation": "Milk yield typically peaks 4-8 weeks postpartum.",
                                            },
                                            {
                                                "question": "What is a total mixed ration (TMR)?",
                                                "type": "short_answer",
                                                "answer": "A precisely blended mix of forages, grains, protein supplements, vitamins, and minerals.",
                                                "explanation": "TMR ensures each bite contains a balanced diet.",
                                            },
                                        ],
                                    }
                                ],
                            },
                        ],
                    }
                ],
            },
            {
                "title": "Agricultural Economics",
                "slug": "agricultural-economics",
                "description": "Economic principles applied to farming and food systems.",
                "topics": [
                    {
                        "title": "Farm Management",
                        "difficulty": "intermediate",
                        "description": "Decision-making on agricultural enterprises.",
                        "subtopics": [
                            {
                                "title": "Production Economics",
                                "concepts": [
                                    {
                                        "title": "Cost Analysis and Profitability",
                                        "description": "Calculating costs and returns in farming.",
                                        "material_title": "Farm Financial Management",
                                        "material_content": "Fixed costs (land, machinery) remain constant. Variable costs (seed, fertilizer, fuel) change with production. Profit = total revenue - total cost. Marginal analysis determines optimal input levels. Break-even analysis identifies minimum production levels needed to cover costs.",
                                        "practices": [
                                            {
                                                "question": "What is the break-even yield?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Maximum yield","B) Yield where revenue equals total cost","C) Average yield","D) Yield covering variable costs only"]}',
                                                "answer": "B",
                                                "explanation": "Break-even yield is where total revenue equals total cost, resulting in zero profit.",
                                            },
                                            {
                                                "question": "What is the difference between fixed and variable costs?",
                                                "type": "short_answer",
                                                "answer": "Fixed costs do not change with production; variable costs increase with more production.",
                                                "explanation": "Land rent is fixed; seed cost varies with area planted (variable).",
                                            },
                                        ],
                                    }
                                ],
                            }
                        ],
                    }
                ],
            },
            {
                "title": "Plant Pathology",
                "slug": "plant-pathology",
                "description": "Study of plant diseases and their management.",
                "topics": [
                    {
                        "title": "Disease Epidemiology",
                        "difficulty": "intermediate",
                        "description": "How plant diseases spread in populations.",
                        "subtopics": [
                            {
                                "title": "Disease Triangle",
                                "concepts": [
                                    {
                                        "title": "The Disease Triangle",
                                        "description": "Three factors required for plant disease.",
                                        "material_title": "Plant Disease Fundamentals",
                                        "material_content": "The disease triangle states that three conditions must coincide: a susceptible host, a virulent pathogen, and a favorable environment. Disease cycles include inoculum production, dispersal, infection, and sporulation.",
                                        "practices": [
                                            {
                                                "question": "What are the three components of the disease triangle?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Host, pathogen, environment","B) Soil, water, sunlight","C) Seeds, fertilizer, pesticide","D) Temperature, humidity, wind"]}',
                                                "answer": "A",
                                                "explanation": "Disease requires a susceptible host, a virulent pathogen, and favorable environmental conditions.",
                                            },
                                            {
                                                "question": "How does crop rotation help prevent disease?",
                                                "type": "short_answer",
                                                "answer": "It breaks the disease cycle by removing the host for pathogen survival.",
                                                "explanation": "Many pathogens survive on crop residues; rotating to a non-host crop starves them.",
                                            },
                                        ],
                                    }
                                ],
                            }
                        ],
                    }
                ],
            },
            {
                "title": "Water Resources Management",
                "slug": "water-resources",
                "description": "Sustainable management of water for agriculture.",
                "topics": [
                    {
                        "title": "Watershed Management",
                        "difficulty": "intermediate",
                        "description": "Managing water at the landscape scale.",
                        "subtopics": [
                            {
                                "title": "Watershed Hydrology",
                                "concepts": [
                                    {
                                        "title": "Water Cycle in Agriculture",
                                        "description": "How water moves through agricultural landscapes.",
                                        "material_title": "Agricultural Hydrology",
                                        "material_content": "The hydrological cycle in agricultural areas involves precipitation, infiltration, surface runoff, and evapotranspiration. No-till increases infiltration, reducing runoff and erosion. Buffer strips along waterways filter sediment and nutrients.",
                                        "practices": [
                                            {
                                                "question": "How does no-till farming affect water infiltration?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Decreases it","B) No effect","C) Increases it","D) Eliminates it"]}',
                                                "answer": "C",
                                                "explanation": "No-till preserves soil structure and surface residue, increasing infiltration.",
                                            },
                                            {
                                                "question": "What is the role of riparian buffer strips?",
                                                "type": "short_answer",
                                                "answer": "Vegetated strips that filter sediment, nutrients, and pesticides from runoff.",
                                                "explanation": "Buffers protect water quality by trapping pollutants before they reach waterways.",
                                            },
                                        ],
                                    }
                                ],
                            },
                            {
                                "title": "Groundwater Management",
                                "concepts": [
                                    {
                                        "title": "Aquifer Sustainability",
                                        "description": "Managing underground water resources.",
                                        "material_title": "Groundwater Management",
                                        "material_content": "Groundwater is stored in aquifers. Over-pumping causes water table decline, land subsidence, and saltwater intrusion. Sustainable yield is the amount that can be extracted without depleting the aquifer. Managed aquifer recharge augments natural recharge.",
                                        "practices": [
                                            {
                                                "question": "What happens when groundwater is over-pumped in coastal areas?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Water becomes sweeter","B) Saltwater intrusion contaminates wells","C) Aquifer refills faster","D) No effect"]}',
                                                "answer": "B",
                                                "explanation": "Over-pumping reduces freshwater pressure, allowing saltwater to migrate inland.",
                                            },
                                            {
                                                "question": "What is managed aquifer recharge?",
                                                "type": "short_answer",
                                                "answer": "Intentionally adding water to aquifers through infiltration basins or injection wells.",
                                                "explanation": "MAR augments natural recharge to store water for future use.",
                                            },
                                        ],
                                    }
                                ],
                            },
                        ],
                    }
                ],
            },
        ],
    },
    # -- 7. Environmental Science --
    {
        "title": "Environmental Science",
        "slug": "environmental-science",
        "icon": "eco",
        "color": "#059669",
        "description": "The interdisciplinary study of the natural environment and human impacts.",
        "disciplines": [
            {
                "title": "Environmental Ecology",
                "slug": "environmental-ecology",
                "description": "Ecological principles applied to environmental issues.",
                "topics": [
                    {
                        "title": "Ecosystem Services",
                        "difficulty": "foundational",
                        "description": "Benefits that ecosystems provide to humans.",
                        "subtopics": [
                            {
                                "title": "Types of Ecosystem Services",
                                "concepts": [
                                    {
                                        "title": "Provisioning, Regulating, Cultural, and Supporting Services",
                                        "description": "The four categories of ecosystem services.",
                                        "material_title": "Ecosystem Services Framework",
                                        "material_content": "Provisioning services provide tangible goods (food, water, timber, fiber). Regulating services control environmental processes (climate regulation, water purification, pollination, flood control). Cultural services provide non-material benefits (recreation, spiritual value, education). Supporting services maintain other services (nutrient cycling, soil formation, primary production). The Millennium Ecosystem Assessment classified these four categories to value nature's contributions to human well-being.",
                                        "practices": [
                                            {
                                                "question": "Which category does pollination fall under?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Provisioning","B) Regulating","C) Cultural","D) Supporting"]}',
                                                "answer": "B",
                                                "explanation": "Pollination is a regulating service because it controls the reproduction of plants.",
                                            },
                                            {
                                                "question": "Name two provisioning ecosystem services.",
                                                "type": "short_answer",
                                                "answer": "Fresh water supply and food production",
                                                "explanation": "Provisioning services are the tangible goods obtained from ecosystems.",
                                            },
                                        ],
                                    }
                                ],
                            }
                        ],
                    }
                ],
            },
            {
                "title": "Conservation Biology",
                "slug": "conservation-biology",
                "description": "Protecting and restoring biodiversity.",
                "topics": [
                    {
                        "title": "Biodiversity",
                        "difficulty": "foundational",
                        "description": "The variety of life at all levels.",
                        "subtopics": [
                            {
                                "title": "Levels of Biodiversity",
                                "concepts": [
                                    {
                                        "title": "Genetic, Species, and Ecosystem Diversity",
                                        "description": "The three hierarchical levels of biodiversity.",
                                        "material_title": "Biodiversity Levels",
                                        "material_content": "Genetic diversity is the variation in genes within a species, enabling adaptation. Species diversity is the variety of species in an area, measured by species richness and evenness (Shannon index). Ecosystem diversity is the variety of habitats, communities, and ecological processes. Biodiversity hotspots are regions with high species richness and significant habitat loss. Biodiversity underpins ecosystem resilience, providing insurance against environmental change.",
                                        "practices": [
                                            {
                                                "question": "What does species richness measure?",
                                                "type": "mcq",
                                                "options": '{"options":["A) The number of individuals per species","B) The number of different species in an area","C) The genetic diversity within a species","D) The area of habitat"]}',
                                                "answer": "B",
                                                "explanation": "Species richness is simply the count of different species present in a defined area.",
                                            },
                                            {
                                                "question": "Why is genetic diversity important for species survival?",
                                                "type": "short_answer",
                                                "answer": "It provides the raw material for natural selection and adaptation to environmental changes.",
                                                "explanation": "Genetically diverse populations are more likely to contain individuals that survive new diseases or climate shifts.",
                                            },
                                        ],
                                    }
                                ],
                            }
                        ],
                    }
                ],
            },
            {
                "title": "Pollution and Remediation",
                "slug": "pollution-remediation",
                "description": "Environmental contamination and cleanup methods.",
                "topics": [
                    {
                        "title": "Water Pollution",
                        "difficulty": "intermediate",
                        "description": "Contamination of freshwater and marine systems.",
                        "subtopics": [
                            {
                                "title": "Types of Water Pollutants",
                                "concepts": [
                                    {
                                        "title": "Point Source and Non-Point Source Pollution",
                                        "description": "Different origins of water contamination.",
                                        "material_title": "Water Pollution Sources",
                                        "material_content": "Point source pollution comes from identifiable, discrete sources (factory pipes, sewage outlets). Non-point source pollution comes from diffuse sources (agricultural runoff, urban stormwater, atmospheric deposition). Key pollutants include nutrients (nitrogen, phosphorus causing eutrophication), heavy metals, pesticides, pharmaceuticals, and microplastics. Biological oxygen demand (BOD) measures organic pollution by the oxygen needed to decompose waste. Eutrophication causes algal blooms and dead zones.",
                                        "practices": [
                                            {
                                                "question": "What is eutrophication?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Heavy metal contamination","B) Nutrient enrichment causing algal blooms","C) Oil spills","D) Thermal pollution"]}',
                                                "answer": "B",
                                                "explanation": "Eutrophication results from excess nutrients (N, P) causing algal blooms that deplete oxygen when they decompose.",
                                            },
                                            {
                                                "question": "What is the difference between point and non-point source pollution?",
                                                "type": "short_answer",
                                                "answer": "Point source comes from a single identifiable location; non-point source comes from diffuse areas.",
                                                "explanation": "A factory pipe is point source; agricultural runoff across a watershed is non-point source.",
                                            },
                                        ],
                                    }
                                ],
                            }
                        ],
                    }
                ],
            },
            {
                "title": "Climate Science",
                "slug": "climate-science",
                "description": "Understanding Earth's climate system and change.",
                "topics": [
                    {
                        "title": "Climate Change",
                        "difficulty": "intermediate",
                        "description": "Long-term changes in Earth's climate patterns.",
                        "subtopics": [
                            {
                                "title": "Causes of Climate Change",
                                "concepts": [
                                    {
                                        "title": "Greenhouse Effect and Global Warming",
                                        "description": "How greenhouse gases trap heat in the atmosphere.",
                                        "material_title": "The Greenhouse Effect",
                                        "material_content": "The natural greenhouse effect keeps Earth habitable by trapping outgoing infrared radiation. Greenhouse gases (CO2, CH4, N2O, water vapor) absorb and re-emit infrared radiation. Human activities have increased CO2 from ~280 ppm (pre-industrial) to over 420 ppm (2024). Enhanced greenhouse effect causes global warming: rising average temperatures, melting ice caps, sea level rise, and more extreme weather. Feedback loops (ice-albedo, water vapor) amplify warming.",
                                        "practices": [
                                            {
                                                "question": "What is the primary human-caused greenhouse gas?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Methane","B) Carbon dioxide","C) Nitrous oxide","D) Ozone"]}',
                                                "answer": "B",
                                                "explanation": "CO2 from fossil fuel combustion is the largest contributor to anthropogenic climate change.",
                                            },
                                            {
                                                "question": "What is the ice-albedo feedback loop?",
                                                "type": "short_answer",
                                                "answer": "Warming melts ice, exposing darker surfaces that absorb more heat, causing further warming.",
                                                "explanation": "This positive feedback loop amplifies initial warming by reducing Earth's reflectivity.",
                                            },
                                        ],
                                    }
                                ],
                            }
                        ],
                    }
                ],
            },
        ],
    },
    # -- 8. Statistics --
    {
        "title": "Statistics",
        "slug": "statistics",
        "icon": "bar_chart",
        "color": "#0EA5E9",
        "description": "The science of collecting, analyzing, and interpreting data.",
        "disciplines": [
            {
                "title": "Descriptive Statistics",
                "slug": "descriptive-statistics",
                "description": "Summarizing and describing data features.",
                "topics": [
                    {
                        "title": "Measures of Central Tendency",
                        "difficulty": "foundational",
                        "description": "Single values representing data centers.",
                        "subtopics": [
                            {
                                "title": "Mean, Median, and Mode",
                                "concepts": [
                                    {
                                        "title": "Computing and Interpreting Central Tendency",
                                        "description": "The three main measures of data center.",
                                        "material_title": "Central Tendency Measures",
                                        "material_content": "The mean is the arithmetic average (sum/n), sensitive to outliers. The median is the middle value when data is sorted, robust to outliers. The mode is the most frequent value, useful for categorical data. For symmetric distributions, mean = median = mode. For right-skewed data, mean > median. For left-skewed, mean < median. Choosing the appropriate measure depends on data distribution and the presence of outliers.",
                                        "practices": [
                                            {
                                                "question": "Which measure of central tendency is most affected by outliers?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Median","B) Mode","C) Mean","D) Range"]}',
                                                "answer": "C",
                                                "explanation": "The mean is calculated using every value, so extreme outliers pull it toward them.",
                                            },
                                            {
                                                "question": "The dataset is: 2, 3, 3, 5, 12. What is the median?",
                                                "type": "short_answer",
                                                "answer": "3",
                                                "explanation": "The sorted dataset is 2, 3, 3, 5, 12. The middle value (3rd of 5) is 3.",
                                            },
                                        ],
                                    }
                                ],
                            }
                        ],
                    },
                    {
                        "title": "Measures of Spread",
                        "difficulty": "foundational",
                        "description": "Quantifying data variability.",
                        "subtopics": [
                            {
                                "title": "Variance and Standard Deviation",
                                "concepts": [
                                    {
                                        "title": "Dispersion Measures",
                                        "description": "How spread out data values are.",
                                        "material_title": "Data Spread Measures",
                                        "material_content": "Range is the difference between max and min. Variance is the average squared deviation from the mean: s^2 = sum((xi - xbar)^2)/(n-1). Standard deviation is the square root of variance, in the same units as the data. The interquartile range (IQR = Q3 - Q1) is robust to outliers. The coefficient of variation (CV = s/xbar * 100%) allows comparing spread across datasets with different units or means.",
                                        "practices": [
                                            {
                                                "question": "What does a standard deviation of zero indicate?",
                                                "type": "mcq",
                                                "options": '{"options":["A) The data is skewed","B) All values are identical","C) The mean is zero","D) The data has no outliers"]}',
                                                "answer": "B",
                                                "explanation": "If all values equal the mean, the standard deviation is zero, meaning no variability.",
                                            },
                                            {
                                                "question": "Why is sample variance divided by n-1 instead of n?",
                                                "type": "short_answer",
                                                "answer": "Using n-1 (Bessel's correction) gives an unbiased estimate of the population variance.",
                                                "explanation": "Dividing by n systematically underestimates the true population variance.",
                                            },
                                        ],
                                    }
                                ],
                            }
                        ],
                    },
                ],
            },
            {
                "title": "Probability Theory",
                "slug": "probability-theory",
                "description": "Mathematical framework for uncertainty.",
                "topics": [
                    {
                        "title": "Probability Distributions",
                        "difficulty": "intermediate",
                        "description": "Models describing random phenomena.",
                        "subtopics": [
                            {
                                "title": "Discrete Distributions",
                                "concepts": [
                                    {
                                        "title": "Binomial and Poisson Distributions",
                                        "description": "Common discrete probability models.",
                                        "material_title": "Discrete Distributions",
                                        "material_content": "The binomial distribution B(n,p) counts successes in n independent trials with probability p each. P(X=k) = C(n,k)*p^k*(1-p)^(n-k). Mean = np, variance = np(1-p). The Poisson distribution Pois(lambda) counts events in a fixed interval when events occur independently at rate lambda. P(X=k) = e^(-lambda)*lambda^k/k!. Mean = variance = lambda. The Poisson approximates the binomial when n is large and p is small.",
                                        "practices": [
                                            {
                                                "question": "A coin is flipped 10 times. What is the probability of exactly 7 heads?",
                                                "type": "mcq",
                                                "options": '{"options":["A) 0.117","B) 0.205","C) 0.500","D) 0.700"]}',
                                                "answer": "A",
                                                "explanation": "P(X=7) = C(10,7)*0.5^7*0.5^3 = 120*0.0078125*0.125 = 0.117.",
                                            },
                                            {
                                                "question": "When does the Poisson distribution apply?",
                                                "type": "short_answer",
                                                "answer": "When counting independent events occurring at a constant average rate in a fixed interval.",
                                                "explanation": "Examples: number of customer arrivals per hour, mutations per gene per generation.",
                                            },
                                        ],
                                    }
                                ],
                            }
                        ],
                    }
                ],
            },
            {
                "title": "Inferential Statistics",
                "slug": "inferential-statistics",
                "description": "Drawing conclusions about populations from samples.",
                "topics": [
                    {
                        "title": "Hypothesis Testing",
                        "difficulty": "intermediate",
                        "description": "Formal procedures for testing claims about populations.",
                        "subtopics": [
                            {
                                "title": "Test Framework",
                                "concepts": [
                                    {
                                        "title": "Null and Alternative Hypotheses",
                                        "description": "The formal structure of statistical tests.",
                                        "material_title": "Hypothesis Testing",
                                        "material_content": "The null hypothesis (H0) states no effect or no difference. The alternative hypothesis (Ha) states the effect we want to detect. The significance level (alpha, typically 0.05) is the probability of rejecting H0 when it is true (Type I error). The p-value is the probability of observing data as extreme as ours, given H0 is true. If p < alpha, reject H0. Type II error (beta) is failing to reject a false H0. Power = 1 - beta.",
                                        "practices": [
                                            {
                                                "question": "What is a Type I error in hypothesis testing?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Failing to detect a real effect","B) Rejecting a true null hypothesis","C) Accepting a false alternative","D) Using the wrong test"]}',
                                                "answer": "B",
                                                "explanation": "Type I error (false positive) occurs when we reject H0 when it is actually true.",
                                            },
                                            {
                                                "question": "What does a p-value of 0.03 mean at alpha = 0.05?",
                                                "type": "short_answer",
                                                "answer": "There is a 3% probability of observing this data if H0 is true; we reject H0.",
                                                "explanation": "Since 0.03 < 0.05, the result is statistically significant and we reject the null hypothesis.",
                                            },
                                        ],
                                    }
                                ],
                            }
                        ],
                    }
                ],
            },
            {
                "title": "Regression Analysis",
                "slug": "regression-analysis",
                "description": "Modeling relationships between variables.",
                "topics": [
                    {
                        "title": "Linear Regression",
                        "difficulty": "intermediate",
                        "description": "Fitting straight lines to data.",
                        "subtopics": [
                            {
                                "title": "Simple Linear Regression",
                                "concepts": [
                                    {
                                        "title": "Least Squares Method",
                                        "description": "Finding the best-fitting line through data points.",
                                        "material_title": "Linear Regression",
                                        "material_content": "Simple linear regression models the relationship y = beta0 + beta1*x + epsilon. The least squares method minimizes sum of squared residuals. The slope beta1 = sum((xi-xbar)(yi-ybar))/sum((xi-xbar)^2). R-squared (coefficient of determination) measures the proportion of variance explained: R^2 = 1 - SSE/SST. Assumptions: linearity, independence, homoscedasticity, normality of residuals (LINE).",
                                        "practices": [
                                            {
                                                "question": "What does R-squared measure?",
                                                "type": "mcq",
                                                "options": '{"options":["A) The slope of the regression line","B) The proportion of variance in Y explained by X","C) The correlation coefficient","D) The p-value"]}',
                                                "answer": "B",
                                                "explanation": "R-squared indicates how well the model explains the variation in the dependent variable.",
                                            },
                                            {
                                                "question": "What are the four assumptions of linear regression?",
                                                "type": "short_answer",
                                                "answer": "Linearity, Independence, Normality of residuals, and Equal variance (homoscedasticity).",
                                                "explanation": "These are remembered by the acronym LINE.",
                                            },
                                        ],
                                    }
                                ],
                            }
                        ],
                    }
                ],
            },
            {
                "title": "Bayesian Statistics",
                "slug": "bayesian-statistics",
                "description": "Updating beliefs with evidence using probability.",
                "topics": [
                    {
                        "title": "Bayesian Inference",
                        "difficulty": "advanced",
                        "description": "The Bayesian approach to statistical reasoning.",
                        "subtopics": [
                            {
                                "title": "Bayes' Theorem in Statistics",
                                "concepts": [
                                    {
                                        "title": "Prior, Likelihood, and Posterior",
                                        "description": "The components of Bayesian updating.",
                                        "material_title": "Bayesian Framework",
                                        "material_content": "Bayesian inference uses Bayes' theorem: posterior = (likelihood * prior) / evidence. The prior represents initial beliefs about a parameter. The likelihood is the probability of the data given the parameter. The posterior is the updated belief after seeing data. As more data accumulates, the posterior becomes dominated by the likelihood, and the prior matters less. Bayesian credible intervals give the probability that a parameter lies within a range, unlike frequentist confidence intervals.",
                                        "practices": [
                                            {
                                                "question": "In Bayesian inference, what does the prior represent?",
                                                "type": "mcq",
                                                "options": '{"options":["A) The observed data","B) Initial beliefs about a parameter before seeing data","C) The final conclusion","D) The sample size"]}',
                                                "answer": "B",
                                                "explanation": "The prior encodes existing knowledge or assumptions about the parameter before data is collected.",
                                            },
                                            {
                                                "question": "What happens to the posterior as sample size increases?",
                                                "type": "short_answer",
                                                "answer": "The posterior becomes more influenced by the data (likelihood) and less by the prior.",
                                                "explanation": "With large datasets, the likelihood overwhelms the prior, and all observers converge on similar posteriors.",
                                            },
                                        ],
                                    }
                                ],
                            }
                        ],
                    }
                ],
            },
        ],
    },
    # -- 9. Earth and Geosciences --
    {
        "title": "Earth and Geosciences",
        "slug": "earth-geosciences",
        "icon": "public",
        "color": "#A855F7",
        "description": "The study of Earth's structure, processes, and history.",
        "disciplines": [
            {
                "title": "Geology",
                "slug": "geology",
                "description": "The study of Earth's solid structure and materials.",
                "topics": [
                    {
                        "title": "Mineralogy",
                        "difficulty": "foundational",
                        "description": "The study of minerals and their properties.",
                        "subtopics": [
                            {
                                "title": "Mineral Identification",
                                "concepts": [
                                    {
                                        "title": "Physical Properties of Minerals",
                                        "description": "Observable characteristics used to identify minerals.",
                                        "material_title": "Mineral Properties",
                                        "material_content": "Minerals are naturally occurring, inorganic, crystalline solids with definite chemical composition. Key identification properties include: hardness (Mohs scale 1-10), luster (metallic vs. non-metallic), cleavage (planes of breakage), fracture (irregular breakage), streak (color of powdered mineral), color, specific gravity, and crystal habit. For example, quartz has hardness 7, no cleavage, vitreous luster, and conchoidal fracture.",
                                        "practices": [
                                            {
                                                "question": "On the Mohs scale, which mineral has hardness 10?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Quartz","B) Topaz","C) Diamond","D) Corundum"]}',
                                                "answer": "C",
                                                "explanation": "Diamond is the hardest natural mineral with a Mohs hardness of 10.",
                                            },
                                            {
                                                "question": "What is the difference between cleavage and fracture?",
                                                "type": "short_answer",
                                                "answer": "Cleavage is breaking along flat, parallel planes; fracture is irregular, uneven breakage.",
                                                "explanation": "Cleavage results from weak bonds in certain crystallographic directions.",
                                            },
                                        ],
                                    }
                                ],
                            }
                        ],
                    },
                    {
                        "title": "Plate Tectonics",
                        "difficulty": "intermediate",
                        "description": "The theory explaining Earth's surface dynamics.",
                        "subtopics": [
                            {
                                "title": "Tectonic Plate Boundaries",
                                "concepts": [
                                    {
                                        "title": "Types of Plate Boundaries",
                                        "description": "Convergent, divergent, and transform boundaries.",
                                        "material_title": "Plate Boundary Types",
                                        "material_content": "Divergent boundaries separate plates, creating new crust (mid-ocean ridges, rift valleys). Convergent boundaries bring plates together: oceanic-oceanic (island arcs), oceanic-continental (subduction zones, volcanic mountains), continental-continental (mountain ranges like the Himalayas). Transform boundaries slide plates past each other horizontally (San Andreas Fault). Plate tectonics explains earthquakes, volcanism, mountain building, and the distribution of continents and oceans.",
                                        "practices": [
                                            {
                                                "question": "What type of boundary forms the Himalayan mountains?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Divergent","B) Transform","C) Convergent (continental-continental)","D) Convergent (oceanic-oceanic)"]}',
                                                "answer": "C",
                                                "explanation": "The Himalayas formed from the collision of the Indian and Eurasian continental plates.",
                                            },
                                            {
                                                "question": "Where are new oceanic plates created?",
                                                "type": "short_answer",
                                                "answer": "At divergent boundaries, specifically mid-ocean ridges.",
                                                "explanation": "Magma rises at mid-ocean ridges, solidifying to form new oceanic crust (seafloor spreading).",
                                            },
                                        ],
                                    }
                                ],
                            }
                        ],
                    },
                ],
            },
            {
                "title": "Meteorology",
                "slug": "meteorology",
                "description": "The study of Earth's atmosphere and weather.",
                "topics": [
                    {
                        "title": "Atmospheric Processes",
                        "difficulty": "intermediate",
                        "description": "Physical processes driving weather patterns.",
                        "subtopics": [
                            {
                                "title": "Weather Systems",
                                "concepts": [
                                    {
                                        "title": "Air Masses and Fronts",
                                        "description": "Large-scale atmospheric structures and their boundaries.",
                                        "material_title": "Weather Systems",
                                        "material_content": "Air masses are large bodies of air with uniform temperature and moisture characteristics, classified by source region (maritime tropical, continental polar, etc.). Fronts are boundaries between air masses. Cold fronts bring sharp temperature drops and intense precipitation. Warm fronts bring gradual warming with steady rain. Occluded fronts form when a cold front overtakes a warm front. Low-pressure systems (cyclones) bring unsettled weather; high-pressure systems (anticyclones) bring clear skies.",
                                        "practices": [
                                            {
                                                "question": "What weather typically accompanies a cold front?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Gradual warming with light rain","B) Sharp temperature drop with intense storms","C) Clear skies and calm winds","D) Steady snowfall"]}',
                                                "answer": "B",
                                                "explanation": "Cold fronts push under warm air, forcing rapid uplift that produces intense but brief precipitation.",
                                            },
                                            {
                                                "question": "What is a low-pressure system associated with?",
                                                "type": "short_answer",
                                                "answer": "Cloudy skies, precipitation, and unsettled weather.",
                                                "explanation": "Air converges and rises at low-pressure centers, cooling and forming clouds and precipitation.",
                                            },
                                        ],
                                    }
                                ],
                            }
                        ],
                    }
                ],
            },
            {
                "title": "Oceanography",
                "slug": "oceanography",
                "description": "The study of the world's oceans.",
                "topics": [
                    {
                        "title": "Ocean Circulation",
                        "difficulty": "intermediate",
                        "description": "How water moves in the world's oceans.",
                        "subtopics": [
                            {
                                "title": "Thermohaline Circulation",
                                "concepts": [
                                    {
                                        "title": "The Global Ocean Conveyor Belt",
                                        "description": "Deep ocean circulation driven by temperature and salinity.",
                                        "material_title": "Thermohaline Circulation",
                                        "material_content": "Thermohaline circulation is driven by density differences from temperature (thermo) and salinity (haline). Cold, salty water sinks at high latitudes (North Atlantic, Antarctic) and flows along the ocean floor toward the equator. Surface currents return warm water poleward. This global conveyor belt takes about 1,000 years to complete a cycle, distributing heat around the planet and regulating climate. The Atlantic Meridional Overturning Circulation (AMOC) is a critical component.",
                                        "practices": [
                                            {
                                                "question": "What drives thermohaline circulation?",
                                                "type": "mcq",
                                                "options": '{"options":["A) Wind only","B) Tides","C) Density differences from temperature and salinity","D) Earth\'s rotation"]}',
                                                "answer": "C",
                                                "explanation": "Dense (cold, salty) water sinks and drives deep currents; less dense surface water flows poleward.",
                                            },
                                            {
                                                "question": "Why is the AMOC important for European climate?",
                                                "type": "short_answer",
                                                "answer": "It transports warm water from the tropics to the North Atlantic, warming Western Europe.",
                                                "explanation": "Without this heat transport, Northern Europe would be significantly colder.",
                                            },
                                        ],
                                    }
                                ],
                            }
                        ],
                    }
                ],
            },
            {
                "title": "Geophysics",
                "slug": "geophysics",
                "description": "Applying physics to study Earth's interior.",
                "topics": [
                    {
                        "title": "Seismology",
                        "difficulty": "advanced",
                        "description": "Studying earthquakes and Earth's interior structure.",
                        "subtopics": [
                            {
                                "title": "Seismic Waves",
                                "concepts": [
                                    {
                                        "title": "P-Waves, S-Waves, and Surface Waves",
                                        "description": "Different types of seismic energy propagation.",
                                        "material_title": "Seismic Wave Types",
                                        "material_content": "Primary waves (P-waves) are compressional, travel fastest, and pass through solids, liquids, and gases. Secondary waves (S-waves) are shear waves, slower than P-waves, and cannot pass through liquids. Surface waves (Love and Rayleigh waves) travel along Earth's surface, cause the most damage, and have the largest amplitude. The shadow zone (104-140 degrees from epicenter) revealed Earth's liquid outer core because S-waves cannot pass through it.",
                                        "practices": [
                                            {
                                                "question": "Why do S-waves not pass through Earth's outer core?",
                                                "type": "mcq",
                                                "options": '{"options":["A) They are too slow","B) The outer core is liquid and S-waves only travel through solids","C) They are absorbed by iron","D) They reflect back"]}',
                                                "answer": "B",
                                                "explanation": "S-waves are shear waves that require a rigid medium; the liquid outer core cannot transmit them.",
                                            },
                                            {
                                                "question": "How did seismologists determine that Earth's outer core is liquid?",
                                                "type": "short_answer",
                                                "answer": "S-waves are blocked by the outer core, creating a shadow zone that proves it is liquid.",
                                                "explanation": "The S-wave shadow zone between 104-140 degrees from the epicenter demonstrates the liquid core.",
                                            },
                                        ],
                                    }
                                ],
                            }
                        ],
                    }
                ],
            },
        ],
    },
]


async def seed_stem():

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with async_session() as db:
        result = await db.execute(select(STEMSubject).limit(1))
        if result.scalar_one_or_none():
            print("STEM already seeded")
            return

        counts = {
            "subjects": 0,
            "disciplines": 0,
            "topics": 0,
            "subtopics": 0,
            "concepts": 0,
            "materials": 0,
            "practices": 0,
        }

        for sd in SUBJECTS:
            subj = STEMSubject(
                title=sd["title"],
                subject_slug=sd["slug"],
                description=sd.get("description", ""),
                icon=sd.get("icon", ""),
                color=sd.get("color", ""),
            )
            db.add(subj)
            await db.flush()
            counts["subjects"] += 1

            for dd in sd.get("disciplines", []):
                disc = STEMDiscipline(
                    title=dd["title"],
                    discipline_slug=dd.get("slug", ""),
                    subject_id=subj.id,
                    description=dd.get("description", ""),
                )
                db.add(disc)
                await db.flush()
                counts["disciplines"] += 1

                for ti, td in enumerate(dd.get("topics", [])):
                    top = STEMTopic(
                        title=td["title"],
                        discipline_id=disc.id,
                        difficulty_level=td.get("difficulty", "intermediate"),
                        order_index=ti,
                        description=td.get("description", ""),
                    )
                    db.add(top)
                    await db.flush()
                    counts["topics"] += 1

                    for si, std in enumerate(td.get("subtopics", [])):
                        sub = STEMSubtopic(
                            title=std["title"],
                            topic_id=top.id,
                            difficulty_level=std.get("difficulty", td.get("difficulty", "intermediate")),
                            order_index=si,
                            description=std.get("description", ""),
                        )
                        db.add(sub)
                        await db.flush()
                        counts["subtopics"] += 1

                        for ci, cd in enumerate(std.get("concepts", [])):
                            con = STEMConcept(
                                title=cd["title"],
                                subtopic_id=sub.id,
                                description=cd.get("description", ""),
                                difficulty_level=cd.get("difficulty", std.get("difficulty", "intermediate")),
                                order_index=ci,
                            )
                            db.add(con)
                            await db.flush()
                            counts["concepts"] += 1

                            mat = STLearningMaterial(
                                title=cd.get("material_title", cd["title"]),
                                content=cd.get("material_content", ""),
                                material_type="text",
                                concept_id=con.id,
                            )
                            db.add(mat)
                            counts["materials"] += 1

                            for pd in cd.get("practices", []):
                                prac = STPractice(
                                    title=pd.get("title", pd["question"][:60]),
                                    question_text=pd["question"],
                                    question_type=pd["type"],
                                    options=pd.get("options"),
                                    answer=pd["answer"],
                                    explanation=pd.get("explanation", ""),
                                    difficulty=pd.get(
                                        "difficulty",
                                        cd.get("difficulty", "intermediate"),
                                    ),
                                    marks=1,
                                    concept_id=con.id,
                                )
                                db.add(prac)
                                counts["practices"] += 1

        await db.commit()
        print(f"STEM seeded: {counts}")


if __name__ == "__main__":
    asyncio.run(seed_stem())
