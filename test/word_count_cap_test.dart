import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/models/game_metadata.dart';
import 'package:gridmind/screens/base_setup_screen.dart';
import 'package:gridmind/services/game_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Word Search: the Word Count slider may not promise more words than the grid holds.
void main() {
  final game = GameRegistry.games.firstWhere((g) => g.id == 'wordsearch');
  final words = game.configOptions.firstWhere((o) => o.key == 'wordCount') as SliderConfigOption;

  test('cap grows with grid size and stays inside the slider range', () {
    double cap(double size) => words.maxFor!({'gridSize': size}).clamp(words.min, words.max);
    expect(cap(6), 5);
    expect(cap(8), 8);
    expect(cap(20), 20);
    for (var s = 6.0; s < 20; s++) {
      expect(cap(s + 1), greaterThanOrEqualTo(cap(s)));
    }
  });

  test('a saved word count above the cap is pulled down', () {
    final c = game.resolveConfig({'gridSize': 6.0, 'wordCount': 18.0});
    expect(c['wordCount'], 5.0);
    expect(game.resolveConfig({'gridSize': 12.0, 'wordCount': 14.0})['wordCount'], 13.0);
  });

  testWidgets('setup screen: lowering Grid Size lowers Word Count and its slider maximum', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(400, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(home: BaseSetupScreen(game: game)));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await t.pump(const Duration(milliseconds: 300));
    final sliders = find.byType(Slider);
    // Word Count up to the top of its range at the default 8x8, then drop the grid to 6.
    Slider at(int i) => t.widget<Slider>(sliders.at(i));
    expect(at(1).max, 8);
    at(1).onChanged!(8);
    await t.pump();
    at(0).onChanged!(6);
    await t.pump();
    expect(at(1).max, 5);
    expect(at(1).value, 5);
  });
}
