#!/bin/bash
# Unified Lambda build script
# This script builds all Lambda functions and creates deployment packages

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$SCRIPT_DIR/build"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Ensure build directory exists
mkdir -p "$BUILD_DIR"

usage() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  all           Build all Lambda functions (default)"
    echo "  go            Build all Go Lambda functions"
    echo "  python        Build all Python Lambda functions"
    echo "  poll          Build poll-rss-feeds Lambda (Go)"
    echo "  merge         Build merge-transcript Lambda (Go)"
    echo "  chunking      Build chunking Lambda (Python)"
    echo "  whisper       Build whisper Lambda (Python)"
    echo "  layers        Build Lambda layers only"
    echo "  clean         Remove all build artifacts"
    echo ""
    echo "Options:"
    echo "  --docker      Build using Docker (default)"
    echo "  --extract     Extract zip files to build/ directory"
    echo "  --help        Show this help message"
    exit 0
}

# Build Go Lambdas
build_go_lambdas() {
    log_info "Building Go Lambda functions..."

    cd "$PROJECT_ROOT"

    # Build both Go lambdas in a single Docker build context
    docker build \
        -f lambdas/Dockerfile.go \
        --target poll-lambda-package \
        --output type=local,dest="$BUILD_DIR/poll-lambda" \
        .

    docker build \
        -f lambdas/Dockerfile.go \
        --target merge-lambda-package \
        --output type=local,dest="$BUILD_DIR/merge-lambda" \
        .

    # Copy zip files to expected locations
    cp "$BUILD_DIR/poll-lambda/package/poll-lambda.zip" "$PROJECT_ROOT/poll-lambda-go/poll-lambda-go.zip"
    cp "$BUILD_DIR/poll-lambda/package/bootstrap" "$PROJECT_ROOT/poll-lambda-go/bootstrap"
    cp "$BUILD_DIR/merge-lambda/package/merge-lambda.zip" "$PROJECT_ROOT/merge-transcript-lambda-go/merge-transcript-lambda-go.zip"
    cp "$BUILD_DIR/merge-lambda/package/bootstrap" "$PROJECT_ROOT/merge-transcript-lambda-go/bootstrap"

    log_success "Go Lambda functions built successfully"
    ls -lh "$PROJECT_ROOT/poll-lambda-go/poll-lambda-go.zip"
    ls -lh "$PROJECT_ROOT/merge-transcript-lambda-go/merge-transcript-lambda-go.zip"
}

build_poll_lambda() {
    log_info "Building poll-rss-feeds Lambda (Go)..."

    cd "$PROJECT_ROOT"

    docker build \
        -f lambdas/Dockerfile.go \
        --target poll-lambda-package \
        --output type=local,dest="$BUILD_DIR/poll-lambda" \
        .

    cp "$BUILD_DIR/poll-lambda/package/poll-lambda.zip" "$PROJECT_ROOT/poll-lambda-go/poll-lambda-go.zip"
    cp "$BUILD_DIR/poll-lambda/package/bootstrap" "$PROJECT_ROOT/poll-lambda-go/bootstrap"

    log_success "Poll Lambda built: poll-lambda-go/poll-lambda-go.zip"
}

build_merge_lambda() {
    log_info "Building merge-transcript Lambda (Go)..."

    cd "$PROJECT_ROOT"

    docker build \
        -f lambdas/Dockerfile.go \
        --target merge-lambda-package \
        --output type=local,dest="$BUILD_DIR/merge-lambda" \
        .

    cp "$BUILD_DIR/merge-lambda/package/merge-lambda.zip" "$PROJECT_ROOT/merge-transcript-lambda-go/merge-transcript-lambda-go.zip"
    cp "$BUILD_DIR/merge-lambda/package/bootstrap" "$PROJECT_ROOT/merge-transcript-lambda-go/bootstrap"

    log_success "Merge Lambda built: merge-transcript-lambda-go/merge-transcript-lambda-go.zip"
}

# Build Python Lambdas as Docker images
build_python_lambdas() {
    log_info "Building Python Lambda Docker images..."

    cd "$PROJECT_ROOT"

    # Build chunking lambda image
    log_info "Building chunking Lambda image..."
    docker build \
        -f lambdas/Dockerfile.python \
        --target chunking-lambda \
        -t podcast-chunking-lambda:latest \
        .

    # Build whisper lambda image
    log_info "Building whisper Lambda image..."
    docker build \
        -f lambdas/Dockerfile.python \
        --target whisper-lambda \
        -t podcast-whisper-lambda:latest \
        .

    log_success "Python Lambda Docker images built successfully"
    docker images | grep podcast-.*-lambda
}

build_chunking_lambda() {
    log_info "Building chunking Lambda Docker image..."

    cd "$PROJECT_ROOT"

    # Build the chunking lambda image
    docker build \
        -f lambdas/Dockerfile.python \
        --target chunking-lambda \
        -t podcast-chunking-lambda:latest \
        .

    log_success "Chunking Lambda image built: podcast-chunking-lambda:latest"
    docker images | grep podcast-chunking-lambda
}

build_whisper_lambda() {
    log_info "Building whisper Lambda Docker image..."

    cd "$PROJECT_ROOT"

    # Build the whisper lambda image
    docker build \
        -f lambdas/Dockerfile.python \
        --target whisper-lambda \
        -t podcast-whisper-lambda:latest \
        .

    log_success "Whisper Lambda image built: podcast-whisper-lambda:latest"
    docker images | grep podcast-whisper-lambda
}

# Build Lambda layers
build_layers() {
    log_info "Building Lambda layers..."

    cd "$PROJECT_ROOT"

    # Build Python dependencies layer
    docker build \
        -f lambdas/Dockerfile.python \
        --target python-deps-builder \
        -t podcast-python-layer:latest \
        .

    # Extract layer
    docker run --rm \
        -v "$BUILD_DIR:/output" \
        --entrypoint /bin/bash \
        podcast-python-layer:latest \
        -c "cd /opt && zip -r /output/python-deps-layer.zip python"

    # Build ffmpeg layer
    docker build \
        -f lambdas/Dockerfile.python \
        --target ffmpeg-builder \
        -t podcast-ffmpeg-layer:latest \
        .

    docker run --rm \
        -v "$BUILD_DIR:/output" \
        --entrypoint /bin/bash \
        podcast-ffmpeg-layer:latest \
        -c "cd /opt && zip -r /output/ffmpeg-layer.zip bin"

    log_success "Lambda layers built:"
    ls -lh "$BUILD_DIR"/*.zip 2>/dev/null || true
}

# Clean build artifacts
clean() {
    log_info "Cleaning build artifacts..."

    rm -rf "$BUILD_DIR"
    rm -f "$PROJECT_ROOT/poll-lambda-go/bootstrap" "$PROJECT_ROOT/poll-lambda-go/"*.zip
    rm -f "$PROJECT_ROOT/merge-transcript-lambda-go/bootstrap" "$PROJECT_ROOT/merge-transcript-lambda-go/"*.zip
    rm -f "$PROJECT_ROOT/chunking-lambda/"*.zip
    rm -rf "$PROJECT_ROOT/chunking-lambda/package"
    rm -f "$PROJECT_ROOT/whisper-lambda/"*.zip
    rm -rf "$PROJECT_ROOT/whisper-lambda/package"

    # Remove Docker images
    docker rmi podcast-chunking-lambda:latest 2>/dev/null || true
    docker rmi podcast-whisper-lambda:latest 2>/dev/null || true
    docker rmi podcast-python-layer:latest 2>/dev/null || true
    docker rmi podcast-ffmpeg-layer:latest 2>/dev/null || true

    log_success "Build artifacts cleaned"
}

# Build all
build_all() {
    log_info "Building all Lambda functions..."

    build_go_lambdas
    build_python_lambdas

    log_success "All Lambda functions built successfully!"
    echo ""
    echo "Build artifacts:"
    ls -lh "$PROJECT_ROOT/poll-lambda-go/"*.zip 2>/dev/null || true
    ls -lh "$PROJECT_ROOT/merge-transcript-lambda-go/"*.zip 2>/dev/null || true
    ls -lh "$PROJECT_ROOT/chunking-lambda/"*.zip 2>/dev/null || true
    ls -lh "$PROJECT_ROOT/whisper-lambda/"*.zip 2>/dev/null || true
}

# Parse arguments
CMD="${1:-all}"
shift || true

case "$CMD" in
    all)
        build_all
        ;;
    go)
        build_go_lambdas
        ;;
    python)
        build_python_lambdas
        ;;
    poll)
        build_poll_lambda
        ;;
    merge)
        build_merge_lambda
        ;;
    chunking)
        build_chunking_lambda
        ;;
    whisper)
        build_whisper_lambda
        ;;
    layers)
        build_layers
        ;;
    clean)
        clean
        ;;
    --help|-h|help)
        usage
        ;;
    *)
        log_error "Unknown command: $CMD"
        usage
        ;;
esac
