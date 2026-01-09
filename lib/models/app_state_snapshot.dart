import 'package:flutter/foundation.dart';
import 'imported_image.dart';
import 'image_group.dart';
import 'colorized_image.dart';
import '../providers/processing_provider.dart';

/// Immutable snapshot of all undoable application state.
///
/// Used by the undo/redo system to capture and restore app state.
/// Binary data (image bytes) is stored separately in ImageCacheService
/// to avoid memory issues - this snapshot only holds metadata.
class AppStateSnapshot {
  final List<ImportedImage> images;
  final List<ImageGroup> groups;
  final List<ColorizedImage> colorizedImages;
  final Map<String, ImageAdjustments> adjustments;
  final Map<String, int> selectedGenerations;

  const AppStateSnapshot({
    required this.images,
    required this.groups,
    required this.colorizedImages,
    required this.adjustments,
    required this.selectedGenerations,
  });

  /// Creates an empty snapshot with no state.
  factory AppStateSnapshot.empty() {
    return const AppStateSnapshot(
      images: [],
      groups: [],
      colorizedImages: [],
      adjustments: {},
      selectedGenerations: {},
    );
  }

  AppStateSnapshot copyWith({
    List<ImportedImage>? images,
    List<ImageGroup>? groups,
    List<ColorizedImage>? colorizedImages,
    Map<String, ImageAdjustments>? adjustments,
    Map<String, int>? selectedGenerations,
  }) {
    return AppStateSnapshot(
      images: images ?? this.images,
      groups: groups ?? this.groups,
      colorizedImages: colorizedImages ?? this.colorizedImages,
      adjustments: adjustments ?? this.adjustments,
      selectedGenerations: selectedGenerations ?? this.selectedGenerations,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AppStateSnapshot) return false;

    return listEquals(images, other.images) &&
        listEquals(groups, other.groups) &&
        listEquals(colorizedImages, other.colorizedImages) &&
        mapEquals(adjustments, other.adjustments) &&
        mapEquals(selectedGenerations, other.selectedGenerations);
  }

  @override
  int get hashCode {
    return Object.hash(
      Object.hashAll(images),
      Object.hashAll(groups),
      Object.hashAll(colorizedImages),
      Object.hashAll(adjustments.entries),
      Object.hashAll(selectedGenerations.entries),
    );
  }
}
