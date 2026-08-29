from datetime import datetime

from pydantic import BaseModel, EmailStr, computed_field

from app.models.models import UserRole


class UserCreate(BaseModel):
    email: EmailStr
    password: str
    full_name: str
    role: UserRole = UserRole.STUDENT
    institution: str | None = None
    department: str | None = None
    student_id: str | None = None
    year_of_study: int | None = None


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    id: int
    email: str
    full_name: str
    role: UserRole
    is_active: bool
    is_verified: bool
    avatar_url: str | None = None
    institution: str | None = None
    department: str | None = None
    student_id: str | None = None
    year_of_study: int | None = None
    created_at: datetime

    @computed_field
    @property
    def display_name(self) -> str:
        return self.full_name

    model_config = {"from_attributes": True}


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserResponse


class RefreshRequest(BaseModel):
    refresh_token: str


class PasswordChange(BaseModel):
    current_password: str
    new_password: str


class UserUpdate(BaseModel):
    full_name: str | None = None
    phone: str | None = None
    institution: str | None = None
    department: str | None = None
    avatar_url: str | None = None
