import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/services/game_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Test-only: needed to hold SharedPreferences loading open (transitive dep).
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/types.dart';

/// In-memory store whose first read blocks until [gate] completes, so a game's
/// async setup (palette / best-score load) is provably still pending when the
/// screen is torn down.
class _GatedStore extends InMemorySharedPreferencesStore {
  _GatedStore(this.gate) : super.empty();
  final Future<void> gate;

  @override
  Future<Map<String, Object>> getAllWithParameters(GetAllParameters parameters) async {
    await gate;
    return super.getAllWithParameters(parameters);
  }
}

/// Leaving a game while its async setup is still in flight must not call
/// setState on the disposed State.
void main() {
  for (final game in GameRegistry.games) {
    testWidgets('${game.id}: disposing before async init completes does not throw',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 2048);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({}); // resets the cached instance
      final gate = Completer<void>();
      SharedPreferencesStorePlatform.instance = _GatedStore(gate.future);

      final config = {for (final o in game.configOptions) o.key: o.defaultValue};

      await tester.pumpWidget(
        MaterialApp(home: Builder(builder: (c) => game.gameBuilder(c, config))),
      );
      // Tear the screen down while prefs loading is still blocked on the gate.
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));

      // Release the abandoned init futures, let them run, drain any timers.
      gate.complete();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(seconds: 5));

      expect(tester.takeException(), isNull);
    });
  }
}
