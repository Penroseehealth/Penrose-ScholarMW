from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class MapConfig(BaseModel):
    model_config = ConfigDict(extra="forbid")

    seed: int = 7
    hills: int = Field(default=3, ge=1, le=6)
    terrain: Literal["hills", "escarp", "uvalley", "mixed"] = "hills"
    complexity: int = Field(default=2, ge=1, le=3)
    interval: Literal[10, 20, 50] = 20
    scale: Literal[25000, 50000] = 50000
    view: Literal["split", "v2d", "v3d"] = "v2d"
    verticalExaggeration: float = Field(default=2, ge=1, le=6)
    reliefIntensity: float = Field(default=1, ge=0.4, le=1.8)
    palette: Literal["brown", "exam", "elevation", "earth", "teaching"] = "brown"
    indexColor: str = Field(default="#54351f", pattern=r"^#[0-9a-fA-F]{6}$")
    intermediateColor: str = Field(default="#986642", pattern=r"^#[0-9a-fA-F]{6}$")
    minorColor: str = Field(default="#c6a887", pattern=r"^#[0-9a-fA-F]{6}$")
    depressionColor: str = Field(default="#587985", pattern=r"^#[0-9a-fA-F]{6}$")
    labelColor: str = Field(default="#54351f", pattern=r"^#[0-9a-fA-F]{6}$")
    lineWidth: float = Field(default=1, ge=0.5, le=2.5)
    contourOpacity: float = Field(default=1, ge=0.25, le=1)
    contourEmphasis: float = Field(default=1.8, ge=1, le=2.5)
    showLabels: bool = True
    showGrid: bool = True
    showRefs: bool = True
    showDepressions: bool = True
    hillShading: bool = True
    surface: Literal["hypsometric", "monochrome"] = "hypsometric"
    printSize: Literal["a4", "a3"] = "a4"
    layers: dict[str, bool] = Field(
        default_factory=lambda: {
            "roads": True,
            "settlements": True,
            "landCover": True,
            "boundary": True,
            "rivers": True,
            "schools": True,
            "markets": True,
            "bridges": True,
            "boreholes": True,
            "woodland": True,
            "cultivation": True,
            "wetlands": True,
        }
    )


class MapGenerationRequest(BaseModel):
    config: MapConfig


class MapCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    config: MapConfig
    annotations: list[dict[str, Any]] = Field(default_factory=list)

    @field_validator("name")
    @classmethod
    def name_must_not_be_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Map name cannot be blank")
        return value


class MapRecord(MapCreate):
    id: str
    created_at: str
    updated_at: str


class MapSummary(BaseModel):
    id: str
    name: str
    config: MapConfig
    created_at: str
    updated_at: str


class MapGenerationResponse(BaseModel):
    config: MapConfig
    renderer: Literal["javascript-smartboard"] = "javascript-smartboard"


class PngExportRequest(BaseModel):
    data_url: str = Field(min_length=32, max_length=14_000_000)


class ExportResponse(BaseModel):
    id: str
    kind: Literal["png"]
    download_url: str
    created_at: str
