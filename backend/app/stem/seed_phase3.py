import asyncio
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select

from app.database.engine import Base, async_session, engine
from app.models.stem import (
    STEMBadge,
    STEMChallenge,
    STEMCurriculumAlignment,
    STEMDailyProgress,
    STEMFlashcard,
    STEMLeaderboardEntry,
    STEMMalawiExample,
    STEMStudyPlan,
    STEMStudyPlanItem,
    STEMStudySession,
)

BADGES: list[dict] = [
    {
        "title": "First Steps",
        "category": "milestone",
        "points": 10,
        "icon": "emoji_events",
        "description": "Complete your first learning activity",
    },
    {
        "title": "Quick Learner",
        "category": "milestone",
        "points": 20,
        "icon": "speed",
        "description": "Complete 10 concepts in a single session",
    },
    {
        "title": "Week Warrior",
        "category": "streak",
        "points": 30,
        "icon": "local_fire_department",
        "description": "Study for 7 consecutive days",
    },
    {
        "title": "Month Master",
        "category": "streak",
        "points": 50,
        "icon": "military_tech",
        "description": "Study for 30 consecutive days",
    },
    {
        "title": "Century Club",
        "category": "streak",
        "points": 100,
        "icon": "stars",
        "description": "Study for 100 consecutive days",
    },
    {
        "title": "Quiz Champion",
        "category": "assessment",
        "points": 25,
        "icon": "quiz",
        "description": "Complete 50 assessment questions",
    },
    {
        "title": "Perfect Score",
        "category": "assessment",
        "points": 40,
        "icon": "grade",
        "description": "Score 100% on a practice test",
    },
    {
        "title": "Math Wizard",
        "category": "subject",
        "points": 30,
        "icon": "calculate",
        "description": "Master 20 mathematics concepts",
    },
    {
        "title": "Physics Pioneer",
        "category": "subject",
        "points": 30,
        "icon": "science",
        "description": "Master 20 physics concepts",
    },
    {
        "title": "Code Master",
        "category": "subject",
        "points": 30,
        "icon": "code",
        "description": "Master 20 computer science concepts",
    },
    {
        "title": "Lab Explorer",
        "category": "subject",
        "points": 25,
        "icon": "science",
        "description": "Complete 10 lab activities",
    },
    {
        "title": "Formulary Expert",
        "category": "knowledge",
        "points": 35,
        "icon": "functions",
        "description": "Memorise 30 formulae",
    },
    {
        "title": "Knowledge Seeker",
        "category": "knowledge",
        "points": 20,
        "icon": "menu_book",
        "description": "Review 100 flashcards",
    },
    {
        "title": "Team Player",
        "category": "social",
        "points": 15,
        "icon": "group",
        "description": "Join a study group",
    },
    {
        "title": "Malawi STEM Hero",
        "category": "achievement",
        "points": 50,
        "icon": "flag",
        "description": "Complete all Malawi context examples",
    },
]

CHALLENGES: list[dict] = [
    {
        "title": "Daily Warmup",
        "challenge_type": "daily",
        "points_reward": 10,
        "difficulty": "easy",
        "description": "Quick 5-question warmup to start your day",
    },
    {
        "title": "Speed Round",
        "challenge_type": "daily",
        "points_reward": 20,
        "difficulty": "medium",
        "description": "Answer 10 questions under time pressure",
    },
    {
        "title": "Weekly Challenge",
        "challenge_type": "weekly",
        "points_reward": 50,
        "difficulty": "medium",
        "description": "A comprehensive weekly assessment across all subjects",
    },
    {
        "title": "Concept Marathon",
        "challenge_type": "weekly",
        "points_reward": 75,
        "difficulty": "hard",
        "description": "Deep-dive into a single concept with 20 advanced questions",
    },
    {
        "title": "Monthly Mastery",
        "challenge_type": "monthly",
        "points_reward": 150,
        "difficulty": "hard",
        "description": "Demonstrate mastery across multiple topics in a monthly exam",
    },
    {
        "title": "STEM Olympiad",
        "challenge_type": "monthly",
        "points_reward": 200,
        "difficulty": "hard",
        "description": "Compete in the ultimate STEM challenge covering all disciplines",
    },
]

MALAWI_EXAMPLES: list[dict] = [
    {
        "concept_id": 1,
        "title": "Counting in Chichewa",
        "description": "Explore how numbers work in the Chichewa language, connecting natural number concepts to local counting systems used in Malawian markets and daily life.",
        "local_context": "Market vendors in Lilongwe use Chichewa numerals for everyday transactions. Understanding place value helps with counting mbeya (bags of maize) and change calculations.",
        "region": "Lilongwe",
        "real_world_application": "Used in village markets for trade, calculating change, and inventory management of farm produce.",
    },
    {
        "concept_id": 13,
        "title": "Force in Bicycle Transport",
        "description": "Apply Newton's Second Law (F=ma) to understand the forces acting on a cyclist riding along the M1 highway between Lilongwe and Blantyre.",
        "local_context": "Bicycles are a primary mode of transport in Malawi. Understanding force, mass, and acceleration helps cyclists navigate hilly terrain on the way to Mandala in Blantyre.",
        "region": "Blantyre",
        "real_world_application": "Optimising cargo load on bicycle taxis (dzadzitsa) and understanding braking distances on wet roads.",
    },
    {
        "concept_id": 22,
        "title": "Maize Storage Temperature",
        "description": "Use the heat transfer formula Q=mc*delta-T to model temperature changes in maize silos used for post-harvest storage in Malawi.",
        "local_context": "Smallholder farmers in Mangochi store maize in silos after harvest. Understanding heat transfer prevents spoilage and aflatoxin growth during the hot season.",
        "region": "Mangochi",
        "real_world_application": "Designing ventilated storage facilities and determining optimal conditions for long-term grain preservation.",
    },
    {
        "concept_id": 27,
        "title": "Lake Malawi Gas Laws",
        "description": "Apply the Ideal Gas Law (PV=nRT) to understand dissolved gases in Lake Malawi, the third-largest lake in Africa.",
        "local_context": "Fishermen on Lake Malawi in Mangochi notice fish behaviour changes with temperature and pressure. Gas solubility affects fish distribution and water quality.",
        "region": "Mangochi",
        "real_world_application": "Predicting fish catch locations based on atmospheric pressure and understanding dissolved oxygen levels for aquaculture.",
    },
    {
        "concept_id": 35,
        "title": "Population Growth in Malawi",
        "description": "Model Malawi's population growth using exponential and logistic growth equations, exploring carrying capacity in the context of national development.",
        "local_context": "Malawi's population has grown rapidly from 3.6 million in 1966 to over 20 million today. This example uses real census data from Zomba to model growth trends.",
        "region": "Zomba",
        "real_world_application": "Government planning for schools, hospitals, and food security based on projected population growth rates.",
    },
    {
        "concept_id": 37,
        "title": "Probability in Traditional Games",
        "description": "Analyse the probability and strategy in bao, a traditional mancala game popular across East and Southern Africa, including Malawi.",
        "local_context": "Bao is played in villages and towns across Malawi, including Mzuzu. Understanding probability of capturing seeds and optimal move sequences combines mathematics with cultural heritage.",
        "region": "Mzuzu",
        "real_world_application": "Game theory and strategic decision-making applicable to resource allocation and competitive reasoning.",
    },
    {
        "concept_id": 45,
        "title": "Crop Yield Regression",
        "description": "Use linear regression to model the relationship between rainfall, fertiliser use, and maize crop yield in Malawi's agricultural regions.",
        "local_context": "Agricultural extension officers in Kasungu use data-driven approaches to advise farmers on optimal fertiliser application rates based on historical yield data.",
        "region": "Kasungu",
        "real_world_application": "Predicting harvest yields for food security planning and optimising fertiliser input costs for smallholder farmers.",
    },
    {
        "concept_id": 154,
        "title": "Solar Panel Installation",
        "description": "Calculate optimal solar panel tilt angles using trigonometry and energy conversion principles for off-grid installations in rural Malawi.",
        "local_context": "Solar home systems are transforming rural life in Nkhotakota. Understanding angles of elevation and energy calculations helps technicians install panels for maximum efficiency.",
        "region": "Nkhotakota",
        "real_world_application": "Designing solar installations for schools, health centres, and homes in off-grid communities across Malawi.",
    },
    {
        "concept_id": 28,
        "title": "pH of Malawian Water",
        "description": "Measure and analyse the pH of water sources in southern Malawi, connecting acid-base chemistry to public health and water treatment.",
        "local_context": "Water quality testing in Phalombe district reveals variation in pH across boreholes and open wells. Understanding pH is critical for water purification and health.",
        "region": "Phalombe",
        "real_world_application": "Ensuring safe drinking water through pH monitoring, lime dosing for acidic wells, and quality control at treatment plants.",
    },
    {
        "concept_id": 180,
        "title": "Data Structures in Mobile Money",
        "description": "Explore how data structures (arrays, hash maps, linked lists) power Airtel Money and Mpamba mobile money platforms used across Malawi.",
        "local_context": "Mobile money transactions are processed millions of times daily in Malawi. Efficient data structures ensure fast lookup of user accounts and transaction histories in Blantyre's fintech hubs.",
        "region": "Blantyre",
        "real_world_application": "Designing efficient backend systems for mobile money platforms that serve millions of unbanked Malawians.",
    },
]

CURRICULUM_ALIGNMENTS: list[dict] = [
    {
        "concept_id": 1,
        "curriculum_name": "MSCE Mathematics Form 4",
        "syllabus_code": "MATH 401",
        "form_level": "Form 4",
        "exam_board": "MSCE",
        "learning_outcome": "Demonstrate understanding of natural numbers, integers, and number operations.",
    },
    {
        "concept_id": 13,
        "curriculum_name": "MSCE Physics Form 3",
        "syllabus_code": "PHY 302",
        "form_level": "Form 3",
        "exam_board": "MSCE",
        "learning_outcome": "Apply Newton's laws of motion to solve problems involving forces and acceleration.",
    },
    {
        "concept_id": 27,
        "curriculum_name": "MSCE Chemistry Form 4",
        "syllabus_code": "CHEM 401",
        "form_level": "Form 4",
        "exam_board": "MSCE",
        "learning_outcome": "Use the ideal gas law to solve problems relating to pressure, volume, and temperature of gases.",
    },
    {
        "concept_id": 35,
        "curriculum_name": "MSCE Biology Form 3",
        "syllabus_code": "BIO 301",
        "form_level": "Form 3",
        "exam_board": "MSCE",
        "learning_outcome": "Describe population growth models and factors affecting population size.",
    },
    {
        "concept_id": 45,
        "curriculum_name": "MSCE Mathematics Form 4",
        "syllabus_code": "MATH 403",
        "form_level": "Form 4",
        "exam_board": "MSCE",
        "learning_outcome": "Use statistical methods including regression to analyse real-world data sets.",
    },
    {
        "concept_id": 180,
        "curriculum_name": "MSCE Computer Studies Form 3",
        "syllabus_code": "CS 301",
        "form_level": "Form 3",
        "exam_board": "MSCE",
        "learning_outcome": "Describe and apply basic data structures including arrays, stacks, and queues.",
    },
    {
        "concept_id": 22,
        "curriculum_name": "MSCE Physics Form 4",
        "syllabus_code": "PHY 401",
        "form_level": "Form 4",
        "exam_board": "MSCE",
        "learning_outcome": "Explain the laws of heat transfer and apply calorimetry equations to real situations.",
    },
    {
        "concept_id": 37,
        "curriculum_name": "MSCE Mathematics Form 3",
        "syllabus_code": "MATH 302",
        "form_level": "Form 3",
        "exam_board": "MSCE",
        "learning_outcome": "Calculate theoretical and experimental probabilities of events.",
    },
]


async def seed_phase3():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with async_session() as db:
        count = await db.scalar(select(func.count()).select_from(STEMBadge))
        if count and count > 0:
            print("STEM Phase 3 data already exists. Skipping.")
            return

        user_row = await db.execute(select(func.min(STEMDailyProgress.user_id)))
        user_id = user_row.scalar_one_or_none()
        if user_id is None:
            from app.models.models import User

            user_row = await db.execute(select(func.min(User.id)))
            user_id = user_row.scalar_one_or_none()
        if user_id is None:
            print("No users found in DB. Cannot seed user-specific data.")
            return

        counts = {}

        for b in BADGES:
            db.add(STEMBadge(**b))
        counts["badges"] = len(BADGES)

        for c in CHALLENGES:
            db.add(STEMChallenge(**c))
        counts["challenges"] = len(CHALLENGES)

        for ex in MALAWI_EXAMPLES:
            db.add(STEMMalawiExample(**ex))
        counts["malawi_examples"] = len(MALAWI_EXAMPLES)

        for ca in CURRICULUM_ALIGNMENTS:
            db.add(STEMCurriculumAlignment(**ca))
        counts["curriculum_alignments"] = len(CURRICULUM_ALIGNMENTS)

        now = datetime.now(timezone.utc)

        sessions = [
            {
                "user_id": user_id,
                "subject_slug": "mathematics",
                "duration_minutes": 25,
                "activity_type": "study",
                "started_at": now - timedelta(days=2, hours=3),
                "ended_at": now - timedelta(days=2, hours=2, minutes=35),
            },
            {
                "user_id": user_id,
                "subject_slug": "physics",
                "duration_minutes": 45,
                "activity_type": "practice",
                "started_at": now - timedelta(days=1, hours=5),
                "ended_at": now - timedelta(days=1, hours=4, minutes=15),
            },
            {
                "user_id": user_id,
                "subject_slug": "computer-science",
                "duration_minutes": 60,
                "activity_type": "lab",
                "started_at": now - timedelta(hours=4),
                "ended_at": now - timedelta(hours=3),
            },
        ]
        for s in sessions:
            db.add(STEMStudySession(**s))
        counts["study_sessions"] = len(sessions)

        daily_data = []
        for i in range(14):
            date_str = (now - timedelta(days=13 - i)).strftime("%Y-%m-%d")
            daily_data.append(
                {
                    "user_id": user_id,
                    "date": date_str,
                    "concepts_reviewed": 3 + i * 2,
                    "concepts_mastered": i,
                    "practice_correct": 5 + i * 3,
                    "practice_total": 8 + i * 4,
                    "study_minutes": 15 + i * 5,
                    "streak_days": i + 1,
                }
            )
        for d in daily_data:
            db.add(STEMDailyProgress(**d))
        counts["daily_progress"] = len(daily_data)

        leaderboard_entries = [
            {
                "user_id": user_id,
                "subject_slug": "mathematics",
                "total_points": 300,
                "concepts_mastered": 25,
                "challenges_completed": 8,
                "current_streak": 14,
                "longest_streak": 14,
                "rank": 1,
            },
            {
                "user_id": user_id,
                "subject_slug": "physics",
                "total_points": 250,
                "concepts_mastered": 20,
                "challenges_completed": 6,
                "current_streak": 10,
                "longest_streak": 12,
                "rank": 2,
            },
            {
                "user_id": user_id,
                "subject_slug": "chemistry",
                "total_points": 200,
                "concepts_mastered": 15,
                "challenges_completed": 5,
                "current_streak": 7,
                "longest_streak": 9,
                "rank": 3,
            },
            {
                "user_id": user_id,
                "subject_slug": "biology",
                "total_points": 150,
                "concepts_mastered": 10,
                "challenges_completed": 3,
                "current_streak": 5,
                "longest_streak": 7,
                "rank": 4,
            },
            {
                "user_id": user_id,
                "subject_slug": "computer-science",
                "total_points": 100,
                "concepts_mastered": 8,
                "challenges_completed": 2,
                "current_streak": 3,
                "longest_streak": 5,
                "rank": 5,
            },
        ]
        for lb in leaderboard_entries:
            db.add(STEMLeaderboardEntry(**lb))
        counts["leaderboard_entries"] = len(leaderboard_entries)

        flashcards = [
            {
                "user_id": user_id,
                "concept_id": 1,
                "front": "What are the Chichewa numerals for 1-5?",
                "back": "1=modzi, 2=awiri, 3=atusatu, 4=anayi, 5=anu",
                "difficulty": "easy",
                "ease_factor": 2.5,
                "interval_days": 1,
                "review_count": 0,
            },
            {
                "user_id": user_id,
                "concept_id": 13,
                "front": "State Newton's Second Law.",
                "back": "F = ma (Force equals mass times acceleration)",
                "difficulty": "easy",
                "ease_factor": 2.6,
                "interval_days": 3,
                "review_count": 2,
            },
            {
                "user_id": user_id,
                "concept_id": 27,
                "front": "Write the Ideal Gas Law equation.",
                "back": "PV = nRT where P=pressure, V=volume, n=moles, R=gas constant, T=temperature",
                "difficulty": "medium",
                "ease_factor": 2.3,
                "interval_days": 5,
                "review_count": 4,
            },
            {
                "user_id": user_id,
                "concept_id": 35,
                "front": "What is the exponential growth formula?",
                "back": "dN/dt = rN where r is the intrinsic growth rate and N is population size",
                "difficulty": "medium",
                "ease_factor": 2.4,
                "interval_days": 4,
                "review_count": 3,
            },
            {
                "user_id": user_id,
                "concept_id": 45,
                "front": "What is the formula for the slope in simple linear regression?",
                "back": "beta_1 = sum((x_i - x_bar)(y_i - y_bar)) / sum((x_i - x_bar)^2)",
                "difficulty": "hard",
                "ease_factor": 2.1,
                "interval_days": 7,
                "review_count": 5,
            },
            {
                "user_id": user_id,
                "concept_id": 180,
                "front": "What is the time complexity of searching a hash map?",
                "back": "O(1) average case, O(n) worst case for collision resolution",
                "difficulty": "medium",
                "ease_factor": 2.5,
                "interval_days": 2,
                "review_count": 1,
            },
        ]
        for f in flashcards:
            f["next_review"] = now + timedelta(days=f["interval_days"])
            db.add(STEMFlashcard(**f))
        counts["flashcards"] = len(flashcards)

        plan1 = STEMStudyPlan(
            user_id=user_id,
            title="Mathematics Revision Plan",
            description="Structured revision of key MSCE Mathematics topics in preparation for final exams.",
            subject_slug="mathematics",
            target_date=now + timedelta(days=30),
            status="active",
            progress_pct=0.0,
        )
        db.add(plan1)
        await db.flush()

        plan1_items = [
            STEMStudyPlanItem(
                plan_id=plan1.id,
                concept_id=1,
                title="Natural Numbers and Number Systems",
                order_index=0,
            ),
            STEMStudyPlanItem(
                plan_id=plan1.id,
                concept_id=45,
                title="Linear Regression and Data Analysis",
                order_index=1,
            ),
            STEMStudyPlanItem(
                plan_id=plan1.id,
                concept_id=37,
                title="Probability and Statistics",
                order_index=2,
            ),
        ]
        for item in plan1_items:
            db.add(item)

        plan2 = STEMStudyPlan(
            user_id=user_id,
            title="Physics Exam Prep",
            description="Targeted preparation for MSCE Physics covering mechanics, heat, and electricity.",
            subject_slug="physics",
            target_date=now + timedelta(days=21),
            status="active",
            progress_pct=0.0,
        )
        db.add(plan2)
        await db.flush()

        plan2_items = [
            STEMStudyPlanItem(
                plan_id=plan2.id,
                concept_id=13,
                title="Newton's Laws and Force Analysis",
                order_index=0,
            ),
            STEMStudyPlanItem(
                plan_id=plan2.id,
                concept_id=22,
                title="Heat Transfer and Calorimetry",
                order_index=1,
            ),
            STEMStudyPlanItem(
                plan_id=plan2.id,
                concept_id=27,
                title="Gas Laws and Pressure",
                order_index=2,
            ),
        ]
        for item in plan2_items:
            db.add(item)

        counts["study_plans"] = 2
        counts["study_plan_items"] = 6

        await db.commit()
        print(f"STEM Phase 3 seeded: {counts}")


if __name__ == "__main__":
    asyncio.run(seed_phase3())
