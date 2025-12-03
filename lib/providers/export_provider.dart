import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/export_service.dart';
import 'processing_provider.dart';

final exportServiceProvider = Provider<ExportService>((ref) => ExportService());

// Export settings state
class ExportSettings {
  final ExportFormat format;
  final int quality;

  const ExportSettings({
    this.format = ExportFormat.png,
    this.quality = 90,
  });

  ExportSettings copyWith({
    ExportFormat? format,
    int? quality,
  }) {
    return ExportSettings(
      format: format ?? this.format,
      quality: quality ?? this.quality,
    );
  }
}

final exportSettingsProvider =
    StateNotifierProvider<ExportSettingsNotifier, ExportSettings>((ref) {
  return ExportSettingsNotifier();
});

class ExportSettingsNotifier extends StateNotifier<ExportSettings> {
  ExportSettingsNotifier() : super(const ExportSettings());

  void setFormat(ExportFormat format) {
    state = state.copyWith(format: format);
  }

  void setQuality(int quality) {
    state = state.copyWith(quality: quality);
  }
}

// Export controller
final exportControllerProvider = Provider<ExportController>((ref) {
  return ExportController(ref);
});

class ExportController {
  final Ref _ref;

  ExportController(this._ref);

  Future<void> exportAll() async {
    final colorizedImages = _ref.read(colorizedImagesProvider);
    final settings = _ref.read(exportSettingsProvider);
    final exportService = _ref.read(exportServiceProvider);

    await exportService.saveAllToDirectory(
      images: colorizedImages,
      format: settings.format,
      quality: settings.quality,
    );
  }

  Future<void> exportGroup(String groupId) async {
    final colorizedImages = _ref.read(colorizedImagesByGroupProvider(groupId));
    final settings = _ref.read(exportSettingsProvider);
    final exportService = _ref.read(exportServiceProvider);

    await exportService.saveAllToDirectory(
      images: colorizedImages,
      format: settings.format,
      quality: settings.quality,
    );
  }
}
