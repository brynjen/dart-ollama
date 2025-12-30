import 'dart:ffi';
import 'dart:io';

/// Load the llama.cpp library for Flutter applications.
///
/// Flutter's plugin system handles the native library loading automatically
/// when using an FFI plugin structure. The library is bundled with the app
/// and accessible via the standard plugin mechanism.
DynamicLibrary loadLibrary() {
  if (Platform.isAndroid) {
    // Android: Flutter loads JNI libs automatically
    return DynamicLibrary.open('libllama.so');
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

