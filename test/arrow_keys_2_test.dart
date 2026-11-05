import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/models/collapse_models.dart';
import 'package:gridmind/screens/collapse_game_screen.dart';
import 'package:gridmind/screens/grid_painter_game_screen.dart';
import 'package:gridmind/screens/rotate_matrix_game_screen.dart';
import 'package:gridmind/screens/slide_and_solve_game_screen.dart';

void _phoneView(WidgetTester t) {
  t.view.physicalSize = const Size(800, 1200);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

Future<void> _key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyEvent(k);
  await t.pump();
}

void main() {
  group('keyboard: Space / Q / E and cursors', () {
    testWidgets('Grid Painter: Space toggles the current cell like the middle button', (t) async {
      _phoneView(t);
      await t.pumpWidget(const MaterialApp(
        home: GridPainterGameScreen(gridSize: 3, gameMode: 'show', moveMode: 'zen'),
      ));
      await t.pumpAndSettle();
      expect(find.text('1'), findsNothing);
      await _key(t, LogicalKeyboardKey.space);
      expect(find.text('1'), findsWidgets); // Moves counter
    });

    testWidgets('Rotate Matrix: arrows pick a quadrant, Space rotates right, Q rotates left', (t) async {
      _phoneView(t);
      await t.pumpWidget(MaterialApp(
        home: RotateMatrixGameScreen(
          gridSize: 4, difficulty: 'medium', moveMode: 'zen', testMode: true,
          testGrid: const [
            [Colors.red, Colors.blue, Colors.green, Colors.yellow],
            [Colors.blue, Colors.green, Colors.yellow, Colors.red],
            [Colors.green, Colors.yellow, Colors.red, Colors.blue],
            [Colors.yellow, Colors.red, Colors.blue, Colors.green],
          ],
          testTarget: List.generate(4, (_) => List.filled(4, Colors.purple)),
        ),
      ));
      await t.pumpAndSettle();
      await _key(t, LogicalKeyboardKey.arrowRight);
      expect(find.textContaining('Top-Right'), findsWidgets);
      await _key(t, LogicalKeyboardKey.arrowDown);
      expect(find.textContaining('Bottom-Right'), findsWidgets);
      await _key(t, LogicalKeyboardKey.space);
      expect(find.text('1'), findsWidgets);
      await _key(t, LogicalKeyboardKey.keyE);
      expect(find.text('2'), findsWidgets);
      await _key(t, LogicalKeyboardKey.keyQ);
      expect(find.text('3'), findsWidgets);
    });

    testWidgets('Slide and Solve: Space grabs, then arrows slide the cursor row', (t) async {
      _phoneView(t);
      await t.pumpWidget(const MaterialApp(
        home: SlideAndSolveGameScreen(
          gridSize: 3, testMode: true, skipInitialDelay: true,
          testColors: [Colors.red, Colors.green, Colors.blue, Colors.yellow, Colors.orange, Colors.purple, Colors.cyan, Colors.brown, Colors.grey],
        ),
      ));
      await t.pumpAndSettle();
      await _key(t, LogicalKeyboardKey.arrowDown); // cursor moves, no slide yet
      expect(find.text('0'), findsWidgets);
      await _key(t, LogicalKeyboardKey.space); // grab
      await _key(t, LogicalKeyboardKey.arrowRight); // slide row 2 right
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('Collapse: cursor to a block, Space grabs, arrow swaps it', (t) async {
      _phoneView(t);
      const r = Colors.red, b = Colors.blue, g = Colors.green, y = Colors.yellow, o = Colors.orange, p = Colors.purple;
      final level = CollapseLevel(
        name: 'Test 2x2', levelNumber: 0, gridSize: 4,
        mechanic: CollapseMechanic.fromTop, targetScore: 40,
        availableColors: const [b, g, y, o, p], minMatchCount: 4, moves: 10,
      );
      await t.pumpWidget(MaterialApp(
        home: CollapseGameScreen(
          level: level, testMode: true, skipInitialDelay: true,
          testColors: const [r, r, b, g, r, y, r, o, b, g, y, p, o, p, b, g],
        ),
      ));
      await t.pump();
      await _key(t, LogicalKeyboardKey.arrowDown); // (1,0)
      await _key(t, LogicalKeyboardKey.arrowRight);
      await _key(t, LogicalKeyboardKey.arrowRight); // (1,2) = red
      await _key(t, LogicalKeyboardKey.space);
      await _key(t, LogicalKeyboardKey.arrowLeft); // swap into (1,1): 2x2 red square
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Target Reached in 1 moves!'), findsOneWidget);
    });
  });
}
