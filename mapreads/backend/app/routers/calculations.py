from fastapi import APIRouter

from ..schemas.calculations import CalculationRequest, CalculationResponse
from ..services.calculations import calculate


router = APIRouter(prefix="/api/calculations", tags=["calculations"])


@router.post("", response_model=CalculationResponse)
def calculate_map_value(request: CalculationRequest) -> CalculationResponse:
    return CalculationResponse(kind=request.kind, result=calculate(request))
