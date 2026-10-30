import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/word_search_game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WordSearchGameScreen Widget Tests', () {
    testWidgets('renders screen and plays game in zen mode', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testGrid = [
        ['C', 'A', 'T', 'X', 'Y', 'Z'],
        ['D', 'X', 'X', 'X', 'X', 'X'],
        ['O', 'X', 'X', 'X', 'X', 'X'],
        ['G', 'X', 'X', 'X', 'X', 'X'],
        ['X', 'X', 'X', 'X', 'X', 'X'],
        ['X', 'X', 'X', 'X', 'X', 'X'],
      ];
      final testWords = ['CAT', 'DOG'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WordSearchGameScreen(
              gridSize: 6,
              wordCount: 2,
              moveMode: 'zen',
              category: 'Random',
              testMode: true,
              testGrid: testGrid,
              testWords: testWords,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Words found counter: initially 0/2
      expect(find.text('0/2'), findsOneWidget);
      expect(find.text('CAT'), findsOneWidget);
      expect(find.text('DOG'), findsOneWidget);

      // Perform swipe drag from C to T to select CAT using ValueKeys
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('cell_0_0'))));
      await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('cell_0_1'))));
      await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('cell_0_2'))));
      await gesture.up();
      await tester.pumpAndSettle();

      // CAT is found, words found is 1/2
      expect(find.text('1/2'), findsOneWidget);

      // Perform swipe drag from D to G to select DOG using ValueKeys
      final gesture2 = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('cell_1_0'))));
      await gesture2.moveTo(tester.getCenter(find.byKey(const ValueKey('cell_2_0'))));
      await gesture2.moveTo(tester.getCenter(find.byKey(const ValueKey('cell_3_0'))));
      await gesture2.up();
      await tester.pumpAndSettle();

      // DOG is found, all words found, victory message displays
      expect(find.text('2/2'), findsOneWidget);
      expect(find.text('Victory! All words found!'), findsOneWidget);
    });

    testWidgets('using hint and undoing a word', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testGrid = [
        ['C', 'A', 'T', 'X', 'Y', 'Z'],
        ['D', 'X', 'X', 'X', 'X', 'X'],
        ['O', 'X', 'X', 'X', 'X', 'X'],
        ['G', 'X', 'X', 'X', 'X', 'X'],
        ['X', 'X', 'X', 'X', 'X', 'X'],
        ['X', 'X', 'X', 'X', 'X', 'X'],
      ];
      final testWords = ['CAT', 'DOG'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WordSearchGameScreen(
              gridSize: 6,
              wordCount: 2,
              moveMode: 'zen',
              category: 'Random',
              testMode: true,
              testGrid: testGrid,
              testWords: testWords,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify hint button exists and scroll it into view to prevent hit test failures
      final hintFinder = find.text('Hint (3)');
      expect(hintFinder, findsOneWidget);
      await tester.ensureVisible(hintFinder);
      await tester.pumpAndSettle();
      
      // Tap Hint button
      await tester.tap(hintFinder);
      await tester.pumpAndSettle();

      // Hint count decremented
      expect(find.text('Hint (2)'), findsOneWidget);

      // Select CAT using ValueKeys
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('cell_0_0'))));
      await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('cell_0_1'))));
      await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('cell_0_2'))));
      await gesture.up();
      await tester.pumpAndSettle();

      // Verify 1/2 words found
      expect(find.text('1/2'), findsOneWidget);

      // Scroll Undo button into view
      final undoBtn = find.text('Undo');
      expect(undoBtn, findsOneWidget);
      await tester.ensureVisible(undoBtn);
      await tester.pumpAndSettle();
      
      await tester.tap(undoBtn);
      await tester.pumpAndSettle();

      // Words found goes back to 0/2
      expect(find.text('0/2'), findsOneWidget);
    });

    testWidgets('crowded boards still show a grid and words (8x8 with 11 words, 6x6 with 20)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final (size, words) in [(8, 11), (8, 11), (8, 11), (8, 11), (6, 20), (6, 20), (7, 15), (7, 15)]) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: WordSearchGameScreen(gridSize: size, wordCount: words, moveMode: 'challenge', category: 'Random'),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.byType(Chip), findsWidgets, reason: '$size x $size with $words words: no words listed');
        expect(tester.widgetList<Chip>(find.byType(Chip)).length, lessThanOrEqualTo(words));
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  // Smoke test 2026-10-30 (Pixel 6a): at big grid sizes the bottom of the letters was cut off.
  group('letters fit their cell on a Pixel 6a (411x914 dp)', () {
    setUpAll(() async {
      final root = Platform.environment['FLUTTER_ROOT'];
      final loader = FontLoader('Roboto');
      for (final f in ['Regular', 'Medium', 'Bold']) {
        loader.addFont(Future.value(ByteData.sublistView(File('$root/bin/cache/artifacts/material_fonts/Roboto-$f.ttf').readAsBytesSync())));
      }
      await loader.load();
    });

    for (final n in [14, 16, 18, 19, 20]) {
      testWidgets('$n x $n', (t) async {
        SharedPreferences.setMockInitialValues({'telemetry_consent_answered': true});
        t.view.physicalSize = const Size(1080, 2400);
        t.view.devicePixelRatio = 420 / 160;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(MaterialApp(home: WordSearchGameScreen(gridSize: n, wordCount: 5, moveMode: 'zen', category: 'Random')));
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
        await t.pump(const Duration(milliseconds: 500));
        final cell = find.byKey(ValueKey('cell_${n - 1}_${n - 1}'));
        final fontSize = t.widget<Text>(find.descendant(of: cell, matching: find.byType(Text))).style!.fontSize!;
        // 18x18 (1.31x on the old layout) looked fine on the Pixel 6a, 19x19 (1.22x) clipped: need >= 1.3x.
        expect(t.getRect(cell).height, greaterThanOrEqualTo(fontSize * 1.3), reason: 'cell is shorter than the letter, so its bottom is clipped');
      });
    }
  });

  group('hint and timeout reveal', () {
    final grid = [
      ['C', 'A', 'T', 'X', 'Y', 'Z'],
      ['D', 'X', 'X', 'X', 'X', 'X'],
      ['O', 'X', 'X', 'X', 'X', 'X'],
      ['G', 'X', 'X', 'X', 'X', 'X'],
      ['X', 'X', 'X', 'X', 'X', 'X'],
      ['X', 'X', 'X', 'X', 'X', 'X'],
    ];

    Future<void> open(WidgetTester t, String mode) async {
      t.view.physicalSize = const Size(800, 1400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: WordSearchGameScreen(gridSize: 6, wordCount: 2, moveMode: mode, category: 'Random', testMode: true, testGrid: grid, testWords: const ['CAT', 'DOG']),
        ),
      ));
      await t.pumpAndSettle();
    }

    Color? chipBorder(WidgetTester t, String word) =>
        ((t.widget<Chip>(find.widgetWithText(Chip, word)).shape) as RoundedRectangleBorder).side.color;

    testWidgets('Hint outlines the word it is pointing at in the word list', (t) async {
      await open(t, 'zen');
      expect(chipBorder(t, 'CAT'), isNot(Colors.amber));
      await t.tap(find.textContaining('Hint'));
      await t.pump();
      expect(chipBorder(t, 'CAT'), Colors.amber);
      expect(chipBorder(t, 'DOG'), isNot(Colors.amber));
      await t.pump(const Duration(seconds: 5)); // flash ends
      expect(chipBorder(t, 'CAT'), isNot(Colors.amber));
    });

    testWidgets('time-out marks every missed word on the board and in the list', (t) async {
      // Test mode never starts the countdown, so use a real random board.
      SharedPreferences.setMockInitialValues({'telemetry_consent_answered': true});
      final handle = t.ensureSemantics();
      t.view.physicalSize = const Size(800, 1400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(const MaterialApp(home: WordSearchGameScreen(gridSize: 6, wordCount: 3, moveMode: 'challenge', category: 'Random')));
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.bySemanticsLabel(RegExp('missed word')), findsNothing);
      final chips = t.widgetList<Chip>(find.byType(Chip)).length;
      expect(chips, greaterThan(0));
      await t.pump(const Duration(seconds: 200)); // longer than the limit (6*15 + words*10)
      await t.pump();
      // Every unfound word is outlined in the list, and its letters are marked on the board.
      for (final c in t.widgetList<Chip>(find.byType(Chip))) {
        expect((c.shape as RoundedRectangleBorder).side.color, Colors.redAccent);
      }
      expect(find.bySemanticsLabel(RegExp('part of a missed word')).evaluate().length, greaterThanOrEqualTo(3));
      handle.dispose();
    });
  });
}
