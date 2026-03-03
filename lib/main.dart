import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'src/screens/home_screen.dart';
import 'src/providers/settings_provider.dart';
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
  if (Platform.isMacOS) {
    final cwd = Directory.current.path;
    final candidates = <String>[
      '$cwd/rust/target/release/libconvertx_core.dylib',
      '$cwd/../rust/target/release/libconvertx_core.dylib',
      'rust/target/release/libconvertx_core.dylib',
      '../rust/target/release/libconvertx_core.dylib',
      'libconvertx_core.dylib',
    ];
    for (final p in candidates) {
      final f = File(p);
      if (f.existsSync()) return f.absolute.path;
    }
    return 'libconvertx_core.dylib';
  }
  if (Platform.isLinux) {
    return 'libconvertx_core.so';
  }
  throw UnsupportedError('Unsupported platform');
}

class ConvertXApp extends ConsumerWidget {
  const ConvertXApp({super.key});

  ThemeData _buildLightTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3B82F6),
      brightness: Brightness.light,
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Roboto',
    );
  }

  ThemeData _buildDarkTheme() {
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF007ACC),
      brightness: Brightness.dark,
    );

    final scheme = base.copyWith(
      primary: const Color(0xFF3794FF),
      onPrimary: const Color(0xFF001B3D),
      primaryContainer: const Color(0xFF094771),
      onPrimaryContainer: const Color(0xFFC7E4FF),
      onSurface: const Color(0xFFD4D4D4),
      onSurfaceVariant: const Color(0xFFB0B0B0),
      surface: const Color(0xFF1E1E1E),
      surfaceContainerLowest: const Color(0xFF181818),
      surfaceContainerLow: const Color(0xFF202020),
      surfaceContainer: const Color(0xFF252526),
      surfaceContainerHigh: const Color(0xFF2D2D2D),
      surfaceContainerHighest: const Color(0xFF333333),
      outline: const Color(0xFF3E3E42),
      outlineVariant: const Color(0xFF2A2A2A),
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      dividerColor: scheme.outlineVariant.withValues(alpha: 0.35),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surfaceContainer,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.primary, width: 1.2),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'ConvertX',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
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
