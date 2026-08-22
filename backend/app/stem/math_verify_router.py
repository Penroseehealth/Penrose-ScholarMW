from fastapi import APIRouter, Depends

from app.dependencies.auth import get_current_user
from app.schemas.stem.math_verify import (
    MathVerifyRequest,
    MathVerifyResponse,
    verify_math_expression,
)

router = APIRouter(prefix="/stem/math", tags=["STEM Math Verification"])


@router.post("/verify", response_model=MathVerifyResponse)
async def verify_expression(
    body: MathVerifyRequest,
    _user=Depends(get_current_user),
):
    return await verify_math_expression(body)
