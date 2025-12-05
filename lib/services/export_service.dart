import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/export_provider.dart';

class ExportService {
  static const int exportSize = 1080;
  static const int maxFileSizeBytes = 150 * 1024; // 150KB

  /// Prepare image for export as JPEG: resize to 1080x1080 and compress to stay under 150KB
  Future<Uint8List> _prepareForExport(Uint8List imageBytes) async {
    var image = img.decodeImage(imageBytes);
    if (image == null) {
      throw ExportException('Failed to decode image');
    }

    // Resize to 1080x1080 if not already that size
    if (image.width != exportSize || image.height != exportSize) {
      image = img.copyResize(
        image,
        width: exportSize,
        height: exportSize,
        interpolation: img.Interpolation.cubic,
      );
    }

    // Encode as JPEG, reducing quality until under 150KB
    int quality = 95;
    Uint8List encoded = Uint8List.fromList(img.encodeJpg(image, quality: quality));

    while (encoded.length > maxFileSizeBytes && quality > 10) {
      quality -= 5;
      encoded = Uint8List.fromList(img.encodeJpg(image, quality: quality));
    }

    return encoded;
  }

  /// Export images with both white and transparent background versions
  /// File naming: [hex]_white.jpg and [hex]_transparent.jpg
  /// Note: JPEG format used for 150KB size limit (transparency not preserved)
  Future<void> exportDualBackground({
    required List<ExportImageData> images,
  }) async {
    if (kIsWeb) {
      // Web: Download each file individually
      for (final imageData in images) {
        final hex = imageData.hexColor.replaceAll('#', '');

        // Export white background version
        final whiteConverted = await _prepareForExport(imageData.whiteBytes);
        await FileSaver.instance.saveFile(
          name: '${hex}_white.jpg',
          bytes: whiteConverted,
          ext: 'jpg',
          mimeType: MimeType.jpeg,
        );

        // Export transparent background version
        final transparentConverted = await _prepareForExport(imageData.transparentBytes);
        await FileSaver.instance.saveFile(
          name: '${hex}_transparent.jpg',
          bytes: transparentConverted,
          ext: 'jpg',
          mimeType: MimeType.jpeg,
        );
      }
    } else {
      // Desktop/Mobile: Select directory then save all
      final directory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Export Directory',
      );

      if (directory != null) {
        for (final imageData in images) {
          final hex = imageData.hexColor.replaceAll('#', '');

          // Export white background version
          final whiteConverted = await _prepareForExport(imageData.whiteBytes);
          final whiteFile = File('$directory/${hex}_white.jpg');
          await whiteFile.writeAsBytes(whiteConverted);

          // Export transparent background version
          final transparentConverted = await _prepareForExport(imageData.transparentBytes);
          final transparentFile = File('$directory/${hex}_transparent.jpg');
          await transparentFile.writeAsBytes(transparentConverted);
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
