# Whisper Lambda HTTP Service
# Runs the Lambda handler as an HTTP service for local Docker development

FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install Python dependencies
COPY lambda/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Install Flask and other dependencies for HTTP server
RUN pip install --no-cache-dir \
    flask==3.0.0 \
    gunicorn==21.2.0 \
    boto3==1.35.0 \
    requests==2.31.0

# Copy application code
COPY lambda/ /app/lambda/
COPY server.py /app/

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PORT=8003

# Expose the service port
EXPOSE 8003

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8003/health || exit 1

# Run with gunicorn for production-like behavior
CMD ["gunicorn", "--bind", "0.0.0.0:8003", "--workers", "2", "--timeout", "600", "server:app"]
