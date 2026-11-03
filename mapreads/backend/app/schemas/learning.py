from typing import Literal

from pydantic import BaseModel, Field


class QuestionGenerationRequest(BaseModel):
    map_id: str | None = None
    level: Literal["basic", "intermediate", "advanced", "msce"] = "msce"
    seed: int = 1


class TeachingAssistanceRequest(BaseModel):
    prompt: str = Field(min_length=1, max_length=4000)
    map_id: str | None = None
