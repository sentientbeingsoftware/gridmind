import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/base_game_screen.dart';
import 'package:gridmind/services/game_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Every game, default config, at desktop / tablet / landscape-phone sizes:
// no overflow, and the wide layout (side panel) is used where the window is
// wide enough.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const sizes = [Size(1280, 720), Size(1024, 768), Size(800, 360), Size(720, 400)];
  for (final size in sizes) {
    for (final game in GameRegistry.games) {
      testWidgets('${game.id} at ${size.width.toInt()}x${size.height.toInt()}', (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final config = {for (final o in game.configOptions) o.key: o.defaultValue};
        await t.pumpWidget(MaterialApp(home: Builder(builder: (c) => game.gameBuilder(c, config))));
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await t.pump(const Duration(milliseconds: 400));
        final ex = t.takeException();
        expect(ex, isNull, reason: ex?.toString().split('\n').first);
        expect(find.byType(BaseGameScreen), findsOneWidget);
        await t.pumpWidget(const SizedBox()); // dispose so game timers cancel
        await t.pump(const Duration(seconds: 5));
      });
    }
  }

  Future<Offset> restartAt(WidgetTester t, Size size) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
      home: BaseGameScreen(title: 'T', onReset: () {}, child: const SizedBox(key: Key('board'))),
    ));
    await t.pump();
    return t.getCenter(find.text('Restart'));
  }

  testWidgets('wide window puts controls in a left panel, board on the right', (t) async {
    final restart = await restartAt(t, const Size(1280, 720));
    expect(restart.dx, lessThan(400));
    expect(t.getCenter(find.byKey(const Key('board'))).dx, greaterThan(restart.dx));
  });

  testWidgets('portrait keeps controls centred below the board', (t) async {
    final restart = await restartAt(t, const Size(360, 640));
    expect(restart.dy, greaterThan(500));
  });
}
