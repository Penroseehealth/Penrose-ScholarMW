"""Split CE5 'Nutrition in Humans' into 7 separate Form 1 topics in the database.

The official scope chart has these as separate Form 1 topics:
1. Nutrition in humans (food nutrients, substances, functions, food tests, sources)
2. Balanced diet
3. Deficiency diseases
4. Digestive system
5. Circulatory system
6. Anaemia
7. Worm infestations

Currently they are all bundled into one monolithic topic with 37 L.O.s.
"""
import asyncio
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy import text, select
from app.database.engine import async_session
from app.models.stem import (
    SyllabusTopic,
    SyllabusSubtopic,
    SyllabusLearningObjective,
    SyllabusResource,
)

async def main():
    async with async_session() as db:
        # Find the monolithic "Nutrition in Humans" topic (year_level=1, CE5)
        result = await db.execute(
            select(SyllabusTopic).where(
                SyllabusTopic.title == "Nutrition in Humans",
                SyllabusTopic.year_level == 1,
            )
        )
        topic = result.scalar_one_or_none()
        if not topic:
            print("ERROR: 'Nutrition in Humans' (Form 1) topic not found")
            return

        print(f"Found topic: id={topic.id}, title='{topic.title}', year_level={topic.year_level}")
        print(f"  core_element_id={topic.core_element_id}")

        # Get all subtopics with their learning objectives
        sub_result = await db.execute(
            select(SyllabusSubtopic).where(SyllabusSubtopic.topic_id == topic.id)
        )
        subtopics = sub_result.scalars().all()
        print(f"  subtopics: {len(subtopics)}")

        for st in subtopics:
            lo_result = await db.execute(
                select(SyllabusLearningObjective).where(
                    SyllabusLearningObjective.subtopic_id == st.id
                )
            )
            los = lo_result.scalars().all()
            print(f"    - '{st.title}' ({len(los)} L.O.s)")

        # Get resources
        res_result = await db.execute(
            select(SyllabusResource).where(SyllabusResource.topic_id == topic.id)
        )
        resources = res_result.scalars().all()
        print(f"  resources: {[r.resource_text for r in resources]}")

        # Delete all learning objectives
        for st in subtopics:
            await db.execute(
                text("DELETE FROM syllabus_learning_objectives WHERE subtopic_id = :sid"),
                {"sid": st.id}
            )
        # Delete all subtopics
        await db.execute(
            text("DELETE FROM syllabus_subtopics WHERE topic_id = :tid"),
            {"tid": topic.id}
        )
        # Delete all resources
        await db.execute(
            text("DELETE FROM syllabus_resources WHERE topic_id = :tid"),
            {"tid": topic.id}
        )
        # Delete the topic itself
        await db.execute(
            text("DELETE FROM syllabus_topics WHERE id = :tid"),
            {"tid": topic.id}
        )
        await db.commit()
        print("\nDeleted old monolithic topic.")

        # Now create 7 separate topics
        core_element_id = topic.core_element_id
        resources_nutrition = ["food samples", "test reagents (iodine, Benedict's, Biuret, Sudan III)", "charts", "diagrams"]
        resources_generic = ["charts", "diagrams", "textbooks"]

        new_topics = [
            {
                "title": "Nutrition in Humans",
                "year_level": 1,
                "subtopics": [
                    {
                        "title": "Food Nutrients and Substances",
                        "description": "Identifying food nutrients, food substances, their functions, common sources, and carrying out food tests.",
                        "los": [
                            ("identify food nutrients", "Application", "Discussion/Practical"),
                            ("identify food substances", "Application", "Discussion/Practical"),
                            ("describe the functions of different types of food nutrients", "Comprehension", "Discussion"),
                            ("carry out food tests for carbohydrates", "Application", "Discussion/Practical"),
                            ("carry out food tests for proteins", "Application", "Discussion/Practical"),
                            ("carry out food tests for lipids", "Application", "Discussion/Practical"),
                            ("identify common sources of food nutrients", "Application", "Discussion/Practical"),
                        ],
                    }
                ],
                "resources": resources_nutrition,
            },
            {
                "title": "Balanced Diet",
                "year_level": 1,
                "subtopics": [
                    {
                        "title": "Balanced Diet",
                        "description": "Defining balanced diet and designing a balanced diet.",
                        "los": [
                            ("define balanced diet", "Comprehension", "Discussion"),
                            ("design a balanced diet", "Application", "Discussion/Practical"),
                        ],
                    }
                ],
                "resources": ["food composition charts", "diet planning worksheets"],
            },
            {
                "title": "Deficiency Diseases",
                "year_level": 1,
                "subtopics": [
                    {
                        "title": "Deficiency Diseases",
                        "description": "Describing deficiency diseases: examples, causes, signs and symptoms, prevention, treatment, and obesity.",
                        "los": [
                            ("describe examples of deficiency diseases", "Comprehension", "Discussion"),
                            ("describe causes of deficiency diseases", "Comprehension", "Discussion"),
                            ("describe signs and symptoms of deficiency diseases", "Comprehension", "Discussion"),
                            ("describe prevention of deficiency diseases", "Comprehension", "Discussion"),
                            ("describe treatment of deficiency diseases", "Comprehension", "Discussion"),
                            ("describe causes of obesity", "Comprehension", "Discussion"),
                            ("describe ways of preventing obesity", "Comprehension", "Discussion"),
                        ],
                    }
                ],
                "resources": resources_generic,
            },
            {
                "title": "Digestive System",
                "year_level": 1,
                "subtopics": [
                    {
                        "title": "Digestive System",
                        "description": "Identifying parts of the human digestive tract, their functions, and the process of digestion.",
                        "los": [
                            ("identify parts of the human digestive tract", "Application", "Discussion/Practical"),
                            ("describe functions of parts of the human digestive tract", "Application", "Discussion/Practical"),
                            ("describe the process of digestion", "Comprehension", "Discussion"),
                            ("differentiate physical and chemical digestion", "Comprehension", "Discussion"),
                            ("identify enzymes involved in digestion", "Application", "Discussion/Practical"),
                            ("describe end products of digestion: amino acids, glucose, fatty acids, glycerol", "Comprehension", "Discussion"),
                        ],
                    }
                ],
                "resources": ["digestive system models", "charts", "diagrams"],
            },
            {
                "title": "Circulatory System",
                "year_level": 1,
                "subtopics": [
                    {
                        "title": "Circulatory System",
                        "description": "Identifying parts of the human circulatory system, the heart, blood vessels, blood composition, and their functions.",
                        "los": [
                            ("identify parts of the human circulatory system and their functions", "Application", "Discussion/Practical"),
                            ("describe the heart", "Application", "Discussion/Practical"),
                            ("differentiate arteries, veins, and capillaries", "Application", "Discussion/Practical"),
                            ("describe blood circulation", "Comprehension", "Discussion"),
                            ("identify composition of blood: plasma, blood cells, platelets", "Application", "Discussion/Practical"),
                            ("describe functions of components of blood", "Comprehension", "Discussion"),
                        ],
                    }
                ],
                "resources": ["heart models", "blood charts", "microscope slides"],
            },
            {
                "title": "Anaemia",
                "year_level": 1,
                "subtopics": [
                    {
                        "title": "Anaemia",
                        "description": "Describing anaemia: causes, signs and symptoms, prevention, and treatment.",
                        "los": [
                            ("describe causes of anaemia (worms, bleeding, lack of nutrients)", "Comprehension", "Discussion"),
                            ("describe signs and symptoms of anaemia", "Comprehension", "Discussion"),
                            ("describe prevention of anaemia", "Comprehension", "Discussion"),
                            ("describe treatment of anaemia", "Comprehension", "Discussion"),
                        ],
                    }
                ],
                "resources": resources_generic,
            },
            {
                "title": "Worm Infestations",
                "year_level": 1,
                "subtopics": [
                    {
                        "title": "Worm Infestations",
                        "description": "Identifying types of worms, their life cycles, modes of transmission, signs and symptoms, and prevention.",
                        "los": [
                            ("identify types of worms: roundworms, hookworms, tapeworms, threadworms, bilharzia worms", "Application", "Discussion/Practical"),
                            ("describe life cycles of worms", "Comprehension", "Discussion"),
                            ("describe modes of transmission of worms", "Comprehension", "Discussion"),
                            ("describe signs and symptoms of worm infestations", "Comprehension", "Discussion"),
                            ("describe preventive and control measures for worm infestations", "Comprehension", "Discussion"),
                        ],
                    }
                ],
                "resources": ["charts", "life cycle diagrams", "textbooks"],
            },
        ]

        ce_id = core_element_id
        for t_data in new_topics:
            t = SyllabusTopic(
                title=t_data["title"],
                year_level=t_data["year_level"],
                core_element_id=ce_id,
            )
            db.add(t)
            await db.commit()
            await db.refresh(t)

            for r_text in t_data["resources"]:
                db.add(SyllabusResource(topic_id=t.id, resource_text=r_text))
            await db.commit()

            for s_data in t_data["subtopics"]:
                s = SyllabusSubtopic(
                    topic_id=t.id,
                    title=s_data["title"],
                    description=s_data["description"],
                )
                db.add(s)
                await db.commit()
                await db.refresh(s)

                for obj, cog, method in s_data["los"]:
                    db.add(SyllabusLearningObjective(
                        subtopic_id=s.id,
                        objective=obj,
                        cognitive_level=cog,
                        teaching_method=method,
                    ))
                await db.commit()

            print(f"  Created: '{t.title}' (Form {t.year_level}, {len(t_data['subtopics'])} subtopics)")

        print(f"\nDone! Created 7 separate Form 1 topics for CE5 Human Biology.")

        # Verify
        result = await db.execute(
            select(SyllabusTopic).where(
                SyllabusTopic.core_element_id == ce_id,
                SyllabusTopic.year_level == 1,
            )
        )
        topics = result.scalars().all()
        print(f"\nVerification: CE5 now has {len(topics)} Form 1 topics:")
        for t in topics:
            print(f"  - {t.title} (id={t.id})")

if __name__ == "__main__":
    asyncio.run(main())
