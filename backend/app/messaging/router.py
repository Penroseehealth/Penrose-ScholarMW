from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import Conversation, ConversationMember, Message, User

router = APIRouter(prefix="/messaging", tags=["Messaging"])


class ConversationCreate(BaseModel):
    title: str | None = None
    member_ids: list[int]


class ConversationResponse(BaseModel):
    id: int
    title: str | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class MessageCreate(BaseModel):
    content: str


class MessageResponse(BaseModel):
    id: int
    conversation_id: int
    sender_id: int
    content: str
    created_at: datetime
    is_read: bool

    model_config = {"from_attributes": True}


async def _get_conversation_or_404(
    conv_id: int, user: User, db: AsyncSession
) -> Conversation:
    result = await db.execute(
        select(ConversationMember).where(
            ConversationMember.conversation_id == conv_id,
            ConversationMember.user_id == user.id,
        )
    )
    if result.scalar_one_or_none() is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found",
        )
    conv_result = await db.execute(
        select(Conversation).where(Conversation.id == conv_id)
    )
    return conv_result.scalar_one()


@router.post(
    "/conversations",
    response_model=ConversationResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_conversation(
    body: ConversationCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    conv = Conversation(title=body.title)
    db.add(conv)
    await db.flush()
    db.add(ConversationMember(conversation_id=conv.id, user_id=user.id))
    for mid in body.member_ids:
        if mid != user.id:
            db.add(ConversationMember(conversation_id=conv.id, user_id=mid))
    await db.commit()
    await db.refresh(conv)
    return ConversationResponse.model_validate(conv)


@router.get("/conversations", response_model=list[ConversationResponse])
async def list_conversations(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Conversation)
        .join(ConversationMember, ConversationMember.conversation_id == Conversation.id)
        .where(ConversationMember.user_id == user.id)
        .order_by(Conversation.created_at.desc())
    )
    return [ConversationResponse.model_validate(c) for c in result.scalars().all()]


@router.get("/conversations/{conv_id}/messages", response_model=list[MessageResponse])
async def get_messages(
    conv_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await _get_conversation_or_404(conv_id, user, db)
    result = await db.execute(
        select(Message)
        .where(Message.conversation_id == conv_id)
        .order_by(Message.created_at.asc())
    )
    return [MessageResponse.model_validate(m) for m in result.scalars().all()]


@router.post(
    "/conversations/{conv_id}/messages",
    response_model=MessageResponse,
    status_code=status.HTTP_201_CREATED,
)
async def send_message(
    conv_id: int,
    body: MessageCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await _get_conversation_or_404(conv_id, user, db)
    msg = Message(conversation_id=conv_id, sender_id=user.id, content=body.content)
    db.add(msg)
    await db.commit()
    await db.refresh(msg)
    return MessageResponse.model_validate(msg)


@router.put("/conversations/{conv_id}/read")
async def mark_conversation_read(
    conv_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await _get_conversation_or_404(conv_id, user, db)
    result = await db.execute(
        select(Message).where(
            Message.conversation_id == conv_id,
            Message.sender_id != user.id,
            Message.is_read.is_(False),
        )
    )
    for msg in result.scalars().all():
        msg.is_read = True
    await db.commit()
    return {"detail": "Messages marked as read"}
