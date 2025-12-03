import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../providers/providers.dart';
import '../services/file_service.dart';
import 'grouping_screen.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final images = ref.watch(importedImagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Filament Images'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Drop Zone / Import Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: images.isEmpty
                  ? _buildDropZone()
                  : _buildImageGrid(images),
            ),
          ),
          // Bottom Actions
          _buildBottomBar(images),
        ],
      ),
    );
  }

  Widget _buildDropZone() {
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) async {
        setState(() => _isDragging = false);

        // Read bytes from files
        final processedItems = <DroppedFileItem>[];
        for (final file in details.files) {
          final bytes = await file.readAsBytes();
          processedItems.add(DroppedFileItem(name: file.name, bytes: bytes));
        }

        await ref.read(importedImagesProvider.notifier).addDroppedFiles(processedItems);
      },
      child: GestureDetector(
        onTap: () => ref.read(importedImagesProvider.notifier).pickAndAddImages(),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _isDragging
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade400,
              width: _isDragging ? 3 : 2,
              strokeAlign: BorderSide.strokeAlignCenter,
            ),
            borderRadius: BorderRadius.circular(16),
            color: _isDragging
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Colors.grey.shade100,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 80,
                  color: _isDragging
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade600,
                ),
                const SizedBox(height: 16),
                Text(
                  'Drag & drop images here',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'or click to select files',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => ref.read(importedImagesProvider.notifier).pickAndAddImages(),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Select Files'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageGrid(List images) {
    return Column(
      children: [
        // Add more images button
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => ref.read(importedImagesProvider.notifier).pickAndAddImages(),
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Add More'),
            ),
            const SizedBox(width: 16),
            Text(
              '${images.length} image${images.length == 1 ? '' : 's'} imported',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Image Grid with drop support
        Expanded(
          child: DropTarget(
            onDragEntered: (_) => setState(() => _isDragging = true),
            onDragExited: (_) => setState(() => _isDragging = false),
            onDragDone: (details) async {
              setState(() => _isDragging = false);
              final processedItems = <DroppedFileItem>[];
              for (final file in details.files) {
                final bytes = await file.readAsBytes();
                processedItems.add(DroppedFileItem(name: file.name, bytes: bytes));
              }
              await ref.read(importedImagesProvider.notifier).addDroppedFiles(processedItems);
            },
            child: Container(
              decoration: BoxDecoration(
                border: _isDragging
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      )
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: images.length,
                itemBuilder: (context, index) {
                  final image = images[index];
                  return _buildImageThumbnail(image);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageThumbnail(image) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.memory(
              image.thumbnailBytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
        // Remove button
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => ref.read(importedImagesProvider.notifier).removeImage(image.id),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
        // Filename
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: const BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(7),
                bottomRight: Radius.circular(7),
              ),
            ),
            child: Text(
              image.filename,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(List images) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (images.isNotEmpty)
            TextButton(
              onPressed: () {
                ref.read(importedImagesProvider.notifier).reset();
              },
              child: const Text('Clear All'),
            ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: images.isEmpty
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const GroupingScreen(),
                      ),
                    );
                  },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Next: Create Groups'),
          ),
        ],
      ),
    );
  }
}
