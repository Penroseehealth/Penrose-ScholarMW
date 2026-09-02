from datetime import datetime

from pydantic import BaseModel


class ResearchProjectCreate(BaseModel):
    title: str
    description: str | None = None
    research_question: str | None = None
    methodology: str | None = None


class ResearchProjectResponse(BaseModel):
    id: int
    owner_id: int
    title: str
    description: str | None = None
    status: str
    research_question: str | None = None
    methodology: str | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class ResearchNoteCreate(BaseModel):
    title: str
    content: str
    note_type: str = "general"


class ResearchNoteResponse(BaseModel):
    id: int
    project_id: int
    title: str
    content: str
    note_type: str
    created_at: datetime

    model_config = {"from_attributes": True}


class LiteratureSearchRequest(BaseModel):
    query: str
    max_results: int = 10
    filters: dict | None = None


class LiteratureResult(BaseModel):
    title: str
    authors: str
    abstract: str
    year: int
    doi: str | None = None
    source: str
    relevance_score: float


class EvidenceExtraction(BaseModel):
    paper_title: str
    methodology: str
    sample_size: str | None = None
    key_findings: list[str]
    limitations: list[str]


class VaultDocumentUpload(BaseModel):
    title: str
    doc_type: str
    course_id: int | None = None
    tags: str | None = None


class VaultDocumentResponse(BaseModel):
    id: int
    title: str
    doc_type: str
    file_name: str | None = None
    file_size: int | None = None
    mime_type: str | None = None
    course_id: int | None = None
    uploaded_by: int
    is_indexed: bool
    tags: str | None = None
    content: str | None = None
    created_at: datetime

    model_config = {"from_attributes": True}
