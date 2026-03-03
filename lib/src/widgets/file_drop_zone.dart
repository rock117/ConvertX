import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../providers/conversion_provider.dart';

class FileDropZone extends ConsumerWidget {
  const FileDropZone({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dragState = ref.watch(dragStateProvider);
    final files = ref.watch(fileListProvider);

    return DropTarget(
      onDragEntered: (details) {
        ref.read(dragStateProvider.notifier).state = true;
      },
      onDragExited: (details) {
        ref.read(dragStateProvider.notifier).state = false;
      },
      onDragDone: (details) {
        final paths = details.files.map((f) => f.path).toList();
        ref.read(fileListProvider.notifier).addFiles(paths);
        ref.read(dragStateProvider.notifier).state = false;
      },
      child: Container(
        decoration: BoxDecoration(
          color: dragState
              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2)
              : Theme.of(context).colorScheme.surface,
          border: Border(
            right: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Files',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  if (files.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        ref.read(fileListProvider.notifier).clear();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 24),
                      ),
                      child: const Text('Clear', style: TextStyle(fontSize: 12)),
                    ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () async {
                      await ref.read(fileListProvider.notifier).pickFiles();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    tooltip: 'Add files',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    splashRadius: 16,
                  ),
                ],
              ),
            ),
            
            // Drop zone content
            Expanded(
              child: files.isEmpty
                  ? _buildEmptyState(context, ref)
                  : _buildFileList(context, ref, files),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.move_to_inbox_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Drop files here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList(BuildContext context, WidgetRef ref, List<String> files) {
    return ListView.separated(
      itemCount: files.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
      ),
      itemBuilder: (context, index) {
        final file = files[index];
        final fileName = file.split(RegExp(r'[\\/]')).last;
        
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {}, // For hover effect
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _getFileIcon(fileName),
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          file,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    splashRadius: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    onPressed: () {
                      ref.read(fileListProvider.notifier).removeFile(index);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'webp':
      case 'gif':
      case 'bmp':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'md':
      case 'txt':
      case 'html':
        return Icons.description;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audio_file;
      case 'mp4':
      case 'avi':
      case 'mkv':
        return Icons.video_file;
      default:
        return Icons.insert_drive_file;
    }
  }
}
