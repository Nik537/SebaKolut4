# Specification: Keyboard-Driven Photo Selection with Export Destination Prompt

## Overview

This feature adds a keyboard-driven photo selection workflow to the GroupingScreen, enabling rapid sequential photo selection for creating groups. Users will be able to use keyboard shortcuts (Space, Shift+Space, Enter, Shift+Enter) to select/deselect photos and create/undo groups efficiently. Additionally, the export destination will be prompted at the beginning of the grouping workflow rather than at the end during export.

## Workflow Type

**Type**: feature

**Rationale**: This task adds new functionality (keyboard navigation and early export destination selection) to an existing screen without changing the underlying architecture. It enhances user workflow efficiency by enabling keyboard-driven operation.

## Task Scope

### Services Involved
- **grouping_screen.dart** (primary) - Add keyboard event handling, cursor position tracking, and export destination dialog
- **groups_provider.dart** (integration) - Add undo group creation functionality
- **images_provider.dart** (integration) - Add cursor-based select/deselect methods

### This Task Will:
- [ ] Prompt user for export destination when first entering the GroupingScreen
- [ ] Add keyboard shortcut: Space to select current photo and auto-advance to next
- [ ] Add keyboard shortcut: Shift+Space to deselect current photo and auto-move backward
- [ ] Add keyboard shortcut: Enter to quickly create group from selected photos
- [ ] Add keyboard shortcut: Shift+Enter to undo the last group creation
- [ ] Add visual cursor indicator showing currently focused photo
- [ ] Store export directory path for later use during actual export

### Out of Scope:
- Modifying the export process itself (the directory is already passed to export functions)
- Changing the image import workflow
- Modifying the processing screen or AI color extraction
- Touch/gesture-based navigation (this is keyboard-only)

## Service Context

### Flutter App - Filament Colorizer

**Tech Stack:**
- Language: Dart (SDK ^3.7.2)
- Framework: Flutter with Material Design 3
- State Management: Riverpod (`flutter_riverpod`)
- Key directories: `lib/screens/`, `lib/providers/`, `lib/models/`

**Entry Point:** `lib/main.dart`

**How to Run:**
```bash
flutter run
```

**Port:** N/A (native app)

## Files to Modify

| File | Service | What to Change |
|------|---------|---------------|
| `lib/screens/grouping_screen.dart` | UI | Add Focus widget, keyboard event handler, cursor state, export destination dialog, visual cursor indicator |
| `lib/providers/groups_provider.dart` | State | Add `undoLastGroup()` method, track last created group for undo functionality |
| `lib/providers/images_provider.dart` | State | Add `selectImageAt(int index)`, `deselectImageAt(int index)`, `markAsUngrouped(List<String> ids)` methods |
| `lib/providers/export_provider.dart` | State | Add `exportDirectoryProvider` StateProvider to store the selected export path |

## Files to Reference

These files show patterns to follow:

| File | Pattern to Copy |
|------|----------------|
| `lib/screens/import_screen.dart` | ConsumerStatefulWidget pattern, Scaffold structure, dialog handling |
| `lib/providers/images_provider.dart` | StateNotifier pattern, list state manipulation methods |
| `lib/services/export_service.dart` | `getExportDirectory()` method for directory picker dialog |

## Patterns to Follow

### StateNotifier Pattern

From `lib/providers/groups_provider.dart`:

```dart
class GroupsNotifier extends StateNotifier<List<ImageGroup>> {
  final Ref _ref;
  final _uuid = const Uuid();

  GroupsNotifier(this._ref) : super([]);

  void createGroupFromSelection() {
    final selectedImages = _ref.read(selectedImagesProvider);
    if (selectedImages.isEmpty) return;
    // ... creates group and updates state
    state = [...state, group];
  }
}
```

**Key Points:**
- Use `StateNotifier<T>` for complex state with methods
- Access other providers via `_ref.read()`
- Update state immutably with spread operator

### ConsumerStatefulWidget Pattern

From `lib/screens/grouping_screen.dart`:

```dart
class GroupingScreen extends ConsumerWidget {
  const GroupingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ungroupedImages = ref.watch(ungroupedImagesProvider);
    // ... build UI
  }
}
```

**Key Points:**
- Use `ref.watch()` for reactive state watching
- Use `ref.read()` for one-time reads in callbacks
- Convert to `ConsumerStatefulWidget` when local state is needed (e.g., cursor position)

### Keyboard Event Handling Pattern (Flutter Standard)

```dart
Focus(
  autofocus: true,
  onKeyEvent: (node, event) {
    if (event is KeyDownEvent) {
      final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

      if (event.logicalKey == LogicalKeyboardKey.space) {
        if (isShiftPressed) {
          // Shift+Space: deselect and move back
        } else {
          // Space: select and advance
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (isShiftPressed) {
          // Shift+Enter: undo group
        } else {
          // Enter: create group
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  },
  child: // ... screen content
)
```

**Key Points:**
- Wrap screen content with `Focus` widget
- Set `autofocus: true` to capture keyboard immediately
- Check `HardwareKeyboard.instance.isShiftPressed` for modifier keys
- Return `KeyEventResult.handled` to prevent event bubbling

## Requirements

### Functional Requirements

1. **Export Destination Prompt**
   - Description: When user enters the GroupingScreen, show a directory picker dialog to select the export destination
   - Acceptance: Dialog appears on screen entry; selected directory is stored and used during final export

2. **Space Key Selection**
   - Description: Pressing Space selects the currently focused photo and automatically moves the cursor to the next photo
   - Acceptance: Photo at cursor position becomes selected; cursor advances to next ungrouped photo

3. **Shift+Space Deselection**
   - Description: Pressing Shift+Space deselects the currently focused photo and moves the cursor backward to the previous photo
   - Acceptance: Photo at cursor position becomes deselected; cursor moves to previous ungrouped photo

4. **Enter Group Creation**
   - Description: Pressing Enter creates a group from all currently selected photos
   - Acceptance: New group appears in sidebar; selected photos move from ungrouped grid to the group

5. **Shift+Enter Undo**
   - Description: Pressing Shift+Enter undoes the last group creation, returning photos to ungrouped state
   - Acceptance: Last created group is removed; its photos return to the ungrouped grid with cursor on first returned photo

6. **Visual Cursor Indicator**
   - Description: The currently focused photo should have a distinct visual indicator (e.g., colored border, highlight)
   - Acceptance: User can always see which photo will be affected by keyboard actions

### Edge Cases

1. **Cursor at end of list (Space)** - Wrap to beginning or stop at last photo
2. **Cursor at start of list (Shift+Space)** - Stop at first photo or wrap to end
3. **No photos selected (Enter)** - Show message or do nothing gracefully
4. **No groups to undo (Shift+Enter)** - Do nothing gracefully
5. **All photos grouped** - Disable keyboard navigation, show completion message
6. **User cancels directory picker** - Allow continuing without directory (will prompt again at export)
7. **Web platform** - Skip directory picker (web uses browser download)

## Implementation Notes

### DO
- Use `Focus` widget with `autofocus: true` to ensure keyboard capture
- Store cursor position as local state in `ConsumerStatefulWidget`
- Use `ref.watch(ungroupedImagesProvider)` to get the list for navigation
- Clamp cursor position when list size changes (after grouping)
- Store last created group ID in `GroupsNotifier` for undo functionality
- Show visual feedback immediately on key press (before async operations)
- Use existing `ExportService.getExportDirectory()` for the directory picker

### DON'T
- Don't use raw keyboard listeners (use Flutter's `Focus` widget pattern)
- Don't modify cursor position directly from providers (keep it as local UI state)
- Don't block UI during directory selection (show dialog, handle result async)
- Don't assume cursor index is valid after operations (always clamp/validate)
- Don't forget to handle the case where `ungroupedImages` becomes empty

## Development Environment

### Start Services

```bash
# Install dependencies
flutter pub get

# Run app
flutter run

# Run on specific platform
flutter run -d macos
flutter run -d windows
flutter run -d chrome
```

### Service URLs
- N/A (native/web app, no backend services)

### Required Environment Variables
- `GEMINI_API_KEY`: API key for Google Gemini AI (in `.env` file)

## Success Criteria

The task is complete when:

1. [ ] Export destination dialog appears when entering GroupingScreen (desktop/mobile)
2. [ ] Space key selects current photo and advances cursor
3. [ ] Shift+Space deselects current photo and moves cursor backward
4. [ ] Enter key creates group from selected photos
5. [ ] Shift+Enter undoes the last created group
6. [ ] Visual cursor indicator is visible on the focused photo
7. [ ] Keyboard navigation works smoothly without lag
8. [ ] Edge cases (empty list, end of list) handled gracefully
9. [ ] No console errors during operation
10. [ ] Existing click-based selection still works alongside keyboard controls

## QA Acceptance Criteria

**CRITICAL**: These criteria must be verified by the QA Agent before sign-off.

### Unit Tests
| Test | File | What to Verify |
|------|------|----------------|
| GroupsNotifier.undoLastGroup | `test/providers/groups_provider_test.dart` | Returns photos to ungrouped state, removes last group |
| ImagesNotifier.selectImageAt | `test/providers/images_provider_test.dart` | Selects image at specific index |
| ImagesNotifier.deselectImageAt | `test/providers/images_provider_test.dart` | Deselects image at specific index |
| ImagesNotifier.markAsUngrouped | `test/providers/images_provider_test.dart` | Marks images as ungrouped |

### Integration Tests
| Test | Services | What to Verify |
|------|----------|----------------|
| Keyboard selection flow | GroupingScreen ↔ ImagesProvider | Space key triggers selection and advances cursor |
| Group creation flow | GroupingScreen ↔ GroupsProvider | Enter key creates group with selected images |
| Undo flow | GroupingScreen ↔ GroupsProvider ↔ ImagesProvider | Shift+Enter restores images to ungrouped |

### End-to-End Tests
| Flow | Steps | Expected Outcome |
|------|-------|------------------|
| Full keyboard workflow | 1. Enter GroupingScreen 2. Press Space 3x 3. Press Enter 4. Press Shift+Enter | 3 photos selected, group created, then undone |
| Mixed keyboard/mouse | 1. Click to select 2. Press Space 3. Press Enter | Both click and keyboard selections in group |
| Export directory | 1. Enter GroupingScreen 2. Select directory 3. Complete workflow 4. Export | Files exported to selected directory |

### Browser Verification (if frontend)
| Page/Component | URL | Checks |
|----------------|-----|--------|
| GroupingScreen | Navigate from ImportScreen | Keyboard shortcuts work, cursor visible, export prompt appears |
| Desktop app | Run with `flutter run -d macos` | Directory picker dialog appears and works |
| Web app | Run with `flutter run -d chrome` | Skips directory picker, keyboard navigation works |

### Database Verification (if applicable)
| Check | Query/Command | Expected |
|-------|---------------|----------|
| N/A | N/A | No database in this Flutter app |

### QA Sign-off Requirements
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] All E2E tests pass
- [ ] Browser verification complete (if applicable)
- [ ] Database state verified (if applicable)
- [ ] No regressions in existing functionality
- [ ] Code follows established patterns
- [ ] No security vulnerabilities introduced
- [ ] Keyboard shortcuts don't conflict with OS/browser shortcuts
- [ ] Visual cursor indicator has sufficient contrast
