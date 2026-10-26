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
  });
}
