import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// Sentinel for "no score recorded yet" on lower-is-better metrics (moves, steps).
const int kNoScore = 999999;

class AppPersistenceService {
  // Pre-ConfigHighScoreMixin keys. Read once by ScoreMigration; only cleared here.
  static const String _legacyKeyPrefixes = r'^(collapse_high_score|simon_high_score|word_search_high_score|tile_slider_high_score_.*|collapse_moves_.*|pathweaver_highscore_.*)$';

  Future<SharedPreferences> _getPrefs() async {
    return SharedPreferences.getInstance();
  }

  /// Generates a configuration-aware persistent score key for a given game
  String _getConfigHighScoreKey(String gameId, Map<String, dynamic> config) {
    final sortedKeys = config.keys.toList()..sort();
    final parts = sortedKeys.map((k) {
      final v = config[k];
      final displayVal = (v is double)
          ? v.toStringAsFixed(4)
          : (v is Enum ? v.name : v.toString());
      return '$k=$displayVal';
    }).join(';');
    return 'config_high_score_${gameId}_$parts';
  }

  /// Get the configuration-aware high score
  Future<int> getConfigHighScore(String gameId, Map<String, dynamic> config) async {
    final key = _getConfigHighScoreKey(gameId, config);
    final prefs = await _getPrefs();
    return prefs.getInt(key) ?? 0;
  }

  /// Updates the configuration-aware high score if the new score is better.
  /// lowerIsBetter: true for moves/times, false for score/sequence lengths.
  Future<bool> updateConfigHighScore(String gameId, Map<String, dynamic> config, int newScore, {bool lowerIsBetter = false}) async {
    if (newScore <= 0) return false;
    final key = _getConfigHighScoreKey(gameId, config);
    final prefs = await _getPrefs();
    int currentBest = prefs.getInt(key) ?? (lowerIsBetter ? kNoScore : 0);
    
    bool isBetter = lowerIsBetter ? (newScore < currentBest) : (newScore > currentBest);
    if (isBetter) {
      await prefs.setInt(key, newScore);
      return true;
    }
    return false;
  }

  Future<void> setLastConfig(String game, Map<String, dynamic> config) async {
    final prefs = await _getPrefs();
    await prefs.setString('last_config_$game', json.encode(config, toEncodable: (o) => o is Enum ? o.name : o));
  }

  Future<Map<String, dynamic>?> getLastConfig(String game) async {
    final prefs = await _getPrefs();
    final str = prefs.getString('last_config_$game');
    if (str == null || str.isEmpty) return null;
    try {
      return json.decode(str) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  static const String _paletteTypeKey = 'color_palette_type';
  static const String _customPaletteKey = 'custom_palette_colors';

  Future<void> setPaletteType(String type) async {
    final prefs = await _getPrefs();
    await prefs.setString(_paletteTypeKey, type);
  }

  Future<String> getPaletteType() async {
    final prefs = await _getPrefs();
    return prefs.getString(_paletteTypeKey) ?? 'random';
  }

  Future<void> setCustomPalette(List<Color> colors) async {
    final prefs = await _getPrefs();
    final hexList = colors.map((c) => c.toARGB32().toRadixString(16)).join(',');
    await prefs.setString(_customPaletteKey, hexList);
  }

  Future<List<Color>> getCustomPalette() async {
    final prefs = await _getPrefs();
    final hexList = prefs.getString(_customPaletteKey);
    if (hexList == null || hexList.isEmpty) return [];
    return hexList.split(',').map((hex) {
      try {
        return Color(int.parse(hex, radix: 16));
      } catch (_) {
        return Colors.grey;
      }
    }).toList();
  }

  static const String _themeModeKey = 'app_theme_mode';

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await _getPrefs();
    await prefs.setString(_themeModeKey, mode.toString());
  }

  Future<ThemeMode> getThemeMode() async {
    final prefs = await _getPrefs();
    final modeStr = prefs.getString(_themeModeKey);
    if (modeStr == null) return ThemeMode.system;
    return ThemeMode.values.firstWhere(
      (e) => e.toString() == modeStr,
      orElse: () => ThemeMode.system,
    );
  }

  static const String _musicEnabledKey = 'background_music_enabled';

  Future<bool> getMusicEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_musicEnabledKey) ?? true;
  }

  Future<void> setMusicEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_musicEnabledKey, enabled);
  }

  static const String _musicTrackKey = 'background_music_track';

  Future<String> getMusicTrack() async {
    final prefs = await _getPrefs();
    return prefs.getString(_musicTrackKey) ?? 'ambient_loop';
  }

  Future<void> setMusicTrack(String trackId) async {
    final prefs = await _getPrefs();
    await prefs.setString(_musicTrackKey, trackId);
  }

  Future<void> clearAllHighScores() async {
    final prefs = await _getPrefs();
    final legacy = RegExp(_legacyKeyPrefixes);
    for (final k in prefs.getKeys().toList()) {
      if (k.startsWith('config_high_score_') || legacy.hasMatch(k)) {
        await prefs.remove(k);
      }
    }
  }

  // Walkthrough ("how to play") seen state
  static const String _walkthroughPrefix = 'walkthrough_seen_';

  Future<bool> hasSeenWalkthrough(String gameId) async {
    final prefs = await _getPrefs();
    return prefs.getBool('$_walkthroughPrefix$gameId') ?? false;
  }

  Future<void> setWalkthroughSeen(String gameId, {bool seen = true}) async {
    final prefs = await _getPrefs();
    await prefs.setBool('$_walkthroughPrefix$gameId', seen);
  }

  /// Clears the seen flag so the walkthrough shows again on next launch.
  Future<void> resetWalkthrough(String gameId) async {
    final prefs = await _getPrefs();
    await prefs.remove('$_walkthroughPrefix$gameId');
  }

  Future<void> resetAllWalkthroughs() async {
    final prefs = await _getPrefs();
    for (final k in prefs.getKeys().toList()) {
      if (k.startsWith(_walkthroughPrefix)) await prefs.remove(k);
    }
  }

  // Favorites management
  static const String _favoritesKey = 'favorite_games';

  /// Returns the set of favorited game IDs.
  Future<Set<String>> getFavorites() async {
    final prefs = await _getPrefs();
    return (prefs.getStringList(_favoritesKey) ?? <String>[]).toSet();
  }

  /// Toggles the favorited status of a game by ID.
  Future<Set<String>> toggleFavorite(String gameId) async {
    final prefs = await _getPrefs();
    final current = (prefs.getStringList(_favoritesKey) ?? <String>[]).toSet();
    final updated = Set<String>.from(current);
    if (updated.contains(gameId)) {
      updated.remove(gameId);
    } else {
      updated.add(gameId);
    }
    await prefs.setStringList(_favoritesKey, updated.toList());
    return updated;
  }

  /// Explicitly sets the favorites set.
  Future<void> setFavorites(Set<String> ids) async {
    final prefs = await _getPrefs();
    await prefs.setStringList(_favoritesKey, ids.toList());
  }

  static Future<List<Color>> getPaletteForGame({required int colorCount}) async {
    final svc = AppPersistenceService();
    final type = await svc.getPaletteType();
    List<Color> palette = [];
    if (type == 'preset1') {
      palette = [
        Colors.red,
        Colors.green,
        Colors.blue,
        Colors.yellow,
        Colors.purple,
        Colors.orange,
        Colors.cyan,
        Colors.pink,
        Colors.teal
      ];
    } else if (type == 'preset2') {
      palette = const [
        Color(0xFFFFB3BA),
        Color(0xFFBAE1FF),
        Color(0xFFBAFFC9),
        Color(0xFFFFFFBA),
        Color(0xFFFFDFBA),
        Color(0xFFB3FFD9),
        Color(0xFFB3B3FF),
        Color(0xFFFFB3FF),
        Color(0xFFB3FFF6)
      ];
    } else if (type == 'preset3') {
      palette = [
        Colors.black,
        Colors.white,
        Colors.yellow,
        Colors.cyan,
        Colors.deepOrange,
        Colors.lime,
        Colors.blue,
        Colors.pink,
        Colors.red
      ];
    } else if (type == 'preset4') {
      palette = const [
        Color(0xFF377eb8),
        Color(0xFFff7f00),
        Color(0xFF984ea3),
        Color(0xFF4daf4a),
        Color(0xFFf781bf),
        Color(0xFFa65628),
        Color(0xFF999999),
        Color(0xFFe41a1c),
        Color(0xFFdede00)
      ];
    } else if (type == 'custom') {
      palette = await svc.getCustomPalette();
    }
    if (type == 'random' || palette.length < colorCount) {
      List<Color> allColors = [
        Colors.red,
        Colors.green,
        Colors.blue,
        Colors.yellow,
        Colors.purple,
        Colors.orange,
        Colors.cyan,
        Colors.pink,
        Colors.teal,
        Colors.amber,
        Colors.indigo,
        Colors.brown,
        Colors.lime,
        Colors.lightBlue,
        Colors.deepPurple,
        Colors.lightGreen,
        Colors.deepOrange,
        Colors.blueGrey,
        Colors.white,
        Colors.black
      ];
      allColors.shuffle();
      palette = allColors.take(colorCount).toList();
    }
    return palette.take(colorCount).toList();
  }
}
