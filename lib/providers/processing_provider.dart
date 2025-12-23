import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../services/image_cache_service.dart';
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
  final imageCache = ref.watch(imageCacheServiceProvider);
  return ColorizedImagesNotifier(imageCache);
});

class ColorizedImagesNotifier extends StateNotifier<List<ColorizedImage>> {
  final ImageCacheService _imageCache;

  ColorizedImagesNotifier(this._imageCache) : super([]);

  void addColorizedImage(ColorizedImage image) {
    state = [...state, image];
  }

  void updateForGroup(String groupId, ColorizedImage newImage, {String? oldImageId}) {
    // Remove old image from cache if provided
    if (oldImageId != null) {
      _imageCache.removeColorizedImage(oldImageId);
    }
    state = state.map((img) => img.groupId == groupId ? newImage : img).toList();
  }

  void updateForGroupAndGeneration(String groupId, int generationIndex, ColorizedImage newImage, {String? oldImageId}) {
    // Remove old image from cache if provided
    if (oldImageId != null) {
      _imageCache.removeColorizedImage(oldImageId);
    }
    state = state.map((img) {
      if (img.groupId == groupId && img.generationIndex == generationIndex) {
        return newImage;
      }
      return img;
    }).toList();
  }

  void removeGenerationsForGroup(String groupId) {
    // Remove from cache first
    final toRemove = state.where((img) => img.groupId == groupId).map((img) => img.id).toList();
    _imageCache.removeColorizedImagesForGroup(toRemove);
    state = state.where((img) => img.groupId != groupId).toList();
  }

  void reset() {
    _imageCache.clearColorizedImages();
    state = [];
  }

  List<ColorizedImage> getByGroup(String groupId) {
    return state.where((img) => img.groupId == groupId).toList();
  }

  ColorizedImage? getByGroupAndGeneration(String groupId, int generationIndex) {
    try {
      return state.firstWhere(
        (img) => img.groupId == groupId && img.generationIndex == generationIndex,
      );
    } catch (_) {
      return null;
    }
  }
}

// Get colorized images for a specific group
final colorizedImagesByGroupProvider =
    Provider.family<List<ColorizedImage>, String>((ref, groupId) {
  final colorized = ref.watch(colorizedImagesProvider);
  return colorized.where((img) => img.groupId == groupId).toList();
});

// Selected generation index per group (0, 1, or 2)
final selectedGenerationProvider =
    StateProvider.family<int, String>((ref, groupId) => 0);

// Map of all selected generations (groupId -> generationIndex)
// This avoids loop-watching in selectedColorizedImagesProvider
final allSelectedGenerationsProvider = StateNotifierProvider<AllSelectedGenerationsNotifier, Map<String, int>>((ref) {
  return AllSelectedGenerationsNotifier();
});

class AllSelectedGenerationsNotifier extends StateNotifier<Map<String, int>> {
  AllSelectedGenerationsNotifier() : super({});

  void setGeneration(String groupId, int generationIndex) {
    state = {...state, groupId: generationIndex};
  }

  int getGeneration(String groupId) => state[groupId] ?? 0;
}

// Get only the selected colorized images (one per group) for export
// Optimized to avoid loop-watching
final selectedColorizedImagesProvider = Provider<List<ColorizedImage>>((ref) {
  final groups = ref.watch(groupsProvider);
  final colorized = ref.watch(colorizedImagesProvider);
  final allSelectedGenerations = ref.watch(allSelectedGenerationsProvider);

  final selected = <ColorizedImage>[];
  for (final group in groups) {
    final selectedGeneration = allSelectedGenerations[group.id] ?? 0;
    final image = colorized.where(
      (img) => img.groupId == group.id && img.generationIndex == selectedGeneration,
    ).firstOrNull;
    if (image != null) {
      selected.add(image);
    }
  }
  return selected;
});

// Get colorized image for a specific group and generation
final colorizedImageByGenerationProvider =
    Provider.family<ColorizedImage?, ({String groupId, int generationIndex})>((ref, params) {
  final colorized = ref.watch(colorizedImagesProvider);
  try {
    return colorized.firstWhere(
      (img) => img.groupId == params.groupId && img.generationIndex == params.generationIndex,
    );
  } catch (_) {
    return null;
  }
});

// Processing controller
final processingControllerProvider = Provider<ProcessingController>((ref) {
  return ProcessingController(ref);
});

class ProcessingController {
  final Ref _ref;
  final _uuid = const Uuid();

  ProcessingController(this._ref);

  LogNotifier get _log => _ref.read(logProvider.notifier);
  ImageCacheService get _imageCache => _ref.read(imageCacheServiceProvider);

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
      // Get image bytes from cache for Gemini
      final imageBytes = <Uint8List>[];
      for (final img in groupImages) {
        final bytes = _imageCache.getFullImage(img.id);
        if (bytes != null) {
          imageBytes.add(bytes);
        }
      }

      // Extract single color from Gemini (initial processing creates 1 generation only)
      final hexColor = await geminiService.extractColorFromMultipleImages(imageBytes);

      _log.success('Color determined: $hexColor');

      // Mark all images as color extracted
      for (final image in groupImages) {
        processingNotifier.setStatus(
          image.id,
          ProcessingStatus.colorExtracted,
          extractedHex: hexColor,
        );
      }

      // Mark first image as colorizing (to show progress)
      processingNotifier.setStatus(groupImages.first.id, ProcessingStatus.colorizing);

      // Create single colorized image
      _log.info('Colorizing template with $hexColor...');

      final colorizationResult = await nanoBananaService.colorizeTemplate(
        templateImageBytes: templateBytes,
        hexColor: hexColor,
      );

      // Create colorized image metadata and store bytes in cache
      final colorizedImageId = _uuid.v4();
      _imageCache.cacheColorizedImage(
        colorizedImageId,
        colorizationResult.outputBytes,
        colorizationResult.baseColorizedBytes,
      );

      final colorizedImage = ColorizedImage(
        id: colorizedImageId,
        sourceImageId: groupImages.first.id,
        groupId: group.id,
        appliedHex: hexColor,
        createdAt: DateTime.now(),
        generationIndex: 0,
      );

      _log.success('Template colorized (${colorizationResult.outputBytes.length} bytes)');

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

  /// Extract 3 unique hex colors using Gemini AI
  Future<List<String>> _extractMultipleUniqueColors(
    GeminiService geminiService,
    List<Uint8List> imageBytes, {
    String? promptHint,
  }) async {
    final colors = <String>{};
    int attempts = 0;
    const maxAttempts = 10;

    while (colors.length < 3 && attempts < maxAttempts) {
      final hex = await geminiService.extractColorFromMultipleImages(imageBytes, promptHint: promptHint);
      colors.add(hex.toUpperCase());
      attempts++;

      if (colors.length < 3) {
        _log.info('Got color $hex, need ${3 - colors.length} more unique colors (attempt $attempts)');
      }
    }

    // If we couldn't get 3 unique colors, generate variations
    if (colors.length < 3) {
      _log.info('Could not get 3 unique colors from AI, generating variations...');
      final baseColor = colors.first;
      while (colors.length < 3) {
        final shifted = _shiftHue(baseColor, colors.length * 10);
        colors.add(shifted);
      }
    }

    return colors.toList();
  }

  /// Shift the hue of a hex color by a certain amount (in degrees, 0-360 scale)
  String _shiftHue(String hexColor, int degrees) {
    final hex = hexColor.replaceAll('#', '');
    final r = int.parse(hex.substring(0, 2), radix: 16);
    final g = int.parse(hex.substring(2, 4), radix: 16);
    final b = int.parse(hex.substring(4, 6), radix: 16);

    // Convert RGB to HSL
    final rNorm = r / 255;
    final gNorm = g / 255;
    final bNorm = b / 255;

    final max = [rNorm, gNorm, bNorm].reduce((a, b) => a > b ? a : b);
    final min = [rNorm, gNorm, bNorm].reduce((a, b) => a < b ? a : b);
    final delta = max - min;

    double h = 0;
    final l = (max + min) / 2;
    double s = 0;

    if (delta != 0) {
      s = l > 0.5 ? delta / (2 - max - min) : delta / (max + min);
      if (max == rNorm) {
        h = ((gNorm - bNorm) / delta + (gNorm < bNorm ? 6 : 0)) * 60;
      } else if (max == gNorm) {
        h = ((bNorm - rNorm) / delta + 2) * 60;
      } else {
        h = ((rNorm - gNorm) / delta + 4) * 60;
      }
    }

    // Shift hue
    h = (h + degrees) % 360;

    // Convert back to RGB
    final c = (1 - (2 * l - 1).abs()) * s;
    final x = c * (1 - ((h / 60) % 2 - 1).abs());
    final m = l - c / 2;

    double rNew, gNew, bNew;
    if (h < 60) {
      rNew = c; gNew = x; bNew = 0;
    } else if (h < 120) {
      rNew = x; gNew = c; bNew = 0;
    } else if (h < 180) {
      rNew = 0; gNew = c; bNew = x;
    } else if (h < 240) {
      rNew = 0; gNew = x; bNew = c;
    } else if (h < 300) {
      rNew = x; gNew = 0; bNew = c;
    } else {
      rNew = c; gNew = 0; bNew = x;
    }

    final newR = ((rNew + m) * 255).round().clamp(0, 255);
    final newG = ((gNew + m) * 255).round().clamp(0, 255);
    final newB = ((bNew + m) * 255).round().clamp(0, 255);

    return '#${newR.toRadixString(16).padLeft(2, '0')}${newG.toRadixString(16).padLeft(2, '0')}${newB.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
  }

  /// Re-colorize a specific generation with a new hex color (user override)
  Future<void> recolorizeGeneration(String groupId, int generationIndex, String newHexColor) async {
    final groups = _ref.read(groupsProvider);
    final group = groups.firstWhere((g) => g.id == groupId);
    final images = _ref.read(importedImagesProvider);

    final processingNotifier = _ref.read(imageProcessingStateProvider.notifier);
    final colorizedNotifier = _ref.read(colorizedImagesProvider.notifier);

    // Get all images in this group
    final groupImages = group.imageIds
        .map((id) => images.firstWhere((img) => img.id == id))
        .toList();

    _log.info('Re-colorizing generation ${generationIndex + 1} with $newHexColor...');

    try {
      final templateBytes = await _ref.read(templateImageProvider.future);
      final nanoBananaService = _ref.read(nanoBananaServiceProvider);

      // Ensure service is initialized
      await nanoBananaService.initialize();

      // Mark first image as colorizing (to show progress)
      processingNotifier.setStatus(groupImages.first.id, ProcessingStatus.colorizing, extractedHex: newHexColor);

      // Get old image ID to clean up cache
      final oldImage = colorizedNotifier.getByGroupAndGeneration(groupId, generationIndex);
      final oldImageId = oldImage?.id;

      final colorizationResult = await nanoBananaService.colorizeTemplate(
        templateImageBytes: templateBytes,
        hexColor: newHexColor,
      );

      // Create new colorized image metadata and store bytes in cache
      final colorizedImageId = _uuid.v4();
      _imageCache.cacheColorizedImage(
        colorizedImageId,
        colorizationResult.outputBytes,
        colorizationResult.baseColorizedBytes,
      );

      final colorizedImage = ColorizedImage(
        id: colorizedImageId,
        sourceImageId: groupImages.first.id,
        groupId: groupId,
        appliedHex: newHexColor,
        createdAt: DateTime.now(),
        generationIndex: generationIndex,
      );

      _log.success('Re-colorized generation ${generationIndex + 1} with $newHexColor');

      // Update the colorized image for this specific generation
      colorizedNotifier.updateForGroupAndGeneration(groupId, generationIndex, colorizedImage, oldImageId: oldImageId);

      // Mark all images in the group as completed
      for (final image in groupImages) {
        processingNotifier.setStatus(image.id, ProcessingStatus.completed, extractedHex: newHexColor);
      }

      // Reset adjustments for this generation
      final adjustmentKey = '$groupId:$generationIndex';
      _ref.read(imageAdjustmentsProvider.notifier).reset(adjustmentKey);

    } catch (e, stack) {
      final errorMsg = e.toString();
      _log.error('Failed to re-colorize generation ${generationIndex + 1}',
          details: '$errorMsg\n\nStack trace:\n$stack');

      // Revert to completed state
      for (final image in groupImages) {
        processingNotifier.setStatus(image.id, ProcessingStatus.completed);
      }
    }
  }

  /// Regenerate all 3 generations for a group by calling Gemini AI 3 times
  /// Optionally accepts a [promptHint] to provide additional context to the AI.
  Future<void> regenerateGroup(String groupId, {String? promptHint}) async {
    final groups = _ref.read(groupsProvider);
    final group = groups.firstWhere((g) => g.id == groupId);
    final images = _ref.read(importedImagesProvider);

    final processingNotifier = _ref.read(imageProcessingStateProvider.notifier);
    final colorizedNotifier = _ref.read(colorizedImagesProvider.notifier);

    // Get all images in this group
    final groupImages = group.imageIds
        .map((id) => images.firstWhere((img) => img.id == id))
        .toList();

    _log.info('Regenerating ${group.name} with 3 new AI extractions...${promptHint != null ? ' (hint: $promptHint)' : ''}');

    // Mark all images as extracting color
    for (final image in groupImages) {
      processingNotifier.setStatus(image.id, ProcessingStatus.extractingColor);
    }

    try {
      final templateBytes = await _ref.read(templateImageProvider.future);
      final geminiService = _ref.read(geminiServiceProvider);
      final nanoBananaService = _ref.read(nanoBananaServiceProvider);

      // Ensure services are initialized
      geminiService.initialize();
      await nanoBananaService.initialize();

      // Remove existing generations for this group (also cleans cache)
      colorizedNotifier.removeGenerationsForGroup(groupId);

      // Reset adjustments for all 3 generations
      for (int i = 0; i < 3; i++) {
        final adjustmentKey = '$groupId:$i';
        _ref.read(imageAdjustmentsProvider.notifier).reset(adjustmentKey);
      }

      // Get image bytes from cache for Gemini
      final imageBytes = <Uint8List>[];
      for (final img in groupImages) {
        final bytes = _imageCache.getFullImage(img.id);
        if (bytes != null) {
          imageBytes.add(bytes);
        }
      }

      final uniqueColors = await _extractMultipleUniqueColors(geminiService, imageBytes, promptHint: promptHint);

      _log.success('3 unique colors determined: ${uniqueColors.join(', ')}');

      // Mark all images as color extracted
      for (final image in groupImages) {
        processingNotifier.setStatus(
          image.id,
          ProcessingStatus.colorExtracted,
          extractedHex: uniqueColors.first,
        );
      }

      // Mark first image as colorizing
      processingNotifier.setStatus(groupImages.first.id, ProcessingStatus.colorizing);

      // Create 3 colorized images
      for (int i = 0; i < uniqueColors.length; i++) {
        final hexColor = uniqueColors[i];
        _log.info('Colorizing with $hexColor (generation ${i + 1}/3)...');

        final colorizationResult = await nanoBananaService.colorizeTemplate(
          templateImageBytes: templateBytes,
          hexColor: hexColor,
        );

        // Create colorized image metadata and store bytes in cache
        final colorizedImageId = _uuid.v4();
        _imageCache.cacheColorizedImage(
          colorizedImageId,
          colorizationResult.outputBytes,
          colorizationResult.baseColorizedBytes,
        );

        final colorizedImage = ColorizedImage(
          id: colorizedImageId,
          sourceImageId: groupImages.first.id,
          groupId: groupId,
          appliedHex: hexColor,
          createdAt: DateTime.now(),
          generationIndex: i,
        );

        _log.success('Generation ${i + 1} colorized');

        colorizedNotifier.addColorizedImage(colorizedImage);
      }

      // Mark all images as completed
      for (final image in groupImages) {
        processingNotifier.setStatus(image.id, ProcessingStatus.completed, extractedHex: uniqueColors.first);
      }

      _log.success('Group ${group.name} regenerated with 3 new generations!');
    } catch (e, stack) {
      final errorMsg = e.toString();
      _log.error('Failed to regenerate group ${group.name}',
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
  final double contrast;
  final double sharpness;

  const ImageAdjustments({
    this.hue = 0.0,
    this.saturation = 0.0,
    this.brightness = 0.0,
    this.contrast = 0.0,
    this.sharpness = 0.0,
  });

  ImageAdjustments copyWith({
    double? hue,
    double? saturation,
    double? brightness,
    double? contrast,
    double? sharpness,
  }) {
    return ImageAdjustments(
      hue: hue ?? this.hue,
      saturation: saturation ?? this.saturation,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      sharpness: sharpness ?? this.sharpness,
    );
  }

  bool get hasAdjustments => hue != 0 || saturation != 0 || brightness != 0 || contrast != 0 || sharpness != 0;
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

  void updateContrast(String groupId, double value) {
    final current = state[groupId] ?? const ImageAdjustments();
    state = {...state, groupId: current.copyWith(contrast: value)};
  }

  void updateSharpness(String groupId, double value) {
    final current = state[groupId] ?? const ImageAdjustments();
    state = {...state, groupId: current.copyWith(sharpness: value)};
  }

  void reset(String groupId) {
    state = {...state, groupId: const ImageAdjustments()};
  }
}

// Get adjustments for a specific key (groupId or groupId:generationIndex)
final groupAdjustmentsProvider =
    Provider.family<ImageAdjustments, String>((ref, key) {
  final adjustments = ref.watch(imageAdjustmentsProvider);
  return adjustments[key] ?? const ImageAdjustments();
});

// Get adjustments for a specific group and generation
final generationAdjustmentsProvider =
    Provider.family<ImageAdjustments, ({String groupId, int generationIndex})>((ref, params) {
  final key = '${params.groupId}:${params.generationIndex}';
  final adjustments = ref.watch(imageAdjustmentsProvider);
  return adjustments[key] ?? const ImageAdjustments();
});

// Adjusted image bytes provider - computes adjusted image when needed
// Always uses white background for preview (both versions exported separately)
// DEPRECATED: Use adjustedImageByGenerationProvider instead
final adjustedImageBytesProvider =
    FutureProvider.family<Uint8List?, String>((ref, groupId) async {
  final colorizedImages = ref.watch(colorizedImagesByGroupProvider(groupId));
  final adjustments = ref.watch(groupAdjustmentsProvider(groupId));
  final imageCache = ref.read(imageCacheServiceProvider);

  if (colorizedImages.isEmpty) return null;

  final colorizedImage = colorizedImages.first;
  final baseColorizedBytes = imageCache.getBaseColorizedImage(colorizedImage.id);

  if (baseColorizedBytes == null) return null;

  final nanoBananaService = ref.read(nanoBananaServiceProvider);
  return nanoBananaService.applyAdjustments(
    baseColorizedBytes: baseColorizedBytes,
    hue: adjustments.hue,
    saturation: adjustments.saturation,
    brightness: adjustments.brightness,
    contrast: adjustments.contrast,
    sharpness: adjustments.sharpness,
    useWhiteBackground: true,
  );
});

// Adjusted image bytes provider for a specific generation
final adjustedImageByGenerationProvider =
    FutureProvider.family<Uint8List?, ({String groupId, int generationIndex})>((ref, params) async {
  final colorizedImage = ref.watch(colorizedImageByGenerationProvider(params));
  final adjustments = ref.watch(generationAdjustmentsProvider(params));
  final imageCache = ref.read(imageCacheServiceProvider);

  if (colorizedImage == null) return null;

  final baseColorizedBytes = imageCache.getBaseColorizedImage(colorizedImage.id);
  if (baseColorizedBytes == null) return null;

  final nanoBananaService = ref.read(nanoBananaServiceProvider);
  return nanoBananaService.applyAdjustments(
    baseColorizedBytes: baseColorizedBytes,
    hue: adjustments.hue,
    saturation: adjustments.saturation,
    brightness: adjustments.brightness,
    contrast: adjustments.contrast,
    sharpness: adjustments.sharpness,
    useWhiteBackground: true,
  );
});

// Provider for base colorized bytes (no adjustments applied) for GPU-based preview
final baseColorizedBytesProvider =
    Provider.family<Uint8List?, ({String groupId, int generationIndex})>((ref, params) {
  final colorizedImage = ref.watch(colorizedImageByGenerationProvider(params));
  if (colorizedImage == null) return null;
  final imageCache = ref.read(imageCacheServiceProvider);
  return imageCache.getBaseColorizedImage(colorizedImage.id);
});

// Provider for carton overlay bytes (for GPU-based preview)
final cartonOverlayBytesProvider = Provider<Uint8List?>((ref) {
  final nanoBananaService = ref.watch(nanoBananaServiceProvider);
  return nanoBananaService.cartonImageBytes;
});
