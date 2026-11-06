import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/mirror_match_game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final inset in [0.0, 40.0]) {
    testWidgets('Mirror Match 12 fits the wide board area (insets $inset)', (t) async {
      t.view.physicalSize = const Size(1920, 1080);
      t.view.devicePixelRatio = 1.0;
      t.view.padding = FakeViewPadding(top: inset, bottom: inset);
      t.view.viewPadding = FakeViewPadding(top: inset, bottom: inset);
      addTearDown(t.view.reset);
      await t.pumpWidget(const MaterialApp(
        home: MirrorMatchGameScreen(
            gridSize: 12, symmetryType: 'vertical', moveMode: 'zen', testMode: true),
      ));
      await t.pump(const Duration(milliseconds: 500));
      final cells = find.descendant(
          of: find.byType(GestureDetector), matching: find.byType(AnimatedContainer));
      final first = t.getRect(cells.first);
      final last = t.getRect(cells.last);
      // ignore: avoid_print
      print('inset $inset first=$first last=$last');
      // Board is 320dp tall with 8dp padding, centered in the body: grid must be
      // symmetric inside it, i.e. equal gaps above the first and below the last row.
      final board = t.getRect(find.byType(GridView));
      expect((first.top - board.top) - (board.bottom - last.bottom), closeTo(0, 1));
      expect(last.bottom, lessThanOrEqualTo(board.bottom + 0.01));
    });
  }
}
