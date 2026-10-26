import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/grid_miner_game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GridMinerGameScreen Widget Tests', () {
    testWidgets('Grid Miner screen builds and plays to victory in challenge mode', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: GridMinerGameScreen(
            gridSize: 3,
            difficulty: 'easy',
            moveMode: 'challenge',
            maxMoves: 10,
            testMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle(); // Allow async initialization to complete

      // Verify initial HUD details (2 total resources now)
      expect(find.text('0/2'), findsOneWidget); // Score: 0/2
      expect(find.text('⚡ Energy: 100%'), findsOneWidget);
      expect(find.text('Moves: 0/10'), findsOneWidget);

      final cells = find.byType(GestureDetector);

      // Tap index 3 (adjacent to start index 6)
      await tester.tap(cells.at(3));
      await tester.pumpAndSettle();

      // Energy pack 'P' at index 3: easy energy cost is 4, then +30 pack -> 100 - 4 + 30 = 100 (capped)
      expect(find.text('⚡ Energy: 100%'), findsOneWidget);
      expect(find.text('Moves: 1/10'), findsOneWidget);

      // Tap index 0 (adjacent to index 3)
      await tester.tap(cells.at(0));
      await tester.pumpAndSettle();

      // Empty cell 'E' at index 0: cost 4 -> 100 - 4 = 96
      expect(find.text('⚡ Energy: 96%'), findsOneWidget);
      expect(find.text('Moves: 2/10'), findsOneWidget);

      // Tap index 1 (resource cell adjacent to index 0)
      await tester.tap(cells.at(1));
      await tester.pumpAndSettle();

      // Collected first resource -> Score is 1/2
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('Moves: 3/10'), findsOneWidget);

      // Tap index 2 (hazard cell adjacent to index 1)
      await tester.tap(cells.at(2));
      await tester.pumpAndSettle();

      // Tap index 5 (adjacent to index 2)
      await tester.tap(cells.at(5));
      await tester.pumpAndSettle();

      // Tap index 8 (second resource cell adjacent to index 5)
      await tester.tap(cells.at(8));
      await tester.pumpAndSettle();

      // Collected last resource -> Win game!
      expect(find.text('Victory! All resources collected.'), findsOneWidget);
    });

    testWidgets('stepping on hazard reduces extra energy', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: GridMinerGameScreen(
            gridSize: 3,
            difficulty: 'hard', // cost is 8
            moveMode: 'challenge',
            maxMoves: 10,
            testMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cells = find.byType(GestureDetector);

      // Step to index 3 (power cell P, but hard mode: 100 - 8 + 30 = 100)
      await tester.tap(cells.at(3));
      await tester.pumpAndSettle();

      // Step to index 0 (empty, 100 - 8 = 92)
      await tester.tap(cells.at(0));
      await tester.pumpAndSettle();
      expect(find.text('⚡ Energy: 92%'), findsOneWidget);

      // Step to index 1 (resource cell: 92 - 8 = 84)
      await tester.tap(cells.at(1));
      await tester.pumpAndSettle();
      expect(find.text('⚡ Energy: 84%'), findsOneWidget);

      // Step to index 2 (hazard cell H adjacent to index 1: 84 - 8 (hard cost) - 20 (hazard damage) = 56)
      await tester.tap(cells.at(2));
      await tester.pumpAndSettle();
      expect(find.text('⚡ Energy: 56%'), findsOneWidget);
    });
  });
}
