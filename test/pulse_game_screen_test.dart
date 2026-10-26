import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/pulse_game_screen.dart';
import 'package:gridmind/services/app_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PulseGameScreen Widget Tests', () {
    testWidgets('renders Pulse screen and increments score on correct tap', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PulseGameScreen(
            gridSize: 3,
            speed: 'normal',
            testMode: true,
          ),
        ),
      );

      // Initially score is 0
      expect(find.text('Score'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);

      // The active index initially is 0. Tap the first cell.
      final cells = find.byType(GestureDetector);
      await tester.tap(cells.first);
      await tester.pump();

      // Score should become 1, and currentIndex advances
      expect(find.text('Score'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('incorrect tap triggers game over', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PulseGameScreen(
            gridSize: 3,
            speed: 'normal',
            testMode: true,
          ),
        ),
      );

      // Initially active index is 0. Tap the second cell (index 1) to make a mistake.
      final cells = find.byType(GestureDetector);
      await tester.tap(cells.at(1));
      await tester.pump();

      // Should be game over with final score
      expect(find.text('Game Over! Final Score: 0'), findsOneWidget);
    });

    testWidgets('timer advances active cell over time', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PulseGameScreen(
            gridSize: 3,
            speed: 'normal',
            testMode: true,
          ),
        ),
      );

      // Wait 500ms for timer tick (speed: normal corresponds to 500ms)
      await tester.pump(const Duration(milliseconds: 500));

      // Active cell is now 1. Let's tap index 1.
      final cells = find.byType(GestureDetector);
      await tester.tap(cells.at(1));
      await tester.pump();

      // Score should increment to 1
      expect(find.text('Score'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('game over saves the score and the next run shows it as Best', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<void> launch() async {
        await tester.pumpWidget(const MaterialApp(
          home: PulseGameScreen(gridSize: 3, speed: 'normal', testMode: true),
        ));
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }

      await launch();
      expect(find.text('--'), findsOneWidget);
      final cells = find.byType(GestureDetector);
      await tester.tap(cells.first); // correct: index 0 is active
      await tester.pump();
      await tester.tap(cells.at(5)); // wrong -> game over, score 1
      await tester.pump();
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));

      final stored = await tester.runAsync(() => AppPersistenceService()
          .getConfigHighScore('pulse', {'gridSize': 3.0, 'speed': 'normal'}));
      expect(stored, 1);

      await tester.pumpWidget(const SizedBox());
      await launch();
      expect(find.text('--'), findsNothing);
      expect(find.text('1'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
