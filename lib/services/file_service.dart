import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import '../models/imported_image.dart';

class FileService {
  final _uuid = const Uuid();

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
      final thumbnail = await _generateThumbnail(bytes);

      return ImportedImage(
        id: _uuid.v4(),
        filename: filename,
        bytes: bytes,
        thumbnailBytes: thumbnail,
        importedAt: DateTime.now(),
      );
    } catch (e) {
      // Skip files that can't be processed
      return null;
    }
  }

  Future<Uint8List> _generateThumbnail(Uint8List bytes) async {
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
