import 'dart:ffi';
import 'dart:io';

import 'generated/bridge_definitions.dart';

class ConvertXRust {
  static ConvertXRust? _instance;
  late final DynamicLibrary _dylib;
  late final ConvertXCore _api;

  ConvertXRust._() {
    _dylib = _openLibrary();
    _api = ConvertXCore(_dylib);
  }

  static ConvertXRust get instance => _instance ??= ConvertXRust._();

  ConvertXCore get api => _api;

  static DynamicLibrary _openLibrary() {
    if (Platform.isWindows) {
      return DynamicLibrary.open('convertx_core.dll');
    } else if (Platform.isLinux) {
      return DynamicLibrary.open('libconvertx_core.so');
    } else if (Platform.isMacOS) {
      return DynamicLibrary.open('libconvertx_core.dylib');
    }
    throw UnsupportedError('Unsupported platform');
  }
}

// Re-export API for convenience
ConvertXCore get rust => ConvertXRust.instance.api;
