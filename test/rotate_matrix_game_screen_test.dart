import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gridmind/screens/rotate_matrix_game_screen.dart';

void main() {
  group('RotateMatrixGameScreen Widget Tests', () {
    testWidgets('renders Rotate Matrix screen in challenge mode', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: RotateMatrixGameScreen(
            gridSize: 4,
            difficulty: 'medium',
            moveMode: 'challenge',
            testMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RotateMatrixGameScreen), findsOneWidget);
      expect(find.text('Moves'), findsOneWidget);
      expect(find.text('Target Pattern:'), findsOneWidget);
    });

    testWidgets('tapping rotate buttons updates moves and rotates quadrant', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // A simple 4x4 grid for testing (with 2x2 quadrants)
      final testGrid = [
        [Colors.red, Colors.blue, Colors.white, Colors.white],
        [Colors.green, Colors.yellow, Colors.white, Colors.white],
        [Colors.white, Colors.white, Colors.white, Colors.white],
        [Colors.white, Colors.white, Colors.white, Colors.white],
      ];
      final testTarget = [
        [Colors.green, Colors.red, Colors.white, Colors.white],
        [Colors.yellow, Colors.blue, Colors.white, Colors.white],
        [Colors.white, Colors.white, Colors.white, Colors.white],
        [Colors.white, Colors.white, Colors.white, Colors.white],
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: RotateMatrixGameScreen(
            gridSize: 4,
            difficulty: 'medium',
            moveMode: 'zen',
            testMode: true,
            testGrid: testGrid,
            testTarget: testTarget,
            testMaxMoves: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap rotate right (clockwise)
      final rotateRightButton = find.byIcon(Icons.rotate_right);
      expect(rotateRightButton, findsOneWidget);

      await tester.tap(rotateRightButton);
      await tester.pumpAndSettle();

      // Verified moves incremented to 1
      expect(find.text('1'), findsOneWidget);

      // Verify that after 1 clockwise rotation, the grid:
      // [red, blue] -> [green, red]
      // [green, yellow] -> [yellow, blue]
      // which matches testTarget, so it should trigger victory!
      expect(find.text('Solved in 1 moves!'), findsOneWidget);
    });

    testWidgets('exceeding move limit in challenge mode triggers game over', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testGrid = [
        [Colors.red, Colors.blue, Colors.white, Colors.white],
        [Colors.green, Colors.yellow, Colors.white, Colors.white],
        [Colors.white, Colors.white, Colors.white, Colors.white],
        [Colors.white, Colors.white, Colors.white, Colors.white],
      ];
      final testTarget = [
        [Colors.blue, Colors.yellow, Colors.white, Colors.white],
        [Colors.red, Colors.green, Colors.white, Colors.white],
        [Colors.white, Colors.white, Colors.white, Colors.white],
        [Colors.white, Colors.white, Colors.white, Colors.white],
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: RotateMatrixGameScreen(
            gridSize: 4,
            difficulty: 'medium',
            moveMode: 'challenge',
            testMode: true,
            testGrid: testGrid,
            testTarget: testTarget,
            testMaxMoves: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap rotate right (clockwise) - triggers 1 move
      final rotateRightButton = find.byIcon(Icons.rotate_right);
      await tester.tap(rotateRightButton);
      await tester.pumpAndSettle();

      // Moves = 1 (equals max limit 1, and target is not matched)
      // Should show game over overlay
      expect(find.text('Move limit exceeded! Try again.'), findsOneWidget);
    });
  });
}
