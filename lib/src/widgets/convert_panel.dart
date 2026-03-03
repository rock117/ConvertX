import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/conversion_provider.dart';

class ConvertPanel extends ConsumerWidget {
  const ConvertPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(fileListProvider);
    final isConverting = ref.watch(isConvertingProvider);
    final outputFormat = ref.watch(outputFormatProvider);
    final showAdvanced = ref.watch(showAdvancedOptionsProvider);

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.2),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.35),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.tune,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                if (!isConverting)
                  SizedBox(
                    height: 28,
                    child: FilledButton.icon(
                      onPressed: files.isEmpty
                          ? null
                          : () {
                              ref.read(conversionProvider).startConversion();
                            },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('Convert'),
                    ),
                  )
                else if (isConverting)
                  SizedBox(
                    height: 28,
                    child: FilledButton.icon(
                      onPressed: null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      icon: const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      label: const Text('Converting'),
                    ),
                  ),
              ],
            ),
          ),

          // Settings content (scrollable)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Output format
                  _buildFormatSelector(context, ref, outputFormat),

                  const SizedBox(height: 16),

                  // Output directory
                  _buildOutputDirectory(context, ref),

                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),

                  // Advanced options toggle
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        ref.read(showAdvancedOptionsProvider.notifier).state =
                            !showAdvanced;
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(
                          children: [
                            AnimatedRotation(
                              turns: showAdvanced ? 0.25 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Advanced Options',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Advanced options
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: showAdvanced
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12, left: 4),
                            child: _buildAdvancedOptions(context, ref, outputFormat),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatSelector(
      BuildContext context, WidgetRef ref, String format) {
    final supportedFormatsAsync = ref.watch(supportedFormatsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Format',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 6),
        supportedFormatsAsync.when(
          data: (supportedFormats) {
            final items = supportedFormats.map((f) {
              final description = _getFormatDescription(f);
              return DropdownMenuItem(
                value: f,
                child: Text(
                  description != null
                      ? '${f.toUpperCase()} - $description'
                      : f.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList();

            final hasItems = items.isNotEmpty;
            final safeValue = hasItems
                ? (supportedFormats.contains(format)
                    ? format
                    : supportedFormats.first)
                : null;

            // Ensure selected value is always valid.
            if (hasItems && safeValue != format) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(outputFormatProvider.notifier).state = safeValue!;
              });
            }

            return DropdownButtonFormField<String>(
              isDense: true,
              initialValue: safeValue,
              decoration: InputDecoration(
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                helperText: hasItems
                    ? null
                    : 'No available output formats for this file type',
                helperStyle: const TextStyle(fontSize: 11),
              ),
              items: hasItems ? items : const <DropdownMenuItem<String>>[],
              onChanged: hasItems
                  ? (value) {
                      if (value != null) {
                        ref.read(outputFormatProvider.notifier).state = value;
                      }
                    }
                  : null,
            );
          },
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (_, __) => Text(
            'Failed to get supported formats',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
        ),
      ],
    );
  }

  String? _getFormatDescription(String format) {
    final descriptions = {
      // Image formats
      'png': 'Transparency, lossless',
      'jpg': 'Small size, universal',
      'jpeg': 'Small size, universal',
      'webp': 'Modern, efficient',
      'bmp': 'Uncompressed',
      'ico': 'Windows icon',
      'gif': 'Animated support',
      // Document formats
      'pdf': 'Document standard',
      'html': 'Web format',
      'txt': 'Plain text',
      'md': 'Markdown',
      'docx': 'Word document',
      'pptx': 'PowerPoint',
      // Config formats
      'yaml': 'Human-readable config',
      'yml': 'YAML shorthand',
      'json': 'Data interchange',
      'properties': 'Java properties',
      // Audio formats
      'mp3': 'Compressed audio',
      'wav': 'Lossless audio',
      'aac': 'Efficient audio',
      'flac': 'Lossless compression',
      'ogg': 'Open format',
      'm4a': 'Apple audio',
      // Video formats
      'mp4': 'Universal video',
      'avi': 'Legacy format',
      'mkv': 'High quality',
      'mov': 'QuickTime',
      'webm': 'Web format',
      'flv': 'Flash video',
    };
    return descriptions[format.toLowerCase()];
  }

  Widget _buildOutputDirectory(BuildContext context, WidgetRef ref) {
    final outputDir = ref.watch(outputDirectoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Output Folder',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        outputDir.isEmpty
                            ? 'Default: Documents/ConvertX_Output'
                            : outputDir,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: outputDir.isEmpty
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                  : null,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              onPressed: () async {
                await ref
                    .read(outputDirectoryProvider.notifier)
                    .pickDirectory();
              },
              icon: const Icon(Icons.more_horiz, size: 16),
              tooltip: 'Change folder',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              splashRadius: 20,
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdvancedOptions(
      BuildContext context, WidgetRef ref, String outputFormat) {
    final isImageFormat = [
      'png',
      'jpg',
      'jpeg',
      'webp',
      'bmp',
      'ico',
      'gif',
    ].contains(outputFormat.toLowerCase());

    final isAudioFormat = [
      'mp3',
      'wav',
      'aac',
      'flac',
      'ogg',
      'm4a',
    ].contains(outputFormat.toLowerCase());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image quality
        if (isImageFormat) ...[
          _buildImageQualityOptions(context, ref),
        ],

        // Audio options
        if (isAudioFormat) ...[
          _buildAudioOptions(context, ref, outputFormat),
        ],

        // Info for other formats
        if (!isImageFormat && !isAudioFormat) ...[
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'No advanced options available for this format.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildImageQualityOptions(BuildContext context, WidgetRef ref) {
    final imageQuality = ref.watch(imageQualityProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Image Quality',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '$imageQuality%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: imageQuality.toDouble(),
            min: 1,
            max: 100,
            divisions: 100,
            onChanged: (value) {
              ref.read(imageQualityProvider.notifier).state = value.round();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAudioOptions(
      BuildContext context, WidgetRef ref, String outputFormat) {
    final audioQuality = ref.watch(audioQualityProvider);
    final audioBitrate = ref.watch(audioBitrateProvider);
    final audioSampleRate = ref.watch(audioSampleRateProvider);

    final isLossless = outputFormat.toLowerCase() == 'flac' ||
        outputFormat.toLowerCase() == 'wav';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quality/Bitrate (for lossy formats)
        if (!isLossless) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                outputFormat.toLowerCase() == 'mp3' ||
                        outputFormat.toLowerCase() == 'ogg'
                    ? 'Quality (Lower is better)'
                    : 'Bitrate',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                outputFormat.toLowerCase() == 'mp3' ||
                        outputFormat.toLowerCase() == 'ogg'
                    ? audioQuality.toString()
                    : '${audioBitrate ?? 192} kbps',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: outputFormat.toLowerCase() == 'mp3' ||
                    outputFormat.toLowerCase() == 'ogg'
                ? Slider(
                    value: audioQuality.toDouble(),
                    min: 0,
                    max: 9,
                    divisions: 9,
                    onChanged: (value) {
                      ref.read(audioQualityProvider.notifier).state = value.round();
                    },
                  )
                : Slider(
                    value: (audioBitrate ?? 192).toDouble(),
                    min: 64,
                    max: 320,
                    divisions: 16,
                    onChanged: (value) {
                      ref.read(audioBitrateProvider.notifier).state = value.round();
                    },
                  ),
          ),
          const SizedBox(height: 12),
        ],

        // Sample rate
        Text(
          'Sample Rate',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int?>(
          isDense: true,
          initialValue: audioSampleRate,
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: const [
            DropdownMenuItem(value: null, child: Text('Auto', style: TextStyle(fontSize: 13))),
            DropdownMenuItem(value: 44100, child: Text('44.1 kHz (CD)', style: TextStyle(fontSize: 13))),
            DropdownMenuItem(value: 48000, child: Text('48 kHz (DVD)', style: TextStyle(fontSize: 13))),
            DropdownMenuItem(value: 96000, child: Text('96 kHz (HD)', style: TextStyle(fontSize: 13))),
          ],
          onChanged: (value) {
            ref.read(audioSampleRateProvider.notifier).state = value;
          },
        ),
        if (isLossless) ...[
          const SizedBox(height: 8),
          Text(
            'Lossless format - quality parameters are not applicable.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
          ),
        ],
      ],
    );
  }
}
