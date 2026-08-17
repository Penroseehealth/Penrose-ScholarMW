import http.server
import os
import socketserver

PORT = 3001
DIRECTORY = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build", "web")


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def log_message(self, format, *args):
        pass


os.chdir(DIRECTORY)
with socketserver.TCPServer(("0.0.0.0", PORT), Handler) as httpd:
    print(f"Serving on http://localhost:{PORT}", flush=True)
    httpd.serve_forever()
