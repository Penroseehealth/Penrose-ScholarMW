import asyncio

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.security import create_access_token, hash_password
from app.database.engine import Base, get_db
from app.main import app
from app.models.models import User, UserRole

TEST_DATABASE_URL = "sqlite:///./test.db"
engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(autouse=True)
def setup_db():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def db_session():
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture
def client():
    transport = ASGITransport(app=app)
    return AsyncClient(transport=transport, base_url="http://test")


@pytest.fixture
def student_user(db_session: Session):
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
    db_session.commit()
    db_session.refresh(user)
    return user


@pytest.fixture
def lecturer_user(db_session: Session):
    user = User(
        email="lecturer@test.com",
        hashed_password=hash_password("TestPass1!"),
        full_name="Dr. Test Lecturer",
        role=UserRole.LECTURER,
        institution="University of Malawi",
        department="Medicine",
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


@pytest.fixture
def admin_user(db_session: Session):
    user = User(
        email="admin@test.com",
        hashed_password=hash_password("TestPass1!"),
        full_name="Admin User",
        role=UserRole.ADMIN,
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
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
