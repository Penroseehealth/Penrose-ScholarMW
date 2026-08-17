from fastapi import APIRouter, Depends

from app.dependencies.auth import get_current_user

router = APIRouter(prefix="/messaging", tags=["Messaging"])


@router.get("/conversations")
async def list_conversations(user=Depends(get_current_user)):
    return []


@router.get("/conversations/{conv_id}/messages")
async def get_messages(conv_id: int, user=Depends(get_current_user)):
    return []
