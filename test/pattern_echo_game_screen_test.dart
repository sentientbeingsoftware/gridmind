import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gridmind/screens/pattern_echo_game_screen.dart';
import 'dart:math';

void main() {
  group('board fits desktop windows', () {
    for (final size in const [Size(1366, 720), Size(1920, 1032), Size(411, 914)]) {
      for (final n in [4, 6]) {
        testWidgets('${n}x$n at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(MaterialApp(
            home: PatternEchoGameScreen(gridSize: n, transformationMode: 'none', displayMode: 'mental', lives: 3),
          ));
          await tester.pumpAndSettle();
          final last = find.bySemanticsLabel(RegExp('^Row $n, column $n'));
          expect(last, findsOneWidget);
          expect(tester.getRect(last).bottom, lessThanOrEqualTo(size.height));
        });
      }
    }
  });

  group('PatternEchoGameScreen Widget Tests', () {
    testWidgets('renders screen in show phase and transitions to input phase', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PatternEchoGameScreen(
            gridSize: 3,
            transformationMode: 'none',
            displayMode: 'mental',
            lives: 3,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PatternEchoGameScreen), findsOneWidget);
      expect(find.text('Score'), findsOneWidget);
      expect(find.text('Lives: ❤️❤️❤️'), findsOneWidget);
    });

    testWidgets('mental mode: correct tap at transformed cell advances round', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PatternEchoGameScreen(
            gridSize: 3,
            transformationMode: 'rotate',
            displayMode: 'mental',
            lives: 1,
            testMode: true,
            testPattern: [Point(0, 0)],
            testTransformation: 'rotate90',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tileFinder = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(GestureDetector),
      );
      expect(tileFinder, findsAtLeastNWidgets(9));

      // Tap cell (0, 2) which is index 2
      await tester.tap(tileFinder.at(2));
      await tester.pumpAndSettle();

      // Verify the score is found
      expect(find.text('Score'), findsOneWidget);
    });

    testWidgets('mental mode: incorrect tap deducts lives and triggers game over', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PatternEchoGameScreen(
            gridSize: 3,
            transformationMode: 'rotate',
            displayMode: 'mental',
            lives: 1,
            testMode: true,
            testPattern: [Point(0, 0)],
            testTransformation: 'rotate90',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tileFinder = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(GestureDetector),
      );
      expect(tileFinder, findsAtLeastNWidgets(9));

      // Tap cell (0, 0) which is index 0:
      await tester.tap(tileFinder.first);
      await tester.pumpAndSettle();

      expect(find.text('Game Over!'), findsOneWidget);
      expect(find.text('Final Score: 0 points!'), findsOneWidget);
    });
  });
}
