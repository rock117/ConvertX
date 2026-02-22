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
    final quality = ref.watch(qualityProvider);
    final showAdvanced = ref.watch(showAdvancedOptionsProvider);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.tune,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Convert Settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Settings
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Output format
                _buildFormatSelector(context, ref, outputFormat),
                
                const SizedBox(height: 20),

                // Advanced options toggle
                InkWell(
                  onTap: () {
                    ref.read(showAdvancedOptionsProvider.notifier).state =
                        !showAdvanced;
                  },
                  child: Row(
                    children: [
                      Icon(
                        showAdvanced
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Advanced Options',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),

                // Advanced options
                if (showAdvanced) ...[
                  const SizedBox(height: 16),
                  _buildAdvancedOptions(context, ref, quality),
                ],

                const SizedBox(height: 24),

                // Convert button
                FilledButton.icon(
                  onPressed: (files.isEmpty || isConverting)
                      ? null
                      : () {
                          ref.read(conversionProvider).startConversion();
                        },
                  icon: isConverting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.transform),
                  label: Text(isConverting ? 'Converting...' : 'Convert'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatSelector(BuildContext context, WidgetRef ref, String format) {
    final supportedFormatsAsync = ref.watch(supportedFormatsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Output Format',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        supportedFormatsAsync.when(
          data: (supportedFormats) {
            final items = supportedFormats
                .map((f) => DropdownMenuItem(
                      value: f,
                      child: Text(f.toUpperCase()),
                    ))
                .toList();

            final hasItems = items.isNotEmpty;
            final safeValue = hasItems
                ? (supportedFormats.contains(format) ? format : supportedFormats.first)
                : null;

            // Ensure selected value is always valid.
            if (hasItems && safeValue != format) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(outputFormatProvider.notifier).state = safeValue!;
              });
            }

            return DropdownButtonFormField<String>(
              initialValue: safeValue,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                helperText: hasItems ? null : '该文件类型暂无可用输出格式',
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
            '无法获取支持的输出格式',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedOptions(BuildContext context, WidgetRef ref, int quality) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quality slider
        Text(
          'Quality: $quality%',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Slider(
          value: quality.toDouble(),
          min: 1,
          max: 100,
          divisions: 100,
          label: '$quality%',
          onChanged: (value) {
            ref.read(qualityProvider.notifier).state = value.round();
          },
        ),

        const SizedBox(height: 16),

        // Output directory
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(outputDirectoryProvider.notifier).pickDirectory();
                },
                icon: const Icon(Icons.folder_outlined),
                label: const Text('Output Folder'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
