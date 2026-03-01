import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/conversion_provider.dart';
import '../widgets/file_drop_zone.dart';
import '../widgets/convert_panel.dart';
import '../widgets/progress_list.dart';
import '../widgets/resizable_divider.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final horizontalRatio = ref.watch(horizontalPanelRatioProvider);
    final verticalRatio = ref.watch(verticalPanelRatioProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(context),

              // Main content with vertical resizer
              Expanded(
                child: Column(
                  children: [
                    // Top section: horizontal panels
                    Expanded(
                      flex: (verticalRatio * 100).round(),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                            child: Row(
                              children: [
                                // Left panel - File drop zone
                                SizedBox(
                                  width: (constraints.maxWidth - 48) *
                                      horizontalRatio,
                                  child: const FileDropZone(),
                                ),

                                // Horizontal resizable divider
                                ResizableDivider(
                                  direction: Axis.vertical,
                                  initialSize: horizontalRatio,
                                  minSize: 0.2,
                                  maxSize: 0.8,
                                  onResize: (value) {
                                    ref
                                        .read(horizontalPanelRatioProvider
                                            .notifier)
                                        .state = value;
                                  },
                                ),

                                // Right panel - Convert options
                                Expanded(
                                  child: const ConvertPanel(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Vertical resizable divider
                    ResizableDivider(
                      direction: Axis.horizontal,
                      initialSize: verticalRatio,
                      minSize: 0.3,
                      maxSize: 0.9,
                      onResize: (value) {
                        ref.read(verticalPanelRatioProvider.notifier).state =
                            value;
                      },
                    ),

                    // Bottom section - Progress list
                    Expanded(
                      flex: ((1 - verticalRatio) * 100).round(),
                      child: const ProgressList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Logo and title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.transform,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'ConvertX',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
              ),
            ],
          ),
          const Spacer(),
          // Settings button
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }
}
