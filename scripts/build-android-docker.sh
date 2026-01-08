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
# Use --platform linux/amd64 because Android NDK only provides x86_64 host tools
echo "Building Docker image (this may take a few minutes on first run)..."
docker build --platform linux/amd64 -t llamacpp-android-builder -f "$SCRIPT_DIR/Dockerfile.android-build" "$PROJECT_ROOT"

echo ""
echo "Cleaning stale build caches (if any)..."
# Remove any stale CMake caches that might have wrong paths
rm -rf "$PROJECT_ROOT/build-android/deps" 2>/dev/null || true

echo ""
echo "Running build inside Docker container..."
echo ""

# Run the build
# Use --platform linux/amd64 to ensure NDK tools work on Apple Silicon Macs
# Skip x86_64 build to speed up (only arm64 is needed for real devices)
# Vulkan disabled by default (OpenCL is better for Qualcomm/Adreno devices)
docker run --rm \
    --platform linux/amd64 \
    -v "$PROJECT_ROOT:/workspace" \
    -e BUILD_VULKAN=${BUILD_VULKAN:-OFF} \
    -e BUILD_OPENCL=${BUILD_OPENCL:-ON} \
    -e BUILD_X86_64=OFF \
    llamacpp-android-builder

BUILD_RESULT=$?
if [ $BUILD_RESULT -ne 0 ]; then
    echo ""
    echo "=========================================="
    echo "ERROR: Build failed!"
    echo "=========================================="
    echo "Check the output above for error messages."
    exit 1
fi

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
