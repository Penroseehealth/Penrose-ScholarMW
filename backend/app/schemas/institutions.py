from pydantic import BaseModel


class InstitutionCreate(BaseModel):
    name: str
    short_name: str | None = None
    domain: str | None = None
    logo_url: str | None = None
    primary_color: str | None = None
    country: str = "Malawi"
    city: str | None = None


class InstitutionResponse(BaseModel):
    id: int
    name: str
    short_name: str | None = None
    domain: str | None = None
    logo_url: str | None = None
    primary_color: str | None = None
    country: str
    city: str | None = None
    is_active: bool

    model_config = {"from_attributes": True}


class InstitutionStatsResponse(BaseModel):
    institution_id: int
    user_count: int
    course_count: int
    active_students: int
