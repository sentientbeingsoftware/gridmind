import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:collection'; // Added for Queue
import 'base_game_screen.dart';
import 'mixins/config_high_score_mixin.dart';

class PathWeaverGameScreen extends StatefulWidget {
  final int gridSize;
  final double obstacleDensity;
  final bool oneWayPaths;
  final bool powerUps;
  final bool testMode;
  final List<Point<int>>? testPath;
  final List<List<PathCell>>? testGrid;

  const PathWeaverGameScreen({
    super.key,
    required this.gridSize,
    required this.obstacleDensity,
    required this.oneWayPaths,
    required this.powerUps,
    this.testMode = false,
    this.testPath,
    this.testGrid,
  });

  @override
  State<PathWeaverGameScreen> createState() => _PathWeaverGameScreenState();
}

class PathCell {
  bool isObstacle;
  bool isStart;
  bool isEnd;
  bool isPath;
  bool isPowerUp;
  bool isOneWay;
  Offset? oneWayDirection; // e.g., Offset(1,0) for right

  PathCell({
    this.isObstacle = false,
    this.isStart = false,
    this.isEnd = false,
    this.isPath = false,
    this.isPowerUp = false,
    this.isOneWay = false,
    this.oneWayDirection,
  });

  PathCell clone() {
    return PathCell(
      isObstacle: isObstacle,
      isStart: isStart,
      isEnd: isEnd,
      isPath: isPath,
      isPowerUp: isPowerUp,
      isOneWay: isOneWay,
      oneWayDirection: oneWayDirection,
    );
  }
}

/// Shortest 4-way route from the top-left to the bottom-right corner over cells that are
/// not [blocked]. Neighbours are tried in random order so ties differ from game to game.
List<Point<int>>? _route(int n, bool Function(int r, int c) blocked, Random rand) {
  final prev = List.generate(n, (_) => List<Point<int>?>.filled(n, null));
  final seen = List.generate(n, (_) => List<bool>.filled(n, false));
  final queue = Queue<Point<int>>()..add(const Point(0, 0));
  seen[0][0] = true;
  final dirs = [const Point(1, 0), const Point(-1, 0), const Point(0, 1), const Point(0, -1)];
  while (queue.isNotEmpty) {
    final cur = queue.removeFirst();
    if (cur.x == n - 1 && cur.y == n - 1) {
      final path = <Point<int>>[];
      for (Point<int>? p = cur; p != null; p = prev[p.x][p.y]) {
        path.add(p);
      }
      return path.reversed.toList();
    }
    dirs.shuffle(rand);
    for (final d in dirs) {
      final r = cur.x + d.x, c = cur.y + d.y;
      if (r < 0 || r >= n || c < 0 || c >= n || seen[r][c] || blocked(r, c)) continue;
      seen[r][c] = true;
      prev[r][c] = cur;
      queue.add(Point(r, c));
    }
  }
  return null;
}

/// True when the end cannot be reached without stepping on a one-way cell, even after
/// every power-up has cleared its 3x3 area.
bool _oneWayIsRequired(List<List<PathCell>> grid, Random rand) {
  final n = grid.length;
  bool nearPowerUp(int r, int c) {
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        final rr = r + dr, cc = c + dc;
        if (rr >= 0 && rr < n && cc >= 0 && cc < n && grid[rr][cc].isPowerUp) return true;
      }
    }
    return false;
  }

  return _route(n, (r, c) => grid[r][c].isOneWay || (grid[r][c].isObstacle && !nearPowerUp(r, c)), rand) == null;
}

/// Fills [grid] (start and end already flagged) with obstacles, one-way cells and power-ups.
///
/// Obstacles go where they lengthen the shortest route the most, so the board winds
/// instead of being open with a few random blocks. With [oneWayPaths] one cell on the
/// route becomes a gate that can only be entered along the route, and every other way
/// round it is walled off, so the end cannot be reached without using a one-way cell.
@visibleForTesting
void layoutPathWeaverGrid(
  List<List<PathCell>> grid, {
  required double obstacleDensity,
  required bool oneWayPaths,
  required bool powerUps,
  required Random rand,
}) {
  final n = grid.length;
  bool isEnd(int r, int c) => (r == 0 && c == 0) || (r == n - 1 && c == n - 1);

  // 1. Winding obstacles.
  final wanted = min((n * n * obstacleDensity).round(), n * n - 2);
  for (var placed = 0; placed < wanted; placed++) {
    final route = _route(n, (r, c) => grid[r][c].isObstacle, rand)!;
    final scored = <(int, double, Point<int>)>[];
    for (final p in route.sublist(1, route.length - 1)) {
      grid[p.x][p.y].isObstacle = true;
      final alt = _route(n, (r, c) => grid[r][c].isObstacle, rand);
      grid[p.x][p.y].isObstacle = false;
      if (alt != null) scored.add((alt.length, rand.nextDouble(), p));
    }
    if (scored.isEmpty) {
      // Every cell on the route is a chokepoint: spend the rest off the route.
      final onRoute = route.toSet();
      final spare = [
        for (var r = 0; r < n; r++)
          for (var c = 0; c < n; c++)
            if (!isEnd(r, c) && !grid[r][c].isObstacle && !onRoute.contains(Point(r, c))) Point(r, c)
      ]..shuffle(rand);
      for (final p in spare.take(wanted - placed)) {
        grid[p.x][p.y].isObstacle = true;
      }
      break;
    }
    scored.sort((a, b) => a.$1 != b.$1 ? b.$1.compareTo(a.$1) : a.$2.compareTo(b.$2));
    final pick = scored[rand.nextInt(min(3, scored.length))].$3;
    grid[pick.x][pick.y].isObstacle = true;
  }

  // 2. One-way cells: a gate on the route, decoys elsewhere, then wall off the detours.
  if (oneWayPaths) {
    final route = _route(n, (r, c) => grid[r][c].isObstacle, rand)!;
    final gateIndex = route.length ~/ 2;
    final gate = route[gateIndex], before = route[gateIndex - 1];
    grid[gate.x][gate.y]
      ..isOneWay = true
      ..oneWayDirection = Offset((gate.x - before.x).toDouble(), (gate.y - before.y).toDouble());

    final onRoute = route.toSet();
    final dirs = [const Offset(1, 0), const Offset(-1, 0), const Offset(0, 1), const Offset(0, -1)];
    for (var i = 0, made = 1; i < 60 && made < max(1, n ~/ 3); i++) {
      final r = rand.nextInt(n), c = rand.nextInt(n);
      final cell = grid[r][c];
      if (isEnd(r, c) || cell.isObstacle || cell.isOneWay || onRoute.contains(Point(r, c))) continue;
      cell
        ..isOneWay = true
        ..oneWayDirection = dirs[rand.nextInt(4)];
      made++;
    }

    while (true) {
      final detour = _route(n, (r, c) => grid[r][c].isObstacle || grid[r][c].isOneWay, rand);
      if (detour == null) break;
      final free = detour.where((p) => !isEnd(p.x, p.y) && !onRoute.contains(p)).toList();
      if (free.isEmpty) break; // not expected: the route has no shortcuts
      final p = free[rand.nextInt(free.length)];
      grid[p.x][p.y].isObstacle = true;
    }
  }

  // 3. Power-ups. On a one-way board a power-up that could tear down the wall is skipped.
  if (powerUps) {
    for (var i = 0; i < max(1, n ~/ 4); i++) {
      final r = rand.nextInt(n), c = rand.nextInt(n);
      final cell = grid[r][c];
      if (isEnd(r, c) || cell.isObstacle || cell.isOneWay) continue;
      cell.isPowerUp = true;
      if (oneWayPaths && !_oneWayIsRequired(grid, rand)) cell.isPowerUp = false;
    }
  }
}

class _PathWeaverGameScreenState extends State<PathWeaverGameScreen> with ConfigHighScoreMixin<PathWeaverGameScreen> {
  @override
  String get highScoreGameId => 'pathweaver';
  @override
  bool get highScoreLowerIsBetter => true;
  @override
  Map<String, dynamic> get highScoreConfig => {
        'gridSize': widget.gridSize.toDouble(),
        'obstacleDensity': widget.obstacleDensity,
        'oneWayPaths': widget.oneWayPaths,
        'powerUps': widget.powerUps,
      };
  late List<List<PathCell>> _grid;
  late Point<int> _start;
  late Point<int> _end;
  List<Point<int>> _path = [];
  List<Point<int>> _guidePath = [];
  bool _gameWon = false;
  bool _gameOver = false;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    if (widget.testMode && widget.testPath != null) {
      // Deterministic test path and grid
      _generateGrid();
      _path = List.from(widget.testPath!);
      _gameWon = true;
      _gameOver = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
    } else if (widget.testMode && widget.testGrid != null) {
      // Deterministic custom grid
      _grid = List.generate(
        widget.gridSize,
        (r) => List.generate(
          widget.gridSize,
          (c) => widget.testGrid![r][c].clone(),
        ),
      );
      // Find start and end cells
      _start = const Point(0, 0);
      _end = Point(widget.gridSize - 1, widget.gridSize - 1);
      for (int r = 0; r < widget.gridSize; r++) {
        for (int c = 0; c < widget.gridSize; c++) {
          if (_grid[r][c].isStart) {
            _start = Point(r, c);
          }
          if (_grid[r][c].isEnd) {
            _end = Point(r, c);
          }
        }
      }
      _path = [_start];
      _grid[_start.x][_start.y].isPath = true;
      _gameWon = false;
      _gameOver = false;
      _guidePath = _findGuidePath();
      WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
    } else if (widget.testMode) {
      // Deterministic grid, no async/high score
      _generateGrid();
      _path = [_start];
      _gameWon = false;
      _gameOver = false;
      _guidePath = _findGuidePath();
      WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
    } else {
      _generateGridEnsuringPath();
      _loadHighScore();
    }
  }

  Future<void> _loadHighScore() async {
    final stored = await loadBestScore();
    if (mounted) {
      setState(() {
        bestScore = stored;
      });
    }
  }

  Future<void> _updateHighScoreIfNeeded() async {
    if (!_gameWon) return;
    await submitScore(_path.length - 1);
  }

  void _generateGridEnsuringPath() {
    // Try generating until a valid path exists
    int attempts = 0;
    do {
      _generateGrid();
      _guidePath = _findGuidePath();
      attempts++;
    } while (_guidePath.isEmpty && attempts < 100);
  }

  // BFS to find a valid path from start to end
  List<Point<int>> _findGuidePath() {
    int n = widget.gridSize;
    Queue<List<Point<int>>> queue = Queue();
    Set<Point<int>> visited = {};
    queue.add([_start]);
    while (queue.isNotEmpty) {
      final path = queue.removeFirst();
      final last = path.last;
      if (last == _end) return path;
      for (var d in [const Point(1,0), const Point(-1,0), const Point(0,1), const Point(0,-1)]) {
        int nr = last.x + d.x;
        int nc = last.y + d.y;
        if (nr >= 0 && nr < n && nc >= 0 && nc < n) {
          final cell = _grid[nr][nc];
          final next = Point(nr, nc);
          if (cell.isObstacle || path.contains(next)) continue;
          // One-way logic
          if (cell.isOneWay && cell.oneWayDirection != null) {
            int dr = nr - last.x;
            int dc = nc - last.y;
            if (Offset(dr.toDouble(), dc.toDouble()) != cell.oneWayDirection) continue;
          }
          if (!visited.contains(next)) {
            visited.add(next);
            queue.add([...path, next]);
          }
        }
      }
    }
    return [];
  }

  void _generateGrid() {
    final rand = Random();
    int n = widget.gridSize;
    _grid = List.generate(n, (_) => List.generate(n, (_) => PathCell()));
    // Place start and end
    _start = const Point(0, 0);
    _end = Point(n - 1, n - 1);
    _grid[_start.x][_start.y].isStart = true;
    _grid[_end.x][_end.y].isEnd = true;
    layoutPathWeaverGrid(
      _grid,
      obstacleDensity: widget.obstacleDensity,
      oneWayPaths: widget.oneWayPaths,
      powerUps: widget.powerUps,
      rand: rand,
    );
    // Reset path
    _path = [_start];
    _grid[_start.x][_start.y].isPath = true;
    _gameWon = false;
    _gameOver = false;
  }

  // Drag handling
  void _handleDragStart(int r, int c) {
    if (_gameWon || _gameOver) return;
    if (_path.length == 1 && r == _start.x && c == _start.y) {
      setState(() {
        _dragging = true;
      });
    }
  }

  void _handleDragUpdate(int r, int c) {
    if (!_dragging || _gameWon || _gameOver) return;
    final last = _path.last;
    if ((last.x - r).abs() + (last.y - c).abs() != 1) return;
    final cell = _grid[r][c];
    if (cell.isObstacle || cell.isPath) return;
    // One-way logic
    if (cell.isOneWay && cell.oneWayDirection != null) {
      int dr = r - last.x;
      int dc = c - last.y;
      if (Offset(dr.toDouble(), dc.toDouble()) != cell.oneWayDirection) return;
    }
    setState(() {
      _path.add(Point(r, c));
      cell.isPath = true;
      // Power-up: clear obstacles in a 3x3 area
      if (cell.isPowerUp) {
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            int nr = r + dr;
            int nc = c + dc;
            if (nr >= 0 && nr < widget.gridSize && nc >= 0 && nc < widget.gridSize) {
              _grid[nr][nc].isObstacle = false;
            }
          }
        }
        cell.isPowerUp = false;
      }
      if (cell.isEnd) {
        _gameWon = true;
        _dragging = false;
        _updateHighScoreIfNeeded();
      }
      if (!_hasValidMoves()) {
        _gameOver = true;
        _dragging = false;
      }
    });
  }

  void _handleDragEnd() {
    setState(() {
      _dragging = false;
    });
  }

  void _handleCellTap(int r, int c) {
    if (_gameWon || _gameOver) return;
    final last = _path.last;
    if ((last.x - r).abs() + (last.y - c).abs() != 1) return;
    final cell = _grid[r][c];
    if (cell.isObstacle || cell.isPath) return;
    // One-way logic
    if (cell.isOneWay && cell.oneWayDirection != null) {
      int dr = r - last.x;
      int dc = c - last.y;
      if (Offset(dr.toDouble(), dc.toDouble()) != cell.oneWayDirection) return;
    }
    setState(() {
      _path.add(Point(r, c));
      cell.isPath = true;
      // Power-up: clear obstacles in a 3x3 area
      if (cell.isPowerUp) {
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            int nr = r + dr;
            int nc = c + dc;
            if (nr >= 0 && nr < widget.gridSize && nc >= 0 && nc < widget.gridSize) {
              _grid[nr][nc].isObstacle = false;
            }
          }
        }
        cell.isPowerUp = false;
      }
      if (cell.isEnd) {
        _gameWon = true;
        _dragging = false;
        _updateHighScoreIfNeeded();
      }
      if (!_hasValidMoves()) {
        _gameOver = true;
        _dragging = false;
      }
    });
  }

  void _undoLastMove() {
    if (_path.length <= 1 || _gameWon || _gameOver) return;
    setState(() {
      final last = _path.removeLast();
      _grid[last.x][last.y].isPath = false;
      _gameWon = false;
      _gameOver = false;
      _dragging = false;
    });
  }

  bool _hasValidMoves() {
    final last = _path.last;
    for (var d in [const Point(1,0), const Point(-1,0), const Point(0,1), const Point(0,-1)]) {
      int nr = last.x + d.x;
      int nc = last.y + d.y;
      if (nr >= 0 && nr < widget.gridSize && nc >= 0 && nc < widget.gridSize) {
        final cell = _grid[nr][nc];
        if (!cell.isObstacle && !cell.isPath) {
          if (cell.isOneWay && cell.oneWayDirection != null) {
            int dr = nr - last.x;
            int dc = nc - last.y;
            if (Offset(dr.toDouble(), dc.toDouble()) != cell.oneWayDirection) continue;
          }
          return true;
        }
      }
    }
    return false;
  }

  void _showHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.teal),
            SizedBox(width: 8),
            Expanded(child: Text('How to Play Path Weaver')),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Goal:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Draw a route from the blue start (top-left) to the red end (bottom-right) in as few moves as you can.'),
              SizedBox(height: 12),
              Text('Rules:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '1. Drag or tap to step one square up, down, left or right. You cannot cross obstacles or your own path.\n'
                '2. Obstacle Density: more obstacles make the route twist. A route always exists.\n'
                '3. One-Way Paths: a purple arrow square can only be entered by moving in the arrow\'s direction. When this is on, at least one of them is on the only way to the end, so you must use one. Others may be decoys.\n'
                '4. Power-ups clear the obstacles around them when you step on one. On a One-Way board they are never placed where they could open a way round the one-way square.\n'
                '5. Undo removes your last step. If you get stuck with no move left, the game is over.',
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it'))],
      ),
    );
  }

  void _resetGame() {
    setState(() {
      _generateGridEnsuringPath();
    });
  }

  @override
  Widget build(BuildContext context) {
    double tileSize = MediaQuery.of(context).size.width / (widget.gridSize + 2);
    final moves = _path.isNotEmpty ? _path.length - 1 : 0;

    return BaseGameScreen(
      title: 'Path Weaver',
      gameId: 'pathweaver',
      gameConfig: {
        'gridSize': widget.gridSize,
        'obstacleDensity': widget.obstacleDensity,
        'oneWayPaths': widget.oneWayPaths,
        'powerUps': widget.powerUps,
      },
      highScoreLabel: 'Best',
      highScoreValue: bestScore != null ? '$bestScore moves' : '-',
      currentScoreLabel: 'Moves',
      currentScoreValue: '$moves',
      statusText: 'Start is Blue, End is Red. Trace a path!',
      isGameWon: _gameWon,
      isGameOver: _gameOver && !_gameWon,
      victoryMessage: 'You Win!',
      gameOverMessage: 'No more moves! Game Over.',
      onReset: _resetGame,
      onUndo: _undoLastMove,
      onHelp: _showHelpDialog,
      isGameInProgress: _path.length > 1,
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: Listener(
            onPointerUp: (_) => _handleDragEnd(),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  // Guide path lines
                  CustomPaint(
                    size: Size.infinite,
                    painter: _GuidePathPainter(_guidePath, tileSize),
                  ),
                  Builder(
                    builder: (gridContext) {
                      return GestureDetector(
                        // onPanDown, not onPanStart: PanStart reports the point after
                        // the touch slop, which on a small scaled cell can already be
                        // the next cell, so the drag would never begin on the start.
                        onPanDown: (details) {
                          final RenderBox? rBox = gridContext.findRenderObject() as RenderBox?;
                          if (rBox == null) return;
                          final local = rBox.globalToLocal(details.globalPosition);
                          final cellW = rBox.size.width / widget.gridSize;
                          final cellH = rBox.size.height / widget.gridSize;
                          final c = (local.dx / cellW).floor();
                          final r = (local.dy / cellH).floor();
                          if (r >= 0 && r < widget.gridSize && c >= 0 && c < widget.gridSize) {
                            _handleDragStart(r, c);
                          }
                        },
                        onPanUpdate: (details) {
                          final RenderBox? rBox = gridContext.findRenderObject() as RenderBox?;
                          if (rBox == null) return;
                          final local = rBox.globalToLocal(details.globalPosition);
                          final cellW = rBox.size.width / widget.gridSize;
                          final cellH = rBox.size.height / widget.gridSize;
                          final c = (local.dx / cellW).floor();
                          final r = (local.dy / cellH).floor();
                          if (r >= 0 && r < widget.gridSize && c >= 0 && c < widget.gridSize) {
                            _handleDragUpdate(r, c);
                          }
                        },
                        onPanEnd: (_) => _handleDragEnd(),
                        onTapDown: (details) {
                          final RenderBox? rBox = gridContext.findRenderObject() as RenderBox?;
                          if (rBox == null) return;
                          final local = rBox.globalToLocal(details.globalPosition);
                          final cellW = rBox.size.width / widget.gridSize;
                          final cellH = rBox.size.height / widget.gridSize;
                          final c = (local.dx / cellW).floor();
                          final r = (local.dy / cellH).floor();
                          if (r >= 0 && r < widget.gridSize && c >= 0 && c < widget.gridSize) {
                            _handleCellTap(r, c);
                          }
                        },
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: widget.gridSize,
                          ),
                          itemCount: widget.gridSize * widget.gridSize,
                          itemBuilder: (context, idx) {
                            int r = idx ~/ widget.gridSize;
                            int c = idx % widget.gridSize;
                            final cell = _grid[r][c];
                            Color color = Colors.white;
                            if (cell.isObstacle) {
                              color = Colors.black;
                            } else if (cell.isStart) {
                              color = Colors.blue;
                            } else if (cell.isEnd) {
                              color = Colors.red;
                            } else if (cell.isPath) {
                              color = Colors.greenAccent;
                            } else if (cell.isPowerUp) {
                              color = Colors.amber;
                            } else if (cell.isOneWay) {
                              color = Colors.purple.shade200;
                            }
                            final what = cell.isStart
                                ? 'start'
                                : cell.isEnd
                                    ? 'end'
                                    : cell.isObstacle
                                        ? 'blocked'
                                        : cell.isPath
                                            ? 'on your path'
                                            : cell.isPowerUp
                                                ? 'power-up'
                                                : cell.isOneWay
                                                    ? 'one-way'
                                                    : 'open';
                            return Semantics(
                              label: 'Row ${r + 1}, column ${c + 1}, $what',
                              button: !cell.isObstacle && !cell.isPath,
                              onTap: () => _handleCellTap(r, c),
                              excludeSemantics: true,
                              child: Container(
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: color,
                                border: Border.all(color: Colors.grey.shade700),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: cell.isOneWay && cell.oneWayDirection != null
                                  ? Center(child: Icon(_arrowIcon(cell.oneWayDirection!), size: 18, color: Colors.purple.shade700))
                                  : null,
                            ),
                            );
                          },
                        ),
                      );
                    }
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _arrowIcon(Offset dir) {
    if (dir == const Offset(1,0)) return Icons.arrow_downward;
    if (dir == const Offset(-1,0)) return Icons.arrow_upward;
    if (dir == const Offset(0,1)) return Icons.arrow_forward;
    if (dir == const Offset(0,-1)) return Icons.arrow_back;
    return Icons.help;
  }
}

class _GuidePathPainter extends CustomPainter {
  final List<Point<int>> path;
  final double tileSize;
  _GuidePathPainter(this.path, this.tileSize);
  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;
    final paint = Paint()
      ..color = Colors.lightBlueAccent.withValues(alpha: 0.4)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < path.length - 1; i++) {
      final p1 = path[i];
      final p2 = path[i + 1];
      final o1 = Offset(p1.y * tileSize + tileSize / 2, p1.x * tileSize + tileSize / 2);
      final o2 = Offset(p2.y * tileSize + tileSize / 2, p2.x * tileSize + tileSize / 2);
      canvas.drawLine(o1, o2, paint);
    }
  }
  @override
  bool shouldRepaint(covariant _GuidePathPainter oldDelegate) =>
      oldDelegate.tileSize != tileSize || !listEquals(oldDelegate.path, path);
} 