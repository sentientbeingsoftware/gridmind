import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gridmind/screens/simon_game_screen.dart';
import 'package:gridmind/models/pattern_speed.dart';

void main() {
  group('SimonGameScreen Widget Tests', () {
    testWidgets('renders with default params', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SimonGameScreen(
            numberOfSquares: 4,
            patternSpeed: PatternSpeed.normal,
            testMode: true,
            skipInitialDelay: true,
            testColors: [Colors.red, Colors.green, Colors.blue, Colors.yellow],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SimonGameScreen), findsOneWidget);
    });

    // Add more widget tests for gameplay, sequence, win/lose, etc.
  });

  for (final n in [7, 8, 9]) {
    testWidgets('$n squares fit a 320x568 phone without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: SimonGameScreen(
          numberOfSquares: n,
          patternSpeed: PatternSpeed.normal,
          testMode: true,
          skipInitialDelay: true,
          testColors: List.filled(n, Colors.red),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });
  }
}
