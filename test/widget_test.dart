import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:filament_colorizer/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: FilamentColorizerApp(),
      ),
    );

    // Verify that the import screen is shown
    expect(find.text('Import Filament Images'), findsOneWidget);
  });
}
