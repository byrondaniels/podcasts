#!/bin/sh
set -e

echo "Building Poll Lambda for AWS Lambda runtime..."

# Download dependencies
go mod download

# Build for Lambda (Linux ARM64 or AMD64)
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -tags lambda.norpc -o bootstrap main.go

echo "✓ Lambda built successfully: bootstrap"
ls -lh bootstrap
