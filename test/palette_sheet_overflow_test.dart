import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/settings_screen.dart';
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
}
