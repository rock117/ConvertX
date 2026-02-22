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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: dragState
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: dragState
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: dragState ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_open,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Files to Convert',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  if (files.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        ref.read(fileListProvider.notifier).clear();
                      },
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Clear All'),
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
            Icons.cloud_upload_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Drag & Drop files here',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'or',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              final result = await ref.read(fileListProvider.notifier).pickFiles();
            },
            icon: const Icon(Icons.add),
            label: const Text('Browse Files'),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList(BuildContext context, WidgetRef ref, List<String> files) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final fileName = file.split(RegExp(r'[\\/]')).last;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              _getFileIcon(fileName),
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              file,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                ref.read(fileListProvider.notifier).removeFile(index);
              },
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
