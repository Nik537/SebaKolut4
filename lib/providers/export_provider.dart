import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/export_service.dart';
import '../services/image_cache_service.dart';
import 'processing_provider.dart';
import 'groups_provider.dart';

final exportServiceProvider = Provider<ExportService>((ref) => ExportService());

// Export controller
final exportControllerProvider = Provider<ExportController>((ref) {
  return ExportController(ref);
});

class ExportController {
  final Ref _ref;

  ExportController(this._ref);

  Future<void> exportAll() async {
    final groups = _ref.read(groupsProvider);
    final exportService = _ref.read(exportServiceProvider);
    final nanoBananaService = _ref.read(nanoBananaServiceProvider);
    final colorizedNotifier = _ref.read(colorizedImagesProvider.notifier);
    final imageCache = _ref.read(imageCacheServiceProvider);

    // Prepare export data: for each group, export only the selected generation
    final exportData = <ExportImageData>[];

    for (final group in groups) {
      // Get the selected generation for this group
      final selectedGeneration = _ref.read(selectedGenerationProvider(group.id));

      // Get the colorized image for this group's selected generation
      final image = colorizedNotifier.getByGroupAndGeneration(group.id, selectedGeneration);
      if (image == null) continue;

      // Get base colorized bytes from cache
      final baseColorizedBytes = imageCache.getBaseColorizedImage(image.id);
      if (baseColorizedBytes == null) continue;

      // Use generation-specific adjustment key
      final adjustmentKey = '${group.id}:$selectedGeneration';
      final adjustments = _ref.read(groupAdjustmentsProvider(adjustmentKey));

      // Generate transparent background version
      final transparentBytes = await nanoBananaService.applyAdjustments(
        baseColorizedBytes: baseColorizedBytes,
        hue: adjustments.hue,
        saturation: adjustments.saturation,
        brightness: adjustments.brightness,
        contrast: adjustments.contrast,
        sharpness: adjustments.sharpness,
        useWhiteBackground: false,
      );

      // Generate zoom version (using zoomed SILK template + zoomed carton)
      final zoomBytes = await nanoBananaService.generateZoomImage(
        hexColor: image.appliedHex,
        hue: adjustments.hue,
        saturation: adjustments.saturation,
        brightness: adjustments.brightness,
        contrast: adjustments.contrast,
        sharpness: adjustments.sharpness,
      );

      // Generate front version (using Kolut in gorila spodaj + CartonGorilla)
      final frontBytes = await nanoBananaService.generateFrontImage(
        hexColor: image.appliedHex,
        hue: adjustments.hue,
        saturation: adjustments.saturation,
        brightness: adjustments.brightness,
        contrast: adjustments.contrast,
        sharpness: adjustments.sharpness,
      );

      exportData.add(ExportImageData(
        groupName: group.name,
        sku: group.sku,
        transparentBytes: transparentBytes,
        zoomBytes: zoomBytes,
        frontBytes: frontBytes,
      ));
    }

    await exportService.exportDualBackground(images: exportData);
  }

  /// Export a single generation from a specific group
  Future<void> exportSingleGeneration(String groupId, int generationIndex) async {
    final colorizedNotifier = _ref.read(colorizedImagesProvider.notifier);
    final colorizedImage = colorizedNotifier.getByGroupAndGeneration(groupId, generationIndex);

    if (colorizedImage == null) {
      throw Exception('No colorized image found for group $groupId, generation $generationIndex');
    }

    // Get base colorized bytes from cache
    final imageCache = _ref.read(imageCacheServiceProvider);
    final baseColorizedBytes = imageCache.getBaseColorizedImage(colorizedImage.id);
    if (baseColorizedBytes == null) {
      throw Exception('No base colorized bytes found in cache for image ${colorizedImage.id}');
    }

    // Get group info for name and SKU
    final groups = _ref.read(groupsProvider);
    final group = groups.firstWhere((g) => g.id == groupId);

    final exportService = _ref.read(exportServiceProvider);
    final nanoBananaService = _ref.read(nanoBananaServiceProvider);

    // Use generation-specific adjustment key
    final adjustmentKey = '$groupId:$generationIndex';
    final adjustments = _ref.read(groupAdjustmentsProvider(adjustmentKey));

    // Generate transparent background version
    final transparentBytes = await nanoBananaService.applyAdjustments(
      baseColorizedBytes: baseColorizedBytes,
      hue: adjustments.hue,
      saturation: adjustments.saturation,
      brightness: adjustments.brightness,
      contrast: adjustments.contrast,
      sharpness: adjustments.sharpness,
      useWhiteBackground: false,
    );

    // Generate zoom version (using zoomed SILK template + zoomed carton)
    final zoomBytes = await nanoBananaService.generateZoomImage(
      hexColor: colorizedImage.appliedHex,
      hue: adjustments.hue,
      saturation: adjustments.saturation,
      brightness: adjustments.brightness,
      contrast: adjustments.contrast,
      sharpness: adjustments.sharpness,
    );

    // Generate front version (using Kolut in gorila spodaj + CartonGorilla)
    final frontBytes = await nanoBananaService.generateFrontImage(
      hexColor: colorizedImage.appliedHex,
      hue: adjustments.hue,
      saturation: adjustments.saturation,
      brightness: adjustments.brightness,
      contrast: adjustments.contrast,
      sharpness: adjustments.sharpness,
    );

    final exportData = ExportImageData(
      groupName: group.name,
      sku: group.sku,
      transparentBytes: transparentBytes,
      zoomBytes: zoomBytes,
      frontBytes: frontBytes,
    );

    await exportService.exportDualBackground(images: [exportData]);
  }
}

/// Data class for exporting images with all background versions
class ExportImageData {
  final String groupName;
  final String sku;
  final Uint8List transparentBytes;
  final Uint8List zoomBytes;
  final Uint8List frontBytes;

  ExportImageData({
    required this.groupName,
    required this.sku,
    required this.transparentBytes,
    required this.zoomBytes,
    required this.frontBytes,
  });
}
