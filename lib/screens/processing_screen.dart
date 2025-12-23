import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../services/image_cache_service.dart';
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Processing images...'),
          ],
        ),
        duration: Duration(seconds: 60),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider);
    final processingComplete = ref.watch(processingCompleteProvider);

    // Show snackbar when processing completes
    ref.listen<bool>(processingCompleteProvider, (previous, next) {
      if (next && !(previous ?? false)) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Processing complete!'),
              ],
            ),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (!_processingStarted)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton(
                onPressed: _startProcessing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Start Processing'),
              ),
            ),
          const LogViewerButton(),
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
}

class _GroupProcessingView extends ConsumerStatefulWidget {
  final ImageGroup group;

  const _GroupProcessingView({required this.group});

  @override
  ConsumerState<_GroupProcessingView> createState() => _GroupProcessingViewState();
}

class _GroupProcessingViewState extends ConsumerState<_GroupProcessingView>
    with SingleTickerProviderStateMixin {
  late TabController _generationTabController;

  @override
  void initState() {
    super.initState();
    _generationTabController = TabController(length: 3, vsync: this);
    // Sync with provider
    _generationTabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _generationTabController.removeListener(_onTabChanged);
    _generationTabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_generationTabController.indexIsChanging) {
      final newIndex = _generationTabController.index;
      ref.read(selectedGenerationProvider(widget.group.id).notifier).state = newIndex;
      // Also update the aggregated map for efficient export selection
      ref.read(allSelectedGenerationsProvider.notifier).setGeneration(widget.group.id, newIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allImages = ref.watch(importedImagesProvider);
    final processingStates = ref.watch(imageProcessingStateProvider);
    final colorizedImages = ref.watch(colorizedImagesByGroupProvider(widget.group.id));
    final selectedGeneration = ref.watch(selectedGenerationProvider(widget.group.id));

    final groupImages = allImages.where((img) => widget.group.imageIds.contains(img.id)).toList();

    // Get group-level state from first image (all images in group share same state)
    final groupState = groupImages.isNotEmpty ? processingStates[groupImages.first.id] : null;

    // Get the colorized image for the selected generation
    final colorizedImage = colorizedImages.isNotEmpty
        ? colorizedImages.where((img) => img.generationIndex == selectedGeneration).firstOrNull
        : null;

    // Check generation counts for UI decisions
    final hasGenerations = colorizedImages.isNotEmpty;
    final hasMultipleGenerations = colorizedImages.length > 1;

    return Stack(
      children: [
        // Main content
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Source Images Section with Regenerate button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Source Images (${groupImages.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (hasGenerations || groupState?.hasError == true)
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.read(processingControllerProvider).regenerateGroup(widget.group.id);
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(groupState?.hasError == true && !hasGenerations ? 'Retry' : 'Regenerate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 240,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: groupImages.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final image = groupImages[index];
                    final imageCache = ref.read(imageCacheServiceProvider);
                    final fullBytes = imageCache.getFullImage(image.id);
                    // Use thumbnail as fallback for display
                    final displayBytes = fullBytes ?? imageCache.getThumbnail(image.id);
                    return GestureDetector(
                      onTap: () {
                        if (fullBytes != null) {
                          _openImageInSystemViewer(fullBytes, image.filename);
                        }
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: displayBytes != null
                              ? Image.memory(
                                  displayBytes,
                                  width: 240,
                                  height: 240,
                                  fit: BoxFit.cover,
                                )
                              : const SizedBox(
                                  width: 240,
                                  height: 240,
                                  child: Center(child: Icon(Icons.image_not_supported)),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Status/Color Section
              _buildStatusSection(context, groupState, groupImages.length),
              const SizedBox(height: 24),

              // Generation tabs (only show when we have multiple generations)
              if (hasMultipleGenerations) ...[
                Text(
                  'Generations',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TabBar(
                    controller: _generationTabController,
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    tabs: [
                      _buildGenerationTab(colorizedImages, 0),
                      _buildGenerationTab(colorizedImages, 1),
                      _buildGenerationTab(colorizedImages, 2),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

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
              _buildResultSection(context, groupState, colorizedImage, selectedGeneration),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenerationTab(List<ColorizedImage> colorizedImages, int index) {
    final image = colorizedImages.where((img) => img.generationIndex == index).firstOrNull;
    final hexColor = image?.appliedHex ?? '---';
    return Tab(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (image != null)
              Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _hexToColor(image.appliedHex),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade400, width: 0.5),
                ),
              ),
            Text('Gen ${index + 1}'),
            if (image != null)
              Text(
                ' ($hexColor)',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openImageInSystemViewer(Uint8List imageBytes, String imageName) async {
    try {
      // Get the temporary directory
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$imageName');

      // Write image bytes to the temp file
      await tempFile.writeAsBytes(imageBytes);

      // Open the file with the system's default application
      await OpenFile.open(tempFile.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
        // Don't show editable hex here, it's shown per-generation in the result section
        return _buildStatusRow(
          icon: Icons.check_circle,
          color: Colors.green,
          text: 'Processing complete',
        );
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

  Widget _buildResultSection(BuildContext context, ImageProcessingState? state, ColorizedImage? colorizedImage, int generationIndex) {
    if (colorizedImage != null) {
      return _ResultWithSliders(
        groupId: widget.group.id,
        colorizedImage: colorizedImage,
        generationIndex: generationIndex,
      );
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
  final int generationIndex;

  const _ResultWithSliders({
    required this.groupId,
    required this.colorizedImage,
    required this.generationIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use generation-specific adjustment key
    final adjustmentKey = '$groupId:$generationIndex';
    final adjustments = ref.watch(groupAdjustmentsProvider(adjustmentKey));
    final adjustedImageAsync = ref.watch(adjustedImageByGenerationProvider((
      groupId: groupId,
      generationIndex: generationIndex,
    )));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Editable hex color for this generation
        Row(
          children: [
            _EditableHexColor(
              hexColor: colorizedImage.appliedHex,
              groupId: groupId,
              onColorChanged: (newHex) {
                ref.read(processingControllerProvider).recolorizeGeneration(
                  groupId,
                  generationIndex,
                  newHex,
                );
              },
            ),
            const Spacer(),
            // Export button for this generation
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await ref.read(exportControllerProvider).exportSingleGeneration(
                    groupId,
                    generationIndex,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Exported generation ${generationIndex + 1} (${colorizedImage.appliedHex})'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Export failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Export'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Main content row
        Row(
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
            // Adjustment controls (50% width)
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AdjustmentButtons(
                    label: 'Hue',
                    value: adjustments.hue,
                    min: -0.2,
                    max: 0.2,
                    step: 0.01,
                    onChanged: (v) => ref.read(imageAdjustmentsProvider.notifier).updateHue(adjustmentKey, v),
                  ),
                  const SizedBox(height: 12),
                  _AdjustmentButtons(
                    label: 'Saturation',
                    value: adjustments.saturation,
                    min: -0.3,
                    max: 0.3,
                    step: 0.01,
                    onChanged: (v) => ref.read(imageAdjustmentsProvider.notifier).updateSaturation(adjustmentKey, v),
                  ),
                  const SizedBox(height: 12),
                  _AdjustmentButtons(
                    label: 'Brightness',
                    value: adjustments.brightness,
                    min: -0.3,
                    max: 0.3,
                    step: 0.01,
                    onChanged: (v) => ref.read(imageAdjustmentsProvider.notifier).updateBrightness(adjustmentKey, v),
                  ),
                  const SizedBox(height: 12),
                  _AdjustmentButtons(
                    label: 'Contrast',
                    value: adjustments.contrast,
                    min: -0.3,
                    max: 0.3,
                    step: 0.01,
                    onChanged: (v) => ref.read(imageAdjustmentsProvider.notifier).updateContrast(adjustmentKey, v),
                  ),
                  const SizedBox(height: 16),
                  // Reset all button
                  TextButton.icon(
                    onPressed: () => ref.read(imageAdjustmentsProvider.notifier).reset(adjustmentKey),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reset All'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Adjustment control with plus, minus, and reset buttons
class _AdjustmentButtons extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;

  const _AdjustmentButtons({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.step = 0.01,
    required this.onChanged,
  });

  @override
  State<_AdjustmentButtons> createState() => _AdjustmentButtonsState();
}

class _AdjustmentButtonsState extends State<_AdjustmentButtons> {
  late double _localValue;
  late TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _localValue = widget.value;
    _textController = TextEditingController(text: _localValue.toStringAsFixed(2));
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_AdjustmentButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_isEditing) {
      _localValue = widget.value;
      _textController.text = _localValue.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      _submitTextValue();
    }
    setState(() {
      _isEditing = _focusNode.hasFocus;
    });
  }

  void _submitTextValue() {
    final parsed = double.tryParse(_textController.text);
    if (parsed != null) {
      final clamped = parsed.clamp(widget.min, widget.max);
      setState(() {
        _localValue = clamped;
        _textController.text = clamped.toStringAsFixed(2);
      });
      widget.onChanged(clamped);
    } else {
      _textController.text = _localValue.toStringAsFixed(2);
    }
  }

  void _increment() {
    final newValue = (_localValue + widget.step).clamp(widget.min, widget.max);
    setState(() {
      _localValue = newValue;
      _textController.text = newValue.toStringAsFixed(2);
    });
    widget.onChanged(newValue);
  }

  void _decrement() {
    final newValue = (_localValue - widget.step).clamp(widget.min, widget.max);
    setState(() {
      _localValue = newValue;
      _textController.text = newValue.toStringAsFixed(2);
    });
    widget.onChanged(newValue);
  }

  void _reset() {
    setState(() {
      _localValue = 0.0;
      _textController.text = '0.00';
    });
    widget.onChanged(0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Button row
        Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              onPressed: _decrement,
              icon: const Icon(Icons.remove),
              iconSize: 20,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 60,
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Colors.blue, width: 1),
                  ),
                ),
                onSubmitted: (_) => _submitTextValue(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _increment,
              icon: const Icon(Icons.add),
              iconSize: 20,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              iconSize: 18,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Reset to 0',
              style: IconButton.styleFrom(
                backgroundColor: Colors.orange.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
        // Slider below buttons
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: _localValue,
            min: widget.min,
            max: widget.max,
            onChanged: (v) {
              // Update local state only for smooth dragging
              setState(() {
                _localValue = v;
                _textController.text = v.toStringAsFixed(2);
              });
            },
            onChangeEnd: (v) {
              // Trigger provider update when slider is released
              widget.onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}

/// Editable hex color input with live color swatch preview
class _EditableHexColor extends StatefulWidget {
  final String hexColor;
  final String groupId;
  final ValueChanged<String> onColorChanged;

  const _EditableHexColor({
    required this.hexColor,
    required this.groupId,
    required this.onColorChanged,
  });

  @override
  State<_EditableHexColor> createState() => _EditableHexColorState();
}

class _EditableHexColorState extends State<_EditableHexColor> {
  late TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();
  bool _isEditing = false;
  String _displayHex = '';
  bool _isValidHex = true;

  @override
  void initState() {
    super.initState();
    _displayHex = widget.hexColor;
    _textController = TextEditingController(text: widget.hexColor);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_EditableHexColor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update when provider value changes (e.g., after re-colorization)
    if (oldWidget.hexColor != widget.hexColor && !_isEditing) {
      _displayHex = widget.hexColor;
      _textController.text = widget.hexColor;
      _isValidHex = true;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      _submitValue();
    }
    setState(() {
      _isEditing = _focusNode.hasFocus;
    });
  }

  bool _isValidHexColor(String hex) {
    final pattern = RegExp(r'^#[0-9A-Fa-f]{6}$');
    return pattern.hasMatch(hex);
  }

  void _onTextChanged(String value) {
    // Auto-add # prefix if not present
    String hex = value;
    if (!hex.startsWith('#') && hex.isNotEmpty) {
      hex = '#$hex';
    }
    hex = hex.toUpperCase();

    setState(() {
      _isValidHex = _isValidHexColor(hex) || hex.length < 7;
      if (_isValidHexColor(hex)) {
        _displayHex = hex;
      }
    });
  }

  void _submitValue() {
    String hex = _textController.text.trim().toUpperCase();
    if (!hex.startsWith('#')) {
      hex = '#$hex';
    }

    if (_isValidHexColor(hex)) {
      if (hex != widget.hexColor) {
        widget.onColorChanged(hex);
      }
      setState(() {
        _displayHex = hex;
        _textController.text = hex;
        _isValidHex = true;
      });
    } else {
      // Invalid input, revert to current value
      setState(() {
        _displayHex = widget.hexColor;
        _textController.text = widget.hexColor;
        _isValidHex = true;
      });
    }
  }

  Color _hexToColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    if (hexCode.length != 6) return Colors.grey;
    try {
      return Color(int.parse('FF$hexCode', radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _hexToColor(_displayHex),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade400),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: TextField(
            controller: _textController,
            focusNode: _focusNode,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              color: _isValidHex ? Colors.black87 : Colors.red,
            ),
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[#0-9A-Fa-f]')),
              LengthLimitingTextInputFormatter(7),
            ],
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: _isValidHex ? Colors.blue : Colors.red,
                  width: 1.5,
                ),
              ),
              errorBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 1),
              ),
            ),
            onChanged: _onTextChanged,
            onSubmitted: (_) => _submitValue(),
          ),
        ),
      ],
    );
  }
}
