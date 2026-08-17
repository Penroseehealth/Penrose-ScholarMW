from pydantic import BaseModel


class KnowledgeLayerCreate(BaseModel):
    name: str
    layer_type: str
    institution_id: int | None = None
    faculty: str | None = None
    department: str | None = None
    course_id: int | None = None
    description: str | None = None
    priority: int = 0


class KnowledgeLayerResponse(BaseModel):
    id: int
    name: str
    layer_type: str
    institution_id: int | None = None
    faculty: str | None = None
    department: str | None = None
    course_id: int | None = None
    owner_id: int | None = None
    description: str | None = None
    is_active: bool
    priority: int

    model_config = {"from_attributes": True}


class KnowledgeDocumentCreate(BaseModel):
    layer_id: int
    title: str
    content: str | None = None
    doc_type: str
    tags: str | None = None


class KnowledgeDocumentResponse(BaseModel):
    id: int
    layer_id: int
    title: str
    content: str | None = None
    doc_type: str
    file_path: str | None = None
    tags: str | None = None
    is_indexed: bool
    uploaded_by: int | None = None

    model_config = {"from_attributes": True}


class InstitutionKnowledgeCreate(BaseModel):
    course_id: int
    title: str
    content: str
    doc_type: str
    access_level: str = "course"
    is_ai_exclusive: bool = False


class InstitutionKnowledgeResponse(BaseModel):
    id: int
    course_id: int
    title: str
    content: str
    doc_type: str
    access_level: str
    uploaded_by: int
    is_ai_exclusive: bool

    model_config = {"from_attributes": True}


class ContextQueryRequest(BaseModel):
    question: str
    course_id: int | None = None
    layer_type: str | None = None
    use_national: bool = True
    use_institutional: bool = True


class ContextQueryResponse(BaseModel):
    answer: str
    sources: list[str]
    layers_used: list[str]
