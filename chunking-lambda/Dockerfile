# Chunking Lambda HTTP Service
# Runs the Lambda handler as an HTTP service for local Docker development

FROM python:3.11-slim

# Install system dependencies including ffmpeg
RUN apt-get update && apt-get install -y \
    ffmpeg \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Install Flask for HTTP server
RUN pip install --no-cache-dir flask gunicorn

# Copy application code
COPY lambda_handler.py /app/
COPY server.py /app/

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PORT=8002

# Expose the service port
EXPOSE 8002

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8002/health || exit 1

# Run with gunicorn for production-like behavior
CMD ["gunicorn", "--bind", "0.0.0.0:8002", "--workers", "2", "--timeout", "600", "server:app"]
