import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'app_persistence_service.dart';

/// Short sound effects and haptic taps. Both are user toggles (Settings) and
/// every call is fire-and-forget: a missing plugin or audio failure never throws.
class GameEffects {
  GameEffects._();
  static final GameEffects instance = GameEffects._();

  final AppPersistenceService _prefs = AppPersistenceService();
  bool _sound = true;
  bool _haptics = true;
  bool _loaded = false;
  AudioPlayer? _player;

  /// Test hook: set to false to skip the audio plugin entirely.
  @visibleForTesting
  // The plugin does not exist under flutter test; its async init errors escape try/catch.
  bool audioPluginAvailable = !Platform.environment.containsKey('FLUTTER_TEST');

  /// Test hook: false = use Flutter's built-in HapticFeedback (the only option under flutter test).
  @visibleForTesting
  bool vibrationPluginAvailable = !Platform.environment.containsKey('FLUTTER_TEST');

  /// A tap of [ms] at [amplitude] (1-255). HapticFeedback cannot set a strength and is
  /// barely felt on many phones, so use the vibrator directly; fall back to [fallback].
  Future<void> _buzz(int ms, int amplitude, Future<void> Function() fallback) async {
    if (!vibrationPluginAvailable) {
      fallback().catchError((_) {});
      return;
    }
    try {
      // Android ignores the amplitude on hardware that cannot vary it.
      await Vibration.vibrate(duration: ms, amplitude: amplitude);
    } catch (e) {
      debugPrint('Haptic failed: $e');
      fallback().catchError((_) {});
    }
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    _sound = await _prefs.getSoundEffectsEnabled();
    _haptics = await _prefs.getHapticsEnabled();
  }

  /// Called by Settings so a toggle takes effect without a restart.
  void apply({bool? sound, bool? haptics}) {
    _loaded = true;
    if (sound != null) _sound = sound;
    if (haptics != null) _haptics = haptics;
  }

  Future<void> _play(String name) async {
    if (!audioPluginAvailable) return;
    try {
      final p = _player ??= AudioPlayer()
        ..setAudioContext(AudioContext(
          android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ));
      await p.stop();
      await p.setVolume(0.6);
      await p.play(AssetSource('sfx/$name.wav'));
    } catch (e) {
      debugPrint('Sound effect failed: $e');
    }
  }

  Future<void> tick() async {
    await _load();
    if (_haptics) await _buzz(30, 180, HapticFeedback.selectionClick);
  }

  Future<void> win() async {
    await _load();
    if (_haptics) await _buzz(70, 230, HapticFeedback.mediumImpact);
    if (_sound) await _play('win');
  }

  Future<void> lose() async {
    await _load();
    if (_haptics) await _buzz(140, 255, HapticFeedback.heavyImpact);
    if (_sound) await _play('lose');
  }

  /// Simon tones; [index] wraps over the 9 available notes.
  Future<void> note(int index) async {
    await _load();
    if (_sound) await _play('note${index % 9}');
  }
}
