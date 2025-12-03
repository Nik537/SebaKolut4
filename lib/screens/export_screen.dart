import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../services/export_service.dart';
import '../widgets/log_viewer.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _isExporting = false;

  Future<void> _exportAll() async {
    setState(() => _isExporting = true);
    try {
      await ref.read(exportControllerProvider).exportAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export complete!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorizedImages = ref.watch(colorizedImagesProvider);
    final exportSettings = ref.watch(exportSettingsProvider);
    final groups = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Images'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: const [
          LogViewerButton(),
        ],
      ),
      body: Row(
        children: [
          // Preview grid
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${colorizedImages.length} colorized images ready to export',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: colorizedImages.length,
                      itemBuilder: (context, index) {
                        final image = colorizedImages[index];
                        final group = groups.firstWhere(
                          (g) => g.id == image.groupId,
                          orElse: () => groups.first,
                        );
                        return _ExportPreviewCard(
                          image: image,
                          groupName: group.name,
                          index: index,
                          format: exportSettings.format,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Export settings sidebar
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                left: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Export Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Format selection
                        const Text(
                          'Format',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FormatOption(
                          format: ExportFormat.png,
                          label: 'PNG',
                          description: 'Lossless, best quality',
                          selected: exportSettings.format == ExportFormat.png,
                          onSelect: () {
                            ref.read(exportSettingsProvider.notifier).setFormat(ExportFormat.png);
                          },
                        ),
                        const SizedBox(height: 8),
                        _FormatOption(
                          format: ExportFormat.jpeg,
                          label: 'JPEG',
                          description: 'Smaller file size',
                          selected: exportSettings.format == ExportFormat.jpeg,
                          onSelect: () {
                            ref.read(exportSettingsProvider.notifier).setFormat(ExportFormat.jpeg);
                          },
                        ),
                        const SizedBox(height: 8),
                        _FormatOption(
                          format: ExportFormat.webp,
                          label: 'WebP',
                          description: 'Modern format, good compression',
                          selected: exportSettings.format == ExportFormat.webp,
                          onSelect: () {
                            ref.read(exportSettingsProvider.notifier).setFormat(ExportFormat.webp);
                          },
                        ),
                        const SizedBox(height: 24),
                        // Quality slider (for JPEG/WebP)
                        if (exportSettings.format != ExportFormat.png) ...[
                          const Text(
                            'Quality',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Slider(
                                  value: exportSettings.quality.toDouble(),
                                  min: 10,
                                  max: 100,
                                  divisions: 9,
                                  label: '${exportSettings.quality}%',
                                  onChanged: (value) {
                                    ref.read(exportSettingsProvider.notifier).setQuality(value.toInt());
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 50,
                                child: Text(
                                  '${exportSettings.quality}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Spacer(),
                        // Export info
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Files will be named:\nfilament_[hex]_001.${_getExtension(exportSettings.format)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                // Export button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isExporting || colorizedImages.isEmpty
                          ? null
                          : _exportAll,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download),
                      label: Text(_isExporting ? 'Exporting...' : 'Export All'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getExtension(ExportFormat format) {
    switch (format) {
      case ExportFormat.png:
        return 'png';
      case ExportFormat.jpeg:
        return 'jpg';
      case ExportFormat.webp:
        return 'webp';
    }
  }
}

class _FormatOption extends StatelessWidget {
  final ExportFormat format;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onSelect;

  const _FormatOption({
    required this.format,
    required this.label,
    required this.description,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
              : Colors.white,
        ),
        child: Row(
          children: [
            Radio<ExportFormat>(
              value: format,
              groupValue: selected ? format : null,
              onChanged: (_) => onSelect(),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.black87,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportPreviewCard extends StatelessWidget {
  final dynamic image;
  final String groupName;
  final int index;
  final ExportFormat format;

  const _ExportPreviewCard({
    required this.image,
    required this.groupName,
    required this.index,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final hexClean = image.appliedHex.replaceAll('#', '');
    final extension = format == ExportFormat.jpeg ? 'jpg' : format.name;
    final filename = 'filament_${hexClean}_${index.toString().padLeft(3, '0')}.$extension';

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              child: Image.memory(
                image.bytes,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _hexToColor(image.appliedHex),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      image.appliedHex,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  filename,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  groupName,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _hexToColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }
}
