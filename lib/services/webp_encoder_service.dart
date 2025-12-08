import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

class WebpEncoderService {
  static const int defaultMaxBytes = 150 * 1024; // 150KB
  static const int defaultTargetSize = 1080;

  /// Encode PNG image bytes to WebP format
  ///
  /// For [preserveTransparency] = true: Uses lossless encoding with alpha
  /// For [preserveTransparency] = false: Uses lossy encoding with size target
  Future<Uint8List> encodeToWebp({
    required Uint8List pngBytes,
    required bool preserveTransparency,
    int maxBytes = defaultMaxBytes,
    int targetSize = defaultTargetSize,
  }) async {
    if (kIsWeb) {
      // Web platform: return PNG as-is (WebP encoding not supported)
      // TODO: Consider using flutter_image_compress for web
      return pngBytes;
    }

    if (Platform.isWindows) {
      return _encodeWithCwebp(
        pngBytes: pngBytes,
        preserveTransparency: preserveTransparency,
        maxBytes: maxBytes,
        targetSize: targetSize,
      );
    }

    // For other platforms (iOS, Android, macOS, Linux)
    // TODO: Add flutter_image_compress support
    // For now, return PNG as-is
    return pngBytes;
  }

  /// Encode using cwebp.exe on Windows
  Future<Uint8List> _encodeWithCwebp({
    required Uint8List pngBytes,
    required bool preserveTransparency,
    required int maxBytes,
    required int targetSize,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final inputPath = '${tempDir.path}/webp_input_$timestamp.png';
    final outputPath = '${tempDir.path}/webp_output_$timestamp.webp';

    try {
      // Write PNG to temp file
      final inputFile = File(inputPath);
      await inputFile.writeAsBytes(pngBytes);

      // Find cwebp.exe (next to the main executable)
      final cwebpPath = await _findCwebpPath();

      // Build cwebp arguments
      final args = <String>[];

      if (preserveTransparency) {
        // Lossless with alpha preservation
        args.addAll(['-lossless', '-exact']);
      } else {
        // Lossy with size target
        args.addAll(['-q', '95', '-size', maxBytes.toString()]);
      }

      // Add resize if needed (cwebp will handle this)
      args.addAll(['-resize', targetSize.toString(), targetSize.toString()]);

      // Add input and output
      args.addAll([inputPath, '-o', outputPath]);

      // Run cwebp
      final result = await Process.run(cwebpPath, args);

      if (result.exitCode != 0) {
        throw WebpEncoderException(
          'cwebp failed with exit code ${result.exitCode}: ${result.stderr}',
        );
      }

      // Read output WebP file
      final outputFile = File(outputPath);
      if (!await outputFile.exists()) {
        throw WebpEncoderException('cwebp did not produce output file');
      }

      final webpBytes = await outputFile.readAsBytes();

      // For lossy encoding, check if we need to reduce quality further
      if (!preserveTransparency && webpBytes.length > maxBytes) {
        // Try with lower quality
        return _encodeWithReducedQuality(
          inputPath: inputPath,
          outputPath: outputPath,
          cwebpPath: cwebpPath,
          maxBytes: maxBytes,
          targetSize: targetSize,
        );
      }

      return webpBytes;
    } finally {
      // Cleanup temp files
      try {
        final inputFile = File(inputPath);
        if (await inputFile.exists()) {
          await inputFile.delete();
        }
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          await outputFile.delete();
        }
      } catch (_) {
        // Ignore cleanup errors
      }
    }
  }

  /// Retry encoding with progressively lower quality until under maxBytes
  Future<Uint8List> _encodeWithReducedQuality({
    required String inputPath,
    required String outputPath,
    required String cwebpPath,
    required int maxBytes,
    required int targetSize,
  }) async {
    int quality = 90;
    Uint8List? webpBytes;
    Uint8List? smallestBytes;
    int smallestSize = 0x7FFFFFFF; // Max int

    while (quality >= 1) {
      final args = [
        '-q', quality.toString(),
        '-resize', targetSize.toString(), targetSize.toString(),
        inputPath,
        '-o', outputPath,
      ];

      final result = await Process.run(cwebpPath, args);

      if (result.exitCode == 0) {
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          webpBytes = await outputFile.readAsBytes();
          
          // Track the smallest result achieved
          if (webpBytes.length < smallestSize) {
            smallestSize = webpBytes.length;
            smallestBytes = webpBytes;
          }
          
          if (webpBytes.length <= maxBytes) {
            return webpBytes;
          }
        }
      }

      // More aggressive quality reduction: fast at high quality, slower at low
      if (quality > 50) {
        quality -= 10;
      } else if (quality > 20) {
        quality -= 5;
      } else {
        quality -= 2;
      }
    }

    // Return smallest attempt even if over size limit (better than failing)
    if (smallestBytes != null) {
      return smallestBytes;
    }

    // This should rarely happen - only if all encoding attempts failed
    if (webpBytes != null) {
      return webpBytes;
    }

    throw WebpEncoderException('Failed to encode WebP - all encoding attempts failed');
  }

  /// Find cwebp.exe path - should be next to the main executable
  Future<String> _findCwebpPath() async {
    // Get the directory containing the running executable
    final exePath = Platform.resolvedExecutable;
    final exeDir = File(exePath).parent.path;

    // cwebp.exe should be in the same directory
    final cwebpPath = '$exeDir/cwebp.exe';
    final cwebpFile = File(cwebpPath);

    if (await cwebpFile.exists()) {
      return cwebpPath;
    }

    // Fallback: check if cwebp is in PATH
    try {
      final result = await Process.run('where', ['cwebp']);
      if (result.exitCode == 0) {
        final path = (result.stdout as String).trim().split('\n').first;
        return path;
      }
    } catch (_) {
      // Ignore
    }

    throw WebpEncoderException(
      'cwebp.exe not found. Expected at: $cwebpPath',
    );
  }
}

class WebpEncoderException implements Exception {
  final String message;
  WebpEncoderException(this.message);

  @override
  String toString() => 'WebpEncoderException: $message';
}
