"""Access to the harvested MANEB MSCE past-paper library.

The papers live on disk as one PDF per exam paper.  This service reads the
harvest manifest, renders individual pages to PNG on demand and caches the
render, so the app can show a paper page by page without the user ever
receiving a file.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import threading
import time
from pathlib import Path

try:
    import fitz  # PyMuPDF
except ImportError:  # pragma: no cover - PyMuPDF is an optional extra
    fitz = None

REPO_ROOT = Path(__file__).resolve().parents[3]
DATA_DIR = REPO_ROOT / "backend" / "data" / "msce_papers"
MANIFEST_PATH = DATA_DIR / "manifest.json"
PAPERS_DIR = DATA_DIR / "papers"
PAGE_CACHE_DIR = DATA_DIR / "cache" / "pages"
HARVEST_SCRIPT = REPO_ROOT / "tools" / "harvest_msce_papers.py"

DEFAULT_DPI = 150
MAX_DPI = 220
MIN_DPI = 90

_lock = threading.Lock()
_manifest_cache: dict = {}
_manifest_stamp: float = 0.0
_harvest_started = False


class PaperNotFound(Exception):
    """Raised when a paper id is unknown to the manifest."""


class PaperFileMissing(Exception):
    """Raised when the manifest knows a paper but its PDF is not on disk."""


def load_manifest(force: bool = False) -> dict:
    """Read the manifest, re-reading it when the file changed on disk."""
    global _manifest_cache, _manifest_stamp
    with _lock:
        try:
            stamp = MANIFEST_PATH.stat().st_mtime
        except OSError:
            stamp = 0.0
        if force or stamp != _manifest_stamp or not _manifest_cache:
            data: dict = {"papers": [], "generated_at": None}
            if MANIFEST_PATH.is_file():
                try:
                    data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
                except (OSError, json.JSONDecodeError):
                    data = {"papers": [], "generated_at": None}
            data.setdefault("papers", [])
            _manifest_cache = data
            _manifest_stamp = stamp
        return _manifest_cache


def papers_ready() -> bool:
    """True when at least one verified paper is present on disk."""
    return bool(available_papers())


def available_papers() -> list[dict]:
    """Every verified paper whose PDF is actually on disk."""
    manifest = load_manifest()
    ready = []
    for paper in manifest.get("papers", []):
        if not paper.get("verified"):
            continue
        if not (DATA_DIR / paper.get("file", "")).is_file():
            continue
        ready.append(paper)
    return ready


def list_papers(
    year: int | None = None,
    subject: str | None = None,
    paper: int | None = None,
) -> list[dict]:
    """Filter the catalogue by year, subject and paper number."""
    results = []
    for item in available_papers():
        if year is not None and item.get("year") != year:
            continue
        if subject and (item.get("subject") or "").lower() != subject.lower():
            continue
        if paper is not None and item.get("paper") != paper:
            continue
        results.append(item)
    results.sort(
        key=lambda p: (
            p.get("year") or 0,
            (p.get("subject") or ""),
            p.get("paper") or 0,
        ),
        reverse=True,
    )
    return results


def catalogue() -> dict:
    """The full catalogue plus the filter options for the UI."""
    manifest = load_manifest()
    papers = list_papers()
    years = sorted({p.get("year") for p in papers if p.get("year")}, reverse=True)
    subjects = sorted({p.get("subject") for p in papers if p.get("subject")})
    return {
        "papers": papers,
        "total": len(papers),
        "years": years,
        "subjects": subjects,
        "generated_at": manifest.get("generated_at"),
        "available": bool(papers),
        "source": "Malawi National Examinations Board (MANEB)",
    }


def get_paper(paper_id: str) -> dict:
    """One paper by id."""
    for item in load_manifest().get("papers", []):
        if item.get("id") == paper_id:
            return item
    raise PaperNotFound(paper_id)


def paper_path(paper: dict) -> Path:
    return DATA_DIR / paper.get("file", "")


def render_page(paper_id: str, page_number: int, dpi: int = DEFAULT_DPI) -> bytes:
    """Render one page of a paper to PNG bytes (cached on disk)."""
    paper = get_paper(paper_id)
    source = paper_path(paper)
    if not source.is_file():
        raise PaperFileMissing(paper_id)
    if fitz is None:
        raise RuntimeError("PyMuPDF is not installed on the server")

    dpi = max(MIN_DPI, min(MAX_DPI, int(dpi)))
    page_number = max(1, int(page_number))
    cache_dir = PAGE_CACHE_DIR / paper_id
    cache_file = cache_dir / f"{page_number}_{dpi}.png"
    if cache_file.is_file():
        return cache_file.read_bytes()

    cache_dir.mkdir(parents=True, exist_ok=True)
    document = fitz.open(source)
    try:
        if page_number > document.page_count:
            raise PaperNotFound(f"{paper_id} has no page {page_number}")
        pixmap = document[page_number - 1].get_pixmap(dpi=dpi)
        data = pixmap.tobytes("png")
    finally:
        document.close()
    cache_file.write_bytes(data)
    return data


def paper_text(paper_id: str) -> dict:
    """Extract the embedded text layer of a paper, when it has one."""
    paper = get_paper(paper_id)
    source = paper_path(paper)
    if not source.is_file() or fitz is None:
        raise PaperFileMissing(paper_id)
    document = fitz.open(source)
    try:
        pages = []
        for index in range(document.page_count):
            pages.append(document[index].get_text().strip())
    finally:
        document.close()
    text = "\n\n".join(pages)
    return {
        "id": paper_id,
        "title": paper.get("title"),
        "has_text": bool(text.strip()),
        "text": text,
    }


def start_harvest() -> bool:
    """Kick off the paper harvester when the library is still empty.

    The harvester downloads and verifies the papers from their public mirrors;
    it is slow the first time and writes into ``backend/data/msce_papers``.
    """
    global _harvest_started
    with _lock:
        if _harvest_started:
            return False
        if available_papers():
            return False
        if not HARVEST_SCRIPT.is_file():
            return False
        _harvest_started = True
    log_path = DATA_DIR / "harvest.log"
    try:
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        handle = open(log_path, "a", encoding="utf-8")
        subprocess.Popen(
            [sys.executable, str(HARVEST_SCRIPT)],
            stdout=handle,
            stderr=subprocess.STDOUT,
            cwd=str(REPO_ROOT),
            start_new_session=True,
        )
    except Exception:  # noqa: BLE001
        with _lock:
            _harvest_started = False
        return False
    return True


def harvest_status() -> dict:
    """A short description of the library state for the UI."""
    papers = available_papers()
    last_error = None
    log_path = DATA_DIR / "harvest.log"
    if log_path.is_file():
        try:
            lines = (
                log_path.read_text(encoding="utf-8", errors="ignore")
                .strip()
                .splitlines()
            )
            last_error = lines[-1][:400] if lines else None
        except OSError:
            last_error = None
    return {
        "available": bool(papers),
        "count": len(papers),
        "running": _harvest_started,
        "checked_at": time.time(),
        "last_log_line": last_error,
    }


def ensure_library() -> None:
    """Make sure the catalogue exists, starting a harvest if necessary."""
    if not available_papers():
        start_harvest()


os.makedirs(DATA_DIR, exist_ok=True)
os.makedirs(PAGE_CACHE_DIR, exist_ok=True)
