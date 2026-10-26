import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/territory_game_screen.dart';
import 'package:gridmind/services/app_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('TerritoryGameScreen Widget Tests', () {
    testWidgets('renders Territory game screen and claims cells in Zen mode', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: TerritoryGameScreen(
            gridSize: 3,
            targetArea: 4,
            moveMode: 'zen',
            testMode: true,
          ),
        ),
      );

      // Verify initial UI elements
      expect(find.text('Score'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Claimed 0/4'), findsOneWidget);

      // Find cells in GridView. Standard GestureDetector container margin and decoration.
      // Grid has 3x3 = 9 cells. Let's tap the first cell.
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      // Verify state updates
      expect(find.text('Score'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Claimed 1/4'), findsOneWidget);

      // Re-tapping a claimed cell claims nothing new but still costs a move.
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Claimed 1/4'), findsOneWidget);
    });

    testWidgets('winning in Zen mode shows victory message', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: TerritoryGameScreen(
            gridSize: 3,
            targetArea: 2,
            moveMode: 'zen',
            testMode: true,
          ),
        ),
      );

      // Tap 2 unique cells to win
      final finders = find.byType(GestureDetector);
      await tester.tap(finders.at(0));
      await tester.pump();
      await tester.tap(finders.at(1));
      await tester.pump();

      // Verify victory message
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
            targetArea: 3,
            moveMode: 'challenge',
            maxMoves: 2,
            testMode: true,
          ),
        ),
      );

      final finders = find.byType(GestureDetector);
      // Make 2 moves
      await tester.tap(finders.at(0));
      await tester.pump();
      await tester.tap(finders.at(1));
      await tester.pump();

      // We had a limit of 2 moves but targetArea of 3. We didn't reach target area.
      // So game over should trigger
      expect(find.text('Game Over - No more moves.'), findsOneWidget);
    });

    testWidgets('wasted re-taps can lose challenge mode', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(
        home: TerritoryGameScreen(
            gridSize: 3, targetArea: 3, moveMode: 'challenge', maxMoves: 5, testMode: true),
      ));
      final cells = find.byType(GestureDetector);
      for (var i = 0; i < 5; i++) {
        await tester.tap(cells.at(0)); // same cell, never reaches 3 claimed
        await tester.pump();
      }
      expect(find.text('Game Over - No more moves.'), findsOneWidget);
    });

    testWidgets('a win saves fewest moves; a worse win does not overwrite it', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cfg = {'gridSize': 3.0, 'targetArea': 2.0, 'moveMode': 'zen'};

      Future<void> play(List<int> taps) async {
        await tester.pumpWidget(const MaterialApp(
          home: TerritoryGameScreen(gridSize: 3, targetArea: 2, moveMode: 'zen', testMode: true),
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

      await play([0, 0, 0, 1]); // 4 moves
      final svc = AppPersistenceService();
      expect(await tester.runAsync(() => svc.getConfigHighScore('territory', cfg)), 4);
      await play([0, 1]); // 2 moves: better
      expect(await tester.runAsync(() => svc.getConfigHighScore('territory', cfg)), 2);
      await play([0, 0, 1]); // 3 moves: worse, ignored
      expect(await tester.runAsync(() => svc.getConfigHighScore('territory', cfg)), 2);
    });
  });
}
