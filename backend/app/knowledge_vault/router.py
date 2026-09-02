import mimetypes
import os
import re
import uuid

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import Course, Enrollment, User, UserRole, VaultDocument
from app.schemas.research import VaultDocumentResponse

router = APIRouter(prefix="/vault", tags=["Knowledge Vault"])

ALLOWED_EXTENSIONS = {
    ".pdf",
    ".docx",
    ".txt",
    ".pptx",
    ".xlsx",
    ".csv",
    ".jpg",
    ".jpeg",
    ".png",
    ".mp4",
    ".webm",
    ".mov",
    ".mkv",
    ".avi",
}
_MIME_BY_EXT = {
    ".pdf": "application/pdf",
    ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    ".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    ".txt": "text/plain",
    ".csv": "text/csv",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".mp4": "video/mp4",
    ".webm": "video/webm",
    ".mov": "video/quicktime",
    ".mkv": "video/x-matroska",
    ".avi": "video/x-msvideo",
}


def _mime_type(name: str | None) -> str | None:
    ext = os.path.splitext(name or "")[1].lower()
    if ext in _MIME_BY_EXT:
        return _MIME_BY_EXT[ext]
    if name:
        return mimetypes.guess_type(name)[0]
    return None


def _safe_filename(filename: str | None) -> str:
    """Keep only the basename and strip path separators to block traversal."""
    base = os.path.basename((filename or "upload").replace("\\", "/"))
    base = re.sub(r"[^A-Za-z0-9._\-\u00C0-\uFFFF ]", "_", base).strip()
    return base or "upload"


def _to_response(doc: VaultDocument) -> VaultDocumentResponse:
    """Serialize a vault doc, exposing a safe download path instead of the disk path."""
    data = VaultDocumentResponse.model_validate(doc).model_dump()
    data["mime_type"] = _mime_type(doc.file_name or doc.file_path)
    return VaultDocumentResponse(**data)


@router.get("/", response_model=list[VaultDocumentResponse])
async def list_documents(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if user.role == UserRole.ADMIN:
        result = await db.execute(
            select(VaultDocument).order_by(VaultDocument.created_at.desc())
        )
    elif user.role == UserRole.LECTURER:
        result = await db.execute(
            select(VaultDocument)
            .join(Course, Course.id == VaultDocument.course_id)
            .where(Course.lecturer_id == user.id)
            .order_by(VaultDocument.created_at.desc())
        )
    else:
        enrolled_course_ids = (
            (
                await db.execute(
                    select(Enrollment.course_id).where(
                        Enrollment.student_id == user.id,
                        Enrollment.is_active.is_(True),
                    )
                )
            )
            .scalars()
            .all()
        )
        result = await db.execute(
            select(VaultDocument)
            .where(
                or_(
                    VaultDocument.course_id.in_(enrolled_course_ids),
                    VaultDocument.uploaded_by == user.id,
                )
            )
            .order_by(VaultDocument.created_at.desc())
        )
    return [_to_response(d) for d in result.scalars().all()]


@router.post("/upload", response_model=VaultDocumentResponse)
async def upload_document(
    title: str = Form(...),
    doc_type: str = Form(...),
    course_id: int | None = Form(None),
    tags: str | None = Form(None),
    content: str | None = Form(None),
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from app.config.settings import get_settings

    settings = get_settings()

    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File type '{ext}' not allowed. Allowed: {', '.join(sorted(ALLOWED_EXTENSIONS))}",
        )

    os.makedirs(settings.MEDIA_DIR, exist_ok=True)
    original_name = _safe_filename(file.filename)
    stored_name = f"{uuid.uuid4().hex[:12]}_{original_name}"
    file_path = os.path.join(settings.MEDIA_DIR, stored_name)
    file_bytes = await file.read()
    max_bytes = settings.VAULT_MAX_FILE_SIZE_MB * 1024 * 1024
    if len(file_bytes) > max_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=(
                f"File size exceeds {settings.VAULT_MAX_FILE_SIZE_MB} MB limit. "
                "Adjust VAULT_MAX_FILE_SIZE_MB in the backend .env to raise it."
            ),
        )
    with open(file_path, "wb") as f:
        f.write(file_bytes)

    doc = VaultDocument(
        title=title,
        doc_type=doc_type,
        file_path=file_path,
        file_name=file.filename,
        file_size=len(file_bytes),
        course_id=course_id,
        uploaded_by=user.id,
        tags=tags,
        content=content,
    )
    db.add(doc)
    await db.commit()
    await db.refresh(doc)
    return _to_response(doc)


@router.get("/search")
async def search_vault(
    q: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(VaultDocument).where(VaultDocument.title.ilike(f"%{q}%"))
    )
    return [_to_response(d) for d in result.scalars().all()]


@router.get("/count")
async def count_documents(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import func

    if user.role == UserRole.ADMIN:
        count_result = await db.execute(select(func.count()).select_from(VaultDocument))
    elif user.role == UserRole.LECTURER:
        count_result = await db.execute(
            select(func.count())
            .select_from(VaultDocument)
            .join(Course, Course.id == VaultDocument.course_id)
            .where(Course.lecturer_id == user.id)
        )
    else:
        enrolled_course_ids = (
            (
                await db.execute(
                    select(Enrollment.course_id).where(
                        Enrollment.student_id == user.id,
                        Enrollment.is_active.is_(True),
                    )
                )
            )
            .scalars()
            .all()
        )
        count_result = await db.execute(
            select(func.count()).where(
                or_(
                    VaultDocument.course_id.in_(enrolled_course_ids),
                    VaultDocument.uploaded_by == user.id,
                )
            )
        )
    return {"count": count_result.scalar() or 0}


async def _authorized_doc(db: AsyncSession, user: User, doc_id: int) -> VaultDocument:
    """Load a doc and enforce the same role-based scoping as the list endpoint."""
    result = await db.execute(select(VaultDocument).where(VaultDocument.id == doc_id))
    doc = result.scalar_one_or_none()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")
    if user.role == UserRole.ADMIN:
        return doc
    if user.role == UserRole.LECTURER:
        if doc.course_id is None:
            if doc.uploaded_by != user.id:
                raise HTTPException(
                    status_code=403, detail="Not authorized to access this document"
                )
            return doc
        course = (
            await db.execute(select(Course).where(Course.id == doc.course_id))
        ).scalar_one_or_none()
        if course is not None and course.lecturer_id == user.id:
            return doc
        if doc.uploaded_by == user.id:
            return doc
        raise HTTPException(
            status_code=403, detail="Not authorized to access this document"
        )
    enrolled = (
        (
            await db.execute(
                select(Enrollment.course_id).where(
                    Enrollment.student_id == user.id,
                    Enrollment.is_active.is_(True),
                )
            )
        )
        .scalars()
        .all()
    )
    if doc.uploaded_by == user.id or (
        doc.course_id is not None and doc.course_id in enrolled
    ):
        return doc
    raise HTTPException(
        status_code=403, detail="Not authorized to access this document"
    )


@router.get("/{doc_id}/download")
async def download_document(
    doc_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    doc = await _authorized_doc(db, user, doc_id)
    if not os.path.exists(doc.file_path):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="File not found on disk",
        )
    file_name = doc.file_name or os.path.basename(doc.file_path)
    media_type = _mime_type(file_name) or "application/octet-stream"
    return FileResponse(path=doc.file_path, media_type=media_type, filename=file_name)


@router.get("/{doc_id}", response_model=VaultDocumentResponse)
async def get_document(
    doc_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    doc = await _authorized_doc(db, user, doc_id)
    return _to_response(doc)


@router.delete("/{doc_id}", status_code=204)
async def delete_document(
    doc_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    doc = await _authorized_doc(db, user, doc_id)
    if doc.file_path and os.path.exists(doc.file_path):
        try:
            os.remove(doc.file_path)
        except OSError:
            pass
    await db.delete(doc)
    await db.commit()
