enum ProcessingStatus {
  pending,
  extractingColor,
  colorExtracted,
  colorizing,
  completed,
  error,
}

class ImageProcessingState {
  final String imageId;
  final ProcessingStatus status;
  final String? extractedHex;
  final String? errorMessage;

  const ImageProcessingState({
    required this.imageId,
    this.status = ProcessingStatus.pending,
    this.extractedHex,
    this.errorMessage,
  });

  ImageProcessingState copyWith({
    String? imageId,
    ProcessingStatus? status,
    String? extractedHex,
    String? errorMessage,
  }) {
    return ImageProcessingState(
      imageId: imageId ?? this.imageId,
      status: status ?? this.status,
      extractedHex: extractedHex ?? this.extractedHex,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isProcessing =>
      status == ProcessingStatus.extractingColor ||
      status == ProcessingStatus.colorizing;

  bool get isComplete => status == ProcessingStatus.completed;

  bool get hasError => status == ProcessingStatus.error;
}
