import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/gravity_shift_game_screen.dart';
import 'package:gridmind/screens/grid_painter_game_screen.dart';
import 'package:gridmind/screens/grid_runner_game_screen.dart';

void _phoneView(WidgetTester t) {
  t.view.physicalSize = const Size(800, 1200);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

void main() {
  group('keyboard arrows / WASD', () {
    for (final key in [LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.keyD]) {
      testWidgets('Grid Runner: ${key.keyLabel} runs right like the D-pad', (t) async {
        _phoneView(t);
        await t.pumpWidget(const MaterialApp(
          home: GridRunnerGameScreen(
            gridSize: 4, speed: 'normal', gemCount: 1,
            testMode: true, testGems: [Point(2, 3)], testStart: Point(2, 2),
          ),
        ));
        await t.pumpAndSettle();
        await t.sendKeyEvent(key);
        await t.pumpAndSettle();
        expect(find.text('Success! Solved in 1 steps!'), findsOneWidget);
      });
    }

    testWidgets('Gravity Shift: up arrow = up button', (t) async {
      _phoneView(t);
      final e = Colors.transparent;
      await t.pumpWidget(MaterialApp(
        home: GravityShiftGameScreen(
          gridSize: 4, difficulty: 'medium', moveMode: 'zen', testMode: true,
          testGrid: [
            [e, e, e, e],
            [Colors.red, e, e, e],
            [e, e, e, e],
            [e, e, e, e],
          ],
          testTarget: [
            [Colors.red, e, e, e],
            [e, e, e, e],
            [e, e, e, e],
            [e, e, e, e],
          ],
          testMaxMoves: 5,
        ),
      ));
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await t.pumpAndSettle();
      expect(find.textContaining('Solved in'), findsOneWidget);
    });

    testWidgets('Grid Painter: arrow keys move the brush and count moves', (t) async {
      _phoneView(t);
      await t.pumpWidget(const MaterialApp(
        home: GridPainterGameScreen(gridSize: 3, gameMode: 'show', moveMode: 'zen'),
      ));
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.sendKeyEvent(LogicalKeyboardKey.keyD);
      await t.pumpAndSettle();
      expect(find.text('2'), findsWidgets); // Moves counter
    });
  });
}
