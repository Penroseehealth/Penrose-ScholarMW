FROM python:3.12-slim AS backend

WORKDIR /app

COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/ ./backend/
COPY penrose-scholar.db ./penrose-scholar.db 2>/dev/null || true

EXPOSE 8000

CMD ["python", "backend/run.py"]
