import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/image_group.dart';
import 'images_provider.dart';
import 'undo_redo_provider.dart';

final groupsProvider =
    StateNotifierProvider<GroupsNotifier, List<ImageGroup>>((ref) {
  return GroupsNotifier(ref);
});

class GroupsNotifier extends StateNotifier<List<ImageGroup>> {
  final Ref _ref;
  final _uuid = const Uuid();

  GroupsNotifier(this._ref) : super([]);

  /// Captures state before a mutation for undo/redo support.
  void _captureBeforeMutation() {
    _ref.read(undoRedoProvider.notifier).captureState();
  }

  void createGroupFromSelection() {
    final selectedImages = _ref.read(selectedImagesProvider);
    if (selectedImages.isEmpty) return;

    _captureBeforeMutation();

    final imageIds = selectedImages.map((img) => img.id).toList();

    final group = ImageGroup(
      id: _uuid.v4(),
      name: '',
      imageIds: imageIds,
      createdAt: DateTime.now(),
    );

    state = [...state, group];

    // Mark images as grouped
    _ref.read(importedImagesProvider.notifier).markAsGrouped(imageIds);
  }

  void removeGroup(String groupId) {
    _captureBeforeMutation();
    state = state.where((g) => g.id != groupId).toList();
  }

  void renameGroup(String groupId, String newName) {
    _captureBeforeMutation();
    state = state.map((g) {
      if (g.id == groupId) {
        return g.copyWith(name: newName);
      }
      return g;
    }).toList();
  }

  void updateSku(String groupId, String sku) {
    _captureBeforeMutation();
    state = state.map((g) {
      if (g.id == groupId) {
        return g.copyWith(sku: sku);
      }
      return g;
    }).toList();
  }

  void reset() {
    _captureBeforeMutation();
    state = [];
  }

  /// Restores state from a snapshot for undo/redo operations.
  void setStateFromSnapshot(List<ImageGroup> groups) {
    state = groups;
  }
}

// Provider to get image objects for a specific group
final groupImagesProvider =
    Provider.family<List<String>, String>((ref, groupId) {
  final groups = ref.watch(groupsProvider);
  final group = groups.firstWhere(
    (g) => g.id == groupId,
    orElse: () => ImageGroup(
      id: '',
      name: '',
      imageIds: [],
      createdAt: DateTime.now(),
    ),
  );
  return group.imageIds;
});
