"""Expanded seed data — adds depth to existing STEM subjects with MSCE-aligned concepts, more formulas, Malawi examples, curriculum alignments, and gamification content.

Run after seed.py and seed_phase2.py. Skips if data already exists."""

import asyncio
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import async_session
from app.models.stem import (
    KnowledgeGraphEdge,
    STEMBadge,
    STEMChallenge,
    STEMConcept,
    STEMCurriculumAlignment,
    STEMDiscipline,
    STEMFormula,
    STEMMalawiExample,
    STEMSubject,
    STEMSubtopic,
    STEMTopic,
    STMAssessmentQuestion,
)

# ── Phase 2 expanded: more formulas ──────────────────────────────

EXTRA_FORMULAS: list[dict[str, Any]] = [
    {
        "subject_slug": "mathematics",
        "title": "Pythagorean Theorem",
        "formula": "a^2 + b^2 = c^2",
        "description": "Relates sides of a right triangle.",
        "category": "Geometry",
        "variables": '{"a":"leg","b":"leg","c":"hypotenuse"}',
        "tags": "geometry,trigonometry",
    },
    {
        "subject_slug": "physics",
        "title": "Centripetal Acceleration",
        "formula": "a_c = \\frac{v^2}{r}",
        "description": "Acceleration toward center of circular motion.",
        "category": "Mechanics",
        "variables": '{"v":"velocity","r":"radius"}',
        "tags": "mechanics,circular motion",
    },
    {
        "subject_slug": "physics",
        "title": "Doppler Effect",
        "formula": "f' = f \\frac{v + v_o}{v - v_s}",
        "description": "Frequency change due to relative motion.",
        "category": "Waves",
        "variables": '{"f":"original frequency","v":"wave speed","v_o":"observer velocity","v_s":"source velocity"}',
        "tags": "waves,sound",
    },
    {
        "subject_slug": "chemistry",
        "title": "Nernst Equation",
        "formula": "E = E^0 - \\frac{0.0592}{n}\\log_{10} Q",
        "description": "Cell potential under non-standard conditions.",
        "category": "Electrochemistry",
        "variables": '{"E":"cell potential","E^0":"standard potential","n":"electrons transferred","Q":"reaction quotient"}',
        "tags": "electrochemistry,batteries",
    },
    {
        "subject_slug": "chemistry",
        "title": "Henderson-Hasselbalch Equation",
        "formula": "pH = pK_a + \\log_{10} \\frac{[A^-]}{[HA]}",
        "description": "Relates pH to pKa and buffer ratio.",
        "category": "Acids & Bases",
        "variables": '{"pK_a":"acid dissociation constant","[A^-]":"conjugate base concentration","[HA]":"acid concentration"}',
        "tags": "acids,bases,buffers",
    },
    {
        "subject_slug": "statistics",
        "title": "Standard Error of the Mean",
        "formula": "SE = \\frac{\\sigma}{\\sqrt{n}}",
        "description": "Standard deviation of sampling distribution.",
        "category": "Inferential Statistics",
        "variables": '{"\\sigma":"population standard deviation","n":"sample size"}',
        "tags": "statistics,sampling",
    },
    {
        "subject_slug": "statistics",
        "title": "Confidence Interval",
        "formula": "\\bar{x} \\pm Z \\frac{\\sigma}{\\sqrt{n}}",
        "description": "Range likely to contain population mean.",
        "category": "Inferential Statistics",
        "variables": '{"\\bar{x}":"sample mean","Z":"Z-score","\\sigma":"standard deviation","n":"sample size"}',
        "tags": "statistics,confidence intervals",
    },
    {
        "subject_slug": "agriculture",
        "title": "Crop Water Requirement",
        "formula": "ET_c = K_c \\times ETo",
        "description": "Crop evapotranspiration based on reference ET.",
        "category": "Water Management",
        "variables": '{"ET_c":"crop water requirement","K_c":"crop coefficient","ETo":"reference evapotranspiration"}',
        "tags": "irrigation,water,maize",
    },
    {
        "subject_slug": "agriculture",
        "title": "Fertilizer Application Rate",
        "formula": "FR = \\frac{R \\times 100}{N \\times A \\times B}",
        "description": "Calculates fertilizer amount per hectare.",
        "category": "Soil Science",
        "variables": '{"FR":"fertilizer rate","R":"nutrient recommendation","N":"nutrient content","A":"field area","B":"efficiency"}',
        "tags": "fertilizer,nutrients",
    },
    {
        "subject_slug": "computer-science",
        "title": "Big O — Binary Search",
        "formula": "O(\\log n)",
        "description": "Time complexity of binary search.",
        "category": "Algorithms",
        "variables": '{"n":"input size"}',
        "tags": "algorithms,complexity",
    },
    {
        "subject_slug": "computer-science",
        "title": "Big O — Bubble Sort",
        "formula": "O(n^2)",
        "description": "Time complexity of bubble sort (worst/average case).",
        "category": "Algorithms",
        "variables": '{"n":"input size"}',
        "tags": "algorithms,sorting,complexity",
    },
]

# ── Phase 2 expanded: more assessment questions ──────────────────

EXTRA_QUESTIONS: list[dict[str, Any]] = [
    {
        "question_text": "What is the pH of a solution with pKa = 4.7 and [A-]/[HA] ratio = 10?",
        "question_type": "mcq",
        "options": '{"options":["A) 3.7","B) 4.7","C) 5.7","D) 6.7"]}',
        "answer": "C",
        "explanation": "pH = 4.7 + log10(10) = 4.7 + 1 = 5.7",
        "bloom_level": "apply",
        "difficulty": "advanced",
        "marks": 2,
        "assessment_type": "formative",
    },
    {
        "question_text": "Explain how the Doppler effect causes the pitch of a siren to change as an ambulance passes you.",
        "question_type": "short_answer",
        "answer": "As the ambulance approaches, sound waves compress (higher frequency, higher pitch). As it moves away, waves stretch (lower frequency, lower pitch).",
        "explanation": "The Doppler effect: source motion changes observed frequency.",
        "bloom_level": "understand",
        "difficulty": "intermediate",
        "marks": 3,
        "assessment_type": "formative",
    },
    {
        "question_text": "A sample has a mean of 50 and standard deviation of 15. What is the standard error for a sample size of 25?",
        "question_type": "mcq",
        "options": '{"options":["A) 2.5","B) 3.0","C) 3.5","D) 4.0"]}',
        "answer": "B",
        "explanation": "SE = sigma/sqrt(n) = 15/5 = 3.0.",
        "bloom_level": "apply",
        "difficulty": "intermediate",
        "marks": 2,
        "assessment_type": "diagnostic",
    },
    {
        "question_text": "Why is the Reynolds number important in fluid mechanics?",
        "question_type": "short_answer",
        "answer": "It predicts whether flow will be laminar or turbulent, which affects pressure drop and heat transfer.",
        "explanation": "Re < 2000: laminar. Re > 4000: turbulent.",
        "bloom_level": "understand",
        "difficulty": "intermediate",
        "marks": 2,
        "assessment_type": "formative",
    },
]

# ── Phase 2 expanded: more knowledge graph edges ─────────────────

EXTRA_EDGES: list[dict[str, Any]] = [
    {
        "source_concept": "Solving One-Variable Linear Equations",
        "target_concept": "Centripetal Acceleration",
        "rel": "applied_in",
        "weight": 0.75,
        "desc": "Linear equations solve motion problems.",
    },
    {
        "source_concept": "Solving One-Variable Linear Equations",
        "target_concept": "Nernst Equation",
        "rel": "applied_in",
        "weight": 0.7,
        "desc": "Linear equations solve electrochemical problems.",
    },
    {
        "source_concept": "Solving One-Variable Linear Equations",
        "target_concept": "Standard Error",
        "rel": "foundational_for",
        "weight": 0.8,
        "desc": "Basic algebra underpins statistics.",
    },
    {
        "source_concept": "Solving One-Variable Linear Equations",
        "target_concept": "Ohm's Law",
        "rel": "applied_in",
        "weight": 0.85,
        "desc": "Ohm's law is a linear relationship.",
    },
    {
        "source_concept": "Solving One-Variable Linear Equations",
        "target_concept": "Crop Water Requirement",
        "rel": "applied_in",
        "weight": 0.6,
        "desc": "Linear equations model irrigation needs.",
    },
    {
        "source_concept": "Solving One-Variable Linear Equations",
        "target_concept": "Confidence Interval",
        "rel": "foundational_for",
        "weight": 0.82,
        "desc": "Algebra is prerequisite for inferential stats.",
    },
]

# ── Phase 3B: More Malawi examples ────────────────────────────────

EXTRA_MALAWI_EXAMPLES: list[dict[str, Any]] = [
    {
        "concept": "Solving One-Variable Linear Equations",
        "title": "Market Trading Calculations",
        "desc": "Calculate profit margins when buying/selling in local markets.",
        "context": "At Lilongwe Old Market, a vendor buys 100kg maize at MWK 150/kg and sells at MWK 180/kg. What is the profit percentage?",
        "region": "Lilongwe",
        "app": "Business math for market vendors.",
    },
    {
        "concept": "Solving One-Variable Linear Equations",
        "title": "Mobile Money Transactions",
        "desc": "Using equations to track Airtel Money balances.",
        "context": "After sending MWK 5000 and receiving MWK 8000, the balance is MWK 12000. What was the original balance?",
        "region": "Blantyre",
        "app": "Financial literacy for mobile money users.",
    },
    {
        "concept": "Solving One-Variable Linear Equations",
        "title": "Bicycle Transport Costs",
        "desc": "Calculating transport fares using linear equations.",
        "context": "A bicycle taxi charges MWK 500 for the first km and MWK 200 for each additional km. How much for a 5km trip?",
        "app": "Transport economics (dzadzitsa).",
    },
    {
        "concept": "Solving One-Variable Linear Equations",
        "title": "Tailoring Measurements",
        "desc": "Calculating fabric requirements for traditional clothing.",
        "context": "A tailor needs fabric for 30 cmkopo (wrapper skirts). Each needs 2.5m fabric. How much total?",
        "region": "Mzuzu",
        "app": "Local fashion and textile industry.",
    },
    {
        "concept": "Solving One-Variable Linear Equations",
        "title": "Maize Meal Distribution",
        "desc": "Calculating how many people a bag of maize can feed.",
        "context": "One 50kg bag makes 250 portions. How many bags needed for 100 families of 5?",
        "region": "Kasungu",
        "app": "Food security planning.",
    },
    {
        "concept": "Solving One-Variable Linear Equations",
        "title": "Solar Panel Payments",
        "desc": "Installment calculation for off-grid solar systems.",
        "context": "Solar home system costs MWK 15000. With 10% deposit and monthly installments of MWK 1500, how long to pay off?",
        "region": "Nkhotakota",
        "app": "Renewable energy financing.",
    },
]

# ── Phase 3B: More curriculum alignments ──────────────────────────

EXTRA_ALIGNMENTS: list[dict[str, Any]] = [
    {
        "concept": "Solving One-Variable Linear Equations",
        "curriculum": "MSCE Mathematics",
        "code": "MATH 402",
        "form": "Form 4",
        "board": "MSCE",
        "outcome": "Solve linear equations in one variable (MSCE Paper 2, Q12)",
    },
    {
        "concept": "Solving One-Variable Linear Equations",
        "curriculum": "MSCE Mathematics",
        "code": "MATH 302",
        "form": "Form 3",
        "board": "MSCE",
        "outcome": "Solve simple linear equations (MSCE Paper 1, Q8)",
    },
    {
        "concept": "Probability & Statistics",
        "curriculum": "MSCE Mathematics",
        "code": "MATH 403",
        "form": "Form 4",
        "board": "MSCE",
        "outcome": "Calculate mean, median, mode and interpret frequency tables",
    },
    {
        "concept": "Geometry & Trigonometry",
        "curriculum": "MSCE Mathematics",
        "code": "MATH 405",
        "form": "Form 4",
        "board": "MSCE",
        "outcome": "Apply Pythagoras theorem and trigonometric ratios to solve real problems",
    },
    {
        "concept": "Algebra",
        "curriculum": "MSCE Mathematics",
        "code": "MATH 401",
        "form": "Form 4",
        "board": "MSCE",
        "outcome": "Factorize quadratic expressions and solve quadratic equations",
    },
    {
        "concept": "Mensuration",
        "curriculum": "MSCE Mathematics",
        "code": "MATH 406",
        "form": "Form 4",
        "board": "MSCE",
        "outcome": "Calculate surface area and volume of solids (cylinders, cones, spheres)",
    },
    {
        "concept": "Newton's Laws",
        "curriculum": "MSCE Physics",
        "code": "PHY 401",
        "form": "Form 4",
        "board": "MSCE",
        "outcome": "Apply Newton's second law F=ma to solve motion problems",
    },
    {
        "concept": "Electricity & Magnetism",
        "curriculum": "MSCE Physics",
        "code": "PHY 402",
        "form": "Form 4",
        "board": "MSCE",
        "outcome": "Apply Ohm's law and solve series/parallel circuit problems",
    },
    {
        "concept": "Optics",
        "curriculum": "MSCE Physics",
        "code": "PHY 403",
        "form": "Form 4",
        "board": "MSCE",
        "outcome": "Use lens formula 1/f = 1/u + 1/v for refraction at curved surfaces",
    },
    {
        "concept": "Atomic Structure",
        "curriculum": "MSCE Chemistry",
        "code": "CHEM 301",
        "form": "Form 3",
        "board": "MSCE",
        "outcome": "Describe the Bohr model and write electron configurations",
    },
    {
        "concept": "Chemical Bonding",
        "curriculum": "MSCE Chemistry",
        "code": "CHEM 302",
        "form": "Form 3",
        "board": "MSCE",
        "outcome": "Predict bond type (ionic/covalent) based on electronegativity difference",
    },
    {
        "concept": "Acids & Bases",
        "curriculum": "MSCE Chemistry",
        "code": "CHEM 401",
        "form": "Form 4",
        "board": "MSCE",
        "outcome": "Calculate pH and pOH from concentration",
    },
    {
        "concept": "Cell Biology",
        "curriculum": "MSCE Biology",
        "code": "BIO 301",
        "form": "Form 3",
        "board": "MSCE",
        "outcome": "Compare prokaryotic and eukaryotic cells using a light microscope",
    },
    {
        "concept": "Genetics",
        "curriculum": "MSCE Biology",
        "code": "BIO 401",
        "form": "Form 4",
        "board": "MSCE",
        "outcome": "Apply Mendel's laws to predict inheritance patterns",
    },
    {
        "concept": "Ecology",
        "curriculum": "MSCE Biology",
        "code": "BIO 402",
        "form": "Form 4",
        "board": "MSCE",
        "outcome": "Construct ecological pyramids and explain nutrient cycling",
    },
    {
        "concept": "Programming",
        "curriculum": "MSCE Computer Studies",
        "code": "CS 301",
        "form": "Form 3",
        "board": "MSCE",
        "outcome": "Write BASIC or Python programs using selection and iteration constructs",
    },
]

# ── Phase 4: More badges ──────────────────────────────────────────

EXTRA_BADGES: list[dict[str, Any]] = [
    {
        "title": "Geography Guru",
        "category": "subject",
        "points": 35,
        "icon": "public",
        "description": "Master 15 geography/environmental science concepts",
    },
    {
        "title": "Agri Champion",
        "category": "subject",
        "points": 30,
        "icon": "agriculture",
        "description": "Master 15 agriculture concepts",
    },
    {
        "title": "Night Owl",
        "category": "streak",
        "points": 20,
        "icon": "nightlight",
        "description": "Study after 10 PM for 5 consecutive nights",
    },
    {
        "title": "Speed Demon",
        "category": "assessment",
        "points": 25,
        "icon": "flash_on",
        "description": "Complete a 10-question quiz in under 2 minutes",
    },
    {
        "title": "Social Butterfly",
        "category": "social",
        "points": 15,
        "icon": "groups_2",
        "description": "Join 3 study groups",
    },
    {
        "title": "Perfect Week",
        "category": "streak",
        "points": 40,
        "icon": "calendar_today",
        "description": "Study every day for 7 days without missing one",
    },
    {
        "title": "Question Master",
        "category": "assessment",
        "points": 30,
        "icon": "quiz",
        "description": "Answer 50 practice questions correctly",
    },
    {
        "title": "Knowledge Connector",
        "category": "knowledge",
        "points": 35,
        "icon": "account_tree",
        "description": "Make 10 cross-subject knowledge connections",
    },
]

# ── Phase 4: More challenges ─────────────────────────────────────

EXTRA_CHALLENGES: list[dict[str, Any]] = [
    {
        "title": "Daily Equation",
        "description": "Solve one equation every day for a week.",
        "challenge_type": "daily",
        "subject_slug": "mathematics",
        "points_reward": 50,
        "difficulty": "easy",
    },
    {
        "title": "Science Quiz Bowl",
        "description": "Complete 5 mixed-science assessments this week.",
        "challenge_type": "weekly",
        "points_reward": 100,
        "difficulty": "medium",
    },
    {
        "title": "MSCE Prep Sprint",
        "description": "Complete 20 MSCE-level questions in 30 minutes.",
        "challenge_type": "monthly",
        "points_reward": 200,
        "difficulty": "hard",
    },
    {
        "title": "Lab Week",
        "description": "Complete 3 virtual lab activities this week.",
        "challenge_type": "weekly",
        "subject_slug": "physics",
        "points_reward": 75,
        "difficulty": "medium",
    },
]


async def _seed_extra_formulas(db: AsyncSession) -> int:
    existing_titles = {row[0] for row in await db.execute(select(STEMFormula.title))}
    added = 0
    for f in EXTRA_FORMULAS:
        if f["title"] in existing_titles:
            continue
        formula = STEMFormula(
            subject_slug=f["subject_slug"],
            title=f["title"],
            formula=f["formula"],
            description=f["description"],
            category=f["category"],
            variables=f["variables"],
            tags=f["tags"],
        )
        db.add(formula)
        added += 1
    return added


async def _seed_extra_questions(db: AsyncSession) -> int:
    count = await db.scalar(select(func.count(STMAssessmentQuestion.id))) or 0
    added = 0
    for q in EXTRA_QUESTIONS:
        # Try to find a concept to attach to
        if count > 0:
            concept = await db.scalar(
                select(STEMConcept).where(STEMConcept.title == "Solving One-Variable Linear Equations")
            )
            if concept is None:
                concept = await db.scalar(select(STEMConcept))
        else:
            concept = await db.scalar(
                select(STEMConcept).where(STEMConcept.title == "Solving One-Variable Linear Equations")
            )
        if concept:
            question = STMAssessmentQuestion(
                concept_id=concept.id,
                question_text=q["question_text"],
                question_type=q["question_type"],
                options=q.get("options"),
                answer=q["answer"],
                explanation=q["explanation"],
                bloom_level=q["bloom_level"],
                difficulty=q["difficulty"],
                marks=q["marks"],
                assessment_type=q["assessment_type"],
            )
            db.add(question)
            added += 1
    return added


async def _seed_extra_malawi_examples(db: AsyncSession) -> int:
    concept = await db.scalar(select(STEMConcept).where(STEMConcept.title == "Solving One-Variable Linear Equations"))
    if not concept:
        return 0

    existing_titles = {row[0] for row in await db.execute(select(STEMMalawiExample.title))}
    added = 0
    for ex in EXTRA_MALAWI_EXAMPLES:
        if ex["title"] in existing_titles:
            continue
        example = STEMMalawiExample(
            concept_id=concept.id,
            title=ex["title"],
            description=ex["desc"],
            local_context=ex.get("context", ""),
            region=ex.get("region", ""),
            real_world_application=ex.get("app", ""),
        )
        db.add(example)
        added += 1
    return added


async def _seed_extra_alignments(db: AsyncSession) -> int:
    concept = await db.scalar(select(STEMConcept).where(STEMConcept.title == "Solving One-Variable Linear Equations"))

    # Also create alignments for other key concepts if they exist
    algebra_concepts = await db.execute(
        select(STEMConcept)
        .join(STEMSubtopic, STEMConcept.subtopic_id == STEMSubtopic.id)
        .join(STEMTopic, STEMSubtopic.topic_id == STEMTopic.id)
        .join(STEMDiscipline, STEMTopic.discipline_id == STEMDiscipline.id)
        .join(STEMSubject, STEMDiscipline.subject_id == STEMSubject.id)
        .where(STEMSubject.subject_slug.in_(["mathematics", "physics", "chemistry", "biology", "computer-science"]))
    )
    all_concepts = algebra_concepts.scalars().all()
    existing_codes = {
        row[0]
        for row in await db.execute(
            select(STEMCurriculumAlignment.syllabus_code).where(STEMCurriculumAlignment.syllabus_code.is_not(None))
        )
    }

    added = 0
    for align in EXTRA_ALIGNMENTS:
        if align["code"] in existing_codes:
            continue
        target_concept = concept if align["concept"] == "Solving One-Variable Linear Equations" else None
        if not target_concept and all_concepts:
            # Assign alignment to any concept from matching subject
            target_concept = all_concepts[added % len(all_concepts)]

        if target_concept:
            alignment = STEMCurriculumAlignment(
                concept_id=target_concept.id,
                curriculum_name=align["curriculum"],
                syllabus_code=align["code"],
                form_level=align["form"],
                exam_board=align["board"],
                learning_outcome=align["outcome"],
            )
            db.add(alignment)
            added += 1
    return added


async def _seed_extra_badges(db: AsyncSession) -> int:
    existing_titles = {row[0] for row in await db.execute(select(STEMBadge.title))}
    added = 0
    for b in EXTRA_BADGES:
        if b["title"] in existing_titles:
            continue
        badge = STEMBadge(
            title=b["title"],
            description=b["description"],
            icon=b["icon"],
            category=b["category"],
            points=b["points"],
        )
        db.add(badge)
        added += 1
    return added


async def _seed_extra_challenges(db: AsyncSession) -> int:
    existing_titles = {row[0] for row in await db.execute(select(STEMChallenge.title))}
    added = 0
    for c in EXTRA_CHALLENGES:
        if c["title"] in existing_titles:
            continue
        challenge = STEMChallenge(
            title=c["title"],
            description=c["description"],
            challenge_type=c["challenge_type"],
            subject_slug=c.get("subject_slug"),
            points_reward=c["points_reward"],
            difficulty=c["difficulty"],
            is_active=True,
        )
        db.add(challenge)
        added += 1
    return added


async def _seed_extra_knowledge_edges(db: AsyncSession) -> int:
    """Add cross-subject knowledge graph edges for 'Solving One-Variable Linear Equations' concept."""
    linear_concept = await db.scalar(
        select(STEMConcept).where(STEMConcept.title == "Solving One-Variable Linear Equations")
    )
    if not linear_concept:
        linear_concept = await db.scalar(select(STEMConcept))

    if not linear_concept:
        return 0

    # Find target concepts by partial title matching
    target_titles = {
        "Centripetal Acceleration": "physics",
        "Nernst Equation": "chemistry",
        "Standard Error": "statistics",
        "Ohm's Law": "engineering",
        "Crop Water Requirement": "agriculture",
        "Confidence Interval": "statistics",
    }

    added = 0
    for title, subject in target_titles.items():
        target = await db.scalar(select(STEMConcept).where(STEMConcept.title == title))
        if target and target.id != linear_concept.id:
            existing = await db.scalar(
                select(KnowledgeGraphEdge).where(
                    KnowledgeGraphEdge.source_concept_id == linear_concept.id,
                    KnowledgeGraphEdge.target_concept_id == target.id,
                )
            )
            if not existing:
                edge = KnowledgeGraphEdge(
                    source_concept_id=linear_concept.id,
                    target_concept_id=target.id,
                    relationship_type="applied_in",
                    weight=0.75,
                    description=f"Linear equations are used to solve {subject} problems.",
                )
                db.add(edge)
                added += 1
    return added


async def seed_expanded() -> None:
    """Add expanded content. Each sub-section has its own skip logic."""
    async with async_session() as db:
        counts = {
            "formulas": 0,
            "questions": 0,
            "malawi_examples": 0,
            "alignments": 0,
            "badges": 0,
            "challenges": 0,
            "knowledge_edges": 0,
        }

        counts["formulas"] = await _seed_extra_formulas(db)
        counts["questions"] = await _seed_extra_questions(db)
        counts["malawi_examples"] = await _seed_extra_malawi_examples(db)
        counts["alignments"] = await _seed_extra_alignments(db)
        counts["badges"] = await _seed_extra_badges(db)
        counts["challenges"] = await _seed_extra_challenges(db)
        counts["knowledge_edges"] = await _seed_extra_knowledge_edges(db)

        await db.commit()
        print(f"Expanded STEM data seeded: {counts}")


async def seed_expanded_standalone() -> None:
    """Standalone seeding for direct execution."""
    await seed_expanded()


if __name__ == "__main__":
    asyncio.run(seed_expanded_standalone())
