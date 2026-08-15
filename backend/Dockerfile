FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/
COPY sql/ ./sql/
COPY uploads/ ./uploads/

# Defaults: SQLite (local + free cloud). Override with env/secrets.
ENV DB_TYPE=sqlite \
    SQLITE_FILE=/data/novel_app.db \
    UPLOAD_DIR=/data/uploads \
    PYTHONUNBUFFERED=1 \
    PORT=7860

RUN mkdir -p /data/uploads /app/uploads

# HF Spaces uses 7860; Render injects $PORT
EXPOSE 7860

CMD ["sh", "-c", "mkdir -p /data/uploads || true; mkdir -p "$UPLOAD_DIR" || true; if [ ! -w /data 2>/dev/null ]; then export SQLITE_FILE=/app/novel_app.db UPLOAD_DIR=/app/uploads; fi; uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-7860}"]
