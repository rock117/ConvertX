import 'dart:io';
import 'package:dio/dio.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FfmpegDownloadStatus {
  notDownloaded,
  downloading,
  extracting,
  ready,
  error,
}

class FfmpegState {
  final FfmpegDownloadStatus status;
  final double progress; // 0.0 to 1.0
  final String? executablePath;
  final String? errorMessage;

  const FfmpegState({
    required this.status,
    this.progress = 0.0,
    this.executablePath,
    this.errorMessage,
  });

  FfmpegState copyWith({
    FfmpegDownloadStatus? status,
    double? progress,
    String? executablePath,
    String? errorMessage,
  }) {
    return FfmpegState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      executablePath: executablePath ?? this.executablePath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class FfmpegNotifier extends StateNotifier<FfmpegState> {
  FfmpegNotifier() : super(const FfmpegState(status: FfmpegDownloadStatus.notDownloaded)) {
    _checkExistingInstallation();
  }

  // Windows build of FFmpeg from BtbN (GPL shared)
  static const _ffmpegDownloadUrl =
      'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl-shared.zip';

  Future<void> _checkExistingInstallation() async {
    // 1. First check if it's already in the system PATH
    try {
      final result = await Process.run('ffmpeg', ['-version']);
      if (result.exitCode == 0) {
        state = state.copyWith(
          status: FfmpegDownloadStatus.ready,
          executablePath: 'ffmpeg', // Let the system resolve it via PATH
        );
        return;
      }
    } catch (_) {
      // ffmpeg not found in PATH, continue to check local installation
    }

    // 2. Check local app support directory installation
    final appDir = await getApplicationSupportDirectory();
    final ffmpegExe = File('${appDir.path}/ffmpeg/bin/ffmpeg.exe');

    if (ffmpegExe.existsSync()) {
      state = state.copyWith(
        status: FfmpegDownloadStatus.ready,
        executablePath: ffmpegExe.path,
      );
    }
  }

  Future<bool> ensureFfmpeg() async {
    if (state.status == FfmpegDownloadStatus.ready) {
      return true;
    }

    if (!Platform.isWindows) {
      state = state.copyWith(
        status: FfmpegDownloadStatus.error,
        errorMessage: 'Auto-download is only supported on Windows. Please install FFmpeg manually.',
      );
      return false;
    }

    try {
      state = state.copyWith(status: FfmpegDownloadStatus.downloading, progress: 0.0);
      
      final appDir = await getApplicationSupportDirectory();
      final zipPath = '${appDir.path}/ffmpeg.zip';
      final extractDir = '${appDir.path}/ffmpeg_temp';
      final finalDir = '${appDir.path}/ffmpeg';

      // 1. Download
      final dio = Dio();
      await dio.download(
        _ffmpegDownloadUrl,
        zipPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            state = state.copyWith(
              status: FfmpegDownloadStatus.downloading,
              progress: received / total,
            );
          }
        },
      );

      // 2. Extract
      state = state.copyWith(status: FfmpegDownloadStatus.extracting);
      
      // Run extraction in a separate isolate to avoid blocking the main thread
      // but for simplicity here we just await it (archive package is synchronous mostly)
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          final outFile = File('$extractDir/$filename');
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(data);
        } else {
          await Directory('$extractDir/$filename').create(recursive: true);
        }
      }

      // 3. Move the inner ffmpeg folder to final destination
      // The zip usually contains a root folder like "ffmpeg-master-latest-win64-gpl-shared"
      final dir = Directory(extractDir);
      final entities = dir.listSync();
      if (entities.isNotEmpty && entities.first is Directory) {
        final innerDir = entities.first as Directory;
        
        // Clean old if exists
        final destDir = Directory(finalDir);
        if (destDir.existsSync()) {
          destDir.deleteSync(recursive: true);
        }
        
        innerDir.renameSync(finalDir);
      }

      // Cleanup
      File(zipPath).deleteSync();
      if (Directory(extractDir).existsSync()) {
        Directory(extractDir).deleteSync(recursive: true);
      }

      final ffmpegExe = File('$finalDir/bin/ffmpeg.exe');
      if (ffmpegExe.existsSync()) {
        state = state.copyWith(
          status: FfmpegDownloadStatus.ready,
          executablePath: ffmpegExe.path,
        );
        return true;
      } else {
        throw Exception('ffmpeg.exe not found after extraction');
      }
    } catch (e) {
      state = state.copyWith(
        status: FfmpegDownloadStatus.error,
        errorMessage: 'Failed to download FFmpeg: $e',
      );
      return false;
    }
  }
}

final ffmpegProvider = StateNotifierProvider<FfmpegNotifier, FfmpegState>((ref) {
  return FfmpegNotifier();
});
