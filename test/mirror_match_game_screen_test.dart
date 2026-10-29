import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gridmind/screens/mirror_match_game_screen.dart';
import 'package:gridmind/models/game_metadata.dart';
import 'package:gridmind/services/game_registry.dart';

void main() {
  group('MirrorMatchGameScreen Widget Tests', () {
    testWidgets('renders screen in vertical symmetry mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MirrorMatchGameScreen(
            gridSize: 4,
            symmetryType: 'vertical',
            moveMode: 'zen',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MirrorMatchGameScreen), findsOneWidget);
      expect(find.text('Moves'), findsOneWidget);
      expect(find.text('--'), findsOneWidget);
    });

    testWidgets('clue cells are not interactive, player cells are interactive', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MirrorMatchGameScreen(
            gridSize: 4,
            symmetryType: 'vertical',
            moveMode: 'zen',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gridFinder = find.byType(GridView);
      expect(gridFinder, findsOneWidget);

      final gridRect = tester.getRect(gridFinder);
      final cellW = gridRect.width / 4;
      final cellH = gridRect.height / 4;

      Offset getCellCenter(int r, int c) {
        return Offset(
          gridRect.left + (c + 0.5) * cellW,
          gridRect.top + (r + 0.5) * cellH,
        );
      }

      // Tap cell (0, 0) - static side
      await tester.tapAt(getCellCenter(0, 0));
      await tester.pumpAndSettle();
      expect(find.text('0'), findsOneWidget); // Moves remains 0

      // Tap cell (0, 2) - player side
      await tester.tapAt(getCellCenter(0, 2));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget); // Moves increments to 1
    });

    testWidgets('completing vertical symmetry wins the game', (WidgetTester tester) async {
      final testPattern = [
        [true, false, false, false],
        [false, false, false, false],
        [false, false, false, false],
        [false, false, false, false],
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: MirrorMatchGameScreen(
            gridSize: 4,
            symmetryType: 'vertical',
            moveMode: 'zen',
            testMode: true,
            testPattern: testPattern,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gridFinder = find.byType(GridView);
      final gridRect = tester.getRect(gridFinder);
      final cellW = gridRect.width / 4;
      final cellH = gridRect.height / 4;

      Offset getCellCenter(int r, int c) {
        return Offset(
          gridRect.left + (c + 0.5) * cellW,
          gridRect.top + (r + 0.5) * cellH,
        );
      }

      // Tap cell (0, 3) to mirror (0, 0)
      await tester.tapAt(getCellCenter(0, 3));
      await tester.pumpAndSettle();

      expect(find.text('Solved in 1 moves!'), findsOneWidget);
    });

    testWidgets('exceeding move limit in challenge mode triggers game over', (WidgetTester tester) async {
      final testPattern = [
        [true, false, false, false],
        [false, false, false, false],
        [false, false, false, false],
        [false, false, false, false],
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: MirrorMatchGameScreen(
            gridSize: 4,
            symmetryType: 'vertical',
            moveMode: 'challenge',
            testMode: true,
            testPattern: testPattern,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gridFinder = find.byType(GridView);
      final gridRect = tester.getRect(gridFinder);
      final cellW = gridRect.width / 4;
      final cellH = gridRect.height / 4;

      Offset getCellCenter(int r, int c) {
        return Offset(
          gridRect.left + (c + 0.5) * cellW,
          gridRect.top + (r + 0.5) * cellH,
        );
      }

      // Tap (0, 2) repeatedly to exceed move limit of 7
      for (int i = 0; i < 8; i++) {
        await tester.tapAt(getCellCenter(0, 2));
        await tester.pumpAndSettle();
      }

      expect(find.textContaining('Failed! Exceeded move limit'), findsOneWidget);
    });

    for (final n in [10, 12]) {
      testWidgets('grid size $n fits a 360x640 phone without overflow', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
          home: MirrorMatchGameScreen(gridSize: n, symmetryType: 'vertical', moveMode: 'zen'),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(GridView), findsOneWidget);
      });
    }

    test('setup slider offers sizes 4 to 12 in steps of 2', () {
      final game = GameRegistry.games.firstWhere((g) => g.id == 'mirror_match');
      final o = game.configOptions.firstWhere((o) => o.key == 'gridSize') as SliderConfigOption;
      expect((o.min, o.max, o.divisions), (4.0, 12.0, 4));
    });
  });
}
