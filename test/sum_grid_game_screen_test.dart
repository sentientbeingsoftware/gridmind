import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gridmind/screens/sum_grid_game_screen.dart';

void main() {
  group('SumGridGameScreen Widget Tests', () {
    testWidgets('renders Sum Grid screen in timed mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SumGridGameScreen(
            gridSize: 5,
            gameMode: 'timed',
            targetMode: 'random',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SumGridGameScreen), findsOneWidget);
      expect(find.textContaining('TARGET:'), findsOneWidget);
      expect(find.text('Score'), findsOneWidget);
    });

    testWidgets('renders Sum Grid screen in classic mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SumGridGameScreen(
            gridSize: 4,
            gameMode: 'classic',
            targetMode: 'fixed',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SumGridGameScreen), findsOneWidget);
      expect(find.text('TARGET: 10'), findsOneWidget);
      expect(find.text('Targets: 0/10'), findsOneWidget);
    });

    testWidgets('simulates selection/tap and drag on cells', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SumGridGameScreen(
            gridSize: 3,
            gameMode: 'classic',
            targetMode: 'fixed', // Target is fixed to 10
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the GridView which contains all the cells
      final gridFinder = find.byType(GridView);
      expect(gridFinder, findsOneWidget);

      final gridRect = tester.getRect(gridFinder);
      final cellW = gridRect.width / 3;
      final cellH = gridRect.height / 3;

      // Helper to get center offset of a cell at (row, col)
      Offset getCellCenter(int r, int c) {
        return Offset(
          gridRect.left + (c + 0.5) * cellW,
          gridRect.top + (r + 0.5) * cellH,
        );
      }

      // Tap on cell (0, 0)
      final center00 = getCellCenter(0, 0);
      await tester.tapAt(center00);
      await tester.pumpAndSettle();

      // Drag from cell (0, 0) to cell (0, 1)
      final center01 = getCellCenter(0, 1);
      final TestGesture gesture = await tester.startGesture(center00);
      await tester.pump();
      await gesture.moveTo(center01);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
