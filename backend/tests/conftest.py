from contextlib import asynccontextmanager

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.security import create_access_token, hash_password
from app.database.engine import Base, get_db
from app.models.models import User, UserRole

TEST_DATABASE_URL = "sqlite+aiosqlite:///./test.db"
test_engine = create_async_engine(TEST_DATABASE_URL, echo=False)
TestSessionLocal = async_sessionmaker(
    test_engine, class_=AsyncSession, expire_on_commit=False
)


async def override_get_db():
    async with TestSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()


@asynccontextmanager
async def lifespan_override(app):
    yield


app = None


@pytest.fixture(autouse=True)
async def setup_db():
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest.fixture
async def db_session():
    async with TestSessionLocal() as session:
        yield session


@pytest.fixture
def client():
    from app.main import app as real_app

    real_app.router.lifespan_context = lifespan_override
    real_app.dependency_overrides[get_db] = override_get_db
    transport = ASGITransport(app=real_app)
    return AsyncClient(transport=transport, base_url="http://test")


@pytest.fixture
async def student_user(db_session: AsyncSession):
    user = User(
        email="student@test.com",
        hashed_password=hash_password("TestPass1!"),
        full_name="Test Student",
        role=UserRole.STUDENT,
        institution="University of Malawi",
        department="Medicine",
        student_id="STU001",
        year_of_study=2,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
async def lecturer_user(db_session: AsyncSession):
    user = User(
        email="lecturer@test.com",
        hashed_password=hash_password("TestPass1!"),
        full_name="Dr. Test Lecturer",
        role=UserRole.LECTURER,
        institution="University of Malawi",
        department="Medicine",
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
async def admin_user(db_session: AsyncSession):
    user = User(
        email="admin@test.com",
        hashed_password=hash_password("TestPass1!"),
        full_name="Admin User",
        role=UserRole.ADMIN,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
def student_token(student_user):
    return create_access_token(
        {"sub": str(student_user.id), "role": student_user.role.value}
    )


@pytest.fixture
def lecturer_token(lecturer_user):
    return create_access_token(
        {"sub": str(lecturer_user.id), "role": lecturer_user.role.value}
    )


@pytest.fixture
def admin_token(admin_user):
    return create_access_token(
        {"sub": str(admin_user.id), "role": admin_user.role.value}
    )


def auth_header(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}
