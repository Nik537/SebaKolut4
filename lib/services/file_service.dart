import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import '../models/imported_image.dart';
import 'image_cache_service.dart';

/// Top-level isolate function for thumbnail generation (required for compute)
Uint8List _generateThumbnailIsolate(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) {
    throw Exception('Failed to decode image');
  }

  // Resize to thumbnail (200px max dimension)
  final thumbnail = img.copyResize(
    image,
    width: image.width > image.height ? 200 : null,
    height: image.height >= image.width ? 200 : null,
  );

  return Uint8List.fromList(img.encodeJpg(thumbnail, quality: 80));
}

class FileService {
  final _uuid = const Uuid();
  final ImageCacheService _imageCache;

  FileService(this._imageCache);

  Future<List<ImportedImage>> pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return [];
    }

    final images = <ImportedImage>[];
    for (final file in result.files) {
      if (file.bytes != null) {
        final image = await _createImportedImage(file.name, file.bytes!);
        if (image != null) {
          images.add(image);
        }
      }
    }

    return images;
  }

  Future<List<ImportedImage>> processDroppedFiles(List<DroppedFileItem> items) async {
    final images = <ImportedImage>[];

    for (final item in items) {
      if (item.bytes != null && _isImageFile(item.name)) {
        final image = await _createImportedImage(item.name, item.bytes!);
        if (image != null) {
          images.add(image);
        }
      }
    }

    return images;
  }

  Future<ImportedImage?> _createImportedImage(
      String filename, Uint8List bytes) async {
    try {
      final id = _uuid.v4();
      final thumbnail = await _generateThumbnail(bytes);

      // Store bytes in cache (not in the model)
      _imageCache.cacheImportedImage(id, bytes, thumbnail);

      return ImportedImage(
        id: id,
        filename: filename,
        importedAt: DateTime.now(),
      );
    } catch (e) {
      // Skip files that can't be processed
      return null;
    }
  }

  Future<Uint8List> _generateThumbnail(Uint8List bytes) async {
    // Run image decoding/resizing in a separate isolate to avoid blocking UI
    return compute(_generateThumbnailIsolate, bytes);
  }

  bool _isImageFile(String filename) {
    final ext = filename.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.webp') ||
        ext.endsWith('.gif');
  }
}

class DroppedFileItem {
  final String name;
  final Uint8List? bytes;

  DroppedFileItem({required this.name, this.bytes});
}
