import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';
import 'images_provider.dart';
import 'groups_provider.dart';

final geminiServiceProvider = Provider<GeminiService>((ref) => GeminiService());
final nanoBananaServiceProvider =
    Provider<NanoBananaService>((ref) => NanoBananaService());

// Template image bytes provider
final templateImageProvider = FutureProvider<Uint8List>((ref) async {
  final data = await rootBundle.load('assets/images/Neutral grey SILK.jpg');
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

  Future<void> processAllGroups() async {
    final groups = _ref.read(groupsProvider);
    final images = _ref.read(importedImagesProvider);
    final templateBytes = await _ref.read(templateImageProvider.future);
    final geminiService = _ref.read(geminiServiceProvider);
    final nanoBananaService = _ref.read(nanoBananaServiceProvider);

    // Initialize services
    geminiService.initialize();
    nanoBananaService.initialize();

    for (final group in groups) {
      await _processGroup(
        group: group,
        images: images,
        templateBytes: templateBytes,
        geminiService: geminiService,
        nanoBananaService: nanoBananaService,
      );
    }
  }

  Future<void> _processGroup({
    required ImageGroup group,
    required List<ImportedImage> images,
    required Uint8List templateBytes,
    required GeminiService geminiService,
    required NanoBananaService nanoBananaService,
  }) async {
    for (final imageId in group.imageIds) {
      final image = images.firstWhere((img) => img.id == imageId);
      await _processImage(
        image: image,
        groupId: group.id,
        templateBytes: templateBytes,
        geminiService: geminiService,
        nanoBananaService: nanoBananaService,
      );
    }
  }

  Future<void> _processImage({
    required ImportedImage image,
    required String groupId,
    required Uint8List templateBytes,
    required GeminiService geminiService,
    required NanoBananaService nanoBananaService,
  }) async {
    final processingNotifier = _ref.read(imageProcessingStateProvider.notifier);
    final colorizedNotifier = _ref.read(colorizedImagesProvider.notifier);

    try {
      // Step 1: Extract color
      processingNotifier.setStatus(image.id, ProcessingStatus.extractingColor);

      final colorResult = await geminiService.extractColor(image.bytes);

      processingNotifier.setStatus(
        image.id,
        ProcessingStatus.colorExtracted,
        extractedHex: colorResult.hexColor,
      );

      // Step 2: Colorize template
      processingNotifier.setStatus(image.id, ProcessingStatus.colorizing);

      final colorizedImage = await nanoBananaService.colorizeTemplate(
        templateImageBytes: templateBytes,
        hexColor: colorResult.hexColor,
        sourceImageId: image.id,
        groupId: groupId,
      );

      colorizedNotifier.addColorizedImage(colorizedImage);
      processingNotifier.setStatus(image.id, ProcessingStatus.completed);
    } catch (e) {
      processingNotifier.setStatus(
        image.id,
        ProcessingStatus.error,
        errorMessage: e.toString(),
      );
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
