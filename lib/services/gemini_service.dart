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

    final response = await _model.generateContent([prompt]);
    final hexColor = _parseHexFromResponse(response.text);

    return ColorExtractionResult(
      hexColor: hexColor,
      rawResponse: response.text,
    );
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
