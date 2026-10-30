import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gridmind/screens/slide_and_solve_game_screen.dart';

void main() {
  group('SlideAndSolveGameScreen Widget Tests', () {
    testWidgets('renders with default grid size', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SlideAndSolveGameScreen(
            gridSize: 3,
            testMode: true,
            skipInitialDelay: true,
            testColors: [Colors.red, Colors.green, Colors.blue, Colors.yellow, Colors.orange, Colors.purple, Colors.cyan, Colors.brown, Colors.grey],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SlideAndSolveGameScreen), findsOneWidget);
    });

    // Add more widget tests for grid logic, win, moves, etc.
  });

  // Reported on a Pixel 6a: at 5x5 the bottom of the board was hidden behind Restart/Exit.
  for (final size in [4, 5]) {
    for (final phone in [const Size(411, 890), const Size(360, 640)]) {
      testWidgets('${size}x$size board is fully visible above the buttons on ${phone.width.toInt()}x${phone.height.toInt()}', (tester) async {
        final handle = tester.ensureSemantics();
        tester.view.physicalSize = phone;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
          home: SlideAndSolveGameScreen(
            gridSize: size,
            testMode: true,
            skipInitialDelay: true,
            testColors: const [Colors.red, Colors.green, Colors.blue, Colors.yellow, Colors.orange, Colors.purple, Colors.cyan, Colors.brown, Colors.grey],
          ),
        ));
        await tester.pumpAndSettle();
        final lastRow = tester.getRect(find.bySemanticsLabel(RegExp('^Row $size, column 1,')));
        final restart = tester.getRect(find.text('Restart'));
        expect(lastRow.bottom, lessThanOrEqualTo(restart.top), reason: 'last board row is under the buttons');
        expect(tester.takeException(), isNull);
        handle.dispose();
      });
    }
  }
}
