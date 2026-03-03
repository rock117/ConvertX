import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/conversion_provider.dart';
import '../providers/ffmpeg_provider.dart';

class ProgressList extends ConsumerStatefulWidget {
  const ProgressList({super.key});

  @override
  ConsumerState<ProgressList> createState() => _ProgressListState();
}

class _ProgressListState extends ConsumerState<ProgressList> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _convertingHint(ConversionTask task, Duration duration) {
    final ext = task.inputPath.split('.').last.toLowerCase();
    final elapsed = _formatDuration(duration);

    if (ext == 'epub') {
      return 'EPUB -> PDF: running external tool... ($elapsed)';
    }

    return 'Converting... ($elapsed)';
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      final minutes = duration.inMinutes % 60;
      return '${duration.inHours}h ${minutes}m';
    }
    if (duration.inMinutes > 0) {
      final seconds = duration.inSeconds % 60;
      return '${duration.inMinutes}m ${seconds}s';
    }
    return '${duration.inSeconds}s';
  }

  void _showErrorDetails(BuildContext context, ConversionTask task) {
    final error = task.error ?? 'Unknown error';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Conversion Error - ${task.fileName}', style: const TextStyle(fontSize: 16)),
        content: SingleChildScrollView(
          child: SelectableText(error, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(conversionTasksProvider);
    final isDownloadingFfmpeg =
        ref.watch(ffmpegProvider).status == FfmpegDownloadStatus.downloading ||
            ref.watch(ffmpegProvider).status == FfmpegDownloadStatus.extracting;

    final hasContent = tasks.isNotEmpty || isDownloadingFfmpeg;

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tasks',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                if (hasContent)
                  TextButton(
                    onPressed: () {
                      ref.read(conversionTasksProvider.notifier).clearCompleted();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 24),
                    ),
                    child: const Text('Clear Completed', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),

          // Content area
          Expanded(
            child: hasContent
                ? ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: tasks.length + (isDownloadingFfmpeg ? 1 : 0),
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                    itemBuilder: (context, index) {
                      if (isDownloadingFfmpeg && index == 0) {
                        return _buildFfmpegDownloadItem(context);
                      }

                      final taskIndex = isDownloadingFfmpeg ? index - 1 : index;
                      final task = tasks[taskIndex];
                      return _buildTaskItem(context, task);
                    },
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 32,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No active tasks',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFfmpegDownloadItem(BuildContext context) {
    final state = ref.watch(ffmpegProvider);
    final isExtracting = state.status == FfmpegDownloadStatus.extracting;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: isExtracting ? null : state.progress,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Downloading FFmpeg component...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isExtracting
                      ? 'Extracting files...'
                      : '${(state.progress * 100).toStringAsFixed(1)}% completed',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, ConversionTask task) {
    final endedAt = task.endedAt ?? DateTime.now();
    final duration = endedAt.difference(task.startedAt);

    // Get source file size
    String fileSize = '';
    int? sourceBytes;
    try {
      final file = File(task.inputPath);
      if (file.existsSync()) {
        sourceBytes = file.lengthSync();
        fileSize = _formatFileSize(sourceBytes);
      }
    } catch (_) {}

    // Get output file size (if completed)
    String? outputFileSize;
    int? outputBytes;
    String? compressionRatio;
    if (task.status == ConversionStatus.completed && task.outputPath != null) {
      try {
        final outputFile = File(task.outputPath!);
        if (outputFile.existsSync()) {
          outputBytes = outputFile.lengthSync();
          outputFileSize = _formatFileSize(outputBytes);

          // Calculate compression ratio
          if (sourceBytes != null && sourceBytes > 0) {
            final ratio = ((sourceBytes - outputBytes) / sourceBytes * 100);
            if (ratio > 0) {
              compressionRatio = '-${ratio.toStringAsFixed(1)}%';
            } else if (ratio < 0) {
              compressionRatio = '+${(-ratio).toStringAsFixed(1)}%';
            }
          }
        }
      } catch (_) {}
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {}, // Hover effect
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Status icon
              SizedBox(
                width: 20,
                child: Center(
                  child: task.status == ConversionStatus.converting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          task.status == ConversionStatus.completed
                              ? Icons.check_circle
                              : task.status == ConversionStatus.failed
                                  ? Icons.error
                                  : Icons.schedule,
                          size: 16,
                          color: task.status == ConversionStatus.completed
                              ? Colors.green
                              : task.status == ConversionStatus.failed
                                  ? Colors.red
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // File name and info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.fileName,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (fileSize.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            outputFileSize != null
                                ? '$fileSize → $outputFileSize'
                                : fileSize,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                          ),
                          if (compressionRatio != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: compressionRatio.startsWith('-')
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                compressionRatio,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: compressionRatio.startsWith('-')
                                          ? Colors.green[700]
                                          : Colors.orange[700],
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),

                    // Status text and path
                    if (task.status == ConversionStatus.completed && task.outputPath != null)
                      Text(
                        'Completed in ${_formatDuration(duration)} • ${task.outputPath}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                      )
                    else if (task.status == ConversionStatus.failed && task.error != null)
                      Text(
                        task.error!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 11,
                            ),
                      )
                    else if (task.status == ConversionStatus.converting)
                      Text(
                        _convertingHint(task, duration),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 11,
                            ),
                      )
                    else
                      Text(
                        'Waiting...',
                        maxLines: 1,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Completed: reverse convert + open folder
                  if (task.status == ConversionStatus.completed) ...[
                    IconButton(
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      onPressed: () {
                        ref.read(conversionProvider).reverseConvert(task.id);
                      },
                      tooltip: 'Convert back',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      splashRadius: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    IconButton(
                      icon: const Icon(Icons.folder_open, size: 16),
                      onPressed: () {
                        ref
                            .read(conversionProvider)
                            .openOutputFolder(task.outputPath!);
                      },
                      tooltip: 'Open folder',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      splashRadius: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],

                  // Converting: cancel button
                  if (task.status == ConversionStatus.converting)
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        ref.read(conversionTasksProvider.notifier).updateTask(
                              task.id,
                              status: ConversionStatus.cancelled,
                              endedAt: DateTime.now(),
                              clearOutputPath: true,
                              error: 'Cancelled',
                            );
                      },
                      tooltip: 'Cancel',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      splashRadius: 16,
                      color: Theme.of(context).colorScheme.error,
                    ),

                  // Failed/Cancelled: view error + retry
                  if (task.status == ConversionStatus.failed || task.status == ConversionStatus.cancelled) ...[
                    if (task.error != null && task.status == ConversionStatus.failed)
                      IconButton(
                        icon: const Icon(Icons.info_outline, size: 16),
                        onPressed: () => _showErrorDetails(context, task),
                        tooltip: 'View error',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        splashRadius: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 16),
                      onPressed: () {
                        ref.read(conversionProvider).retryTask(task.id);
                      },
                      tooltip: 'Retry',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      splashRadius: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
