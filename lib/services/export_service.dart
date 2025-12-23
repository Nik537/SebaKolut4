import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/export_provider.dart';
import 'webp_encoder_service.dart';

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
    var image = img.decodeImage(imageBytes);
    if (image == null) {
      throw ExportException('Failed to decode image');
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

    // Encode as PNG first (lossless intermediate format)
    final pngBytes = Uint8List.fromList(img.encodePng(image));

    // Convert to WebP
    final webpBytes = await _webpEncoder.encodeToWebp(
      pngBytes: pngBytes,
      preserveTransparency: preserveTransparency,
      maxBytes: maxFileSizeBytes,
      targetSize: targetSize,
    );

    return webpBytes;
  }

  /// Export images with transparent, zoom, and front background versions
  /// File naming: 3d-filament-{GroupName}-alpha-azurefilm.webp, etc.
  /// Folder structure: {GroupName} {SKU}/
  /// WebP format with lossy (zoom/front) and lossless (transparent) compression
  Future<void> exportDualBackground({
    required List<ExportImageData> images,
  }) async {
    if (kIsWeb) {
      // Web: Download each file individually (no folder structure)
      for (final imageData in images) {
        final baseName = imageData.groupName.replaceAll(' ', '-');

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
      // Desktop/Mobile: Select directory then save all in folders
      final directory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Export Directory',
      );

      if (directory != null) {
        for (final imageData in images) {
          // Create folder: "{GroupName} {SKU}"
          final folderName = '${imageData.groupName} ${imageData.sku}'.trim();
          final folderPath = '$directory/$folderName';
          await Directory(folderPath).create(recursive: true);

          // Generate base filename: replace spaces with "-"
          final baseName = imageData.groupName.replaceAll(' ', '-');

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
}

class ExportException implements Exception {
  final String message;
  ExportException(this.message);

  @override
  String toString() => 'ExportException: $message';
}
