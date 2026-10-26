import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/settings_screen.dart';
import 'package:gridmind/services/app_persistence_service.dart';
import 'package:gridmind/services/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePlayer implements MusicPlayer {
  int starts = 0, pauses = 0;
  MusicTrack? track;
  @override
  Future<void> setTrack(MusicTrack t) async => track = t;
  @override
  Future<void> start() async => starts++;
  @override
  Future<void> pause() async => pauses++;
  @override
  Future<void> dispose() async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to enabled and plays on load', () async {
    final p = FakePlayer();
    final s = AudioService(player: p);
    await s.load();
    expect(s.enabled, isTrue);
    expect(p.starts, 1);
  });

  test('disabling pauses and persists; stays off after reload', () async {
    final p = FakePlayer();
    final s = AudioService(player: p);
    await s.load();
    await s.setEnabled(false);
    expect(p.pauses, 1);
    expect(await AppPersistenceService().getMusicEnabled(), isFalse);

    final p2 = FakePlayer();
    await AudioService(player: p2).load();
    expect(p2.starts, 0);
  });

  test('background pauses, foreground resumes only if enabled', () async {
    final p = FakePlayer();
    final s = AudioService(player: p);
    await s.load();
    await s.setForeground(false);
    expect(p.pauses, 1);
    await s.setForeground(true);
    expect(p.starts, 2);
    await s.setEnabled(false);
    await s.setForeground(false);
    await s.setForeground(true);
    expect(p.starts, 2);
  });

  testWidgets('settings switch toggles service', (tester) async {
    final p = FakePlayer();
    final s = AudioService(player: p);
    await tester.runAsync(s.load);
    await tester.pumpWidget(AudioScope(
      service: s,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();
    final tile = find.widgetWithText(SwitchListTile, 'Background Music');
    await tester.scrollUntilVisible(tile, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(tile);
    await tester.pump();
    expect(s.enabled, isFalse);
  });

  test('has 6 tracks with unique ids', () {
    expect(kMusicTracks.length, 6);
    expect(kMusicTracks.map((t) => t.id).toSet().length, 6);
  });

  test('track selection persists and is restored on load', () async {
    final p = FakePlayer();
    final s = AudioService(player: p);
    await s.load();
    expect(s.track.id, 'ambient_loop');
    await s.setTrack(kMusicTracks[3]);
    expect(p.track, kMusicTracks[3]);
    expect(await AppPersistenceService().getMusicTrack(), kMusicTracks[3].id);

    final p2 = FakePlayer();
    final s2 = AudioService(player: p2);
    await s2.load();
    expect(s2.track, kMusicTracks[3]);
    expect(p2.track, kMusicTracks[3]);
  });

  test('unknown saved track falls back to default', () async {
    SharedPreferences.setMockInitialValues({'background_music_track': 'nope'});
    final s = AudioService(player: FakePlayer());
    await s.load();
    expect(s.track.id, 'ambient_loop');
  });
}
