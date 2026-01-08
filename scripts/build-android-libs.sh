#!/bin/bash
# Build llama.cpp native libraries for Android from local submodule
# Requires: Android NDK installed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LLAMACPP_DIR="$PROJECT_ROOT/packages/llm_llamacpp/llamacpp"
BUILD_DIR="$PROJECT_ROOT/build-android"

# Check that llama.cpp submodule exists
if [ ! -d "$LLAMACPP_DIR" ]; then
    echo "Error: llama.cpp not found at $LLAMACPP_DIR"
    echo "Please clone the submodule first:"
    echo "  cd packages/llm_llamacpp"
    echo "  git submodule add https://github.com/ggml-org/llama.cpp.git llamacpp"
    exit 1
fi

# Find Android NDK
if [ -n "$ANDROID_NDK_HOME" ]; then
    NDK_PATH="$ANDROID_NDK_HOME"
elif [ -n "$ANDROID_NDK" ]; then
    NDK_PATH="$ANDROID_NDK"
elif [ -d "$HOME/Android/Sdk/ndk" ]; then
    # Find latest NDK version
    NDK_PATH=$(find "$HOME/Android/Sdk/ndk" -maxdepth 1 -type d | sort -V | tail -1)
elif [ -d "/usr/local/android-sdk/ndk" ]; then
    NDK_PATH=$(find "/usr/local/android-sdk/ndk" -maxdepth 1 -type d | sort -V | tail -1)
else
    echo "Error: Android NDK not found. Please set ANDROID_NDK_HOME environment variable."
    exit 1
fi

echo "Using Android NDK: $NDK_PATH"
TOOLCHAIN="$NDK_PATH/build/cmake/android.toolchain.cmake"

if [ ! -f "$TOOLCHAIN" ]; then
    echo "Error: NDK toolchain not found at $TOOLCHAIN"
    exit 1
fi

echo "Using llama.cpp from: $LLAMACPP_DIR"

# Create build directory
mkdir -p "$BUILD_DIR"

# Build for x86_64 (emulator)
echo ""
echo "=========================================="
echo "Building for x86_64 (Android emulator)..."
echo "=========================================="
rm -rf "$BUILD_DIR/x86_64"
mkdir -p "$BUILD_DIR/x86_64"
cd "$BUILD_DIR/x86_64"
cmake "$LLAMACPP_DIR" \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DANDROID_ABI=x86_64 \
    -DANDROID_PLATFORM=android-24 \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF \
    -DLLAMA_BUILD_SERVER=OFF \
    -DLLAMA_BUILD_TOOLS=OFF \
    -DLLAMA_CURL=OFF \
    -DGGML_OPENMP=OFF \
    -DBUILD_SHARED_LIBS=ON
cmake --build . --config Release -j$(nproc) --target llama ggml ggml-base ggml-cpu || true

# Build for arm64-v8a (physical devices)
echo ""
echo "=========================================="
echo "Building for arm64-v8a (physical devices)..."
echo "=========================================="
rm -rf "$BUILD_DIR/arm64-v8a"
mkdir -p "$BUILD_DIR/arm64-v8a"
cd "$BUILD_DIR/arm64-v8a"
cmake "$LLAMACPP_DIR" \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-24 \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF \
    -DLLAMA_BUILD_SERVER=OFF \
    -DLLAMA_BUILD_TOOLS=OFF \
    -DLLAMA_CURL=OFF \
    -DGGML_OPENMP=OFF \
    -DBUILD_SHARED_LIBS=ON
cmake --build . --config Release -j$(nproc) --target llama ggml ggml-base ggml-cpu || true

# Copy libraries to jniLibs
JNILIBS_DIR="$PROJECT_ROOT/packages/llm_llamacpp/android/src/main/jniLibs"

echo ""
echo "=========================================="
echo "Copying libraries to jniLibs..."
echo "=========================================="

# x86_64
mkdir -p "$JNILIBS_DIR/x86_64"
# Try different possible locations for the built libraries
for src_dir in "$BUILD_DIR/x86_64/src" "$BUILD_DIR/x86_64" "$BUILD_DIR/x86_64/bin"; do
    if [ -f "$src_dir/libllama.so" ]; then
        cp "$src_dir/libllama.so" "$JNILIBS_DIR/x86_64/"
        echo "Copied libllama.so from $src_dir"
        break
    fi
done
# Copy ggml libraries
for src_dir in "$BUILD_DIR/x86_64/ggml/src" "$BUILD_DIR/x86_64" "$BUILD_DIR/x86_64/bin"; do
    if ls "$src_dir"/libggml*.so 1> /dev/null 2>&1; then
        cp "$src_dir"/libggml*.so "$JNILIBS_DIR/x86_64/" 2>/dev/null || true
        echo "Copied ggml libraries from $src_dir"
        break
    fi
done

# arm64-v8a
mkdir -p "$JNILIBS_DIR/arm64-v8a"
for src_dir in "$BUILD_DIR/arm64-v8a/src" "$BUILD_DIR/arm64-v8a" "$BUILD_DIR/arm64-v8a/bin"; do
    if [ -f "$src_dir/libllama.so" ]; then
        cp "$src_dir/libllama.so" "$JNILIBS_DIR/arm64-v8a/"
        echo "Copied libllama.so from $src_dir"
        break
    fi
done
for src_dir in "$BUILD_DIR/arm64-v8a/ggml/src" "$BUILD_DIR/arm64-v8a" "$BUILD_DIR/arm64-v8a/bin"; do
    if ls "$src_dir"/libggml*.so 1> /dev/null 2>&1; then
        cp "$src_dir"/libggml*.so "$JNILIBS_DIR/arm64-v8a/" 2>/dev/null || true
        echo "Copied ggml libraries from $src_dir"
        break
    fi
done

echo ""
echo "=========================================="
echo "Build complete!"
echo "=========================================="
echo ""
echo "Libraries in $JNILIBS_DIR:"
find "$JNILIBS_DIR" -name "*.so" -type f 2>/dev/null | while read f; do
    size=$(du -h "$f" | cut -f1)
    arch=$(basename $(dirname "$f"))
    name=$(basename "$f")
    echo "  $arch/$name ($size)"
done

echo ""
echo "Now rebuild your Flutter app:"
echo "  cd $PROJECT_ROOT/packages/llm_llamacpp/example_app"
echo "  flutter clean && flutter run"
