from pydantic import BaseModel


class WritingProjectCreate(BaseModel):
    title: str
    project_type: str = "essay"


class WritingProjectResponse(BaseModel):
    id: int
    owner_id: int
    title: str
    project_type: str
    status: str
    created_at: str

    model_config = {"from_attributes": True}


class WritingSectionCreate(BaseModel):
    title: str
    section_type: str
    content: str | None = None
    order: int = 0


class WritingSectionResponse(BaseModel):
    id: int
    project_id: int
    title: str
    section_type: str
    content: str | None = None
    order: int
    word_count: int
    ai_suggestions: str | None = None

    model_config = {"from_attributes": True}


class WritingAssistRequest(BaseModel):
    section_id: int
    action: str  # improve_grammar, improve_tone, suggest_structure, identify_gaps, paraphrase
    content: str | None = None


class WritingAssistResponse(BaseModel):
    suggestions: list[str]
    improved_text: str | None = None
    analysis: str | None = None


class ReferenceCollectionCreate(BaseModel):
    name: str
    description: str | None = None


class ReferenceCollectionResponse(BaseModel):
    id: int
    owner_id: int
    name: str
    description: str | None = None

    model_config = {"from_attributes": True}


class CitationCreate(BaseModel):
    collection_id: int
    title: str
    authors: str | None = None
    year: int | None = None
    doi: str | None = None
    journal: str | None = None
    volume: str | None = None
    pages: str | None = None
    url: str | None = None
    citation_style: str | None = None
    tags: str | None = None
    notes: str | None = None


class CitationResponse(BaseModel):
    id: int
    collection_id: int
    title: str
    authors: str | None = None
    year: int | None = None
    doi: str | None = None
    journal: str | None = None
    volume: str | None = None
    pages: str | None = None
    url: str | None = None
    citation_style: str | None = None
    tags: str | None = None
    notes: str | None = None

    model_config = {"from_attributes": True}


class BibliographyGenerateRequest(BaseModel):
    collection_id: int
    style: str = "apa"  # apa, vancouver, harvard, mla


class BibliographyGenerateResponse(BaseModel):
    entries: list[str]
    style: str
    count: int
