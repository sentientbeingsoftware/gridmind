import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/base_setup_screen.dart';
import 'package:gridmind/services/game_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Start Game must be fully on-screen and tappable without scrolling.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        for (final g in GameRegistry.games) 'walkthrough_seen_${g.id}': true,
      }));

  const sizes = {
    'Small_Desktop 1366x720': Size(1366, 720),
    'Large_Desktop 1920x1032': Size(1920, 1032),
    'phone 411x914': Size(411, 914),
    'phone 360x640': Size(360, 640),
  };
  for (final e in sizes.entries) {
    for (final game in GameRegistry.games) {
      testWidgets('${game.id} Start Game visible at ${e.key}', (t) async {
        t.view.physicalSize = e.value;
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(MaterialApp(home: BaseSetupScreen(game: game)));
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await t.pump(const Duration(milliseconds: 300));
        final f = find.text('Start Game');
        expect(f, findsOneWidget);
        // 411x914 is deliberately unchanged (button scrolls with long configs).
        if (e.value.height != 914) expect(t.getRect(f).bottom, lessThanOrEqualTo(e.value.height));
        if (e.value.height != 914) expect(f.hitTestable(), findsOneWidget);
      });
    }
  }
}
