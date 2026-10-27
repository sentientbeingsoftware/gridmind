import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/slide_and_solve_game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // On a compact phone the shell scales the game area down. A drag must still
  // register as a move on the scaled board.
  testWidgets('dragging a row on a scaled-down board still counts a move', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(const MaterialApp(home: SlideAndSolveGameScreen(gridSize: 3)));
    await t.runAsync(() async => Future.delayed(const Duration(milliseconds: 100)));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);

    final tile = t.getRect(
      find.byWidgetPredicate((w) => w is GestureDetector && w.onHorizontalDragStart != null).first,
    );

    expect(find.text('0'), findsWidgets); // Moves: 0
    final g = await t.startGesture(tile.center);
    for (var i = 0; i < 8; i++) {
      await g.moveBy(const Offset(-10, 0));
      await t.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await t.pumpAndSettle();
    expect(find.text('1'), findsWidgets); // Moves: 1
  });
}
