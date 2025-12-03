import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../models/colorized_image.dart';
import 'package:uuid/uuid.dart';

class NanoBananaService {
  bool _isInitialized = false;
  final _uuid = const Uuid();

  void initialize() {
    if (_isInitialized) return;
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

    // Parse hex color
    final color = _parseHexColor(hexColor);

    // Decode the template image
    final image = img.decodeImage(templateImageBytes);
    if (image == null) {
      throw ColorizationException('Failed to decode template image');
    }

    // Apply colorization
    final colorizedImage = _applyColorTint(image, color);

    // Encode back to JPEG
    final outputBytes = Uint8List.fromList(img.encodeJpg(colorizedImage, quality: 95));

    return ColorizedImage(
      id: _uuid.v4(),
      sourceImageId: sourceImageId,
      groupId: groupId,
      appliedHex: hexColor,
      bytes: outputBytes,
      createdAt: DateTime.now(),
    );
  }

  img.Color _parseHexColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    final r = int.parse(hexCode.substring(0, 2), radix: 16);
    final g = int.parse(hexCode.substring(2, 4), radix: 16);
    final b = int.parse(hexCode.substring(4, 6), radix: 16);
    return img.ColorRgba8(r, g, b, 255);
  }

  img.Image _applyColorTint(img.Image source, img.Color tintColor) {
    final result = img.Image.from(source);

    final tintR = tintColor.r.toInt();
    final tintG = tintColor.g.toInt();
    final tintB = tintColor.b.toInt();

    // Calculate the luminance of the tint color (0-255)
    final tintLuminance = (0.299 * tintR + 0.587 * tintG + 0.114 * tintB);

    // Boost factor to make colors more vibrant (especially for darker tints)
    final boostFactor = tintLuminance < 128 ? 1.3 : 1.1;

    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);

        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final a = pixel.a.toInt();

        // Calculate luminance of original pixel (grayscale value)
        final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;

        // Detect if pixel is part of the cardboard spool (brownish colors)
        // Cardboard typically has: R > G > B, with specific ratios
        final isBrownish = _isCardboardColor(r, g, b);

        if (isBrownish) {
          // Keep cardboard colors unchanged
          continue;
        }

        // Apply color tint while preserving luminance/sheen
        // Use overlay-like blending for better silk appearance
        int newR, newG, newB;

        if (luminance < 0.5) {
          // Darker areas: multiply blend
          newR = ((2 * luminance * tintR) * boostFactor).round().clamp(0, 255);
          newG = ((2 * luminance * tintG) * boostFactor).round().clamp(0, 255);
          newB = ((2 * luminance * tintB) * boostFactor).round().clamp(0, 255);
        } else {
          // Lighter areas: screen blend (for highlights/sheen)
          newR = (255 - (2 * (1 - luminance) * (255 - tintR))).round().clamp(0, 255);
          newG = (255 - (2 * (1 - luminance) * (255 - tintG))).round().clamp(0, 255);
          newB = (255 - (2 * (1 - luminance) * (255 - tintB))).round().clamp(0, 255);
        }

        result.setPixel(x, y, img.ColorRgba8(newR, newG, newB, a));
      }
    }

    return result;
  }

  bool _isCardboardColor(int r, int g, int b) {
    // Cardboard detection: brownish tones
    // Typical cardboard: warm brown colors where R > G > B
    // And the color is not too saturated (not pure gray, but not vivid either)

    final maxVal = [r, g, b].reduce((a, b) => a > b ? a : b);
    final minVal = [r, g, b].reduce((a, b) => a < b ? a : b);
    final saturation = maxVal > 0 ? (maxVal - minVal) / maxVal : 0.0;
    final luminance = (r + g + b) / 3.0;

    // Check for brownish hue (R > G > B or R >= G > B)
    final isBrownHue = r >= g && g > b;

    // Cardboard has moderate saturation and is in mid-luminance range
    final hasCardboardSaturation = saturation > 0.1 && saturation < 0.6;
    final hasCardboardLuminance = luminance > 60 && luminance < 200;

    // Also check for the specific brown color ratios
    final rToG = g > 0 ? r / g : 0.0;
    final gToB = b > 0 ? g / b : 0.0;
    final hasCardboardRatio = rToG > 1.0 && rToG < 1.5 && gToB > 1.1 && gToB < 2.0;

    return isBrownHue && hasCardboardSaturation && hasCardboardLuminance && hasCardboardRatio;
  }
}

class ColorizationException implements Exception {
  final String message;
  ColorizationException(this.message);

  @override
  String toString() => 'ColorizationException: $message';
}
