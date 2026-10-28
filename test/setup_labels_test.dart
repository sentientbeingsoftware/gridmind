import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/base_setup_screen.dart';
import 'package:gridmind/services/game_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Every setup screen must lay out on a narrow phone at 150% text, with the
// dropdown labels readable (the Grid Miner "Move Mode" label used to squeeze).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final game in GameRegistry.games) {
    testWidgets('setup screen for ${game.id} fits 320x568 at 150% text', (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
        builder: (c, ch) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.5)), child: ch!),
        home: BaseSetupScreen(game: game),
      ));
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await t.pump(const Duration(milliseconds: 300));
      final ex = t.takeException();
      expect(ex, isNull, reason: ex?.toString().split('\n').first);
    });
  }
}
