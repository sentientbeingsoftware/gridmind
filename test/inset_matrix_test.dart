import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/base_setup_screen.dart';
import 'package:gridmind/screens/feedback_screen.dart';
import 'package:gridmind/screens/menu_screen.dart';
import 'package:gridmind/screens/settings_screen.dart';
import 'package:gridmind/services/game_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Android 15+ draws apps edge-to-edge, so the system navigation bar (and a camera
// cutout) sits over the app. For every non-game screen: scroll to the end and fail if
// the last text ends under the bottom inset. Game screens wrap their body in SafeArea.
// Build 7 shipped with the menu's last card (Word Search) under the nav bar.
void main() {
  setUpAll(() async {
    final root = Platform.environment['FLUTTER_ROOT'];
    final loader = FontLoader('Roboto');
    for (final f in ['Regular', 'Medium', 'Bold']) {
      final file = File('$root/bin/cache/artifacts/material_fonts/Roboto-$f.ttf');
      if (root != null && file.existsSync()) {
        loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      }
    }
    await loader.load();
  });

  setUp(() => SharedPreferences.setMockInitialValues({'telemetry_consent_answered': true, 'walkthrough_seen__app_intro': true}));

  // dp. Gesture bar is ~24-34; the 3-button bar is 48. Cutout: 40 at the top.
  const insets = {'gesture bar': 34.0, '3-button bar': 48.0};
  const sizes = [Size(360, 640), Size(411, 914)];

  Future<void> expectLastContentAboveInset(WidgetTester t, Size size, double inset, Widget home) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    t.view.padding = FakeViewPadding(top: 40, bottom: inset);
    t.view.viewPadding = FakeViewPadding(top: 40, bottom: inset);
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: home));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100))); // lets async loads finish
    await t.pump(const Duration(milliseconds: 500));

    // A lazy list re-estimates its length as items build, so jump until it stops growing.
    for (var i = 0; i < 5; i++) {
      for (final s in t.stateList<ScrollableState>(find.byType(Scrollable))) {
        if (s.position.axis == Axis.vertical) s.position.jumpTo(s.position.maxScrollExtent);
      }
      await t.pump();
    }

    // At the end of the scroll, the lowest content inside a vertical scroll view is the last item.
    var lowest = 0.0;
    final content = [find.byType(Text), find.byType(Card), find.byType(ButtonStyleButton), find.byType(ListTile)];
    for (final sc in find.byType(Scrollable).evaluate().where((e) => (e.widget as Scrollable).axisDirection == AxisDirection.down)) {
      for (final f in content) {
        for (final e in find.descendant(of: find.byElementPredicate((x) => x == sc), matching: f).evaluate()) {
          final box = e.renderObject as RenderBox;
          final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
          if (bottom > lowest && bottom <= size.height) lowest = bottom;
        }
      }
    }
    expect(lowest, lessThanOrEqualTo(size.height - inset),
        reason: 'last content ends at $lowest dp but the nav bar starts at ${size.height - inset}');
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  }

  for (final size in sizes) {
    for (final inset in insets.entries) {
      final tag = '${size.width.toInt()}x${size.height.toInt()}, ${inset.key}';
      testWidgets('Menu: last card clears the nav bar ($tag)', (t) => expectLastContentAboveInset(t, size, inset.value, const MenuScreen()));
      testWidgets('Settings: last item clears the nav bar ($tag)', (t) => expectLastContentAboveInset(t, size, inset.value, const SettingsScreen()));
      testWidgets('Feedback: last item clears the nav bar ($tag)', (t) => expectLastContentAboveInset(t, size, inset.value, const FeedbackScreen(diagnostics: {})));
      testWidgets('Setup screens: start button clears the nav bar ($tag)', (t) async {
        for (final game in GameRegistry.games) {
          await expectLastContentAboveInset(t, size, inset.value, BaseSetupScreen(game: game));
        }
      });
    }
  }
}
