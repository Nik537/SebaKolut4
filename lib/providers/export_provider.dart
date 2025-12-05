import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/export_service.dart';
import 'processing_provider.dart';

final exportServiceProvider = Provider<ExportService>((ref) => ExportService());

// Export controller
final exportControllerProvider = Provider<ExportController>((ref) {
  return ExportController(ref);
});

class ExportController {
  final Ref _ref;

  ExportController(this._ref);

  Future<void> exportAll() async {
    final colorizedImages = _ref.read(colorizedImagesProvider);
    final exportService = _ref.read(exportServiceProvider);
    final nanoBananaService = _ref.read(nanoBananaServiceProvider);

    // Prepare export data: for each image, generate both white and transparent versions
    final exportData = <ExportImageData>[];

    for (final image in colorizedImages) {
      final adjustments = _ref.read(groupAdjustmentsProvider(image.groupId));

      // Generate white background version
      final whiteBytes = await nanoBananaService.applyAdjustments(
        baseColorizedBytes: image.baseColorizedBytes,
        hue: adjustments.hue,
        saturation: adjustments.saturation,
        brightness: adjustments.brightness,
        sharpness: adjustments.sharpness,
        useWhiteBackground: true,
      );

      // Generate transparent background version
      final transparentBytes = await nanoBananaService.applyAdjustments(
        baseColorizedBytes: image.baseColorizedBytes,
        hue: adjustments.hue,
        saturation: adjustments.saturation,
        brightness: adjustments.brightness,
        sharpness: adjustments.sharpness,
        useWhiteBackground: false,
      );

      exportData.add(ExportImageData(
        hexColor: image.appliedHex,
        whiteBytes: whiteBytes,
        transparentBytes: transparentBytes,
      ));
    }

    await exportService.exportDualBackground(images: exportData);
  }
}

/// Data class for exporting images with both background versions
class ExportImageData {
  final String hexColor;
  final Uint8List whiteBytes;
  final Uint8List transparentBytes;

  ExportImageData({
    required this.hexColor,
    required this.whiteBytes,
    required this.transparentBytes,
  });
}
