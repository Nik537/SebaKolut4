import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import '../models/colorized_image.dart';
import 'package:uuid/uuid.dart';

class NanoBananaService {
  bool _isInitialized = false;
  final _uuid = const Uuid();
  Uint8List? _cartonImageBytes;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Load the carton overlay image
    final byteData = await rootBundle.load('assets/images/Carton.png');
    _cartonImageBytes = byteData.buffer.asUint8List();

    _isInitialized = true;
  }

  Future<ColorizedImage> colorizeTemplate({
    required Uint8List templateImageBytes,
    required String hexColor,
    required String sourceImageId,
    required String groupId,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Parse hex color
    final color = _parseHexColor(hexColor);

    // Decode the template image
    final image = img.decodeImage(templateImageBytes);
    if (image == null) {
      throw ColorizationException('Failed to decode template image');
    }

    // Apply colorization to the entire image
    final colorizedImage = _applyColorTint(image, color);

    // Overlay the carton image on top
    final finalImage = _overlayCarton(colorizedImage);

    // Encode back to JPEG
    final outputBytes = Uint8List.fromList(img.encodeJpg(finalImage, quality: 95));

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

  img.Image _overlayCarton(img.Image baseImage) {
    if (_cartonImageBytes == null) {
      return baseImage;
    }

    // Decode carton image (PNG with transparency)
    final cartonImage = img.decodeImage(_cartonImageBytes!);
    if (cartonImage == null) {
      return baseImage;
    }

    // Resize carton to match base image if needed
    img.Image carton = cartonImage;
    if (carton.width != baseImage.width || carton.height != baseImage.height) {
      carton = img.copyResize(
        carton,
        width: baseImage.width,
        height: baseImage.height,
        interpolation: img.Interpolation.cubic,
      );
    }

    // Composite carton on top of base image using alpha blending
    final result = img.Image.from(baseImage);

    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        final cartonPixel = carton.getPixel(x, y);
        final cartonAlpha = cartonPixel.a.toInt();

        if (cartonAlpha > 0) {
          final basePixel = result.getPixel(x, y);

          // Alpha blending
          final alpha = cartonAlpha / 255.0;
          final invAlpha = 1.0 - alpha;

          final newR = (cartonPixel.r.toInt() * alpha + basePixel.r.toInt() * invAlpha).round().clamp(0, 255);
          final newG = (cartonPixel.g.toInt() * alpha + basePixel.g.toInt() * invAlpha).round().clamp(0, 255);
          final newB = (cartonPixel.b.toInt() * alpha + basePixel.b.toInt() * invAlpha).round().clamp(0, 255);

          result.setPixel(x, y, img.ColorRgba8(newR, newG, newB, 255));
        }
      }
    }

    return result;
  }
}

class ColorizationException implements Exception {
  final String message;
  ColorizationException(this.message);

  @override
  String toString() => 'ColorizationException: $message';
}
