"""Public read-only endpoints for the MANEB MSCE past-paper library.

The papers are published by the Malawi National Examinations Board for study
use, so these endpoints are intentionally open: the app shows them inline, page
by page, and no visitor is handed a file to download.
"""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, Query, Response
from pydantic import BaseModel

from app.msce_papers import service

router = APIRouter(prefix="/msce-papers", tags=["msce-papers"])


class PaperSummary(BaseModel):
    id: str
    year: int | None = None
    subject: str | None = None
    paper: int | None = None
    subject_code: str | None = None
    title: str
    pages: int
    verified: bool
    source_provider: str | None = None
    source_url: str | None = None
    attribution: str | None = None
    licence: str | None = None
    sha256: str | None = None
    verification: dict = {}


@router.get("")
async def list_papers(
    year: int | None = Query(default=None, ge=1990, le=2035),
    subject: str | None = Query(default=None),
    paper: int | None = Query(default=None, ge=1, le=9),
) -> dict:
    """The paper catalogue, optionally filtered."""
    service.ensure_library()
    if subject or paper is not None or year is not None:
        papers = service.list_papers(year=year, subject=subject, paper=paper)
        return {"papers": papers, "total": len(papers)}
    return service.catalogue()


@router.get("/status")
async def status() -> dict:
    """Whether the library is ready, and how much of it there is."""
    service.ensure_library()
    return service.harvest_status()


@router.get("/{paper_id}")
async def paper_detail(paper_id: str) -> dict:
    """One paper, including the URLs of its pages."""
    try:
        paper = service.get_paper(paper_id)
    except service.PaperNotFound:
        raise HTTPException(status_code=404, detail="Paper not found")
    return {
        "paper": paper,
        "pages": [
            {"page": number, "url": f"/api/v1/msce-papers/{paper_id}/page/{number}.png"}
            for number in range(1, int(paper.get("pages") or 1) + 1)
        ],
    }


@router.get("/{paper_id}/page/{page_number}.png")
async def paper_page(
    paper_id: str,
    page_number: int,
    dpi: int = Query(
        default=service.DEFAULT_DPI, ge=service.MIN_DPI, le=service.MAX_DPI
    ),
) -> Response:
    """One page of a paper rendered to PNG, for inline viewing."""
    try:
        data = service.render_page(paper_id, page_number, dpi=dpi)
    except service.PaperNotFound:
        raise HTTPException(status_code=404, detail="Page not found")
    except service.PaperFileMissing:
        raise HTTPException(status_code=503, detail="Paper file is not available yet")
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    return Response(
        content=data,
        media_type="image/png",
        headers={
            # Inline, never an attachment: the page is shown in the app and is
            # never written to the visitor's device as a file.
            "Content-Disposition": f'inline; filename="{paper_id}-p{page_number}.png"',
            "Cache-Control": "public, max-age=86400",
        },
    )


@router.get("/{paper_id}/text")
async def paper_text(paper_id: str) -> dict:
    """The embedded text layer of a paper, when the source PDF has one."""
    try:
        return service.paper_text(paper_id)
    except service.PaperNotFound:
        raise HTTPException(status_code=404, detail="Paper not found")
    except service.PaperFileMissing:
        raise HTTPException(status_code=503, detail="Paper file is not available yet")
