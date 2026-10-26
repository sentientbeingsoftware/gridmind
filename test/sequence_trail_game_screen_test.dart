import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gridmind/screens/sequence_trail_game_screen.dart';

void main() {
  group('SequenceTrailGameScreen Widget Tests', () {
    testWidgets('renders Sequence Trail screen with default parameters', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SequenceTrailGameScreen(
            gridSize: 3,
            timeLimit: 5.0,
            enableDecoys: false,
            enableMoving: false,
            lives: 3,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SequenceTrailGameScreen), findsOneWidget);
      expect(find.text('Score'), findsOneWidget);
      expect(find.text('Lives: ❤️❤️❤️'), findsOneWidget);
    });

    testWidgets('tapping correct numbers in sequence clears round and increments score', (WidgetTester tester) async {
      // 3x3 layout:
      // index 0 -> 1
      // index 1 -> 2
      // index 2 -> 3
      // others -1 (empty)
      final testLayout = [1, 2, 3, -1, -1, -1, -1, -1, -1];
      
      await tester.pumpWidget(
        MaterialApp(
          home: SequenceTrailGameScreen(
            gridSize: 3,
            timeLimit: 5.0,
            enableDecoys: false,
            enableMoving: false,
            lives: 3,
            testMode: true,
            testLayout: testLayout,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Score'), findsOneWidget);
      expect(find.text('Current Target: 1'), findsOneWidget);

      // Tap '1' (index 0)
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      expect(find.text('Current Target: 2'), findsOneWidget);
      expect(find.text('1'), findsNothing); // should be cleared

      // Tap '2' (index 1)
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      expect(find.text('Current Target: 3'), findsOneWidget);
      expect(find.text('2'), findsNothing);

      // Tap '3' (index 2)
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();

      // Since the round is cleared, it increments score to 1 and starts next round.
      expect(find.text('Score'), findsOneWidget);
    });

    testWidgets('tapping decoy (X) or incorrect numbers deducts lives and triggers game over', (WidgetTester tester) async {
      // 3x3 layout:
      // index 0 -> 1
      // index 1 -> 2
      // index 2 -> -2 (decoy 'X')
      final testLayout = [1, 2, -2, -1, -1, -1, -1, -1, -1];

      await tester.pumpWidget(
        MaterialApp(
          home: SequenceTrailGameScreen(
            gridSize: 3,
            timeLimit: 5.0,
            enableDecoys: true,
            enableMoving: false,
            lives: 1,
            testMode: true,
            testLayout: testLayout,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lives: ❤️'), findsOneWidget);

      // Tap 'X' (index 2)
      await tester.tap(find.text('X'));
      await tester.pumpAndSettle();

      // Lives should become 0 and Game Over modal should render
      expect(find.text('Game Over!'), findsOneWidget);
      expect(find.text('Score achieved: 0 points!'), findsOneWidget);
    });

    testWidgets('tapping out of order number deducts lives and triggers game over', (WidgetTester tester) async {
      final testLayout = [1, 2, -1, -1, -1, -1, -1, -1, -1];

      await tester.pumpWidget(
        MaterialApp(
          home: SequenceTrailGameScreen(
            gridSize: 3,
            timeLimit: 5.0,
            enableDecoys: false,
            enableMoving: false,
            lives: 1,
            testMode: true,
            testLayout: testLayout,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap '2' instead of '1'
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      expect(find.text('Game Over!'), findsOneWidget);
    });
  });
}
