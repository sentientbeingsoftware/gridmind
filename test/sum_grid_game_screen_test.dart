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

    // 8x8 on a short phone: the screen scrolls, which used to steal vertical drags.
    Future<(SemanticsHandle, Map<(int, int), int>)> openBoard(WidgetTester t) async {
      t.view.physicalSize = const Size(360, 480);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final handle = t.ensureSemantics();
      await t.pumpWidget(const MaterialApp(
        home: SumGridGameScreen(gridSize: 8, gameMode: 'classic', targetMode: 'fixed'),
      ));
      await t.pumpAndSettle();
      final vals = <(int, int), int>{};
      for (final w in t.widgetList<Semantics>(find.byType(Semantics))) {
        final m = RegExp(r'^Row (\d+), column (\d+), (\d+)').firstMatch(w.properties.label ?? '');
        if (m != null) vals[(int.parse(m[1]!) - 1, int.parse(m[2]!) - 1)] = int.parse(m[3]!);
      }
      return (handle, vals);
    }

    Offset centre(WidgetTester t, int r, int c) {
      final g = t.getRect(find.byType(GridView));
      return Offset(g.left + (c + 0.5) * g.width / 8, g.top + (r + 0.5) * g.height / 8);
    }

    int selected(WidgetTester t) => t.widgetList<Semantics>(find.byType(Semantics))
        .where((w) => (w.properties.label ?? '').endsWith(', selected'))
        .length;

    testWidgets('vertical drag on the grid selects cells and does not scroll the screen', (t) async {
      final (handle, _) = await openBoard(t);
      final scroll = t.state<ScrollableState>(find.byType(Scrollable).first);
      final before = scroll.position.pixels;
      final g = await t.startGesture(centre(t, 0, 0));
      await g.moveTo(centre(t, 1, 0));
      await t.pump();
      await g.moveTo(centre(t, 2, 0));
      await t.pump();
      expect(scroll.position.pixels, before, reason: 'page scrolled during the drag');
      expect(selected(t), greaterThan(0));
      await g.up();
      handle.dispose();
    });

    testWidgets('tap selects a neighbour, tap the last cell again to deselect', (t) async {
      final (handle, v) = await openBoard(t);
      // Two neighbours whose sum stays under the target of 10, so nothing clears or scores.
      final pair = [for (final e in v.entries) if (e.key.$2 < 7 && e.value + v[(e.key.$1, e.key.$2 + 1)]! < 10) e.key].first;
      final a = pair, b = (pair.$1, pair.$2 + 1);
      await t.tapAt(centre(t, a.$1, a.$2));
      await t.pump();
      expect(selected(t), 1);
      await t.tapAt(centre(t, b.$1, b.$2));
      await t.pump();
      expect(selected(t), 2, reason: 'second tap should add the neighbour');
      await t.tapAt(centre(t, b.$1, b.$2));
      await t.pump();
      expect(selected(t), 1, reason: 'tapping the last cell should deselect it');
      handle.dispose();
    });
  });
}
