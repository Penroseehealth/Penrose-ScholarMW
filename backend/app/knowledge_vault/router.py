from fastapi import APIRouter, Depends, File, UploadFile
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import User, VaultDocument
from app.schemas.research import VaultDocumentResponse

router = APIRouter(prefix="/vault", tags=["Knowledge Vault"])


@router.get("/", response_model=list[VaultDocumentResponse])
async def list_documents(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(VaultDocument).order_by(VaultDocument.created_at.desc())
    )
    return [VaultDocumentResponse.model_validate(d) for d in result.scalars().all()]


@router.post("/upload", response_model=VaultDocumentResponse)
async def upload_document(
    title: str,
    doc_type: str,
    course_id: int | None = None,
    tags: str | None = None,
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    import os

    from app.config.settings import get_settings

    settings = get_settings()
    os.makedirs(settings.MEDIA_DIR, exist_ok=True)
    file_path = os.path.join(settings.MEDIA_DIR, file.filename or "upload")
    content = await file.read()
    with open(file_path, "wb") as f:
        f.write(content)

    doc = VaultDocument(
        title=title,
        doc_type=doc_type,
        file_path=file_path,
        course_id=course_id,
        uploaded_by=user.id,
        tags=tags,
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
