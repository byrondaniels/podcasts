#!/bin/bash
set -e

echo "Building Chunking Lambda..."

# Install zip utility
apt-get update -qq && apt-get install -y -qq zip > /dev/null 2>&1

# Install dependencies in a temp directory
mkdir -p package
pip install -r requirements.txt -t package/ --upgrade --no-cache-dir

# Copy Lambda code (lambda_handler.py is in root directory)
cp lambda_handler.py package/

# Create deployment package
cd package
zip -r ../chunking-lambda.zip . -q

cd ..
rm -rf package

echo "✓ Chunking Lambda built successfully: chunking-lambda.zip"
ls -lh chunking-lambda.zip 2>/dev/null || echo "chunking-lambda.zip created"
