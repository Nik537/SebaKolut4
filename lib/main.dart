import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/import_screen.dart';
import 'providers/undo_redo_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  runApp(
    const ProviderScope(
      child: FilamentColorizerApp(),
    ),
  );
}

/// Intent for triggering undo action.
class UndoIntent extends Intent {
  const UndoIntent();
}

/// Intent for triggering redo action.
class RedoIntent extends Intent {
  const RedoIntent();
}

class FilamentColorizerApp extends ConsumerWidget {
  const FilamentColorizerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        // Windows/Linux: Ctrl+Z for undo, Ctrl+Shift+Z for redo
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            const UndoIntent(),
        const SingleActivator(LogicalKeyboardKey.keyZ,
            control: true, shift: true): const RedoIntent(),
        // macOS: Command+Z for undo, Command+Shift+Z for redo
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
            const UndoIntent(),
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            const RedoIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          UndoIntent: CallbackAction<UndoIntent>(
            onInvoke: (UndoIntent intent) {
              ref.read(undoRedoProvider.notifier).undo();
              return null;
            },
          ),
          RedoIntent: CallbackAction<RedoIntent>(
            onInvoke: (RedoIntent intent) {
              ref.read(undoRedoProvider.notifier).redo();
              return null;
            },
          ),
        },
        child: MaterialApp(
          title: 'Filament Colorizer',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
            ),
            cardTheme: CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          home: const ImportScreen(),
        ),
      ),
    );
  }
}
