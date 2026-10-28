import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/base_game_screen.dart';

void main() {
  // Undo + Restart + Exit must fit a 360 px phone at 150% system text.
  testWidgets('BaseGameScreen button row does not overflow at 150% text', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.5)),
        child: child!,
      ),
      home: BaseGameScreen(
        title: 'T',
        gameId: 'x',
        gameConfig: const {},
        highScoreLabel: 'Best Time Left',
        currentScoreLabel: 'Words Found',
        highScoreValue: '1',
        currentScoreValue: '2',
        onUndo: () {},
        onReset: () {},
        child: const SizedBox(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
