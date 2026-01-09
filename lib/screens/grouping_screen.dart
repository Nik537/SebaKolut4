import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../services/image_cache_service.dart';
import '../services/filament_type_service.dart';
import '../widgets/log_viewer.dart';
import 'processing_screen.dart';

class GroupingScreen extends ConsumerStatefulWidget {
  const GroupingScreen({super.key});

  @override
  ConsumerState<GroupingScreen> createState() => _GroupingScreenState();
}

class _GroupingScreenState extends ConsumerState<GroupingScreen> {
  final FocusNode _gridFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Auto-focus the grid on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gridFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _gridFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyDown(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final ungroupedImages = ref.read(ungroupedImagesProvider);
    if (ungroupedImages.isEmpty) return KeyEventResult.ignored;

    final focusedId = ref.read(focusedImageIdProvider);
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

    // Initialize focus if null
    if (focusedId == null) {
      ref.read(focusedImageIdProvider.notifier).setFocus(ungroupedImages.first.id);
      return KeyEventResult.handled;
    }

    final currentIndex = ungroupedImages.indexWhere((img) => img.id == focusedId);
    if (currentIndex < 0) {
      ref.read(focusedImageIdProvider.notifier).setFocus(ungroupedImages.first.id);
      return KeyEventResult.handled;
    }

    // Space = select + advance
    if (event.logicalKey == LogicalKeyboardKey.space && !isShiftPressed) {
      final image = ungroupedImages[currentIndex];
      if (!image.isSelected) {
        ref.read(importedImagesProvider.notifier).toggleSelection(image.id);
      }
      // Advance to next
      if (currentIndex < ungroupedImages.length - 1) {
        ref.read(focusedImageIdProvider.notifier).setFocus(ungroupedImages[currentIndex + 1].id);
        _scrollToIndex(currentIndex + 1);
      }
      return KeyEventResult.handled;
    }

    // Shift+Space = deselect + go back
    if (event.logicalKey == LogicalKeyboardKey.space && isShiftPressed) {
      final image = ungroupedImages[currentIndex];
      if (image.isSelected) {
        ref.read(importedImagesProvider.notifier).toggleSelection(image.id);
      }
      // Move back
      if (currentIndex > 0) {
        ref.read(focusedImageIdProvider.notifier).setFocus(ungroupedImages[currentIndex - 1].id);
        _scrollToIndex(currentIndex - 1);
      }
      return KeyEventResult.handled;
    }

    // Enter = create group
    if (event.logicalKey == LogicalKeyboardKey.enter && !isShiftPressed) {
      final selected = ref.read(selectedImagesProvider);
      if (selected.isNotEmpty) {
        ref.read(groupsProvider.notifier).createGroupFromSelection();
        // Reset focus to first remaining image
        final remaining = ref.read(ungroupedImagesProvider);
        if (remaining.isNotEmpty) {
          ref.read(focusedImageIdProvider.notifier).setFocus(remaining.first.id);
          _scrollToIndex(0);
        } else {
          ref.read(focusedImageIdProvider.notifier).clearFocus();
        }
      }
      return KeyEventResult.handled;
    }

    // Shift+Enter = undo last group
    if (event.logicalKey == LogicalKeyboardKey.enter && isShiftPressed) {
      ref.read(groupsProvider.notifier).undoLastGroup();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _scrollToIndex(int index) {
    // Calculate scroll position for 4-column grid
    const crossAxisCount = 4;
    const itemHeight = 120.0; // Approximate item height with spacing
    final rowIndex = index ~/ crossAxisCount;
    final targetScroll = rowIndex * itemHeight;

    // Only scroll if needed
    if (!_scrollController.hasClients) return;
    final viewportHeight = _scrollController.position.viewportDimension;
    final currentScroll = _scrollController.offset;

    if (targetScroll < currentScroll || targetScroll > currentScroll + viewportHeight - itemHeight) {
      _scrollController.animateTo(
        targetScroll.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ungroupedImages = ref.watch(ungroupedImagesProvider);
    final selectedImages = ref.watch(selectedImagesProvider);
    final groups = ref.watch(groupsProvider);
    final allImages = ref.watch(importedImagesProvider);
    final focusedId = ref.watch(focusedImageIdProvider);

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
                                child: Focus(
                                  focusNode: _gridFocusNode,
                                  onKeyEvent: (node, event) => _handleKeyDown(event),
                                  child: GridView.builder(
                                    controller: _scrollController,
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 1,
                                    ),
                                    itemCount: ungroupedImages.length,
                                    itemBuilder: (context, index) {
                                      final image = ungroupedImages[index];
                                      return _SelectableThumbnail(
                                        image: image,
                                        isFocused: focusedId == image.id,
                                        onTap: () {
                                          ref.read(importedImagesProvider.notifier).toggleSelection(image.id);
                                          ref.read(focusedImageIdProvider.notifier).setFocus(image.id);
                                        },
                                      );
                                    },
                                  ),
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
                      onPressed: ref.watch(allGroupsReadyProvider)
                          ? () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const ProcessingScreen(),
                                ),
                              );
                            }
                          : null,
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
  final bool isFocused;
  final VoidCallback? onTap;

  const _SelectableThumbnail({
    required this.image,
    this.isFocused = false,
    this.onTap,
  });

  Border _getBorder(BuildContext context) {
    if (isFocused) {
      // Orange focus ring - distinct from blue selection
      return Border.all(color: Colors.orange, width: 4);
    } else if (image.isSelected) {
      return Border.all(
        color: Theme.of(context).colorScheme.primary,
        width: 3,
      );
    } else {
      return Border.all(color: Colors.grey.shade300, width: 1);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageCache = ref.read(imageCacheServiceProvider);
    final thumbnailBytes = imageCache.getThumbnail(image.id);

    return GestureDetector(
      onTap: onTap ?? () {
        ref.read(importedImagesProvider.notifier).toggleSelection(image.id);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: _getBorder(context),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: thumbnailBytes != null
                  ? Image.memory(
                      thumbnailBytes,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : const Center(child: Icon(Icons.image_not_supported)),
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

class _GroupCard extends ConsumerStatefulWidget {
  final ImageGroup group;
  final List<ImportedImage> allImages;

  const _GroupCard({required this.group, required this.allImages});

  @override
  ConsumerState<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends ConsumerState<_GroupCard> {
  late TextEditingController _nameController;
  late TextEditingController _skuController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _skuController = TextEditingController(text: widget.group.sku);
  }

  @override
  void didUpdateWidget(_GroupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.name != widget.group.name &&
        _nameController.text != widget.group.name) {
      _nameController.text = widget.group.name;
    }
    if (oldWidget.group.sku != widget.group.sku &&
        _skuController.text != widget.group.sku) {
      _skuController.text = widget.group.sku;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupImages = widget.allImages.where((img) => widget.group.imageIds.contains(img.id)).toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group name input field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: const OutlineInputBorder(),
                      hintText: 'Ime (npr. Refill PLA Silk Lila)',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      labelText: 'Ime',
                      labelStyle: const TextStyle(fontSize: 12),
                    ),
                    onChanged: (value) {
                      ref.read(groupsProvider.notifier).renameGroup(widget.group.id, value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.group.imageIds.length} img',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Filament type dropdown
            _buildFilamentTypeDropdown(context, ref),
            const SizedBox(height: 8),
            // SKU input field
            TextField(
              controller: _skuController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: const OutlineInputBorder(),
                hintText: 'SKU (npr. FLR171-4005)',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                labelText: 'SKU',
                labelStyle: const TextStyle(fontSize: 12),
              ),
              onChanged: (value) {
                ref.read(groupsProvider.notifier).updateSku(widget.group.id, value);
              },
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
                  final imageCache = ref.read(imageCacheServiceProvider);
                  final thumbnailBytes = imageCache.getThumbnail(image.id);
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: thumbnailBytes != null
                          ? Image.memory(
                              thumbnailBytes,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            )
                          : const SizedBox(
                              width: 50,
                              height: 50,
                              child: Icon(Icons.image_not_supported, size: 24),
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

  Widget _buildFilamentTypeDropdown(BuildContext context, WidgetRef ref) {
    final filamentTypesAsync = ref.watch(availableFilamentTypesProvider);

    return filamentTypesAsync.when(
      data: (filamentTypes) => DropdownButtonFormField<String>(
        initialValue: widget.group.filamentType,
        isExpanded: true,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: const OutlineInputBorder(),
          labelText: 'Filament Type *',
          labelStyle: const TextStyle(fontSize: 12),
          hintText: 'Select filament type',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          errorText: widget.group.filamentType == null ? 'Required' : null,
          errorStyle: const TextStyle(fontSize: 10),
        ),
        items: filamentTypes.map((type) {
          return DropdownMenuItem<String>(
            value: type.id,
            child: Text(type.displayName, style: const TextStyle(fontSize: 13)),
          );
        }).toList(),
        onChanged: (value) {
          ref.read(groupsProvider.notifier).updateFilamentType(
                widget.group.id,
                value,
              );
        },
      ),
      loading: () => const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (err, stack) => Text(
        'Error loading filament types: $err',
        style: const TextStyle(color: Colors.red, fontSize: 12),
      ),
    );
  }
}
