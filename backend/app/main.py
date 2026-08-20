from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import select

from app.admin.router import router as admin_router
from app.ai_orchestrator.router import router as ai_orchestrator_router
from app.ai_tutor.router import router as ai_router
from app.analytics.router import router as analytics_router
from app.assessments.router import router as assessments_router
from app.auth.router import router as auth_router
from app.config.settings import get_settings
from app.core.security import hash_password
from app.courses.router import router as courses_router
from app.database.engine import Base, async_session, engine
from app.examinations.router import router as examinations_router
from app.gamification.router import router as gamification_router
from app.global_search.router import router as global_search_router
from app.institutions.router import router as institutions_router
from app.knowledge_retrieval.router import router as knowledge_retrieval_router
from app.knowledge_vault.router import router as vault_router
from app.malawi_context.router import router as malawi_context_router
from app.messaging.router import router as messaging_router
from app.notifications.router import router as notifications_router
from app.research.router import router as research_router
from app.smart_notifications.router import router as smart_notifications_router
from app.stem.adaptive_learning_router import router as adaptive_router
from app.stem.ai_stem_tutor_router import router as stem_tutor_router
from app.stem.analytics_router import router as stem_analytics_router
from app.stem.announcement_router import router as announcement_router
from app.stem.assessment_engine_router import router as assessment_engine_router
from app.stem.careers_router import router as careers_router
from app.stem.certificate_router import router as certificate_router
from app.stem.collaboration_router import router as collaboration_router
from app.stem.content_cms_router import router as content_cms_router
from app.stem.content_moderation_router import router as content_moderation_router
from app.stem.exam_analytics_router import router as exam_analytics_router
from app.stem.export_router import router as export_router
from app.stem.formulas_router import router as formulas_router
from app.stem.forum_router import router as forum_router
from app.stem.gamification_router import router as stem_gamification_router
from app.stem.group_session_router import router as group_session_router
from app.stem.groups_router import router as stem_groups_router
from app.stem.knowledge_graph_router import router as kg_router
from app.stem.labs_router import router as labs_router
from app.stem.malawi_stem_router import router as malawi_stem_router
from app.stem.mastery_router import router as mastery_router
from app.stem.mock_exam_router import router as mock_exam_router
from app.stem.proctor_router import router as proctor_router
from app.stem.revision_router import router as revision_router
from app.stem.router import router as stem_router
from app.stem.study_planner_router import router as study_planner_router
from app.stem.subject_dashboard_router import router as subject_dashboard_router
from app.sync_engine.router import router as sync_engine_router
from app.users.router import router as users_router
from app.writing_studio.router import router as writing_studio_router

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    await _seed_default_users()
    from app.stem.seed import seed_stem

    await seed_stem()
    from app.stem.seed_phase2 import seed_phase2

    await seed_phase2()
    from app.stem.seed_phase3 import seed_phase3

    await seed_phase3()
    from app.stem.seed_expanded import seed_expanded

    await seed_expanded()
    yield


async def _seed_default_users():
    from app.models.models import Course, Enrollment, User, UserRole

    async with async_session() as db:
        result = await db.execute(select(User).limit(1))
        if result.scalar_one_or_none():
            return

        users = [
            User(
                email="admin@scholar.mw",
                hashed_password=hash_password("admin123"),
                full_name="System Admin",
                role=UserRole.ADMIN,
                institution="University of Malawi",
                is_active=True,
                is_verified=True,
            ),
            User(
                email="lecturer@scholar.mw",
                hashed_password=hash_password("lecturer123"),
                full_name="Dr. Grace Mphatso",
                role=UserRole.LECTURER,
                institution="University of Malawi",
                department="Computer Science",
                is_active=True,
                is_verified=True,
            ),
            User(
                email="student@scholar.mw",
                hashed_password=hash_password("student123"),
                full_name="Chimwemwe Banda",
                role=UserRole.STUDENT,
                institution="University of Malawi",
                department="Computer Science",
                student_id="CS/2024/001",
                year_of_study=2,
                is_active=True,
                is_verified=True,
            ),
        ]
        db.add_all(users)
        await db.commit()

        for u in users:
            await db.refresh(u)

        course = Course(
            code="CS101",
            title="Introduction to Computer Science",
            description="Fundamentals of computing, algorithms, and programming.",
            level="Year 1",
            credits=3,
            semester="Semester 1",
            year=2025,
            lecturer_id=users[1].id,
            is_active=True,
        )
        db.add(course)
        await db.commit()
        await db.refresh(course)

        db.add(
            Enrollment(student_id=users[2].id, course_id=course.id, progress_pct=35.0)
        )
        await db.commit()


app = FastAPI(
    title="Penrose ScholarMW API",
    description="AI-Powered Academic Intelligence & Learning Platform for Malawi",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router, prefix="/api/v1")
app.include_router(users_router, prefix="/api/v1")
app.include_router(courses_router, prefix="/api/v1")
app.include_router(ai_router, prefix="/api/v1")
app.include_router(assessments_router, prefix="/api/v1")
app.include_router(research_router, prefix="/api/v1")
app.include_router(vault_router, prefix="/api/v1")
app.include_router(notifications_router, prefix="/api/v1")
app.include_router(admin_router, prefix="/api/v1")
app.include_router(messaging_router, prefix="/api/v1")
app.include_router(malawi_context_router, prefix="/api/v1")
app.include_router(analytics_router, prefix="/api/v1")
app.include_router(examinations_router, prefix="/api/v1")
app.include_router(writing_studio_router, prefix="/api/v1")
app.include_router(knowledge_retrieval_router, prefix="/api/v1")
app.include_router(sync_engine_router, prefix="/api/v1")
app.include_router(ai_orchestrator_router, prefix="/api/v1")
app.include_router(global_search_router, prefix="/api/v1")
app.include_router(gamification_router, prefix="/api/v1")
app.include_router(smart_notifications_router, prefix="/api/v1")
app.include_router(institutions_router, prefix="/api/v1")
app.include_router(stem_router, prefix="/api/v1")
app.include_router(kg_router, prefix="/api/v1")
app.include_router(formulas_router, prefix="/api/v1")
app.include_router(careers_router, prefix="/api/v1")
app.include_router(labs_router, prefix="/api/v1")
app.include_router(assessment_engine_router, prefix="/api/v1")
app.include_router(mastery_router, prefix="/api/v1")
app.include_router(revision_router, prefix="/api/v1")
app.include_router(stem_tutor_router, prefix="/api/v1")
app.include_router(stem_analytics_router, prefix="/api/v1")
app.include_router(malawi_stem_router, prefix="/api/v1")
app.include_router(stem_gamification_router, prefix="/api/v1")
app.include_router(stem_groups_router, prefix="/api/v1")
app.include_router(group_session_router, prefix="/api/v1")
app.include_router(adaptive_router, prefix="/api/v1")
app.include_router(mock_exam_router, prefix="/api/v1")
app.include_router(proctor_router, prefix="/api/v1")
app.include_router(certificate_router, prefix="/api/v1")
app.include_router(exam_analytics_router, prefix="/api/v1")
app.include_router(subject_dashboard_router, prefix="/api/v1")
app.include_router(study_planner_router, prefix="/api/v1")
app.include_router(forum_router, prefix="/api/v1")
app.include_router(announcement_router, prefix="/api/v1")
app.include_router(content_moderation_router, prefix="/api/v1")
app.include_router(content_cms_router, prefix="/api/v1")
app.include_router(collaboration_router, prefix="/api/v1")
app.include_router(export_router, prefix="/api/v1")


@app.get("/health")
async def health():
    return {"status": "ok", "service": "Penrose ScholarMW"}


WEB_DIR = Path(__file__).resolve().parent.parent.parent / "frontend" / "build" / "web"
if WEB_DIR.is_dir():
    assets_dir = WEB_DIR / "assets"
    if assets_dir.is_dir():
        app.mount("/assets", StaticFiles(directory=str(assets_dir)), name="assets")
    icons_dir = WEB_DIR / "icons"
    if icons_dir.is_dir():
        app.mount("/icons", StaticFiles(directory=str(icons_dir)), name="icons")

    from starlette.responses import FileResponse

    @app.get("/{full_path:path}")
    async def serve_spa(full_path: str):
        file_path = WEB_DIR / full_path
        if file_path.is_file():
            return FileResponse(str(file_path))
        return FileResponse(str(WEB_DIR / "index.html"))
