import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:async';
import 'dart:io';
import '../rust/generated/api.dart' as rust_api;
import 'ffmpeg_provider.dart';

// State providers
final fileListProvider =
    StateNotifierProvider<FileListNotifier, List<String>>((ref) {
  return FileListNotifier();
});

final dragStateProvider = StateProvider<bool>((ref) => false);

final outputFormatProvider = StateProvider<String>((ref) => 'png');

final qualityProvider = StateProvider<int>((ref) => 85);

final showAdvancedOptionsProvider = StateProvider<bool>((ref) => false);

final horizontalPanelRatioProvider = StateProvider<double>((ref) => 0.6);
final verticalPanelRatioProvider = StateProvider<double>((ref) => 0.75);

final outputDirectoryProvider =
    StateNotifierProvider<OutputDirectoryNotifier, String>((ref) {
  return OutputDirectoryNotifier();
});

final supportedFormatsProvider = FutureProvider<List<String>>((ref) async {
  final files = ref.watch(fileListProvider);
  if (files.isEmpty) {
    return ['png', 'jpg', 'webp', 'bmp', 'gif'];
  }

  try {
    final formats =
        await rust_api.getSupportedOutputFormatsForFile(filePath: files.first);
    if (formats.isEmpty) {
      // If file type is not supported or there is no valid output, return empty list
      // so the UI can disable selection.
      return <String>[];
    }
    return formats;
  } catch (_) {
    return <String>[];
  }
});

final conversionTasksProvider =
    StateNotifierProvider<ConversionTasksNotifier, List<ConversionTask>>((ref) {
  return ConversionTasksNotifier();
});

final isConvertingProvider = Provider<bool>((ref) {
  final tasks = ref.watch(conversionTasksProvider);
  return tasks.any((t) => t.status == ConversionStatus.converting);
});

final conversionProvider = Provider<ConversionNotifier>((ref) {
  return ConversionNotifier(ref);
});

// Models
enum ConversionStatus {
  pending,
  converting,
  completed,
  failed,
  cancelled,
}

class ConversionTask {
  final String id;
  final String fileName;
  final String inputPath;
  final DateTime startedAt;
  DateTime? endedAt;
  ConversionStatus status;
  int progress;
  String? outputPath;
  String? error;

  ConversionTask({
    required this.id,
    required this.fileName,
    required this.inputPath,
    required this.startedAt,
    this.endedAt,
    this.status = ConversionStatus.pending,
    this.progress = 0,
    this.outputPath,
    this.error,
  });
}

// Notifiers
class FileListNotifier extends StateNotifier<List<String>> {
  FileListNotifier() : super([]);

  Future<void> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null && result.files.isNotEmpty) {
      state = [...state, ...result.paths.whereType<String>()];
    }
  }

  void addFiles(List<String> paths) {
    state = [...state, ...paths];
  }

  void removeFile(int index) {
    state = [...state.sublist(0, index), ...state.sublist(index + 1)];
  }

  void clear() {
    state = [];
  }
}

class OutputDirectoryNotifier extends StateNotifier<String> {
  OutputDirectoryNotifier() : super('');

  Future<void> pickDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      state = result;
    }
  }

  Future<String> getDefaultOutputDirectory() async {
    if (state.isNotEmpty) return state;

    final documents = await getApplicationDocumentsDirectory();
    final outputDir = '${documents.path}/ConvertX_Output';
    await Directory(outputDir).create(recursive: true);
    return outputDir;
  }
}

class ConversionTasksNotifier extends StateNotifier<List<ConversionTask>> {
  ConversionTasksNotifier() : super([]);

  void addTask(ConversionTask task) {
    state = [task, ...state];
  }

  void updateTask(
    String id, {
    ConversionStatus? status,
    int? progress,
    String? outputPath,
    String? error,
    DateTime? endedAt,
    bool clearOutputPath = false,
    bool clearError = false,
  }) {
    state = state.map((task) {
      if (task.id == id) {
        return ConversionTask(
          id: task.id,
          fileName: task.fileName,
          inputPath: task.inputPath,
          startedAt: task.startedAt,
          endedAt: endedAt ?? task.endedAt,
          status: status ?? task.status,
          progress: progress ?? task.progress,
          outputPath: clearOutputPath ? null : (outputPath ?? task.outputPath),
          error: clearError ? null : (error ?? task.error),
        );
      }
      return task;
    }).toList();
  }

  void clearCompleted() {
    state = state
        .where((task) => task.status != ConversionStatus.completed)
        .toList();
  }

  void removeTask(String id) {
    state = state.where((task) => task.id != id).toList();
  }
}

class ConversionNotifier {
  final Ref ref;

  ConversionNotifier(this.ref);

  Future<void> startConversion() async {
    final isConverting = ref.read(isConvertingProvider);
    if (isConverting) {
      return;
    }
    final files = ref.read(fileListProvider);
    final outputFormat = ref.read(outputFormatProvider);
    final quality = ref.read(qualityProvider);
    final outputDir = await ref
        .read(outputDirectoryProvider.notifier)
        .getDefaultOutputDirectory();

    // Check if FFmpeg is required for any of the tasks (video -> audio)
    bool requiresFfmpeg = false;
    for (final file in files) {
      final ext = file.split('.').last.toLowerCase();
      final isVideo = ['mp4', 'avi', 'mkv', 'mov', 'webm', 'flv'].contains(ext);
      final isAudioOutput =
          ['mp3', 'wav', 'aac', 'flac'].contains(outputFormat);
      if (isVideo && isAudioOutput) {
        requiresFfmpeg = true;
        break;
      }
    }

    String? customFfmpegPath;
    if (requiresFfmpeg) {
      // Prompt download if necessary
      final success = await ref.read(ffmpegProvider.notifier).ensureFfmpeg();
      if (!success) {
        // Find existing task IDs or skip, let's just abort with error state handled by provider UI
        final error =
            ref.read(ffmpegProvider).errorMessage ?? 'Failed to setup FFmpeg';
        for (final file in files) {
          final fileName = file.split(RegExp(r'[\\/]')).last;
          final taskId =
              '${DateTime.now().microsecondsSinceEpoch}_${file.hashCode.abs()}';
          ref.read(conversionTasksProvider.notifier).addTask(ConversionTask(
                id: taskId,
                fileName: fileName,
                inputPath: file,
                startedAt: DateTime.now(),
                status: ConversionStatus.failed,
                error: error,
              ));
        }
        return;
      }
      customFfmpegPath = ref.read(ffmpegProvider).executablePath;
    }

    for (final file in files) {
      final fileName = file.split(RegExp(r'[\\/]')).last;
      final taskId =
          '${DateTime.now().microsecondsSinceEpoch}_${file.hashCode.abs()}';

      final task = ConversionTask(
        id: taskId,
        fileName: fileName,
        inputPath: file,
        startedAt: DateTime.now(),
        status: ConversionStatus.converting,
        progress: 1,
      );

      ref.read(conversionTasksProvider.notifier).addTask(task);

      try {
        final options = rust_api.ConvertOptions(
          outputFormat: outputFormat,
          quality: quality,
          width: null,
          height: null,
          ffmpegPath: customFfmpegPath,
        );

        final result = await rust_api
            .convertFile(
              inputPath: file,
              outputDir: outputDir,
              options: options,
            )
            .timeout(const Duration(minutes: 15));

        if (result.success && result.outputPath != null) {
          ref.read(conversionTasksProvider.notifier).updateTask(
                taskId,
                status: ConversionStatus.completed,
                progress: 100,
                outputPath: result.outputPath,
                endedAt: DateTime.now(),
                clearError: true,
              );
        } else {
          ref.read(conversionTasksProvider.notifier).updateTask(
                taskId,
                status: ConversionStatus.failed,
                progress: 0,
                endedAt: DateTime.now(),
                clearOutputPath: true,
                error: result.error ?? 'Unknown error',
              );
        }
      } on TimeoutException {
        ref.read(conversionTasksProvider.notifier).updateTask(
              taskId,
              status: ConversionStatus.failed,
              progress: 0,
              endedAt: DateTime.now(),
              clearOutputPath: true,
              error: '转换超时（15分钟）。外部工具可能卡住，请重试或改用另一个工具。',
            );
      } catch (e) {
        ref.read(conversionTasksProvider.notifier).updateTask(
              taskId,
              status: ConversionStatus.failed,
              progress: 0,
              endedAt: DateTime.now(),
              clearOutputPath: true,
              error: e.toString(),
            );
      } finally {
        final stillConverting = ref.read(conversionTasksProvider).any(
            (t) => t.id == taskId && t.status == ConversionStatus.converting);
        if (stillConverting) {
          ref.read(conversionTasksProvider.notifier).updateTask(
                taskId,
                status: ConversionStatus.failed,
                progress: 0,
                endedAt: DateTime.now(),
                clearOutputPath: true,
                error: '转换状态异常：任务已结束但未收到完成信号。',
              );
        }
      }
    }

    // Keep selected input files after conversion so users can run repeated conversions
    // (e.g., convert again or convert to another format).
  }

  Future<void> openOutputFolder(String path) async {
    final file = File(path);
    var directory = file.parent.path;
    var filePath = file.path;

    if (Platform.isWindows) {
      // explorer.exe is picky about path separators; normalize them.
      directory = directory.replaceAll('/', '\\');
      filePath = filePath.replaceAll('/', '\\');
      filePath = File(filePath).absolute.path;
      directory = Directory(directory).absolute.path;
    }

    // Best UX on Windows: open folder and select the file.
    if (Platform.isWindows) {
      try {
        if (File(filePath).existsSync()) {
          await Process.start('explorer.exe', ['/select,', filePath]);
        } else {
          await Process.start('explorer.exe', [directory]);
        }
        return;
      } catch (_) {
        // Fallbacks below.
      }
    }

    // Use Rust helper (explorer/open/xdg-open) if available.
    try {
      await rust_api.openFolder(folderPath: directory);
      return;
    } catch (_) {
      // Final fallback.
      await OpenFile.open(directory);
    }
  }

  Future<void> retryTask(String taskId) async {
    final task =
        ref.read(conversionTasksProvider).firstWhere((t) => t.id == taskId);

    // Reset task to pending state
    ref.read(conversionTasksProvider.notifier).updateTask(
          taskId,
          status: ConversionStatus.converting,
          progress: 0,
          endedAt: null,
          clearOutputPath: true,
          clearError: true,
        );

    final outputFormat = ref.read(outputFormatProvider);
    final quality = ref.read(qualityProvider);
    final outputDir = await ref
        .read(outputDirectoryProvider.notifier)
        .getDefaultOutputDirectory();

    // Check if FFmpeg is required
    String? customFfmpegPath;
    final ext = task.inputPath.split('.').last.toLowerCase();
    final isVideo = ['mp4', 'avi', 'mkv', 'mov', 'webm', 'flv'].contains(ext);
    final isAudioOutput = ['mp3', 'wav', 'aac', 'flac'].contains(outputFormat);

    if (isVideo && isAudioOutput) {
      final success = await ref.read(ffmpegProvider.notifier).ensureFfmpeg();
      if (!success) {
        final error =
            ref.read(ffmpegProvider).errorMessage ?? 'Failed to setup FFmpeg';
        ref.read(conversionTasksProvider.notifier).updateTask(
              taskId,
              status: ConversionStatus.failed,
              progress: 0,
              endedAt: DateTime.now(),
              clearOutputPath: true,
              error: error,
            );
        return;
      }
      customFfmpegPath = ref.read(ffmpegProvider).executablePath;
    }

    try {
      final options = rust_api.ConvertOptions(
        outputFormat: outputFormat,
        quality: quality,
        width: null,
        height: null,
        ffmpegPath: customFfmpegPath,
      );

      final result = await rust_api
          .convertFile(
            inputPath: task.inputPath,
            outputDir: outputDir,
            options: options,
          )
          .timeout(const Duration(minutes: 15));

      if (result.success && result.outputPath != null) {
        ref.read(conversionTasksProvider.notifier).updateTask(
              taskId,
              status: ConversionStatus.completed,
              progress: 100,
              outputPath: result.outputPath,
              endedAt: DateTime.now(),
              clearError: true,
            );
      } else {
        ref.read(conversionTasksProvider.notifier).updateTask(
              taskId,
              status: ConversionStatus.failed,
              progress: 0,
              endedAt: DateTime.now(),
              clearOutputPath: true,
              error: result.error ?? 'Unknown error',
            );
      }
    } on TimeoutException {
      ref.read(conversionTasksProvider.notifier).updateTask(
            taskId,
            status: ConversionStatus.failed,
            progress: 0,
            endedAt: DateTime.now(),
            clearOutputPath: true,
            error: 'Conversion timeout (15 minutes)',
          );
    } catch (e) {
      ref.read(conversionTasksProvider.notifier).updateTask(
            taskId,
            status: ConversionStatus.failed,
            progress: 0,
            endedAt: DateTime.now(),
            clearOutputPath: true,
            error: e.toString(),
          );
    }
  }
}
