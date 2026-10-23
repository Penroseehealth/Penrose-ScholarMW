"""Fast OCR helper for MSCE paper discovery (RapidOCR / PP-OCRv3, CPU)."""

import os
import re
import io
import time
import numpy as np
from PIL import Image
import fitz

_PKG = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..",
    "backend",
    ".venv",
    "Lib",
    "site-packages",
    "rapidocr_onnxruntime",
)
_DET = os.path.normpath(os.path.join(_PKG, "models", "ch_PP-OCRv3_det_infer.onnx"))

_ENGINE = None


def get_engine():
    global _ENGINE
    if _ENGINE is None:
        from rapidocr_onnxruntime import RapidOCR

        _ENGINE = RapidOCR(
            use_angle_cls=False,
            det_model_path=_DET,
            det_limit_type="max",
            det_limit_side_len=960,
            det_thresh=0.3,
            box_thresh=0.4,
        )
    return _ENGINE


def render(page, dpi=140, top=0.0, frac=1.0):
    r = page.rect
    clip = fitz.Rect(r.x0, r.y0 + r.height * top, r.x1, r.y0 + r.height * (top + frac))
    pix = page.get_pixmap(dpi=dpi, clip=clip)
    return np.array(Image.open(io.BytesIO(pix.tobytes("png"))).convert("RGB"))


def ocr_page(page, dpi=140, top=0.0, frac=1.0):
    arr = render(page, dpi=dpi, top=top, frac=frac)
    res, _ = get_engine()(arr)
    if not res:
        return ""
    return re.sub(r"\s+", " ", " ".join(x[1] for x in res)).strip()


def header_text(doc, page_index, dpi=140, frac=0.30):
    try:
        return ocr_page(doc[page_index], dpi=dpi, top=0.0, frac=frac)
    except Exception:
        return ""


if __name__ == "__main__":
    import sys

    WORK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_msce_raw")
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
    for name, pages in [
        ("wtec1_maths_2001_2019", [1, 2, 3, 15, 16]),
        ("ia_2023_maths_p1", [0, 1, 2]),
    ]:
        p = os.path.join(WORK, name + ".pdf")
        if not os.path.exists(p):
            continue
        doc = fitz.open(p)
        print(f"=== {name} ({doc.page_count}p)", flush=True)
        for pi in pages:
            if pi >= doc.page_count:
                continue
            t = time.time()
            txt = header_text(doc, pi, dpi=140, frac=0.32)
            print(f"  p{pi} {time.time()-t:5.1f}s :: {txt[:190]}", flush=True)
        doc.close()
