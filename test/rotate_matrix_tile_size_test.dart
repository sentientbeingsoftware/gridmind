import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/rotate_matrix_game_screen.dart';

// Report-only: measures Rotate Matrix 10x10 tile size (dp) on the smallest phones.
// Android guidance is 48 dp touch targets; proposed floor is 24 dp (half that;
// the board must still fit 320x568 with the rotate controls).
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
    testWidgets('Rotate Matrix 10x10 tile >= ${_floorDp}dp at ${size.width.toInt()}x${size.height.toInt()}',
        (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(const MaterialApp(
        home: RotateMatrixGameScreen(
            gridSize: 10, difficulty: 'hard', moveMode: 'challenge', testMode: true),
      ));
      await t.pump(const Duration(milliseconds: 500));

      // Board tiles: the DecoratedBoxes that sit inside a GestureDetector and are tappable
      // cells (100 of them for 10x10). Take the smallest-pitch cell, i.e. the first.
      final cells = find.descendant(
          of: find.byType(GestureDetector), matching: find.byType(DecoratedBox));
      final s = t.getSize(cells.first);
      // ignore: avoid_print
      print('MEASURED ${size.width.toInt()}x${size.height.toInt()}: tile ${s.width} x ${s.height} dp, '
          'cells=${cells.evaluate().length}');
      expect(s.width, greaterThanOrEqualTo(_floorDp));
    }, skip: _skip);
  }
}
