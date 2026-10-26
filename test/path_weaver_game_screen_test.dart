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
      of: find.byType(Listener),
      matching: find.byType(GestureDetector),
    );
    final RenderBox rBox = tester.renderObject(gridFinder.first);
    final gridPosition = rBox.localToGlobal(Offset.zero);
    final size = rBox.size;
    final cellWidth = size.width / gridSize;
    final cellHeight = size.height / gridSize;
    final tapPos = gridPosition + Offset(cellWidth * (c + 0.5), cellHeight * (r + 0.5));
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
}
