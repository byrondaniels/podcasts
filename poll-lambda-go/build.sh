#!/bin/bash
set -e

echo "Building Poll Lambda (Go)..."

# Build for Linux (Lambda runtime)
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o bootstrap main.go

# Create deployment package
zip -j poll-lambda-go.zip bootstrap

echo "Build complete: poll-lambda-go.zip"
