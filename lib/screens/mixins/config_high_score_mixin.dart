import 'package:flutter/widgets.dart';
import '../../services/app_persistence_service.dart';

/// Shared high-score handling for games whose best score is keyed by
/// (game id + config). Replaces the per-screen copies of the config map,
/// load/save methods and the "no score" sentinel.
///
/// Usage: implement [highScoreGameId], [highScoreConfig] and
/// [highScoreLowerIsBetter], call [loadBestScore] when the game starts and
/// [submitScore] when it ends. [bestScore] is null until a score exists.
mixin ConfigHighScoreMixin<T extends StatefulWidget> on State<T> {
  final AppPersistenceService highScorePersistence = AppPersistenceService();

  String get highScoreGameId;

  /// Must match the config the setup screen uses to look the score up.
  Map<String, dynamic> get highScoreConfig;

  /// true for moves/steps/time, false for points/length.
  bool get highScoreLowerIsBetter;

  /// Best recorded score for the current config, or null if none yet.
  int? bestScore;

  /// Loads the stored best score. Does not call setState; callers typically
  /// fold the value into their own setState together with other loaded data.
  Future<int?> loadBestScore() async {
    final stored = await highScorePersistence.getConfigHighScore(
      highScoreGameId,
      highScoreConfig,
    );
    // Persistence returns 0 when nothing is stored, for both directions.
    return stored > 0 ? stored : null;
  }

  /// Records [score] if it beats the stored best; returns whether it did.
  Future<bool> submitScore(int score) async {
    final improved = await highScorePersistence.updateConfigHighScore(
      highScoreGameId,
      highScoreConfig,
      score,
      lowerIsBetter: highScoreLowerIsBetter,
    );
    if (improved && mounted) {
      setState(() => bestScore = score);
    }
    return improved;
  }
}
