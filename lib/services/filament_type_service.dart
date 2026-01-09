import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents an available filament type with its folder path
class FilamentType {
  final String id;
  final String displayName;
  final String folderPath;

  const FilamentType({
    required this.id,
    required this.displayName,
    required this.folderPath,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FilamentType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Service to discover available filament types from asset folder structure
class FilamentTypeService {
  static const String templateBasePath =
      'assets/TEMPLATES FOR DIFFERENT FILAMENTS';

  List<FilamentType>? _cachedTypes;

  /// Get all available filament types by reading the manifest file
  Future<List<FilamentType>> getAvailableTypes() async {
    if (_cachedTypes != null) return _cachedTypes!;

    final manifestContent =
        await rootBundle.loadString('$templateBasePath/manifest.txt');

    final folderNames = manifestContent
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toList();

    _cachedTypes = folderNames.map((folderName) {
      return FilamentType(
        id: folderName,
        displayName: folderName,
        folderPath: '$templateBasePath/$folderName',
      );
    }).toList();

    return _cachedTypes!;
  }

  /// Get the asset path for a specific template file within a filament type folder
  String getTemplatePath(String filamentTypeId, String filename) {
    return '$templateBasePath/$filamentTypeId/$filename';
  }

  /// Clear cached types (useful for testing or hot reload)
  void clearCache() {
    _cachedTypes = null;
  }
}

/// Provider for FilamentTypeService
final filamentTypeServiceProvider = Provider<FilamentTypeService>((ref) {
  return FilamentTypeService();
});

/// Provider for available filament types (async)
final availableFilamentTypesProvider =
    FutureProvider<List<FilamentType>>((ref) async {
  final service = ref.watch(filamentTypeServiceProvider);
  return service.getAvailableTypes();
});
