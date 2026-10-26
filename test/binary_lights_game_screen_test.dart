import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gridmind/screens/binary_lights_game_screen.dart';

void main() {
  group('BinaryLightsGameScreen Widget Tests', () {
    testWidgets('renders Binary Lights screen in classic mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BinaryLightsGameScreen(
            gridSize: 3,
            gameMode: 'classic',
            moveMode: 'zen',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BinaryLightsGameScreen), findsOneWidget);
      expect(find.text('Goal: Turn all lights off!'), findsOneWidget);
      expect(find.text('Moves'), findsOneWidget);
    });

    testWidgets('renders Binary Lights screen in pattern mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BinaryLightsGameScreen(
            gridSize: 3,
            gameMode: 'pattern',
            moveMode: 'challenge',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BinaryLightsGameScreen), findsOneWidget);
      expect(find.text('TARGET PATTERN'), findsOneWidget);
    });

    testWidgets('taps a cell to toggle it and neighbors and wins', (WidgetTester tester) async {
      final testStart = [
        [true, true, false],
        [true, false, false],
        [false, false, false],
      ];
      final testTarget = [
        [false, false, false],
        [false, false, false],
        [false, false, false],
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: BinaryLightsGameScreen(
            gridSize: 3,
            gameMode: 'classic',
            moveMode: 'zen',
            testMode: true,
            testStartGrid: testStart,
            testTargetGrid: testTarget,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the interactive board tiles specifically within the GridView
      final tileFinder = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(GestureDetector),
      );
      expect(tileFinder, findsAtLeastNWidgets(9));

      // Tap on the first tile (0, 0)
      await tester.tap(tileFinder.first);
      await tester.pumpAndSettle();

      // Verify the moves counter incremented
      expect(find.text('Moves'), findsOneWidget);

      // Verify that the game is won and the victory banner is visible
      expect(find.text('Solved in 1 moves!'), findsOneWidget);
    });
  });
}
