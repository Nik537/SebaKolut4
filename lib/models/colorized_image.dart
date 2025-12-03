import 'dart:typed_data';

class ColorizedImage {
  final String id;
  final String sourceImageId;
  final String groupId;
  final String appliedHex;
  final Uint8List bytes;
  final Uint8List baseColorizedBytes; // Colorized image BEFORE carton overlay
  final DateTime createdAt;

  const ColorizedImage({
    required this.id,
    required this.sourceImageId,
    required this.groupId,
    required this.appliedHex,
    required this.bytes,
    required this.baseColorizedBytes,
    required this.createdAt,
  });

  ColorizedImage copyWith({
    String? id,
    String? sourceImageId,
    String? groupId,
    String? appliedHex,
    Uint8List? bytes,
    Uint8List? baseColorizedBytes,
    DateTime? createdAt,
  }) {
    return ColorizedImage(
      id: id ?? this.id,
      sourceImageId: sourceImageId ?? this.sourceImageId,
      groupId: groupId ?? this.groupId,
      appliedHex: appliedHex ?? this.appliedHex,
      bytes: bytes ?? this.bytes,
      baseColorizedBytes: baseColorizedBytes ?? this.baseColorizedBytes,
      createdAt: createdAt ?? this.createdAt,
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
