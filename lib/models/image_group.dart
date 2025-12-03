class ImageGroup {
  final String id;
  final String name;
  final List<String> imageIds;
  final DateTime createdAt;

  const ImageGroup({
    required this.id,
    required this.name,
    required this.imageIds,
    required this.createdAt,
  });

  ImageGroup copyWith({
    String? id,
    String? name,
    List<String>? imageIds,
    DateTime? createdAt,
  }) {
    return ImageGroup(
      id: id ?? this.id,
      name: name ?? this.name,
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
