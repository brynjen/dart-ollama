#!/bin/bash
# Build Android libraries using Docker (works on macOS, Windows, Linux)
# This builds llama.cpp with GPU support (Vulkan + OpenCL)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "Building Android libraries with Docker"
echo "=========================================="
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    echo "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop"
    exit 1
fi

# Build the Docker image (cached after first run)
echo "Building Docker image (this may take a few minutes on first run)..."
docker build -t llamacpp-android-builder -f "$SCRIPT_DIR/Dockerfile.android-build" "$PROJECT_ROOT"

echo ""
echo "Running build inside Docker container..."
echo ""

# Run the build
docker run --rm \
    -v "$PROJECT_ROOT:/workspace" \
    -e BUILD_VULKAN=ON \
    -e BUILD_OPENCL=ON \
    llamacpp-android-builder

echo ""
echo "=========================================="
echo "Docker build complete!"
echo "=========================================="
echo ""
echo "Libraries are in: packages/llm_llamacpp/android/src/main/jniLibs/"
echo ""
echo "Now rebuild your Flutter app:"
echo "  cd packages/llm_llamacpp/example_app"
echo "  flutter clean && flutter run"
