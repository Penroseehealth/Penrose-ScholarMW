from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select

from app.admin.router import router as admin_router
from app.ai_orchestrator.router import router as ai_orchestrator_router
from app.ai_tutor.router import router as ai_router
from app.analytics.router import router as analytics_router
from app.assessments.router import router as assessments_router
from app.auth.router import router as auth_router
from app.biology_viz.router import router as biology_viz_router
from app.chemistry.router import router as chem_syllabus_router
from app.chemistry.tutor_router import router as chemistry_tutor_router
from app.config.settings import get_settings
from app.context_engine.router import router as context_engine_router
from app.core.security import hash_password
from app.courses.router import router as courses_router
from app.database.engine import Base, async_session, engine
from app.examinations.router import router as examinations_router
from app.examinations_builder.router import router as examinations_builder_router
from app.gamification.router import router as gamification_router
from app.global_search.router import router as global_search_router
from app.institutions.router import router as institutions_router
from app.knowledge_retrieval.router import router as knowledge_retrieval_router
from app.knowledge_vault.router import router as vault_router
from app.languages.router import router as languages_router
from app.livekit.router import router as livekit_router
from app.malawi_context.router import router as malawi_context_router
from app.mathematics.router import router as math_syllabus_router
from app.mathematics.tutor_router import router as math_tutor_router
from app.messaging.router import router as messaging_router
from app.middleware.security import RateLimitMiddleware
from app.notifications.router import router as notifications_router
from app.ocr.router import router as ocr_router
from app.physics.router import router as phys_syllabus_router
from app.physics.tutor_router import router as physics_tutor_router
from app.practical.router import router as practical_router
from app.presentation.router import router as presentation_router
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
from app.stem.math_verify_router import router as math_verify_router
from app.stem.mock_exam_router import router as mock_exam_router
from app.stem.multimodal_router import router as multimodal_router
from app.stem.proctor_router import router as proctor_router
from app.stem.revision_router import router as revision_router
from app.stem.router import router as stem_router
from app.stem.study_planner_router import router as study_planner_router
from app.stem.subject_dashboard_router import router as subject_dashboard_router
from app.stem.syllabus_router import router as syllabus_router
from app.sync_engine.router import router as sync_engine_router
from app.users.router import router as users_router
from app.voice.router import router as voice_router
from app.writing_studio.router import router as writing_studio_router

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        from app.database.meta_migrations import run_meta_migrations

        await run_meta_migrations(conn)
    await _seed_default_users()
    from app.stem.seed import seed_stem

    await seed_stem()
    from app.stem.seed_phase2 import seed_phase2

    await seed_phase2()
    from app.stem.seed_phase3 import seed_phase3

    await seed_phase3()
    from app.stem.seed_expanded import seed_expanded

    await seed_expanded()
    from app.stem.seed_community import seed_community

    await seed_community()
    from app.stem.seed_syllabus import seed_syllabus

    await seed_syllabus()
    from app.mathematics.seed_math_syllabus import seed_math_syllabus

    await seed_math_syllabus()
    from app.chemistry.seed_chemistry import seed_chemistry_syllabus

    await seed_chemistry_syllabus()
    from app.physics.seed_physics import seed_physics_syllabus

    await seed_physics_syllabus()
    from app.languages.seed_english import seed_english

    await seed_english()
    from app.languages.seed_chinese import seed_chinese

    await seed_chinese()
    from app.languages.expand_hsk1 import expand_hsk1

    await expand_hsk1()
    from app.languages.seed_arabic import seed_arabic

    await seed_arabic()
    from app.agriculture.seed_agriculture import seed_agriculture

    await seed_agriculture()
    from app.agriculture.seed_agriculture_syllabus import seed_agriculture_syllabus

    await seed_agriculture_syllabus()
    from app.computer_science.seed_computer_studies_syllabus import (
        seed_computer_studies_syllabus,
    )

    await seed_computer_studies_syllabus()
    from app.livekit.agent_manager import voice_agent_host

    async with voice_agent_host():
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
                full_name="Mr. R. Asedi",
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
app.add_middleware(RateLimitMiddleware, requests_per_minute=60, requests_per_hour=500)

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
app.include_router(context_engine_router, prefix="/api/v1")
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
app.include_router(syllabus_router, prefix="/api/v1")
app.include_router(math_syllabus_router, prefix="/api/v1")
app.include_router(math_tutor_router, prefix="/api/v1")
app.include_router(math_verify_router, prefix="/api/v1")
app.include_router(multimodal_router, prefix="/api/v1")
app.include_router(chem_syllabus_router, prefix="/api/v1")
app.include_router(phys_syllabus_router, prefix="/api/v1")
app.include_router(physics_tutor_router, prefix="/api/v1")
app.include_router(chemistry_tutor_router, prefix="/api/v1")
app.include_router(languages_router, prefix="/api/v1")
app.include_router(livekit_router, prefix="/api/v1")
app.include_router(voice_router, prefix="/api/v1")
app.include_router(ocr_router, prefix="/api/v1")
app.include_router(practical_router, prefix="/api/v1")
app.include_router(biology_viz_router, prefix="/api/v1")
app.include_router(presentation_router, prefix="/api/v1")
app.include_router(examinations_builder_router, prefix="/api/v1")


@app.get("/health")
async def health():
    return {"status": "ok", "service": "Penrose ScholarMW"}


WEB_DIR = Path(__file__).resolve().parent.parent.parent / "frontend" / "build" / "web"
if WEB_DIR.is_dir():
    import hashlib
    import os
    import time

    from starlette.responses import FileResponse, HTMLResponse

    _main_js_path = WEB_DIR / "main.dart.js"
    _build_hash = hashlib.md5(
        str(os.path.getmtime(_main_js_path)).encode()
    ).hexdigest()[:12]
    _startup_version = str(int(time.time()))
    _no_cache_headers = {
        "Cache-Control": "no-cache, no-store, must-revalidate",
        "Pragma": "no-cache",
        "Expires": "0",
    }

    _index_html = (WEB_DIR / "index.html").read_text(encoding="utf-8")
    _index_html = _index_html.replace(
        "flutter_bootstrap.js", f"flutter_bootstrap.js?v={_build_hash}"
    )
    _index_html = _index_html.replace("main.dart.js", f"main.dart.js?v={_build_hash}")
    _index_html = _index_html.replace(
        "flutter_service_worker.js",
        f"flutter_service_worker.js?v={_startup_version}",
    )
    _bootstrap_js = (WEB_DIR / "flutter_bootstrap.js").read_text(encoding="utf-8")
    _bootstrap_js = _bootstrap_js.replace(
        "main.dart.js", f"main.dart.js?v={_build_hash}"
    )

    _NO_CACHE_MIME = {
        ".js": "application/javascript",
        ".css": "text/css",
        ".json": "application/json",
        ".woff2": "font/woff2",
        ".woff": "font/woff",
        ".ttf": "font/ttf",
        ".png": "image/png",
        ".svg": "image/svg+xml",
        ".ico": "image/x-icon",
    }

    @app.get("/{full_path:path}")
    async def serve_spa(full_path: str):
        file_path = WEB_DIR / full_path
        if full_path == "" or full_path == "index.html":
            return HTMLResponse(
                _index_html,
                headers=_no_cache_headers,
            )
        if full_path == "flutter_bootstrap.js":
            return HTMLResponse(
                _bootstrap_js,
                headers=_no_cache_headers,
            )
        if full_path == "flutter_service_worker.js":
            sw_code = (
                "self.addEventListener('install', function(e) {\n"
                "  self.skipWaiting();\n"
                "});\n"
                "self.addEventListener('activate', function(e) {\n"
                "  e.waitUntil(\n"
                "    caches.keys().then(function(names) {\n"
                "      return Promise.all(names.map(function(n) { return caches.delete(n); }));\n"
                "    }).then(function() { return self.registration.unregister(); })\n"
                "  );\n"
                "});\n"
                "self.addEventListener('fetch', function(e) {\n"
                "  e.respondWith(fetch(e.request, { cache: 'no-store' }));\n"
                "});\n"
            )
            return HTMLResponse(
                sw_code,
                headers=_no_cache_headers,
            )
        if file_path.is_file():
            return FileResponse(
                str(file_path),
                headers=_no_cache_headers,
            )
        return HTMLResponse(_index_html, headers=_no_cache_headers)
