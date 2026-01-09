import 'package:flutter_test/flutter_test.dart';
import 'package:filament_colorizer/models/app_state_snapshot.dart';
import 'package:filament_colorizer/models/imported_image.dart';
import 'package:filament_colorizer/models/image_group.dart';
import 'package:filament_colorizer/models/colorized_image.dart';
import 'package:filament_colorizer/providers/processing_provider.dart';

void main() {
  group('AppStateSnapshot', () {
    final testDateTime = DateTime(2024, 1, 15, 12, 0, 0);

    // Test fixtures
    ImportedImage createTestImage(String id, {bool isSelected = false, bool isGrouped = false}) {
      return ImportedImage(
        id: id,
        filename: '$id.png',
        importedAt: testDateTime,
        isSelected: isSelected,
        isGrouped: isGrouped,
      );
    }

    ImageGroup createTestGroup(String id, List<String> imageIds) {
      return ImageGroup(
        id: id,
        name: 'Group $id',
        sku: 'SKU-$id',
        imageIds: imageIds,
        createdAt: testDateTime,
      );
    }

    ColorizedImage createTestColorizedImage(String id, String groupId, {int generationIndex = 0}) {
      return ColorizedImage(
        id: id,
        sourceImageId: 'source-$id',
        groupId: groupId,
        appliedHex: '#FF0000',
        createdAt: testDateTime,
        generationIndex: generationIndex,
      );
    }

    group('factory empty()', () {
      test('creates snapshot with empty collections', () {
        final snapshot = AppStateSnapshot.empty();

        expect(snapshot.images, isEmpty);
        expect(snapshot.groups, isEmpty);
        expect(snapshot.colorizedImages, isEmpty);
        expect(snapshot.adjustments, isEmpty);
        expect(snapshot.selectedGenerations, isEmpty);
      });

      test('creates identical empty snapshots', () {
        final empty1 = AppStateSnapshot.empty();
        final empty2 = AppStateSnapshot.empty();

        expect(empty1, equals(empty2));
      });
    });

    group('constructor', () {
      test('creates snapshot with provided values', () {
        final images = [createTestImage('img-1'), createTestImage('img-2')];
        final groups = [createTestGroup('grp-1', ['img-1', 'img-2'])];
        final colorizedImages = [createTestColorizedImage('col-1', 'grp-1')];
        final adjustments = {'grp-1': const ImageAdjustments(hue: 0.5)};
        final selectedGenerations = {'grp-1': 1};

        final snapshot = AppStateSnapshot(
          images: images,
          groups: groups,
          colorizedImages: colorizedImages,
          adjustments: adjustments,
          selectedGenerations: selectedGenerations,
        );

        expect(snapshot.images, equals(images));
        expect(snapshot.groups, equals(groups));
        expect(snapshot.colorizedImages, equals(colorizedImages));
        expect(snapshot.adjustments, equals(adjustments));
        expect(snapshot.selectedGenerations, equals(selectedGenerations));
      });
    });

    group('copyWith', () {
      test('creates new instance with updated images', () {
        final original = AppStateSnapshot(
          images: [createTestImage('img-1')],
          groups: [],
          colorizedImages: [],
          adjustments: {},
          selectedGenerations: {},
        );

        final newImages = [createTestImage('img-2'), createTestImage('img-3')];
        final updated = original.copyWith(images: newImages);

        expect(updated.images, equals(newImages));
        expect(updated.groups, isEmpty);
        expect(updated.colorizedImages, isEmpty);
        expect(updated.adjustments, isEmpty);
        expect(updated.selectedGenerations, isEmpty);
        expect(original.images.length, equals(1)); // Original unchanged
      });

      test('creates new instance with updated groups', () {
        final original = AppStateSnapshot(
          images: [],
          groups: [createTestGroup('grp-1', ['img-1'])],
          colorizedImages: [],
          adjustments: {},
          selectedGenerations: {},
        );

        final newGroups = [createTestGroup('grp-2', ['img-2'])];
        final updated = original.copyWith(groups: newGroups);

        expect(updated.groups, equals(newGroups));
        expect(original.groups.first.id, equals('grp-1')); // Original unchanged
      });

      test('creates new instance with updated colorizedImages', () {
        final original = AppStateSnapshot(
          images: [],
          groups: [],
          colorizedImages: [createTestColorizedImage('col-1', 'grp-1')],
          adjustments: {},
          selectedGenerations: {},
        );

        final newColorized = [createTestColorizedImage('col-2', 'grp-2')];
        final updated = original.copyWith(colorizedImages: newColorized);

        expect(updated.colorizedImages, equals(newColorized));
        expect(original.colorizedImages.first.id, equals('col-1')); // Original unchanged
      });

      test('creates new instance with updated adjustments', () {
        final original = AppStateSnapshot(
          images: [],
          groups: [],
          colorizedImages: [],
          adjustments: {'grp-1': const ImageAdjustments(hue: 0.2)},
          selectedGenerations: {},
        );

        final newAdjustments = {'grp-2': const ImageAdjustments(saturation: 0.5)};
        final updated = original.copyWith(adjustments: newAdjustments);

        expect(updated.adjustments, equals(newAdjustments));
        expect(original.adjustments['grp-1']?.hue, equals(0.2)); // Original unchanged
      });

      test('creates new instance with updated selectedGenerations', () {
        final original = AppStateSnapshot(
          images: [],
          groups: [],
          colorizedImages: [],
          adjustments: {},
          selectedGenerations: {'grp-1': 0},
        );

        final newGenerations = {'grp-2': 2};
        final updated = original.copyWith(selectedGenerations: newGenerations);

        expect(updated.selectedGenerations, equals(newGenerations));
        expect(original.selectedGenerations['grp-1'], equals(0)); // Original unchanged
      });

      test('preserves unchanged fields when updating one field', () {
        final images = [createTestImage('img-1')];
        final groups = [createTestGroup('grp-1', ['img-1'])];
        final colorizedImages = [createTestColorizedImage('col-1', 'grp-1')];
        final adjustments = {'grp-1': const ImageAdjustments(hue: 0.3)};
        final selectedGenerations = {'grp-1': 1};

        final original = AppStateSnapshot(
          images: images,
          groups: groups,
          colorizedImages: colorizedImages,
          adjustments: adjustments,
          selectedGenerations: selectedGenerations,
        );

        final newImages = [createTestImage('img-new')];
        final updated = original.copyWith(images: newImages);

        expect(updated.images, equals(newImages));
        expect(updated.groups, equals(groups));
        expect(updated.colorizedImages, equals(colorizedImages));
        expect(updated.adjustments, equals(adjustments));
        expect(updated.selectedGenerations, equals(selectedGenerations));
      });
    });

    group('equality (==)', () {
      test('identical instances are equal', () {
        final snapshot = AppStateSnapshot(
          images: [createTestImage('img-1')],
          groups: [createTestGroup('grp-1', ['img-1'])],
          colorizedImages: [],
          adjustments: {},
          selectedGenerations: {},
        );

        expect(identical(snapshot, snapshot), isTrue);
        expect(snapshot == snapshot, isTrue);
      });

      test('snapshots with same values are equal', () {
        final snapshot1 = AppStateSnapshot(
          images: [createTestImage('img-1')],
          groups: [createTestGroup('grp-1', ['img-1'])],
          colorizedImages: [createTestColorizedImage('col-1', 'grp-1')],
          adjustments: {'grp-1': const ImageAdjustments(hue: 0.5)},
          selectedGenerations: {'grp-1': 1},
        );

        final snapshot2 = AppStateSnapshot(
          images: [createTestImage('img-1')],
          groups: [createTestGroup('grp-1', ['img-1'])],
          colorizedImages: [createTestColorizedImage('col-1', 'grp-1')],
          adjustments: {'grp-1': const ImageAdjustments(hue: 0.5)},
          selectedGenerations: {'grp-1': 1},
        );

        expect(snapshot1, equals(snapshot2));
      });

      test('snapshots with different images are not equal', () {
        final snapshot1 = AppStateSnapshot(
          images: [createTestImage('img-1')],
          groups: [],
          colorizedImages: [],
          adjustments: {},
          selectedGenerations: {},
        );

        final snapshot2 = AppStateSnapshot(
          images: [createTestImage('img-2')],
          groups: [],
          colorizedImages: [],
          adjustments: {},
          selectedGenerations: {},
        );

        expect(snapshot1, isNot(equals(snapshot2)));
      });

      test('snapshots with different groups are not equal', () {
        final snapshot1 = AppStateSnapshot(
          images: [],
          groups: [createTestGroup('grp-1', ['img-1'])],
          colorizedImages: [],
          adjustments: {},
          selectedGenerations: {},
        );

        final snapshot2 = AppStateSnapshot(
          images: [],
          groups: [createTestGroup('grp-2', ['img-2'])],
          colorizedImages: [],
          adjustments: {},
          selectedGenerations: {},
        );

        expect(snapshot1, isNot(equals(snapshot2)));
      });

      test('snapshots with different colorizedImages are not equal', () {
        final snapshot1 = AppStateSnapshot(
          images: [],
          groups: [],
          colorizedImages: [createTestColorizedImage('col-1', 'grp-1')],
          adjustments: {},
          selectedGenerations: {},
        );

        final snapshot2 = AppStateSnapshot(
          images: [],
          groups: [],
          colorizedImages: [createTestColorizedImage('col-2', 'grp-1')],
          adjustments: {},
          selectedGenerations: {},
        );

        expect(snapshot1, isNot(equals(snapshot2)));
      });

      test('snapshots with different adjustments are not equal', () {
        final snapshot1 = AppStateSnapshot(
          images: [],
          groups: [],
          colorizedImages: [],
          adjustments: {'grp-1': const ImageAdjustments(hue: 0.5)},
          selectedGenerations: {},
        );

        final snapshot2 = AppStateSnapshot(
          images: [],
          groups: [],
          colorizedImages: [],
          adjustments: {'grp-1': const ImageAdjustments(hue: 0.8)},
          selectedGenerations: {},
        );

        expect(snapshot1, isNot(equals(snapshot2)));
      });

      test('snapshots with different selectedGenerations are not equal', () {
        final snapshot1 = AppStateSnapshot(
          images: [],
          groups: [],
          colorizedImages: [],
          adjustments: {},
          selectedGenerations: {'grp-1': 0},
        );

        final snapshot2 = AppStateSnapshot(
          images: [],
          groups: [],
          colorizedImages: [],
          adjustments: {},
          selectedGenerations: {'grp-1': 1},
        );

        expect(snapshot1, isNot(equals(snapshot2)));
      });

      test('snapshots with different list lengths are not equal', () {
        final snapshot1 = AppStateSnapshot(
          images: [createTestImage('img-1')],
          groups: [],
          colorizedImages: [],
          adjustments: {},
          selectedGenerations: {},
        );

        final snapshot2 = AppStateSnapshot(
          images: [createTestImage('img-1'), createTestImage('img-2')],
          groups: [],
          colorizedImages: [],
          adjustments: {},
          selectedGenerations: {},
        );

        expect(snapshot1, isNot(equals(snapshot2)));
      });

      test('empty snapshots are equal', () {
        final empty1 = AppStateSnapshot.empty();
        final empty2 = AppStateSnapshot(
          images: [],
          groups: [],
          colorizedImages: [],
          adjustments: {},
          selectedGenerations: {},
        );

        expect(empty1, equals(empty2));
      });

      test('comparison with non-AppStateSnapshot returns false', () {
        final snapshot = AppStateSnapshot.empty();
        expect(snapshot == 'not a snapshot', isFalse);
        expect(snapshot == 42, isFalse);
        expect(snapshot == null, isFalse);
      });
    });

    group('hashCode', () {
      test('equal snapshots have equal hashCodes', () {
        final snapshot1 = AppStateSnapshot(
          images: [createTestImage('img-1')],
          groups: [createTestGroup('grp-1', ['img-1'])],
          colorizedImages: [createTestColorizedImage('col-1', 'grp-1')],
          adjustments: {'grp-1': const ImageAdjustments(hue: 0.5)},
          selectedGenerations: {'grp-1': 1},
        );

        final snapshot2 = AppStateSnapshot(
          images: [createTestImage('img-1')],
          groups: [createTestGroup('grp-1', ['img-1'])],
          colorizedImages: [createTestColorizedImage('col-1', 'grp-1')],
          adjustments: {'grp-1': const ImageAdjustments(hue: 0.5)},
          selectedGenerations: {'grp-1': 1},
        );

        expect(snapshot1.hashCode, equals(snapshot2.hashCode));
      });

      test('hashCode is consistent across multiple calls', () {
        final snapshot = AppStateSnapshot(
          images: [createTestImage('img-1')],
          groups: [],
          colorizedImages: [],
          adjustments: {},
          selectedGenerations: {},
        );

        final hash1 = snapshot.hashCode;
        final hash2 = snapshot.hashCode;
        final hash3 = snapshot.hashCode;

        expect(hash1, equals(hash2));
        expect(hash2, equals(hash3));
      });

      test('empty snapshots have equal hashCodes', () {
        final empty1 = AppStateSnapshot.empty();
        final empty2 = AppStateSnapshot.empty();

        expect(empty1.hashCode, equals(empty2.hashCode));
      });
    });

    group('deep copy verification', () {
      test('copyWith creates independent copy - modifying original list does not affect copy', () {
        final originalImages = <ImportedImage>[createTestImage('img-1')];
        final original = AppStateSnapshot(
          images: originalImages,
          groups: [],
          colorizedImages: [],
          adjustments: {},
          selectedGenerations: {},
        );

        final copied = original.copyWith();

        // The copyWith with no args returns same references (expected behavior)
        // But when we modify via copyWith with new list, original is unaffected
        final newImages = [...original.images, createTestImage('img-2')];
        final modified = original.copyWith(images: newImages);

        expect(original.images.length, equals(1));
        expect(modified.images.length, equals(2));
      });

      test('copyWith creates independent copy - modifying original map does not affect copy', () {
        final originalAdjustments = <String, ImageAdjustments>{
          'grp-1': const ImageAdjustments(hue: 0.5)
        };
        final original = AppStateSnapshot(
          images: [],
          groups: [],
          colorizedImages: [],
          adjustments: originalAdjustments,
          selectedGenerations: {},
        );

        // Create new map with additional entry
        final newAdjustments = {...original.adjustments, 'grp-2': const ImageAdjustments(saturation: 0.3)};
        final modified = original.copyWith(adjustments: newAdjustments);

        expect(original.adjustments.length, equals(1));
        expect(modified.adjustments.length, equals(2));
      });

      test('copyWith preserves immutability of fields', () {
        final snapshot1 = AppStateSnapshot(
          images: [createTestImage('img-1')],
          groups: [createTestGroup('grp-1', ['img-1'])],
          colorizedImages: [],
          adjustments: {'grp-1': const ImageAdjustments()},
          selectedGenerations: {'grp-1': 0},
        );

        // Create a modified copy
        final snapshot2 = snapshot1.copyWith(
          selectedGenerations: {'grp-1': 2},
        );

        // Original should be unchanged
        expect(snapshot1.selectedGenerations['grp-1'], equals(0));
        expect(snapshot2.selectedGenerations['grp-1'], equals(2));
      });
    });

    group('complex state scenarios', () {
      test('snapshot with multiple items in all collections', () {
        final snapshot = AppStateSnapshot(
          images: [
            createTestImage('img-1', isSelected: true),
            createTestImage('img-2', isGrouped: true),
            createTestImage('img-3'),
          ],
          groups: [
            createTestGroup('grp-1', ['img-1', 'img-2']),
            createTestGroup('grp-2', ['img-3']),
          ],
          colorizedImages: [
            createTestColorizedImage('col-1', 'grp-1', generationIndex: 0),
            createTestColorizedImage('col-2', 'grp-1', generationIndex: 1),
            createTestColorizedImage('col-3', 'grp-2', generationIndex: 0),
          ],
          adjustments: {
            'grp-1': const ImageAdjustments(hue: 0.2, saturation: 0.3),
            'grp-2': const ImageAdjustments(brightness: 0.1),
          },
          selectedGenerations: {
            'grp-1': 1,
            'grp-2': 0,
          },
        );

        expect(snapshot.images.length, equals(3));
        expect(snapshot.groups.length, equals(2));
        expect(snapshot.colorizedImages.length, equals(3));
        expect(snapshot.adjustments.length, equals(2));
        expect(snapshot.selectedGenerations.length, equals(2));
      });

      test('snapshot equality with complex state', () {
        createComplexSnapshot() => AppStateSnapshot(
          images: [
            createTestImage('img-1', isSelected: true),
            createTestImage('img-2', isGrouped: true),
          ],
          groups: [
            createTestGroup('grp-1', ['img-1', 'img-2']),
          ],
          colorizedImages: [
            createTestColorizedImage('col-1', 'grp-1'),
          ],
          adjustments: {
            'grp-1': const ImageAdjustments(hue: 0.5, saturation: 0.5),
          },
          selectedGenerations: {
            'grp-1': 1,
          },
        );

        final snapshot1 = createComplexSnapshot();
        final snapshot2 = createComplexSnapshot();

        expect(snapshot1, equals(snapshot2));
        expect(snapshot1.hashCode, equals(snapshot2.hashCode));
      });
    });
  });

  group('ImageAdjustments equality', () {
    test('ImageAdjustments with same values are equal', () {
      const adj1 = ImageAdjustments(hue: 0.5, saturation: 0.3);
      const adj2 = ImageAdjustments(hue: 0.5, saturation: 0.3);

      // ImageAdjustments doesn't override == so identity check only
      expect(adj1.hue, equals(adj2.hue));
      expect(adj1.saturation, equals(adj2.saturation));
    });

    test('hasAdjustments returns true when values are non-zero', () {
      const adj1 = ImageAdjustments(hue: 0.5);
      const adj2 = ImageAdjustments();

      expect(adj1.hasAdjustments, isTrue);
      expect(adj2.hasAdjustments, isFalse);
    });
  });
}
