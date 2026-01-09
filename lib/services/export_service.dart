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

  /// Export images with transparent, zoom, and front background versions
  /// File naming: 3d-filament-{GroupName}-alpha-azurefilm.webp, etc.
  /// Folder structure: {GroupName} {SKU}/
  /// WebP format with lossy (zoom/front) and lossless (transparent) compression
  ///
  /// [isCancelled] - Optional callback to check if export has been cancelled.
  /// When cancelled, partial files on desktop/mobile are cleaned up.
  Future<void> exportDualBackground({
    required List<ExportImageData> images,
    bool Function()? isCancelled,
  }) async {
    if (kIsWeb) {
      // Web: Download each file individually (no folder structure)
      // Note: Web downloads cannot be cancelled once initiated
      for (final imageData in images) {
        // Check for cancellation before processing each image
        if (isCancelled?.call() == true) {
          throw ExportCancelledException();
        }

        final baseName = imageData.groupName.replaceAll(' ', '-');

        // Export transparent background version (lossless WebP with alpha, 2000x2000)
        final transparentConverted = await _prepareForExport(
          imageData.transparentBytes,
          preserveTransparency: true,
          targetSize: exportSizeLarge,
        );

        if (isCancelled?.call() == true) {
          throw ExportCancelledException();
        }

        await FileSaver.instance.saveFile(
          name: '3d-filament-$baseName-alpha-azurefilm.webp',
          bytes: transparentConverted,
          ext: 'webp',
          mimeType: MimeType.other,
        );

        // Check for cancellation before zoom processing
        if (isCancelled?.call() == true) {
          throw ExportCancelledException();
        }

        // Export zoom version (lossy WebP, 1080x1080)
        final zoomConverted = await _prepareForExport(
          imageData.zoomBytes,
          preserveTransparency: false,
          targetSize: exportSizeSmall,
        );

        if (isCancelled?.call() == true) {
          throw ExportCancelledException();
        }

        await FileSaver.instance.saveFile(
          name: '3d-filament-$baseName-zoom-azurefilm.webp',
          bytes: zoomConverted,
          ext: 'webp',
          mimeType: MimeType.other,
        );

        // Check for cancellation before front processing
        if (isCancelled?.call() == true) {
          throw ExportCancelledException();
        }

        // Export front version (lossy WebP, 1080x1080)
        final frontConverted = await _prepareForExport(
          imageData.frontBytes,
          preserveTransparency: false,
          targetSize: exportSizeSmall,
        );

        if (isCancelled?.call() == true) {
          throw ExportCancelledException();
        }

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
        // Track created files and directories for cleanup on cancellation
        final createdFiles = <File>[];
        final createdDirectories = <Directory>[];

        try {
          for (final imageData in images) {
            // Check for cancellation before processing each image
            if (isCancelled?.call() == true) {
              throw ExportCancelledException();
            }

            // Create folder: "{GroupName} {SKU}"
            final folderName = '${imageData.groupName} ${imageData.sku}'.trim();
            final folderPath = '$directory/$folderName';
            final folder = Directory(folderPath);

            // Track if this is a new directory
            final folderExisted = await folder.exists();
            await folder.create(recursive: true);
            if (!folderExisted) {
              createdDirectories.add(folder);
            }

            // Generate base filename: replace spaces with "-"
            final baseName = imageData.groupName.replaceAll(' ', '-');

            // Export transparent background version (lossless WebP with alpha, 2000x2000)
            final transparentConverted = await _prepareForExport(
              imageData.transparentBytes,
              preserveTransparency: true,
              targetSize: exportSizeLarge,
            );

            if (isCancelled?.call() == true) {
              throw ExportCancelledException();
            }

            final transparentFile = File('$folderPath/3d-filament-$baseName-alpha-azurefilm.webp');
            await transparentFile.writeAsBytes(transparentConverted);
            createdFiles.add(transparentFile);

            // Check for cancellation before zoom processing
            if (isCancelled?.call() == true) {
              throw ExportCancelledException();
            }

            // Export zoom version (lossy WebP, 1080x1080)
            final zoomConverted = await _prepareForExport(
              imageData.zoomBytes,
              preserveTransparency: false,
              targetSize: exportSizeSmall,
            );

            if (isCancelled?.call() == true) {
              throw ExportCancelledException();
            }

            final zoomFile = File('$folderPath/3d-filament-$baseName-zoom-azurefilm.webp');
            await zoomFile.writeAsBytes(zoomConverted);
            createdFiles.add(zoomFile);

            // Check for cancellation before front processing
            if (isCancelled?.call() == true) {
              throw ExportCancelledException();
            }

            // Export front version (lossy WebP, 1080x1080)
            final frontConverted = await _prepareForExport(
              imageData.frontBytes,
              preserveTransparency: false,
              targetSize: exportSizeSmall,
            );

            if (isCancelled?.call() == true) {
              throw ExportCancelledException();
            }

            final frontFile = File('$folderPath/3d-filament-$baseName-front-azurefilm.webp');
            await frontFile.writeAsBytes(frontConverted);
            createdFiles.add(frontFile);
          }
        } on ExportCancelledException {
          // Cleanup partial files on cancellation
          await _cleanupPartialExport(createdFiles, createdDirectories);
          rethrow;
        }
      }
    }
  }

  /// Clean up partial export files and empty directories created during a cancelled export
  Future<void> _cleanupPartialExport(
    List<File> files,
    List<Directory> directories,
  ) async {
    // Delete files first
    for (final file in files) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Ignore cleanup errors - best effort cleanup
      }
    }

    // Delete empty directories (in reverse order to handle nested dirs)
    for (final directory in directories.reversed) {
      try {
        if (await directory.exists()) {
          final contents = await directory.list().toList();
          if (contents.isEmpty) {
            await directory.delete();
          }
        }
      } catch (_) {
        // Ignore cleanup errors - best effort cleanup
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
