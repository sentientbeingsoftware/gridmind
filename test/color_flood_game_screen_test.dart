import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gridmind/screens/color_flood_game_screen.dart';

void main() {
  group('ColorFloodGameScreen Widget Tests', () {
    testWidgets('14 colours on a 360x640 phone do not overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(const MaterialApp(
        home: ColorFloodGameScreen(gridSize: 8, colorCount: 14, moveMode: 'zen'),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders Color Flood screen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ColorFloodGameScreen(
            gridSize: 3,
            colorCount: 3,
            moveMode: 'zen',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ColorFloodGameScreen), findsOneWidget);
      expect(find.text('Moves'), findsOneWidget);
      expect(find.text('--'), findsOneWidget);
    });

    testWidgets('tapping color buttons floods connected cells and updates moves', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testGrid = [
        [Colors.red, Colors.blue, Colors.red],
        [Colors.blue, Colors.red, Colors.blue],
        [Colors.red, Colors.blue, Colors.red],
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ColorFloodGameScreen(
            gridSize: 3,
            colorCount: 3,
            moveMode: 'zen',
            testMode: true,
            testGrid: testGrid,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final blueButtonFinder = find.byWidgetPredicate(
        (widget) => widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == Colors.blue &&
            (widget.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(blueButtonFinder, findsOneWidget);

      await tester.tap(blueButtonFinder);
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('completing flood wins the game', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testGrid = [
        [Colors.red, Colors.blue],
        [Colors.blue, Colors.blue],
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ColorFloodGameScreen(
            gridSize: 2,
            colorCount: 2,
            moveMode: 'zen',
            testMode: true,
            testGrid: testGrid,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final blueButtonFinder = find.byWidgetPredicate(
        (widget) => widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == Colors.blue &&
            (widget.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(blueButtonFinder, findsOneWidget);

      await tester.tap(blueButtonFinder);
      await tester.pumpAndSettle();

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
        [Colors.red, Colors.blue, Colors.green],
        [Colors.blue, Colors.green, Colors.red],
        [Colors.green, Colors.red, Colors.blue],
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ColorFloodGameScreen(
            gridSize: 3,
            colorCount: 3,
            moveMode: 'challenge',
            testMode: true,
            testGrid: testGrid,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final redButtonFinder = find.byWidgetPredicate(
        (widget) => widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == Colors.red &&
            (widget.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      final blueButtonFinder = find.byWidgetPredicate(
        (widget) => widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == Colors.blue &&
            (widget.decoration as BoxDecoration).shape == BoxShape.circle,
      );

      for (int i = 0; i < 6; i++) {
        await tester.tap(blueButtonFinder);
        await tester.pumpAndSettle();
        await tester.tap(redButtonFinder);
        await tester.pumpAndSettle();
      }

      expect(find.textContaining('Failed! Exceeded move limit'), findsOneWidget);
    });
  });
}
