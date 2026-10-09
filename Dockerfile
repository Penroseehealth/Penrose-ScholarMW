# The Flutter SDK image is a build arg so the base can be swapped without
# editing the rest of this file. `stable` tracks the channel used in local dev;
# the SDK version is pinned by the `flutter` directive in frontend/pubspec.yaml.
ARG FLUTTER_IMAGE=ghcr.io/cirruslabs/flutter:stable

# ---------------------------------------------------------------------------
# Stage 1: compile the Flutter web bundle.
# ---------------------------------------------------------------------------
FROM ${FLUTTER_IMAGE} AS web

# Some Flutter base images default to an unprivileged user, which cannot write
# to the pub cache. Build as root inside the image.
USER root
WORKDIR /build

# Resolve dependencies against the lockfile on its own layer, so it stays cached
# until pubspec.yaml or pubspec.lock actually change.
COPY frontend/pubspec.yaml frontend/pubspec.lock ./
RUN flutter pub get

# .dockerignore excludes frontend/build and frontend/.dart_tool, so this builds a
# clean bundle instead of shipping host artefacts into the image.
COPY frontend/ ./
RUN flutter build web --release

# ---------------------------------------------------------------------------
# Stage 2: runtime.
# ---------------------------------------------------------------------------
FROM python:3.12-slim AS backend

WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY backend/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/ ./backend/

# app/main.py resolves WEB_DIR as three levels up from itself, which lands on
# /app/frontend/build/web. This path must match that exactly or the SPA mount
# is skipped and the browser gets a blank page.
COPY --from=web /build/build/web ./frontend/build/web

EXPOSE 8000
CMD ["python", "backend/run.py"]