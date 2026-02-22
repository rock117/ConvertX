import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/conversion_provider.dart';

class ProgressList extends ConsumerWidget {
  const ProgressList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                return _buildTaskItem(context, ref, task);
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, WidgetRef ref, ConversionTask task) {
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
                    value: task.progress / 100,
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
            ),
        ],
      ),
    );
  }
}
