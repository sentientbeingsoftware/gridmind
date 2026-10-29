import 'dart:collection';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gridmind/screens/path_weaver_game_screen.dart';
import 'dart:math';

void main() {
  // Helper to get color of a cell decoration at row r, column c
  Color? getCellColor(WidgetTester tester, int r, int c, int gridSize) {
    final idx = r * gridSize + c;
    final containerFinder = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(Container),
    );
    final container = tester.widget<Container>(containerFinder.at(idx));
    final decoration = container.decoration as BoxDecoration?;
    return decoration?.color;
  }

  // Helper to tap a cell relative to the grid detector
  Future<void> tapCell(WidgetTester tester, int r, int c, int gridSize) async {
    final gridFinder = find.descendant(
      of: find.byType(AspectRatio),
      matching: find.byType(GestureDetector),
    );
    // getRect applies ancestor transforms, so this stays correct when the
    // shell scales the board down to fit a short window.
    final rect = tester.getRect(gridFinder.first);
    final cellWidth = rect.width / gridSize;
    final cellHeight = rect.height / gridSize;
    final tapPos = rect.topLeft + Offset(cellWidth * (c + 0.5), cellHeight * (r + 0.5));
    await tester.tapAt(tapPos);
    await tester.pumpAndSettle();
  }

  testWidgets('PathWeaverGameScreen renders and auto-wins in test mode', (WidgetTester tester) async {
    final List<Point<int>> testPath = [
      const Point(0, 0),
      const Point(0, 1),
      const Point(0, 2),
      const Point(0, 3),
      const Point(0, 4),
      const Point(1, 4),
      const Point(2, 4),
      const Point(3, 4),
      const Point(4, 4),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: PathWeaverGameScreen(
          gridSize: 5,
          obstacleDensity: 0.0,
          oneWayPaths: false,
          powerUps: false,
          testMode: true,
          testPath: testPath,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Path Weaver'), findsOneWidget);
    expect(find.text('You Win!'), findsOneWidget);
  });

  testWidgets('PathWeaverGameScreen renders custom testGrid with obstacles, one-ways, and power-ups', (WidgetTester tester) async {
    final testGrid = [
      [PathCell(isStart: true), PathCell(isObstacle: true), PathCell()],
      [PathCell(isOneWay: true, oneWayDirection: const Offset(1, 0)), PathCell(isPowerUp: true), PathCell()],
      [PathCell(), PathCell(), PathCell(isEnd: true)],
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: PathWeaverGameScreen(
          gridSize: 3,
          obstacleDensity: 0.0,
          oneWayPaths: true,
          powerUps: true,
          testMode: true,
          testGrid: testGrid,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify cell colors
    expect(getCellColor(tester, 0, 0, 3), equals(Colors.blue)); // Start
    expect(getCellColor(tester, 0, 1, 3), equals(Colors.black)); // Obstacle
    expect(getCellColor(tester, 1, 0, 3), equals(Colors.purple.shade200)); // OneWay
    expect(getCellColor(tester, 1, 1, 3), equals(Colors.amber)); // PowerUp
    expect(getCellColor(tester, 2, 2, 3), equals(Colors.red)); // End
  });

  testWidgets('PathWeaverGameScreen gameplay: valid tap, obstacle tap, one-way alignment, and win condition', (WidgetTester tester) async {
    final testGrid = [
      [PathCell(isStart: true), PathCell(isObstacle: true), PathCell()],
      [PathCell(isOneWay: true, oneWayDirection: const Offset(1, 0)), PathCell(), PathCell()],
      [PathCell(), PathCell(), PathCell(isEnd: true)],
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: PathWeaverGameScreen(
          gridSize: 3,
          obstacleDensity: 0.0,
          oneWayPaths: true,
          powerUps: false,
          testMode: true,
          testGrid: testGrid,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Try tapping obstacle at (0, 1). Should be blocked.
    await tapCell(tester, 0, 1, 3);
    expect(getCellColor(tester, 0, 1, 3), equals(Colors.black)); // Remains black/obstacle

    // 2. Tap (1, 0) which is a one-way pointing down.
    // Moving (0, 0) -> (1, 0) is down (row offset = 1, col offset = 0), matching Offset(1, 0).
    await tapCell(tester, 1, 0, 3);
    expect(getCellColor(tester, 1, 0, 3), equals(Colors.greenAccent)); // Successfully traversed

    // 3. Tap (2, 0) -> empty space.
    await tapCell(tester, 2, 0, 3);
    expect(getCellColor(tester, 2, 0, 3), equals(Colors.greenAccent));

    // 4. Tap (2, 1) -> empty space.
    await tapCell(tester, 2, 1, 3);
    expect(getCellColor(tester, 2, 1, 3), equals(Colors.greenAccent));

    // 5. Tap (2, 2) -> End.
    await tapCell(tester, 2, 2, 3);
    expect(find.text('You Win!'), findsOneWidget);
  });

  testWidgets('PathWeaverGameScreen gameplay: one-way direction mismatch blocks move', (WidgetTester tester) async {
    final testGrid = [
      [PathCell(isStart: true), PathCell(isOneWay: true, oneWayDirection: const Offset(-1, 0)), PathCell()],
      [PathCell(), PathCell(), PathCell()],
      [PathCell(), PathCell(), PathCell(isEnd: true)],
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: PathWeaverGameScreen(
          gridSize: 3,
          obstacleDensity: 0.0,
          oneWayPaths: true,
          powerUps: false,
          testMode: true,
          testGrid: testGrid,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tapping (0, 1) which points UP Offset(-1, 0) from (0, 0) is a DOWN/RIGHT move, which is incorrect.
    await tapCell(tester, 0, 1, 3);
    expect(getCellColor(tester, 0, 1, 3), equals(Colors.purple.shade200)); // Remains purple (not traversed)
  });

  testWidgets('PathWeaverGameScreen gameplay: power-up clears neighboring obstacles', (WidgetTester tester) async {
    final testGrid = [
      [PathCell(isStart: true), PathCell(), PathCell(isObstacle: true)],
      [PathCell(isPowerUp: true), PathCell(isObstacle: true), PathCell()],
      [PathCell(), PathCell(), PathCell(isEnd: true)],
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: PathWeaverGameScreen(
          gridSize: 3,
          obstacleDensity: 0.0,
          oneWayPaths: false,
          powerUps: true,
          testMode: true,
          testGrid: testGrid,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial obstacle at (1, 1) is black
    expect(getCellColor(tester, 1, 1, 3), equals(Colors.black));

    // Move to (1, 0) which is the power-up
    await tapCell(tester, 1, 0, 3);

    // Obstacle at (1, 1) should now be cleared (should be white/grey)
    expect(getCellColor(tester, 1, 1, 3), equals(Colors.white));
  });

  testWidgets('PathWeaverGameScreen gameplay: undo button removes last move', (WidgetTester tester) async {
    final testGrid = [
      [PathCell(isStart: true), PathCell(), PathCell()],
      [PathCell(), PathCell(), PathCell()],
      [PathCell(), PathCell(), PathCell(isEnd: true)],
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: PathWeaverGameScreen(
          gridSize: 3,
          obstacleDensity: 0.0,
          oneWayPaths: false,
          powerUps: false,
          testMode: true,
          testGrid: testGrid,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Move to (1, 0)
    await tapCell(tester, 1, 0, 3);
    expect(getCellColor(tester, 1, 0, 3), equals(Colors.greenAccent));

    // Tap Undo
    final undoFinder = find.widgetWithIcon(ElevatedButton, Icons.undo);
    await tester.tap(undoFinder);
    await tester.pumpAndSettle();

    // (1, 0) should be reverted to white
    expect(getCellColor(tester, 1, 0, 3), equals(Colors.white));
  });

  testWidgets('PathWeaverGameScreen gameplay: no valid moves triggers Game Over', (WidgetTester tester) async {
    // Start is at (0,0). Valid move is only to (0,1).
    // (1,0) is blocked by obstacle, (1,1) is blocked, (0,2) is blocked.
    final testGrid = [
      [PathCell(isStart: true), PathCell(), PathCell(isObstacle: true)],
      [PathCell(isObstacle: true), PathCell(isObstacle: true), PathCell()],
      [PathCell(), PathCell(), PathCell(isEnd: true)],
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: PathWeaverGameScreen(
          gridSize: 3,
          obstacleDensity: 0.0,
          oneWayPaths: false,
          powerUps: false,
          testMode: true,
          testGrid: testGrid,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial state is not Game Over yet
    expect(find.text('No more moves! Game Over.'), findsNothing);

    // Tap (0, 1) to make the only valid move.
    await tapCell(tester, 0, 1, 3);

    // Now player has no valid directions left. The game should show Game Over.
    expect(find.text('No more moves! Game Over.'), findsOneWidget);
  });

  testWidgets('PathWeaverGameScreen non-testMode generates grid safely with oneWayPaths without hanging', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PathWeaverGameScreen(
          gridSize: 5,
          obstacleDensity: 0.2,
          oneWayPaths: true,
          powerUps: true,
          testMode: false,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Path Weaver'), findsOneWidget);
  });

  // --- generator: winding maps and a one-way square that cannot be avoided ---
  List<List<PathCell>> newGrid(int n) {
    final g = List.generate(n, (_) => List.generate(n, (_) => PathCell()));
    g[0][0].isStart = true;
    g[n - 1][n - 1].isEnd = true;
    return g;
  }

  // Shortest length from corner to corner, or null. [canEnter] decides each step.
  int? shortest(List<List<PathCell>> g, bool Function(int fromR, int fromC, int r, int c) canEnter) {
    final n = g.length;
    final dist = {const Point(0, 0): 0};
    final q = Queue<Point<int>>()..add(const Point(0, 0));
    while (q.isNotEmpty) {
      final p = q.removeFirst();
      if (p.x == n - 1 && p.y == n - 1) return dist[p];
      for (final d in const [Point(1, 0), Point(-1, 0), Point(0, 1), Point(0, -1)]) {
        final r = p.x + d.x, c = p.y + d.y;
        if (r < 0 || r >= n || c < 0 || c >= n || dist.containsKey(Point(r, c)) || !canEnter(p.x, p.y, r, c)) continue;
        dist[Point(r, c)] = dist[p]! + 1;
        q.add(Point(r, c));
      }
    }
    return null;
  }

  bool oneWayOk(List<List<PathCell>> g, int fr, int fc, int r, int c) {
    final cell = g[r][c];
    if (cell.isOneWay && cell.oneWayDirection != null) {
      return Offset((r - fr).toDouble(), (c - fc).toDouble()) == cell.oneWayDirection;
    }
    return true;
  }

  test('every generated board is solvable, and with One-Way Paths a one-way square is unavoidable', () {
    final rand = Random(11);
    for (final n in [5, 7, 9, 12]) {
      for (final density in [0.0, 0.15, 0.4]) {
        for (final powerUps in [false, true]) {
          for (var i = 0; i < 25; i++) {
            final g = newGrid(n);
            layoutPathWeaverGrid(g, obstacleDensity: density, oneWayPaths: true, powerUps: powerUps, rand: rand);
            final why = 'n=$n density=$density powerUps=$powerUps';
            // The game's own rules (obstacles block, one-ways only along their arrow): reachable.
            expect(shortest(g, (fr, fc, r, c) => !g[r][c].isObstacle && oneWayOk(g, fr, fc, r, c)), isNotNull, reason: 'unsolvable: $why');
            // Treat one-way squares as walls and let every power-up clear its 3x3: still no way through.
            bool nearPowerUp(int r, int c) => [
                  for (var a = -1; a <= 1; a++)
                    for (var b = -1; b <= 1; b++)
                      if (r + a >= 0 && r + a < n && c + b >= 0 && c + b < n && g[r + a][c + b].isPowerUp) 1
                ].isNotEmpty;
            final avoidable = shortest(g, (fr, fc, r, c) => !g[r][c].isOneWay && (!g[r][c].isObstacle || nearPowerUp(r, c)));
            expect(avoidable, isNull, reason: 'a one-way square can be avoided: $why');
          }
        }
      }
    }
  });

  test('without One-Way Paths nothing is one-way and the board is still solvable', () {
    final rand = Random(5);
    for (var i = 0; i < 40; i++) {
      final g = newGrid(8);
      layoutPathWeaverGrid(g, obstacleDensity: 0.4, oneWayPaths: false, powerUps: true, rand: rand);
      expect(g.expand((row) => row).any((c) => c.isOneWay), isFalse);
      expect(shortest(g, (fr, fc, r, c) => !g[r][c].isObstacle), isNotNull);
    }
  });

  test('at 40% density the route is much longer than the straight line (maps are no longer open)', () {
    final rand = Random(3);
    for (final n in [7, 9, 12]) {
      var total = 0.0;
      const boards = 20;
      for (var i = 0; i < boards; i++) {
        final g = newGrid(n);
        layoutPathWeaverGrid(g, obstacleDensity: 0.4, oneWayPaths: false, powerUps: false, rand: rand);
        total += shortest(g, (fr, fc, r, c) => !g[r][c].isObstacle)! / (2 * n - 2);
      }
      // Random obstacles gave 1.02-1.04 here (almost always a straight staircase).
      expect(total / boards, greaterThan(1.4), reason: 'n=$n');
    }
  });

  testWidgets('help button explains one-way paths', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PathWeaverGameScreen(gridSize: 5, obstacleDensity: 0.2, oneWayPaths: true, powerUps: true, testMode: true),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pumpAndSettle();
    expect(find.text('How to Play Path Weaver'), findsOneWidget);
    expect(find.textContaining('you must use one'), findsOneWidget);
  });
}
