#!/bin/bash
set -e

echo "Building ffmpeg Lambda layer..."

# Create layer directory structure
mkdir -p ffmpeg-layer/bin

# Download static ffmpeg build
cd ffmpeg-layer
wget -q https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz
tar xf ffmpeg-release-amd64-static.tar.xz
mv ffmpeg-*-amd64-static/ffmpeg bin/
mv ffmpeg-*-amd64-static/ffprobe bin/
rm -rf ffmpeg-*

# Create layer ZIP
zip -r ../ffmpeg-layer.zip bin/

# Cleanup
cd ..
rm -rf ffmpeg-layer

echo "✓ ffmpeg layer built successfully: ffmpeg-layer.zip"
ls -lh ffmpeg-layer.zip
