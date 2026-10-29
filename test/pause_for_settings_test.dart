import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/pulse_game_screen.dart';
import 'package:gridmind/screens/sum_grid_game_screen.dart';
import 'package:gridmind/screens/word_search_game_screen.dart';
import 'package:gridmind/utils/game_pause.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Opening Settings from inside a game must hold the clock still.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'telemetry_consent_answered': true}));

  Future<void> run(WidgetTester t, Widget game, String Function() clock) async {
    t.view.physicalSize = const Size(400, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(home: game));
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(seconds: 3)); // let it count a little
    final before = clock();
    expect(before, isNotEmpty, reason: 'could not read the clock');

    await t.tap(find.byTooltip('Settings'));
    await t.pump(const Duration(milliseconds: 500));
    expect(GamePause.isPaused, isTrue);
    await t.pump(const Duration(seconds: 10));
    expect(clock(), before, reason: 'clock moved while Settings was open');

    await t.pageBack();
    await t.pump(const Duration(milliseconds: 500));
    expect(GamePause.isPaused, isFalse);
    await t.pump(const Duration(seconds: 3));
    expect(clock(), isNot(before), reason: 'clock did not resume');
    await t.pumpWidget(const SizedBox()); // dispose timers
  }

  String text(WidgetTester t, RegExp re) =>
      t.widgetList<Text>(find.byType(Text, skipOffstage: false)).map((w) => w.data ?? '').firstWhere(re.hasMatch, orElse: () => '');

  testWidgets('Sum Grid timed: countdown holds while Settings is open', (t) async {
    await run(t, const SumGridGameScreen(gridSize: 4, gameMode: 'timed', targetMode: 'random'), () => text(t, RegExp(r'^Time: \d+s')));
  });

  testWidgets('Word Search challenge: countdown holds while Settings is open', (t) async {
    await run(t, const WordSearchGameScreen(gridSize: 8, wordCount: 4, moveMode: 'challenge', category: 'Random'),
        () => text(t, RegExp(r'^Time remaining: \d+s')));
  });

  testWidgets('Pulse: the moving highlight holds while Settings is open', (t) async {
    await run(t, const PulseGameScreen(gridSize: 3, speed: 'normal'), () {
      // The pulse cell is the one drawn highlighted; its position is its identity.
      final boxes = t.widgetList<AnimatedContainer>(find.byType(AnimatedContainer, skipOffstage: false)).toList();
      return boxes.map((b) => (b.decoration as BoxDecoration?)?.color?.toARGB32().toString() ?? '-').join(',');
    });
  });
}
