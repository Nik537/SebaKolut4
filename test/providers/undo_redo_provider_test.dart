import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:filament_colorizer/providers/undo_redo_provider.dart';
import 'package:filament_colorizer/providers/images_provider.dart';
import 'package:filament_colorizer/providers/groups_provider.dart';
import 'package:filament_colorizer/providers/processing_provider.dart';
import 'package:filament_colorizer/models/imported_image.dart';
import 'package:filament_colorizer/models/image_group.dart';
import 'package:filament_colorizer/models/colorized_image.dart';
import 'package:filament_colorizer/services/image_cache_service.dart';

void main() {
  group('UndoRedoState', () {
    test('default state has canUndo and canRedo as false', () {
      const state = UndoRedoState();
      expect(state.canUndo, isFalse);
      expect(state.canRedo, isFalse);
    });

    test('copyWith creates new state with updated values', () {
      const state = UndoRedoState();
      final updated = state.copyWith(canUndo: true);
      expect(updated.canUndo, isTrue);
      expect(updated.canRedo, isFalse);

      final updated2 = state.copyWith(canRedo: true);
      expect(updated2.canUndo, isFalse);
      expect(updated2.canRedo, isTrue);

      final updated3 = state.copyWith(canUndo: true, canRedo: true);
      expect(updated3.canUndo, isTrue);
      expect(updated3.canRedo, isTrue);
    });

    test('equality works correctly', () {
      const state1 = UndoRedoState(canUndo: true, canRedo: false);
      const state2 = UndoRedoState(canUndo: true, canRedo: false);
      const state3 = UndoRedoState(canUndo: false, canRedo: true);

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });

    test('hashCode is consistent with equality', () {
      const state1 = UndoRedoState(canUndo: true, canRedo: false);
      const state2 = UndoRedoState(canUndo: true, canRedo: false);

      expect(state1.hashCode, equals(state2.hashCode));
    });
  });

  group('UndoRedoNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          // Override image cache service to avoid file system dependencies
          imageCacheServiceProvider.overrideWithValue(ImageCacheService()),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has canUndo and canRedo as false', () {
      final state = container.read(undoRedoProvider);
      expect(state.canUndo, isFalse);
      expect(state.canRedo, isFalse);
    });

    test('initial historyLength and futureLength are 0', () {
      final notifier = container.read(undoRedoProvider.notifier);
      expect(notifier.historyLength, equals(0));
      expect(notifier.futureLength, equals(0));
    });

    test('captureState adds to history and enables undo', () {
      final notifier = container.read(undoRedoProvider.notifier);

      notifier.captureState();

      expect(notifier.historyLength, equals(1));
      expect(container.read(undoRedoProvider).canUndo, isTrue);
      expect(container.read(undoRedoProvider).canRedo, isFalse);
    });

    test('captureState clears future stack', () {
      final notifier = container.read(undoRedoProvider.notifier);

      // Create a future stack by capturing, undoing, then capturing again
      notifier.captureState();
      notifier.undo();

      expect(notifier.futureLength, equals(1));

      // New capture should clear the future
      notifier.captureState();
      expect(notifier.futureLength, equals(0));
    });

    test('undo returns false when history is empty', () {
      final notifier = container.read(undoRedoProvider.notifier);

      final result = notifier.undo();

      expect(result, isFalse);
      expect(notifier.historyLength, equals(0));
      expect(notifier.futureLength, equals(0));
    });

    test('undo returns true and moves state to future when history exists', () {
      final notifier = container.read(undoRedoProvider.notifier);

      notifier.captureState();
      expect(notifier.historyLength, equals(1));

      final result = notifier.undo();

      expect(result, isTrue);
      expect(notifier.historyLength, equals(0));
      expect(notifier.futureLength, equals(1));
      expect(container.read(undoRedoProvider).canUndo, isFalse);
      expect(container.read(undoRedoProvider).canRedo, isTrue);
    });

    test('redo returns false when future is empty', () {
      final notifier = container.read(undoRedoProvider.notifier);

      final result = notifier.redo();

      expect(result, isFalse);
      expect(notifier.futureLength, equals(0));
    });

    test('redo returns true and moves state to history when future exists', () {
      final notifier = container.read(undoRedoProvider.notifier);

      // Create a future by capturing then undoing
      notifier.captureState();
      notifier.undo();

      expect(notifier.futureLength, equals(1));

      final result = notifier.redo();

      expect(result, isTrue);
      expect(notifier.historyLength, equals(1));
      expect(notifier.futureLength, equals(0));
      expect(container.read(undoRedoProvider).canUndo, isTrue);
      expect(container.read(undoRedoProvider).canRedo, isFalse);
    });

    test('multiple undo/redo operations work correctly', () {
      final notifier = container.read(undoRedoProvider.notifier);

      // Capture 3 states
      notifier.captureState();
      notifier.captureState();
      notifier.captureState();

      expect(notifier.historyLength, equals(3));
      expect(notifier.futureLength, equals(0));

      // Undo twice
      notifier.undo();
      notifier.undo();

      expect(notifier.historyLength, equals(1));
      expect(notifier.futureLength, equals(2));

      // Redo once
      notifier.redo();

      expect(notifier.historyLength, equals(2));
      expect(notifier.futureLength, equals(1));
    });

    test('clearHistory removes all history and future', () {
      final notifier = container.read(undoRedoProvider.notifier);

      // Build up some history and future
      notifier.captureState();
      notifier.captureState();
      notifier.captureState();
      notifier.undo();

      expect(notifier.historyLength, greaterThan(0));
      expect(notifier.futureLength, greaterThan(0));

      notifier.clearHistory();

      expect(notifier.historyLength, equals(0));
      expect(notifier.futureLength, equals(0));
      expect(container.read(undoRedoProvider).canUndo, isFalse);
      expect(container.read(undoRedoProvider).canRedo, isFalse);
    });

    test('history limit is enforced at maxHistorySize', () {
      final notifier = container.read(undoRedoProvider.notifier);

      // Capture more than maxHistorySize states
      for (int i = 0; i < maxHistorySize + 10; i++) {
        notifier.captureState();
      }

      // Should be capped at maxHistorySize
      expect(notifier.historyLength, equals(maxHistorySize));
    });

    test('history limit is enforced during redo', () {
      final notifier = container.read(undoRedoProvider.notifier);

      // Fill history to max
      for (int i = 0; i < maxHistorySize; i++) {
        notifier.captureState();
      }

      expect(notifier.historyLength, equals(maxHistorySize));

      // Undo one to create future state
      notifier.undo();
      expect(notifier.historyLength, equals(maxHistorySize - 1));
      expect(notifier.futureLength, equals(1));

      // Redo should add to history and enforce limit
      notifier.redo();
      expect(notifier.historyLength, equals(maxHistorySize));
    });
  });

  group('Derived Providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(ImageCacheService()),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('canUndoProvider reflects UndoRedoState.canUndo', () {
      expect(container.read(canUndoProvider), isFalse);

      container.read(undoRedoProvider.notifier).captureState();

      expect(container.read(canUndoProvider), isTrue);

      container.read(undoRedoProvider.notifier).undo();

      expect(container.read(canUndoProvider), isFalse);
    });

    test('canRedoProvider reflects UndoRedoState.canRedo', () {
      expect(container.read(canRedoProvider), isFalse);

      container.read(undoRedoProvider.notifier).captureState();
      expect(container.read(canRedoProvider), isFalse);

      container.read(undoRedoProvider.notifier).undo();
      expect(container.read(canRedoProvider), isTrue);

      container.read(undoRedoProvider.notifier).redo();
      expect(container.read(canRedoProvider), isFalse);
    });
  });

  group('UndoRedoNotifier state restoration', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(ImageCacheService()),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('undo restores images state', () {
      final imagesNotifier = container.read(importedImagesProvider.notifier);
      final undoNotifier = container.read(undoRedoProvider.notifier);

      // Add an image using setStateFromSnapshot (simulates state change)
      final testImage = ImportedImage(
        id: 'test-1',
        filename: 'test.png',
        importedAt: DateTime.now(),
      );

      // Capture initial empty state
      undoNotifier.captureState();

      // Change state
      imagesNotifier.setStateFromSnapshot([testImage]);

      // Verify state changed
      expect(container.read(importedImagesProvider).length, equals(1));

      // Undo should restore empty state
      undoNotifier.undo();

      expect(container.read(importedImagesProvider).length, equals(0));
    });

    test('undo restores groups state', () {
      final groupsNotifier = container.read(groupsProvider.notifier);
      final undoNotifier = container.read(undoRedoProvider.notifier);

      // Capture initial empty state
      undoNotifier.captureState();

      // Add a group
      final testGroup = ImageGroup(
        id: 'group-1',
        name: 'Test Group',
        imageIds: ['img-1'],
        createdAt: DateTime.now(),
      );
      groupsNotifier.setStateFromSnapshot([testGroup]);

      // Verify state changed
      expect(container.read(groupsProvider).length, equals(1));

      // Undo should restore empty state
      undoNotifier.undo();

      expect(container.read(groupsProvider).length, equals(0));
    });

    test('undo restores colorized images state', () {
      final colorizedNotifier = container.read(colorizedImagesProvider.notifier);
      final undoNotifier = container.read(undoRedoProvider.notifier);

      // Capture initial empty state
      undoNotifier.captureState();

      // Add a colorized image
      final testColorized = ColorizedImage(
        id: 'colorized-1',
        sourceImageId: 'img-1',
        groupId: 'group-1',
        appliedHex: '#FF0000',
        createdAt: DateTime.now(),
      );
      colorizedNotifier.setStateFromSnapshot([testColorized]);

      // Verify state changed
      expect(container.read(colorizedImagesProvider).length, equals(1));

      // Undo should restore empty state
      undoNotifier.undo();

      expect(container.read(colorizedImagesProvider).length, equals(0));
    });

    test('undo restores adjustments state', () {
      final adjustmentsNotifier = container.read(imageAdjustmentsProvider.notifier);
      final undoNotifier = container.read(undoRedoProvider.notifier);

      // Capture initial empty state
      undoNotifier.captureState();

      // Add adjustments
      adjustmentsNotifier.setStateFromSnapshot({
        'group-1': const ImageAdjustments(hue: 0.5, saturation: 0.3),
      });

      // Verify state changed
      expect(container.read(imageAdjustmentsProvider).containsKey('group-1'), isTrue);

      // Undo should restore empty state
      undoNotifier.undo();

      expect(container.read(imageAdjustmentsProvider).isEmpty, isTrue);
    });

    test('undo restores selected generations state', () {
      final generationsNotifier = container.read(allSelectedGenerationsProvider.notifier);
      final undoNotifier = container.read(undoRedoProvider.notifier);

      // Capture initial empty state
      undoNotifier.captureState();

      // Add selected generations
      generationsNotifier.setStateFromSnapshot({'group-1': 2});

      // Verify state changed
      expect(container.read(allSelectedGenerationsProvider)['group-1'], equals(2));

      // Undo should restore empty state
      undoNotifier.undo();

      expect(container.read(allSelectedGenerationsProvider).isEmpty, isTrue);
    });

    test('redo restores undone state', () {
      final imagesNotifier = container.read(importedImagesProvider.notifier);
      final undoNotifier = container.read(undoRedoProvider.notifier);

      final testImage = ImportedImage(
        id: 'test-1',
        filename: 'test.png',
        importedAt: DateTime.now(),
      );

      // Capture initial empty state
      undoNotifier.captureState();

      // Change state
      imagesNotifier.setStateFromSnapshot([testImage]);

      // Verify state changed
      expect(container.read(importedImagesProvider).length, equals(1));

      // Undo
      undoNotifier.undo();
      expect(container.read(importedImagesProvider).length, equals(0));

      // Redo should restore the added image
      undoNotifier.redo();
      expect(container.read(importedImagesProvider).length, equals(1));
      expect(container.read(importedImagesProvider).first.id, equals('test-1'));
    });
  });

  group('maxHistorySize constant', () {
    test('maxHistorySize is 50', () {
      expect(maxHistorySize, equals(50));
    });
  });
}
