import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/imported_image.dart';
import '../services/file_service.dart';
import '../services/image_cache_service.dart';
import 'undo_redo_provider.dart';

final fileServiceProvider = Provider<FileService>((ref) {
  final imageCache = ref.watch(imageCacheServiceProvider);
  return FileService(imageCache);
});

final importedImagesProvider =
    StateNotifierProvider<ImportedImagesNotifier, List<ImportedImage>>((ref) {
  final fileService = ref.watch(fileServiceProvider);
  final imageCache = ref.watch(imageCacheServiceProvider);
  return ImportedImagesNotifier(fileService, imageCache, ref);
});

class ImportedImagesNotifier extends StateNotifier<List<ImportedImage>> {
  final FileService _fileService;
  final ImageCacheService _imageCache;
  final Ref _ref;

  ImportedImagesNotifier(this._fileService, this._imageCache, this._ref) : super([]);

  /// Captures state before a mutation for undo/redo support.
  void _captureBeforeMutation() {
    _ref.read(undoRedoProvider.notifier).captureState();
  }

  Future<void> pickAndAddImages() async {
    final images = await _fileService.pickImages();
    state = [...state, ...images];
  }

  Future<void> addDroppedFiles(List<DroppedFileItem> items) async {
    final images = await _fileService.processDroppedFiles(items);
    state = [...state, ...images];
  }

  void removeImage(String id) {
    _captureBeforeMutation();
    // Remove from cache first
    _imageCache.removeImportedImage(id);
    state = state.where((img) => img.id != id).toList();
  }

  void toggleSelection(String id) {
    _captureBeforeMutation();
    state = state.map((img) {
      if (img.id == id && !img.isGrouped) {
        return img.copyWith(isSelected: !img.isSelected);
      }
      return img;
    }).toList();
  }

  void clearSelections() {
    _captureBeforeMutation();
    state = state.map((img) => img.copyWith(isSelected: false)).toList();
  }

  void markAsGrouped(List<String> imageIds) {
    _captureBeforeMutation();
    state = state.map((img) {
      if (imageIds.contains(img.id)) {
        return img.copyWith(isSelected: false, isGrouped: true);
      }
      return img;
    }).toList();
  }

  void selectImageAt(int index) {
    if (index < 0 || index >= state.length) return;
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index && !state[i].isGrouped)
          state[i].copyWith(isSelected: true)
        else
          state[i],
    ];
  }

  void deselectImageAt(int index) {
    if (index < 0 || index >= state.length) return;
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index)
          state[i].copyWith(isSelected: false)
        else
          state[i],
    ];
  }

  void markAsUngrouped(List<String> imageIds) {
    state = state.map((img) {
      if (imageIds.contains(img.id)) {
        return img.copyWith(isGrouped: false);
      }
      return img;
    }).toList();
  }

  /// Select a specific image by ID (used for keyboard navigation)
  void selectById(String id) {
    state = state.map((img) {
      if (img.id == id && !img.isGrouped) {
        return img.copyWith(isSelected: true);
      }
      return img;
    }).toList();
  }

  /// Deselect a specific image by ID (used for keyboard navigation)
  void deselectById(String id) {
    state = state.map((img) {
      if (img.id == id) {
        return img.copyWith(isSelected: false);
      }
      return img;
    }).toList();
  }

  void reset() {
    _captureBeforeMutation();
    // Clear all cached imported images
    _imageCache.clearImportedImages();
    state = [];
  }

  List<ImportedImage> get selectedImages =>
      state.where((img) => img.isSelected).toList();

  List<ImportedImage> get ungroupedImages =>
      state.where((img) => !img.isGrouped).toList();

  /// Restores state from a snapshot for undo/redo operations.
  void setStateFromSnapshot(List<ImportedImage> images) {
    state = images;
  }
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
