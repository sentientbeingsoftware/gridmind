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
    // Place obstacles
    int numObstacles = min((n * n * widget.obstacleDensity).round(), n * n - 2);
    int placed = 0;
    int obstacleAttempts = 0;
    while (placed < numObstacles && obstacleAttempts < 1000) {
      obstacleAttempts++;
      int r = rand.nextInt(n);
      int c = rand.nextInt(n);
      if (!_grid[r][c].isStart && !_grid[r][c].isEnd && !_grid[r][c].isObstacle) {
        _grid[r][c].isObstacle = true;
        placed++;
      }
    }
    // Place one-way paths
    if (widget.oneWayPaths) {
      int numOneWay = max(1, n ~/ 3);
      for (int i = 0; i < numOneWay; i++) {
        int r = rand.nextInt(n);
        int c = rand.nextInt(n);
        if (!_grid[r][c].isStart && !_grid[r][c].isEnd && !_grid[r][c].isObstacle) {
          _grid[r][c].isOneWay = true;
          // Random direction: up, down, left, right
          List<Offset> dirs = [const Offset(1,0), const Offset(-1,0), const Offset(0,1), const Offset(0,-1)];
          _grid[r][c].oneWayDirection = dirs[rand.nextInt(4)];
        }
      }
    }
    // Place power-ups
    if (widget.powerUps) {
      int numPowerUps = max(1, n ~/ 4);
      for (int i = 0; i < numPowerUps; i++) {
        int r = rand.nextInt(n);
        int c = rand.nextInt(n);
        if (!_grid[r][c].isStart && !_grid[r][c].isEnd && !_grid[r][c].isObstacle && !_grid[r][c].isOneWay) {
          _grid[r][c].isPowerUp = true;
        }
      }
    }
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
                        onPanStart: (details) {
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
                            return Container(
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: color,
                                border: Border.all(color: Colors.grey.shade700),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: cell.isOneWay && cell.oneWayDirection != null
                                  ? Center(child: Icon(_arrowIcon(cell.oneWayDirection!), size: 18, color: Colors.purple.shade700))
                                  : null,
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