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
    bool useWhiteBackground = true,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Parse hex color
    final color = _parseHexColor(hexColor);

    // Decode the template image (SILK Template.png with transparency)
    final templateImage = img.decodeImage(templateImageBytes);
    if (templateImage == null) {
      throw ColorizationException('Failed to decode template image');
    }

    // Apply colorization to the template (preserving alpha)
    final colorizedTemplate = _applyColorTint(templateImage, color);

    // Store base colorized bytes BEFORE background/carton (for adjustments later)
    final baseColorizedBytes = Uint8List.fromList(img.encodePng(colorizedTemplate));

    // Composite 3 layers: background + colorized template + carton
    final finalImage = _composite3Layers(colorizedTemplate, useWhiteBackground);

    // Encode based on background mode
    final Uint8List outputBytes;
    if (useWhiteBackground) {
      outputBytes = Uint8List.fromList(img.encodeJpg(finalImage, quality: 95));
    } else {
      outputBytes = Uint8List.fromList(img.encodePng(finalImage));
    }

    return ColorizedImage(
      id: _uuid.v4(),
      sourceImageId: sourceImageId,
      groupId: groupId,
      appliedHex: hexColor,
      bytes: outputBytes,
      baseColorizedBytes: baseColorizedBytes,
      createdAt: DateTime.now(),
    );
  }

  /// Apply adjustments to the base colorized image (without carton/background),
  /// then composite 3 layers: background + adjusted template + carton.
  Future<Uint8List> applyAdjustments({
    required Uint8List baseColorizedBytes,
    required double hue,        // -1.0 to 1.0 (0 = no change)
    required double saturation, // -1.0 to 1.0 (0 = no change)
    required double brightness, // -1.0 to 1.0 (0 = no change)
    required double contrast,   // -1.0 to 1.0 (0 = no change)
    required double sharpness,  // 0.0 to 1.0 (0 = no change)
    bool useWhiteBackground = true,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Decode base colorized image (with alpha preserved)
    var image = img.decodeImage(baseColorizedBytes);
    if (image == null) {
      throw ColorizationException('Failed to decode base colorized image');
    }

    // Apply hue adjustment (preserving alpha)
    if (hue != 0) {
      image = _adjustHue(image, hue);
    }

    // Apply saturation adjustment (preserving alpha)
    if (saturation != 0) {
      image = _adjustSaturation(image, saturation);
    }

    // Apply brightness adjustment (preserving alpha)
    if (brightness != 0) {
      image = _adjustBrightness(image, brightness);
    }

    // Apply contrast adjustment (preserving alpha)
    if (contrast != 0) {
      image = _adjustContrast(image, contrast);
    }

    // Apply sharpness adjustment (preserving alpha)
    if (sharpness > 0) {
      image = _adjustSharpness(image, sharpness);
    }

    // Composite 3 layers: background + adjusted template + carton
    final finalImage = _composite3Layers(image, useWhiteBackground);

    // Encode based on background mode
    if (useWhiteBackground) {
      return Uint8List.fromList(img.encodeJpg(finalImage, quality: 95));
    } else {
      return Uint8List.fromList(img.encodePng(finalImage));
    }
  }

  img.Image _adjustHue(img.Image source, double hueShift) {
    final result = img.Image.from(source);
    // hueShift is -1.0 to 1.0, convert to degrees (-180 to 180)
    final hueDegrees = hueShift * 180;

    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final a = pixel.a.toInt();

        // Convert RGB to HSL
        final hsl = _rgbToHsl(r, g, b);

        // Shift hue
        hsl[0] = (hsl[0] + hueDegrees) % 360;
        if (hsl[0] < 0) hsl[0] += 360;

        // Convert back to RGB
        final rgb = _hslToRgb(hsl[0], hsl[1], hsl[2]);
        result.setPixel(x, y, img.ColorRgba8(rgb[0], rgb[1], rgb[2], a));
      }
    }
    return result;
  }

  img.Image _adjustSaturation(img.Image source, double saturationShift) {
    final result = img.Image.from(source);
    // saturationShift is -1.0 to 1.0

    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final a = pixel.a.toInt();

        // Convert RGB to HSL
        final hsl = _rgbToHsl(r, g, b);

        // Adjust saturation
        if (saturationShift > 0) {
          hsl[1] = hsl[1] + (1 - hsl[1]) * saturationShift;
        } else {
          hsl[1] = hsl[1] * (1 + saturationShift);
        }
        hsl[1] = hsl[1].clamp(0.0, 1.0);

        // Convert back to RGB
        final rgb = _hslToRgb(hsl[0], hsl[1], hsl[2]);
        result.setPixel(x, y, img.ColorRgba8(rgb[0], rgb[1], rgb[2], a));
      }
    }
    return result;
  }

  img.Image _adjustBrightness(img.Image source, double brightnessShift) {
    final result = img.Image.from(source);
    // brightnessShift is -1.0 to 1.0
    // Adjust lightness in HSL space to affect only brightness, not contrast

    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final a = pixel.a.toInt();

        // Convert RGB to HSL
        final hsl = _rgbToHsl(r, g, b);

        // Adjust lightness
        if (brightnessShift > 0) {
          // Brighten: move lightness towards 1.0
          hsl[2] = hsl[2] + (1.0 - hsl[2]) * brightnessShift;
        } else {
          // Darken: move lightness towards 0.0
          hsl[2] = hsl[2] * (1.0 + brightnessShift);
        }
        hsl[2] = hsl[2].clamp(0.0, 1.0);

        // Convert back to RGB
        final rgb = _hslToRgb(hsl[0], hsl[1], hsl[2]);
        result.setPixel(x, y, img.ColorRgba8(rgb[0], rgb[1], rgb[2], a));
      }
    }
    return result;
  }

  img.Image _adjustContrast(img.Image source, double contrastShift) {
    final result = img.Image.from(source);
    // contrastShift is -1.0 to 1.0
    // Formula: newValue = ((value - 128) * (1 + contrastShift)) + 128

    final factor = 1.0 + contrastShift;

    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final a = pixel.a.toInt();

        final newR = ((r - 128) * factor + 128).round().clamp(0, 255);
        final newG = ((g - 128) * factor + 128).round().clamp(0, 255);
        final newB = ((b - 128) * factor + 128).round().clamp(0, 255);

        result.setPixel(x, y, img.ColorRgba8(newR, newG, newB, a));
      }
    }
    return result;
  }

  img.Image _adjustSharpness(img.Image source, double sharpness) {
    // Use unsharp mask technique
    // sharpness is 0.0 to 1.0
    final blurred = img.gaussianBlur(source, radius: 1);
    final result = img.Image.from(source);

    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        final original = source.getPixel(x, y);
        final blur = blurred.getPixel(x, y);

        // Unsharp mask: original + (original - blurred) * amount
        final newR = (original.r + (original.r - blur.r) * sharpness * 2).round().clamp(0, 255);
        final newG = (original.g + (original.g - blur.g) * sharpness * 2).round().clamp(0, 255);
        final newB = (original.b + (original.b - blur.b) * sharpness * 2).round().clamp(0, 255);

        result.setPixel(x, y, img.ColorRgba8(newR, newG, newB, original.a.toInt()));
      }
    }
    return result;
  }

  // RGB to HSL conversion
  List<double> _rgbToHsl(int r, int g, int b) {
    final rf = r / 255.0;
    final gf = g / 255.0;
    final bf = b / 255.0;

    final max = [rf, gf, bf].reduce((a, b) => a > b ? a : b);
    final min = [rf, gf, bf].reduce((a, b) => a < b ? a : b);
    final diff = max - min;

    double h = 0;
    double s = 0;
    final l = (max + min) / 2;

    if (diff != 0) {
      s = l > 0.5 ? diff / (2 - max - min) : diff / (max + min);

      if (max == rf) {
        h = ((gf - bf) / diff + (gf < bf ? 6 : 0)) * 60;
      } else if (max == gf) {
        h = ((bf - rf) / diff + 2) * 60;
      } else {
        h = ((rf - gf) / diff + 4) * 60;
      }
    }

    return [h, s, l];
  }

  // HSL to RGB conversion
  List<int> _hslToRgb(double h, double s, double l) {
    if (s == 0) {
      final v = (l * 255).round();
      return [v, v, v];
    }

    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;

    double hueToRgb(double t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    }

    final hNorm = h / 360;
    return [
      (hueToRgb(hNorm + 1 / 3) * 255).round().clamp(0, 255),
      (hueToRgb(hNorm) * 255).round().clamp(0, 255),
      (hueToRgb(hNorm - 1 / 3) * 255).round().clamp(0, 255),
    ];
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
        final a = pixel.a.toInt();

        // Skip fully transparent pixels (preserve transparency)
        if (a == 0) continue;

        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

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

        // Preserve original alpha
        result.setPixel(x, y, img.ColorRgba8(newR, newG, newB, a));
      }
    }

    return result;
  }

  /// Composite 3 layers: background (white or transparent) + colorized template + carton
  img.Image _composite3Layers(img.Image colorizedTemplate, bool useWhiteBackground) {
    final width = colorizedTemplate.width;
    final height = colorizedTemplate.height;

    // Layer 1: Create background
    final result = img.Image(width: width, height: height);
    if (useWhiteBackground) {
      // Fill with white
      result.clear(img.ColorRgba8(255, 255, 255, 255));
    } else {
      // Fill with transparent
      result.clear(img.ColorRgba8(0, 0, 0, 0));
    }

    // Layer 2: Composite colorized template on top of background (alpha blend)
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final templatePixel = colorizedTemplate.getPixel(x, y);
        final templateAlpha = templatePixel.a.toInt();

        if (templateAlpha > 0) {
          final basePixel = result.getPixel(x, y);
          final alpha = templateAlpha / 255.0;
          final invAlpha = 1.0 - alpha;

          final newR = (templatePixel.r.toInt() * alpha + basePixel.r.toInt() * invAlpha).round().clamp(0, 255);
          final newG = (templatePixel.g.toInt() * alpha + basePixel.g.toInt() * invAlpha).round().clamp(0, 255);
          final newB = (templatePixel.b.toInt() * alpha + basePixel.b.toInt() * invAlpha).round().clamp(0, 255);

          // Preserve alpha for transparent background mode
          final newA = useWhiteBackground ? 255 : (basePixel.a.toInt() + templateAlpha * (255 - basePixel.a.toInt()) ~/ 255).clamp(0, 255);

          result.setPixel(x, y, img.ColorRgba8(newR, newG, newB, newA));
        }
      }
    }

    // Layer 3: Composite carton on top
    if (_cartonImageBytes != null) {
      final cartonImage = img.decodeImage(_cartonImageBytes!);
      if (cartonImage != null) {
        img.Image carton = cartonImage;
        if (carton.width != width || carton.height != height) {
          carton = img.copyResize(
            carton,
            width: width,
            height: height,
            interpolation: img.Interpolation.cubic,
          );
        }

        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final cartonPixel = carton.getPixel(x, y);
            final cartonAlpha = cartonPixel.a.toInt();

            if (cartonAlpha > 0) {
              final basePixel = result.getPixel(x, y);
              final alpha = cartonAlpha / 255.0;
              final invAlpha = 1.0 - alpha;

              final newR = (cartonPixel.r.toInt() * alpha + basePixel.r.toInt() * invAlpha).round().clamp(0, 255);
              final newG = (cartonPixel.g.toInt() * alpha + basePixel.g.toInt() * invAlpha).round().clamp(0, 255);
              final newB = (cartonPixel.b.toInt() * alpha + basePixel.b.toInt() * invAlpha).round().clamp(0, 255);

              // Preserve alpha for transparent background mode
              final newA = useWhiteBackground ? 255 : (basePixel.a.toInt() + cartonAlpha * (255 - basePixel.a.toInt()) ~/ 255).clamp(0, 255);

              result.setPixel(x, y, img.ColorRgba8(newR, newG, newB, newA));
            }
          }
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
