import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/base_game_screen.dart';

Widget _shell({
  bool won = false,
  bool over = false,
  String status = 'Your turn',
}) =>
    MaterialApp(
      home: BaseGameScreen(
        title: 'Test Game',
        highScoreValue: '12',
        currentScoreValue: '3',
        statusText: status,
        isGameWon: won,
        isGameOver: over,
        victoryMessage: 'Solved it!',
        gameOverMessage: 'Out of moves!',
        onHelp: () {},
        onReset: () {},
        onUndo: () {},
        child: const SizedBox(),
      ),
    );

void main() {
  testWidgets('app bar icon buttons have accessible labels', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_shell());

    // IconButton tooltips surface to screen readers as the semantics `tooltip`.
    for (final tip in ['Back to menu', 'How to play', 'Restart']) {
      final node = tester.getSemantics(find.byTooltip(tip));
      expect(node.tooltip, tip);
      expect(node.flagsCollection.isButton, isTrue, reason: tip);
    }
    handle.dispose();
  });

  testWidgets('HUD stat cards read as a single "label: value" item', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_shell());

    expect(find.bySemanticsLabel('Best: 12'), findsOneWidget);
    expect(find.bySemanticsLabel('Score: 3'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('status text and result banners are live regions', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(_shell());
    expect(tester.getSemantics(find.text('Your turn')).flagsCollection.isLiveRegion, isTrue);

    await tester.pumpWidget(_shell(won: true));
    expect(tester.getSemantics(find.text('Solved it!')).flagsCollection.isLiveRegion, isTrue);

    await tester.pumpWidget(_shell(over: true));
    expect(tester.getSemantics(find.text('Out of moves!')).flagsCollection.isLiveRegion, isTrue);
    handle.dispose();
  });
}
