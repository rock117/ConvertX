import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/conversion_provider.dart';

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
      return 'EPUB -> PDF: running external tool (pandoc/ebook-convert), may take a few minutes... ($elapsed)';
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
        title: Text('Conversion Error - ${task.fileName}'),
        content: SingleChildScrollView(
          child: SelectableText(error),
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

    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Conversion Tasks',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    ref.read(conversionTasksProvider.notifier).clearCompleted();
                  },
                  child: const Text('Clear Completed'),
                ),
              ],
            ),
          ),

          // Task list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _buildTaskItem(context, task);
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, ConversionTask task) {
    final endedAt = task.endedAt ?? DateTime.now();
    final duration = endedAt.difference(task.startedAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Status icon
          Icon(
            task.status == ConversionStatus.completed
                ? Icons.check_circle
                : task.status == ConversionStatus.failed
                    ? Icons.error
                    : task.status == ConversionStatus.converting
                        ? Icons.sync
                        : Icons.schedule,
            size: 20,
            color: task.status == ConversionStatus.completed
                ? Colors.green
                : task.status == ConversionStatus.failed
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),

          // File name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.fileName,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (task.status == ConversionStatus.converting)
                  Text(
                    _convertingHint(task, duration),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                if (task.status == ConversionStatus.completed)
                  Text(
                    'Completed in ${_formatDuration(duration)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                        ),
                  ),
                if (task.status == ConversionStatus.failed)
                  Text(
                    'Failed after ${_formatDuration(duration)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                if (task.status == ConversionStatus.completed && task.outputPath != null)
                  Text(
                    task.outputPath!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                if (task.status == ConversionStatus.failed && task.error != null)
                  Text(
                    task.error!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                if (task.status == ConversionStatus.converting)
                  LinearProgressIndicator(
                    value: null,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Action button
          if (task.status == ConversionStatus.completed)
            IconButton(
              icon: const Icon(Icons.folder_open, size: 18),
              onPressed: () {
                ref.read(conversionProvider).openOutputFolder(task.outputPath!);
              },
              tooltip: 'Open in folder',
            )
          else if (task.status == ConversionStatus.failed && task.error != null)
            IconButton(
              icon: const Icon(Icons.info_outline, size: 18),
              onPressed: () => _showErrorDetails(context, task),
              tooltip: 'View error details',
            ),
        ],
      ),
    );
  }
}
