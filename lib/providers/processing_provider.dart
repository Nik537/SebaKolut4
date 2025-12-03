import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';
import 'images_provider.dart';
import 'groups_provider.dart';
import 'log_provider.dart';

final geminiServiceProvider = Provider<GeminiService>((ref) => GeminiService());
final nanoBananaServiceProvider =
    Provider<NanoBananaService>((ref) => NanoBananaService());

// Template image bytes provider (using SILK Template.png with transparency)
final templateImageProvider = FutureProvider<Uint8List>((ref) async {
  final data = await rootBundle.load('assets/images/SILK Template.png');
  return data.buffer.asUint8List();
});

// Background mode enum
enum BackgroundMode { white, transparent }

// Background mode state provider
final backgroundModeProvider = StateProvider<BackgroundMode>((ref) => BackgroundMode.white);

// Processing state for individual images
final imageProcessingStateProvider =
    StateNotifierProvider<ImageProcessingStateNotifier, Map<String, ImageProcessingState>>((ref) {
  return ImageProcessingStateNotifier();
});

class ImageProcessingStateNotifier
    extends StateNotifier<Map<String, ImageProcessingState>> {
  ImageProcessingStateNotifier() : super({});

  void setStatus(String imageId, ProcessingStatus status, {String? extractedHex, String? errorMessage}) {
    state = {
      ...state,
      imageId: ImageProcessingState(
        imageId: imageId,
        status: status,
        extractedHex: extractedHex ?? state[imageId]?.extractedHex,
        errorMessage: errorMessage,
      ),
    };
  }

  void reset() {
    state = {};
  }
}

// Colorized images provider
final colorizedImagesProvider =
    StateNotifierProvider<ColorizedImagesNotifier, List<ColorizedImage>>((ref) {
  return ColorizedImagesNotifier();
});

class ColorizedImagesNotifier extends StateNotifier<List<ColorizedImage>> {
  ColorizedImagesNotifier() : super([]);

  void addColorizedImage(ColorizedImage image) {
    state = [...state, image];
  }

  void reset() {
    state = [];
  }

  List<ColorizedImage> getByGroup(String groupId) {
    return state.where((img) => img.groupId == groupId).toList();
  }
}

// Get colorized images for a specific group
final colorizedImagesByGroupProvider =
    Provider.family<List<ColorizedImage>, String>((ref, groupId) {
  final colorized = ref.watch(colorizedImagesProvider);
  return colorized.where((img) => img.groupId == groupId).toList();
});

// Processing controller
final processingControllerProvider = Provider<ProcessingController>((ref) {
  return ProcessingController(ref);
});

class ProcessingController {
  final Ref _ref;

  ProcessingController(this._ref);

  LogNotifier get _log => _ref.read(logProvider.notifier);

  Future<void> processAllGroups() async {
    final groups = _ref.read(groupsProvider);
    final images = _ref.read(importedImagesProvider);

    _log.info('Starting processing for ${groups.length} groups');

    try {
      final templateBytes = await _ref.read(templateImageProvider.future);
      _log.info('Template image loaded (${templateBytes.length} bytes)');

      final geminiService = _ref.read(geminiServiceProvider);
      final nanoBananaService = _ref.read(nanoBananaServiceProvider);

      // Initialize services
      _log.info('Initializing Gemini service...');
      geminiService.initialize();
      _log.success('Gemini service initialized');

      _log.info('Initializing Nano Banana service...');
      await nanoBananaService.initialize();
      _log.success('Nano Banana service initialized');

      for (final group in groups) {
        _log.info('Processing group: ${group.name} (${group.imageIds.length} images)');
        await _processGroup(
          group: group,
          images: images,
          templateBytes: templateBytes,
          geminiService: geminiService,
          nanoBananaService: nanoBananaService,
        );
      }

      _log.success('All groups processed successfully!');
    } catch (e, stack) {
      _log.error('Failed to process groups', details: '$e\n\nStack trace:\n$stack');
    }
  }

  Future<void> _processGroup({
    required ImageGroup group,
    required List<ImportedImage> images,
    required Uint8List templateBytes,
    required GeminiService geminiService,
    required NanoBananaService nanoBananaService,
  }) async {
    final processingNotifier = _ref.read(imageProcessingStateProvider.notifier);
    final colorizedNotifier = _ref.read(colorizedImagesProvider.notifier);

    // Get all images in this group
    final groupImages = group.imageIds
        .map((id) => images.firstWhere((img) => img.id == id))
        .toList();

    _log.info('Analyzing ${groupImages.length} images to determine color...');

    // Mark all images as extracting color
    for (final image in groupImages) {
      processingNotifier.setStatus(image.id, ProcessingStatus.extractingColor);
    }

    try {
      // Extract color from ALL images in the group at once
      final hexColor = await geminiService.extractColorFromMultipleImages(
        groupImages.map((img) => img.bytes).toList(),
      );

      _log.success('Color determined for group: $hexColor');

      // Mark all images as color extracted
      for (final image in groupImages) {
        processingNotifier.setStatus(
          image.id,
          ProcessingStatus.colorExtracted,
          extractedHex: hexColor,
        );
      }

      // Now colorize the template ONCE for the entire group
      _log.info('Colorizing template with $hexColor...');

      // Mark first image as colorizing (to show progress)
      processingNotifier.setStatus(groupImages.first.id, ProcessingStatus.colorizing);

      final colorizedImage = await nanoBananaService.colorizeTemplate(
        templateImageBytes: templateBytes,
        hexColor: hexColor,
        sourceImageId: groupImages.first.id, // Use first image as reference
        groupId: group.id,
      );

      _log.success('Template colorized successfully (${colorizedImage.bytes.length} bytes)');

      // Add ONE colorized image for the entire group
      colorizedNotifier.addColorizedImage(colorizedImage);

      // Mark all images in the group as completed
      for (final image in groupImages) {
        processingNotifier.setStatus(image.id, ProcessingStatus.completed, extractedHex: hexColor);
      }

      _log.success('Group ${group.name} completed!');
    } catch (e, stack) {
      final errorMsg = e.toString();
      _log.error('Failed to process group ${group.name}',
          details: '$errorMsg\n\nStack trace:\n$stack');

      // Mark all images as error
      for (final image in groupImages) {
        processingNotifier.setStatus(
          image.id,
          ProcessingStatus.error,
          errorMessage: errorMsg,
        );
      }
    }
  }

}

// Overall processing status
final isProcessingProvider = Provider<bool>((ref) {
  final states = ref.watch(imageProcessingStateProvider);
  return states.values.any((s) => s.isProcessing);
});

final processingCompleteProvider = Provider<bool>((ref) {
  final states = ref.watch(imageProcessingStateProvider);
  final groups = ref.watch(groupsProvider);

  if (groups.isEmpty || states.isEmpty) return false;

  final allImageIds = groups.expand((g) => g.imageIds).toSet();
  return allImageIds.every((id) =>
    states[id]?.isComplete == true || states[id]?.hasError == true
  );
});

// Image adjustments
class ImageAdjustments {
  final double hue;
  final double saturation;
  final double brightness;
  final double sharpness;

  const ImageAdjustments({
    this.hue = 0.0,
    this.saturation = 0.0,
    this.brightness = 0.0,
    this.sharpness = 0.0,
  });

  ImageAdjustments copyWith({
    double? hue,
    double? saturation,
    double? brightness,
    double? sharpness,
  }) {
    return ImageAdjustments(
      hue: hue ?? this.hue,
      saturation: saturation ?? this.saturation,
      brightness: brightness ?? this.brightness,
      sharpness: sharpness ?? this.sharpness,
    );
  }

  bool get hasAdjustments => hue != 0 || saturation != 0 || brightness != 0 || sharpness != 0;
}

// Per-group adjustments state
final imageAdjustmentsProvider =
    StateNotifierProvider<ImageAdjustmentsNotifier, Map<String, ImageAdjustments>>((ref) {
  return ImageAdjustmentsNotifier();
});

class ImageAdjustmentsNotifier extends StateNotifier<Map<String, ImageAdjustments>> {
  ImageAdjustmentsNotifier() : super({});

  void setAdjustments(String groupId, ImageAdjustments adjustments) {
    state = {...state, groupId: adjustments};
  }

  void updateHue(String groupId, double value) {
    final current = state[groupId] ?? const ImageAdjustments();
    state = {...state, groupId: current.copyWith(hue: value)};
  }

  void updateSaturation(String groupId, double value) {
    final current = state[groupId] ?? const ImageAdjustments();
    state = {...state, groupId: current.copyWith(saturation: value)};
  }

  void updateBrightness(String groupId, double value) {
    final current = state[groupId] ?? const ImageAdjustments();
    state = {...state, groupId: current.copyWith(brightness: value)};
  }

  void updateSharpness(String groupId, double value) {
    final current = state[groupId] ?? const ImageAdjustments();
    state = {...state, groupId: current.copyWith(sharpness: value)};
  }

  void reset(String groupId) {
    state = {...state, groupId: const ImageAdjustments()};
  }
}

// Get adjustments for a specific group
final groupAdjustmentsProvider =
    Provider.family<ImageAdjustments, String>((ref, groupId) {
  final adjustments = ref.watch(imageAdjustmentsProvider);
  return adjustments[groupId] ?? const ImageAdjustments();
});

// Adjusted image bytes provider - computes adjusted image when needed
final adjustedImageBytesProvider =
    FutureProvider.family<Uint8List?, String>((ref, groupId) async {
  final colorizedImages = ref.watch(colorizedImagesByGroupProvider(groupId));
  final adjustments = ref.watch(groupAdjustmentsProvider(groupId));
  final backgroundMode = ref.watch(backgroundModeProvider);

  if (colorizedImages.isEmpty) return null;

  final colorizedImage = colorizedImages.first;

  // Always apply adjustments (to handle background mode changes)
  final nanoBananaService = ref.read(nanoBananaServiceProvider);
  return nanoBananaService.applyAdjustments(
    baseColorizedBytes: colorizedImage.baseColorizedBytes,
    hue: adjustments.hue,
    saturation: adjustments.saturation,
    brightness: adjustments.brightness,
    sharpness: adjustments.sharpness,
    useWhiteBackground: backgroundMode == BackgroundMode.white,
  );
});
