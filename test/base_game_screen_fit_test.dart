import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/base_game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A board-like child: a Column that needs [height] px whatever room it gets,
/// like the real games, so a too-short game area overflows it.
Widget _game(double height) => MaterialApp(
      home: BaseGameScreen(
        title: 'Fit',
        highScoreValue: '1',
        currentScoreValue: '2',
        onReset: () {},
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [SizedBox(key: const Key('board'), width: 200, height: height)],
          ),
        ),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpAt(WidgetTester t, Size size, Widget app) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(app);
  }

  testWidgets('a tall child is scaled to fit a compact phone without overflow', (t) async {
    await pumpAt(t, const Size(360, 640), _game(400));
    expect(t.takeException(), isNull);
    final board = t.getRect(find.byKey(const Key('board')));
    expect(board.height, lessThan(400));
    expect(board.height, greaterThan(400 * 0.55 - 1));
    expect(find.text('Restart'), findsOneWidget);
    expect(t.getRect(find.text('Exit')).bottom, lessThanOrEqualTo(640));
  });

  testWidgets('a tall screen leaves the board at its natural size', (t) async {
    await pumpAt(t, const Size(412, 915), _game(400));
    expect(t.takeException(), isNull);
    expect(t.getRect(find.byKey(const Key('board'))).height, 400);
  });

  testWidgets('an extremely short window scrolls instead of overflowing', (t) async {
    await pumpAt(t, const Size(340, 300), _game(400));
    expect(t.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
