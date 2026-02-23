import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'src/screens/home_screen.dart';
import 'src/providers/settings_provider.dart';
import 'dart:ffi';
import 'dart:io';
import 'src/rust/generated/frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Optionally preload the dynamic library so the default loader can find it.
  final dylibPath = _resolveRustDylibPath();

  // Explicitly load the correct DLL to avoid FRB content-hash mismatch.
  // (The default loader may pick up an older copy from another directory.)
  await RustLib.init(
    externalLibrary: ExternalLibrary.open(dylibPath),
  );

  runApp(const ProviderScope(child: ConvertXApp()));
}

String _resolveRustDylibPath() {
  if (Platform.isWindows) {
    final cwd = Directory.current.path;
    final candidates = <String>[
      '$cwd\\rust\\target\\release\\convertx_core.dll',
      '$cwd\\..\\rust\\target\\release\\convertx_core.dll',
      'rust\\target\\release\\convertx_core.dll',
      '..\\rust\\target\\release\\convertx_core.dll',
      'convertx_core.dll',
      'convertx_core.dll'.replaceAll('/', '\\'),
    ];
    for (final p in candidates) {
      final f = File(p);
      if (f.existsSync()) return f.absolute.path;
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

class ConvertXApp extends ConsumerWidget {
  const ConvertXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

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
      themeMode: settings.getThemeMode(),
      locale: settings.getLocale(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('zh'),
      ],
      home: const HomeScreen(),
    );
  }
}
