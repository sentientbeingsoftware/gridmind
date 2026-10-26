import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/services/app_persistence_service.dart';
import 'package:gridmind/services/game_registry.dart';
import 'package:gridmind/services/score_migration.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _defaults(String id) =>
    GameRegistry.games.firstWhere((g) => g.id == id).resolveConfig(null);

void main() {
  test('legacy scores become readable under the setup-screen key', () async {
    SharedPreferences.setMockInitialValues({
      'simon_high_score': 9,
      'tile_slider_high_score_4x4': 31,
      'tile_slider_high_score_5x5': 999999, // sentinel, must be ignored
      'pathweaver_highscore_7_0.15_false_true': 14,
      'collapse_moves_8_fromTop_1000_3': 12,
    });
    await ScoreMigration.run();
    final p = AppPersistenceService();

    expect(await p.getConfigHighScore('simon', _defaults('simon')), 9);
    expect(await p.getConfigHighScore('slideandsolve', {'gridSize': 4.0}), 31);
    expect(await p.getConfigHighScore('slideandsolve', {'gridSize': 5.0}), 0);
    expect(await p.getConfigHighScore('pathweaver', _defaults('pathweaver')), 14);
    expect(await p.getConfigHighScore('collapse', _defaults('collapse')), 12);
  });

  test('runs once, keeps legacy keys, never overwrites a better config score', () async {
    SharedPreferences.setMockInitialValues({'tile_slider_high_score_3x3': 40});
    final p = AppPersistenceService();
    await p.updateConfigHighScore('slideandsolve', {'gridSize': 3.0}, 25, lowerIsBetter: true);

    await ScoreMigration.run();
    expect(await p.getConfigHighScore('slideandsolve', {'gridSize': 3.0}), 25);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('tile_slider_high_score_3x3'), 40);
    expect(prefs.getBool(ScoreMigration.doneFlag), isTrue);

    // Second run is a no-op even if new legacy data appears.
    await prefs.setInt('tile_slider_high_score_4x4', 8);
    await ScoreMigration.run();
    expect(await p.getConfigHighScore('slideandsolve', {'gridSize': 4.0}), 0);
  });

  test('clearAllHighScores wipes both config-keyed and leftover legacy scores', () async {
    SharedPreferences.setMockInitialValues({
      'simon_high_score': 9,
      'tile_slider_high_score_3x3': 20,
      'pathweaver_highscore_7_0.15_false_true': 14,
      'collapse_moves_8_fromTop_1000_3': 12,
      'favorite_games': ['simon'],
    });
    await ScoreMigration.run();
    await AppPersistenceService().clearAllHighScores();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((k) => k.contains('high') || k.startsWith('collapse_moves')), isEmpty);
    expect(prefs.getStringList('favorite_games'), ['simon']);
  });
}
