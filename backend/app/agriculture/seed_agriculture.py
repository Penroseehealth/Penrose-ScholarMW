"""Seed Agriculture subject row — syllabus-ready, no hard-coded content."""

from sqlalchemy import select

from app.database.engine import async_session
from app.models.stem import STEMSubject


async def seed_agriculture():
    """Ensure the Agriculture STEMSubject row exists.

    The subject hierarchy (disciplines, topics, subtopics, concepts) will be
    populated later when the official MoEST syllabus is provided.
    """
    async with async_session() as session:
        existing = await session.execute(
            select(STEMSubject).where(STEMSubject.subject_slug == "agriculture")
        )
        if existing.scalar_one_or_none() is not None:
            return

        agri = STEMSubject(
            title="Agriculture",
            subject_slug="agriculture",
            description=(
                "Learn the science, practice, and technology of sustainable "
                "agricultural production. Covers crop science, soil management, "
                "livestock, agro-processing, and modern agricultural systems."
            ),
            icon="agriculture",
            color="#22C55E",
        )
        session.add(agri)
        await session.commit()
