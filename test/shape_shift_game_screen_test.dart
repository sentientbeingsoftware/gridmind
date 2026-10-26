import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gridmind/screens/shape_shift_game_screen.dart';

void main() {
  group('ShapeShiftGameScreen Widget Tests', () {
    testWidgets('renders Shape Shift screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ShapeShiftGameScreen(
            gridSize: 3,
            colorCount: 2,
            moveMode: 'zen',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ShapeShiftGameScreen), findsOneWidget);
      expect(find.text('Moves'), findsOneWidget);
      expect(find.text('--'), findsOneWidget);
    });

    testWidgets('tapping cells updates selection and swapping adjacent works', (WidgetTester tester) async {
      final targetPattern = [
        [Colors.red, Colors.blue, Colors.red],
        [Colors.blue, Colors.red, Colors.blue],
        [Colors.red, Colors.blue, Colors.red],
      ];
      final playerGrid = [
        [Colors.blue, Colors.red, Colors.red],
        [Colors.blue, Colors.red, Colors.blue],
        [Colors.red, Colors.blue, Colors.red],
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ShapeShiftGameScreen(
            gridSize: 3,
            colorCount: 2,
            moveMode: 'zen',
            testMode: true,
            testTargetPattern: targetPattern,
            testPlayerGrid: playerGrid,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gridFinder = find.byType(GridView).last;
      expect(gridFinder, findsOneWidget);

      final gridRect = tester.getRect(gridFinder);
      final cellW = gridRect.width / 3;
      final cellH = gridRect.height / 3;

      Offset getCellCenter(int r, int c) {
        return Offset(
          gridRect.left + (c + 0.5) * cellW,
          gridRect.top + (r + 0.5) * cellH,
        );
      }

      await tester.tapAt(getCellCenter(0, 0));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);

      await tester.tapAt(getCellCenter(2, 2));
      await tester.pumpAndSettle();
      expect(find.text('0'), findsOneWidget);

      await tester.tapAt(getCellCenter(0, 0));
      await tester.pumpAndSettle();

      await tester.tapAt(getCellCenter(0, 1));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('Solved in 1 moves!'), findsOneWidget);
    });

    testWidgets('exceeding move limit in challenge mode triggers game over', (WidgetTester tester) async {
      final targetPattern = [
        [Colors.red, Colors.blue, Colors.red],
        [Colors.blue, Colors.red, Colors.blue],
        [Colors.red, Colors.blue, Colors.red],
      ];
      final playerGrid = [
        [Colors.blue, Colors.red, Colors.red],
        [Colors.blue, Colors.red, Colors.blue],
        [Colors.red, Colors.blue, Colors.red],
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ShapeShiftGameScreen(
            gridSize: 3,
            colorCount: 2,
            moveMode: 'challenge',
            testMode: true,
            testTargetPattern: targetPattern,
            testPlayerGrid: playerGrid,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gridFinder = find.byType(GridView).last;
      final gridRect = tester.getRect(gridFinder);
      final cellW = gridRect.width / 3;
      final cellH = gridRect.height / 3;

      Offset getCellCenter(int r, int c) {
        return Offset(
          gridRect.left + (c + 0.5) * cellW,
          gridRect.top + (r + 0.5) * cellH,
        );
      }

      for (int i = 0; i < 16; i++) {
        await tester.tapAt(getCellCenter(1, 1));
        await tester.pumpAndSettle();
        await tester.tapAt(getCellCenter(1, 2));
        await tester.pumpAndSettle();
      }

      expect(find.textContaining('Failed! Exceeded move limit'), findsOneWidget);
    });
  });
}
