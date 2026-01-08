import 'dart:ffi';
import 'dart:io';

/// Load the llama.cpp library for Flutter applications.
///
/// Flutter's plugin system handles the native library loading automatically
/// when using an FFI plugin structure. The library is bundled with the app
/// and accessible via the standard plugin mechanism.
DynamicLibrary loadLibrary() {
  if (Platform.isAndroid) {
    // Android: Pre-load ggml dependencies before loading libllama.so
    // These libraries must be loaded in dependency order
    _loadAndroidDependencies();
    try {
      final lib = DynamicLibrary.open('libllama.so');
      print('[llm_llamacpp] Successfully loaded libllama.so');
      return lib;
    } catch (e) {
      print('[llm_llamacpp] ERROR loading libllama.so: $e');
      rethrow;
    }
  } else if (Platform.isIOS) {
    // iOS: Framework is linked statically or via xcframework
    return DynamicLibrary.process();
  } else if (Platform.isMacOS) {
    // macOS: Dylib is bundled in the app
    return DynamicLibrary.open('libllama.dylib');
  } else if (Platform.isWindows) {
    // Windows: DLL is bundled with the app
    return DynamicLibrary.open('llama.dll');
  } else if (Platform.isLinux) {
    // Linux: Shared library is bundled with the app
    return DynamicLibrary.open('libllama.so');
  } else {
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }
}

/// Pre-load ggml dependency libraries on Android.
///
/// On Android, shared libraries must be loaded in dependency order.
/// libllama.so depends on libggml.so which depends on libggml-base.so
/// and libggml-cpu.so. GPU backends (Vulkan, OpenCL) are optional and
/// loaded silently - if not present, CPU inference continues to work.
///
/// Load order:
/// 1. libggml-base.so (base GGML library)
/// 2. libggml-cpu.so (CPU backend - required)
/// 3. libggml-vulkan.so (Vulkan GPU backend - optional)
/// 4. libggml-opencl.so (OpenCL/Adreno GPU backend - optional)
/// 5. libggml.so (GGML coordinator that manages backends)
void _loadAndroidDependencies() {
  // Required dependencies - these must load successfully
  const requiredDependencies = [
    'libggml-base.so',
    'libggml-cpu.so',
  ];

  // Optional GPU backend dependencies - fail silently if not present
  const optionalGpuBackends = [
    'libggml-vulkan.so', // Vulkan GPU backend (broad device support)
    'libggml-opencl.so', // OpenCL GPU backend (Adreno optimized)
  ];

  // Final coordinator library
  const coordinatorLibrary = 'libggml.so';

  // Load required dependencies
  for (final lib in requiredDependencies) {
    try {
      DynamicLibrary.open(lib);
      print('[llm_llamacpp] Loaded dependency: $lib');
    } catch (e) {
      print('[llm_llamacpp] Failed to load required $lib: $e');
      // Continue anyway - the main library load will fail with a clearer error
    }
  }

  // Attempt to load optional GPU backends (fail silently)
  for (final lib in optionalGpuBackends) {
    try {
      DynamicLibrary.open(lib);
      print('[llm_llamacpp] Loaded GPU backend: $lib');
    } catch (e) {
      // GPU backends are optional - silently continue without them
      print('[llm_llamacpp] GPU backend not available: $lib');
    }
  }

  // Load the GGML coordinator library
  try {
    DynamicLibrary.open(coordinatorLibrary);
    print('[llm_llamacpp] Loaded dependency: $coordinatorLibrary');
  } catch (e) {
    print('[llm_llamacpp] Failed to load $coordinatorLibrary: $e');
  }
}
