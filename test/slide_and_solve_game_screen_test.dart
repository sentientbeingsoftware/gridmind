import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gridmind/screens/slide_and_solve_game_screen.dart';

void main() {
  group('SlideAndSolveGameScreen Widget Tests', () {
    testWidgets('renders with default grid size', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SlideAndSolveGameScreen(
            gridSize: 3,
            testMode: true,
            skipInitialDelay: true,
            testColors: [Colors.red, Colors.green, Colors.blue, Colors.yellow, Colors.orange, Colors.purple, Colors.cyan, Colors.brown, Colors.grey],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SlideAndSolveGameScreen), findsOneWidget);
    });

    // Add more widget tests for grid logic, win, moves, etc.
  });
}
