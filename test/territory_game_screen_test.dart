import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/territory_game_screen.dart';
import 'package:gridmind/services/app_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('TerritoryGameScreen Widget Tests', () {
    testWidgets('claims only cells adjacent to territory and ignores non-adjacent or re-taps', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: TerritoryGameScreen(
            gridSize: 3,
            targetArea: 10,
            moveMode: 'zen',
            testMode: true,
            testValues: [1, 2, 3, 1, 2, 3, 1, 2, 3],
          ),
        ),
      );

      expect(find.text('Captured 0/10'), findsOneWidget);
      final cells = find.byType(GestureDetector);

      // Cell 8 (bottom-right) is not adjacent to cell 0 -> ignored
      await tester.tap(cells.at(8));
      await tester.pump();
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Captured 0/10'), findsOneWidget);

      // Cell 1 (top-middle, value 2) is adjacent to cell 0 -> claimed
      await tester.tap(cells.at(1));
      await tester.pump();
      expect(find.text('Captured 2/10'), findsOneWidget);

      // Re-tapping cell 1 is ignored
      await tester.tap(cells.at(1));
      await tester.pump();
      expect(find.text('Captured 2/10'), findsOneWidget);
    });

    testWidgets('winning in Zen mode shows victory message and clamps oversized target', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // All values 1; max achievable on 3x3 (8 claimable cells) is 8.
      await tester.pumpWidget(
        const MaterialApp(
          home: TerritoryGameScreen(
            gridSize: 3,
            targetArea: 15,
            moveMode: 'zen',
            testMode: true,
            testValues: [1, 1, 1, 1, 1, 1, 1, 1, 1],
          ),
        ),
      );

      expect(find.text('Captured 0/8'), findsOneWidget);

      final cells = find.byType(GestureDetector);
      for (final idx in [1, 2, 5, 4, 3, 6, 7, 8]) {
        await tester.tap(cells.at(idx));
        await tester.pump();
      }

      expect(find.text('Victory! Territory captured.'), findsOneWidget);
    });

    testWidgets('challenge mode limits moves and triggers game over', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: TerritoryGameScreen(
            gridSize: 3,
            targetArea: 6,
            moveMode: 'challenge',
            maxMoves: 2,
            testMode: true,
            testValues: [1, 1, 1, 1, 1, 1, 1, 1, 1],
          ),
        ),
      );

      final cells = find.byType(GestureDetector);
      await tester.tap(cells.at(1));
      await tester.pump();
      await tester.tap(cells.at(2));
      await tester.pump();

      expect(find.text('Game Over - No more moves.'), findsOneWidget);
    });

    testWidgets('a win saves fewest moves; a worse win does not overwrite it', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cfg = {'gridSize': 3.0, 'targetArea': 3.0, 'moveMode': 'zen'};
      // Cell 1 = 3 pts (1-move win), cells 3 & 6 = 2 + 1 pts (2-move win).
      const board = [1, 3, 1, 2, 1, 1, 1, 1, 1];

      Future<void> play(List<int> taps) async {
        await tester.pumpWidget(const MaterialApp(
          home: TerritoryGameScreen(
            gridSize: 3,
            targetArea: 3,
            moveMode: 'zen',
            testMode: true,
            testValues: board,
          ),
        ));
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
        final cells = find.byType(GestureDetector);
        for (final i in taps) {
          await tester.tap(cells.at(i));
          await tester.pump();
        }
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pumpWidget(const SizedBox());
      }

      await play([3, 6]); // 2 moves
      final svc = AppPersistenceService();
      expect(await tester.runAsync(() => svc.getConfigHighScore('territory', cfg)), 2);
      await play([1]); // 1 move: better
      expect(await tester.runAsync(() => svc.getConfigHighScore('territory', cfg)), 1);
      await play([3, 6]); // 2 moves: worse, ignored
      expect(await tester.runAsync(() => svc.getConfigHighScore('territory', cfg)), 1);
    });
  });
}
