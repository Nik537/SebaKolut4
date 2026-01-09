class ImageGroup {
  final String id;
  final String name;
  final String sku;
  final String? filamentType;
  final List<String> imageIds;
  final DateTime createdAt;

  const ImageGroup({
    required this.id,
    required this.name,
    this.sku = '',
    this.filamentType,
    required this.imageIds,
    required this.createdAt,
  });

  /// Check if the group is ready for processing (has required fields)
  bool get isReadyForProcessing => name.isNotEmpty && filamentType != null;

  ImageGroup copyWith({
    String? id,
    String? name,
    String? sku,
    String? filamentType,
    List<String>? imageIds,
    DateTime? createdAt,
  }) {
    return ImageGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      filamentType: filamentType ?? this.filamentType,
      imageIds: imageIds ?? this.imageIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImageGroup && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
