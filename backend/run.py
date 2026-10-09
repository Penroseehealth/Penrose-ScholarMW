import os

import uvicorn

if __name__ == "__main__":
    # Render injects PORT. Keep 8000 as the default for local dev and to match
    # the PORT env var in render.yaml.
    port = int(os.environ.get("PORT", "8000"))

    # The autoreloader forks a second process and watches the filesystem, which
    # is wasteful and fragile on a single dyno. Only enable it outside production.
    reload = os.environ.get("ENVIRONMENT") != "production"

    uvicorn.run("app.main:app", host="0.0.0.0", port=port, reload=reload)
