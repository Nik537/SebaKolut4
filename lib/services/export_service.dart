import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/colorized_image.dart';

enum ExportFormat { png, jpeg, webp }

class ExportService {
  static const int exportSize = 1080;

  Future<Uint8List> convertImage({
    required Uint8List imageBytes,
    required ExportFormat format,
    int quality = 90,
  }) async {
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

    switch (format) {
      case ExportFormat.png:
        return Uint8List.fromList(img.encodePng(image));
      case ExportFormat.jpeg:
        return Uint8List.fromList(img.encodeJpg(image, quality: quality));
      case ExportFormat.webp:
        // Note: image package doesn't support webp encoding well
        // Fall back to PNG for now
        return Uint8List.fromList(img.encodePng(image));
    }
  }

  String _getExtension(ExportFormat format) {
    switch (format) {
      case ExportFormat.png:
        return 'png';
      case ExportFormat.jpeg:
        return 'jpg';
      case ExportFormat.webp:
        return 'webp';
    }
  }

  MimeType _getMimeType(ExportFormat format) {
    switch (format) {
      case ExportFormat.png:
        return MimeType.png;
      case ExportFormat.jpeg:
        return MimeType.jpeg;
      case ExportFormat.webp:
        return MimeType.other;
    }
  }

  String generateFilename(ColorizedImage image, ExportFormat format, int index) {
    final ext = _getExtension(format);
    final hex = image.appliedHex.replaceAll('#', '');
    return 'filament_${hex}_${index.toString().padLeft(3, '0')}.$ext';
  }

  Future<void> saveFile({
    required Uint8List bytes,
    required String filename,
    required ExportFormat format,
  }) async {
    final ext = _getExtension(format);
    if (kIsWeb) {
      await FileSaver.instance.saveFile(
        name: filename,
        bytes: bytes,
        ext: ext,
        mimeType: _getMimeType(format),
      );
    } else {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Colorized Image',
        fileName: filename,
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsBytes(bytes);
      }
    }
  }

  Future<void> saveAllToDirectory({
    required List<ColorizedImage> images,
    required ExportFormat format,
    int quality = 90,
  }) async {
    final ext = _getExtension(format);

    if (kIsWeb) {
      // Web: Download each file individually
      for (int i = 0; i < images.length; i++) {
        final converted = await convertImage(
          imageBytes: images[i].bytes,
          format: format,
          quality: quality,
        );
        final filename = generateFilename(images[i], format, i);
        await FileSaver.instance.saveFile(
          name: filename,
          bytes: converted,
          ext: ext,
          mimeType: _getMimeType(format),
        );
      }
    } else {
      // Desktop/Mobile: Select directory then save all
      final directory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Export Directory',
      );

      if (directory != null) {
        for (int i = 0; i < images.length; i++) {
          final converted = await convertImage(
            imageBytes: images[i].bytes,
            format: format,
            quality: quality,
          );
          final filename = generateFilename(images[i], format, i);
          final file = File('$directory/$filename');
          await file.writeAsBytes(converted);
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
