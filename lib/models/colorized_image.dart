/// Lightweight model for colorized images.
/// Binary data (bytes, baseColorizedBytes) is stored separately in ImageCacheService
/// to avoid expensive state copies when provider state changes.
class ColorizedImage {
  final String id;
  final String sourceImageId;
  final String groupId;
  final String appliedHex;
  final DateTime createdAt;
  final int generationIndex; // 0, 1, or 2 for Generation 1, 2, 3

  const ColorizedImage({
    required this.id,
    required this.sourceImageId,
    required this.groupId,
    required this.appliedHex,
    required this.createdAt,
    this.generationIndex = 0,
  });

  ColorizedImage copyWith({
    String? id,
    String? sourceImageId,
    String? groupId,
    String? appliedHex,
    DateTime? createdAt,
    int? generationIndex,
  }) {
    return ColorizedImage(
      id: id ?? this.id,
      sourceImageId: sourceImageId ?? this.sourceImageId,
      groupId: groupId ?? this.groupId,
      appliedHex: appliedHex ?? this.appliedHex,
      createdAt: createdAt ?? this.createdAt,
      generationIndex: generationIndex ?? this.generationIndex,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ColorizedImage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
