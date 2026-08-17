from pydantic import BaseModel


class SearchResult(BaseModel):
    type: str
    id: int
    title: str
    subtitle: str | None = None
    url_path: str
    relevance: float = 0.0


class SearchResponse(BaseModel):
    query: str
    results: list[SearchResult]
    total: int
