#!/bin/sh
set -e

echo "Building Merge Transcript Lambda for AWS Lambda runtime..."

# Download dependencies
go mod download

# Build for Lambda (Linux AMD64)
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -tags lambda.norpc -o bootstrap main.go

echo "✓ Lambda built successfully: bootstrap"
ls -lh bootstrap
