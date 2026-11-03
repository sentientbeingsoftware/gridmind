import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/main.dart';
import 'package:integration_test/integration_test.dart';

// Run: flutter test integration_test/random_tap_test.dart -d <android-device>
//      [--dart-define=SEED=123 --dart-define=EVENTS=500]
// Any exception (incl. RenderFlex overflow) fails the test; SEED reproduces it.
const _seed = int.fromEnvironment('SEED', defaultValue: 42);
const _events = int.fromEnvironment('EVENTS', defaultValue: 300);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('random taps and swipes do not crash or overflow',
      (tester) async {
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
          await nav.maybePop();
      }
      await tester.pump(const Duration(milliseconds: 100));
      final e = tester.takeException();
      if (e != null) fail('seed=$_seed event=$i at $p: $e');
    }
  });
}
