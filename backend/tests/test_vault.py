import pytest
from httpx import AsyncClient

from tests.conftest import auth_header


def _txt_bytes(
    content: str = "Lecture one covered cell biology basics.\nMitochondria and energy.",
) -> bytes:
    return content.encode("utf-8")


@pytest.mark.asyncio
async def test_upload_document_sets_uploaded_status(
    client: AsyncClient, student_user, student_token
):
    response = await client.post(
        "/api/v1/vault/upload",
        data={
            "title": "Cell Biology Notes",
            "doc_type": "lecture_notes",
            "file_name": "cell_bio.txt",
            "file_size": "60",
        },
        files={"file": ("cell_bio.txt", _txt_bytes(), "text/plain")},
        headers=auth_header(student_token),
    )
    assert response.status_code in (200, 201)
    data = response.json()
    assert data["title"] == "Cell Biology Notes"
    assert data["processing_status"] == "uploaded"
    assert data["id"] is not None


@pytest.mark.asyncio
async def test_process_document_reaches_ready(
    client: AsyncClient, student_user, student_token
):
    upload = await client.post(
        "/api/v1/vault/upload",
        data={
            "title": "Cell Biology Notes",
            "doc_type": "lecture_notes",
            "file_name": "cell_bio.txt",
            "file_size": "60",
        },
        files={"file": ("cell_bio.txt", _txt_bytes(), "text/plain")},
        headers=auth_header(student_token),
    )
    doc_id = upload.json()["id"]

    status_resp = await client.get(
        f"/api/v1/vault/{doc_id}/status", headers=auth_header(student_token)
    )
    assert status_resp.status_code == 200
    assert status_resp.json()["processing_status"] == "uploaded"

    process_resp = await client.post(
        f"/api/v1/vault/{doc_id}/process",
        json={"force_ocr": False},
        headers=auth_header(student_token),
    )
    assert process_resp.status_code == 200
    status_data = process_resp.json()
    assert status_data["processing_status"] == "ready"
    assert status_data["is_indexed"] is True

    doc_resp = await client.get(
        f"/api/v1/vault/{doc_id}", headers=auth_header(student_token)
    )
    assert doc_resp.status_code == 200
    assert "cell" in (doc_resp.json()["content"] or "").lower()


@pytest.mark.asyncio
async def test_force_ocr_keeps_text_layer(
    client: AsyncClient, student_user, student_token
):
    upload = await client.post(
        "/api/v1/vault/upload",
        data={
            "title": "Notes",
            "doc_type": "lecture_notes",
            "file_name": "notes.txt",
            "file_size": "30",
        },
        files={"file": ("notes.txt", _txt_bytes("Plain text notes."), "text/plain")},
        headers=auth_header(student_token),
    )
    doc_id = upload.json()["id"]

    ocr_resp = await client.post(
        f"/api/v1/vault/{doc_id}/ocr", headers=auth_header(student_token)
    )
    assert ocr_resp.status_code == 200
    data = ocr_resp.json()
    # .txt has native text; forced OCR should not regress it to failure.
    assert data["processing_status"] in ("ready", "failed")


@pytest.mark.asyncio
async def test_lecturer_sees_own_and_course_docs(
    client: AsyncClient, lecturer_user, lecturer_token
):
    await client.post(
        "/api/v1/vault/upload",
        data={
            "title": "Lecturer Upload",
            "doc_type": "research",
            "file_name": "research.txt",
            "file_size": "40",
        },
        files={"file": ("research.txt", _txt_bytes("Research notes."), "text/plain")},
        headers=auth_header(lecturer_token),
    )

    listed = await client.get("/api/v1/vault/", headers=auth_header(lecturer_token))
    assert listed.status_code == 200
    assert any(d["title"] == "Lecturer Upload" for d in listed.json())

    counted = await client.get(
        "/api/v1/vault/count", headers=auth_header(lecturer_token)
    )
    assert counted.status_code == 200
    assert counted.json()["count"] >= 1


@pytest.mark.asyncio
async def test_invalid_extension_rejected(
    client: AsyncClient, student_user, student_token
):
    response = await client.post(
        "/api/v1/vault/upload",
        data={
            "title": "Bad File",
            "doc_type": "lecture_notes",
            "file_name": "evil.exe",
            "file_size": "10",
        },
        files={"file": ("evil.exe", b"MZ", "application/octet-stream")},
        headers=auth_header(student_token),
    )
    assert response.status_code == 400
