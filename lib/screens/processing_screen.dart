import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import 'export_screen.dart';

class ProcessingScreen extends ConsumerStatefulWidget {
  const ProcessingScreen({super.key});

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _processingStarted = false;

  @override
  void initState() {
    super.initState();
    final groups = ref.read(groupsProvider);
    _tabController = TabController(length: groups.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _startProcessing() {
    setState(() => _processingStarted = true);
    ref.read(processingControllerProvider).processAllGroups();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider);
    final isProcessing = ref.watch(isProcessingProvider);
    final processingComplete = ref.watch(processingCompleteProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: groups.length > 1
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: groups.map((g) => Tab(text: g.name)).toList(),
              )
            : null,
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            padding: const EdgeInsets.all(16),
            color: _getStatusColor(isProcessing, processingComplete),
            child: Row(
              children: [
                if (isProcessing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else if (processingComplete)
                  const Icon(Icons.check_circle, color: Colors.white)
                else
                  const Icon(Icons.pending, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  _getStatusText(isProcessing, processingComplete, _processingStarted),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                if (!_processingStarted)
                  ElevatedButton(
                    onPressed: _startProcessing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    child: const Text('Start Processing'),
                  ),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: groups.length > 1
                ? TabBarView(
                    controller: _tabController,
                    children: groups.map((g) => _GroupProcessingView(group: g)).toList(),
                  )
                : groups.isNotEmpty
                    ? _GroupProcessingView(group: groups.first)
                    : const Center(child: Text('No groups to process')),
          ),
          // Bottom action bar
          if (processingComplete)
            Container(
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
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ExportScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Export All'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(bool isProcessing, bool processingComplete) {
    if (processingComplete) return Colors.green;
    if (isProcessing) return Colors.blue;
    return Colors.orange;
  }

  String _getStatusText(bool isProcessing, bool processingComplete, bool started) {
    if (processingComplete) return 'Processing complete!';
    if (isProcessing) return 'Processing images...';
    if (!started) return 'Ready to process';
    return 'Waiting...';
  }
}

class _GroupProcessingView extends ConsumerWidget {
  final ImageGroup group;

  const _GroupProcessingView({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allImages = ref.watch(importedImagesProvider);
    final processingStates = ref.watch(imageProcessingStateProvider);
    final colorizedImages = ref.watch(colorizedImagesByGroupProvider(group.id));

    final groupImages = allImages.where((img) => group.imageIds.contains(img.id)).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.65,
        ),
        itemCount: groupImages.length,
        itemBuilder: (context, index) {
          final image = groupImages[index];
          final state = processingStates[image.id];
          final colorizedImage = colorizedImages.firstWhere(
            (c) => c.sourceImageId == image.id,
            orElse: () => ColorizedImage(
              id: '',
              sourceImageId: '',
              groupId: '',
              appliedHex: '',
              bytes: image.bytes,
              createdAt: DateTime.now(),
            ),
          );

          return _ProcessingCard(
            image: image,
            state: state,
            colorizedImage: colorizedImage.id.isNotEmpty ? colorizedImage : null,
          );
        },
      ),
    );
  }
}

class _ProcessingCard extends StatelessWidget {
  final ImportedImage image;
  final ImageProcessingState? state;
  final ColorizedImage? colorizedImage;

  const _ProcessingCard({
    required this.image,
    this.state,
    this.colorizedImage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Original image thumbnail
            Text(
              'Original',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(
                  image.thumbnailBytes,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Status and extracted color
            _buildStatusSection(context),
            const SizedBox(height: 8),
            // Result image
            Text(
              'Result',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: colorizedImage != null
                    ? Image.memory(
                        colorizedImage!.bytes,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                    : Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          child: state?.isProcessing == true
                              ? const CircularProgressIndicator()
                              : Icon(
                                  Icons.image_outlined,
                                  color: Colors.grey.shade400,
                                  size: 32,
                                ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(BuildContext context) {
    if (state == null) {
      return _buildStatusRow(
        context,
        icon: Icons.pending,
        color: Colors.grey,
        text: 'Waiting...',
      );
    }

    switch (state!.status) {
      case ProcessingStatus.pending:
        return _buildStatusRow(
          context,
          icon: Icons.pending,
          color: Colors.grey,
          text: 'Pending',
        );
      case ProcessingStatus.extractingColor:
        return _buildStatusRow(
          context,
          icon: Icons.colorize,
          color: Colors.blue,
          text: 'Extracting color...',
          showProgress: true,
        );
      case ProcessingStatus.colorExtracted:
      case ProcessingStatus.colorizing:
        return Column(
          children: [
            _buildColorPreview(state!.extractedHex!),
            const SizedBox(height: 4),
            _buildStatusRow(
              context,
              icon: Icons.brush,
              color: Colors.orange,
              text: 'Colorizing...',
              showProgress: true,
            ),
          ],
        );
      case ProcessingStatus.completed:
        return _buildColorPreview(state!.extractedHex!);
      case ProcessingStatus.error:
        return _buildStatusRow(
          context,
          icon: Icons.error,
          color: Colors.red,
          text: 'Error',
        );
    }
  }

  Widget _buildStatusRow(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String text,
    bool showProgress = false,
  }) {
    return Row(
      children: [
        if (showProgress)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: color,
            ),
          )
        else
          Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildColorPreview(String hexColor) {
    final color = _hexToColor(hexColor);
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade400),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          hexColor,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Color _hexToColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }
}
