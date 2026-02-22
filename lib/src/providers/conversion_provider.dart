import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import '../rust/generated/api.dart' as rust_api;

// State providers
final fileListProvider = StateNotifierProvider<FileListNotifier, List<String>>((ref) {
  return FileListNotifier();
});

final dragStateProvider = StateProvider<bool>((ref) => false);

final outputFormatProvider = StateProvider<String>((ref) => 'png');

final qualityProvider = StateProvider<int>((ref) => 85);

final showAdvancedOptionsProvider = StateProvider<bool>((ref) => false);

final outputDirectoryProvider = StateNotifierProvider<OutputDirectoryNotifier, String>((ref) {
  return OutputDirectoryNotifier();
});

final supportedFormatsProvider = Provider<List<String>>((ref) {
  // This would normally come from Rust backend
  return ['png', 'jpg', 'webp', 'bmp', 'gif', 'pdf', 'html', 'txt', 'mp3', 'mp4'];
});

final conversionTasksProvider = StateNotifierProvider<ConversionTasksNotifier, List<ConversionTask>>((ref) {
  return ConversionTasksNotifier();
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
}

class ConversionTask {
  final String id;
  final String fileName;
  final String inputPath;
  ConversionStatus status;
  int progress;
  String? outputPath;
  String? error;

  ConversionTask({
    required this.id,
    required this.fileName,
    required this.inputPath,
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
      type: FileType.custom,
      allowedExtensions: [
        'png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif', 'ico', 'svg',
        'pdf', 'md', 'html', 'htm', 'txt',
        'mp3', 'wav', 'flac', 'aac', 'ogg',
        'mp4', 'avi', 'mkv', 'mov', 'webm',
      ],
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
    state = [...state, task];
  }

  void updateTask(String id, {
    ConversionStatus? status,
    int? progress,
    String? outputPath,
    String? error,
  }) {
    state = state.map((task) {
      if (task.id == id) {
        return ConversionTask(
          id: task.id,
          fileName: task.fileName,
          inputPath: task.inputPath,
          status: status ?? task.status,
          progress: progress ?? task.progress,
          outputPath: outputPath ?? task.outputPath,
          error: error ?? task.error,
        );
      }
      return task;
    }).toList();
  }

  void clearCompleted() {
    state = state.where((task) => task.status != ConversionStatus.completed).toList();
  }
}

class ConversionNotifier {
  final Ref ref;

  ConversionNotifier(this.ref);

  Future<void> startConversion() async {
    final files = ref.read(fileListProvider);
    final outputFormat = ref.read(outputFormatProvider);
    final quality = ref.read(qualityProvider);
    final outputDir = await ref.read(outputDirectoryProvider.notifier).getDefaultOutputDirectory();

    for (final file in files) {
      final fileName = file.split(RegExp(r'[\\/]')).last;
      final taskId = DateTime.now().millisecondsSinceEpoch.toString();
      
      final task = ConversionTask(
        id: taskId,
        fileName: fileName,
        inputPath: file,
        status: ConversionStatus.converting,
      );
      
      ref.read(conversionTasksProvider.notifier).addTask(task);

      try {
        final options = rust_api.ConvertOptions(
          outputFormat: outputFormat,
          quality: quality,
          width: null,
          height: null,
        );

        final result = await rust_api.convertFile(
          inputPath: file,
          outputDir: outputDir,
          options: options,
        );

        if (result.success && result.outputPath != null) {
          ref.read(conversionTasksProvider.notifier).updateTask(
            taskId,
            status: ConversionStatus.completed,
            progress: 100,
            outputPath: result.outputPath,
          );
        } else {
          ref.read(conversionTasksProvider.notifier).updateTask(
            taskId,
            status: ConversionStatus.failed,
            progress: 0,
            error: result.error ?? 'Unknown error',
          );
        }
      } catch (e) {
        ref.read(conversionTasksProvider.notifier).updateTask(
          taskId,
          status: ConversionStatus.failed,
          progress: 0,
          error: e.toString(),
        );
      }
    }

    // Clear input file list after conversion
    ref.read(fileListProvider.notifier).clear();
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
}
