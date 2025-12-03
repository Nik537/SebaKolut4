import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/colorized_image.dart';
import 'package:uuid/uuid.dart';

class NanoBananaService {
  late final GenerativeModel _model;
  bool _isInitialized = false;
  final _uuid = const Uuid();

  void initialize() {
    if (_isInitialized) return;

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_api_key_here') {
      throw Exception(
          'GEMINI_API_KEY not found in .env file. Please add your API key.');
    }

    // Use gemini-2.0-flash-exp for image generation capabilities
    _model = GenerativeModel(
      model: 'gemini-2.0-flash-exp',
      apiKey: apiKey,
    );
    _isInitialized = true;
  }

  Future<ColorizedImage> colorizeTemplate({
    required Uint8List templateImageBytes,
    required String hexColor,
    required String sourceImageId,
    required String groupId,
  }) async {
    if (!_isInitialized) {
      initialize();
    }

    final prompt = Content.multi([
      TextPart(
        'Change the color of this 3D printing filament spool to $hexColor. '
        'Maintain the silk/metallic sheen appearance of the filament. '
        'Keep the brown cardboard center spool unchanged. '
        'Preserve all lighting, shadows, and reflections. '
        'Return only the modified image.',
      ),
      DataPart('image/jpeg', templateImageBytes),
    ]);

    final response = await _model.generateContent([prompt]);
    final imageData = _extractImageFromResponse(response);

    return ColorizedImage(
      id: _uuid.v4(),
      sourceImageId: sourceImageId,
      groupId: groupId,
      appliedHex: hexColor,
      bytes: imageData,
      createdAt: DateTime.now(),
    );
  }

  Uint8List _extractImageFromResponse(GenerateContentResponse response) {
    // Try to find inline data in the response
    for (final candidate in response.candidates) {
      for (final part in candidate.content.parts) {
        // Check if part has inline data
        if (part is DataPart) {
          return Uint8List.fromList(part.bytes);
        }
      }
    }

    // If no image found, throw exception with the text response for debugging
    final text = response.text;
    throw ColorizationException(
      'No image found in API response. '
      'Response text: ${text ?? "empty"}. '
      'Note: Image generation may require specific API access.',
    );
  }
}

class ColorizationException implements Exception {
  final String message;
  ColorizationException(this.message);

  @override
  String toString() => 'ColorizationException: $message';
}
