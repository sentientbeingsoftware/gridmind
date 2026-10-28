import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/grid_painter_game_screen.dart';
import 'package:gridmind/screens/path_weaver_game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// On a short screen the shell scales the game area down (or scrolls). Drags
// must still land on the right cells. Slide and Solve has its own test.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Small steps so the pan starts inside the first cell.
  Future<void> dragTo(WidgetTester t, TestGesture g, Offset from, Offset to) async {
    const steps = 12;
    for (var i = 1; i <= steps; i++) {
      await g.moveTo(Offset.lerp(from, to, i / steps)!);
      await t.pump(const Duration(milliseconds: 16));
    }
  }

  void smallScreen(WidgetTester t) {
    t.view.physicalSize = const Size(340, 480);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  testWidgets('Path Weaver: dragging along the top row on a small screen extends the path',
      (t) async {
    smallScreen(t);
    final grid = List.generate(
      4,
      (r) => List.generate(
        4,
        (c) => PathCell(isStart: r == 0 && c == 0, isEnd: r == 3 && c == 3),
      ),
    );
    await t.pumpWidget(MaterialApp(
      home: PathWeaverGameScreen(
        gridSize: 4,
        obstacleDensity: 0,
        oneWayPaths: false,
        powerUps: false,
        testMode: true,
        testGrid: grid,
      ),
    ));
    await t.pumpAndSettle();

    final rect = t.getRect(find
        .descendant(of: find.byType(AspectRatio), matching: find.byType(GestureDetector))
        .first);
    Offset cell(int r, int c) =>
        rect.topLeft + Offset(rect.width / 4 * (c + 0.5), rect.height / 4 * (r + 0.5));

    final g = await t.startGesture(cell(0, 0));
    for (final c in [1, 2, 3]) {
      await dragTo(t, g, cell(0, c - 1), cell(0, c));
    }
    await g.up();
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('3'), findsOneWidget); // Moves: 3
  });

  testWidgets('Grid Painter: dragging across the board on a small screen counts one move per cell',
      (t) async {
    smallScreen(t);
    final blueprint = List.generate(4, (r) => List.generate(4, (c) => r == 0));
    await t.pumpWidget(MaterialApp(
      home: GridPainterGameScreen(
        gridSize: 4,
        gameMode: 'show',
        moveMode: 'zen',
        testMode: true,
        testBlueprint: blueprint,
      ),
    ));
    await t.pumpAndSettle();

    final board = find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onPanStart != null && w.onPanUpdate != null);
    final rect = t.getRect(board.first);
    Offset cell(int r, int c) =>
        rect.topLeft + Offset(rect.width / 4 * (c + 0.5), rect.height / 4 * (r + 0.5));

    final g = await t.startGesture(cell(0, 0));
    for (final c in [1, 2, 3]) {
      await dragTo(t, g, cell(0, c - 1), cell(0, c));
    }
    await g.up();
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('3'), findsOneWidget); // Moves: 3 (one per cell crossed)
  });
}
