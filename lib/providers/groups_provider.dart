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

  GroupsNotifier(this._ref) : super([]);

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

    // Mark images as grouped
    _ref.read(importedImagesProvider.notifier).markAsGrouped(imageIds);
  }

  void removeGroup(String groupId) {
    state = state.where((g) => g.id != groupId).toList();
  }

  void undoLastGroup() {
    if (state.isEmpty) return;

    final lastGroup = state.last;
    final imageIds = lastGroup.imageIds;

    // Remove the last group
    state = state.sublist(0, state.length - 1);

    // Return images to ungrouped state
    _ref.read(importedImagesProvider.notifier).unmarkAsGrouped(imageIds);
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

  void updateFilamentType(String groupId, String? filamentType) {
    state = state.map((g) {
      if (g.id == groupId) {
        return g.copyWith(filamentType: filamentType);
      }
      return g;
    }).toList();
  }

  void reset() {
    state = [];
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

/// Provider to check if all groups are ready for processing
final allGroupsReadyProvider = Provider<bool>((ref) {
  final groups = ref.watch(groupsProvider);
  if (groups.isEmpty) return false;
  return groups.every((g) => g.isReadyForProcessing);
});
