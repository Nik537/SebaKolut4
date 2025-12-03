import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/log_viewer.dart';
import 'processing_screen.dart';

class GroupingScreen extends ConsumerWidget {
  const GroupingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ungroupedImages = ref.watch(ungroupedImagesProvider);
    final selectedImages = ref.watch(selectedImagesProvider);
    final groups = ref.watch(groupsProvider);
    final allImages = ref.watch(importedImagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Groups'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: const [
          LogViewerButton(),
        ],
      ),
      body: Row(
        children: [
          // Main content - image selection
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // Selection info bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade100,
                  child: Row(
                    children: [
                      Text(
                        '${selectedImages.length} selected',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (selectedImages.isNotEmpty) ...[
                        TextButton(
                          onPressed: () {
                            ref.read(importedImagesProvider.notifier).clearSelections();
                          },
                          child: const Text('Clear Selection'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            ref.read(groupsProvider.notifier).createGroupFromSelection();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Group'),
                        ),
                      ],
                    ],
                  ),
                ),
                // Ungrouped images grid
                Expanded(
                  child: ungroupedImages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 64,
                                color: Colors.green.shade400,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'All images have been grouped!',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Click "Done" to continue',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select images to create a group (${ungroupedImages.length} remaining)',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: GridView.builder(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 1,
                                  ),
                                  itemCount: ungroupedImages.length,
                                  itemBuilder: (context, index) {
                                    final image = ungroupedImages[index];
                                    return _SelectableThumbnail(image: image);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          // Sidebar - groups list
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                left: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Groups (${groups.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: groups.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'No groups yet.\nSelect images and click "Create Group"',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: groups.length,
                          itemBuilder: (context, index) {
                            final group = groups[index];
                            return _GroupCard(
                              group: group,
                              allImages: allImages,
                            );
                          },
                        ),
                ),
                const Divider(height: 1),
                // Done button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: groups.isEmpty
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const ProcessingScreen(),
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Done - Process Groups',
                        style: TextStyle(fontSize: 16),
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

class _SelectableThumbnail extends ConsumerWidget {
  final ImportedImage image;

  const _SelectableThumbnail({required this.image});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(importedImagesProvider.notifier).toggleSelection(image.id);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: image.isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: image.isSelected ? 3 : 1,
          ),
        ),
        child: Stack(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                image.thumbnailBytes,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            // Checkbox
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: image.isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: image.isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: image.isSelected
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : null,
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
                    bottomLeft: Radius.circular(6),
                    bottomRight: Radius.circular(6),
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
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final ImageGroup group;
  final List<ImportedImage> allImages;

  const _GroupCard({required this.group, required this.allImages});

  @override
  Widget build(BuildContext context) {
    final groupImages = allImages.where((img) => group.imageIds.contains(img.id)).toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  group.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  '${group.imageIds.length} images',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Mini thumbnails preview
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: groupImages.length.clamp(0, 5),
                itemBuilder: (context, index) {
                  final image = groupImages[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.memory(
                        image.thumbnailBytes,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (groupImages.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${groupImages.length - 5} more',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
