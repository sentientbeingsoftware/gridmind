import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/base_game_screen.dart';

void main() {
  for (final h in [640.0, 480.0]) {
    testWidgets('game area is centred horizontally at 360x${h.toInt()}', (t) async {
      t.view.physicalSize = Size(360, h);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
        home: BaseGameScreen(
          title: 'T',
          onReset: () {},
          child: const Center(child: SizedBox(key: Key('board'), width: 200, height: 200)),
        ),
      ));
      await t.pump();
      expect(t.getCenter(find.byKey(const Key('board'))).dx, closeTo(180, 1));
      final b = find.byType(ElevatedButton);
      final left = t.getRect(b.first).left, right = t.getRect(b.last).right;
      expect((left + right) / 2, closeTo(180, 2)); // button row centred
    });
  }

  testWidgets('game app bar opens Settings and returns to the same game', (t) async {
    await t.pumpWidget(MaterialApp(
      home: BaseGameScreen(title: 'T', onReset: () {}, child: const SizedBox(key: Key('board'))),
    ));
    await t.tap(find.byTooltip('Settings'));
    await t.pumpAndSettle();
    expect(find.text('Background Music'), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('board')), findsOneWidget);
  });
}
