import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/screens/home_screen.dart';
import 'dart:ffi';
import 'dart:io';
import 'src/rust/generated/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Optionally preload the dynamic library so the default loader can find it.
  final dylibPath = _resolveRustDylibPath();
  DynamicLibrary.open(dylibPath);

  // Use flutter_rust_bridge generated default loader config.
  await RustLib.init();

  runApp(const ProviderScope(child: ConvertXApp()));
}

String _resolveRustDylibPath() {
  if (Platform.isWindows) {
    final candidates = <String>[
      'convertx_core.dll',
      'rust/target/release/convertx_core.dll',
      '../rust/target/release/convertx_core.dll',
    ];
    for (final p in candidates) {
      if (File(p).existsSync()) return p;
    }
    return 'convertx_core.dll';
  }
  if (Platform.isLinux) {
    return 'libconvertx_core.so';
  }
  if (Platform.isMacOS) {
    return 'libconvertx_core.dylib';
  }
  throw UnsupportedError('Unsupported platform');
}

class ConvertXApp extends StatelessWidget {
  const ConvertXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ConvertX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
