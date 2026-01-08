#!/bin/bash
# Build llama.cpp native libraries for Android from local submodule
# Supports CPU, Vulkan (GPU), and OpenCL (Adreno GPU) backends
#
# Requirements:
#   - Android NDK installed
#   - Ninja build system
#   - glslc shader compiler (for Vulkan - install via: sudo apt install glslc)
#
# Usage:
#   ./build-android-libs.sh                    # Build with all available backends
#   BUILD_VULKAN=OFF ./build-android-libs.sh   # Build without Vulkan
#   BUILD_OPENCL=OFF ./build-android-libs.sh   # Build without OpenCL
#   BUILD_VULKAN=OFF BUILD_OPENCL=OFF ./build-android-libs.sh  # CPU only
#
# Environment Variables:
#   BUILD_VULKAN  - ON/OFF (default: ON) - Build Vulkan GPU backend
#   BUILD_OPENCL  - ON/OFF (default: ON) - Build OpenCL GPU backend (Adreno optimized)
#   BUILD_X86_64  - ON/OFF (default: ON) - Build for x86_64 (emulator)
#   BUILD_ARM64   - ON/OFF (default: ON) - Build for arm64-v8a (real devices)
#
# Note: On macOS, Vulkan and OpenCL backends cannot be built (no cross-compilation support)
#       Use BUILD_VULKAN=OFF BUILD_OPENCL=OFF for Mac builds

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LLAMACPP_DIR="$PROJECT_ROOT/packages/llm_llamacpp/llamacpp"
BUILD_DIR="$PROJECT_ROOT/build-android"
DEPS_DIR="$PROJECT_ROOT/build-android/deps"

# Build options (can be overridden via environment variables)
BUILD_VULKAN=${BUILD_VULKAN:-ON}
BUILD_OPENCL=${BUILD_OPENCL:-ON}
BUILD_X86_64=${BUILD_X86_64:-ON}
BUILD_ARM64=${BUILD_ARM64:-ON}

# Detect if running on macOS - disable GPU backends
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Detected macOS - GPU backends (Vulkan/OpenCL) cannot be cross-compiled"
    BUILD_VULKAN=OFF
    BUILD_OPENCL=OFF
fi

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
elif [ -d "/opt/android-sdk/ndk" ]; then
    # Docker container path
    NDK_PATH=$(find "/opt/android-sdk/ndk" -maxdepth 1 -type d | sort -V | tail -1)
elif [ -d "$HOME/Library/Android/sdk/ndk" ]; then
    # macOS Android Studio path
    NDK_PATH=$(find "$HOME/Library/Android/sdk/ndk" -maxdepth 1 -type d | sort -V | tail -1)
else
    echo "Error: Android NDK not found. Please set ANDROID_NDK_HOME environment variable."
    exit 1
fi

echo "Using Android NDK: $NDK_PATH"
TOOLCHAIN="$NDK_PATH/build/cmake/android.toolchain.cmake"

# Detect host platform for NDK prebuilt path
if [[ "$OSTYPE" == "darwin"* ]]; then
    NDK_HOST="darwin-x86_64"
else
    NDK_HOST="linux-x86_64"
fi
NDK_SYSROOT="$NDK_PATH/toolchains/llvm/prebuilt/$NDK_HOST/sysroot"

if [ ! -f "$TOOLCHAIN" ]; then
    echo "Error: NDK toolchain not found at $TOOLCHAIN"
    exit 1
fi

echo "Using llama.cpp from: $LLAMACPP_DIR"

# Create directories
mkdir -p "$BUILD_DIR"
mkdir -p "$DEPS_DIR"

# ==========================================
# Setup OpenCL Dependencies
# ==========================================
setup_opencl_deps() {
    echo ""
    echo "=========================================="
    echo "Setting up OpenCL dependencies..."
    echo "=========================================="

    local OPENCL_HEADERS_DIR="$DEPS_DIR/OpenCL-Headers"
    local OPENCL_ICD_DIR="$DEPS_DIR/OpenCL-ICD-Loader"
    local OPENCL_INCLUDE_DST="$NDK_SYSROOT/usr/include"
    local OPENCL_LIB_DST_ARM64="$NDK_SYSROOT/usr/lib/aarch64-linux-android"
    local OPENCL_LIB_DST_X86="$NDK_SYSROOT/usr/lib/x86_64-linux-android"

    # Check if already installed
    if [ -d "$OPENCL_INCLUDE_DST/CL" ] && [ -f "$OPENCL_LIB_DST_ARM64/libOpenCL.so" ]; then
        echo "OpenCL dependencies already installed"
        return 0
    fi

    # Clone OpenCL Headers if not present
    if [ ! -d "$OPENCL_HEADERS_DIR" ]; then
        echo "Cloning OpenCL-Headers..."
        git clone --depth 1 https://github.com/KhronosGroup/OpenCL-Headers "$OPENCL_HEADERS_DIR"
    fi

    # Copy headers to NDK sysroot
    if [ ! -d "$OPENCL_INCLUDE_DST/CL" ]; then
        echo "Installing OpenCL headers..."
        cp -r "$OPENCL_HEADERS_DIR/CL" "$OPENCL_INCLUDE_DST/"
    fi

    # Clone OpenCL ICD Loader if not present
    if [ ! -d "$OPENCL_ICD_DIR" ]; then
        echo "Cloning OpenCL-ICD-Loader..."
        git clone --depth 1 https://github.com/KhronosGroup/OpenCL-ICD-Loader "$OPENCL_ICD_DIR"
    fi

    # Build ICD Loader for arm64-v8a
    if [ ! -f "$OPENCL_LIB_DST_ARM64/libOpenCL.so" ]; then
        echo "Building OpenCL ICD Loader for arm64-v8a..."
        mkdir -p "$OPENCL_ICD_DIR/build_arm64"
        cd "$OPENCL_ICD_DIR/build_arm64"
        cmake .. -G Ninja \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
            -DOPENCL_ICD_LOADER_HEADERS_DIR="$OPENCL_INCLUDE_DST" \
            -DANDROID_ABI=arm64-v8a \
            -DANDROID_PLATFORM=android-28 \
            -DANDROID_STL=c++_shared
        ninja
        cp libOpenCL.so "$OPENCL_LIB_DST_ARM64/"
        echo "Installed libOpenCL.so to $OPENCL_LIB_DST_ARM64/"
    fi

    # Build ICD Loader for x86_64
    if [ ! -f "$OPENCL_LIB_DST_X86/libOpenCL.so" ]; then
        echo "Building OpenCL ICD Loader for x86_64..."
        mkdir -p "$OPENCL_ICD_DIR/build_x86_64"
        cd "$OPENCL_ICD_DIR/build_x86_64"
        cmake .. -G Ninja \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
            -DOPENCL_ICD_LOADER_HEADERS_DIR="$OPENCL_INCLUDE_DST" \
            -DANDROID_ABI=x86_64 \
            -DANDROID_PLATFORM=android-28 \
            -DANDROID_STL=c++_shared
        ninja
        cp libOpenCL.so "$OPENCL_LIB_DST_X86/"
        echo "Installed libOpenCL.so to $OPENCL_LIB_DST_X86/"
    fi

    cd "$PROJECT_ROOT"
    echo "OpenCL dependencies ready"
}

# ==========================================
# Setup Vulkan Dependencies (C++ Headers)
# ==========================================
setup_vulkan_deps() {
    echo ""
    echo "=========================================="
    echo "Setting up Vulkan dependencies..."
    echo "=========================================="

    local VULKAN_HPP_DIR="$DEPS_DIR/Vulkan-Hpp"
    local VULKAN_INCLUDE_DST="$NDK_SYSROOT/usr/include/vulkan"

    # Get the NDK's Vulkan header version
    local VK_VERSION=$(grep "#define VK_HEADER_VERSION " "$VULKAN_INCLUDE_DST/vulkan_core.h" | awk '{print $3}')
    echo "NDK Vulkan header version: $VK_VERSION"

    # Check if Vulkan C++ headers are already installed and match version
    if [ -f "$VULKAN_INCLUDE_DST/vulkan.hpp" ]; then
        local INSTALLED_VK=$(grep "VK_HEADER_VERSION ==" "$VULKAN_INCLUDE_DST/vulkan.hpp" | grep -oE '[0-9]+' | head -1)
        if [ "$INSTALLED_VK" = "$VK_VERSION" ]; then
            echo "Vulkan C++ headers already installed (version $VK_VERSION)"
            return 0
        else
            echo "Vulkan C++ headers version mismatch (installed: $INSTALLED_VK, need: $VK_VERSION)"
            rm -rf "$VULKAN_HPP_DIR"
        fi
    fi

    # Clone Vulkan-Hpp with matching version tag
    # VK_HEADER_VERSION 275 corresponds to v1.3.275
    local VK_TAG="v1.3.$VK_VERSION"
    echo "Cloning Vulkan-Hpp tag: $VK_TAG..."
    
    if [ -d "$VULKAN_HPP_DIR" ]; then
        rm -rf "$VULKAN_HPP_DIR"
    fi

    git clone --depth 1 --branch "$VK_TAG" https://github.com/KhronosGroup/Vulkan-Hpp "$VULKAN_HPP_DIR" 2>/dev/null || {
        echo "WARNING: Failed to clone Vulkan-Hpp tag $VK_TAG, trying latest..."
        git clone --depth 1 https://github.com/KhronosGroup/Vulkan-Hpp "$VULKAN_HPP_DIR"
    }

    # Copy headers to NDK sysroot
    echo "Installing Vulkan C++ headers..."
    cp "$VULKAN_HPP_DIR/vulkan/vulkan.hpp" "$VULKAN_INCLUDE_DST/" 2>/dev/null || true
    cp "$VULKAN_HPP_DIR/vulkan/vulkan_enums.hpp" "$VULKAN_INCLUDE_DST/" 2>/dev/null || true
    cp "$VULKAN_HPP_DIR/vulkan/vulkan_funcs.hpp" "$VULKAN_INCLUDE_DST/" 2>/dev/null || true
    cp "$VULKAN_HPP_DIR/vulkan/vulkan_handles.hpp" "$VULKAN_INCLUDE_DST/" 2>/dev/null || true
    cp "$VULKAN_HPP_DIR/vulkan/vulkan_hash.hpp" "$VULKAN_INCLUDE_DST/" 2>/dev/null || true
    cp "$VULKAN_HPP_DIR/vulkan/vulkan_raii.hpp" "$VULKAN_INCLUDE_DST/" 2>/dev/null || true
    cp "$VULKAN_HPP_DIR/vulkan/vulkan_static_assertions.hpp" "$VULKAN_INCLUDE_DST/" 2>/dev/null || true
    cp "$VULKAN_HPP_DIR/vulkan/vulkan_structs.hpp" "$VULKAN_INCLUDE_DST/" 2>/dev/null || true
    cp "$VULKAN_HPP_DIR/vulkan/vulkan_to_string.hpp" "$VULKAN_INCLUDE_DST/" 2>/dev/null || true
    cp "$VULKAN_HPP_DIR/vulkan/vulkan_format_traits.hpp" "$VULKAN_INCLUDE_DST/" 2>/dev/null || true

    # Copy any other hpp files
    cp "$VULKAN_HPP_DIR/vulkan/"*.hpp "$VULKAN_INCLUDE_DST/" 2>/dev/null || true

    echo "Vulkan C++ headers installed (version $VK_VERSION)"
}

# ==========================================
# Check Vulkan SDK
# ==========================================
check_vulkan_sdk() {
    echo ""
    echo "=========================================="
    echo "Checking Vulkan SDK..."
    echo "=========================================="

    # Check for glslc (required for shader compilation)
    if command -v glslc &> /dev/null; then
        echo "Found glslc: $(which glslc)"
        # Also setup Vulkan C++ headers
        setup_vulkan_deps
        return 0
    fi

    # Check common Vulkan SDK locations
    local VULKAN_PATHS=(
        "$VULKAN_SDK/bin/glslc"
        "/usr/bin/glslc"
        "$HOME/VulkanSDK/*/x86_64/bin/glslc"
    )

    for path in "${VULKAN_PATHS[@]}"; do
        if [ -f "$path" ]; then
            echo "Found glslc: $path"
            export PATH="$(dirname "$path"):$PATH"
            # Also setup Vulkan C++ headers
            setup_vulkan_deps
            return 0
        fi
    done

    echo "WARNING: Vulkan SDK (glslc) not found!"
    echo "Vulkan backend will be disabled."
    echo ""
    echo "To enable Vulkan support, install the Vulkan SDK:"
    echo "  - Download from: https://vulkan.lunarg.com/sdk/home"
    echo "  - Or install via package manager: sudo apt install glslc"
    echo ""
    BUILD_VULKAN=OFF
    return 1
}

# ==========================================
# Build function for a specific ABI
# ==========================================
build_for_abi() {
    local ABI=$1
    local PLATFORM=$2

    echo ""
    echo "=========================================="
    echo "Building for $ABI..."
    echo "=========================================="

    rm -rf "$BUILD_DIR/$ABI"
    mkdir -p "$BUILD_DIR/$ABI"
    cd "$BUILD_DIR/$ABI"

    # Base CMake arguments
    local CMAKE_ARGS=(
        -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN"
        -DANDROID_ABI="$ABI"
        -DANDROID_PLATFORM="$PLATFORM"
        -DCMAKE_BUILD_TYPE=Release
        -DLLAMA_BUILD_TESTS=OFF
        -DLLAMA_BUILD_EXAMPLES=OFF
        -DLLAMA_BUILD_SERVER=OFF
        -DLLAMA_BUILD_TOOLS=OFF
        -DLLAMA_CURL=OFF
        -DGGML_OPENMP=OFF
        -DGGML_NATIVE=OFF
        -DGGML_LLAMAFILE=OFF
        -DBUILD_SHARED_LIBS=ON
    )

    # Add Vulkan support if enabled
    if [ "$BUILD_VULKAN" = "ON" ]; then
        CMAKE_ARGS+=(-DGGML_VULKAN=ON)
        echo "  Vulkan: ENABLED"
    else
        CMAKE_ARGS+=(-DGGML_VULKAN=OFF)
        echo "  Vulkan: DISABLED"
    fi

    # Add OpenCL support if enabled (arm64 only - Adreno optimized)
    if [ "$BUILD_OPENCL" = "ON" ] && [ "$ABI" = "arm64-v8a" ]; then
        CMAKE_ARGS+=(-DGGML_OPENCL=ON)
        CMAKE_ARGS+=(-DGGML_OPENCL_USE_ADRENO_KERNELS=ON)
        echo "  OpenCL (Adreno): ENABLED"
    else
        CMAKE_ARGS+=(-DGGML_OPENCL=OFF)
        echo "  OpenCL: DISABLED"
    fi

    # Configure
    echo ""
    echo "Configuring CMake..."
    cmake "$LLAMACPP_DIR" "${CMAKE_ARGS[@]}"

    # Build targets
    local TARGETS="llama ggml ggml-base ggml-cpu"

    if [ "$BUILD_VULKAN" = "ON" ]; then
        TARGETS="$TARGETS ggml-vulkan"
    fi

    if [ "$BUILD_OPENCL" = "ON" ] && [ "$ABI" = "arm64-v8a" ]; then
        TARGETS="$TARGETS ggml-opencl"
    fi

    echo ""
    echo "Building targets: $TARGETS"
    cmake --build . --config Release -j$(nproc) --target $TARGETS || true
}

# ==========================================
# Copy libraries function
# ==========================================
copy_libraries() {
    local ABI=$1
    local JNILIBS_DIR="$PROJECT_ROOT/packages/llm_llamacpp/android/src/main/jniLibs"

    echo ""
    echo "Copying $ABI libraries to jniLibs..."

    # Clear existing libraries for this ABI to avoid stale GPU backends
    rm -rf "$JNILIBS_DIR/$ABI"
    mkdir -p "$JNILIBS_DIR/$ABI"

    # Possible source directories
    local SRC_DIRS=(
        "$BUILD_DIR/$ABI/bin"
        "$BUILD_DIR/$ABI/src"
        "$BUILD_DIR/$ABI"
    )

    # Copy libllama.so
    for src_dir in "${SRC_DIRS[@]}"; do
        if [ -f "$src_dir/libllama.so" ]; then
            cp "$src_dir/libllama.so" "$JNILIBS_DIR/$ABI/"
            echo "  Copied libllama.so"
            break
        fi
    done

    # Copy core ggml libraries (always required)
    local GGML_DIRS=(
        "$BUILD_DIR/$ABI/bin"
        "$BUILD_DIR/$ABI/ggml/src"
        "$BUILD_DIR/$ABI"
    )

    for src_dir in "${GGML_DIRS[@]}"; do
        for lib in libggml.so libggml-base.so libggml-cpu.so; do
            if [ -f "$src_dir/$lib" ] && [ ! -f "$JNILIBS_DIR/$ABI/$lib" ]; then
                cp "$src_dir/$lib" "$JNILIBS_DIR/$ABI/"
                echo "  Copied $lib"
            fi
        done
    done

    # Copy Vulkan backend only if it was built (check build config)
    if [ "$BUILD_VULKAN" = "ON" ]; then
        for src_dir in "${GGML_DIRS[@]}" "$BUILD_DIR/$ABI/ggml/src/ggml-vulkan"; do
            if [ -f "$src_dir/libggml-vulkan.so" ] && [ ! -f "$JNILIBS_DIR/$ABI/libggml-vulkan.so" ]; then
                cp "$src_dir/libggml-vulkan.so" "$JNILIBS_DIR/$ABI/"
                echo "  Copied libggml-vulkan.so (GPU backend)"
            fi
        done
    fi

    # Copy OpenCL backend and its loader only if it was built
    if [ "$BUILD_OPENCL" = "ON" ] && [ "$ABI" = "arm64-v8a" ]; then
        for src_dir in "${GGML_DIRS[@]}" "$BUILD_DIR/$ABI/ggml/src/ggml-opencl"; do
            if [ -f "$src_dir/libggml-opencl.so" ] && [ ! -f "$JNILIBS_DIR/$ABI/libggml-opencl.so" ]; then
                cp "$src_dir/libggml-opencl.so" "$JNILIBS_DIR/$ABI/"
                echo "  Copied libggml-opencl.so (Adreno GPU backend)"
            fi
        done

        # Also bundle libOpenCL.so (ICD loader) for devices without system OpenCL
        local OPENCL_LOADER="$NDK_SYSROOT/usr/lib/aarch64-linux-android/libOpenCL.so"
        if [ -f "$OPENCL_LOADER" ] && [ ! -f "$JNILIBS_DIR/$ABI/libOpenCL.so" ]; then
            cp "$OPENCL_LOADER" "$JNILIBS_DIR/$ABI/"
            echo "  Copied libOpenCL.so (OpenCL ICD loader)"
        fi
    fi
}

# ==========================================
# Main Build Process
# ==========================================

echo ""
echo "=========================================="
echo "Android Build Configuration"
echo "=========================================="
echo "  Build Vulkan: $BUILD_VULKAN"
echo "  Build OpenCL: $BUILD_OPENCL"
echo "  Build x86_64: $BUILD_X86_64"
echo "  Build arm64:  $BUILD_ARM64"
echo ""

# Setup dependencies
if [ "$BUILD_OPENCL" = "ON" ]; then
    setup_opencl_deps
fi

if [ "$BUILD_VULKAN" = "ON" ]; then
    check_vulkan_sdk || true
fi

# Build for x86_64 (emulator) - CPU only, no GPU
if [ "$BUILD_X86_64" = "ON" ]; then
    # Temporarily disable GPU for x86_64 (emulator typically doesn't have GPU passthrough)
    SAVE_VULKAN=$BUILD_VULKAN
    SAVE_OPENCL=$BUILD_OPENCL
    BUILD_VULKAN=OFF
    BUILD_OPENCL=OFF

    build_for_abi "x86_64" "android-28"
    copy_libraries "x86_64"

    BUILD_VULKAN=$SAVE_VULKAN
    BUILD_OPENCL=$SAVE_OPENCL
fi

# Build for arm64-v8a (physical devices) - with GPU support
if [ "$BUILD_ARM64" = "ON" ]; then
    build_for_abi "arm64-v8a" "android-28"
    copy_libraries "arm64-v8a"
fi

# ==========================================
# Summary
# ==========================================
JNILIBS_DIR="$PROJECT_ROOT/packages/llm_llamacpp/android/src/main/jniLibs"

echo ""
echo "=========================================="
echo "Build complete!"
echo "=========================================="
echo ""
echo "Libraries in $JNILIBS_DIR:"
find "$JNILIBS_DIR" -name "*.so" -type f 2>/dev/null | sort | while read f; do
    size=$(du -h "$f" | cut -f1)
    arch=$(basename $(dirname "$f"))
    name=$(basename "$f")
    echo "  $arch/$name ($size)"
done

echo ""
echo "GPU Backend Support (arm64-v8a):"
if [ -f "$JNILIBS_DIR/arm64-v8a/libggml-vulkan.so" ]; then
    echo "  ✓ Vulkan (broad GPU support)"
else
    echo "  ✗ Vulkan (not built)"
fi
if [ -f "$JNILIBS_DIR/arm64-v8a/libggml-opencl.so" ]; then
    echo "  ✓ OpenCL (Adreno GPU optimized)"
else
    echo "  ✗ OpenCL (not built)"
fi

echo ""
echo "Now rebuild your Flutter app:"
echo "  cd $PROJECT_ROOT/packages/llm_llamacpp/example_app"
echo "  flutter clean && flutter run"
