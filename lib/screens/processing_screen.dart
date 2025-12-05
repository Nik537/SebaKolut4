import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/log_viewer.dart';
import 'export_screen.dart';

/// Data class for tracking open image popup windows
class _ImagePopupData {
  final String id;
  final Uint8List imageBytes;
  final String imageName;
  Offset position;
  final int imageWidth;
  final int imageHeight;

  _ImagePopupData({
    required this.id,
    required this.imageBytes,
    required this.imageName,
    required this.position,
    required this.imageWidth,
    required this.imageHeight,
  });
}

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

class _GroupProcessingView extends ConsumerStatefulWidget {
  final ImageGroup group;

  const _GroupProcessingView({required this.group});

  @override
  ConsumerState<_GroupProcessingView> createState() => _GroupProcessingViewState();
}

class _GroupProcessingViewState extends ConsumerState<_GroupProcessingView> {
  final List<_ImagePopupData> _openPopups = [];
  int _popupIdCounter = 0;

  @override
  Widget build(BuildContext context) {
    final allImages = ref.watch(importedImagesProvider);
    final processingStates = ref.watch(imageProcessingStateProvider);
    final colorizedImages = ref.watch(colorizedImagesByGroupProvider(widget.group.id));

    final groupImages = allImages.where((img) => widget.group.imageIds.contains(img.id)).toList();

    // Get group-level state from first image (all images in group share same state)
    final groupState = groupImages.isNotEmpty ? processingStates[groupImages.first.id] : null;

    // Get the single colorized result for this group
    final colorizedImage = colorizedImages.isNotEmpty ? colorizedImages.first : null;

    return Stack(
      children: [
        // Main content
        SingleChildScrollView(
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
                    return GestureDetector(
                      onTap: () => _openImagePopup(image.bytes, image.filename),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            image.thumbnailBytes,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
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
              _buildResultSection(context, groupState, colorizedImage),
            ],
          ),
        ),
        // Popup windows
        ..._openPopups.map((popup) => _DraggableImagePopup(
          key: ValueKey(popup.id),
          popup: popup,
          onClose: () => _closePopup(popup.id),
          onDragUpdate: (delta) => _updatePopupPosition(popup.id, delta),
          onBringToFront: () => _bringToFront(popup.id),
        )),
      ],
    );
  }

  Future<void> _openImagePopup(Uint8List imageBytes, String imageName) async {
    // Decode image to get dimensions
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final imageWidth = frame.image.width;
    final imageHeight = frame.image.height;
    frame.image.dispose();
    codec.dispose();

    // Check if widget is still mounted after async operation
    if (!mounted) return;

    // Calculate initial position (with offset for multiple windows)
    final offsetMultiplier = _openPopups.length % 5;
    final initialPosition = Offset(
      100 + (offsetMultiplier * 30),
      100 + (offsetMultiplier * 30),
    );

    setState(() {
      _openPopups.add(_ImagePopupData(
        id: '${widget.group.id}_${_popupIdCounter++}',
        imageBytes: imageBytes,
        imageName: imageName,
        position: initialPosition,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      ));
    });
  }

  void _closePopup(String popupId) {
    setState(() {
      _openPopups.removeWhere((p) => p.id == popupId);
    });
  }

  void _updatePopupPosition(String popupId, Offset delta) {
    setState(() {
      final popup = _openPopups.firstWhere((p) => p.id == popupId);
      popup.position += delta;
    });
  }

  void _bringToFront(String popupId) {
    setState(() {
      final index = _openPopups.indexWhere((p) => p.id == popupId);
      if (index != -1 && index != _openPopups.length - 1) {
        final popup = _openPopups.removeAt(index);
        _openPopups.add(popup);
      }
    });
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
        return _EditableHexColor(
          hexColor: state.extractedHex!,
          groupId: widget.group.id,
          onColorChanged: (newHex) {
            ref.read(processingControllerProvider).recolorizeGroup(widget.group.id, newHex);
          },
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

  Widget _buildResultSection(BuildContext context, ImageProcessingState? state, ColorizedImage? colorizedImage) {
    if (colorizedImage != null) {
      return _ResultWithSliders(groupId: widget.group.id, colorizedImage: colorizedImage);
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

/// Draggable image popup window
class _DraggableImagePopup extends StatelessWidget {
  final _ImagePopupData popup;
  final VoidCallback onClose;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onBringToFront;

  const _DraggableImagePopup({
    super.key,
    required this.popup,
    required this.onClose,
    required this.onDragUpdate,
    required this.onBringToFront,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const headerHeight = 40.0;
    const maxWidthFactor = 0.8;
    const maxHeightFactor = 0.8;

    // Calculate popup size based on image dimensions
    final maxWidth = screenSize.width * maxWidthFactor;
    final maxHeight = screenSize.height * maxHeightFactor - headerHeight;

    double popupWidth;
    double popupHeight;

    if (popup.imageWidth <= maxWidth && popup.imageHeight <= maxHeight) {
      // Image fits within max constraints
      popupWidth = popup.imageWidth.toDouble();
      popupHeight = popup.imageHeight.toDouble();
    } else {
      // Scale to fit
      final widthRatio = maxWidth / popup.imageWidth;
      final heightRatio = maxHeight / popup.imageHeight;
      final scale = widthRatio < heightRatio ? widthRatio : heightRatio;
      popupWidth = popup.imageWidth * scale;
      popupHeight = popup.imageHeight * scale;
    }

    return Positioned(
      left: popup.position.dx,
      top: popup.position.dy,
      child: GestureDetector(
        onTap: onBringToFront,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: popupWidth,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Draggable header
                GestureDetector(
                  onPanUpdate: (details) => onDragUpdate(details.delta),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.move,
                    child: Container(
                      height: headerHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              popup.imageName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: onClose,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            iconSize: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Image
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  child: SizedBox(
                    width: popupWidth,
                    height: popupHeight,
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.memory(
                        popup.imageBytes,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
              _EditableSlider(
                label: 'Hue',
                value: adjustments.hue,
                min: -0.2,
                max: 0.2,
                onChangeEnd: (v) => ref.read(imageAdjustmentsProvider.notifier).updateHue(groupId, v),
              ),
              const SizedBox(height: 16),
              _EditableSlider(
                label: 'Saturation',
                value: adjustments.saturation,
                min: -0.3,
                max: 0.3,
                onChangeEnd: (v) => ref.read(imageAdjustmentsProvider.notifier).updateSaturation(groupId, v),
              ),
              const SizedBox(height: 16),
              _EditableSlider(
                label: 'Brightness',
                value: adjustments.brightness,
                min: -0.3,
                max: 0.3,
                onChangeEnd: (v) => ref.read(imageAdjustmentsProvider.notifier).updateBrightness(groupId, v),
              ),
              const SizedBox(height: 24),
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

}

/// Editable slider with local state for smooth dragging and keyboard input
class _EditableSlider extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChangeEnd;

  const _EditableSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChangeEnd,
  });

  @override
  State<_EditableSlider> createState() => _EditableSliderState();
}

class _EditableSliderState extends State<_EditableSlider> {
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
  void didUpdateWidget(_EditableSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update local value when provider value changes (e.g., from reset)
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
      widget.onChangeEnd(clamped);
    } else {
      // Invalid input, revert to current value
      _textController.text = _localValue.toStringAsFixed(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(
              width: 60,
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                ],
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue, width: 1),
                  ),
                ),
                onSubmitted: (_) => _submitTextValue(),
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
            value: _localValue,
            min: widget.min,
            max: widget.max,
            onChanged: (v) {
              setState(() {
                _localValue = v;
                _textController.text = v.toStringAsFixed(2);
              });
            },
            onChangeEnd: widget.onChangeEnd,
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
