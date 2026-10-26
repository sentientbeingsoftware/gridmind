import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/mixins/config_high_score_mixin.dart';
import 'package:gridmind/services/app_persistence_service.dart';
import 'package:gridmind/services/game_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guards the contract between BaseSetupScreen (reads the best score using the
/// registry's config) and each game screen (writes it using its own
/// highScoreConfig). A mismatch silently loses scores.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('every ConfigHighScoreMixin game writes to the key the setup screen reads', (tester) async {
    tester.view.physicalSize = const Size(1024, 2048);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final persistence = AppPersistenceService();
    var checked = 0;

    for (final game in GameRegistry.games) {
      // Exactly what BaseSetupScreen builds when nothing was customised.
      final setupConfig = <String, dynamic>{
        for (final opt in game.configOptions) opt.key: opt.defaultValue,
      };

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) => game.gameBuilder(context, setupConfig)),
      ));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
      await tester.pump();

      final states = tester.allStates.whereType<ConfigHighScoreMixin>().toList();
      if (states.isEmpty) {
        // Games without persisted scores (none expected).
        await tester.pumpWidget(const SizedBox());
        continue;
      }
      expect(states, hasLength(1), reason: '${game.id}: expected exactly one score mixin');
      final state = states.single;

      expect(state.highScoreGameId, game.id,
          reason: '${game.id}: highScoreGameId differs from registry id');

      await tester.runAsync(() => state.submitScore(7));
      final readBack = await tester.runAsync(
        () => persistence.getConfigHighScore(game.id, setupConfig),
      );
      expect(readBack, 7,
          reason: '${game.id}: score written by the game is not found under the '
              'setup screen key. Game config: ${state.highScoreConfig}; '
              'setup config: $setupConfig');
      checked++;

      // Dispose before the next game; drain pending timers.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    }

    expect(checked, greaterThanOrEqualTo(22), reason: 'mixin games went untested');
  });
}
