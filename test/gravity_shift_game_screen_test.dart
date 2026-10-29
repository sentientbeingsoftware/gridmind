import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gridmind/screens/gravity_shift_game_screen.dart';

void main() {
  group('GravityShiftGameScreen Widget Tests', () {
    testWidgets('renders Gravity Shift screen in challenge mode', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(
        home: GravityShiftGameScreen(
          gridSize: 4,
          difficulty: 'medium',
          moveMode: 'challenge',
          testMode: true,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(GravityShiftGameScreen), findsOneWidget);
      expect(find.text('Moves'), findsOneWidget);
      expect(find.text('Target Pattern:'), findsOneWidget);
    });

    testWidgets('gravity direction updates moves and triggers victory', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Simple 4x4 grid where a single upward gravity solves the puzzle.
      final testGrid = [
        [Colors.transparent, Colors.transparent, Colors.transparent, Colors.transparent],
        [Colors.red, Colors.transparent, Colors.transparent, Colors.transparent],
        [Colors.transparent, Colors.transparent, Colors.transparent, Colors.transparent],
        [Colors.transparent, Colors.transparent, Colors.transparent, Colors.transparent],
      ];
      final testTarget = [
        [Colors.red, Colors.transparent, Colors.transparent, Colors.transparent],
        [Colors.transparent, Colors.transparent, Colors.transparent, Colors.transparent],
        [Colors.transparent, Colors.transparent, Colors.transparent, Colors.transparent],
        [Colors.transparent, Colors.transparent, Colors.transparent, Colors.transparent],
      ];

      await tester.pumpWidget(MaterialApp(
        home: GravityShiftGameScreen(
          gridSize: 4,
          difficulty: 'medium',
          moveMode: 'zen',
          testMode: true,
          testGrid: testGrid,
          testTarget: testTarget,
          testMaxMoves: 5,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap the upward arrow button.
      final upButton = find.byIcon(Icons.arrow_upward);
      expect(upButton, findsOneWidget);
      await tester.tap(upButton);
      await tester.pumpAndSettle();

      // Moves should be 1.
      expect(find.text('1'), findsOneWidget);
      // Victory message should appear.
      expect(find.textContaining('Solved in'), findsOneWidget);
    });

    testWidgets('exceeding move limit in challenge mode triggers game over', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testGrid = [
        [Colors.red, Colors.transparent, Colors.transparent, Colors.transparent],
        [Colors.transparent, Colors.transparent, Colors.transparent, Colors.transparent],
        [Colors.transparent, Colors.transparent, Colors.transparent, Colors.transparent],
        [Colors.transparent, Colors.transparent, Colors.transparent, Colors.transparent],
      ];
      final testTarget = [
        [Colors.transparent, Colors.transparent, Colors.transparent, Colors.transparent],
        [Colors.red, Colors.transparent, Colors.transparent, Colors.transparent],
        [Colors.transparent, Colors.transparent, Colors.transparent, Colors.transparent],
        [Colors.transparent, Colors.transparent, Colors.transparent, Colors.transparent],
      ];

      await tester.pumpWidget(MaterialApp(
        home: GravityShiftGameScreen(
          gridSize: 4,
          difficulty: 'medium',
          moveMode: 'challenge',
          testMode: true,
          testGrid: testGrid,
          testTarget: testTarget,
          testMaxMoves: 1,
        ),
      ));
      await tester.pumpAndSettle();

      // Apply a gravity direction that does not solve the puzzle.
      final downButton = find.byIcon(Icons.arrow_downward);
      expect(downButton, findsOneWidget);
      await tester.tap(downButton);
      await tester.pumpAndSettle();

      // Should show game over overlay.
      expect(find.text('Move limit exceeded! Try again.'), findsOneWidget);
    });

    testWidgets('generated puzzle does not win on first move across sizes 4-10', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final size in [4, 6, 8, 10]) {
        await tester.pumpWidget(
          MaterialApp(
            home: GravityShiftGameScreen(
              key: ValueKey('gs_$size'),
              gridSize: size,
              difficulty: 'medium',
              moveMode: 'challenge',
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.arrow_upward));
        await tester.pumpAndSettle();
        expect(find.text('Puzzle solved!'), findsNothing, reason: 'size $size won on 1st move');
      }
    });

    for (final size in [const Size(320, 568), const Size(360, 640)]) {
      testWidgets('grid 10 and its arrows fit a ${size.width.toInt()}x${size.height.toInt()} phone without scrolling', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(const MaterialApp(
          home: GravityShiftGameScreen(gridSize: 10, difficulty: 'medium', moveMode: 'zen'),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final screen = Offset.zero & size;
        for (final tip in ['Gravity up', 'Gravity down', 'Gravity left', 'Gravity right']) {
          final r = tester.getRect(find.byTooltip(tip));
          expect(screen.contains(r.bottomRight), isTrue, reason: '$tip off screen: $r');
        }
      });
    }
  });
}
