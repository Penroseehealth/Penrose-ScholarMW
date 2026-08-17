"""Debug server startup and test all endpoints."""

import json
import os
import socket
import subprocess
import sys
import time
import urllib.request

BACKEND = r"C:\Users\zispaas\Documents\Default Project\penrose-scholar\backend"
PORT = 8003

# Clean old DB
for f in ["penrose_scholar.db", "test.db"]:
    p = os.path.join(BACKEND, f)
    if os.path.exists(p):
        try:
            os.remove(p)
        except PermissionError:
            pass

print("Starting server on port", PORT)
proc = subprocess.Popen(
    [
        sys.executable,
        "-m",
        "uvicorn",
        "app.main:app",
        "--host",
        "127.0.0.1",
        "--port",
        str(PORT),
    ],
    cwd=BACKEND,
    stdout=open(os.path.join(BACKEND, "test_out.log"), "w"),
    stderr=open(os.path.join(BACKEND, "test_err.log"), "w"),
)

# Wait for server
for i in range(20):
    time.sleep(1)
    try:
        s = socket.create_connection(("127.0.0.1", PORT), timeout=1)
        s.close()
        break
    except OSError:
        pass
else:
    print("Server did not start")
    proc.kill()
    sys.exit(1)


def api(method, path, data=None, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(
        f"http://127.0.0.1:{PORT}{path}", data=body, headers=headers, method=method
    )
    try:
        r = urllib.request.urlopen(req, timeout=10)
        return json.loads(r.read()), r.status
    except urllib.error.HTTPError as e:
        try:
            body = json.loads(e.read())
        except Exception:
            body = {"detail": str(e)}
        return body, e.code


print("\n--- HEALTH ---")
d, s = api("GET", "/health")
print(f"  [{s}] {d}")

print("\n--- REGISTER ---")
d, s = api(
    "POST",
    "/api/v1/auth/register",
    {
        "email": "demo@scholar.mw",
        "password": "Demo1234!",
        "full_name": "Demo Student",
        "role": "student",
    },
)
print(
    f"  [{s}] user={d.get('user', {}).get('full_name', '?')}, token={'yes' if d.get('access_token') else 'no'}"
)
token = d.get("access_token")

if not token:
    print("\n--- LOGIN ---")
    d2, s2 = api(
        "POST",
        "/api/v1/auth/login",
        {"email": "demo@scholar.mw", "password": "Demo1234!"},
    )
    print(f"  [{s2}] {d2}")
    token = d2.get("access_token")

if token:
    print("\n--- GET /me ---")
    d, s = api("GET", "/api/v1/auth/me", token=token)
    print(f"  [{s}] {d.get('full_name', '?')} ({d.get('role', '?')})")

    print("\n--- LIST COURSES ---")
    d, s = api("GET", "/api/v1/courses/", token=token)
    print(f"  [{s}] {len(d)} courses")

    print("\n--- CREATE COURSE ---")
    d, s = api(
        "POST",
        "/api/v1/courses/",
        {"code": "MED301", "title": "Medical Microbiology", "level": "Year 3"},
        token=token,
    )
    print(f"  [{s}] {d.get('title', '?')}")

    print("\n--- AI CHAT ---")
    d, s = api(
        "POST",
        "/api/v1/ai/chat",
        {"message": "What is antimicrobial resistance?", "agent_type": "tutor"},
        token=token,
    )
    print(f"  [{s}] {str(d.get('content', '?'))[:80]}")

    print("\n--- NOTIFICATIONS ---")
    d, s = api("GET", "/api/v1/notifications/", token=token)
    print(f"  [{s}] {len(d)} notifications")

    print("\n--- RESEARCH PROJECTS ---")
    d, s = api("GET", "/api/v1/research/projects", token=token)
    print(f"  [{s}] {len(d)} projects")

print(f"\n{'=' * 50}")
print(f"  ALL DONE! Server running at http://localhost:{PORT}")
print(f"  API docs: http://localhost:{PORT}/docs")
print(f"{'=' * 50}")

proc.kill()
