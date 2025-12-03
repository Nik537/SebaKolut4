import 'dart:typed_data';

class ImportedImage {
  final String id;
  final String filename;
  final Uint8List bytes;
  final Uint8List thumbnailBytes;
  final DateTime importedAt;
  final bool isSelected;
  final bool isGrouped;

  const ImportedImage({
    required this.id,
    required this.filename,
    required this.bytes,
    required this.thumbnailBytes,
    required this.importedAt,
    this.isSelected = false,
    this.isGrouped = false,
  });

  ImportedImage copyWith({
    String? id,
    String? filename,
    Uint8List? bytes,
    Uint8List? thumbnailBytes,
    DateTime? importedAt,
    bool? isSelected,
    bool? isGrouped,
  }) {
    return ImportedImage(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      bytes: bytes ?? this.bytes,
      thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
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
