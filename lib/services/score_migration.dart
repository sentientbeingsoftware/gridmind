import 'package:shared_preferences/shared_preferences.dart';
import 'app_persistence_service.dart';

/// One-time copy of pre-mixin high scores into the config-keyed scheme
/// (`config_high_score_<game>_<k=v;...>`) that BaseSetupScreen and the
/// ConfigHighScoreMixin read. Legacy keys are left untouched, and an existing
/// config-keyed score is never overwritten.
class ScoreMigration {
  static const String doneFlag = 'scores_migrated_v1';

  // Defaults of the setup options the legacy keys did not record.
  static const double _simonDefaultSquares = 4.0;
  static const String _simonDefaultSpeed = 'normal';
  static const double _collapseDefaultMoves = 25.0;

  static Future<void> run([SharedPreferences? injected]) async {
    final prefs = injected ?? await SharedPreferences.getInstance();
    if (prefs.getBool(doneFlag) ?? false) return;
    final svc = AppPersistenceService();

    // Simon: one global score, so it can only belong to the default config.
    final simon = prefs.getInt('simon_high_score') ?? 0;
    if (simon > 0) {
      await _copy(prefs, svc, 'simon',
          {'numberOfSquares': _simonDefaultSquares, 'patternSpeed': _simonDefaultSpeed},
          simon, lowerIsBetter: false);
    }

    for (final key in prefs.getKeys().toList()) {
      // Other keys hold lists/strings/bools; getInt would throw on them.
      final raw = prefs.get(key);
      if (raw is! int || raw <= 0 || raw >= kNoScore) continue;
      final value = raw;

      // tile_slider_high_score_3x3 -> slideandsolve {gridSize: 3.0}
      final tile = RegExp(r'^tile_slider_high_score_(\d+)x\1$').firstMatch(key);
      if (tile != null) {
        await _copy(prefs, svc, 'slideandsolve',
            {'gridSize': double.parse(tile.group(1)!)}, value, lowerIsBetter: true);
        continue;
      }

      // pathweaver_highscore_<size>_<density>_<oneWay>_<powerUps>
      final path = RegExp(r'^pathweaver_highscore_(\d+)_([\d.]+)_(true|false)_(true|false)$')
          .firstMatch(key);
      if (path != null) {
        await _copy(
            prefs,
            svc,
            'pathweaver',
            {
              'gridSize': double.parse(path.group(1)!),
              'obstacleDensity': double.parse(path.group(2)!),
              'oneWayPaths': path.group(3) == 'true',
              'powerUps': path.group(4) == 'true',
            },
            value,
            lowerIsBetter: true);
        continue;
      }

      // collapse_moves_<grid>_<mechanic>_<target>_<minMatch> (the move limit
      // was not part of the legacy key, so it maps to the default limit).
      final collapse = RegExp(r'^collapse_moves_(\d+)_([A-Za-z]+)_(\d+)_(\d+)$').firstMatch(key);
      if (collapse != null) {
        await _copy(
            prefs,
            svc,
            'collapse',
            {
              'gridSize': double.parse(collapse.group(1)!),
              'mechanic': collapse.group(2)!,
              'targetScore': double.parse(collapse.group(3)!),
              'minMatchCount': double.parse(collapse.group(4)!),
              'moves': _collapseDefaultMoves,
            },
            value,
            lowerIsBetter: true);
      }
    }

    await prefs.setBool(doneFlag, true);
  }

  static Future<void> _copy(SharedPreferences prefs, AppPersistenceService svc, String gameId,
      Map<String, dynamic> config, int score, {required bool lowerIsBetter}) async {
    // updateConfigHighScore keeps the better of old/new, so it never regresses.
    await svc.updateConfigHighScore(gameId, config, score, lowerIsBetter: lowerIsBetter);
  }
}
