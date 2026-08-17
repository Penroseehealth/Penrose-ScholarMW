"""Quick smoke test for the backend API."""

import json
import subprocess
import sys
import time
import urllib.request


def main():
    print("Starting server...")
    proc = subprocess.Popen(
        [
            sys.executable,
            "-m",
            "uvicorn",
            "app.main:app",
            "--host",
            "127.0.0.1",
            "--port",
            "8000",
        ],
        cwd=r"C:\Users\zispaas\Documents\Default Project\penrose-scholar\backend",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    # Wait for server to start
    for i in range(30):
        time.sleep(1)
        try:
            r = urllib.request.urlopen("http://127.0.0.1:8000/health", timeout=2)
            data = json.loads(r.read())
            print(f"\n{'=' * 50}")
            print("  SERVER RUNNING!")
            print(f"  Health: {data}")
            print("  API docs: http://localhost:8000/docs")
            print(f"{'=' * 50}")

            # Test register
            req = urllib.request.Request(
                "http://127.0.0.1:8000/api/v1/auth/register",
                data=json.dumps(
                    {
                        "email": "demo@scholar.mw",
                        "password": "Demo1234!",
                        "full_name": "Demo Student",
                        "role": "student",
                        "institution": "University of Malawi",
                    }
                ).encode(),
                headers={"Content-Type": "application/json"},
            )
            r2 = urllib.request.urlopen(req, timeout=5)
            reg_data = json.loads(r2.read())
            print(
                f"\n  Demo register: OK (user={reg_data['user']['full_name']}, role={reg_data['user']['role']})"
            )

            # Test login
            req3 = urllib.request.Request(
                "http://127.0.0.1:8000/api/v1/auth/login",
                data=json.dumps(
                    {"email": "demo@scholar.mw", "password": "Demo1234!"}
                ).encode(),
                headers={"Content-Type": "application/json"},
            )
            r3 = urllib.request.urlopen(req3, timeout=5)
            login_data = json.loads(r3.read())
            token = login_data["access_token"]
            print(f"  Demo login: OK (token={token[:20]}...)")

            # Test courses
            req4 = urllib.request.Request(
                "http://127.0.0.1:8000/api/v1/courses/",
                headers={"Authorization": f"Bearer {token}"},
            )
            r4 = urllib.request.urlopen(req4, timeout=5)
            courses = json.loads(r4.read())
            print(f"  Courses: {len(courses)} found")

            print("\n  Server is live at http://localhost:8000")
            print("  Press Ctrl+C to stop\n")

            # Keep running
            proc.wait()

        except (urllib.error.URLError, ConnectionRefusedError):
            continue
        except Exception as e:
            print(f"  Error: {e}")
            break
    else:
        print("Server failed to start in 30 seconds")
        stderr = proc.stderr.read().decode()[:500]
        print(f"stderr: {stderr}")
        proc.kill()

    proc.kill()


if __name__ == "__main__":
    main()
