import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/cluster_game_screen.dart';
import 'package:gridmind/screens/grid_miner_game_screen.dart';
import 'package:gridmind/screens/grid_painter_game_screen.dart';
import 'package:gridmind/screens/path_weaver_game_screen.dart';
import 'package:gridmind/screens/rotate_matrix_game_screen.dart';
import 'package:gridmind/screens/word_search_game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Games that overflowed on short windows or at large system text.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final cases = <String, Widget Function()>{
    'grid painter 6 pure': () => const GridPainterGameScreen(gridSize: 6, gameMode: 'pure', moveMode: 'challenge'),
    'grid painter 6 show': () => const GridPainterGameScreen(gridSize: 6, gameMode: 'show', moveMode: 'challenge'),
    'rotate matrix 10': () => const RotateMatrixGameScreen(gridSize: 10, difficulty: 'hard', moveMode: 'challenge'),
    'cluster 6': () => const ClusterGameScreen(gridSize: 6, colorCount: 4, moveMode: 'challenge'),
    'word search': () => const WordSearchGameScreen(gridSize: 8, wordCount: 6, moveMode: 'classic', category: 'Animals'),
    'path weaver': () => const PathWeaverGameScreen(gridSize: 6, obstacleDensity: 0.2, oneWayPaths: true, powerUps: true),
    'grid miner': () => const GridMinerGameScreen(gridSize: 6, difficulty: 'hard', moveMode: 'challenge'),
  };
  for (final size in const [Size(360, 640), Size(340, 480)]) {
    for (final e in cases.entries) {
      testWidgets('${e.key} fits ${size.width.toInt()}x${size.height.toInt()} at 150% text', (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(MaterialApp(
          builder: (c, ch) => MediaQuery(
              data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.5)), child: ch!),
          home: e.value(),
        ));
        await t.pump(const Duration(milliseconds: 300));
        final ex = t.takeException();
        expect(ex, isNull, reason: ex?.toString().split('\n').first);
      });
    }
  }
}
