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
/// and libggml-cpu.so. We load them silently, ignoring errors for
/// optional libraries (like libggml-cuda.so which may not be present).
void _loadAndroidDependencies() {
  // Load in dependency order: base libraries first, then composite libraries
  final dependencies = [
    'libggml-base.so',
    'libggml-cpu.so',
    'libggml.so',
  ];

  for (final lib in dependencies) {
    try {
      DynamicLibrary.open(lib);
      print('[llm_llamacpp] Loaded dependency: $lib');
    } catch (e) {
      print('[llm_llamacpp] Failed to load $lib: $e');
    }
  }
}

