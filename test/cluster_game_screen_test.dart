import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/cluster_game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ClusterGameScreen Widget Tests', () {
    testWidgets('renders Cluster game screen and performs swap to increase cluster', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testGrid = [
        [Colors.blue, Colors.red, Colors.blue],
        [Colors.red, Colors.blue, Colors.red],
        [Colors.blue, Colors.red, Colors.blue],
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ClusterGameScreen(
            gridSize: 3,
            colorCount: 2,
            moveMode: 'challenge',
            testMode: true,
            testGrid: testGrid,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially max cluster size is 1
      expect(find.text('1/4'), findsOneWidget); // Max cluster of 1, target is (3*3*0.4).round() = 4
      // Verify initial moves
      expect(find.text('Moves: 0/9'), findsOneWidget);

      final cells = find.byType(GestureDetector);

      // Select cell (0, 0) - index 0
      await tester.tap(cells.at(0));
      await tester.pumpAndSettle();

      // Tap adjacent cell (0, 1) - index 1 to swap them
      await tester.tap(cells.at(1));
      await tester.pumpAndSettle();

      // Verification: moves incremented to 1
      expect(find.text('Moves: 1/9'), findsOneWidget);
      
      // The swap creates a cluster of 3 Blues.
      // So max cluster size is now 3.
      expect(find.text('3/4'), findsOneWidget);
    });

    testWidgets('reaching target cluster size triggers victory', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // A grid where a single swap will create a cluster of 4 Blues:
      // Row 0: [Blue, Blue, Red]
      // Row 1: [Red, Blue, Blue]
      // Row 2: [Red, Red, Red]
      // Tapping and swapping (1, 0) - Red and (1, 1) - Blue:
      // Row 1 becomes [Blue, Red, Blue]. That doesn't connect.
      // Wait, what if we have:
      // Row 0: [Blue, Blue, Red]
      // Row 1: [Blue, Red, Red]
      // Row 2: [Red, Red, Red]
      // Current Blue cluster at bottom/left is 3.
      // If we swap (0, 2) [Red] and (1, 2) [Red], nothing changes.
      // If we swap (1, 1) [Red] and (1, 0) [Blue] -> Row 1 becomes [Red, Blue, Red].
      // Let's design a simple starting grid:
      // Row 0: [Blue, Blue, Red]
      // Row 1: [Red, Blue, Red]
      // Row 2: [Red, Red, Red]
      // Max cluster of Blue is 3 (Row 0 Col 0, Row 0 Col 1, Row 1 Col 1).
      // Row 2 has all Reds (cluster of 3 + more).
      // Wait, if we swap (1, 0) [Red] and (2, 0) [Red] - nothing changes.
      // What if we swap (1, 2) [Red] and (1, 1) [Blue]?
      // Row 1 becomes [Red, Red, Blue].
      // Row 0 is [Blue, Blue, Red].
      // Blues are at (0, 0), (0, 1), (1, 2) - not connected.
      // What if we swap (0, 2) [Red] and (1, 2) [Red]?
      // Let's use a simpler grid:
      // Row 0: [Blue, Red, Blue]
      // Row 1: [Blue, Blue, Red]
      // Row 2: [Red, Red, Red]
      // Blues are: (0, 0), (1, 0), (1, 1), (0, 2). Size of largest Blue cluster is 3.
      // If we swap (0, 1) [Red] and (0, 2) [Blue] -> Row 0 becomes [Blue, Blue, Red].
      // Now Blues are at (0, 0), (0, 1), (1, 0), (1, 1) -> forms a 2x2 square cluster of 4 Blues!
      // This cluster size is 4, which is >= target cluster size of 4.
      // This should trigger victory!
      final testGrid = [
        [Colors.blue, Colors.red, Colors.blue],
        [Colors.blue, Colors.blue, Colors.red],
        [Colors.red, Colors.red, Colors.red],
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ClusterGameScreen(
            gridSize: 3,
            colorCount: 2,
            moveMode: 'challenge',
            testMode: true,
            testGrid: testGrid,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cells = find.byType(GestureDetector);

      // Select cell (0, 1) - index 1
      await tester.tap(cells.at(1));
      await tester.pumpAndSettle();

      // Tap adjacent cell (0, 2) - index 2 to swap
      await tester.tap(cells.at(2));
      await tester.pumpAndSettle();

      // Max cluster should now be 4, triggering victory
      expect(find.text('4/4'), findsOneWidget);
      expect(find.text('Victory! Target cluster reached.'), findsOneWidget);
    });
  });
}
