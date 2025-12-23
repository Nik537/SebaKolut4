import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for storing large binary image data separately from Riverpod state.
/// This prevents expensive state copies when provider state changes.
class ImageCacheService {
  // Imported image data
  final Map<String, Uint8List> _fullImages = {};
  final Map<String, Uint8List> _thumbnails = {};

  // Colorized image data
  final Map<String, Uint8List> _colorizedImages = {};
  final Map<String, Uint8List> _baseColorizedImages = {};

  // ============================================================================
  // Imported Image Methods
  // ============================================================================

  void cacheImportedImage(String id, Uint8List bytes, Uint8List thumbnailBytes) {
    _fullImages[id] = bytes;
    _thumbnails[id] = thumbnailBytes;
  }

  Uint8List? getFullImage(String id) => _fullImages[id];

  Uint8List? getThumbnail(String id) => _thumbnails[id];

  void removeImportedImage(String id) {
    _fullImages.remove(id);
    _thumbnails.remove(id);
  }

  // ============================================================================
  // Colorized Image Methods
  // ============================================================================

  void cacheColorizedImage(String id, Uint8List bytes, Uint8List baseColorizedBytes) {
    _colorizedImages[id] = bytes;
    _baseColorizedImages[id] = baseColorizedBytes;
  }

  Uint8List? getColorizedImage(String id) => _colorizedImages[id];

  Uint8List? getBaseColorizedImage(String id) => _baseColorizedImages[id];

  void removeColorizedImage(String id) {
    _colorizedImages.remove(id);
    _baseColorizedImages.remove(id);
  }

  /// Remove all colorized images for a specific group
  void removeColorizedImagesForGroup(List<String> imageIds) {
    for (final id in imageIds) {
      removeColorizedImage(id);
    }
  }

  // ============================================================================
  // Utility Methods
  // ============================================================================

  void clearAll() {
    _fullImages.clear();
    _thumbnails.clear();
    _colorizedImages.clear();
    _baseColorizedImages.clear();
  }

  void clearImportedImages() {
    _fullImages.clear();
    _thumbnails.clear();
  }

  void clearColorizedImages() {
    _colorizedImages.clear();
    _baseColorizedImages.clear();
  }

  /// Get memory usage stats (for debugging)
  Map<String, int> getMemoryStats() {
    int importedSize = 0;
    int thumbnailSize = 0;
    int colorizedSize = 0;
    int baseColorizedSize = 0;

    for (final bytes in _fullImages.values) {
      importedSize += bytes.length;
    }
    for (final bytes in _thumbnails.values) {
      thumbnailSize += bytes.length;
    }
    for (final bytes in _colorizedImages.values) {
      colorizedSize += bytes.length;
    }
    for (final bytes in _baseColorizedImages.values) {
      baseColorizedSize += bytes.length;
    }

    return {
      'importedImages': _fullImages.length,
      'importedBytes': importedSize,
      'thumbnails': _thumbnails.length,
      'thumbnailBytes': thumbnailSize,
      'colorizedImages': _colorizedImages.length,
      'colorizedBytes': colorizedSize,
      'baseColorizedImages': _baseColorizedImages.length,
      'baseColorizedBytes': baseColorizedSize,
      'totalBytes': importedSize + thumbnailSize + colorizedSize + baseColorizedSize,
    };
  }
}

/// Global provider for the image cache service
final imageCacheServiceProvider = Provider<ImageCacheService>((ref) {
  return ImageCacheService();
});
