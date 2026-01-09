import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_state_snapshot.dart';
import 'images_provider.dart';
import 'groups_provider.dart';
import 'processing_provider.dart';

/// Maximum number of states to keep in the undo history.
const int maxHistorySize = 50;

/// State class for the UndoRedoNotifier.
/// Contains boolean flags indicating whether undo/redo operations are available.
class UndoRedoState {
  final bool canUndo;
  final bool canRedo;

  const UndoRedoState({
    this.canUndo = false,
    this.canRedo = false,
  });

  UndoRedoState copyWith({
    bool? canUndo,
    bool? canRedo,
  }) {
    return UndoRedoState(
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UndoRedoState &&
        other.canUndo == canUndo &&
        other.canRedo == canRedo;
  }

  @override
  int get hashCode => Object.hash(canUndo, canRedo);
}

/// Provider for the UndoRedoNotifier.
final undoRedoProvider =
    StateNotifierProvider<UndoRedoNotifier, UndoRedoState>((ref) {
  return UndoRedoNotifier(ref);
});

/// StateNotifier that manages undo/redo history stacks.
///
/// This notifier captures snapshots of the application state before mutations
/// and allows users to restore previous states via undo/redo operations.
///
/// The history is limited to [maxHistorySize] states to prevent memory issues.
class UndoRedoNotifier extends StateNotifier<UndoRedoState> {
  final Ref _ref;
  final List<AppStateSnapshot> _history = [];
  final List<AppStateSnapshot> _future = [];

  UndoRedoNotifier(this._ref) : super(const UndoRedoState());

  /// Captures the current application state before a mutation.
  ///
  /// Call this method BEFORE making any state changes to ensure
  /// the previous state is saved for potential undo operations.
  void captureState() {
    final snapshot = _createSnapshot();
    _history.add(snapshot);

    // Enforce history size limit
    if (_history.length > maxHistorySize) {
      _history.removeAt(0);
    }

    // Clear future stack when new state is captured
    _future.clear();

    _updateState();
  }

  /// Undoes the last operation by restoring the previous state.
  ///
  /// Returns `true` if undo was performed, `false` if history is empty.
  bool undo() {
    if (_history.isEmpty) return false;

    // Capture current state for redo
    final currentSnapshot = _createSnapshot();
    _future.add(currentSnapshot);

    // Restore previous state
    final previousSnapshot = _history.removeLast();
    _restoreSnapshot(previousSnapshot);

    _updateState();
    return true;
  }

  /// Redoes the last undone operation by restoring the future state.
  ///
  /// Returns `true` if redo was performed, `false` if future stack is empty.
  bool redo() {
    if (_future.isEmpty) return false;

    // Capture current state for undo
    final currentSnapshot = _createSnapshot();
    _history.add(currentSnapshot);

    // Enforce history size limit
    if (_history.length > maxHistorySize) {
      _history.removeAt(0);
    }

    // Restore future state
    final futureSnapshot = _future.removeLast();
    _restoreSnapshot(futureSnapshot);

    _updateState();
    return true;
  }

  /// Clears all undo/redo history.
  void clearHistory() {
    _history.clear();
    _future.clear();
    _updateState();
  }

  /// Creates a snapshot of the current application state.
  AppStateSnapshot _createSnapshot() {
    final images = _ref.read(importedImagesProvider);
    final groups = _ref.read(groupsProvider);
    final colorizedImages = _ref.read(colorizedImagesProvider);
    final adjustments = _ref.read(imageAdjustmentsProvider);
    final selectedGenerations = _ref.read(allSelectedGenerationsProvider);

    // Create deep copies to avoid reference issues
    return AppStateSnapshot(
      images: List.unmodifiable(images.map((img) => img.copyWith()).toList()),
      groups: List.unmodifiable(groups.map((g) => g.copyWith()).toList()),
      colorizedImages: List.unmodifiable(
          colorizedImages.map((c) => c.copyWith()).toList()),
      adjustments: Map.unmodifiable(Map.fromEntries(
        adjustments.entries.map((e) => MapEntry(e.key, e.value.copyWith())),
      )),
      selectedGenerations: Map.unmodifiable(Map<String, int>.from(selectedGenerations)),
    );
  }

  /// Restores the application state from a snapshot.
  ///
  /// This method directly updates the state of all provider notifiers
  /// to match the snapshot values.
  void _restoreSnapshot(AppStateSnapshot snapshot) {
    // Restore images state
    final imagesNotifier = _ref.read(importedImagesProvider.notifier);
    _restoreImagesState(imagesNotifier, snapshot.images);

    // Restore groups state
    final groupsNotifier = _ref.read(groupsProvider.notifier);
    _restoreGroupsState(groupsNotifier, snapshot.groups);

    // Restore colorized images state
    final colorizedNotifier = _ref.read(colorizedImagesProvider.notifier);
    _restoreColorizedImagesState(colorizedNotifier, snapshot.colorizedImages);

    // Restore adjustments state
    final adjustmentsNotifier = _ref.read(imageAdjustmentsProvider.notifier);
    _restoreAdjustmentsState(adjustmentsNotifier, snapshot.adjustments);

    // Restore selected generations state
    final generationsNotifier = _ref.read(allSelectedGenerationsProvider.notifier);
    _restoreSelectedGenerationsState(generationsNotifier, snapshot.selectedGenerations);
  }

  /// Restores images state by clearing and repopulating.
  void _restoreImagesState(
    ImportedImagesNotifier notifier,
    List<dynamic> images,
  ) {
    // Use internal state setter - will be implemented in provider integration phase
    notifier.setStateFromSnapshot(images.cast());
  }

  /// Restores groups state by clearing and repopulating.
  void _restoreGroupsState(
    GroupsNotifier notifier,
    List<dynamic> groups,
  ) {
    // Use internal state setter - will be implemented in provider integration phase
    notifier.setStateFromSnapshot(groups.cast());
  }

  /// Restores colorized images state.
  void _restoreColorizedImagesState(
    ColorizedImagesNotifier notifier,
    List<dynamic> colorizedImages,
  ) {
    // Use internal state setter - will be implemented in provider integration phase
    notifier.setStateFromSnapshot(colorizedImages.cast());
  }

  /// Restores adjustments state.
  void _restoreAdjustmentsState(
    ImageAdjustmentsNotifier notifier,
    Map<String, ImageAdjustments> adjustments,
  ) {
    // Use internal state setter - will be implemented in provider integration phase
    notifier.setStateFromSnapshot(adjustments);
  }

  /// Restores selected generations state.
  void _restoreSelectedGenerationsState(
    AllSelectedGenerationsNotifier notifier,
    Map<String, int> selectedGenerations,
  ) {
    // Use internal state setter - will be implemented in provider integration phase
    notifier.setStateFromSnapshot(selectedGenerations);
  }

  /// Updates the notifier state based on history/future stack status.
  void _updateState() {
    state = UndoRedoState(
      canUndo: _history.isNotEmpty,
      canRedo: _future.isNotEmpty,
    );
  }

  /// Returns the number of states in the history stack (for testing).
  int get historyLength => _history.length;

  /// Returns the number of states in the future stack (for testing).
  int get futureLength => _future.length;
}

/// Derived provider for checking if undo is available.
final canUndoProvider = Provider<bool>((ref) {
  return ref.watch(undoRedoProvider).canUndo;
});

/// Derived provider for checking if redo is available.
final canRedoProvider = Provider<bool>((ref) {
  return ref.watch(undoRedoProvider).canRedo;
});
