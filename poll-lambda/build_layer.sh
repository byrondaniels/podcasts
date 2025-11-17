#!/bin/bash

# Build Lambda Layer for RSS Feed Poller
# This script creates a Lambda layer zip file with all required dependencies

set -e

echo "Building Lambda layer for RSS Feed Poller..."

# Clean up previous builds
echo "Cleaning up previous builds..."
rm -rf python
rm -f lambda-layer.zip

# Create directory structure for Lambda layer
# Lambda layers require dependencies to be in python/ directory
echo "Creating layer directory structure..."
mkdir -p python

# Install dependencies
echo "Installing Python dependencies..."
pip install -r requirements.txt -t python/ --platform manylinux2014_x86_64 --only-binary=:all: --python-version 3.11

# Remove unnecessary files to reduce layer size
echo "Removing unnecessary files..."
find python -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find python -type d -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true
find python -type f -name "*.pyc" -delete 2>/dev/null || true
find python -type f -name "*.pyo" -delete 2>/dev/null || true

# Create zip file
echo "Creating layer zip file..."
zip -r lambda-layer.zip python -q

# Get zip file size
SIZE=$(du -h lambda-layer.zip | cut -f1)
echo "Lambda layer built successfully: lambda-layer.zip ($SIZE)"

# Verify contents
echo ""
echo "Layer contents:"
unzip -l lambda-layer.zip | head -20

echo ""
echo "Build complete! You can now use lambda-layer.zip in your Terraform configuration."
