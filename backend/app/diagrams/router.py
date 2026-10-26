"""FastAPI routes for the Asymptote diagram service."""

from __future__ import annotations

from fastapi import APIRouter
from fastapi.responses import FileResponse

from . import service
from .schemas import DiagramHealthResponse, DiagramRenderRequest, DiagramRenderResponse

router = APIRouter(prefix="/diagrams", tags=["diagrams"])


@router.post("/render", response_model=DiagramRenderResponse)
def render_diagram(request: DiagramRenderRequest) -> DiagramRenderResponse:
    """Generate an SVG diagram through the real Asymptote compiler.

    Failures are reported in the payload (ok=False + error code) so lessons stay
    usable when the toolchain is unavailable; only a verified, non-empty SVG
    yields ok=True with an asset URL.
    """
    result = service.render_diagram(
        request.kind, request.params, timeout_s=request.timeout_s
    )
    return DiagramRenderResponse(**result)


@router.get("/assets/{sha}.svg")
def diagram_asset(sha: str) -> FileResponse:
    """Serve a cached, hash-addressed SVG (path-traversal safe)."""
    path = service.asset_path(sha)
    if path is None:
        from fastapi import HTTPException

        raise HTTPException(status_code=404, detail="diagram asset not found")
    return FileResponse(str(path), media_type="image/svg+xml")


@router.get("/health", response_model=DiagramHealthResponse)
def diagrams_health() -> DiagramHealthResponse:
    """Executable discovery, version and a real label-capable smoke compile."""
    return DiagramHealthResponse(**service.health())
