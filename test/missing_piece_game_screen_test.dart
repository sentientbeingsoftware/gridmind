import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gridmind/screens/missing_piece_game_screen.dart';

void main() {
  group('MissingPieceGameScreen Widget Tests', () {
    testWidgets('renders screen in numbers mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MissingPieceGameScreen(
            gridSize: 3,
            contentType: 'numbers',
            initialHiddenCount: 1,
            lives: 3,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MissingPieceGameScreen), findsOneWidget);
      expect(find.text('Score'), findsOneWidget);
      expect(find.text('Lives: ❤️❤️❤️'), findsOneWidget);
    });

    testWidgets('renders screen in colors mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MissingPieceGameScreen(
            gridSize: 3,
            contentType: 'colors',
            initialHiddenCount: 1,
            lives: 3,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MissingPieceGameScreen), findsOneWidget);
      expect(find.text('Score'), findsOneWidget);
    });

    testWidgets('correct option selection advances score in testMode', (WidgetTester tester) async {
      // 3x3 grid, value at index 4 is '5', index 4 is hidden.
      // Selecting '5' should advance the score to 1.
      await tester.pumpWidget(
        const MaterialApp(
          home: MissingPieceGameScreen(
            gridSize: 3,
            contentType: 'numbers',
            initialHiddenCount: 1,
            lives: 1,
            testMode: true,
            testValues: ['1', '2', '3', '4', '5', '6', '7', '8', '9'],
            testHiddenIndices: [4],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find all buttons in the Wrap layout
      final buttonFinder = find.byType(ElevatedButton);
      expect(buttonFinder, findsAtLeastNWidgets(9)); // options '1' to '9'

      // We need to tap the option '5'. Let's find it by text!
      final option5Finder = find.widgetWithText(ElevatedButton, '5');
      expect(option5Finder, findsOneWidget);

      await tester.tap(option5Finder);
      await tester.pumpAndSettle();

      // Score is found
      expect(find.text('Score'), findsOneWidget);
    });

    testWidgets('incorrect option selection deducts lives and triggers game over', (WidgetTester tester) async {
      // 3x3 grid, hidden cell at index 4 (correct value '5').
      // Tapping '1' (incorrect) deducts the only life, causing Game Over.
      await tester.pumpWidget(
        const MaterialApp(
          home: MissingPieceGameScreen(
            gridSize: 3,
            contentType: 'numbers',
            initialHiddenCount: 1,
            lives: 1,
            testMode: true,
            testValues: ['1', '2', '3', '4', '5', '6', '7', '8', '9'],
            testHiddenIndices: [4],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap option '1' (incorrect)
      final option1Finder = find.widgetWithText(ElevatedButton, '1');
      expect(option1Finder, findsOneWidget);

      await tester.tap(option1Finder);
      await tester.pumpAndSettle();

      // Game Over modal should appear
      expect(find.text('Game Over!'), findsOneWidget);
      expect(find.text('Score achieved: 0 points!'), findsOneWidget);
    });
  });
}
