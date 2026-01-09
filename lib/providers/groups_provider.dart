import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/image_group.dart';
import 'images_provider.dart';

final groupsProvider =
    StateNotifierProvider<GroupsNotifier, List<ImageGroup>>((ref) {
  return GroupsNotifier(ref);
});

class GroupsNotifier extends StateNotifier<List<ImageGroup>> {
  final Ref _ref;
  final _uuid = const Uuid();
  String? _lastCreatedGroupId;

  GroupsNotifier(this._ref) : super([]);

  /// Returns the ID of the last created group, or null if no group was created
  String? get lastCreatedGroupId => _lastCreatedGroupId;

  void createGroupFromSelection() {
    final selectedImages = _ref.read(selectedImagesProvider);
    if (selectedImages.isEmpty) return;

    final imageIds = selectedImages.map((img) => img.id).toList();

    final group = ImageGroup(
      id: _uuid.v4(),
      name: '',
      imageIds: imageIds,
      createdAt: DateTime.now(),
    );

    state = [...state, group];

    // Track last created group for undo functionality
    _lastCreatedGroupId = group.id;

    // Mark images as grouped
    _ref.read(importedImagesProvider.notifier).markAsGrouped(imageIds);
  }

  void removeGroup(String groupId) {
    state = state.where((g) => g.id != groupId).toList();
  }

  /// Undoes the last created group, returning its images to ungrouped state.
  /// Returns the list of image IDs that were ungrouped, or null if no group to undo.
  List<String>? undoLastGroup() {
    if (_lastCreatedGroupId == null) return null;

    // Find the group to undo
    final groupIndex = state.indexWhere((g) => g.id == _lastCreatedGroupId);
    if (groupIndex == -1) {
      _lastCreatedGroupId = null;
      return null;
    }

    final group = state[groupIndex];
    final imageIds = group.imageIds;

    // Remove the group from state
    state = state.where((g) => g.id != _lastCreatedGroupId).toList();

    // Mark images as ungrouped
    _ref.read(importedImagesProvider.notifier).markAsUngrouped(imageIds);

    // Clear the tracking
    _lastCreatedGroupId = null;

    return imageIds;
  }

  void renameGroup(String groupId, String newName) {
    state = state.map((g) {
      if (g.id == groupId) {
        return g.copyWith(name: newName);
      }
      return g;
    }).toList();
  }

  void updateSku(String groupId, String sku) {
    state = state.map((g) {
      if (g.id == groupId) {
        return g.copyWith(sku: sku);
      }
      return g;
    }).toList();
  }

  void reset() {
    state = [];
    _lastCreatedGroupId = null;
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
