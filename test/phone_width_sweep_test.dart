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

// Opens every non-game screen at small phone widths and fails on any layout
// overflow. Complements wide_layout_test, which covers the game screens.
void main() {
  // flutter_test draws all text in Ahem (1 em per glyph, ~2x wider than Roboto), which
  // invents overflows. Load the real Roboto that ships with the SDK when it is there.
  setUpAll(() async {
    final root = Platform.environment['FLUTTER_ROOT'];
    final dir = '$root/bin/cache/artifacts/material_fonts';
    final loader = FontLoader('Roboto');
    for (final f in ['Regular', 'Medium', 'Bold']) {
      final file = File('$dir/Roboto-$f.ttf');
      if (root != null && file.existsSync()) {
        loader.addFont(
            Future.value(ByteData.sublistView(file.readAsBytesSync())));
      }
    }
    await loader.load();
  });

  setUp(() => SharedPreferences.setMockInitialValues(
      {'telemetry_consent_answered': true}));

  Future<void> open(WidgetTester t, Size size, Widget home,
      {double scale = 1.0}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: home,
    ));
    await t.pump(const Duration(milliseconds: 500));
  }

  final sizes = [const Size(320, 568), const Size(360, 640)];
  final scales = [1.0, 1.5];

  for (final size in sizes) {
    for (final scale in scales) {
      final tag = '${size.width.toInt()}x${size.height.toInt()} @${scale}x';

      testWidgets('Menu $tag', (t) async {
        await open(t, size, const MenuScreen(), scale: scale);
        final e = t.takeException();
        expect(e, isNull, reason: '$e');
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
      });

      testWidgets('Settings $tag', (t) async {
        await open(t, size, const SettingsScreen(), scale: scale);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      });

      testWidgets('Feedback $tag', (t) async {
        await open(t, size, const FeedbackScreen(diagnostics: {}),
            scale: scale);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      });

      testWidgets('Setup screens for all games $tag', (t) async {
        for (final game in GameRegistry.games) {
          await open(
              t, size, BaseSetupScreen(key: ValueKey(game.id), game: game),
              scale: scale);
          final e = t.takeException();
          expect(e, isNull, reason: 'setup screen for ${game.id}: $e');
        }
        await t.pumpWidget(const SizedBox());
      });
    }
  }
}
