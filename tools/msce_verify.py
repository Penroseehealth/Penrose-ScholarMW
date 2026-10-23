"""Verification + parsing helpers for MANEB Malawi MSCE past papers.

The Malawi National Examinations Board (MANEB) does not publish past papers on
its own website, so every candidate PDF is validated against the official
exam-paper fingerprint before it is allowed into the app:

  EXAMINATION NO.: THE MALAWI NATIONAL EXAMINATIONS BOARD <year>
  MALAWI SCHOOL CERTIFICATE OF EDUCATION  EXAMINATION  <subject>
  Subject Number: M<ddd>/<I|II>   ...   PAPER <I|II>  (100 marks)
  "This paper contains <n> printed pages."

Because most archives are scans, the header text may come from a PDF text
layer (often noisy, because it was produced by an OCR pass) or from a fresh
OCR of the rendered page.  All matching below is therefore tolerant of the
character substitutions that OCR engines make.
"""

from __future__ import annotations

import re
import unicodedata

# MANEB subject numbers as printed on the exam papers.
SUBJECT_CODES: dict[str, str] = {
    "022": "Biology",
    "131": "Mathematics",
    "012": "English",
    "032": "Chemistry",
    "052": "Physics",
    "062": "Additional Mathematics",
    "073": "Geography",
    "081": "Agriculture",
    "091": "History",
    "101": "Chichewa",
}

WANTED_SUBJECTS = {"Biology", "Mathematics"}

# Paper I / II may be printed as roman or arabic numerals.
_PAPER_WORDS = {
    "I": 1,
    "1": 1,
    "L": 1,
    "II": 2,
    "2": 2,
    "IL": 2,
    "III": 3,
    "3": 3,
}


def normalize(text: str) -> str:
    """Fold a text layer into a shape that survives OCR noise."""
    if not text:
        return ""
    text = unicodedata.normalize("NFKC", text)
    text = text.replace("\u00a0", " ")
    # Full-width punctuation that OCR/scan pipelines emit.
    table = {
        "\uff0f": "/",
        "\u2215": "/",
        "\u2044": "/",
        "\uff0c": ",",
        "\uff1a": ":",
        "\uff1b": ";",
        "\uff08": "(",
        "\uff09": ")",
        "\uff3d": "[",
        "\uff3e": "]",
        "\u2013": "-",
        "\u2014": "-",
        "\u2010": "-",
        "\u2011": "-",
        "\u2018": "'",
        "\u2019": "'",
        "\u201c": '"',
        "\u201d": '"',
        "\u00b7": ".",
        "\u2022": ".",
        "\u2023": ".",
    }
    for a, b in table.items():
        text = text.replace(a, b)
    return text


def _squash(text: str) -> str:
    """Remove every space so OCR word-splits cannot hide a keyword."""
    return re.sub(r"\s+", "", text)


def looks_like_maneb(text: str) -> bool:
    """True when the text carries the MANEB board identity.

    The archived scans have been through at least one lossy OCR pass, so the
    board name turns up as "THE MALAWI NATIONAL EXAMINATIONS BOARD",
    "THE MAL... EXAMIMIONS BOARD" and similar.  The board name and the
    certificate title are therefore matched on their stable fragments.
    """
    flat = _squash(normalize(text)).upper()
    if "NATIONALEXAMINATIONSBOARD" in flat:
        return True
    # "EXAMINATIONS BOARD" is only printed on the cover sheet of a real paper.
    if "BOARD" in flat and "EXAM" in flat:
        return True
    if "CERTIFICATEOFEDUCATION" in flat and "MALA" in flat:
        return True
    return False


def looks_like_mock(text: str) -> bool:
    """True for mock / cluster / diocesan papers, which are not MANEB papers."""
    flat = _squash(normalize(text)).upper()
    for marker in ("MOCK", "DIOCESE", "CLUSTEREXAMINATION", "SCHOOLEXAMINATION"):
        if marker in flat:
            return True
    return False


def extract_subject_code(text: str) -> str | None:
    """Return the three digit MANEB subject number, e.g. '022' or '131'."""
    flat = _squash(normalize(text)).upper()
    # 'M022', 'M131', 'MO22' (letter O for zero, leading zero lost by OCR).
    for m in re.finditer(r"M[O0]?(\d{2,3})", flat):
        digits = m.group(1)
        candidates = [digits]
        if len(digits) == 2:
            candidates.append("0" + digits)
        for cand in candidates:
            if cand in SUBJECT_CODES:
                return cand
    return None


def extract_year(text: str) -> int | None:
    """Year printed next to the board name on the paper header."""
    flat = normalize(text)
    # The year is often glued to the next word by OCR ("BOARD 2004MALAWI...").
    years = [
        int(y)
        for y in re.findall(r"(?<![0-9])(19[89][0-9]|20[0-2][0-9])(?![0-9])", flat)
    ]
    years = [y for y in years if 1990 <= y <= 2030]
    if not years:
        return None
    return max(years)


def extract_paper_number(text: str) -> int | None:
    """Paper I / II, from the 'PAPER x' label or from the subject number."""
    flat = _squash(normalize(text)).upper()
    patterns = (
        r"PAPER([IVX1-3]{1,3})",
        r"M[O0]?(\d{2,3})[/\\]?([IVX1-3]{1,3})",
    )
    for pattern in patterns:
        for m in re.finditer(pattern, flat):
            groups = [g for g in m.groups() if g]
            for tail in groups:
                if tail in _PAPER_WORDS:
                    return _PAPER_WORDS[tail]
                if tail.startswith("I") and 1 <= len(tail) <= 3:
                    return len(tail)
    return None


def extract_total_pages(text: str) -> int | None:
    """ "This paper contains 14 printed pages"."""
    flat = normalize(text)
    m = re.search(r"contains\s*(\d{1,3})\s*printed\s*\w{0,4}\s*pages", flat, re.I)
    if m:
        return int(m.group(1))
    flat2 = _squash(flat)
    m = re.search(r"contains(\d{1,3})printed\w{0,4}pages", flat2, re.I)
    if m:
        return int(m.group(1))
    return None


def extract_page_of(text: str) -> tuple[int, int] | None:
    """ "Page 3 of 14" -> (3, 14)."""
    flat = normalize(text)
    m = re.search(r"[Pp]age\s*(\d{1,3})\s*of\s*(\d{1,3})", flat)
    if m:
        return int(m.group(1)), int(m.group(2))
    flat2 = _squash(flat)
    m = re.search(r"[Pp]age(\d{1,3})[oO|]?[fF](\d{1,3})", flat2)
    if m:
        return int(m.group(1)), int(m.group(2))
    return None


def subject_name(text: str) -> str | None:
    """Subject name printed on the header line."""
    flat = normalize(text).upper()
    for name in (
        "ADDITIONAL MATHEMATICS",
        "MATHEMATICS",
        "BIOLOGY",
        "CHEMISTRY",
        "PHYSICS",
        "AGRICULTURE",
        "GEOGRAPHY",
        "CHICHEWA",
        "ENGLISH",
    ):
        if name in flat:
            return "Mathematics" if name == "ADDITIONAL MATHEMATICS" else name.title()
    return None


def parse_header(text: str) -> dict:
    """Extract every identifying field from one page of an exam paper."""
    out = {
        "maneb": looks_like_maneb(text),
        "mock": looks_like_mock(text),
        "subject_code": extract_subject_code(text),
        "subject": subject_name(text),
        "year": extract_year(text),
        "paper": extract_paper_number(text),
        "total_pages": extract_total_pages(text),
    }
    po = extract_page_of(text)
    out["page_no"] = po[0] if po else None
    out["page_total"] = po[1] if po else None
    return out


def classify_page(text: str) -> dict:
    """Parse a header and resolve the subject via the printed subject code."""
    info = parse_header(text)
    code = info["subject_code"]
    if code:
        info["subject_from_code"] = SUBJECT_CODES.get(code)
    else:
        info["subject_from_code"] = None
    subject = info["subject_from_code"] or info["subject"]
    info["resolved_subject"] = subject
    # "PAPER I (100 marks)" only appears on the cover sheet, and the board
    # identity only appears on that same sheet, so both together identify page 1.
    page_no = info.get("page_no")
    info["is_first_page"] = bool(
        info["maneb"]
        and not info["mock"]
        and subject in WANTED_SUBJECTS
        and info["paper"] in (1, 2)
        and not (page_no and page_no != 1)
    )
    return info
