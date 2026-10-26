import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gridmind/screens/collapse_game_screen.dart';
import 'package:gridmind/models/collapse_models.dart';

void main() {
  group('CollapseGameScreen Widget Tests', () {
    testWidgets('renders with test level', (WidgetTester tester) async {
      final testLevel = CollapseLevel(
        name: 'Test',
        levelNumber: 0,
        gridSize: 8,
        mechanic: CollapseMechanic.fromTop,
        targetScore: 1000,
        availableColors: [Colors.red, Colors.blue],
        minMatchCount: 3,
        moves: 25,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CollapseGameScreen(
            level: testLevel,
            testMode: true,
            skipInitialDelay: true,
            testColors: const [Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.orange, Colors.purple, Colors.cyan, Colors.brown],
          ),
        ),
      );
      expect(find.byType(CollapseGameScreen), findsOneWidget);
    });

    // Add more widget tests for block matching, score, game over, etc.
  });
}
