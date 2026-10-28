import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/sum_grid_game_screen.dart';
import 'package:gridmind/screens/word_search_game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void big(WidgetTester t) {
    t.view.physicalSize = const Size(800, 1200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  testWidgets('Word Search: activating start then end cell finds the word', (t) async {
    final h = t.ensureSemantics();
    big(t);
    await t.pumpWidget(const MaterialApp(
      home: WordSearchGameScreen(
        gridSize: 3, wordCount: 1, moveMode: 'classic', category: 'Animals', testMode: true,
        testGrid: [['C', 'A', 'T'], ['X', 'X', 'X'], ['X', 'X', 'X']],
        testWords: ['CAT'],
      ),
    ));
    await t.pump();
    // not a straight line from (0,0): ignored, selection stays open
    t.semantics.tap(find.semantics.byLabel(RegExp(r'^Row 1, column 1, letter C')));
    await t.pump();
    expect(find.bySemanticsLabel(RegExp(r'start of selection')), findsOneWidget);
    t.semantics.tap(find.semantics.byLabel(RegExp(r'^Row 2, column 3, letter X')));
    await t.pump();
    expect(find.bySemanticsLabel(RegExp(r'start of selection')), findsOneWidget);
    // straight line: word found
    t.semantics.tap(find.semantics.byLabel(RegExp(r'^Row 1, column 3, letter T')));
    await t.pump();
    expect(find.bySemanticsLabel(RegExp(r'part of a found word')), findsNWidgets(3));
    h.dispose();
  });

  testWidgets('Sum Grid: activating a cell selects it; a far cell is refused', (t) async {
    final h = t.ensureSemantics();
    big(t);
    await t.pumpWidget(const MaterialApp(
      home: SumGridGameScreen(gridSize: 4, gameMode: 'classic', targetMode: 'fixed'),
    ));
    await t.pump();
    t.semantics.tap(find.semantics.byLabel(RegExp(r'^Row 1, column 1, \d')));
    await t.pump();
    expect(find.bySemanticsLabel(RegExp(r'selected')), findsOneWidget);
    t.semantics.tap(find.semantics.byLabel(RegExp(r'^Row 4, column 4, \d')));
    await t.pump();
    expect(find.bySemanticsLabel(RegExp(r'selected')), findsOneWidget); // far cell not added
    h.dispose();
  });
}
