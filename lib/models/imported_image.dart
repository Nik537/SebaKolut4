/// Lightweight model for imported images.
/// Binary data (bytes, thumbnailBytes) is stored separately in ImageCacheService
/// to avoid expensive state copies when provider state changes.
class ImportedImage {
  final String id;
  final String filename;
  final DateTime importedAt;
  final bool isSelected;
  final bool isGrouped;

  const ImportedImage({
    required this.id,
    required this.filename,
    required this.importedAt,
    this.isSelected = false,
    this.isGrouped = false,
  });

  ImportedImage copyWith({
    String? id,
    String? filename,
    DateTime? importedAt,
    bool? isSelected,
    bool? isGrouped,
  }) {
    return ImportedImage(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      importedAt: importedAt ?? this.importedAt,
      isSelected: isSelected ?? this.isSelected,
      isGrouped: isGrouped ?? this.isGrouped,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImportedImage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
