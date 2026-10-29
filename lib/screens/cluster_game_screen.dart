import '../utils/color_names.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/app_persistence_service.dart';
import 'mixins/config_high_score_mixin.dart';
import 'base_game_screen.dart';

/// Largest group of orthogonally connected same-colour tiles.
@visibleForTesting
int largestCluster(List<List<Color>> g) {
  final n = g.length;
  final seen = {for (var r = 0; r < n; r++) for (var c = 0; c < n; c++) Point(r, c): false};
  var best = 0;
  for (final start in seen.keys.toList()) {
    if (seen[start]!) continue;
    final stack = [start];
    seen[start] = true;
    var size = 0;
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      size++;
      for (final q in [Point(p.x + 1, p.y), Point(p.x - 1, p.y), Point(p.x, p.y + 1), Point(p.x, p.y - 1)]) {
        if (seen[q] == false && g[q.x][q.y] == g[p.x][p.y]) {
          seen[q] = true;
          stack.add(q);
        }
      }
    }
    best = max(best, size);
  }
  return best;
}

/// A board that can always be won: grow a [target]-tile cluster, fill the rest at
/// random, then scramble with [swapCount] swaps. Undoing them in reverse is a solution.
/// Random fill alone is often unwinnable (6x6 with 4+ colours: most boards have no
/// colour with enough tiles).
@visibleForTesting
({List<List<Color>> grid, List<(Point<int>, Point<int>)> swaps}) makeWinnableCluster(
    int n, List<Color> palette, int target, int swapCount, Random rand) {
  late List<List<Color>> grid;
  late List<(Point<int>, Point<int>)> swaps;
  // Retry until the scramble really leaves the board un-won; the cap only guards a loop.
  for (var attempt = 0; attempt < 200; attempt++) {
    // The cluster colour appears only in the cluster, so a scramble that splits it
    // always leaves the board un-won.
    final win = palette[rand.nextInt(palette.length)];
    final others = palette.where((c) => c != win).toList();
    grid = List.generate(n, (_) => List.generate(n, (_) => others[rand.nextInt(others.length)]));
    final blob = {Point(rand.nextInt(n), rand.nextInt(n))};
    while (blob.length < target) {
      final p = blob.elementAt(rand.nextInt(blob.length));
      final q = [Point(p.x + 1, p.y), Point(p.x - 1, p.y), Point(p.x, p.y + 1), Point(p.x, p.y - 1)][rand.nextInt(4)];
      if (q.x >= 0 && q.x < n && q.y >= 0 && q.y < n) blob.add(q);
    }
    for (final p in blob) {
      grid[p.x][p.y] = win;
    }
    swaps = [];
    for (var tries = 0; swaps.length < swapCount && tries < 500; tries++) {
      final a = Point(rand.nextInt(n), rand.nextInt(n));
      final b = rand.nextBool() ? Point(a.x + 1, a.y) : Point(a.x, a.y + 1);
      if (b.x >= n || b.y >= n || grid[a.x][a.y] == grid[b.x][b.y]) continue;
      final t = grid[a.x][a.y];
      grid[a.x][a.y] = grid[b.x][b.y];
      grid[b.x][b.y] = t;
      swaps.add((a, b));
    }
    if (largestCluster(grid) < target) break;
  }
  return (grid: grid, swaps: swaps);
}

/// Cluster Game
///
/// A connected-color matching puzzle. Players swap adjacent tiles to build the
/// largest possible cluster of matching colors within move limits.
class ClusterGameScreen extends StatefulWidget {
  final int gridSize;
  final int colorCount;
  final String moveMode; // 'zen' or 'challenge'
  final bool testMode;
  final List<List<Color>>? testGrid; // deterministic layout for tests

  const ClusterGameScreen({
    super.key,
    required this.gridSize,
    required this.colorCount,
    required this.moveMode,
    this.testMode = false,
    this.testGrid,
  });

  @override
  State<ClusterGameScreen> createState() => _ClusterGameScreenState();
}

class _ClusterGameScreenState extends State<ClusterGameScreen> with ConfigHighScoreMixin<ClusterGameScreen> {
  @override
  String get highScoreGameId => 'cluster';
  @override
  bool get highScoreLowerIsBetter => false;
  @override
  Map<String, dynamic> get highScoreConfig => {
        'gridSize': widget.gridSize.toDouble(),
        'colorCount': widget.colorCount.toDouble(),
        'moveMode': widget.moveMode,
      };
  final Random _rand = Random();

  late List<List<Color>> _grid;

  int _moves = 0;
  int _moveLimit = 15;
  int _maxClusterSize = 0;
  int _targetClusterSize = 0;

  bool _isGameOver = false;
  bool _isGameWon = false;

  int? _selectedRow;
  int? _selectedCol;

  final List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _grid = [];
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    final colors = await AppPersistenceService.getPaletteForGame(colorCount: widget.colorCount);
    final palette = colors.isNotEmpty
        ? colors.take(widget.colorCount).toList()
        : [Colors.indigo, Colors.blue, Colors.teal, Colors.purple, Colors.pink]
            .take(widget.colorCount)
            .toList();

    final stored = await loadBestScore();
    if (!mounted) return;

    // Target cluster size: 40% of the board.
    final target = (widget.gridSize * widget.gridSize * 0.4).round();

    // Initial grid setup
    List<List<Color>> grid;
    if (widget.testMode && widget.testGrid != null) {
      grid = List.generate(
        widget.gridSize,
        (r) => List<Color>.from(widget.testGrid![r]),
      );
    } else {
      grid = makeWinnableCluster(widget.gridSize, palette, target, widget.gridSize * 3 ~/ 2, _rand).grid;
    }

    setState(() {
      _grid = grid;
      _moves = 0;
      _moveLimit = widget.gridSize * 3;
      _targetClusterSize = target;
      bestScore = stored;
      _isGameOver = false;
      _isGameWon = false;
      _selectedRow = null;
      _selectedCol = null;
      _history.clear();
      _recalculateScore();
    });
  }

  void _recalculateScore() {
    final size = widget.gridSize;
    final visited = List.generate(size, (_) => List.generate(size, (_) => false));
    int maxCluster = 0;

    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (!visited[r][c]) {
          int count = _exploreCluster(r, c, _grid[r][c], visited);
          if (count > maxCluster) {
            maxCluster = count;
          }
        }
      }
    }

    setState(() {
      _maxClusterSize = maxCluster;
      if (_maxClusterSize >= _targetClusterSize) {
        _isGameWon = true;
      } else if (widget.moveMode == 'challenge' && _moves >= _moveLimit) {
        _isGameOver = true;
      }
    });
  }

  int _exploreCluster(int startRow, int startCol, Color targetColor, List<List<bool>> visited) {
    int count = 0;
    final List<Point<int>> queue = [Point(startRow, startCol)];
    visited[startRow][startCol] = true;

    final dRow = [-1, 1, 0, 0];
    final dCol = [0, 0, -1, 1];

    while (queue.isNotEmpty) {
      final curr = queue.removeAt(0);
      count++;

      for (int i = 0; i < 4; i++) {
        final nr = curr.x + dRow[i];
        final nc = curr.y + dCol[i];

        if (nr >= 0 && nr < widget.gridSize && nc >= 0 && nc < widget.gridSize) {
          if (!visited[nr][nc] && _grid[nr][nc] == targetColor) {
            visited[nr][nc] = true;
            queue.add(Point(nr, nc));
          }
        }
      }
    }

    return count;
  }

  void _saveSnapshot() {
    final gridCopy = List.generate(
      widget.gridSize,
      (r) => List<Color>.from(_grid[r]),
    );

    _history.add({
      'grid': gridCopy,
      'moves': _moves,
      'isGameOver': _isGameOver,
      'isGameWon': _isGameWon,
      'maxClusterSize': _maxClusterSize,
    });
  }

  void _undo() {
    if (_history.isEmpty || _isGameOver || _isGameWon) return;

    setState(() {
      final snap = _history.removeLast();
      _grid = snap['grid'] as List<List<Color>>;
      _moves = snap['moves'] as int;
      _isGameOver = snap['isGameOver'] as bool;
      _isGameWon = snap['isGameWon'] as bool;
      _maxClusterSize = snap['maxClusterSize'] as int;
      _selectedRow = null;
      _selectedCol = null;
    });
  }

  bool _isAdjacent(int r1, int c1, int r2, int c2) {
    return (r1 - r2).abs() + (c1 - c2).abs() == 1;
  }

  void _onCellTap(int r, int c) async {
    if (_isGameOver || _isGameWon) return;

    if (_selectedRow == null) {
      setState(() {
        _selectedRow = r;
        _selectedCol = c;
      });
    } else {
      final sr = _selectedRow!;
      final sc = _selectedCol!;

      if (sr == r && sc == c) {
        // Deselect
        setState(() {
          _selectedRow = null;
          _selectedCol = null;
        });
      } else if (_isAdjacent(sr, sc, r, c)) {
        // Perform Swap
        _saveSnapshot();
        setState(() {
          final temp = _grid[sr][sc];
          _grid[sr][sc] = _grid[r][c];
          _grid[r][c] = temp;
          _moves++;
          _selectedRow = null;
          _selectedCol = null;
        });

        _recalculateScore();

        if (_isGameWon || _isGameOver) {
          await submitScore(_maxClusterSize);
        }
      } else {
        // Change selection
        setState(() {
          _selectedRow = r;
          _selectedCol = c;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final moveInfo = widget.moveMode == 'challenge'
        ? '$_moves/$_moveLimit'
        : '$_moves (Zen)';

    return BaseGameScreen(
      title: 'Cluster',
      gameId: 'cluster',
      gameConfig: {
        'gridSize': widget.gridSize,
        'colorCount': widget.colorCount,
        'moveMode': widget.moveMode,
      },
      highScoreLabel: 'Best Cluster',
      highScoreValue: bestScore?.toString() ?? '--',
      currentScoreLabel: 'Max Cluster',
      currentScoreValue: '$_maxClusterSize/$_targetClusterSize',
      statusText: widget.moveMode == 'challenge'
          ? 'Swaps remaining: ${_moveLimit - _moves}'
          : 'Zen Mode (Unlimited Swaps)',
      isGameWon: _isGameWon,
      isGameOver: _isGameOver,
      victoryMessage: 'Victory! Target cluster reached.',
      gameOverMessage: 'Out of Swaps!',
      onReset: _initializeGame,
      onUndo: _history.isNotEmpty ? _undo : null,
      isGameInProgress: _moves > 0 && !_isGameOver && !_isGameWon,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Moves: $moveInfo',
              style: theme.textTheme.titleMedium,
            ),
          ),
          Container(
            width: 320,
            height: 320,
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
            ),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: widget.gridSize,
                mainAxisSpacing: 4.0,
                crossAxisSpacing: 4.0,
              ),
              itemCount: widget.gridSize * widget.gridSize,
              itemBuilder: (context, index) {
                final r = index ~/ widget.gridSize;
                final c = index % widget.gridSize;

                if (_grid.isEmpty || r >= _grid.length || c >= _grid[r].length) {
                  return const SizedBox();
                }

                final color = _grid[r][c];
                final isSelected = _selectedRow == r && _selectedCol == c;

                return Semantics(
label: 'Row ${r + 1}, column ${c + 1}, ${colorName(color)}${isSelected ? ", selected" : ""}',
button: true,
child: GestureDetector(
                  onTap: () => _onCellTap(r, c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.amberAccent : theme.colorScheme.outline.withValues(alpha: 0.15),
                        width: isSelected ? 3.5 : 1.0,
                      ),
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.swap_horiz,
                            size: widget.gridSize > 5 ? 16 : 24,
                            color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                          )
                        : null,
                  ),
                ),
);
              },
            ),
          ),
        ],
      ),
    );
  }
}
