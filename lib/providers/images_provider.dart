import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/imported_image.dart';
import '../services/file_service.dart';
import '../services/image_cache_service.dart';

final fileServiceProvider = Provider<FileService>((ref) {
  final imageCache = ref.watch(imageCacheServiceProvider);
  return FileService(imageCache);
});

final importedImagesProvider =
    StateNotifierProvider<ImportedImagesNotifier, List<ImportedImage>>((ref) {
  final fileService = ref.watch(fileServiceProvider);
  final imageCache = ref.watch(imageCacheServiceProvider);
  return ImportedImagesNotifier(fileService, imageCache);
});

class ImportedImagesNotifier extends StateNotifier<List<ImportedImage>> {
  final FileService _fileService;
  final ImageCacheService _imageCache;

  ImportedImagesNotifier(this._fileService, this._imageCache) : super([]);

  Future<void> pickAndAddImages() async {
    final images = await _fileService.pickImages();
    state = [...state, ...images];
  }

  Future<void> addDroppedFiles(List<DroppedFileItem> items) async {
    final images = await _fileService.processDroppedFiles(items);
    state = [...state, ...images];
  }

  void removeImage(String id) {
    // Remove from cache first
    _imageCache.removeImportedImage(id);
    state = state.where((img) => img.id != id).toList();
  }

  void toggleSelection(String id) {
    state = state.map((img) {
      if (img.id == id && !img.isGrouped) {
        return img.copyWith(isSelected: !img.isSelected);
      }
      return img;
    }).toList();
  }

  void clearSelections() {
    state = state.map((img) => img.copyWith(isSelected: false)).toList();
  }

  void markAsGrouped(List<String> imageIds) {
    state = state.map((img) {
      if (imageIds.contains(img.id)) {
        return img.copyWith(isSelected: false, isGrouped: true);
      }
      return img;
    }).toList();
  }

  void reset() {
    // Clear all cached imported images
    _imageCache.clearImportedImages();
    state = [];
  }

  List<ImportedImage> get selectedImages =>
      state.where((img) => img.isSelected).toList();

  List<ImportedImage> get ungroupedImages =>
      state.where((img) => !img.isGrouped).toList();
}

// Derived provider for selected images
final selectedImagesProvider = Provider<List<ImportedImage>>((ref) {
  final images = ref.watch(importedImagesProvider);
  return images.where((img) => img.isSelected).toList();
});

// Derived provider for ungrouped images
final ungroupedImagesProvider = Provider<List<ImportedImage>>((ref) {
  final images = ref.watch(importedImagesProvider);
  return images.where((img) => !img.isGrouped).toList();
});
