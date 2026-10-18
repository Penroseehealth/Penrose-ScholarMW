"""Local OCR server for the Mathsdrill web module.

The mathsdrill frontend (``frontend/web/mathsdrill``) reads scanned documents
by POSTing ``{"src": <data-url>, "mime": <type>}`` to this server:

- ``GET  /health``        -> ``{"status": "ok", "engines": [...]}``
- ``POST /ocr/{engine}``  -> ``{"text", "lines", "pageCount"}``
  where ``engine`` is one of ``easyocr`` / ``paddleocr`` / ``tesseract``
- ``POST /extract``       -> ``{"text"}`` (``.doc`` / ``.docx`` extraction)
- ``POST /pages``         -> ``{"pageCount"}`` (PDF page count)

Run from the repo root (the backend venv already has every dependency):

    backend/.venv/Scripts/python.exe scripts/ocr-server.py

Listens on http://127.0.0.1:8001 by default (override with HOST / PORT).

Native engines (``easyocr``, ``paddleocr``, ``pytesseract``) are used when
they are installed. Otherwise RapidOCR answers every engine id, so the
frontend's engine fallback chain always succeeds on the first try. RapidOCR
``rapidocr`` (PP-OCRv6, ~10s/A4-page on a 2-core CPU) is preferred, falling
back to the older ``rapidocr-onnxruntime`` (PP-OCRv4, ~10x slower) if the
newer package is missing.

Tunables (env vars): ``HOST``, ``PORT``, ``PDF_DPI`` (default 150) and
``MAX_PDF_PAGES`` (default 10).
"""

from __future__ import annotations

import base64
import io
import logging
import os
import threading
import time
import urllib.parse
import urllib.request
from typing import Any

import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("ocr-server")

ENGINE_IDS = ("easyocr", "paddleocr", "tesseract")
MAX_PDF_PAGES = int(os.environ.get("MAX_PDF_PAGES", "10"))
PDF_DPI = int(os.environ.get("PDF_DPI", "150"))

app = FastAPI(title="Penrose ScholarMW OCR server")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class OcrRequest(BaseModel):
    src: str = Field(description="Data URL, http(s) URL, or filesystem path")
    mime: str = Field(default="", description="MIME type of the payload")


# ---------------------------------------------------------------------------
# Payload decoding
# ---------------------------------------------------------------------------


def decode_src(src: str, mime: str) -> tuple[bytes, str]:
    """Resolve ``src`` to raw bytes; returns (data, mime)."""
    if src.startswith("data:"):
        header, _, payload = src.partition(",")
        real_mime = header[5:].split(";")[0] or mime
        if ";base64" in header:
            return base64.b64decode(payload), real_mime
        return urllib.parse.unquote_to_bytes(payload), real_mime
    if src.startswith(("http://", "https://")):
        with urllib.request.urlopen(src, timeout=60) as resp:
            return resp.read(), mime or resp.headers.get_content_type()
    try:
        with open(src, "rb") as fh:
            return fh.read(), mime
    except OSError as exc:
        raise HTTPException(status_code=400, detail=f"Cannot read src: {exc}")


def _is_pdf(data: bytes, mime: str) -> bool:
    return mime == "application/pdf" or data[:5] == b"%PDF-"


# ---------------------------------------------------------------------------
# OCR engines (lazy singletons)
# ---------------------------------------------------------------------------

_rapid: Any = None
_rapid_lock = threading.Lock()
_easy_reader: Any = None
_paddle_ocr: Any = None


def _get_rapid() -> tuple[str, Any]:
    """Lazily build the RapidOCR engine; returns (api_kind, engine)."""
    global _rapid
    if _rapid is not None:
        return _rapid
    with _rapid_lock:
        if _rapid is not None:
            return _rapid
        try:
            from rapidocr import RapidOCR

            engine = RapidOCR(params={"Global.log_level": "warning"})
            _rapid = ("v3", engine)
            log.info("RapidOCR v3 (PP-OCRv6) engine ready")
        except ImportError:
            from rapidocr_onnxruntime import RapidOCR as RapidOcrV1

            _rapid = ("v1", RapidOcrV1())
            log.info("RapidOCR v1 (PP-OCRv4) engine ready")
    return _rapid


def _get_easy() -> Any:
    global _easy_reader
    if _easy_reader is None:
        import easyocr

        _easy_reader = easyocr.Reader(["en"], gpu=False, verbose=False)
    return _easy_reader


def _get_paddle() -> Any:
    global _paddle_ocr
    if _paddle_ocr is None:
        from paddleocr import PaddleOCR

        _paddle_ocr = PaddleOCR(lang="en", show_log=False)
    return _paddle_ocr


def _run_rapid(data: bytes) -> list[dict[str, Any]]:
    kind, engine = _get_rapid()
    if kind == "v3":
        res = engine(data)
        txts = _to_list(getattr(res, "txts", None))
        scores = _to_list(getattr(res, "scores", None))
        boxes = _to_list(getattr(res, "boxes", None))
        lines: list[dict[str, Any]] = []
        for i, raw_text in enumerate(txts):
            text = str(raw_text).strip()
            if not text:
                continue
            try:
                conf = float(scores[i]) if i < len(scores) else 1.0
            except (TypeError, ValueError):
                conf = 1.0
            box = _flat_box(boxes[i]) if i < len(boxes) else []
            lines.append({"text": text, "confidence": conf, "box": box})
        return lines

    raw = engine(data)
    detections = raw[0] if isinstance(raw, (list, tuple)) and raw else raw
    lines = []
    for item in detections or []:
        if not isinstance(item, (list, tuple)) or len(item) < 2:
            continue
        text = str(item[1]).strip()
        if not text:
            continue
        try:
            conf = float(item[2]) if len(item) > 2 else 1.0
        except (TypeError, ValueError):
            conf = 1.0
        lines.append({"text": text, "confidence": conf, "box": _flat_box(item[0])})
    return lines


def _run_easy(data: bytes) -> list[dict[str, Any]]:
    import numpy as np
    from PIL import Image

    img = np.asarray(Image.open(io.BytesIO(data)).convert("RGB"))
    lines: list[dict[str, Any]] = []
    for box, text, conf in _get_easy().readtext(img):
        text = str(text).strip()
        if text:
            lines.append(
                {
                    "text": text,
                    "confidence": float(conf),
                    "box": _flat_box(box),
                }
            )
    return lines


def _run_paddle(data: bytes) -> list[dict[str, Any]]:
    result = _get_paddle().ocr(data)
    lines: list[dict[str, Any]] = []
    for page in result or []:
        for entry in page or []:
            try:
                box, (text, conf) = entry[0], entry[1]
            except (TypeError, ValueError, IndexError):
                continue
            text = str(text).strip()
            if text:
                lines.append(
                    {
                        "text": text,
                        "confidence": float(conf),
                        "box": _flat_box(box),
                    }
                )
    return lines


def _run_tesseract(data: bytes) -> list[dict[str, Any]]:
    import pytesseract
    from PIL import Image

    img = Image.open(io.BytesIO(data))
    lines: list[dict[str, Any]] = []
    data_out = pytesseract.image_to_data(img, output_type=pytesseract.Output.DICT)
    for i, text in enumerate(data_out.get("text", [])):
        text = str(text).strip()
        if not text:
            continue
        try:
            conf = float(data_out["conf"][i]) / 100.0
        except (TypeError, ValueError, KeyError):
            conf = 1.0
        x, y, w, h = (data_out[k][i] for k in ("left", "top", "width", "height"))
        box = [[x, y], [x + w, y], [x + w, y + h], [x, y + h]]
        lines.append({"text": text, "confidence": conf, "box": box})
    return lines


def _to_list(value: Any) -> list[Any]:
    """Listify arrays safely (numpy truthiness is ambiguous)."""
    if value is None:
        return []
    return list(value)


def _flat_box(box: Any) -> list[list[float]]:
    """Normalise a detection quad into float [x, y] points.

    Accepts lists/tuples and numpy arrays (v3 boxes are ndarrays).
    """
    points: list[list[float]] = []
    if box is None:
        return points
    try:
        iterator = iter(box)
    except TypeError:
        return points
    for pt in iterator:
        try:
            points.append([float(pt[0]), float(pt[1])])
        except (TypeError, ValueError, IndexError, KeyError):
            continue
    return points


NATIVE_RUNNERS = {
    "easyocr": ("easyocr", _run_easy),
    "paddleocr": ("paddleocr", _run_paddle),
    "tesseract": ("pytesseract", _run_tesseract),
}


def _native_available(engine: str) -> bool:
    mod_name, _ = NATIVE_RUNNERS[engine]
    try:
        __import__(mod_name)
        return True
    except ImportError:
        return False


def run_engine(engine: str, data: bytes) -> tuple[list[dict[str, Any]], str]:
    """OCR one image; returns (lines, engine actually used)."""
    if engine in NATIVE_RUNNERS and _native_available(engine):
        try:
            _, runner = NATIVE_RUNNERS[engine]
            return runner(data), engine
        except Exception as exc:
            log.warning("Native %s failed (%s); using RapidOCR", engine, exc)
    return _run_rapid(data), "rapidocr"


def ocr_image_bytes(engine: str, data: bytes, mime: str) -> dict[str, Any]:
    """OCR an image, or rasterise and OCR each page of a PDF."""
    t0 = time.monotonic()
    if _is_pdf(data, mime):
        import pymupdf

        doc = pymupdf.open(stream=data, filetype="pdf")
        page_count = len(doc)
        all_lines: list[dict[str, Any]] = []
        used = engine
        for i in range(min(page_count, MAX_PDF_PAGES)):
            pix = doc.load_page(i).get_pixmap(dpi=PDF_DPI)
            lines, used = run_engine(engine, pix.tobytes("png"))
            all_lines.extend(lines)
        doc.close()
        log.info(
            "ocr engine=%s pages=%d lines=%d took=%.1fs",
            used,
            page_count,
            len(all_lines),
            time.monotonic() - t0,
        )
        return {
            "text": "\n".join(ln["text"] for ln in all_lines),
            "lines": all_lines,
            "pageCount": page_count,
            "engine": used,
        }

    lines, used = run_engine(engine, data)
    log.info(
        "ocr engine=%s pages=1 lines=%d took=%.1fs",
        used,
        len(lines),
        time.monotonic() - t0,
    )
    return {
        "text": "\n".join(ln["text"] for ln in lines),
        "lines": lines,
        "pageCount": 1,
        "engine": used,
    }


def _warm_up() -> None:
    """Load OCR models in the background so the first upload is fast."""
    try:
        t0 = time.monotonic()
        img = io.BytesIO()
        from PIL import Image

        Image.new("RGB", (16, 16), "white").save(img, "PNG")
        _run_rapid(img.getvalue())
        log.info("OCR engine warm-up done in %.1fs", time.monotonic() - t0)
    except Exception as exc:
        log.warning("OCR warm-up failed: %s", exc)


@app.on_event("startup")
async def _startup_warm_up() -> None:
    threading.Thread(target=_warm_up, daemon=True).start()


# ---------------------------------------------------------------------------
# Text extraction (doc/docx) & PDF page count
# ---------------------------------------------------------------------------


def extract_document(data: bytes) -> str:
    from docx import Document  # python-docx

    doc = Document(io.BytesIO(data))
    parts = [p.text for p in doc.paragraphs if p.text.strip()]
    for table in doc.tables:
        for row in table.rows:
            cells = [c.text.strip() for c in row.cells if c.text.strip()]
            if cells:
                parts.append(" | ".join(cells))
    return "\n".join(parts)


def pdf_page_count(data: bytes) -> int:
    import pymupdf

    doc = pymupdf.open(stream=data, filetype="pdf")
    count = len(doc)
    doc.close()
    return count


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@app.get("/health")
async def health() -> dict[str, Any]:
    engines = list(ENGINE_IDS)  # all usable: RapidOCR fallback always present
    return {
        "status": "ok",
        "engines": engines,
        "native": {e: _native_available(e) for e in ENGINE_IDS},
    }


@app.post("/ocr/{engine}")
async def ocr(engine: str, body: OcrRequest) -> dict[str, Any]:
    if engine not in ENGINE_IDS:
        raise HTTPException(
            status_code=404,
            detail=f"Unknown engine '{engine}' (expected one of {ENGINE_IDS})",
        )
    data, mime = decode_src(body.src, body.mime)
    try:
        return await _to_thread_result(engine, data, mime)
    except HTTPException:
        raise
    except Exception as exc:
        log.warning("OCR %s failed: %s", engine, exc)
        raise HTTPException(status_code=500, detail=f"OCR failed: {exc}")


@app.post("/extract")
async def extract(body: OcrRequest) -> dict[str, Any]:
    data, _mime = decode_src(body.src, body.mime)
    try:
        text = await _to_thread_extract(data)
    except Exception as exc:
        log.warning("Extract failed: %s", exc)
        raise HTTPException(status_code=500, detail=f"Extract failed: {exc}")
    return {"text": text, "engine": "python-docx"}


@app.post("/pages")
async def pages(body: OcrRequest) -> dict[str, Any]:
    data, _mime = decode_src(body.src, body.mime)
    try:
        return {"pageCount": await _to_thread_pages(data)}
    except Exception as exc:
        log.warning("Page count failed: %s", exc)
        raise HTTPException(status_code=500, detail=f"Page count failed: {exc}")


async def _to_thread_result(engine: str, data: bytes, mime: str) -> dict[str, Any]:
    import asyncio

    return await asyncio.to_thread(ocr_image_bytes, engine, data, mime)


async def _to_thread_extract(data: bytes) -> str:
    import asyncio

    return await asyncio.to_thread(extract_document, data)


async def _to_thread_pages(data: bytes) -> int:
    import asyncio

    return await asyncio.to_thread(pdf_page_count, data)


if __name__ == "__main__":
    host = os.environ.get("HOST", "127.0.0.1")
    port = int(os.environ.get("PORT", "8001"))
    uvicorn.run(app, host=host, port=port, log_level="warning")
