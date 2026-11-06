import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/base_game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _game(double scale) => MaterialApp(
      home: BaseGameScreen(
        title: 'Wide',
        highScoreValue: '1',
        currentScoreValue: '2',
        onReset: () {},
        wideScale: scale,
        child: const Center(child: SizedBox(key: Key('board'), width: 300, height: 300)),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<Rect> boardAt(WidgetTester t, Size size, double scale) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(_game(scale));
    expect(t.takeException(), isNull);
    return t.getRect(find.byKey(const Key('board')));
  }

  testWidgets('1920x1032: opted-in board grows to >=60% of body height', (t) async {
    final r = await boardAt(t, const Size(1920, 1032), 3);
    expect(r.height, greaterThanOrEqualTo(0.6 * (1032 - kToolbarHeight)));
    expect(r.width, r.height);
  });

  testWidgets('1366x720: scaled board stays inside the window', (t) async {
    final r = await boardAt(t, const Size(1366, 720), 3);
    expect(r.height, greaterThan(300));
    expect(r.bottom, lessThanOrEqualTo(720));
  });

  testWidgets('not opted in (wideScale 1): board unchanged on wide', (t) async {
    expect((await boardAt(t, const Size(1920, 1032), 1)).height, 300);
  });

  testWidgets('phone: board unchanged even when opted in', (t) async {
    expect((await boardAt(t, const Size(412, 915), 3)).height, 300);
  });
}
