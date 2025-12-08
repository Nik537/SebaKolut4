import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
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
    final colorizedImages = ref.watch(selectedColorizedImagesProvider);
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
                    'Export',
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
                        // Export info
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Two files per image:\n[hex]_white.webp\n[hex]_transparent.webp',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${colorizedImages.length * 2} files will be exported',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const Spacer(),
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
}

class _ExportPreviewCard extends ConsumerWidget {
  final dynamic image;
  final String groupName;

  const _ExportPreviewCard({
    required this.image,
    required this.groupName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hexClean = image.appliedHex.replaceAll('#', '');

    // Use adjusted image bytes for the specific generation
    final adjustedBytesAsync = ref.watch(adjustedImageByGenerationProvider((
      groupId: image.groupId,
      generationIndex: image.generationIndex,
    )));

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              child: adjustedBytesAsync.when(
                data: (bytes) => bytes != null
                    ? Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                    : Image.memory(
                        image.bytes,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Image.memory(
                  image.bytes,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
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
                  '${hexClean}_white.webp',
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
