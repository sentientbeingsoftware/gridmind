import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gridmind/screens/grid_painter_game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('GridPainterGameScreen Widget Tests', () {
    testWidgets('renders Grid Painter screen in show mode', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: GridPainterGameScreen(
            gridSize: 3,
            gameMode: 'show',
            moveMode: 'zen',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GridPainterGameScreen), findsOneWidget);
      expect(find.text('Moves'), findsOneWidget);
      expect(find.text('--'), findsOneWidget);
    });

    testWidgets('renders Grid Painter screen in picross mode', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: GridPainterGameScreen(
            gridSize: 3,
            gameMode: 'picross',
            moveMode: 'challenge',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GridPainterGameScreen), findsOneWidget);
      expect(find.text('Pure Picross Mode'), findsOneWidget);
    });

    testWidgets('moving brush paints tiles and solves blueprint', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 3x3 pattern: only (0, 1) and (1, 1) are painted
      final testBlueprint = [
        [false, true, false],
        [false, true, false],
        [false, false, false],
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: GridPainterGameScreen(
            gridSize: 3,
            gameMode: 'show',
            moveMode: 'zen',
            testMode: true,
            testBlueprint: testBlueprint,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Brush starts at (0, 0), which is index 0.
      // Move mode defaults to Draw.
      // Select 'Move' segment (Navigate mode) to walk without painting.
      final moveSegmentFinder = find.text('Move');
      expect(moveSegmentFinder, findsOneWidget);
      await tester.tap(moveSegmentFinder);
      await tester.pumpAndSettle();

      // Brush is now in Navigate mode.
      // Use the D-pad right arrow to move to (0, 1).
      final rightArrowFinder = find.byIcon(Icons.keyboard_arrow_right);
      expect(rightArrowFinder, findsOneWidget);
      await tester.tap(rightArrowFinder);
      await tester.pumpAndSettle();

      // Now at (0, 1). Switch to 'Draw' segment to paint.
      final drawSegmentFinder = find.text('Draw');
      expect(drawSegmentFinder, findsOneWidget);
      await tester.tap(drawSegmentFinder);
      await tester.pumpAndSettle();

      // Tapping 'Draw' segment toggles the start/current cell to true.
      // Now use D-pad down arrow to move to (1, 1) and paint it as well.
      final downArrowFinder = find.byIcon(Icons.keyboard_arrow_down);
      expect(downArrowFinder, findsOneWidget);
      await tester.tap(downArrowFinder);
      await tester.pumpAndSettle();

      // Matches exactly! Verify completed overlay is shown.
      expect(find.text('Solved in 2 moves!'), findsOneWidget);
    });

    testWidgets('exceeding move limit in challenge mode triggers game over', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testBlueprint = [
        [false, false, false],
        [false, true, false],
        [false, false, false],
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: GridPainterGameScreen(
            gridSize: 3,
            gameMode: 'show',
            moveMode: 'challenge',
            testMode: true,
            testBlueprint: testBlueprint,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Move limit: (3 * 3 * 1.6).round() + 5 = 14 + 5 = 19 moves.
      final rightArrow = find.byIcon(Icons.keyboard_arrow_right);
      final leftArrow = find.byIcon(Icons.keyboard_arrow_left);

      for (int i = 0; i < 15; i++) {
        await tester.tap(rightArrow);
        await tester.pumpAndSettle();
        if (tester.any(find.textContaining('Failed! Exceeded move limit'))) {
          break;
        }
        await tester.tap(leftArrow);
        await tester.pumpAndSettle();
        if (tester.any(find.textContaining('Failed! Exceeded move limit'))) {
          break;
        }
      }

      expect(find.textContaining('Failed! Exceeded move limit'), findsOneWidget);
    });

    testWidgets('a new board starts with nothing painted, including the brush start tile', (tester) async {
      SharedPreferences.setMockInitialValues({}); // _initializeGame reads saved prefs; without this it never finishes
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(
        home: GridPainterGameScreen(gridSize: 4, gameMode: 'show', moveMode: 'zen'),
      ));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp(r'^Row 1, column 1, empty, brush here')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'painted')), findsNothing);
      handle.dispose();
    });
  });
}
