import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/settings_screen.dart';
import 'package:gridmind/services/app_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final w in [320.0, 360.0]) {
    testWidgets('palette sheet does not overflow at ${w.toInt()} px wide', (t) async {
      t.view.physicalSize = Size(w, 800);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await t.pumpAndSettle();
      await t.tap(find.text('Game Color Palette'));
      await t.pumpAndSettle();
      expect(find.text('High Contrast'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('custom palette editor: pick a swatch, change it, Save persists the colours', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await t.pumpAndSettle();
    await t.tap(find.text('Game Color Palette'));
    await t.pumpAndSettle();
    await t.tap(find.text('Edit custom colors'));
    await t.pumpAndSettle();
    expect(find.text('Custom colors'), findsOneWidget);

    // Select swatch 2 (green by default) and drag Hue far right.
    await t.tap(find.bySemanticsLabel(RegExp('^Color 2 of 9')));
    await t.pump();
    await t.drag(find.byType(Slider).first, const Offset(300, 0));
    await t.pump();
    expect(t.takeException(), isNull);
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();

    final saved = await AppPersistenceService().getCustomPalette();
    expect(saved.length, 9);
    expect(saved[1].toARGB32(), isNot(Colors.green.toARGB32()));
    // Swatches that were not touched must come back exactly, not nudged by the HSV round trip.
    const defaults = [Colors.red, Colors.green, Colors.blue, Colors.yellow, Colors.purple, Colors.orange, Colors.cyan, Colors.pink, Colors.teal];
    for (final i in [0, 2, 3, 4, 5, 6, 7, 8]) {
      expect(saved[i].toARGB32(), defaults[i].toARGB32(), reason: 'swatch ${i + 1} drifted');
    }
    expect(await AppPersistenceService().getPaletteType(), 'custom');
  });
}
