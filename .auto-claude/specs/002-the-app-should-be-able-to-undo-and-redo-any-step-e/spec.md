# Specification: Undo/Redo System with Cancellable Export

## Overview

Implement a comprehensive undo/redo system for the Filament Colorizer Flutter application that allows users to reverse and replay any operation except export. All state mutations across imported images, groups, colorized images, and image adjustments should be undoable. Export operations (file writing) should be excluded from undo/redo history but must be cancellable during execution to allow users to abort an ongoing export.

## Workflow Type

**Type**: feature

**Rationale**: This is a significant new feature addition requiring architectural changes to multiple providers. It introduces a new state management pattern (undo/redo stack) and affects the core user workflow across the entire application. Not a refactor (existing functionality remains), not a bug fix (no bug being addressed), and not a migration.

## Task Scope

### Services Involved
- **filament_colorizer** (primary) - Single-service Flutter application

### This Task Will:
- [ ] Create an undo/redo state management system using Riverpod
- [ ] Wrap all existing StateNotifier providers with undo/redo capability
- [ ] Add keyboard shortcuts (Ctrl+Z / Cmd+Z, Ctrl+Shift+Z / Cmd+Shift+Z)
- [ ] Add UI controls for undo/redo operations
- [ ] Implement cancellation mechanism for export operations
- [ ] Exclude export operations from undo/redo history
- [ ] Add history size limit to prevent memory issues

### Out of Scope:
- Persisting undo/redo history across app restarts
- Undo/redo for AI processing operations (Gemini calls)
- Undo/redo for file I/O operations (import, export)
- Granular per-character undo in text fields (use Flutter's built-in)

## Service Context

### Filament Colorizer (Flutter App)

**Tech Stack:**
- Language: Dart
- Framework: Flutter (SDK ^3.7.2)
- State Management: Riverpod (flutter_riverpod ^2.6.1)
- Key directories: `lib/providers/`, `lib/models/`, `lib/services/`, `lib/screens/`

**Entry Point:** `lib/main.dart`

**How to Run:**
```bash
flutter pub get
flutter run
```

**Platforms:** Windows, macOS, Android, iOS, Web

## Files to Modify

| File | Service | What to Change |
|------|---------|---------------|
| `lib/providers/images_provider.dart` | app | Add undo/redo support to ImportedImagesNotifier |
| `lib/providers/groups_provider.dart` | app | Add undo/redo support to GroupsNotifier |
| `lib/providers/processing_provider.dart` | app | Add undo/redo support to ColorizedImagesNotifier, ImageAdjustmentsNotifier, AllSelectedGenerationsNotifier |
| `lib/providers/export_provider.dart` | app | Add export cancellation mechanism |
| `lib/services/export_service.dart` | app | Add cancellation checks during export |
| `lib/main.dart` | app | Add keyboard shortcut handlers for undo/redo |
| `lib/screens/import_screen.dart` | app | Add undo/redo buttons to AppBar |
| `lib/screens/grouping_screen.dart` | app | Add undo/redo buttons to AppBar |
| `lib/screens/processing_screen.dart` | app | Add undo/redo buttons to AppBar |
| `lib/screens/export_screen.dart` | app | Add cancel button and undo/redo buttons |
| `pubspec.yaml` | app | Add `async` package dependency for CancelableOperation |

## Files to Create

| File | Purpose |
|------|---------|
| `lib/providers/undo_redo_provider.dart` | Central undo/redo state management |
| `lib/models/app_state_snapshot.dart` | Immutable snapshot of all undoable state |
| `lib/widgets/undo_redo_buttons.dart` | Reusable undo/redo UI widget |

## Files to Reference

These files show patterns to follow:

| File | Pattern to Copy |
|------|----------------|
| `lib/providers/images_provider.dart` | StateNotifierProvider pattern, immutable state updates |
| `lib/providers/groups_provider.dart` | Ref usage for cross-provider communication |
| `lib/models/imported_image.dart` | Immutable model with copyWith, equality operators |
| `lib/providers/export_provider.dart` | Async operation handling with try/catch |
| `lib/screens/export_screen.dart` | Export button state management pattern |

## Patterns to Follow

### StateNotifier State Updates Pattern

From `lib/providers/images_provider.dart`:

```dart
class ImportedImagesNotifier extends StateNotifier<List<ImportedImage>> {
  // ...
  void removeImage(String id) {
    _imageCache.removeImportedImage(id);
    state = state.where((img) => img.id != id).toList();
  }

  void toggleSelection(String id) {
    state = state.map((img) {
      if (img.id == id && !img.isGrouped) {
        return img.copyWith(isSelected: !img.isSelected);
      }
      return img;
    }).toList();
  }
}
```

**Key Points:**
- Always create new list/map instances (immutability)
- Use `copyWith` for partial updates
- State updates are synchronous

### Immutable Model Pattern

From `lib/models/image_group.dart`:

```dart
class ImageGroup {
  final String id;
  final String name;
  final String sku;
  final List<String> imageIds;
  final DateTime createdAt;

  const ImageGroup({
    required this.id,
    required this.name,
    this.sku = '',
    required this.imageIds,
    required this.createdAt,
  });

  ImageGroup copyWith({/*...*/}) {
    return ImageGroup(/*...*/);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImageGroup && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
```

**Key Points:**
- All fields are `final`
- `const` constructor
- `copyWith` method for updates
- Override `==` and `hashCode`

### Export Async Pattern

From `lib/providers/export_provider.dart`:

```dart
Future<void> exportAll({String? directory}) async {
  // ... async operations
  await exportService.exportDualBackground(images: exportData, directory: directory);
}
```

**Key Points:**
- Export is async Future-based
- Uses Ref to read providers
- No state updates during export

## Requirements

### Functional Requirements

1. **Undo/Redo State Management**
   - Description: Create a central undo/redo provider that maintains history stacks
   - Acceptance: Can undo/redo operations, history limited to 50 states

2. **Undoable Image Operations**
   - Description: Image import, removal, selection, and grouping should be undoable
   - Acceptance: Ctrl+Z undoes last image operation, Ctrl+Shift+Z redoes

3. **Undoable Group Operations**
   - Description: Group creation, renaming, SKU update, and deletion should be undoable
   - Acceptance: All group mutations can be reversed

4. **Undoable Processing Operations**
   - Description: Colorized image additions, generation selection, and adjustments (hue/saturation/brightness/contrast/sharpness) should be undoable
   - Acceptance: All processing state changes can be reversed

5. **Export Exclusion**
   - Description: Export operations must NOT be added to undo history
   - Acceptance: Undo after export reverses the operation BEFORE the export

6. **Export Cancellation**
   - Description: Allow users to cancel an ongoing export operation
   - Acceptance: Cancel button visible during export, cancellation stops file writing

7. **Keyboard Shortcuts**
   - Description: Standard keyboard shortcuts for undo/redo
   - Acceptance: Ctrl+Z (Cmd+Z on Mac) for undo, Ctrl+Shift+Z (Cmd+Shift+Z) for redo

8. **UI Controls**
   - Description: Visual undo/redo buttons in the app bar
   - Acceptance: Buttons disabled when history is empty, enabled when available

### Edge Cases

1. **Empty History** - Undo/redo buttons disabled, operations are no-ops
2. **Cache Synchronization** - When undoing image removal, image bytes may need re-fetching
3. **Cross-Provider Dependencies** - Groups depend on images; undo must maintain consistency
4. **Export Interruption** - Partial files should be cleaned up on cancel
5. **Memory Pressure** - Large images in history; limit to 50 states + consider shallow snapshots
6. **Rapid Undo/Redo** - Debounce rapid operations to prevent race conditions

## Implementation Notes

### Architecture Decision: Centralized Snapshot Approach

Instead of modifying each StateNotifier individually, use a **centralized AppState snapshot approach**:

```dart
// AppStateSnapshot contains all undoable state
class AppStateSnapshot {
  final List<ImportedImage> images;
  final List<ImageGroup> groups;
  final List<ColorizedImage> colorizedImages;
  final Map<String, ImageAdjustments> adjustments;
  final Map<String, int> selectedGenerations;

  const AppStateSnapshot({...});
}

// UndoRedoNotifier manages the history stacks
class UndoRedoNotifier extends StateNotifier<UndoRedoState> {
  final Ref _ref;
  final List<AppStateSnapshot> _history = [];
  final List<AppStateSnapshot> _future = [];

  void captureState() { /* Push current state to history */ }
  void undo() { /* Restore previous state */ }
  void redo() { /* Restore next state */ }
}
```

### DO
- Capture state BEFORE mutations (for proper undo)
- Use deep copy for snapshot to avoid reference issues
- Keep binary data (image bytes) in ImageCacheService, only snapshot metadata
- Provide `canUndo` and `canRedo` boolean getters for UI
- Add package `async: ^2.11.0` for CancelableOperation

### DON'T
- Don't store Uint8List bytes in undo history (memory explosion)
- Don't make export operations undoable (file system side effects)
- Don't modify existing StateNotifier internals; wrap with snapshot capture
- Don't undo AI processing (Gemini API calls are not reversible)

### Export Cancellation Implementation

```dart
class CancellableExportController {
  CancelableOperation<void>? _currentExport;
  bool _isCancelled = false;

  Future<void> startExport({...}) async {
    _isCancelled = false;
    _currentExport = CancelableOperation.fromFuture(
      _doExport(),
      onCancel: () => _isCancelled = true,
    );
    await _currentExport!.value;
  }

  void cancelExport() {
    _isCancelled = true;
    _currentExport?.cancel();
  }

  Future<void> _doExport() async {
    for (final item in items) {
      if (_isCancelled) {
        _cleanupPartialExport();
        throw ExportCancelledException();
      }
      await _exportSingleItem(item);
    }
  }
}
```

## Development Environment

### Start Services

```bash
# Install dependencies
flutter pub get

# Run app in development mode
flutter run

# Run app on specific platform
flutter run -d windows
flutter run -d macos
flutter run -d chrome
```

### Service URLs
- N/A (desktop/mobile application, not web service)

### Required Environment Variables
- `GEMINI_API_KEY`: Google Gemini API key (in `.env` file)

## Success Criteria

The task is complete when:

1. [ ] Undo/redo provider created with history stacks
2. [ ] All image operations (add, remove, select, group) are undoable
3. [ ] All group operations (create, rename, update SKU, delete) are undoable
4. [ ] All adjustment operations (hue, saturation, brightness, contrast, sharpness) are undoable
5. [ ] Generation selection is undoable
6. [ ] Export operations are NOT in undo history
7. [ ] Export can be cancelled mid-operation
8. [ ] Keyboard shortcuts work (Ctrl+Z, Ctrl+Shift+Z)
9. [ ] UI buttons show correct enabled/disabled state
10. [ ] History limited to 50 states
11. [ ] No console errors
12. [ ] Existing tests still pass
13. [ ] New functionality verified via manual testing

## QA Acceptance Criteria

**CRITICAL**: These criteria must be verified by the QA Agent before sign-off.

### Unit Tests
| Test | File | What to Verify |
|------|------|----------------|
| UndoRedoNotifier - initial state | `test/providers/undo_redo_provider_test.dart` | canUndo=false, canRedo=false initially |
| UndoRedoNotifier - capture state | `test/providers/undo_redo_provider_test.dart` | State captured, canUndo becomes true |
| UndoRedoNotifier - undo | `test/providers/undo_redo_provider_test.dart` | State restored, canRedo becomes true |
| UndoRedoNotifier - redo | `test/providers/undo_redo_provider_test.dart` | Future state restored |
| UndoRedoNotifier - history limit | `test/providers/undo_redo_provider_test.dart` | History truncated at 50 states |
| AppStateSnapshot - equality | `test/models/app_state_snapshot_test.dart` | Deep equality comparison works |
| Export cancellation | `test/providers/export_provider_test.dart` | Cancel stops export, cleanup called |

### Integration Tests
| Test | Services | What to Verify |
|------|----------|----------------|
| Undo image removal | UndoRedoProvider ↔ ImagesProvider | Removed image reappears after undo |
| Undo group creation | UndoRedoProvider ↔ GroupsProvider ↔ ImagesProvider | Group removed, images unmarked as grouped |
| Undo adjustment | UndoRedoProvider ↔ ProcessingProvider | Slider values restored |
| Export excluded from history | UndoRedoProvider ↔ ExportProvider | Undo after export skips to pre-export state |
| Cross-provider consistency | All providers | State remains consistent after undo/redo |

### End-to-End Tests
| Flow | Steps | Expected Outcome |
|------|-------|------------------|
| Full undo/redo cycle | 1. Import image 2. Create group 3. Undo 4. Redo 5. Undo 6. Undo | All states correctly restored |
| Keyboard shortcuts | 1. Import image 2. Press Ctrl+Z 3. Press Ctrl+Shift+Z | Image removed then reappears |
| Export cancellation | 1. Start export 2. Click cancel 3. Verify no partial files | Export stopped, no files created |
| History overflow | 1. Perform 60 operations 2. Undo 50 times 3. Try undo again | Only 50 undos available |

### Browser Verification (if frontend)
| Page/Component | URL | Checks |
|----------------|-----|--------|
| Import Screen | App launch | Undo/redo buttons visible, initially disabled |
| Grouping Screen | After import | Buttons enabled after operations |
| Processing Screen | After grouping | Adjustment undo works |
| Export Screen | After processing | Cancel button visible during export |

### Database Verification (if applicable)
N/A - No database in this application

### QA Sign-off Requirements
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] All E2E tests pass (manual verification acceptable)
- [ ] Browser/desktop verification complete
- [ ] No regressions in existing functionality (import, group, process, export still work)
- [ ] Code follows established Riverpod patterns
- [ ] No memory leaks from undo history (verified with DevTools)
- [ ] No security vulnerabilities introduced
- [ ] Keyboard shortcuts work on both Windows/Mac
