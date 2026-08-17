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
from app.sync_engine.router import router as sync_engine_router
from app.users.router import router as users_router
from app.writing_studio.router import router as writing_studio_router

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    await _seed_default_users()
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
