import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/base_game_screen.dart';
import 'package:gridmind/screens/settings_screen.dart';
import 'package:gridmind/screens/walkthrough_dialog.dart';
import 'package:gridmind/services/game_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Extends inset_matrix_test.dart / game_inset_matrix_test.dart to dialogs, bottom sheets,
// win/lose banners and the game board, at small and landscape sizes with the system bar
// at the bottom or on the side. Rule: nothing tappable or drawn as the board may end inside
// a system inset. Per-game result dialogs are not covered here (only the shared ones).
void main() {
  // Real glyph widths: the default test font (Ahem) is wider and gives false overflows.
  setUpAll(() async {
    final root = Platform.environment['FLUTTER_ROOT'];
    final loader = FontLoader('Roboto');
    for (final f in ['Regular', 'Medium', 'Bold']) {
      final file = File('$root/bin/cache/artifacts/material_fonts/Roboto-$f.ttf');
      if (root != null && file.existsSync()) loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await loader.load();
  });

  setUp(() => SharedPreferences.setMockInitialValues({'telemetry_consent_answered': true, 'walkthrough_seen__app_intro': true}));

  // (name, size, left, bottom, right) in dp. Top is always a 40 dp cutout/status bar.
  const cases = [
    ('360x640 gesture', Size(360, 640), 0.0, 34.0, 0.0),
    ('360x640 3-button', Size(360, 640), 0.0, 48.0, 0.0),
    ('411x914 3-button', Size(411, 914), 0.0, 48.0, 0.0),
    ('320x568 3-button', Size(320, 568), 0.0, 48.0, 0.0),
    ('640x360 bar bottom', Size(640, 360), 0.0, 48.0, 0.0),
    ('640x360 bar right', Size(640, 360), 0.0, 0.0, 48.0),
    ('640x360 bar left', Size(640, 360), 48.0, 0.0, 0.0),
  ];

  void setView(WidgetTester t, Size size, double l, double b, double r) {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    t.view.padding = FakeViewPadding(top: 40, bottom: b, left: l, right: r);
    t.view.viewPadding = FakeViewPadding(top: 40, bottom: b, left: l, right: r);
    addTearDown(t.view.reset);
  }

  Future<void> scrollAllToEnd(WidgetTester t, Finder within) async {
    for (var i = 0; i < 3; i++) {
      for (final s in t.stateList<ScrollableState>(find.descendant(of: within, matching: find.byType(Scrollable)))) {
        s.position.jumpTo(s.position.maxScrollExtent);
      }
      await t.pump();
    }
  }

  // Every matching widget inside [within] must lie inside the area the bars leave free.
  void expectClear(WidgetTester t, Size size, double l, double b, double r, Finder within, List<Finder> kinds, String what) {
    final free = Rect.fromLTRB(l, 40, size.width - r, size.height - b);
    var n = 0;
    for (final k in kinds) {
      for (final e in find.descendant(of: within, matching: k).evaluate()) {
        final box = e.renderObject as RenderBox;
        // Both corners, so a scaled ancestor (FittedBox) is honoured.
        final rect = Rect.fromPoints(box.localToGlobal(Offset.zero), box.localToGlobal(box.size.bottomRight(Offset.zero)));
        // Off-screen items of a scroll view are reachable by scrolling; only judge ones on screen.
        if (!what.contains('board') && (rect.bottom > size.height || rect.right > size.width || rect.top < 0)) continue;
        n++;
        expect(rect.bottom, lessThanOrEqualTo(free.bottom), reason: '$what ends at ${rect.bottom}, the bar starts at ${free.bottom}');
        expect(rect.right, lessThanOrEqualTo(free.right), reason: '$what ends at x=${rect.right}, the bar starts at ${free.right}');
        expect(rect.left, greaterThanOrEqualTo(free.left), reason: '$what starts at x=${rect.left}, the bar ends at ${free.left}');
      }
    }
    expect(n, greaterThan(0), reason: 'no $what found');
  }

  final buttons = [find.byWidgetPredicate((w) => w is ButtonStyleButton)];

  for (final c in cases) {
    final (name, size, l, b, r) = c;

    testWidgets('Walkthrough dialog: buttons clear the bars ($name)', (t) async {
      setView(t, size, l, b, r);
      final game = GameRegistry.games.first;
      await t.pumpWidget(MaterialApp(home: Builder(builder: (ctx) => TextButton(onPressed: () => showWalkthroughDialog(ctx, game), child: const Text('open')))));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('walkthrough_dialog')), findsOneWidget);
      expectClear(t, size, l, b, r, find.byKey(const Key('walkthrough_dialog')), buttons, 'walkthrough button');
      expect(t.takeException(), isNull);
    });

    testWidgets('Settings palette sheet: content clears the bars ($name)', (t) async {
      setView(t, size, l, b, r);
      await t.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await t.pumpAndSettle();
      await t.tap(find.text('Game Color Palette'));
      await t.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      await scrollAllToEnd(t, sheet);
      expectClear(t, size, l, b, r, sheet, [...buttons, find.byType(Text), find.byType(RadioListTile<String>)], 'palette sheet content');
    });

    testWidgets('Settings clear-scores dialog: buttons clear the bars ($name)', (t) async {
      setView(t, size, l, b, r);
      await t.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await t.pumpAndSettle();
      final clear = find.byIcon(Icons.delete_sweep_outlined);
      await t.scrollUntilVisible(clear, 100, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(clear);
      await t.pumpAndSettle();
      await t.tap(clear, warnIfMissed: false);
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expectClear(t, size, l, b, r, find.byType(AlertDialog), buttons, 'dialog button');
    });

    // Win and lose banners plus Restart/Exit, and the board, on the shared game shell.
    for (final over in [false, true]) {
      testWidgets('BaseGameScreen ${over ? 'game-over' : 'win'} overlay and board clear the bars ($name)', (t) async {
        setView(t, size, l, b, r);
        const boardKey = Key('board');
        await t.pumpWidget(MaterialApp(
          home: BaseGameScreen(
            title: 'T',
            isGameWon: !over,
            isGameOver: over,
            onReset: () {},
            onUndo: () {},
            child: const SizedBox.expand(key: boardKey),
          ),
        ));
        await t.pump(const Duration(milliseconds: 400));
        expect(t.takeException(), isNull);
        final body = find.byType(BaseGameScreen);
        await scrollAllToEnd(t, body);
        expectClear(t, size, l, b, r, body, [...buttons, find.text(over ? 'Game Over!' : 'You Win!')], 'button or banner');
        expectClear(t, size, l, b, r, find.byType(MaterialApp), [find.byKey(boardKey)], 'board');
      });
    }

    // The board of every real game: its BaseGameScreen child must end above the bar.
    testWidgets('All game boards end above the bars ($name)', (t) async {
      setView(t, size, l, b, r);
      for (final game in GameRegistry.games) {
        final config = {for (final o in game.configOptions) o.key: o.defaultValue};
        await t.pumpWidget(MaterialApp(home: Builder(builder: (c) => game.gameBuilder(c, config))));
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await t.pump(const Duration(milliseconds: 400));
        final base = t.widget<BaseGameScreen>(find.byType(BaseGameScreen));
        final board = find.byWidget(base.child);
        expect(board, findsOneWidget, reason: '${game.id}: board not found');
        await scrollAllToEnd(t, find.byType(BaseGameScreen));
        expectClear(t, size, l, b, r, find.byType(MaterialApp), [board], '${game.id} board');
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 5));
      }
    });
  }
}
