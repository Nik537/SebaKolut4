import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/log_viewer.dart';
import 'export_screen.dart';

class ProcessingScreen extends ConsumerStatefulWidget {
  const ProcessingScreen({super.key});

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _processingStarted = false;

  @override
  void initState() {
    super.initState();
    final groups = ref.read(groupsProvider);
    _tabController = TabController(length: groups.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _startProcessing() {
    setState(() => _processingStarted = true);
    ref.read(processingControllerProvider).processAllGroups();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider);
    final isProcessing = ref.watch(isProcessingProvider);
    final processingComplete = ref.watch(processingCompleteProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: const [
          LogViewerButton(),
        ],
        bottom: groups.length > 1
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: groups.map((g) => Tab(text: g.name)).toList(),
              )
            : null,
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            padding: const EdgeInsets.all(16),
            color: _getStatusColor(isProcessing, processingComplete),
            child: Row(
              children: [
                if (isProcessing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else if (processingComplete)
                  const Icon(Icons.check_circle, color: Colors.white)
                else
                  const Icon(Icons.pending, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  _getStatusText(isProcessing, processingComplete, _processingStarted),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                if (!_processingStarted)
                  ElevatedButton(
                    onPressed: _startProcessing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    child: const Text('Start Processing'),
                  ),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: groups.length > 1
                ? TabBarView(
                    controller: _tabController,
                    children: groups.map((g) => _GroupProcessingView(group: g)).toList(),
                  )
                : groups.isNotEmpty
                    ? _GroupProcessingView(group: groups.first)
                    : const Center(child: Text('No groups to process')),
          ),
          // Bottom action bar
          if (processingComplete)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ExportScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Export All'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(bool isProcessing, bool processingComplete) {
    if (processingComplete) return Colors.green;
    if (isProcessing) return Colors.blue;
    return Colors.orange;
  }

  String _getStatusText(bool isProcessing, bool processingComplete, bool started) {
    if (processingComplete) return 'Processing complete!';
    if (isProcessing) return 'Processing images...';
    if (!started) return 'Ready to process';
    return 'Waiting...';
  }
}

class _GroupProcessingView extends ConsumerWidget {
  final ImageGroup group;

  const _GroupProcessingView({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allImages = ref.watch(importedImagesProvider);
    final processingStates = ref.watch(imageProcessingStateProvider);
    final colorizedImages = ref.watch(colorizedImagesByGroupProvider(group.id));

    final groupImages = allImages.where((img) => group.imageIds.contains(img.id)).toList();

    // Get group-level state from first image (all images in group share same state)
    final groupState = groupImages.isNotEmpty ? processingStates[groupImages.first.id] : null;

    // Get the single colorized result for this group
    final colorizedImage = colorizedImages.isNotEmpty ? colorizedImages.first : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Source Images Section
          Text(
            'Source Images (${groupImages.length})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: groupImages.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final image = groupImages[index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    image.thumbnailBytes,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Status/Color Section
          _buildStatusSection(context, groupState, groupImages.length),
          const SizedBox(height: 24),

          // Result Section
          Text(
            'Result',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          _buildResultSection(context, groupState, colorizedImage, ref),
        ],
      ),
    );
  }

  Widget _buildStatusSection(BuildContext context, ImageProcessingState? state, int imageCount) {
    if (state == null) {
      return _buildStatusRow(
        icon: Icons.pending,
        color: Colors.grey,
        text: 'Waiting to process $imageCount images...',
      );
    }

    switch (state.status) {
      case ProcessingStatus.pending:
        return _buildStatusRow(
          icon: Icons.pending,
          color: Colors.grey,
          text: 'Ready to analyze $imageCount images',
        );
      case ProcessingStatus.extractingColor:
        return _buildStatusRow(
          icon: Icons.colorize,
          color: Colors.blue,
          text: 'Analyzing $imageCount images...',
          showProgress: true,
        );
      case ProcessingStatus.colorExtracted:
      case ProcessingStatus.colorizing:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildColorPreview(state.extractedHex!),
            const SizedBox(height: 8),
            _buildStatusRow(
              icon: Icons.brush,
              color: Colors.orange,
              text: 'Colorizing template...',
              showProgress: true,
            ),
          ],
        );
      case ProcessingStatus.completed:
        return _buildColorPreview(state.extractedHex!);
      case ProcessingStatus.error:
        return _buildStatusRow(
          icon: Icons.error,
          color: Colors.red,
          text: 'Error: ${state.errorMessage ?? "Unknown error"}',
        );
    }
  }

  Widget _buildStatusRow({
    required IconData icon,
    required Color color,
    required String text,
    bool showProgress = false,
  }) {
    return Row(
      children: [
        if (showProgress)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: color,
            ),
          )
        else
          Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildColorPreview(String hexColor) {
    final color = _hexToColor(hexColor);
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade400),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          hexColor,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildResultSection(BuildContext context, ImageProcessingState? state, ColorizedImage? colorizedImage, WidgetRef ref) {
    if (colorizedImage != null) {
      return _ResultWithSliders(groupId: group.id, colorizedImage: colorizedImage);
    }

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: state?.isProcessing == true
            ? const CircularProgressIndicator()
            : Icon(
                Icons.image_outlined,
                color: Colors.grey.shade400,
                size: 48,
              ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }
}

class _ResultWithSliders extends ConsumerWidget {
  final String groupId;
  final ColorizedImage colorizedImage;

  const _ResultWithSliders({
    required this.groupId,
    required this.colorizedImage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adjustments = ref.watch(groupAdjustmentsProvider(groupId));
    final adjustedImageAsync = ref.watch(adjustedImageBytesProvider(groupId));
    final backgroundMode = ref.watch(backgroundModeProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Result image (50% width)
        Expanded(
          flex: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: adjustedImageAsync.when(
              data: (bytes) => bytes != null
                  ? Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    )
                  : const SizedBox(),
              loading: () => Container(
                height: 200,
                color: Colors.grey.shade200,
                child: const Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Container(
                height: 200,
                color: Colors.grey.shade200,
                child: Center(child: Text('Error: $e')),
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Sliders (50% width)
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSlider(
                context,
                ref,
                label: 'Hue',
                value: adjustments.hue,
                min: -1.0,
                max: 1.0,
                onChanged: (v) => ref.read(imageAdjustmentsProvider.notifier).updateHue(groupId, v),
              ),
              const SizedBox(height: 16),
              _buildSlider(
                context,
                ref,
                label: 'Saturation',
                value: adjustments.saturation,
                min: -1.0,
                max: 1.0,
                onChanged: (v) => ref.read(imageAdjustmentsProvider.notifier).updateSaturation(groupId, v),
              ),
              const SizedBox(height: 16),
              _buildSlider(
                context,
                ref,
                label: 'Brightness',
                value: adjustments.brightness,
                min: -1.0,
                max: 1.0,
                onChanged: (v) => ref.read(imageAdjustmentsProvider.notifier).updateBrightness(groupId, v),
              ),
              const SizedBox(height: 16),
              _buildSlider(
                context,
                ref,
                label: 'Sharpness',
                value: adjustments.sharpness,
                min: 0.0,
                max: 1.0,
                onChanged: (v) => ref.read(imageAdjustmentsProvider.notifier).updateSharpness(groupId, v),
              ),
              const SizedBox(height: 24),
              // Background toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Background',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (backgroundMode == BackgroundMode.transparent)
                        Text(
                          'PNG export only',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade700,
                          ),
                        ),
                    ],
                  ),
                  SegmentedButton<BackgroundMode>(
                    segments: const [
                      ButtonSegment(
                        value: BackgroundMode.white,
                        label: Text('White'),
                        icon: Icon(Icons.square, size: 16),
                      ),
                      ButtonSegment(
                        value: BackgroundMode.transparent,
                        label: Text('None'),
                        icon: Icon(Icons.square_outlined, size: 16),
                      ),
                    ],
                    selected: {backgroundMode},
                    onSelectionChanged: (Set<BackgroundMode> selection) {
                      ref.read(backgroundModeProvider.notifier).state = selection.first;
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      textStyle: WidgetStateProperty.all(
                        const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Reset button
              TextButton.icon(
                onPressed: () => ref.read(imageAdjustmentsProvider.notifier).reset(groupId),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reset Adjustments'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSlider(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

