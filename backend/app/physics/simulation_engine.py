"""Closed-form simulation models for animated physics.

A model is a small dictionary: initial conditions, constants, piecewise
closed-form segments and a slider description for every parameter. Python
emits the model once; the Flutter animation controller evaluates it every
frame, so the moving picture is always exactly the equations on the board
and the student can drag a slider and watch the physics respond.

:func:`evaluate` reimplements the same evaluation in Python so the test suite
can assert that the animation state matches the analytic solution.
"""

from __future__ import annotations

import math
from typing import Any, Callable

from app.physics.interpreter import DEFAULT_GRAVITY


def _slider(
    name: str, symbol: str, value: float, low: float, high: float, unit: str
) -> dict[str, Any]:
    return {
        "name": name,
        "symbol": symbol,
        "value": round(value, 6),
        "min": low,
        "max": high,
        "unit": unit,
    }


def projectile_model(
    speed: float,
    angle_deg: float,
    gravity: float = DEFAULT_GRAVITY,
    height: float = 0.0,
) -> dict[str, Any]:
    angle = math.radians(angle_deg)
    vx = speed * math.cos(angle)
    vy = speed * math.sin(angle)
    flight = (vy + math.sqrt(max(vy * vy + 2 * gravity * height, 0.0))) / gravity
    apex = height + vy * vy / (2 * gravity) if flight > 0 else height
    return {
        "kind": "projectile",
        "duration": round(flight, 6),
        "dt": round(max(flight / 120, 0.01), 6),
        "params": {
            "speed": speed,
            "angle_deg": angle_deg,
            "gravity": gravity,
            "height": height,
        },
        "constants": {"g": gravity, "vx": round(vx, 9), "vy": round(vy, 9)},
        "segments": [
            {
                "t0": 0.0,
                "t1": round(flight, 9),
                "x0": 0.0,
                "y0": height,
                "vx": round(vx, 9),
                "vy": round(vy, 9),
                "g": gravity,
            }
        ],
        "marks": [
            {"time": 0.0, "label": "launch"},
            {"time": round(flight, 6), "label": "landing"},
        ],
        "sliders": [
            _slider("Initial speed", "v0", speed, 1.0, 100.0, "m/s"),
            _slider("Launch angle", "angle", angle_deg, 5.0, 85.0, "degrees"),
            _slider("Gravity", "g", gravity, 0.0, 25.0, "m/s^2"),
            _slider("Launch height", "h0", height, 0.0, 50.0, "m"),
        ],
        "derived": {"apex": round(apex, 6)},
    }


def free_fall_model(height: float, gravity: float = DEFAULT_GRAVITY) -> dict[str, Any]:
    flight = math.sqrt(2 * height / gravity) if height > 0 else 0.0
    return {
        "kind": "projectile",
        "duration": round(flight, 6),
        "dt": round(max(flight / 100, 0.01), 6),
        "params": {"height": height, "gravity": gravity},
        "constants": {"g": gravity, "vx": 0.0, "vy": 0.0},
        "segments": [
            {
                "t0": 0.0,
                "t1": round(flight, 9),
                "x0": 0.0,
                "y0": height,
                "vx": 0.0,
                "vy": 0.0,
                "g": gravity,
            }
        ],
        "marks": [{"time": round(flight, 6), "label": "impact"}],
        "sliders": [
            _slider("Drop height", "h0", height, 1.0, 200.0, "m"),
            _slider("Gravity", "g", gravity, 0.0, 25.0, "m/s^2"),
        ],
        "derived": {"impact_speed": round(gravity * flight, 6)},
    }


def pendulum_model(
    length: float,
    gravity: float = DEFAULT_GRAVITY,
    amplitude_deg: float = 10.0,
) -> dict[str, Any]:
    omega = math.sqrt(gravity / length) if length > 0 else 0.0
    period = 2 * math.pi / omega if omega else 0.0
    return {
        "kind": "pendulum",
        "duration": round(max(period * 3.0, 0.1), 6),
        "dt": round(max(period / 80, 0.005), 6),
        "params": {
            "length": length,
            "gravity": gravity,
            "amplitude_deg": amplitude_deg,
        },
        "constants": {
            "omega": round(omega, 9),
            "amplitude_rad": round(math.radians(amplitude_deg), 9),
            "length": length,
            "period": round(period, 6),
        },
        "segments": [
            {
                "t0": 0.0,
                "t1": round(max(period * 3.0, 0.1), 9),
                "omega": round(omega, 9),
                "amplitude_rad": round(math.radians(amplitude_deg), 9),
                "phase": 0.0,
            }
        ],
        "marks": [],
        "sliders": [
            _slider("Length", "L", length, 0.2, 5.0, "m"),
            _slider("Amplitude", "theta0", amplitude_deg, 2.0, 30.0, "degrees"),
            _slider("Gravity", "g", gravity, 0.5, 25.0, "m/s^2"),
        ],
        "derived": {"period": round(period, 6)},
    }


def spring_model(
    mass: float,
    spring_constant: float,
    extension: float = 0.1,
    initial_speed: float = 0.0,
) -> dict[str, Any]:
    omega = math.sqrt(spring_constant / mass) if mass > 0 else 0.0
    period = 2 * math.pi / omega if omega else 0.0
    amplitude = (
        math.sqrt(extension**2 + (initial_speed / omega) ** 2)
        if omega
        else abs(extension)
    )
    phase = math.atan2(-initial_speed / omega, extension) if omega else 0.0
    return {
        "kind": "spring",
        "duration": round(max(period * 3.0, 0.1), 6),
        "dt": round(max(period / 80, 0.005), 6),
        "params": {
            "mass": mass,
            "spring_constant": spring_constant,
            "extension": extension,
        },
        "constants": {
            "omega": round(omega, 9),
            "amplitude": round(amplitude, 9),
            "phase": round(phase, 9),
        },
        "segments": [
            {
                "t0": 0.0,
                "t1": round(max(period * 3.0, 0.1), 9),
                "omega": round(omega, 9),
                "amplitude": round(amplitude, 9),
                "phase": round(phase, 9),
            }
        ],
        "marks": [],
        "sliders": [
            _slider("Mass", "m", mass, 0.1, 20.0, "kg"),
            _slider("Spring constant", "k", spring_constant, 1.0, 500.0, "N/m"),
            _slider("Initial extension", "x0", extension, 0.01, 1.0, "m"),
        ],
        "derived": {"period": round(period, 6), "omega": round(omega, 6)},
    }


def collision_model(
    m1: float,
    u1: float,
    m2: float,
    u2: float,
    elastic: bool,
    separation: float = 2.0,
    duration: float = 6.0,
) -> dict[str, Any]:
    if elastic:
        v1 = ((m1 - m2) * u1 + 2 * m2 * u2) / (m1 + m2)
        v2 = ((m2 - m1) * u2 + 2 * m1 * u1) / (m1 + m2)
    else:
        shared = (m1 * u1 + m2 * u2) / (m1 + m2)
        v1 = shared
        v2 = shared
    contact = separation / max(abs(u1 - u2), 1e-9)
    contact = min(contact, duration)
    x1_contact = u1 * contact
    x2_contact = separation + u2 * contact
    return {
        "kind": "collision",
        "duration": duration,
        "dt": round(duration / 120, 6),
        "params": {"m1": m1, "u1": u1, "m2": m2, "u2": u2, "elastic": elastic},
        "constants": {"v1": round(v1, 9), "v2": round(v2, 9), "separation": separation},
        "segments": [
            {"t0": 0.0, "t1": round(contact, 9), "x0": 0.0, "velocity": u1, "body": 1},
            {
                "t0": 0.0,
                "t1": round(contact, 9),
                "x0": separation,
                "velocity": u2,
                "body": 2,
            },
            {
                "t0": round(contact, 9),
                "t1": duration,
                "x0": round(x1_contact, 9),
                "velocity": round(v1, 9),
                "body": 1,
            },
            {
                "t0": round(contact, 9),
                "t1": duration,
                "x0": round(x2_contact, 9),
                "velocity": round(v2, 9),
                "body": 2,
            },
        ],
        "marks": [{"time": round(contact, 6), "label": "collision"}],
        "sliders": [
            _slider("Mass A", "m1", m1, 0.5, 50.0, "kg"),
            _slider("Velocity A", "u1", u1, -20.0, 20.0, "m/s"),
            _slider("Mass B", "m2", m2, 0.5, 50.0, "kg"),
            _slider("Velocity B", "u2", u2, -20.0, 20.0, "m/s"),
        ],
        "derived": {"v1": round(v1, 6), "v2": round(v2, 6)},
    }


def charge_motion_model(
    mass: float,
    charge_c: float,
    field: float,
    initial_speed: float = 0.0,
    width: float = 4.0,
) -> dict[str, Any]:
    acceleration = charge_c * field / mass if mass else 0.0
    time_cross = math.sqrt(2 * width / abs(acceleration)) if acceleration else 0.0
    return {
        "kind": "projectile",
        "duration": round(max(time_cross, 0.5), 6),
        "dt": round(max(time_cross / 100, 0.01), 6),
        "params": {"mass": mass, "charge": charge_c, "field": field},
        "constants": {"g": 0.0, "vx": initial_speed, "vy": round(acceleration, 9)},
        "segments": [
            {
                "t0": 0.0,
                "t1": round(max(time_cross, 0.5), 9),
                "x0": 0.0,
                "y0": 0.0,
                "vx": initial_speed,
                "vy": 0.0,
                "g": -acceleration,
            }
        ],
        "marks": [],
        "sliders": [
            _slider("Electric field", "E", field, -50.0, 50.0, "N/C"),
        ],
        "derived": {"acceleration": round(acceleration, 6)},
    }


def evaluate(model: dict[str, Any], t: float) -> dict[str, Any]:
    """Evaluate the animated state at time *t* (Python mirror of Flutter).

    Returns ``{"bodies": [{"x", "y", "angle"}...]}`` in SI units.
    """
    kind = model.get("kind")
    time = max(0.0, min(t, float(model.get("duration", 0.0))))
    if kind == "projectile":
        segment = model["segments"][0]
        tau = time - segment["t0"]
        return {
            "bodies": [
                {
                    "x": segment["x0"] + segment["vx"] * tau,
                    "y": segment["y0"]
                    + segment["vy"] * tau
                    - 0.5 * segment["g"] * tau**2,
                    "vx": segment["vx"],
                    "vy": segment["vy"] - segment["g"] * tau,
                }
            ]
        }
    if kind == "pendulum":
        segment = model["segments"][0]
        tau = time - segment["t0"]
        theta = segment["amplitude_rad"] * math.cos(
            segment["omega"] * tau + segment["phase"]
        )
        length = model["constants"]["length"]
        return {
            "bodies": [
                {
                    "theta": theta,
                    "x": length * math.sin(theta),
                    "y": -length * math.cos(theta),
                }
            ]
        }
    if kind == "spring":
        segment = model["segments"][0]
        tau = time - segment["t0"]
        x = segment["amplitude"] * math.cos(segment["omega"] * tau + segment["phase"])
        return {"bodies": [{"x": x, "y": 0.0}]}
    if kind == "collision":
        bodies: dict[int, dict[str, float]] = {}
        for segment in model["segments"]:
            if not (segment["t0"] - 1e-9 <= time <= segment["t1"] + 1e-9):
                continue
            tau = time - segment["t0"]
            body = int(segment["body"])
            if body in bodies:
                continue
            bodies[body] = {
                "x": segment["x0"] + segment["velocity"] * tau,
                "y": 0.0,
            }
        ordered = [bodies[key] for key in sorted(bodies)]
        return {"bodies": ordered}
    return {"bodies": []}


Evaluator = Callable[[dict[str, Any], float], dict[str, Any]]
