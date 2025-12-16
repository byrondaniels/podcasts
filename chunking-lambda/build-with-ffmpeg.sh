#!/bin/bash
set -e

echo "Building Chunking Lambda with ffmpeg..."

# Create temp directory
rm -rf package
mkdir -p package/bin

# Download and extract ffmpeg
cd package
wget -q https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz
tar xf ffmpeg-release-amd64-static.tar.xz
mv ffmpeg-*-amd64-static/ffmpeg bin/
mv ffmpeg-*-amd64-static/ffprobe bin/
rm -rf ffmpeg-*

cd ..

# Install Python dependencies
pip install -r requirements.txt -t package/ --upgrade --no-cache-dir -q

# Copy Lambda code
cp lambda_handler.py package/

# Create deployment package
cd package
zip -r ../chunking-lambda.zip . -q

cd ..
rm -rf package

echo "✓ Chunking Lambda built with ffmpeg: chunking-lambda.zip"
ls -lh chunking-lambda.zip
