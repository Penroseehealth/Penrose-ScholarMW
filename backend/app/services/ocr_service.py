"""OCR engine wrapper for scanned images and scanned PDF pages.

Uses RapidOCR (ONNX-based) so no system-level OCR install is required. The
engine is loaded lazily on first use to avoid slowing down app startup.
"""

from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass, field
from typing import Any

log = logging.getLogger(__name__)


@dataclass
class OcrLine:
    text: str
    confidence: float = 1.0
    box: list[list[float]] = field(default_factory=list)


@dataclass
class OcrResult:
    text: str
    lines: list[OcrLine] = field(default_factory=list)
    page_count: int = 1
    method: str = "ocr"
    error: str | None = None


class _OcrEngine:
    """Lazily-initialised RapidOCR engine (singleton)."""

    _instance: _OcrEngine | None = None
    _engine: Any | None = None
    _lock = asyncio.Lock()

    def __new__(cls) -> _OcrEngine:
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    async def _get_engine(self) -> Any:
        if self._engine is not None:
            return self._engine
        async with self._lock:
            if self._engine is not None:
                return self._engine
            try:
                from rapidocr_onnxruntime import RapidOCR

                self._engine = await asyncio.to_thread(RapidOCR)
                log.info("RapidOCR engine loaded")
            except Exception as e:
                log.warning("RapidOCR unavailable: %s", e)
                self._engine = None
        return self._engine

    async def run(self, content: bytes) -> OcrResult:
        engine = await self._get_engine()
        if engine is None:
            return OcrResult(text="", method="ocr", error="OCR engine unavailable")
        try:
            # RapidOCR returns (detections, elapsed); detections are
            # [box, text, confidence, ...] entries.
            raw = await asyncio.to_thread(engine, content)
            detections = raw[0] if isinstance(raw, (list, tuple)) and raw else raw

            lines: list[OcrLine] = []
            text_parts: list[str] = []
            if detections:
                for item in detections:
                    if not isinstance(item, (list, tuple)) or len(item) < 2:
                        continue
                    raw_text = str(item[1]).strip()
                    if not raw_text:
                        continue
                    try:
                        conf = float(item[2]) if len(item) > 2 else 1.0
                    except (TypeError, ValueError):
                        conf = 1.0
                    lines.append(
                        OcrLine(text=raw_text, confidence=conf, box=_parse_box(item[0]))
                    )
                    text_parts.append(raw_text)
            return OcrResult(
                text="\n".join(text_parts),
                lines=lines,
                page_count=1,
                method="ocr",
            )
        except Exception as e:
            log.warning("OCR run failed: %s", e)
            return OcrResult(text="", method="ocr", error=f"OCR failed: {e}")


def _parse_box(box: Any) -> list[list[float]]:
    """Normalise a RapidOCR quad into float x,y points."""
    points: list[list[float]] = []
    if isinstance(box, (list, tuple)):
        for pt in box:
            if isinstance(pt, (list, tuple)) and len(pt) >= 2:
                points.append([float(pt[0]), float(pt[1])])
    return points


_ocr = _OcrEngine()


async def ocr_image(content: bytes) -> OcrResult:
    """Run OCR on a single image (PNG/JPEG/WebP)."""
    return await _ocr.run(content)


async def ocr_pdf(content: bytes, max_pages: int = 10) -> OcrResult:
    """Rasterise PDF pages with PyMuPDF and OCR each page."""
    try:
        import pymupdf
    except ImportError:
        import fitz as pymupdf

    all_lines: list[OcrLine] = []
    all_text: list[str] = []
    page_count = 0
    try:
        doc = pymupdf.open(stream=content, filetype="pdf")
        page_count = min(len(doc), max_pages)
        for i in range(page_count):
            page = doc.load_page(i)
            pix = page.get_pixmap(dpi=200)
            img_bytes = pix.tobytes("png")
            res = await _ocr.run(img_bytes)
            if res.text:
                all_text.append(f"[Page {i + 1}] {res.text}")
                for line in res.lines:
                    # prefix page number for context on each line
                    line = OcrLine(
                        text=line.text,
                        confidence=line.confidence,
                        box=line.box,
                    )
                    all_lines.append(line)
        doc.close()
    except Exception as e:
        log.warning("PDF OCR failed: %s", e)
        return OcrResult(
            text="",
            method="ocr-pdf",
            page_count=page_count,
            error=f"PDF OCR failed: {e}",
        )
    return OcrResult(
        text="\n\n".join(all_text),
        lines=all_lines,
        page_count=page_count,
        method="ocr-pdf",
    )
