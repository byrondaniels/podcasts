# Poll Lambda HTTP Service
# Runs the Lambda handler as an HTTP service for local Docker development

FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY *.go ./

# Build the HTTP server (with http build tag)
RUN CGO_ENABLED=0 GOOS=linux go build -tags http -o /poll-lambda-http .

# Runtime stage
FROM alpine:3.19

# Install CA certificates for HTTPS requests
RUN apk add --no-cache ca-certificates curl

WORKDIR /app

# Copy the binary
COPY --from=builder /poll-lambda-http /app/poll-lambda-http

# Set environment variables
ENV PORT=8001

# Expose the service port
EXPOSE 8001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8001/health || exit 1

# Run the HTTP server
CMD ["/app/poll-lambda-http"]
