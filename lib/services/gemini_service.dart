import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/color_result.dart';

class GeminiService {
  late final GenerativeModel _model;
  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_api_key_here') {
      throw Exception(
          'GEMINI_API_KEY not found in .env file. Please add your API key.');
    }

    _model = GenerativeModel(
      model: 'gemini-3-pro-preview',
      apiKey: apiKey,
    );
    _isInitialized = true;
  }

  Future<ColorExtractionResult> extractColor(Uint8List imageBytes) async {
    if (!_isInitialized) {
      initialize();
    }

    final prompt = Content.multi([
      TextPart(
        'Analyze this 3D printing filament spool image and identify '
        'the exact hex color code of the filament material. '
        'Return ONLY the hex code in format #RRGGBB, nothing else.',
      ),
      DataPart('image/jpeg', imageBytes),
    ]);

    const maxAttempts = 3;
    Exception? lastError;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _model.generateContent([prompt]);
        final hexColor = _parseHexFromResponse(response.text);

        return ColorExtractionResult(
          hexColor: hexColor,
          rawResponse: response.text,
        );
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (attempt < maxAttempts) {
          // Wait before retrying (1 second delay)
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }

    throw ColorExtractionException(
        'Failed after $maxAttempts attempts: ${lastError.toString()}');
  }

  /// Analyze multiple images of the same filament spool (different angles/lighting)
  /// and determine the single best hex color that represents the filament.
  Future<String> extractColorFromMultipleImages(List<Uint8List> imageBytesList) async {
    if (!_isInitialized) {
      initialize();
    }

    if (imageBytesList.isEmpty) {
      throw ColorExtractionException('No images provided');
    }

    // If only one image, use simple extraction
    if (imageBytesList.length == 1) {
      final result = await extractColor(imageBytesList.first);
      return result.hexColor;
    }

    // Build prompt with all images
    final parts = <Part>[
      TextPart(
        'These are ${imageBytesList.length} photos of the SAME 3D printing filament spool '
        'taken from different angles and under different lighting conditions. '
        'Analyze ALL images together to determine the true color of the filament material. '
        'Consider that lighting variations may make the color appear different in each photo. '
        'Determine the single most accurate hex color code that represents this filament. '
        'Return ONLY the hex code in format #RRGGBB, nothing else.',
      ),
    ];

    // Add all images
    for (final imageBytes in imageBytesList) {
      parts.add(DataPart('image/jpeg', imageBytes));
    }

    final prompt = Content.multi(parts);

    const maxAttempts = 3;
    Exception? lastError;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _model.generateContent([prompt]);
        return _parseHexFromResponse(response.text);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (attempt < maxAttempts) {
          // Wait before retrying (1 second delay)
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }

    throw ColorExtractionException(
        'Failed after $maxAttempts attempts: ${lastError.toString()}');
  }

  String _parseHexFromResponse(String? text) {
    if (text == null || text.isEmpty) {
      throw ColorExtractionException('Empty response from Gemini');
    }

    // Extract hex pattern #RRGGBB
    final hexRegex = RegExp(r'#[0-9A-Fa-f]{6}');
    final match = hexRegex.firstMatch(text);

    if (match == null) {
      throw ColorExtractionException(
          'No hex color found in response: $text');
    }
    return match.group(0)!.toUpperCase();
  }
}

class ColorExtractionException implements Exception {
  final String message;
  ColorExtractionException(this.message);

  @override
  String toString() => 'ColorExtractionException: $message';
}
