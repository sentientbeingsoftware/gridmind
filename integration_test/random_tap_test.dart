import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/main.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Run: flutter test integration_test/random_tap_test.dart -d <android-device>
//      [--dart-define=SEED=123 --dart-define=EVENTS=500]
// Uses mock preferences, so it never touches real scores. Limit: a tap on an external link
// (donate, privacy) leaves the app; the walk ends there.
// Any exception (incl. RenderFlex overflow) fails the test; SEED reproduces it.
const _seed = int.fromEnvironment('SEED', defaultValue: 42);
const _events = int.fromEnvironment('EVENTS', defaultValue: 300);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('random taps and swipes do not crash or overflow',
      (tester) async {
    // Random taps reach Settings > "Clear all high scores" and the telemetry/feedback network
    // calls. Dart-side mock prefs keep the device's real scores safe and telemetry off.
    SharedPreferences.setMockInitialValues({
      'telemetry_consent_answered': true,
      'telemetry_enabled': false,
      'walkthrough_seen__app_intro': true,
    });
    final rng = Random(_seed);
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 500));
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;

    Offset pt() => Offset(
        rng.nextDouble() * size.width, rng.nextDouble() * size.height);

    for (var i = 0; i < _events; i++) {
      final p = pt();
      switch (rng.nextInt(4)) {
        case 0:
          await tester.tapAt(p);
        case 1:
          await tester.longPressAt(p);
        case 2:
          await tester.dragFrom(
              p, Offset(rng.nextDouble() * 400 - 200, rng.nextDouble() * 400 - 200));
        default:
          // Back navigation keeps the walk from getting stuck inside one game.
          final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
          // pop(), not maybePop(): maybePop asserts on a route whose scope is not built yet.
          if (nav.canPop()) nav.pop();
      }
      await tester.pump(const Duration(milliseconds: 100));
      final e = tester.takeException();
      if (e != null) fail('seed=$_seed event=$i at $p: $e');
    }
    // Dispose and let sounds finish: audioplayers' position updater otherwise outlives the tree.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
