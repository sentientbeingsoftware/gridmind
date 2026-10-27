import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gridmind/screens/chain_reaction_game_screen.dart';

void main() {
  group('ChainReactionGameScreen Widget Tests', () {
    testWidgets('renders Chain Reaction screen in challenge mode', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ChainReactionGameScreen(
            gridSize: 5,
            difficulty: 'medium',
            moveMode: 'challenge',
            testMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChainReactionGameScreen), findsOneWidget);
      expect(find.text('Taps'), findsOneWidget);
      expect(find.text('--'), findsOneWidget);
    });

    testWidgets('tapping a critical cell triggers chain reaction and clears board to win', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testGrid = [
        [3],
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ChainReactionGameScreen(
            gridSize: 1,
            difficulty: 'medium',
            moveMode: 'zen',
            testMode: true,
            testGrid: testGrid,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tileFinder = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(GestureDetector),
      );
      expect(tileFinder, findsOneWidget);

      await tester.tap(tileFinder);
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('Chain Reaction complete! Solved in 1 taps!'), findsOneWidget);
    });

    testWidgets('exceeding tap limit in challenge mode triggers game over', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testGrid = [
        [1],
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ChainReactionGameScreen(
            gridSize: 1,
            difficulty: 'medium',
            moveMode: 'challenge',
            testMode: true,
            testGrid: testGrid,
            testMaxTaps: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tileFinder = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(GestureDetector),
      );
      expect(tileFinder, findsOneWidget);

      await tester.tap(tileFinder);
      await tester.pumpAndSettle();

      expect(find.text('Out of taps! Try again.'), findsOneWidget);
    });

    testWidgets('flying dots cross empty cells to trigger distant corners', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 3x3 board: corner (0,0) has 1 (capacity 2), empty (0,1), corner (0,2) has 1 (capacity 2).
      // Tapping (0,0) makes it 2 -> explodes -> flying dot skips empty (0,1) and hits (0,2) ->
      // (0,2) reaches 2 -> explodes -> board clears in 1 tap!
      final testGrid = [
        [1, 0, 1],
        [0, 0, 0],
        [0, 0, 0],
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ChainReactionGameScreen(
            gridSize: 3,
            difficulty: 'medium',
            moveMode: 'challenge',
            testMode: true,
            testGrid: testGrid,
            testMaxTaps: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tiles = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(GestureDetector),
      );
      await tester.tap(tiles.first);
      await tester.pumpAndSettle();

      expect(find.text('Chain Reaction complete! Solved in 1 taps!'), findsOneWidget);
    });
  });
}
