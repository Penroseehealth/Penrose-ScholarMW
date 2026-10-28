"""Live proof that unclassifiable MathsDrill questions reach the assistant.

Run: backend/.venv/Scripts/python.exe _live_assistant_probe.py
Two real provider calls (Cloudflare) - expect ~10-45 s.
"""

import json
import time
import urllib.error
import urllib.request

BASE = "http://localhost:8000"
CASES = [
    ("junk input", "Crrrrffddddddddddddddddddsolve would you rephrase the question?"),
    (
        "free-form word problem",
        "A farmer has 3 times as many goats as cows. Altogether there are 32 "
        "animals. How many goats are there?",
    ),
]


def post(path: str, payload: dict, token: str | None = None) -> tuple[int, dict]:
    request = urllib.request.Request(
        BASE + path,
        data=json.dumps(payload).encode(),
        headers={
            "Content-Type": "application/json",
            **({"Authorization": f"Bearer {token}"} if token else {}),
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            return response.status, json.loads(response.read())
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read() or b"{}")


def main() -> None:
    status, auth = post(
        "/api/v1/auth/login",
        {"email": "student@scholar.mw", "password": "student123"},
    )
    print(f"login: {status}")
    if status != 200:
        print(json.dumps(auth)[:400])
        return
    token = auth.get("access_token") or auth.get("token")

    for label, question in CASES:
        started = time.monotonic()
        status, data = post(
            "/api/v1/mathsdrill/solve", {"question": question}, token=token
        )
        elapsed = time.monotonic() - started
        steps = data.get("steps") or []
        blob = json.dumps(data)
        print(f"\n=== {label}: {status} in {elapsed:.1f}s")
        print(
            f"source={data.get('source')!r} topic={data.get('topic')!r} "
            f"verification={data.get('verification_status')!r}"
        )
        print(f"steps={len(steps)} answer_text={data.get('answer_text')!r}")
        print(
            "clarification_present="
            f"{'could not turn that into a calculation' in blob}"
        )
        print(f"limitation={data.get('limitation')!r}")
        for index, step in enumerate(steps, 1):
            title = str(step.get("title") or "").strip()
            expl = str(step.get("explanation") or "").strip().replace("\n", " / ")
            work = step.get("latex_lines") or step.get("work") or []
            print(f"  {index}. [{title}] {expl[:160]}")
            if work:
                print(f"      work={str(work)[:120]}")


if __name__ == "__main__":
    main()
