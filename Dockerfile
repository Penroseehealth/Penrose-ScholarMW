FROM ghcr.io/cirruslabs/flutter:3.47.0 AS flutter

WORKDIR /app/frontend
COPY frontend/pubspec.* .
RUN flutter pub get

COPY frontend/ .
RUN flutter build web --release --dart-define=API_BASE_URL=


FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libpq-dev && \
    rm -rf /var/lib/apt/lists/*

COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/ ./backend/
COPY --from=flutter /app/frontend/build/web ./frontend/build/web/

WORKDIR /app/backend

EXPOSE 8000

CMD alembic upgrade head; uvicorn app.main:app --host 0.0.0.0 --port $PORT
