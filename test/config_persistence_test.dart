import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/models/pattern_speed.dart';
import 'package:gridmind/services/app_persistence_service.dart';
import 'package:gridmind/services/game_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('enum config values survive a save/load round trip (Simon speed)', () async {
    final p = AppPersistenceService();
    final simon = GameRegistry.games.firstWhere((g) => g.id == 'simon');
    final chosen = simon.resolveConfig(null)..['patternSpeed'] = PatternSpeed.fast;

    await p.setLastConfig('simon', chosen);
    final restored = simon.resolveConfig(await p.getLastConfig('simon'));

    expect(restored['patternSpeed'], PatternSpeed.fast);
    expect(restored['numberOfSquares'], chosen['numberOfSquares']);
  });

  test('every registry game round-trips its non-default config to the same score key', () async {
    final p = AppPersistenceService();
    for (final game in GameRegistry.games) {
      final cfg = game.resolveConfig(null);
      await p.setLastConfig(game.id, cfg);
      final restored = game.resolveConfig(await p.getLastConfig(game.id));
      await p.updateConfigHighScore(game.id, cfg, 5);
      expect(await p.getConfigHighScore(game.id, restored), 5, reason: game.id);
    }
  });

  test('unknown stored enum name falls back to default', () {
    final simon = GameRegistry.games.firstWhere((g) => g.id == 'simon');
    expect(simon.resolveConfig({'patternSpeed': 'bogus'})['patternSpeed'], PatternSpeed.normal);
  });
}
