import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/undo_redo_provider.dart';

/// A widget that displays undo and redo buttons for the AppBar.
///
/// The buttons are automatically enabled/disabled based on whether
/// undo/redo operations are available in the history stack.
class UndoRedoButtons extends ConsumerWidget {
  const UndoRedoButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canUndo = ref.watch(canUndoProvider);
    final canRedo = ref.watch(canRedoProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.undo),
          tooltip: 'Undo (Ctrl+Z)',
          onPressed: canUndo
              ? () {
                  ref.read(undoRedoProvider.notifier).undo();
                }
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.redo),
          tooltip: 'Redo (Ctrl+Shift+Z)',
          onPressed: canRedo
              ? () {
                  ref.read(undoRedoProvider.notifier).redo();
                }
              : null,
        ),
      ],
    );
  }
}
