from typing import Literal

from pydantic import BaseModel, Field


class Point(BaseModel):
    x: float
    y: float


class CalculationRequest(BaseModel):
    kind: Literal["distance", "bearing", "gradient", "grid_reference"]
    a: Point
    b: Point | None = None
    vertical_interval: float | None = None
    scale: int = Field(default=50000, gt=0)
    easting_origin: float = 30000
    northing_origin: float = 70000
    digits: Literal[4, 6] = 6


class CalculationResponse(BaseModel):
    kind: str
    result: dict[str, float | int | str]
