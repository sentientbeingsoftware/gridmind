import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/services/game_registry.dart';
import 'package:gridmind/services/telemetry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('All registered games trigger telemetry on dispose/quit', (WidgetTester tester) async {
    // Set a very tall physical screen size to prevent layout overflows during widget tests
    tester.view.physicalSize = const Size(1024, 2048);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final telemetry = TelemetryService();
    await telemetry.setEnabled(true);

    for (final game in GameRegistry.games) {
      // Clear queue for this game's test iteration
      await telemetry.clearQueue();

      // Build default config for the game
      final Map<String, dynamic> config = {};
      for (final opt in game.configOptions) {
        config[opt.key] = opt.defaultValue;
      }

      // Render the game screen
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return game.gameBuilder(context, config);
            },
          ),
        ),
      );

      // Allow async initializations (e.g. SharedPreferences palette loading) to complete
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      
      // Re-pump to process setState from completed loading futures
      await tester.pump();

      // Now, navigate away/dispose of the game screen by pumping a blank screen
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
          ),
        ),
      );

      // Drain any pending/delayed timers that were scheduled by the screen
      await tester.pump(const Duration(seconds: 5));

      // Allow asynchronous microtasks/futures to run to completion
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });

      // Verify that a telemetry event has been queued
      final queue = await telemetry.getQueue();
      expect(
        queue.any((e) => e['gameId'] == game.id),
        isTrue,
        reason: 'Game "${game.title}" (id: ${game.id}) did not trigger telemetry logging on exit.',
      );
    }
  });
}
