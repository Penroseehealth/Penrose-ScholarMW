import os

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import Course, Enrollment, User, UserRole, VaultDocument
from app.schemas.research import VaultDocumentResponse

router = APIRouter(prefix="/vault", tags=["Knowledge Vault"])

MAX_FILE_SIZE = 50 * 1024 * 1024  # 50 MB
ALLOWED_EXTENSIONS = {".pdf", ".docx", ".txt", ".pptx", ".xlsx", ".csv", ".jpg", ".png"}


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
    return [VaultDocumentResponse.model_validate(d) for d in result.scalars().all()]


@router.post("/upload", response_model=VaultDocumentResponse)
async def upload_document(
    title: str,
    doc_type: str,
    course_id: int | None = None,
    tags: str | None = None,
    content: str | None = None,
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from app.config.settings import get_settings

    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File type '{ext}' not allowed. Allowed: {', '.join(sorted(ALLOWED_EXTENSIONS))}",
        )

    settings = get_settings()
    os.makedirs(settings.MEDIA_DIR, exist_ok=True)
    file_path = os.path.join(settings.MEDIA_DIR, file.filename or "upload")
    file_bytes = await file.read()
    if len(file_bytes) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="File size exceeds 50 MB limit",
        )
    with open(file_path, "wb") as f:
        f.write(file_bytes)

    doc = VaultDocument(
        title=title,
        doc_type=doc_type,
        file_path=file_path,
        course_id=course_id,
        uploaded_by=user.id,
        tags=tags,
        content=content,
    )
    db.add(doc)
    await db.commit()
    await db.refresh(doc)
    return VaultDocumentResponse.model_validate(doc)


@router.get("/search")
async def search_vault(
    q: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(VaultDocument).where(VaultDocument.title.ilike(f"%{q}%"))
    )
    return [VaultDocumentResponse.model_validate(d) for d in result.scalars().all()]
