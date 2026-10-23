"""Self-checks for the MANEB header parser (run: python tools/test_msce_verify.py)."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from msce_verify import classify_page, looks_like_maneb, looks_like_mock  # noqa: E402

CASES = [
    (
        "clean maths 2023",
        "EXAMINATION NO.: THE MALAWI NATIONAL EXAMINATIONS BOARD 2023 MALAWI SCHOOL "
        "CERTIFICATE OF EDUCATION EXAMINATION MATHEMATICS Subject Number: M131/I "
        "Wednesday, 5 July Time Allowed: 2 hours 8:00 - 10:00 am PAPER I (100 marks) "
        "Instructions 1. This paper contains 14 printed pages. Please check.",
        dict(is_first_page=True, year=2023, subject="Mathematics", paper=1,
             subject_code="131", total_pages=14),
    ),
    (
        "clean maths 2023 paper II",
        "EXAMINATION NO: THE MALAWI NATIONAL EXAMINATIONS BOARD 2023 MALAWI SCHOOL "
        "CERTIFICATE OF EDUCATION EXAMINATION MATHEMATICS Subject Number: M131/II "
        "Friday, 7 July Time Allowed: 2 30 min 8:00 - 10:30 am PAPER II (100 marks)",
        dict(is_first_page=True, year=2023, subject="Mathematics", paper=2,
             subject_code="131"),
    ),
    (
        "clean biology 2026",
        "2026 MALAWI SCHOOL CERTIFICATE OF EDUCATION EXAMINATION BIOLOGY Subject "
        "Number: M022/1 Tuesday, 30 June PAPER I Theory (100 marks) Instructions: "
        "This paper contains 12 printed pages. Please check.",
        dict(is_first_page=True, year=2026, subject="Biology", paper=1,
             subject_code="022", total_pages=12),
    ),
    (
        "ocr-garbled biology 2004",
        "\u2168AMINAT10NNO\uff0e\uff1a THEMAL\u7891INATIONAI\uff0eEXAMINATIONS BOARD "
        "2004MALA\u2165SCHOOLCERTIFICATEOFEDUCATION EXAMINATION TlleSday\uff0c"
        "120ctober Instructions BIOLOGY SubjectNumber\uff1aMO22\uff0fI "
        "TimeAllowed\uff1a2h30minS 8\uff1a30\uff0d11\uff1a00am PAPERI \uff08100ma"
        "\u6b62S\uff09 TIIEORY Thispapercontains12printedpages.",
        dict(is_first_page=True, year=2004, subject="Biology", paper=1,
             subject_code="022", total_pages=12),
    ),
    (
        "ocr maths paper ii",
        "NALEXAMINATIONSBOARD MATHEMATICS Subject Number: M131/II Wednesday,28 June "
        "TimeAllowed: 2h30mins 8:00-10:30am PAPERII (100marks)",
        dict(is_first_page=True, subject="Mathematics", paper=2, subject_code="131"),
    ),
    (
        "mock paper must be rejected",
        "NAME OF STUDENT ______ FORM 4 KARONGA DIOCESE 2020 MALAWI SCHOOL CERTIFICATE "
        "OF EDUCATION MOCK EXAMINATIONS ADDITIONAL MATHEMATICS PAPER I (100 marks) "
        "Subject Number: 132/I",
        dict(is_first_page=False, mock=True),
    ),
    (
        "question bank must be rejected",
        "1 Photosynthesis - Questions Section A [2012-2] Figure 1 shows part of a leaf. "
        "Use it to answer the questions that follow.",
        dict(is_first_page=False, maneb=False),
    ),
]


def main() -> int:
    failures = 0
    for label, text, expect in CASES:
        info = classify_page(text)
        for key, want in expect.items():
            got = info.get(key)
            if got != want:
                failures += 1
                print(f"FAIL [{label}] {key}: expected {want!r}, got {got!r}")
        if not expect.get("is_first_page"):
            if info.get("is_first_page"):
                failures += 1
                print(f"FAIL [{label}] should not be a first page")
        print(f"  {'ok  ' if not failures else '..  '}{label}: {info}")

    assert looks_like_maneb(CASES[0][1])
    assert not looks_like_mock(CASES[0][1])
    assert looks_like_mock(CASES[5][1])
    assert not looks_like_maneb(CASES[6][1])

    if failures:
        print(f"\n{failures} failure(s)")
        return 1
    print("\nall verifier checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
