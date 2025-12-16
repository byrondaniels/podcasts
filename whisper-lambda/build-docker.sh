#!/bin/bash
set -e

echo "Building Whisper Lambda..."

# Install zip utility (use yum for Amazon Linux)
if command -v yum &> /dev/null; then
    yum install -y zip > /dev/null 2>&1 || true
else
    apt-get update -qq && apt-get install -y -qq zip > /dev/null 2>&1 || true
fi

# Install dependencies in a temp directory
mkdir -p package
pip install -r lambda/requirements.txt -t package/ --upgrade --no-cache-dir

# Copy Lambda code
cp lambda/*.py package/

# Create deployment package
cd package
zip -r ../whisper-lambda.zip . -q

cd ..
rm -rf package

echo "✓ Whisper Lambda built successfully: whisper-lambda.zip"
ls -lh whisper-lambda.zip 2>/dev/null || echo "whisper-lambda.zip created"
