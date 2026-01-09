import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import '../providers/export_provider.dart';
import 'webp_encoder_service.dart';

/// Top-level isolate function for image resize (required for compute)
Uint8List _resizeImageIsolate(Map<String, dynamic> params) {
  final imageBytes = params['imageBytes'] as Uint8List;
  final targetSize = params['targetSize'] as int;

  var image = img.decodeImage(imageBytes);
  if (image == null) {
    throw Exception('Failed to decode image');
  }

  // Resize to target size if not already that size
  if (image.width != targetSize || image.height != targetSize) {
    image = img.copyResize(
      image,
      width: targetSize,
      height: targetSize,
      interpolation: img.Interpolation.cubic,
    );
  }

  // Encode as PNG (lossless intermediate format)
  return Uint8List.fromList(img.encodePng(image));
}

class ExportService {
  static const int exportSizeSmall = 1080;  // For zoom and front (white bg)
  static const int exportSizeLarge = 2000;  // For alpha (transparent)
  static const int maxFileSizeBytes = 150 * 1024; // 150KB

  final WebpEncoderService _webpEncoder = WebpEncoderService();

  /// Prepare image for export as WebP: resize to target size and compress to stay under 150KB
  Future<Uint8List> _prepareForExport(
    Uint8List imageBytes, {
    required bool preserveTransparency,
    required int targetSize,
  }) async {
    // Run image decoding/resizing in a separate isolate to avoid blocking UI
    final pngBytes = await compute(_resizeImageIsolate, {
      'imageBytes': imageBytes,
      'targetSize': targetSize,
    });

    // Convert to WebP
    final webpBytes = await _webpEncoder.encodeToWebp(
      pngBytes: pngBytes,
      preserveTransparency: preserveTransparency,
      maxBytes: maxFileSizeBytes,
      targetSize: targetSize,
    );

    return webpBytes;
  }

  /// Pick export directory (for non-web platforms)
  /// Returns null if user cancels or on web platform
  Future<String?> pickExportDirectory() async {
    if (kIsWeb) return null;

    return await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Export Directory',
    );
  }

  /// Export images with transparent, zoom, and front background versions
  /// File naming: 3d-filament-{GroupName}-alpha-azurefilm.webp, etc.
  /// Folder structure: {GroupName} {SKU}/
  /// WebP format with lossy (zoom/front) and lossless (transparent) compression
  ///
  /// For desktop/mobile: [directory] must be provided (call pickExportDirectory first)
  /// For web: [directory] is ignored, files are downloaded individually
  Future<void> exportDualBackground({
    required List<ExportImageData> images,
    String? directory,
  }) async {
    if (kIsWeb) {
      // Web: Download each file individually (no folder structure)
      for (final imageData in images) {
        // Build base name with filament type prefix
        final filamentPart = imageData.filamentType?.replaceAll(' ', '-') ?? '';
        final groupPart = imageData.groupName.replaceAll(' ', '-');
        final baseName = filamentPart.isNotEmpty ? '$filamentPart-$groupPart' : groupPart;

        // Export transparent background version (lossless WebP with alpha, 2000x2000)
        final transparentConverted = await _prepareForExport(
          imageData.transparentBytes,
          preserveTransparency: true,
          targetSize: exportSizeLarge,
        );
        await FileSaver.instance.saveFile(
          name: '3d-filament-$baseName-alpha-azurefilm.webp',
          bytes: transparentConverted,
          ext: 'webp',
          mimeType: MimeType.other,
        );

        // Export zoom version (lossy WebP, 1080x1080)
        final zoomConverted = await _prepareForExport(
          imageData.zoomBytes,
          preserveTransparency: false,
          targetSize: exportSizeSmall,
        );
        await FileSaver.instance.saveFile(
          name: '3d-filament-$baseName-zoom-azurefilm.webp',
          bytes: zoomConverted,
          ext: 'webp',
          mimeType: MimeType.other,
        );

        // Export front version (lossy WebP, 1080x1080)
        final frontConverted = await _prepareForExport(
          imageData.frontBytes,
          preserveTransparency: false,
          targetSize: exportSizeSmall,
        );
        await FileSaver.instance.saveFile(
          name: '3d-filament-$baseName-front-azurefilm.webp',
          bytes: frontConverted,
          ext: 'webp',
          mimeType: MimeType.other,
        );
      }
    } else {
      // Desktop/Mobile: Directory must be provided
      if (directory == null) {
        throw ExportException('Export directory not specified');
      }

      for (final imageData in images) {
        // Create folder: "{FilamentType} {GroupName} {SKU}"
        final filamentPrefix = imageData.filamentType != null
            ? '${imageData.filamentType} '
            : '';
        final folderName = '$filamentPrefix${imageData.groupName} ${imageData.sku}'.trim();
        final folderPath = '$directory/$folderName';
        await Directory(folderPath).create(recursive: true);

        // Build base name with filament type prefix
        final filamentPart = imageData.filamentType?.replaceAll(' ', '-') ?? '';
        final groupPart = imageData.groupName.replaceAll(' ', '-');
        final baseName = filamentPart.isNotEmpty ? '$filamentPart-$groupPart' : groupPart;

        // Export transparent background version (lossless WebP with alpha, 2000x2000)
        final transparentConverted = await _prepareForExport(
          imageData.transparentBytes,
          preserveTransparency: true,
          targetSize: exportSizeLarge,
        );
        final transparentFile = File('$folderPath/3d-filament-$baseName-alpha-azurefilm.webp');
        await transparentFile.writeAsBytes(transparentConverted);

        // Export zoom version (lossy WebP, 1080x1080)
        final zoomConverted = await _prepareForExport(
          imageData.zoomBytes,
          preserveTransparency: false,
          targetSize: exportSizeSmall,
        );
        final zoomFile = File('$folderPath/3d-filament-$baseName-zoom-azurefilm.webp');
        await zoomFile.writeAsBytes(zoomConverted);

        // Export front version (lossy WebP, 1080x1080)
        final frontConverted = await _prepareForExport(
          imageData.frontBytes,
          preserveTransparency: false,
          targetSize: exportSizeSmall,
        );
        final frontFile = File('$folderPath/3d-filament-$baseName-front-azurefilm.webp');
        await frontFile.writeAsBytes(frontConverted);
      }
    }
  }
}

class ExportException implements Exception {
  final String message;
  ExportException(this.message);

  @override
  String toString() => 'ExportException: $message';
}
