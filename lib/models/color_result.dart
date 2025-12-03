class ColorExtractionResult {
  final String hexColor;
  final String? rawResponse;

  const ColorExtractionResult({
    required this.hexColor,
    this.rawResponse,
  });

  ColorExtractionResult copyWith({
    String? hexColor,
    String? rawResponse,
  }) {
    return ColorExtractionResult(
      hexColor: hexColor ?? this.hexColor,
      rawResponse: rawResponse ?? this.rawResponse,
    );
  }
}
