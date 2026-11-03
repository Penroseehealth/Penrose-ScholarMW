import math

from fastapi import HTTPException

from ..schemas.calculations import CalculationRequest


def calculate(request: CalculationRequest) -> dict[str, float | int | str]:
    a = request.a
    b = request.b
    if request.kind == "grid_reference":
        east = request.easting_origin + a.x
        north = request.northing_origin + a.y
        digits = request.digits // 2
        unit = 1000 if digits == 2 else 100
        def part(value: float) -> str:
            return str(math.floor(value % 100000 / unit)).zfill(digits)
        return {"grid_reference": part(east) + part(north)}

    if b is None:
        raise HTTPException(status_code=422, detail="This calculation requires point B")
    distance = math.hypot(b.x - a.x, b.y - a.y)
    if request.kind == "distance":
        return {
            "ground_metres": distance,
            "map_centimetres": distance * 100 / request.scale,
        }
    if request.kind == "bearing":
        bearing = math.degrees(math.atan2(b.x - a.x, b.y - a.y)) % 360
        return {"degrees": round(bearing, 1)}
    if request.vertical_interval is None:
        raise HTTPException(status_code=422, detail="Gradient requires vertical_interval")
    if distance <= 0:
        raise HTTPException(status_code=422, detail="Horizontal distance must be greater than zero")
    interval = request.vertical_interval
    return {
        "ratio": "level" if interval == 0 else f"1:{round(distance / abs(interval))}",
        "percent": round(abs(interval) / distance * 100, 2),
    }
