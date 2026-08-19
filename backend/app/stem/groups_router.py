from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import User
from app.models.stem import STEMGroupMember, STEMGroupMessage, STEMStudyGroup

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])


class GroupCreate(BaseModel):
    name: str
    description: str | None = None
    subject_slug: str | None = None
    max_members: int = 10


class MessageCreate(BaseModel):
    message: str


class MemberResponse(BaseModel):
    id: int
    user_id: int
    role: str
    joined_at: str
    full_name: str


class MessageResponse(BaseModel):
    id: int
    user_id: int
    message: str
    created_at: str
    sender_full_name: str


class GroupResponse(BaseModel):
    id: int
    name: str
    description: str | None
    subject_slug: str | None
    creator_id: int
    max_members: int
    is_active: bool
    created_at: str
    member_count: int


class GroupDetailResponse(GroupResponse):
    members: list[MemberResponse]


def _member_to_response(m: STEMGroupMember, user: User) -> MemberResponse:
    return MemberResponse(
        id=m.id,
        user_id=m.user_id,
        role=m.role,
        joined_at=m.joined_at.isoformat(),
        full_name=user.full_name,
    )


def _message_to_response(m: STEMGroupMessage, user: User) -> MessageResponse:
    return MessageResponse(
        id=m.id,
        user_id=m.user_id,
        message=m.message,
        created_at=m.created_at.isoformat(),
        sender_full_name=user.full_name,
    )


def _group_to_response(g: STEMStudyGroup, member_count: int) -> GroupResponse:
    return GroupResponse(
        id=g.id,
        name=g.name,
        description=g.description,
        subject_slug=g.subject_slug,
        creator_id=g.creator_id,
        max_members=g.max_members,
        is_active=g.is_active,
        created_at=g.created_at.isoformat(),
        member_count=member_count,
    )


@router.get("/groups/mine", response_model=list[GroupResponse])
async def list_my_groups(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(STEMStudyGroup, func.count(STEMGroupMember.id).label("member_count"))
        .join(STEMGroupMember, STEMGroupMember.group_id == STEMStudyGroup.id)
        .where(STEMGroupMember.user_id == user.id)
        .group_by(STEMStudyGroup.id)
        .order_by(STEMStudyGroup.created_at.desc())
    )
    result = await db.execute(stmt)
    rows = result.all()
    return [_group_to_response(group, count) for group, count in rows]


@router.get("/groups", response_model=list[GroupResponse])
async def list_groups(
    subject_slug: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(STEMStudyGroup, func.count(STEMGroupMember.id).label("member_count"))
        .outerjoin(STEMGroupMember, STEMGroupMember.group_id == STEMStudyGroup.id)
        .where(STEMStudyGroup.is_active.is_(True))
        .group_by(STEMStudyGroup.id)
        .order_by(STEMStudyGroup.created_at.desc())
    )
    if subject_slug:
        stmt = stmt.where(STEMStudyGroup.subject_slug == subject_slug)
    result = await db.execute(stmt)
    rows = result.all()
    return [_group_to_response(group, count) for group, count in rows]


@router.get("/groups/{id}", response_model=GroupDetailResponse)
async def get_group(
    id: int,
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(STEMStudyGroup)
        .options(joinedload(STEMStudyGroup.members))
        .where(STEMStudyGroup.id == id)
    )
    result = await db.execute(stmt)
    group = result.unique().scalar_one_or_none()
    if not group:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Group not found"
        )

    member_responses: list[MemberResponse] = []
    for m in group.members:
        user_result = await db.execute(select(User).where(User.id == m.user_id))
        member_user = user_result.scalar_one_or_none()
        if member_user:
            member_responses.append(_member_to_response(m, member_user))

    return GroupDetailResponse(
        id=group.id,
        name=group.name,
        description=group.description,
        subject_slug=group.subject_slug,
        creator_id=group.creator_id,
        max_members=group.max_members,
        is_active=group.is_active,
        created_at=group.created_at.isoformat(),
        member_count=len(member_responses),
        members=member_responses,
    )


@router.post(
    "/groups", response_model=GroupResponse, status_code=status.HTTP_201_CREATED
)
async def create_group(
    body: GroupCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    group = STEMStudyGroup(
        name=body.name,
        description=body.description,
        subject_slug=body.subject_slug,
        max_members=body.max_members,
        creator_id=user.id,
    )
    db.add(group)
    await db.flush()

    member = STEMGroupMember(
        group_id=group.id,
        user_id=user.id,
        role="admin",
    )
    db.add(member)
    await db.commit()
    await db.refresh(group)

    return _group_to_response(group, 1)


@router.post("/groups/{id}/join", status_code=status.HTTP_200_OK)
async def join_group(
    id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(STEMStudyGroup).where(STEMStudyGroup.id == id))
    group = result.scalar_one_or_none()
    if not group:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Group not found"
        )
    if not group.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Group is not active"
        )

    existing = await db.execute(
        select(STEMGroupMember).where(
            STEMGroupMember.group_id == id,
            STEMGroupMember.user_id == user.id,
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Already a member"
        )

    count_result = await db.execute(
        select(func.count(STEMGroupMember.id)).where(STEMGroupMember.group_id == id)
    )
    current_count = count_result.scalar()
    if current_count >= group.max_members:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Group is full"
        )

    member = STEMGroupMember(group_id=id, user_id=user.id)
    db.add(member)
    await db.commit()
    return {"detail": "Joined group"}


@router.post("/groups/{id}/leave", status_code=status.HTTP_200_OK)
async def leave_group(
    id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STEMGroupMember).where(
            STEMGroupMember.group_id == id,
            STEMGroupMember.user_id == user.id,
        )
    )
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Not a member of this group"
        )

    group_result = await db.execute(
        select(STEMStudyGroup).where(STEMStudyGroup.id == id)
    )
    group = group_result.scalar_one_or_none()
    if group and group.creator_id == user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Creator cannot leave the group",
        )

    await db.delete(member)
    await db.commit()
    return {"detail": "Left group"}


@router.get("/groups/{id}/messages", response_model=list[MessageResponse])
async def list_messages(
    id: int,
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(STEMGroupMessage)
        .where(STEMGroupMessage.group_id == id)
        .order_by(STEMGroupMessage.created_at.asc())
    )
    result = await db.execute(stmt)
    messages = result.scalars().all()

    responses: list[MessageResponse] = []
    for m in messages:
        user_result = await db.execute(select(User).where(User.id == m.user_id))
        sender = user_result.scalar_one_or_none()
        if sender:
            responses.append(_message_to_response(m, sender))
    return responses


@router.post(
    "/groups/{id}/messages",
    response_model=MessageResponse,
    status_code=status.HTTP_201_CREATED,
)
async def send_message(
    id: int,
    body: MessageCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(STEMStudyGroup).where(STEMStudyGroup.id == id))
    group = result.scalar_one_or_none()
    if not group:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Group not found"
        )

    member_result = await db.execute(
        select(STEMGroupMember).where(
            STEMGroupMember.group_id == id,
            STEMGroupMember.user_id == user.id,
        )
    )
    if not member_result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Must be a member to send messages",
        )

    msg = STEMGroupMessage(
        group_id=id,
        user_id=user.id,
        message=body.message,
    )
    db.add(msg)
    await db.commit()
    await db.refresh(msg)

    return _message_to_response(msg, user)
