import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/base_game_screen.dart';
import 'package:gridmind/services/game_effects.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late List<String> haptics;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    haptics = [];
    GameEffects.instance.audioPluginAvailable = false; // no audio plugin in tests
    GameEffects.instance.apply(sound: true, haptics: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments as String);
      return null;
    });
  });

  Widget screen(String score, {bool won = false, bool over = false, bool tick = true}) =>
      MaterialApp(
        home: BaseGameScreen(
          title: 'T',
          currentScoreValue: score,
          isGameWon: won,
          isGameOver: over,
          tickOnScoreChange: tick,
          child: const SizedBox(),
        ),
      );

  testWidgets('score change taps lightly, win and lose tap harder', (t) async {
    await t.pumpWidget(screen('0'));
    await t.pumpWidget(screen('1'));
    await t.pump();
    expect(haptics, ['HapticFeedbackType.selectionClick']);
    await t.pumpWidget(screen('2', won: true));
    await t.pump();
    expect(haptics.last, 'HapticFeedbackType.mediumImpact');
    await t.pumpWidget(screen('0')); // new game
    await t.pump();
    haptics.clear();
    await t.pumpWidget(screen('0', over: true));
    await t.pump();
    expect(haptics, ['HapticFeedbackType.heavyImpact']);
  });

  testWidgets('countdown screens opt out of per-change taps', (t) async {
    await t.pumpWidget(screen('30s', tick: false));
    await t.pumpWidget(screen('29s', tick: false));
    await t.pump();
    expect(haptics, isEmpty);
  });

  testWidgets('haptics toggle off silences everything', (t) async {
    GameEffects.instance.apply(haptics: false);
    await t.pumpWidget(screen('0'));
    await t.pumpWidget(screen('1', won: true));
    await t.pump();
    expect(haptics, isEmpty);
  });
}
