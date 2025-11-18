#!/bin/bash
set -e

echo "Building Merge Transcript Lambda (Go)..."

# Build for Linux (Lambda runtime)
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o bootstrap main.go

# Create deployment package
zip -j merge-transcript-lambda-go.zip bootstrap

echo "Build complete: merge-transcript-lambda-go.zip"
