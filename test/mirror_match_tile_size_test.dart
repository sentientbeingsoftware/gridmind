import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/mirror_match_game_screen.dart';

// Report-only: measures Mirror Match 12x12 tile size (dp) on the smallest phones.
// Android guidance is 48 dp touch targets; proposed floor is 24 dp (half that;
// the board is a fixed 320 dp square).
const _floorDp = 24.0;
// Skipped while the measured tile is below the floor (numbers in the PR; layout change is
// Jac's decision). Set to false to run the assertion.
const bool _skip = true;

void main() {
  // Real Roboto, as in phone_width_sweep_test.dart (Ahem would distort layout).
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

  for (final size in [const Size(320, 568), const Size(360, 640)]) {
    testWidgets('Mirror Match 12x12 tile >= ${_floorDp}dp at ${size.width.toInt()}x${size.height.toInt()}',
        (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(const MaterialApp(
        home: MirrorMatchGameScreen(
            gridSize: 12, symmetryType: 'vertical', moveMode: 'zen', testMode: true),
      ));
      await t.pump(const Duration(milliseconds: 500));

      // Board tiles: the GestureDetector cells (144 for 12x12); all share one size.
      final cells = find.descendant(
          of: find.byType(GestureDetector), matching: find.byType(AnimatedContainer));
      final s = t.getSize(cells.first);
      // ignore: avoid_print
      print('MEASURED ${size.width.toInt()}x${size.height.toInt()}: tile ${s.width} x ${s.height} dp, '
          'cells=${cells.evaluate().length}');
      expect(s.width, greaterThanOrEqualTo(_floorDp));
    }, skip: _skip);
  }
}
