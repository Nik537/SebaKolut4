import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/export_provider.dart';

class ExportService {
  static const int exportSize = 1080;

  /// Prepare image for export: resize to 1080x1080 and encode as PNG
  /// (PNG preserves transparency for transparent background version)
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

    // Encode as PNG (supports transparency)
    return Uint8List.fromList(img.encodePng(image));
  }

  /// Export images with both white and transparent background versions
  /// File naming: [hex]_white.webp and [hex]_transparent.webp
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
          name: '${hex}_white.webp',
          bytes: whiteConverted,
          ext: 'webp',
          mimeType: MimeType.other,
        );

        // Export transparent background version
        final transparentConverted = await _prepareForExport(imageData.transparentBytes);
        await FileSaver.instance.saveFile(
          name: '${hex}_transparent.webp',
          bytes: transparentConverted,
          ext: 'webp',
          mimeType: MimeType.other,
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
          final whiteFile = File('$directory/${hex}_white.webp');
          await whiteFile.writeAsBytes(whiteConverted);

          // Export transparent background version
          final transparentConverted = await _prepareForExport(imageData.transparentBytes);
          final transparentFile = File('$directory/${hex}_transparent.webp');
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
