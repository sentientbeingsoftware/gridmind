import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/main.dart';
import 'package:gridmind/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Consent already answered so the first-run dialog doesn't cover the UI.
  setUp(() => SharedPreferences.setMockInitialValues({'telemetry_consent_answered': true}));

  test('ThemeController updates value and persists the mode', () async {
    final controller = ThemeController();
    await controller.setMode(ThemeMode.dark);
    expect(controller.value, ThemeMode.dark);

    final reloaded = ThemeController();
    await reloaded.load();
    expect(reloaded.value, ThemeMode.dark);
  });

  testWidgets('changing theme in Settings updates MaterialApp.themeMode', (tester) async {
    tester.view.physicalSize = const Size(1024, 2048);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<ThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });
}
