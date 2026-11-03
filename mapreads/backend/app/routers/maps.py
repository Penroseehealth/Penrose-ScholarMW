from fastapi import APIRouter
from fastapi.responses import Response

from ..schemas.maps import (
    ExportResponse,
    MapCreate,
    MapGenerationRequest,
    MapGenerationResponse,
    MapRecord,
    MapSummary,
    PngExportRequest,
)
from ..services import map_library


router = APIRouter(prefix="/api/maps", tags=["maps"])
exports_router = APIRouter(prefix="/api/exports", tags=["exports"])


@router.post("/generate", response_model=MapGenerationResponse)
def generate_map(request: MapGenerationRequest) -> MapGenerationResponse:
    config = map_library.normalize_generation(request.config)
    return MapGenerationResponse(config=config)


@router.get("", response_model=list[MapSummary])
def list_maps() -> list[MapSummary]:
    return map_library.list_maps()


@router.post("", response_model=MapRecord, status_code=201)
def create_map(payload: MapCreate) -> MapRecord:
    return map_library.create_map(payload)


@router.get("/{map_id}", response_model=MapRecord)
def get_map(map_id: str) -> MapRecord:
    return map_library.get_map(map_id)


@router.put("/{map_id}", response_model=MapRecord)
def update_map(map_id: str, payload: MapCreate) -> MapRecord:
    return map_library.update_map(map_id, payload)


@router.delete("/{map_id}", status_code=204)
def delete_map(map_id: str) -> Response:
    map_library.delete_map(map_id)
    return Response(status_code=204)


@router.post("/{map_id}/exports/png", response_model=ExportResponse, status_code=201)
def create_png_export(map_id: str, payload: PngExportRequest) -> ExportResponse:
    saved = map_library.save_png(map_id, payload.data_url)
    return ExportResponse(
        id=saved["id"],
        kind="png",
        download_url=f"/api/exports/{saved['id']}/png",
        created_at=saved["created_at"],
    )


@exports_router.get("/{export_id}/png")
def download_png(export_id: str) -> Response:
    content, media_type = map_library.get_png(export_id)
    return Response(
        content=content,
        media_type=media_type,
        headers={"Content-Disposition": f'attachment; filename="map-{export_id}.png"'},
    )
