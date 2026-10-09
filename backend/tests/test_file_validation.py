"""Tests for upload validation and text extraction."""

import pytest

from app.services.file_validation import (
    extract_file_content,
    extract_text_content,
    validate_upload,
)


def test_txt_upload_is_accepted_and_readable():
    """A .txt attachment is the common case, so its contents must reach the tutor."""
    body = b"Solve 3x + 4 = 19\nWhat is 15% of 200?"
    validated = validate_upload("notes.txt", body)

    assert not isinstance(validated, str)
    assert validated.file_type == "text"
    assert validated.mime_type == "text/plain"


def test_unknown_extension_is_rejected():
    result = validate_upload("malware.exe", b"MZ")

    assert isinstance(result, str)
    assert "Unsupported file format" in result


def test_empty_file_is_rejected():
    assert isinstance(validate_upload("notes.txt", b""), str)


def test_oversized_file_is_rejected():
    from app.services.file_validation import MAX_FILE_SIZE_BYTES

    result = validate_upload("notes.txt", b"a" * (MAX_FILE_SIZE_BYTES + 1))

    assert isinstance(result, str)
    assert "File too large" in result


def test_corrupt_pdf_is_rejected():
    assert isinstance(validate_upload("paper.pdf", b"not-a-pdf"), str)


@pytest.mark.asyncio
async def test_text_content_is_extracted_not_reported_unsupported():
    body = b"Solve 3x + 4 = 19"
    validated = validate_upload("notes.txt", body)

    extracted = await extract_file_content(validated)

    assert extracted == "Solve 3x + 4 = 19"
    assert "Unsupported" not in extracted


@pytest.mark.asyncio
async def test_non_utf8_text_does_not_raise():
    validated = validate_upload("notes.txt", b"\xff\xfe question")

    extracted = await extract_file_content(validated)

    assert isinstance(extracted, str)
    assert extracted


def test_empty_text_reports_placeholder():
    assert extract_text_content(b"   ") == "(Empty text file)"
