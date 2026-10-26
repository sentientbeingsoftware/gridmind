import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'app_persistence_service.dart';

/// A selectable background music track.
class MusicTrack {
  const MusicTrack(this.id, this.name, this.asset);
  final String id;
  final String name;
  final String asset; // path relative to assets/
}

const List<MusicTrack> kMusicTracks = [
  MusicTrack('ambient_loop', 'Ambient Drift', 'audio/ambient_loop.wav'),
  MusicTrack('soft_pads', 'Soft Pads', 'audio/soft_pads.wav'),
  MusicTrack('deep_space', 'Deep Space', 'audio/deep_space.wav'),
  MusicTrack('gentle_chimes', 'Gentle Chimes', 'audio/gentle_chimes.wav'),
  MusicTrack('warm_drone', 'Warm Drone', 'audio/warm_drone.wav'),
  MusicTrack('night_pulse', 'Night Pulse', 'audio/night_pulse.wav'),
];

const String kDefaultMusicTrackId = 'ambient_loop';

MusicTrack musicTrackById(String? id) => kMusicTracks.firstWhere(
      (t) => t.id == id,
      orElse: () => kMusicTracks.first,
    );

/// Minimal player surface so tests can swap in a fake.
abstract class MusicPlayer {
  /// Selects the track to play; takes effect immediately if playing.
  Future<void> setTrack(MusicTrack track);
  Future<void> start();
  Future<void> pause();
  Future<void> dispose();
}

class _AssetLoopPlayer implements MusicPlayer {
  late final AudioPlayer _player = AudioPlayer();
  bool _ready = false;
  bool _playing = false;
  MusicTrack _track = kMusicTracks.first;
  MusicTrack? _loaded;

  @override
  Future<void> setTrack(MusicTrack track) async {
    _track = track;
    if (_ready && _loaded != track) {
      await _player.setSource(AssetSource(track.asset));
      _loaded = track;
      if (_playing) await _player.resume();
    }
  }

  Future<void> _init() async {
    if (_ready) return;
    // Mix with other apps instead of stealing audio focus, so podcasts and
    // audiobooks keep playing.
    await _player.setAudioContext(AudioContext(
      android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
      iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    ));
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(0.4);
    await _player.setSource(AssetSource(_track.asset));
    _loaded = _track;
    _ready = true;
  }

  @override
  Future<void> start() async {
    await _init();
    await _player.resume();
    _playing = true;
  }

  @override
  Future<void> pause() async {
    _playing = false;
    if (_ready) await _player.pause();
  }

  @override
  Future<void> dispose() async {
    if (_ready) await _player.dispose();
  }
}

/// App-wide background music. Preference is persisted; failures never throw.
class AudioService extends ChangeNotifier {
  AudioService({MusicPlayer? player, AppPersistenceService? persistence})
      : _player = player ?? _AssetLoopPlayer(),
        _persistence = persistence ?? AppPersistenceService();

  final MusicPlayer _player;
  final AppPersistenceService _persistence;
  bool _enabled = true;
  bool _inForeground = true;
  bool _playing = false;
  MusicTrack _track = kMusicTracks.first;

  MusicTrack get track => _track;

  bool get enabled => _enabled;
  bool get isPlaying => _playing;

  Future<void> load() async {
    _enabled = await _persistence.getMusicEnabled();
    _track = musicTrackById(await _persistence.getMusicTrack());
    try {
      await _player.setTrack(_track);
    } catch (e) {
      debugPrint('Background music unavailable: $e');
    }
    notifyListeners();
    await _sync();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    notifyListeners();
    await _persistence.setMusicEnabled(value);
    await _sync();
  }

  Future<void> setTrack(MusicTrack track) async {
    _track = track;
    notifyListeners();
    await _persistence.setMusicTrack(track.id);
    try {
      await _player.setTrack(track);
    } catch (e) {
      debugPrint('Background music unavailable: $e');
    }
  }

  /// Pause when the app is backgrounded; resume on return if still enabled.
  Future<void> setForeground(bool value) async {
    _inForeground = value;
    await _sync();
  }

  Future<void> _sync() async {
    final shouldPlay = _enabled && _inForeground;
    if (shouldPlay == _playing) return;
    try {
      if (shouldPlay) {
        await _player.start();
      } else {
        await _player.pause();
      }
      _playing = shouldPlay;
    } catch (e) {
      debugPrint('Background music unavailable: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

/// Exposes the [AudioService] to descendants.
class AudioScope extends InheritedWidget {
  const AudioScope({super.key, required this.service, required super.child});

  final AudioService service;

  /// Null when no scope exists (e.g. a screen mounted alone in a test).
  static AudioService? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AudioScope>()?.service;

  @override
  bool updateShouldNotify(AudioScope oldWidget) => service != oldWidget.service;
}
