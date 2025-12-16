#!/bin/bash
set -e

echo "Building Chunking Lambda..."

# Install zip utility and wget (use yum for Amazon Linux)
if command -v yum &> /dev/null; then
    yum install -y zip wget xz tar > /dev/null 2>&1 || true
else
    apt-get update -qq && apt-get install -y -qq zip wget xz-utils tar > /dev/null 2>&1 || true
fi

# Install dependencies in a temp directory
mkdir -p package/bin
pip install -r requirements.txt -t package/ --upgrade --no-cache-dir

# Download and add ffmpeg binaries
echo "Downloading ffmpeg..."
cd package
wget -q https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz
tar xf ffmpeg-release-amd64-static.tar.xz
mv ffmpeg-*-amd64-static/ffmpeg bin/
mv ffmpeg-*-amd64-static/ffprobe bin/
rm -rf ffmpeg-*
cd ..

# Copy Lambda code (lambda_handler.py is in root directory)
cp lambda_handler.py package/

# Create deployment package
cd package
zip -r ../chunking-lambda.zip . -q

cd ..
rm -rf package

echo "✓ Chunking Lambda built successfully: chunking-lambda.zip"
ls -lh chunking-lambda.zip 2>/dev/null || echo "chunking-lambda.zip created"
