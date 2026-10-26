import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gridmind/screens/grid_runner_game_screen.dart';
import 'dart:math';

void main() {
  group('GridRunnerGameScreen Widget Tests', () {
    testWidgets('renders Grid Runner screen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: GridRunnerGameScreen(
            gridSize: 6,
            speed: 'normal',
            gemCount: 3,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GridRunnerGameScreen), findsOneWidget);
      expect(find.text('Steps'), findsOneWidget);
      expect(find.text('--'), findsOneWidget);
    });

    testWidgets('tapping D-pad triggers runner movement and gem collection wins the game', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testGems = [const Point(2, 3)];
      const testStart = Point(2, 2);

      await tester.pumpWidget(
        MaterialApp(
          home: GridRunnerGameScreen(
            gridSize: 4,
            speed: 'normal',
            gemCount: 1,
            testMode: true,
            testGems: testGems,
            testStart: testStart,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rightArrow = find.byIcon(Icons.keyboard_arrow_right);
      expect(rightArrow, findsOneWidget);

      await tester.tap(rightArrow);
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('Success! Solved in 1 steps!'), findsOneWidget);
    });

    testWidgets('hitting a wall triggers game over', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testGems = [const Point(3, 3)];
      const testStart = Point(0, 2);

      await tester.pumpWidget(
        MaterialApp(
          home: GridRunnerGameScreen(
            gridSize: 4,
            speed: 'normal',
            gemCount: 1,
            testMode: true,
            testGems: testGems,
            testStart: testStart,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final upArrow = find.byIcon(Icons.keyboard_arrow_up);
      expect(upArrow, findsOneWidget);

      await tester.tap(upArrow);
      await tester.pumpAndSettle();

      expect(find.text('Crashed! Game Over.'), findsOneWidget);
    });
  });
}
