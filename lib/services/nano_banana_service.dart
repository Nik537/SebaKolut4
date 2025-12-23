import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

/// Result of colorizing a template - contains the bytes for storage
class ColorizationResult {
  final Uint8List outputBytes;
  final Uint8List baseColorizedBytes;

  const ColorizationResult({
    required this.outputBytes,
    required this.baseColorizedBytes,
  });
}

// ============================================================================
// TOP-LEVEL ISOLATE FUNCTIONS (required for compute())
// ============================================================================

/// Isolate function for colorizeTemplate
Map<String, Uint8List> _colorizeTemplateIsolate(Map<String, dynamic> params) {
  final templateImageBytes = params['templateImageBytes'] as Uint8List;
  final hexColor = params['hexColor'] as String;
  final useWhiteBackground = params['useWhiteBackground'] as bool;
  final cartonImageBytes = params['cartonImageBytes'] as Uint8List?;

  // Decode the template image
  final templateImage = img.decodeImage(templateImageBytes);
  if (templateImage == null) {
    throw Exception('Failed to decode template image');
  }

  // Parse hex color
  final color = _parseHexColorStatic(hexColor);

  // Apply colorization to the template
  final colorizedTemplate = _applyColorTintStatic(templateImage, color);

  // Store base colorized bytes BEFORE background/carton
  final baseColorizedBytes = Uint8List.fromList(img.encodePng(colorizedTemplate));

  // Composite 3 layers
  final finalImage = _composite3LayersStatic(
    colorizedTemplate,
    useWhiteBackground,
    cartonImageBytes,
  );

  final outputBytes = Uint8List.fromList(img.encodePng(finalImage));

  return {
    'outputBytes': outputBytes,
    'baseColorizedBytes': baseColorizedBytes,
  };
}

/// Isolate function for applyAdjustments
Uint8List _applyAdjustmentsIsolate(Map<String, dynamic> params) {
  final baseColorizedBytes = params['baseColorizedBytes'] as Uint8List;
  final hue = params['hue'] as double;
  final saturation = params['saturation'] as double;
  final brightness = params['brightness'] as double;
  final contrast = params['contrast'] as double;
  final sharpness = params['sharpness'] as double;
  final useWhiteBackground = params['useWhiteBackground'] as bool;
  final cartonImageBytes = params['cartonImageBytes'] as Uint8List?;

  // Decode base colorized image
  var image = img.decodeImage(baseColorizedBytes);
  if (image == null) {
    throw Exception('Failed to decode base colorized image');
  }

  // Apply adjustments
  if (hue != 0) {
    image = _adjustHueStatic(image, hue);
  }
  if (saturation != 0) {
    image = _adjustSaturationStatic(image, saturation);
  }
  if (brightness != 0) {
    image = _adjustBrightnessStatic(image, brightness);
  }
  if (contrast != 0) {
    image = _adjustContrastStatic(image, contrast);
  }
  if (sharpness > 0) {
    image = _adjustSharpnessStatic(image, sharpness);
  }

  // Composite 3 layers
  final finalImage = _composite3LayersStatic(image, useWhiteBackground, cartonImageBytes);

  return Uint8List.fromList(img.encodePng(finalImage));
}

/// Isolate function for generateZoomImage
Uint8List _generateZoomImageIsolate(Map<String, dynamic> params) {
  final zoomedSilkTemplateBytes = params['zoomedSilkTemplateBytes'] as Uint8List;
  final zoomedCartonImageBytes = params['zoomedCartonImageBytes'] as Uint8List;
  final hexColor = params['hexColor'] as String;
  final hue = params['hue'] as double;
  final saturation = params['saturation'] as double;
  final brightness = params['brightness'] as double;
  final contrast = params['contrast'] as double;
  final sharpness = params['sharpness'] as double;

  // Parse hex color
  final color = _parseHexColorStatic(hexColor);

  // Decode the zoomed SILK template
  final zoomedTemplate = img.decodeImage(zoomedSilkTemplateBytes);
  if (zoomedTemplate == null) {
    throw Exception('Failed to decode zoomed SILK template');
  }

  // Apply colorization
  var colorizedZoomed = _applyColorTintStatic(zoomedTemplate, color);

  // Apply adjustments
  if (hue != 0) {
    colorizedZoomed = _adjustHueStatic(colorizedZoomed, hue);
  }
  if (saturation != 0) {
    colorizedZoomed = _adjustSaturationStatic(colorizedZoomed, saturation);
  }
  if (brightness != 0) {
    colorizedZoomed = _adjustBrightnessStatic(colorizedZoomed, brightness);
  }
  if (contrast != 0) {
    colorizedZoomed = _adjustContrastStatic(colorizedZoomed, contrast);
  }
  if (sharpness > 0) {
    colorizedZoomed = _adjustSharpnessStatic(colorizedZoomed, sharpness);
  }

  // Composite with zoomed carton
  final finalImage = _composite3LayersWithCartonStatic(
    colorizedZoomed,
    zoomedCartonImageBytes,
  );

  return Uint8List.fromList(img.encodePng(finalImage));
}

/// Isolate function for generateFrontImage
Uint8List _generateFrontImageIsolate(Map<String, dynamic> params) {
  final frontTemplateBytes = params['frontTemplateBytes'] as Uint8List;
  final frontCartonBytes = params['frontCartonBytes'] as Uint8List;
  final hexColor = params['hexColor'] as String;
  final hue = params['hue'] as double;
  final saturation = params['saturation'] as double;
  final brightness = params['brightness'] as double;
  final contrast = params['contrast'] as double;
  final sharpness = params['sharpness'] as double;

  // Parse hex color
  final color = _parseHexColorStatic(hexColor);

  // Decode the front template
  final frontTemplate = img.decodeImage(frontTemplateBytes);
  if (frontTemplate == null) {
    throw Exception('Failed to decode front template');
  }

  // Apply colorization
  var colorizedFront = _applyColorTintStatic(frontTemplate, color);

  // Apply adjustments
  if (hue != 0) {
    colorizedFront = _adjustHueStatic(colorizedFront, hue);
  }
  if (saturation != 0) {
    colorizedFront = _adjustSaturationStatic(colorizedFront, saturation);
  }
  if (brightness != 0) {
    colorizedFront = _adjustBrightnessStatic(colorizedFront, brightness);
  }
  if (contrast != 0) {
    colorizedFront = _adjustContrastStatic(colorizedFront, contrast);
  }
  if (sharpness > 0) {
    colorizedFront = _adjustSharpnessStatic(colorizedFront, sharpness);
  }

  // Composite with front carton
  final finalImage = _composite3LayersWithCartonStatic(
    colorizedFront,
    frontCartonBytes,
  );

  return Uint8List.fromList(img.encodePng(finalImage));
}

// ============================================================================
// STATIC HELPER FUNCTIONS (for use in isolates)
// ============================================================================

img.Color _parseHexColorStatic(String hex) {
  final hexCode = hex.replaceAll('#', '');
  final r = int.parse(hexCode.substring(0, 2), radix: 16);
  final g = int.parse(hexCode.substring(2, 4), radix: 16);
  final b = int.parse(hexCode.substring(4, 6), radix: 16);
  return img.ColorRgba8(r, g, b, 255);
}

List<double> _rgbToHslStatic(int r, int g, int b) {
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

List<int> _hslToRgbStatic(double h, double s, double l) {
  if (s == 0) {
    final v = (l * 255).round();
    return [v, v, v];
  }

  final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  final p = 2 * l - q;

  double hueToRgb(double t) {
    var tNorm = t;
    if (tNorm < 0) tNorm += 1;
    if (tNorm > 1) tNorm -= 1;
    if (tNorm < 1 / 6) return p + (q - p) * 6 * tNorm;
    if (tNorm < 1 / 2) return q;
    if (tNorm < 2 / 3) return p + (q - p) * (2 / 3 - tNorm) * 6;
    return p;
  }

  final hNorm = h / 360;
  return [
    (hueToRgb(hNorm + 1 / 3) * 255).round().clamp(0, 255),
    (hueToRgb(hNorm) * 255).round().clamp(0, 255),
    (hueToRgb(hNorm - 1 / 3) * 255).round().clamp(0, 255),
  ];
}

img.Image _adjustHueStatic(img.Image source, double hueShift) {
  final result = img.Image.from(source);
  final hueDegrees = hueShift * 180;

  for (int y = 0; y < result.height; y++) {
    for (int x = 0; x < result.width; x++) {
      final pixel = result.getPixel(x, y);
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();
      final a = pixel.a.toInt();

      final hsl = _rgbToHslStatic(r, g, b);
      hsl[0] = (hsl[0] + hueDegrees) % 360;
      if (hsl[0] < 0) hsl[0] += 360;

      final rgb = _hslToRgbStatic(hsl[0], hsl[1], hsl[2]);
      result.setPixel(x, y, img.ColorRgba8(rgb[0], rgb[1], rgb[2], a));
    }
  }
  return result;
}

img.Image _adjustSaturationStatic(img.Image source, double saturationShift) {
  final result = img.Image.from(source);

  for (int y = 0; y < result.height; y++) {
    for (int x = 0; x < result.width; x++) {
      final pixel = result.getPixel(x, y);
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();
      final a = pixel.a.toInt();

      final hsl = _rgbToHslStatic(r, g, b);
      if (saturationShift > 0) {
        hsl[1] = hsl[1] + (1 - hsl[1]) * saturationShift;
      } else {
        hsl[1] = hsl[1] * (1 + saturationShift);
      }
      hsl[1] = hsl[1].clamp(0.0, 1.0);

      final rgb = _hslToRgbStatic(hsl[0], hsl[1], hsl[2]);
      result.setPixel(x, y, img.ColorRgba8(rgb[0], rgb[1], rgb[2], a));
    }
  }
  return result;
}

img.Image _adjustBrightnessStatic(img.Image source, double brightnessShift) {
  final result = img.Image.from(source);

  for (int y = 0; y < result.height; y++) {
    for (int x = 0; x < result.width; x++) {
      final pixel = result.getPixel(x, y);
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();
      final a = pixel.a.toInt();

      final hsl = _rgbToHslStatic(r, g, b);
      if (brightnessShift > 0) {
        hsl[2] = hsl[2] + (1.0 - hsl[2]) * brightnessShift;
      } else {
        hsl[2] = hsl[2] * (1.0 + brightnessShift);
      }
      hsl[2] = hsl[2].clamp(0.0, 1.0);

      final rgb = _hslToRgbStatic(hsl[0], hsl[1], hsl[2]);
      result.setPixel(x, y, img.ColorRgba8(rgb[0], rgb[1], rgb[2], a));
    }
  }
  return result;
}

img.Image _adjustContrastStatic(img.Image source, double contrastShift) {
  final result = img.Image.from(source);
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

img.Image _adjustSharpnessStatic(img.Image source, double sharpness) {
  final blurred = img.gaussianBlur(source, radius: 1);
  final result = img.Image.from(source);

  for (int y = 0; y < result.height; y++) {
    for (int x = 0; x < result.width; x++) {
      final original = source.getPixel(x, y);
      final blur = blurred.getPixel(x, y);

      final newR = (original.r + (original.r - blur.r) * sharpness * 2).round().clamp(0, 255);
      final newG = (original.g + (original.g - blur.g) * sharpness * 2).round().clamp(0, 255);
      final newB = (original.b + (original.b - blur.b) * sharpness * 2).round().clamp(0, 255);

      result.setPixel(x, y, img.ColorRgba8(newR, newG, newB, original.a.toInt()));
    }
  }
  return result;
}

img.Image _applyColorTintStatic(img.Image source, img.Color tintColor) {
  final result = img.Image.from(source);

  final tintR = tintColor.r.toInt();
  final tintG = tintColor.g.toInt();
  final tintB = tintColor.b.toInt();

  final tintLuminance = (0.299 * tintR + 0.587 * tintG + 0.114 * tintB);
  final boostFactor = tintLuminance < 128 ? 1.3 : 1.1;

  final boostedR = (tintR * boostFactor).round().clamp(0, 255);
  final boostedG = (tintG * boostFactor).round().clamp(0, 255);
  final boostedB = (tintB * boostFactor).round().clamp(0, 255);

  for (int y = 0; y < result.height; y++) {
    for (int x = 0; x < result.width; x++) {
      final pixel = result.getPixel(x, y);
      final a = pixel.a.toInt();

      if (a == 0) continue;

      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();

      final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;

      int newR, newG, newB;

      if (luminance < 0.5) {
        newR = (2 * luminance * boostedR).round().clamp(0, 255);
        newG = (2 * luminance * boostedG).round().clamp(0, 255);
        newB = (2 * luminance * boostedB).round().clamp(0, 255);
      } else {
        newR = (255 - (2 * (1 - luminance) * (255 - boostedR))).round().clamp(0, 255);
        newG = (255 - (2 * (1 - luminance) * (255 - boostedG))).round().clamp(0, 255);
        newB = (255 - (2 * (1 - luminance) * (255 - boostedB))).round().clamp(0, 255);
      }

      result.setPixel(x, y, img.ColorRgba8(newR, newG, newB, a));
    }
  }

  return result;
}

/// Composite 3 layers: background + colorized template + carton
img.Image _composite3LayersStatic(
  img.Image colorizedTemplate,
  bool useWhiteBackground,
  Uint8List? cartonImageBytes,
) {
  final width = colorizedTemplate.width;
  final height = colorizedTemplate.height;

  // Layer 1: Create background
  final result = img.Image(width: width, height: height);
  if (useWhiteBackground) {
    result.clear(img.ColorRgba8(255, 255, 255, 255));
  } else {
    result.clear(img.ColorRgba8(0, 0, 0, 0));
  }

  // Layer 2: Composite colorized template on top of background
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

        final newA = useWhiteBackground ? 255 : (basePixel.a.toInt() + templateAlpha * (255 - basePixel.a.toInt()) ~/ 255).clamp(0, 255);

        result.setPixel(x, y, img.ColorRgba8(newR, newG, newB, newA));
      }
    }
  }

  // Layer 3: Composite carton on top
  if (cartonImageBytes != null) {
    final cartonImage = img.decodeImage(cartonImageBytes);
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

            final newA = useWhiteBackground ? 255 : (basePixel.a.toInt() + cartonAlpha * (255 - basePixel.a.toInt()) ~/ 255).clamp(0, 255);

            result.setPixel(x, y, img.ColorRgba8(newR, newG, newB, newA));
          }
        }
      }
    }
  }

  return result;
}

/// Composite 3 layers with specific carton (for zoomed/front variants)
img.Image _composite3LayersWithCartonStatic(
  img.Image colorizedTemplate,
  Uint8List cartonImageBytes,
) {
  final width = colorizedTemplate.width;
  final height = colorizedTemplate.height;

  // Layer 1: Create white background
  final result = img.Image(width: width, height: height);
  result.clear(img.ColorRgba8(255, 255, 255, 255));

  // Layer 2: Composite colorized template on top of background
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

        result.setPixel(x, y, img.ColorRgba8(newR, newG, newB, 255));
      }
    }
  }

  // Layer 3: Composite carton on top
  final cartonImage = img.decodeImage(cartonImageBytes);
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

          result.setPixel(x, y, img.ColorRgba8(newR, newG, newB, 255));
        }
      }
    }
  }

  return result;
}

// ============================================================================
// SERVICE CLASS
// ============================================================================

class NanoBananaService {
  bool _isInitialized = false;
  Uint8List? _cartonImageBytes;
  Uint8List? _zoomedSilkTemplateBytes;
  Uint8List? _zoomedCartonImageBytes;
  Uint8List? _frontTemplateBytes;
  Uint8List? _frontCartonBytes;

  /// Get the carton overlay image bytes (for GPU-based preview)
  Uint8List? get cartonImageBytes => _cartonImageBytes;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Load the carton overlay image
    final byteData = await rootBundle.load('assets/images/Carton.png');
    _cartonImageBytes = byteData.buffer.asUint8List();

    // Load zoomed SILK template
    final zoomedSilkData = await rootBundle.load('assets/images/Zoomed SILK Template.png');
    _zoomedSilkTemplateBytes = zoomedSilkData.buffer.asUint8List();

    // Load zoomed carton overlay
    final zoomedCartonData = await rootBundle.load('assets/images/Zoomed Karton.png');
    _zoomedCartonImageBytes = zoomedCartonData.buffer.asUint8List();

    // Load front template
    final frontTemplateData = await rootBundle.load('assets/images/Kolut in gorila spodaj.png');
    _frontTemplateBytes = frontTemplateData.buffer.asUint8List();

    // Load front carton overlay
    final frontCartonData = await rootBundle.load('assets/images/CartonGorilla.png');
    _frontCartonBytes = frontCartonData.buffer.asUint8List();

    _isInitialized = true;
  }

  /// Colorize a template image with the given hex color.
  /// Returns ColorizationResult containing outputBytes and baseColorizedBytes
  /// for storage in ImageCacheService.
  Future<ColorizationResult> colorizeTemplate({
    required Uint8List templateImageBytes,
    required String hexColor,
    bool useWhiteBackground = true,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Run heavy image processing in a separate isolate
    final result = await compute(_colorizeTemplateIsolate, {
      'templateImageBytes': templateImageBytes,
      'hexColor': hexColor,
      'useWhiteBackground': useWhiteBackground,
      'cartonImageBytes': _cartonImageBytes,
    });

    return ColorizationResult(
      outputBytes: result['outputBytes']!,
      baseColorizedBytes: result['baseColorizedBytes']!,
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

    // Run heavy image processing in a separate isolate
    return compute(_applyAdjustmentsIsolate, {
      'baseColorizedBytes': baseColorizedBytes,
      'hue': hue,
      'saturation': saturation,
      'brightness': brightness,
      'contrast': contrast,
      'sharpness': sharpness,
      'useWhiteBackground': useWhiteBackground,
      'cartonImageBytes': _cartonImageBytes,
    });
  }

  /// Generate a zoomed image for export.
  /// Uses Zoomed SILK Template + Zoomed Karton with white background.
  Future<Uint8List> generateZoomImage({
    required String hexColor,
    required double hue,
    required double saturation,
    required double brightness,
    required double contrast,
    required double sharpness,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_zoomedSilkTemplateBytes == null || _zoomedCartonImageBytes == null) {
      throw ColorizationException('Zoomed templates not loaded');
    }

    // Run heavy image processing in a separate isolate
    return compute(_generateZoomImageIsolate, {
      'zoomedSilkTemplateBytes': _zoomedSilkTemplateBytes!,
      'zoomedCartonImageBytes': _zoomedCartonImageBytes!,
      'hexColor': hexColor,
      'hue': hue,
      'saturation': saturation,
      'brightness': brightness,
      'contrast': contrast,
      'sharpness': sharpness,
    });
  }

  /// Generate a front image for export.
  /// Uses Kolut in gorila spodaj.png + CartonGorilla.png with white background.
  Future<Uint8List> generateFrontImage({
    required String hexColor,
    required double hue,
    required double saturation,
    required double brightness,
    required double contrast,
    required double sharpness,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_frontTemplateBytes == null || _frontCartonBytes == null) {
      throw ColorizationException('Front templates not loaded');
    }

    // Run heavy image processing in a separate isolate
    return compute(_generateFrontImageIsolate, {
      'frontTemplateBytes': _frontTemplateBytes!,
      'frontCartonBytes': _frontCartonBytes!,
      'hexColor': hexColor,
      'hue': hue,
      'saturation': saturation,
      'brightness': brightness,
      'contrast': contrast,
      'sharpness': sharpness,
    });
  }

}

class ColorizationException implements Exception {
  final String message;
  ColorizationException(this.message);

  @override
  String toString() => 'ColorizationException: $message';
}
