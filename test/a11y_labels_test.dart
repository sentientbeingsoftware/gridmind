import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/binary_lights_game_screen.dart';
import 'package:gridmind/screens/color_flood_game_screen.dart';
import 'package:gridmind/screens/territory_game_screen.dart';
import 'package:gridmind/screens/slide_and_solve_game_screen.dart';
import 'package:gridmind/screens/sequence_trail_game_screen.dart';
import 'package:gridmind/screens/grid_runner_game_screen.dart';
import 'package:gridmind/screens/path_weaver_game_screen.dart';
import 'package:gridmind/utils/color_names.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('colorName maps primary colours', () {
    expect(colorName(Colors.red), 'red');
    expect(colorName(Colors.blue), 'blue');
    expect(colorName(Colors.green), 'green');
    expect(colorName(Colors.black), 'black');
    expect(colorName(Colors.yellow), 'yellow');
  });

  testWidgets('Territory cells expose row, column, value and claimable state', (t) async {
    final h = t.ensureSemantics();
    t.view.physicalSize = const Size(800, 1200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const MaterialApp(
      home: TerritoryGameScreen(
        gridSize: 3, targetArea: 10, moveMode: 'zen', testMode: true,
        testValues: [1, 2, 3, 1, 2, 3, 1, 2, 3],
      ),
    ));
    await t.pump();
    expect(find.bySemanticsLabel('Start cell'), findsOneWidget);
    expect(find.bySemanticsLabel('Row 1, column 2, value 2, can claim'), findsOneWidget);
    expect(find.bySemanticsLabel('Row 3, column 3, value 3'), findsOneWidget);
    h.dispose();
  });

  testWidgets('Binary Lights and Color Flood controls are labelled', (t) async {
    final h = t.ensureSemantics();
    t.view.physicalSize = const Size(800, 1200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const MaterialApp(home: BinaryLightsGameScreen(gridSize: 3, gameMode: 'classic', moveMode: 'zen')));
    await t.pump();
    expect(find.bySemanticsLabel(RegExp(r'^Row 1, column 1, light (on|off)$')), findsOneWidget);
    await t.pumpWidget(const MaterialApp(home: ColorFloodGameScreen(gridSize: 3, colorCount: 3, moveMode: 'zen')));
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp(r'^Flood with ')), findsNWidgets(3));
    h.dispose();
  });

  Future<void> big(WidgetTester t) async {
    t.view.physicalSize = const Size(800, 1200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  testWidgets('Slide and Solve cells offer slide actions to screen readers', (t) async {
    final h = t.ensureSemantics();
    await big(t);
    await t.pumpWidget(const MaterialApp(home: SlideAndSolveGameScreen(gridSize: 3)));
    await t.runAsync(() async => Future.delayed(const Duration(milliseconds: 100)));
    await t.pumpAndSettle();
    final node = t.getSemantics(find.bySemanticsLabel(RegExp(r'^Row 1, column 1, ')));
    final actions = node.getSemanticsData().customSemanticsActionIds ?? [];
    expect(actions.length, 4);
    h.dispose();
  });

  testWidgets('Sequence Trail, Grid Runner and Path Weaver controls are labelled', (t) async {
    final h = t.ensureSemantics();
    await big(t);
    await t.pumpWidget(const MaterialApp(
      home: SequenceTrailGameScreen(gridSize: 3, timeLimit: 5.0, enableDecoys: false, enableMoving: false, lives: 3),
    ));
    await t.pump();
    expect(find.bySemanticsLabel(RegExp(r'^Row \d, column \d, number ')), findsWidgets);
    await t.pumpWidget(const MaterialApp(home: GridRunnerGameScreen(gridSize: 5, speed: 'normal', gemCount: 3)));
    await t.pump();
    expect(find.byTooltip('Move up'), findsOneWidget);
    await t.pumpWidget(const MaterialApp(
      home: PathWeaverGameScreen(gridSize: 4, obstacleDensity: 0.0, oneWayPaths: false, powerUps: false),
    ));
    await t.pump();
    expect(find.bySemanticsLabel('Row 1, column 1, start'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
    h.dispose();
  });
}
