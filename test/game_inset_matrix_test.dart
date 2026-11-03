import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/services/game_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Android 15+ draws apps under the system nav bar. Every game, default config, with a
// 48 dp bar at the bottom and a 40 dp cutout at the top: no overflow, and every button
// (Restart, Hint, ...) sits above the bar. See inset_matrix_test.dart for the menus.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'telemetry_consent_answered': true, 'walkthrough_seen__app_intro': true}));

  const size = Size(360, 640);
  const inset = 48.0;
  for (final game in GameRegistry.games) {
    testWidgets('${game.id}: buttons clear the nav bar', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1.0;
      t.view.padding = const FakeViewPadding(top: 40, bottom: inset);
      t.view.viewPadding = const FakeViewPadding(top: 40, bottom: inset);
      addTearDown(t.view.reset);
      final config = {for (final o in game.configOptions) o.key: o.defaultValue};
      await t.pumpWidget(MaterialApp(home: Builder(builder: (c) => game.gameBuilder(c, config))));
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await t.pump(const Duration(milliseconds: 400));
      final ex = t.takeException();
      expect(ex, isNull, reason: ex?.toString().split('\n').first);

      // Scroll to the end first: a button below the fold is reachable, one under the bar is not.
      for (var i = 0; i < 3; i++) {
        for (final sc in t.stateList<ScrollableState>(find.byType(Scrollable))) {
          if (sc.position.axis == Axis.vertical) sc.position.jumpTo(sc.position.maxScrollExtent);
        }
        await t.pump();
      }
      var lowest = 0.0;
      for (final e in find.byWidgetPredicate((w) => w is ButtonStyleButton).evaluate()) {
        final box = e.renderObject as RenderBox;
        final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
        if (bottom > lowest && bottom <= size.height) lowest = bottom;
      }
      expect(lowest, greaterThan(0), reason: 'no buttons found');
      expect(lowest, lessThanOrEqualTo(size.height - inset), reason: 'lowest button ends at $lowest dp, the nav bar starts at ${size.height - inset}');

      await t.pumpWidget(const SizedBox()); // dispose so game timers cancel
      await t.pump(const Duration(seconds: 5));
    });
  }
}
