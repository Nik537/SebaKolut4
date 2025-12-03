import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/imported_image.dart';
import '../services/file_service.dart';

final fileServiceProvider = Provider<FileService>((ref) => FileService());

final importedImagesProvider =
    StateNotifierProvider<ImportedImagesNotifier, List<ImportedImage>>((ref) {
  return ImportedImagesNotifier(ref.watch(fileServiceProvider));
});

class ImportedImagesNotifier extends StateNotifier<List<ImportedImage>> {
  final FileService _fileService;

  ImportedImagesNotifier(this._fileService) : super([]);

  Future<void> pickAndAddImages() async {
    final images = await _fileService.pickImages();
    state = [...state, ...images];
  }

  Future<void> addDroppedFiles(List<DroppedFileItem> items) async {
    final images = await _fileService.processDroppedFiles(items);
    state = [...state, ...images];
  }

  void removeImage(String id) {
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
