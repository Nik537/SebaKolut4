import 'dart:math' as math;
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

  // Apply color adjustments using RGB matrix (matches preview exactly)
  if (hue != 0 || saturation != 0 || brightness != 0 || contrast != 0) {
    image = _applyColorMatrixStatic(
      image,
      hue: hue,
      saturation: saturation,
      brightness: brightness,
      contrast: contrast,
    );
  }

  // Sharpness is a separate convolution operation
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

  // Apply color adjustments using RGB matrix (matches preview exactly)
  if (hue != 0 || saturation != 0 || brightness != 0 || contrast != 0) {
    colorizedZoomed = _applyColorMatrixStatic(
      colorizedZoomed,
      hue: hue,
      saturation: saturation,
      brightness: brightness,
      contrast: contrast,
    );
  }

  // Sharpness is a separate convolution operation
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

  // Apply color adjustments using RGB matrix (matches preview exactly)
  if (hue != 0 || saturation != 0 || brightness != 0 || contrast != 0) {
    colorizedFront = _applyColorMatrixStatic(
      colorizedFront,
      hue: hue,
      saturation: saturation,
      brightness: brightness,
      contrast: contrast,
    );
  }

  // Sharpness is a separate convolution operation
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

// ============================================================================
// RGB COLOR MATRIX FUNCTIONS (matches preview exactly)
// ============================================================================

/// Build a 5x4 color matrix for image adjustments.
/// This is the same algorithm used in the preview (processing_screen.dart).
List<double> _buildColorMatrixStatic({
  double hue = 0.0,
  double saturation = 0.0,
  double brightness = 0.0,
  double contrast = 0.0,
}) {
  // Start with identity matrix
  // Format: [R, G, B, A, offset] for each of R, G, B, A output channels
  final matrix = <double>[
    1, 0, 0, 0, 0, // R
    0, 1, 0, 0, 0, // G
    0, 0, 1, 0, 0, // B
    0, 0, 0, 1, 0, // A
  ];

  // Apply brightness (add to offset, scale by 255)
  final b = brightness * 255;
  matrix[4] += b;
  matrix[9] += b;
  matrix[14] += b;

  // Apply contrast (scale around 0.5)
  final c = 1.0 + contrast;
  final t = (1.0 - c) * 127.5;
  matrix[0] *= c;
  matrix[6] *= c;
  matrix[12] *= c;
  matrix[4] += t;
  matrix[9] += t;
  matrix[14] += t;

  // Apply saturation
  // Blend towards grayscale using luminance weights
  const lr = 0.2126;
  const lg = 0.7152;
  const lb = 0.0722;
  final s = 1.0 + saturation;
  final sr = (1 - s) * lr;
  final sg = (1 - s) * lg;
  final sb = (1 - s) * lb;

  final m0 = matrix[0], m1 = matrix[1], m2 = matrix[2];
  final m5 = matrix[5], m6 = matrix[6], m7 = matrix[7];
  final m10 = matrix[10], m11 = matrix[11], m12 = matrix[12];

  matrix[0] = m0 * (sr + s) + m1 * sr + m2 * sr;
  matrix[1] = m0 * sg + m1 * (sg + s) + m2 * sg;
  matrix[2] = m0 * sb + m1 * sb + m2 * (sb + s);

  matrix[5] = m5 * (sr + s) + m6 * sr + m7 * sr;
  matrix[6] = m5 * sg + m6 * (sg + s) + m7 * sg;
  matrix[7] = m5 * sb + m6 * sb + m7 * (sb + s);

  matrix[10] = m10 * (sr + s) + m11 * sr + m12 * sr;
  matrix[11] = m10 * sg + m11 * (sg + s) + m12 * sg;
  matrix[12] = m10 * sb + m11 * sb + m12 * (sb + s);

  // Apply hue rotation
  if (hue != 0.0) {
    final angle = hue * math.pi; // Convert to radians
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);

    // Hue rotation matrix in RGB space
    final h00 = 0.213 + cosA * 0.787 - sinA * 0.213;
    final h01 = 0.715 - cosA * 0.715 - sinA * 0.715;
    final h02 = 0.072 - cosA * 0.072 + sinA * 0.928;
    final h10 = 0.213 - cosA * 0.213 + sinA * 0.143;
    final h11 = 0.715 + cosA * 0.285 + sinA * 0.140;
    final h12 = 0.072 - cosA * 0.072 - sinA * 0.283;
    final h20 = 0.213 - cosA * 0.213 - sinA * 0.787;
    final h21 = 0.715 - cosA * 0.715 + sinA * 0.715;
    final h22 = 0.072 + cosA * 0.928 + sinA * 0.072;

    final r0 = matrix[0], r1 = matrix[1], r2 = matrix[2];
    final g0 = matrix[5], g1 = matrix[6], g2 = matrix[7];
    final b0 = matrix[10], b1 = matrix[11], b2 = matrix[12];

    matrix[0] = r0 * h00 + r1 * h10 + r2 * h20;
    matrix[1] = r0 * h01 + r1 * h11 + r2 * h21;
    matrix[2] = r0 * h02 + r1 * h12 + r2 * h22;

    matrix[5] = g0 * h00 + g1 * h10 + g2 * h20;
    matrix[6] = g0 * h01 + g1 * h11 + g2 * h21;
    matrix[7] = g0 * h02 + g1 * h12 + g2 * h22;

    matrix[10] = b0 * h00 + b1 * h10 + b2 * h20;
    matrix[11] = b0 * h01 + b1 * h11 + b2 * h21;
    matrix[12] = b0 * h02 + b1 * h12 + b2 * h22;
  }

  return matrix;
}

/// Apply color matrix to image (matches preview exactly).
/// This uses the same RGB matrix algorithm as Flutter's ColorFilter.matrix().
img.Image _applyColorMatrixStatic(
  img.Image source, {
  double hue = 0.0,
  double saturation = 0.0,
  double brightness = 0.0,
  double contrast = 0.0,
}) {
  final result = img.Image.from(source);
  final matrix = _buildColorMatrixStatic(
    hue: hue,
    saturation: saturation,
    brightness: brightness,
    contrast: contrast,
  );

  for (int y = 0; y < result.height; y++) {
    for (int x = 0; x < result.width; x++) {
      final pixel = result.getPixel(x, y);
      final r = pixel.r.toDouble();
      final g = pixel.g.toDouble();
      final b = pixel.b.toDouble();
      final a = pixel.a.toInt();

      // Apply 5x4 color matrix (same as Flutter ColorFilter.matrix)
      final newR = (matrix[0] * r + matrix[1] * g + matrix[2] * b + matrix[4]).round().clamp(0, 255);
      final newG = (matrix[5] * r + matrix[6] * g + matrix[7] * b + matrix[9]).round().clamp(0, 255);
      final newB = (matrix[10] * r + matrix[11] * g + matrix[12] * b + matrix[14]).round().clamp(0, 255);

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
  static const String _templateBasePath =
      'assets/TEMPLATES FOR DIFFERENT FILAMENTS';

  bool _isInitialized = false;
  String? _currentFilamentType;
  Uint8List? _cartonImageBytes;
  Uint8List? _zoomedSilkTemplateBytes;
  Uint8List? _zoomedCartonImageBytes;
  Uint8List? _frontTemplateBytes;
  Uint8List? _frontCartonBytes;

  /// Get the carton overlay image bytes (for GPU-based preview)
  Uint8List? get cartonImageBytes => _cartonImageBytes;

  /// Get the current filament type
  String? get currentFilamentType => _currentFilamentType;

  /// Initialize the service with templates from the specified filament type folder.
  /// If filamentType is null, falls back to assets/images/ for backwards compatibility.
  Future<void> initialize({String? filamentType}) async {
    // If already initialized with the same filament type, skip
    if (_isInitialized && _currentFilamentType == filamentType) return;

    // Reset if switching filament types
    if (_currentFilamentType != filamentType) {
      _isInitialized = false;
      _cartonImageBytes = null;
      _zoomedSilkTemplateBytes = null;
      _zoomedCartonImageBytes = null;
      _frontTemplateBytes = null;
      _frontCartonBytes = null;
    }

    final basePath = filamentType != null
        ? '$_templateBasePath/$filamentType'
        : 'assets/images';

    // Load the carton overlay image
    final byteData = await rootBundle.load('$basePath/Carton.png');
    _cartonImageBytes = byteData.buffer.asUint8List();

    // Load zoomed SILK template
    final zoomedSilkData =
        await rootBundle.load('$basePath/Zoomed SILK Template.png');
    _zoomedSilkTemplateBytes = zoomedSilkData.buffer.asUint8List();

    // Load zoomed carton overlay
    final zoomedCartonData =
        await rootBundle.load('$basePath/Zoomed Karton.png');
    _zoomedCartonImageBytes = zoomedCartonData.buffer.asUint8List();

    // Load front template
    final frontTemplateData =
        await rootBundle.load('$basePath/Kolut in gorila spodaj.png');
    _frontTemplateBytes = frontTemplateData.buffer.asUint8List();

    // Load front carton overlay
    final frontCartonData =
        await rootBundle.load('$basePath/CartonGorilla.png');
    _frontCartonBytes = frontCartonData.buffer.asUint8List();

    _currentFilamentType = filamentType;
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
  /// If [cartonOverrideBytes] is provided, use it instead of the service's cached carton.
  Future<Uint8List> applyAdjustments({
    required Uint8List baseColorizedBytes,
    required double hue,        // -1.0 to 1.0 (0 = no change)
    required double saturation, // -1.0 to 1.0 (0 = no change)
    required double brightness, // -1.0 to 1.0 (0 = no change)
    required double contrast,   // -1.0 to 1.0 (0 = no change)
    required double sharpness,  // 0.0 to 1.0 (0 = no change)
    bool useWhiteBackground = true,
    Uint8List? cartonOverrideBytes,
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
      'cartonImageBytes': cartonOverrideBytes ?? _cartonImageBytes,
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
