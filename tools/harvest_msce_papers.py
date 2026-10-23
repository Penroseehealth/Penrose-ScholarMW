"""Harvest, verify and split MANEB Malawi MSCE past papers.

Pipeline
--------
1. Download every candidate PDF into ``tools/_msce_raw`` (cached, resumable).
2. Read the header of each page.  Pages that already carry a PDF text layer are
   parsed directly; pages without one are OCR'd (RapidOCR / PP-OCRv3) from a
   rendered header strip.
3. Detect the first page of every paper and the paper length, then cut the
   source PDF into one PDF per paper.
4. Only papers that pass :mod:`tools.msce_verify` are kept, and every kept
   paper records where it came from plus the checks that were run.

Output
------
``backend/data/msce_papers/papers/<id>.pdf``   one file per verified paper
``backend/data/msce_papers/manifest.json``     metadata + provenance
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import time
from dataclasses import dataclass, field

import requests

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from msce_verify import WANTED_SUBJECTS, classify_page  # noqa: E402

try:
    import fitz  # PyMuPDF
except ImportError:  # pragma: no cover
    fitz = None

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
RAW_DIR = os.path.join(HERE, "_msce_raw")
OUT_DIR = os.path.join(ROOT, "backend", "data", "msce_papers")
PAPER_DIR = os.path.join(OUT_DIR, "papers")
CACHE_DIR = os.path.join(OUT_DIR, "cache")

UA = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"
    )
}

YEAR_MIN, YEAR_MAX = 2010, 2026


@dataclass
class Source:
    """One downloadable candidate collection of papers."""

    key: str
    name: str
    url: str
    provider: str
    kind: str = "pdf"  # pdf | drive | archive
    expect: str | None = None  # optional subject hint
    note: str = ""


SOURCES: list[Source] = [
    Source(
        key="wtec1_maths_2001_2019",
        name="Maneb Mathematics papers 2001-2019",
        url="https://drive.google.com/uc?export=download&id=1YPraj8Fa4qjvVke_Lch5eHPiZ_pODwg5",
        provider="wtec1.com (Google Drive mirror)",
        kind="drive",
        expect="Mathematics",
    ),
    Source(
        key="wtec1_bio_2005_2018",
        name="Maneb Biology papers 2005-2018",
        url="https://drive.google.com/uc?export=download&id=16UUWbbBcf6xXaDDkuC4Y6AOvxlhpIUQn",
        provider="wtec1.com (Google Drive mirror)",
        kind="drive",
        expect="Biology",
    ),
    Source(
        key="wtec1_bio_2003_2014",
        name="Maneb Biology papers 2003-2014",
        url="https://drive.google.com/uc?export=download&id=1MkcITDET6cEuBDOxnXorxBBOywiW41Vy",
        provider="wtec1.com (Google Drive mirror)",
        kind="drive",
        expect="Biology",
    ),
    Source(
        key="wtec1_2021_2023_mixed",
        name="Maneb MSCE papers 2021 & 2023",
        url="https://drive.google.com/uc?export=download&id=1Pskb61dISyFbx8mu9A4vyPOEpJi2FnWv",
        provider="wtec1.com (Google Drive mirror)",
        kind="drive",
    ),
    Source(
        key="ia_2023_maths_p1",
        name="MSCE Mathematics Paper 1 (2023)",
        url="https://archive.org/download/2023-msce-mat-p-1/2023_MSCE_MAT_P1_text.pdf",
        provider="archive.org",
        kind="archive",
    ),
    Source(
        key="ia_2023_maths_p2",
        name="MSCE Maneb Mathematics Paper 2 (2023)",
        url="https://archive.org/download/2023-maneb-maths-p-2/2023_Maneb_Maths_P2_text.pdf",
        provider="archive.org",
        kind="archive",
    ),
    Source(
        key="ia_2026_bio_p1",
        name="MSCE Biology Paper 1 (2026)",
        url="https://archive.org/download/2026-bio-p-1.pdf/2026%20Bio%20p1.pdf_text.pdf",
        provider="archive.org",
        kind="archive",
    ),
]

# The kizitochikuni.com mirror serves real 2025/2026 papers, but its PDFs only
# carry a watermark text layer, and RapidOCR misreads the paper number on the
# cover ("PAPER I" came back as "PAPER II").  They are kept out of the library
# until the covers are checked by hand:
#   https://kizitochikuni.com/download.php?id=308   2025 Mathematics Paper II
#   https://kizitochikuni.com/download.php?id=1208  2026 Mathematics Paper I
#   https://kizitochikuni.com/download.php?id=1405  2026 Mathematics Paper II
#   https://kizitochikuni.com/download.php?id=1204  2026 Biology Paper I
#
# The archive.org "Excel Academy" 2020-2023 compilation (500 pages, image only)
# was dropped: RapidOCR found a single cover in the whole document, so the paper
# boundaries cannot be recovered.  A better scan is needed:
#   https://archive.org/details/
#   maneb-msce-past-past-papers-from-2020-to-2023-msce-excel-academy
# Sources that are known NOT to be official MANEB examination papers.
REJECT_SOURCES = {
    "wtec1_maths_p1": "topic question bank, not an exam paper",
    "wtec1_maths_p2": "topic question bank, not an exam paper",
    "wtec1_bio_p1": "topic question bank, not an exam paper",
    "wtec1_mixed_subjects": "mock / diocesan papers",
    "wtec1_sample_papers": "mixed study notes, not exam papers",
}


_LOG_FH = None
_LOCK_HANDLE = None


def set_log_file(path: str | None) -> None:
    """Mirror every progress line into ``path`` (the backend reads it)."""
    global _LOG_FH
    if _LOG_FH is not None:
        try:
            _LOG_FH.close()
        except Exception:  # noqa: BLE001
            pass
        _LOG_FH = None
    if path:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        _LOG_FH = open(path, "a", encoding="utf-8")


def acquire_single_instance() -> bool:
    """Take a machine-wide lock so two harvesters never run at once.

    The Windows venv launcher can re-execute this script, and the backend also
    starts a harvest when the library is empty; without the lock they would
    fight over the same OCR cache and manifest.
    """
    global _LOCK_HANDLE
    if os.name != "nt":
        return True
    try:
        import ctypes
        from ctypes import wintypes

        kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel32.CreateMutexW.restype = wintypes.HANDLE
        kernel32.CreateMutexW.argtypes = [
            wintypes.LPCVOID,
            wintypes.BOOL,
            wintypes.LPCWSTR,
        ]
        handle = kernel32.CreateMutexW(None, True, "Local\\PenroseMsceHarvest")
        if not handle:
            return True
        _LOCK_HANDLE = handle
        return ctypes.get_last_error() != 183  # ERROR_ALREADY_EXISTS
    except Exception:  # noqa: BLE001
        return True


def log(msg: str) -> None:
    print(msg, flush=True)
    if _LOG_FH is not None:
        try:
            _LOG_FH.write(msg + "\n")
            _LOG_FH.flush()
        except Exception:  # noqa: BLE001
            pass


def sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def download(src: Source, session: requests.Session) -> str | None:
    """Fetch the source PDF into the raw cache; returns the local path."""
    os.makedirs(RAW_DIR, exist_ok=True)
    dest = os.path.join(RAW_DIR, f"{src.key}.pdf")
    if os.path.exists(dest) and os.path.getsize(dest) > 1024:
        return dest
    for attempt in range(3):
        try:
            resp = session.get(src.url, timeout=600, verify=False)
            if resp.content[:4] == b"%PDF":
                with open(dest, "wb") as fh:
                    fh.write(resp.content)
                return dest
            log(f"    ! {src.key}: not a PDF (status {resp.status_code})")
        except Exception as exc:  # noqa: BLE001
            log(f"    ! {src.key}: {type(exc).__name__}: {exc}")
        time.sleep(4)
    return None


class HeaderReader:
    """Page header text, from the PDF text layer or from OCR when needed."""

    def __init__(
        self,
        doc,
        ocr_cache: dict | None = None,
        allow_ocr: bool = True,
        cache_path: str | None = None,
    ):
        self.doc = doc
        self.ocr_cache = ocr_cache if ocr_cache is not None else {}
        self.allow_ocr = allow_ocr
        self.ocr_calls = 0
        self.cache_path = cache_path
        self._dirty = 0

    def flush(self) -> None:
        """Persist the OCR cache so a long scan can be resumed."""
        if not self.cache_path or not self._dirty:
            return
        try:
            tmp = self.cache_path + ".tmp"
            with open(tmp, "w", encoding="utf-8") as fh:
                json.dump(self.ocr_cache, fh)
            os.replace(tmp, self.cache_path)
            self._dirty = 0
        except Exception:  # noqa: BLE001
            pass

    def text_layer(self, index: int) -> str:
        try:
            return self.doc[index].get_text()
        except Exception:  # noqa: BLE001
            return ""

    def ocr(self, index: int, dpi: int = 140, frac: float = 0.34) -> str:
        key = f"{index}:{dpi}:{frac}"
        if key in self.ocr_cache:
            return self.ocr_cache[key]
        if not self.allow_ocr:
            return ""
        from msce_ocr import ocr_page

        self.ocr_calls += 1
        if self.ocr_calls % 10 == 0:
            log(f"    .. {self.ocr_calls} OCR call(s), still reading headers")
            self.flush()
        try:
            text = ocr_page(self.doc[index], dpi=dpi, top=0.0, frac=frac)
        except Exception as exc:  # noqa: BLE001
            log(f"    ! OCR failed on page {index}: {type(exc).__name__}")
            text = ""
        self.ocr_cache[key] = text
        self._dirty += 1
        return text

    def header(self, index: int, allow_ocr: bool = True) -> str:
        """Best-effort header text for a page."""
        text = self.text_layer(index)
        info = classify_page(text) if text.strip() else {}
        if info.get("is_first_page") or info.get("maneb"):
            return text
        if not allow_ocr:
            return text
        # Only OCR when the text layer is missing or clearly not an exam header.
        if text.strip() and re.search(r"EXAMINATION", text, re.I):
            return text
        ocr_text = self.ocr(index)
        return ocr_text if len(ocr_text.strip()) > len(text.strip()) else text

    def header_wide(self, index: int) -> str:
        """Read a taller strip, for covers where the year sits lower down."""
        if not self.allow_ocr:
            return ""
        return self.ocr(index, dpi=170, frac=0.55)


@dataclass
class DetectedPaper:
    start: int
    length: int
    year: int | None
    subject: str | None
    paper: int | None
    subject_code: str | None
    total_pages: int | None
    checks: dict = field(default_factory=dict)


MAX_LEAD_SCAN = 16
MAX_GAP_SCAN = 4
MAX_FALLBACK_SCAN = 48
OCR_BUDGET = 500
# The shortest authentic MSCE paper seen so far is 11 printed pages, so a
# shorter cut means the boundary scan stopped early and the paper is incomplete.
MIN_PAPER_PAGES = 8
# An MSCE paper is 8-32 printed pages; anything longer means a missed cover and
# the cut swallowed the rest of the compilation.
MAX_PAPER_PAGES = 40


def detect_papers(doc, reader: HeaderReader) -> list[DetectedPaper]:
    """Walk the document and find each exam paper.

    The walk uses the "This paper contains N printed pages" declaration to jump
    to the next paper, then confirms the landing page really is the cover of
    another paper.  That keeps the number of OCR calls proportional to the
    number of papers rather than to the number of pages.
    """
    papers: list[DetectedPaper] = []
    total = doc.page_count
    index = 0
    lead_misses = 0
    while index < total:
        if reader.ocr_calls > OCR_BUDGET:
            log(f"    ! OCR budget of {OCR_BUDGET} call(s) reached, stopping")
            break
        text = reader.header(index)
        info = classify_page(text)
        if not info["is_first_page"]:
            index += 1
            lead_misses += 1
            if not papers and lead_misses > MAX_LEAD_SCAN:
                log(
                    f"    ! no exam cover in the first {MAX_LEAD_SCAN} pages, skipping source"
                )
                break
            continue
        lead_misses = 0
        if info.get("year") is None:
            # The cover's year line sits below the usual crop; read wider once.
            wide_info = classify_page(reader.header_wide(index))
            if wide_info.get("year") and wide_info.get("is_first_page"):
                info = wide_info
        declared = info.get("total_pages") or info.get("page_total") or 0
        year = info.get("year")
        subject = info.get("resolved_subject")
        in_scope = (year is None or YEAR_MIN <= year <= YEAR_MAX) and (
            subject is None or subject in WANTED_SUBJECTS
        )
        if not in_scope:
            log(f"    - page {index}: {year} {subject} (out of scope), skipping")
            index += max(1, declared) if declared else 1
            continue
        next_start = None
        if declared and index + declared < total:
            landing = index + declared
            for step in range(MAX_GAP_SCAN + 1):
                probe = landing + step
                if probe >= total:
                    break
                if classify_page(reader.header(probe))["is_first_page"]:
                    next_start = probe
                    break
        elif not declared:
            # No "this paper contains N pages" line: fall back to scanning for
            # the next cover page so the cut still ends where the paper ends.
            for step in range(1, MAX_FALLBACK_SCAN + 1):
                probe = index + step
                if probe >= total:
                    break
                if classify_page(reader.header(probe))["is_first_page"]:
                    next_start = probe
                    break
        length = (next_start - index) if next_start else (declared or (total - index))
        papers.append(
            DetectedPaper(
                start=index,
                length=max(1, length),
                year=info.get("year"),
                subject=info.get("resolved_subject"),
                paper=info.get("paper"),
                subject_code=info.get("subject_code"),
                total_pages=info.get("total_pages"),
                checks={
                    "maneb_header": bool(info.get("maneb")),
                    "not_mock": not info.get("mock"),
                    "subject_code": info.get("subject_code"),
                    "paper_label": info.get("paper"),
                    "year": info.get("year"),
                    "declared_pages": info.get("total_pages"),
                    "next_paper_found_at": next_start,
                },
            )
        )
        log(
            f"    + page {index}: {info.get('year')} {info.get('resolved_subject')} "
            f"Paper {info.get('paper')} (declared {declared or '?'})"
        )
        index = next_start if next_start else index + max(1, length)
    reader.flush()
    return papers


def refine_boundaries(
    doc, reader: HeaderReader, papers: list[DetectedPaper]
) -> list[DetectedPaper]:
    """Make sure a detected paper really ends where the next one starts."""
    for i, paper in enumerate(papers):
        if paper.length:
            continue
        nxt = papers[i + 1].start if i + 1 < len(papers) else doc.page_count
        paper.length = max(1, nxt - paper.start)
    return papers


def split_pdf(src_path: str, doc, papers: list[DetectedPaper], out_dir: str, key: str):
    """Write one PDF per detected paper; returns [(path, DetectedPaper)]."""
    os.makedirs(out_dir, exist_ok=True)
    written = []
    for paper in papers:
        end = min(paper.start + paper.length, doc.page_count)
        if end <= paper.start:
            continue
        paper.length = end - paper.start
        out = fitz.open()
        out.insert_pdf(doc, from_page=paper.start, to_page=end - 1)
        name = f"{key}_p{paper.start:04d}.pdf"
        path = os.path.join(out_dir, name)
        out.save(path, garbage=0, deflate=True)
        out.close()
        written.append((path, paper))
    return written


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--only", action="append", default=[], help="limit to source keys")
    ap.add_argument("--skip-ocr", action="store_true", help="only use PDF text layers")
    ap.add_argument(
        "--dry-run", action="store_true", help="detect but do not write papers"
    )
    ap.add_argument(
        "--log",
        default=os.path.join(OUT_DIR, "harvest.log"),
        help="also append progress to this file",
    )
    args = ap.parse_args()

    set_log_file(args.log)

    if not acquire_single_instance():
        log("another harvest is already running, exiting")
        return 0

    if fitz is None:
        log("PyMuPDF is required: pip install pymupdf")
        return 2

    os.makedirs(PAPER_DIR, exist_ok=True)
    os.makedirs(CACHE_DIR, exist_ok=True)
    session = requests.Session()
    session.headers.update(UA)

    manifest_path = os.path.join(OUT_DIR, "manifest.json")
    manifest = {"generated_at": None, "papers": []}
    if os.path.exists(manifest_path):
        try:
            with open(manifest_path, encoding="utf-8") as fh:
                manifest = json.load(fh)
        except Exception:  # noqa: BLE001
            pass
    manifest.setdefault("papers", [])

    existing = {p["id"] for p in manifest["papers"]}
    keys = args.only or [s.key for s in SOURCES]

    for src in SOURCES:
        if src.key not in keys:
            continue
        log(f"\n=== {src.key}: {src.name}")
        path = download(src, session)
        if not path:
            log("    download failed, skipping")
            continue
        try:
            doc = fitz.open(path)
        except Exception as exc:  # noqa: BLE001
            log(f"    cannot open: {exc}")
            continue

        cache_file = os.path.join(CACHE_DIR, f"{src.key}_ocr.json")
        ocr_cache: dict = {}
        if os.path.exists(cache_file):
            try:
                with open(cache_file, encoding="utf-8") as fh:
                    ocr_cache = json.load(fh)
            except Exception:  # noqa: BLE001
                ocr_cache = {}

        reader = HeaderReader(
            doc, ocr_cache, allow_ocr=not args.skip_ocr, cache_path=cache_file
        )
        papers = detect_papers(doc, reader)
        papers = refine_boundaries(doc, reader, papers)
        log(
            f"    {doc.page_count} pages -> {len(papers)} detected paper(s), {reader.ocr_calls} OCR call(s)"
        )

        kept_papers = []
        for paper in papers:
            ok = (
                MIN_PAPER_PAGES <= paper.length <= MAX_PAPER_PAGES
                and paper.year
                and paper.subject
                and paper.paper
            )
            log(
                f"      {'kept' if ok else 'skip'} pages {paper.start}-{paper.start + paper.length - 1}: "
                f"{paper.year} {paper.subject} Paper {paper.paper} "
                f"(code {paper.subject_code}, declared {paper.total_pages})"
            )
            if ok:
                kept_papers.append(paper)
        papers = kept_papers

        if not args.dry_run:
            with open(cache_file, "w", encoding="utf-8") as fh:
                json.dump(ocr_cache, fh)
            written = split_pdf(path, doc, papers, PAPER_DIR, src.key)
            for wpath, paper in written:
                pid = f"{paper.year}_{paper.subject.lower().replace(' ', '_')}_p{paper.paper}_{os.path.basename(wpath)[len(src.key) + 1:-4]}"
                if pid in existing:
                    continue
                checks = dict(paper.checks)
                checks["page_range"] = [paper.start, paper.start + paper.length - 1]
                checks["declared_page_total"] = paper.total_pages
                checks["page_count_plausible"] = (
                    MIN_PAPER_PAGES <= paper.length <= MAX_PAPER_PAGES
                )
                checks["pages_match_declared"] = (
                    paper.total_pages is not None
                    and abs(paper.length - paper.total_pages) <= 2
                )
                manifest["papers"].append(
                    {
                        "id": pid,
                        "year": paper.year,
                        "subject": paper.subject,
                        "paper": paper.paper,
                        "subject_code": paper.subject_code,
                        "title": f"MSCE {paper.year} {paper.subject} Paper {paper.paper}",
                        "pages": paper.length,
                        "file": os.path.relpath(wpath, OUT_DIR).replace("\\", "/"),
                        "source_key": src.key,
                        "source_name": src.name,
                        "source_provider": src.provider,
                        "source_url": src.url,
                        "sha256": sha256(wpath),
                        "verified": bool(
                            checks.get("maneb_header")
                            and checks.get("not_mock")
                            and checks.get("subject_code")
                            and checks.get("paper_label")
                            and checks.get("year")
                        ),
                        "verification": checks,
                        "licence": "Educational use; papers are the property of MANEB.",
                        "attribution": "Malawi National Examinations Board (MANEB)",
                    }
                )
                existing.add(pid)
        doc.close()

    manifest["generated_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    if not args.dry_run:
        with open(manifest_path, "w", encoding="utf-8") as fh:
            json.dump(manifest, fh, indent=2, ensure_ascii=False)
    kept = [p for p in manifest["papers"] if p.get("verified")]
    log(f"\nmanifest: {len(manifest['papers'])} paper(s), {len(kept)} verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
