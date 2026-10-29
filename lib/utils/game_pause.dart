import 'package:flutter/foundation.dart';

/// True while a screen laid over a running game (Settings) is open. Timed games check
/// it on every tick, so countdowns, movement and playback hold still until it closes.
class GamePause {
  GamePause._();
  static final ValueNotifier<bool> paused = ValueNotifier(false);
  static bool get isPaused => paused.value;

  /// For async sequences: waits here while paused.
  static Future<void> hold() async {
    while (paused.value) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}
