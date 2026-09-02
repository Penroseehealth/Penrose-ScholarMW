"""Local dev proxy for Penrose ScholarMW web build.

Serves the Flutter web release from build/web and forwards any /api/* request
to the FastAPI backend on port 8000. Lets us hand the user a single working
link without rebuilding the frontend with an absolute API_BASE_URL.
"""

import http.server
import json
import mimetypes
import os
import socketserver
import urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build", "web")
BACKEND = "http://127.0.0.1:8000"
PORT = 8080


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def _forward(self, method):
        url = BACKEND + self.path
        body = None
        length = int(self.headers.get("Content-Length", 0) or 0)
        if length:
            body = self.rfile.read(length)
        req = urllib.request.Request(url, data=body, method=method)
        for k, v in self.headers.items():
            if k.lower() not in ("host", "content-length"):
                req.add_header(k, v)
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                data = resp.read()
                self.send_response(resp.status)
                ct = resp.headers.get("Content-Type", "application/json")
                self.send_header("Content-Type", ct)
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
        except urllib.error.HTTPError as e:
            data = e.read()
            self.send_response(e.code)
            self.send_header("Content-Type", e.headers.get("Content-Type", "application/json"))
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        except Exception as e:  # noqa: BLE001
            msg = json.dumps({"detail": f"proxy error: {e}"}).encode()
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            self.wfile.write(msg)

    def do_GET(self):
        if self.path.startswith("/api/") or self.path == "/health":
            self._forward("GET")
        else:
            super().do_GET()

    def do_POST(self):
        if self.path.startswith("/api/"):
            self._forward("POST")
        else:
            self.send_error(404)

    def do_PUT(self):
        if self.path.startswith("/api/"):
            self._forward("PUT")
        else:
            self.send_error(404)

    def do_DELETE(self):
        if self.path.startswith("/api/"):
            self._forward("DELETE")
        else:
            self.send_error(404)

    def end_headers(self):
        # Allow the app served here to call the backend on :8000 too (bonus).
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()


class ThreadingHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True


if __name__ == "__main__":
    mimetypes.add_type("application/javascript", ".js")
    mimetypes.add_type("text/javascript", ".js")
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"penrose proxy on http://localhost:{PORT} -> backend {BACKEND}")
    server.serve_forever()
