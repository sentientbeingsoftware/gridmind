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

    testWidgets('2x2 square matches even when minMatchCount is 4', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 4x4 grid with minMatchCount=4. Place red at (0,0), (0,1), (1,0),
      // and (1,2) so dragging (1,2) left into (1,1) forms a 2x2 red square
      // without forming any 4-in-a-row.
      const r = Colors.red;
      const b = Colors.blue;
      const g = Colors.green;
      const y = Colors.yellow;
      const o = Colors.orange;
      const p = Colors.purple;
      final colors = <Color>[
        r, r, b, g,
        r, y, r, o,
        b, g, y, p,
        o, p, b, g,
      ];
      final level = CollapseLevel(
        name: 'Test 2x2',
        levelNumber: 0,
        gridSize: 4,
        mechanic: CollapseMechanic.fromTop,
        targetScore: 40,
        availableColors: const [b, g, y, o, p],
        minMatchCount: 4,
        moves: 10,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CollapseGameScreen(
            level: level,
            testMode: true,
            skipInitialDelay: true,
            testColors: colors,
          ),
        ),
      );
      await tester.pump();

      // Drag cell (1,2) -> index 6 left onto (1,1).
      final cells = find.byType(GestureDetector);
      await tester.drag(cells.at(6), const Offset(-120, 0));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 4 blocks cleared * 10 pts = at least 40 score, 9 moves left.
      expect(find.text('Target Reached in 1 moves!'), findsOneWidget);
    });
  });
}
