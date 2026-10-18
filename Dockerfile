# No suitable prebuilt Flutter image exists for the SDK this app pins (the
# lockfile requires Dart >=3.13 / Flutter >=3.44; ghcr.io/cirruslabs/flutter
# stopped publishing at 3.44.0 and ghcr.io/flutter/flutter is private), so
# install the exact SDK from Google's release storage. Render builds run on
# GCP, so the download is fast.
FROM python:3.12-slim AS web

# Some Flutter base images default to an unprivileged user, which cannot write
# to the pub cache. Build as root inside the image.
USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git xz-utils \
    && rm -rf /var/lib/apt/lists/*

ARG FLUTTER_VERSION=3.47.2
RUN curl -fSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" -o /tmp/flutter.tar.xz \
    && mkdir -p /opt \
    && tar -xJf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}" \
    PUB_HOSTED_URL=https://pub.dev \
    FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com

# The committed lockfile records a regional pub mirror (pub.flutter-io.cn) from
# local dev; PUB_HOSTED_URL above makes pub re-resolve against pub.dev, which
# is reachable from CI, while keeping the locked versions.
RUN git config --global --add safe.directory /opt/flutter \
    && flutter --version \
    && flutter config --no-analytics \
    && flutter precache --web

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