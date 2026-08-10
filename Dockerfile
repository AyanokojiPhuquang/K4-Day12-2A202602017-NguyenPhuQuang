# ═══════════════════════════════════════════════════════════════════
# CP2 — Production-ready multi-stage Dockerfile
# ═══════════════════════════════════════════════════════════════════

# Stage 1: builder — cài dependency
FROM python:3.11-slim AS builder

WORKDIR /build

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: runtime — chỉ copy kết quả từ builder
FROM python:3.11-slim AS runtime

WORKDIR /app

# Copy installed dependencies from builder
COPY --from=builder /install /usr/local

# Copy source code
COPY app ./app
COPY utils ./utils

# Create non-root user
RUN useradd --create-home --uid 10001 appuser
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthz').read()" || exit 1

EXPOSE 8000

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
