import 'package:flutter/material.dart';
import 'dart:math';
import '../services/app_persistence_service.dart';
import 'mixins/config_high_score_mixin.dart';
import 'base_game_screen.dart';

/// Gravity Shift Game Screen
///
/// A grid‑based puzzle where the board "falls" in a chosen gravity direction.
/// Tiles slide until they hit the board edge or another tile. The player must
/// rearrange the board to match a target pattern. Supports both Zen (unlimited)
/// and Challenge (move‑limit) modes.
class GravityShiftGameScreen extends StatefulWidget {
  final int gridSize;
  final String difficulty; // easy, medium, hard
  final String moveMode; // zen, challenge
  final bool testMode;
  final List<List<Color>>? testGrid;
  final List<List<Color>>? testTarget;
  final int? testMaxMoves;

  const GravityShiftGameScreen({
    super.key,
    required this.gridSize,
    required this.difficulty,
    required this.moveMode,
    this.testMode = false,
    this.testGrid,
    this.testTarget,
    this.testMaxMoves,
  });

  @override
  State<GravityShiftGameScreen> createState() => _GravityShiftGameScreenState();
}

class _GravityShiftGameScreenState extends State<GravityShiftGameScreen> with ConfigHighScoreMixin<GravityShiftGameScreen> {
  @override
  String get highScoreGameId => 'gravity_shift';
  @override
  bool get highScoreLowerIsBetter => true;
  @override
  Map<String, dynamic> get highScoreConfig => {
        'gridSize': widget.gridSize.toDouble(),
        'difficulty': widget.difficulty,
        'moveMode': widget.moveMode,
      };
  final Random _rand = Random();

  late List<List<Color>> _grid;
  late List<List<Color>> _targetPattern;
  int _moves = 0;
  int _moveLimit = 0;
  bool _isGameOver = false;
  bool _isGameWon = false;

  final List<List<List<Color>>> _history = [];

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  void _initializeGame() {
    _history.clear();
    if (widget.testMode && widget.testGrid != null && widget.testTarget != null) {
      _grid = List.generate(
        widget.gridSize,
        (r) => List<Color>.from(widget.testGrid![r]),
      );
      _targetPattern = List.generate(
        widget.gridSize,
        (r) => List<Color>.from(widget.testTarget![r]),
      );
      _moves = 0;
      _isGameOver = false;
      _isGameWon = false;
      _moveLimit = widget.testMaxMoves ?? 10;
      _loadPersistenceData();
    } else {
      // Placeholder grids to avoid late init errors while async generation runs.
      _grid = List.generate(
        widget.gridSize,
        (_) => List.generate(widget.gridSize, (_) => Colors.grey),
      );
      _targetPattern = List.generate(
        widget.gridSize,
        (_) => List.generate(widget.gridSize, (_) => Colors.grey),
      );
      _moves = 0;
      _isGameOver = false;
      _isGameWon = false;
      _generateAndLoad();
    }
  }

  Future<void> _generateAndLoad() async {
    // Acquire a palette (persisted per game if possible).
    final colors = await AppPersistenceService.getPaletteForGame(colorCount: 4);
    final palette = colors.isNotEmpty
        ? colors
        : [Colors.indigo, Colors.blue, Colors.teal, Colors.purple];

    // Determine scramble steps based on difficulty.
    int scrambleSteps;
    switch (widget.difficulty) {
      case 'easy':
        scrambleSteps = 3;
        break;
      case 'hard':
        scrambleSteps = 8;
        break;
      case 'medium':
      default:
        scrambleSteps = 5;
    }

    // Build a half-empty initial board and derive the solvable target by
    // applying random gravity moves forward (gravity is not invertible, so
    // target = result of k shifts from the start board guarantees solvability).
    final totalCells = widget.gridSize * widget.gridSize;
    final filledCount = totalCells ~/ 2;
    late List<List<Color>> active;
    late List<List<Color>> target;

    for (int attempt = 0; attempt < 30; attempt++) {
      final flat = List<Color>.generate(
        totalCells,
        (i) => i < filledCount
            ? palette[i % palette.length]
            : Colors.transparent,
      )..shuffle(_rand);

      final start = List.generate(
        widget.gridSize,
        (r) => List<Color>.generate(
          widget.gridSize,
          (c) => flat[r * widget.gridSize + c],
        ),
      );

      var cur = List.generate(widget.gridSize, (r) => List<Color>.from(start[r]));
      int lastAxis = -1;
      int applied = 0;
      int guard = 0;
      while (applied < scrambleSteps && guard < 40) {
        guard++;
        final dir = _rand.nextInt(4);
        final axis = dir ~/ 2; // 0: vertical, 1: horizontal
        if (applied > 0 && axis == lastAxis && guard < 25) continue;
        final next = _applyGravity(cur, dir);
        if (_areGridsEqual(next, cur)) continue;
        cur = next;
        lastAxis = axis;
        applied++;
      }

      active = start;
      target = cur;
      if (!_areGridsEqual(active, target) && !_isOneShiftFromTarget(active, target)) {
        break;
      }
    }

    // Load persisted high score.
    final stored = await loadBestScore();

    if (mounted) {
      setState(() {
        _grid = active;
        _targetPattern = target;
        bestScore = stored;
        // Move limit: base on difficulty + 3 (similar to other games).
        _moveLimit = scrambleSteps + 3;
      });
    }
  }

  Future<void> _loadPersistenceData() async {
    final stored = await loadBestScore();
    if (mounted) {
      setState(() {
        bestScore = stored;
      });
    }
  }

  bool _isOneShiftFromTarget(List<List<Color>> grid, List<List<Color>> target) {
    for (int d = 0; d < 4; d++) {
      if (_areGridsEqual(_applyGravity(grid, d), target)) return true;
    }
    return false;
  }

  /// Direction indices: 0 = up, 1 = down, 2 = left, 3 = right.
  List<List<Color>> _applyGravity(List<List<Color>> grid, int direction) {
    final size = widget.gridSize;
    // Work on a copy.
    final result = List.generate(size, (r) => List<Color>.from(grid[r]));
    if (direction == 0) {
      // Up: for each column, compress upwards.
      for (int c = 0; c < size; c++) {
        int write = 0;
        for (int r = 0; r < size; r++) {
          final color = grid[r][c];
          if (color != Colors.transparent) {
            result[write][c] = color;
            if (write != r) result[r][c] = Colors.transparent;
            write++;
          }
        }
        // Fill rest with transparent.
        for (int r = write; r < size; r++) {
          result[r][c] = Colors.transparent;
        }
      }
    } else if (direction == 1) {
      // Down.
      for (int c = 0; c < size; c++) {
        int write = size - 1;
        for (int r = size - 1; r >= 0; r--) {
          final color = grid[r][c];
          if (color != Colors.transparent) {
            result[write][c] = color;
            if (write != r) result[r][c] = Colors.transparent;
            write--;
          }
        }
        for (int r = write; r >= 0; r--) {
          result[r][c] = Colors.transparent;
        }
      }
    } else if (direction == 2) {
      // Left.
      for (int r = 0; r < size; r++) {
        int write = 0;
        for (int c = 0; c < size; c++) {
          final color = grid[r][c];
          if (color != Colors.transparent) {
            result[r][write] = color;
            if (write != c) result[r][c] = Colors.transparent;
            write++;
          }
        }
        for (int c = write; c < size; c++) {
          result[r][c] = Colors.transparent;
        }
      }
    } else if (direction == 3) {
      // Right.
      for (int r = 0; r < size; r++) {
        int write = size - 1;
        for (int c = size - 1; c >= 0; c--) {
          final color = grid[r][c];
          if (color != Colors.transparent) {
            result[r][write] = color;
            if (write != c) result[r][c] = Colors.transparent;
            write--;
          }
        }
        for (int c = write; c >= 0; c--) {
          result[r][c] = Colors.transparent;
        }
      }
    }
    return result;
  }

  void _applyGravityDirection(int dir) {
    if (_isGameOver || _isGameWon) return;
    // Save history for undo.
    _history.add(List.generate(widget.gridSize, (r) => List<Color>.from(_grid[r])));
    final next = _applyGravity(_grid, dir);
    setState(() {
      _grid = next;
      _moves++;
      _checkIfSolved();
    });
    if (_isGameWon) {
      _saveHighScore();
    } else if (widget.moveMode == 'challenge' && _moves >= _moveLimit) {
      setState(() => _isGameOver = true);
    }
  }

  void _undoMove() {
    if (_history.isEmpty || _isGameOver || _isGameWon) return;
    setState(() {
      _grid = _history.removeLast();
      _moves--;
    });
  }

  void _checkIfSolved() {
    if (_areGridsEqual(_grid, _targetPattern)) {
      _isGameWon = true;
    }
  }

  bool _areGridsEqual(List<List<Color>> g1, List<List<Color>> g2) {
    if (g1.length != g2.length) return false;
    for (int r = 0; r < g1.length; r++) {
      if (g1[r].length != g2[r].length) return false;
      for (int c = 0; c < g1[r].length; c++) {
        if (g1[r][c] != g2[r][c]) return false;
      }
    }
    return true;
  }

  Future<void> _saveHighScore() async {
    if (widget.testMode) return;
    await submitScore(_moves);
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text('How to Play Gravity Shift'),
          ],
        ),
        content: const Scrollbar(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Goal:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Rearrange the colored tiles to exactly match the target pattern.'),
                SizedBox(height: 12),
                Text('Rules:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('1. Tap a direction button (↑ ↓ ← →) to apply gravity in that direction.'),
                Text('2. Tiles slide until they hit another tile or the board edge.'),
                Text('3. In Challenge mode you have a limited number of moves.'),
                Text('4. Use the Undo button to revert your last move.'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<List<Color>> grid, {required double tileSize}) {
    return Container(
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.gridSize, (r) {
          final rowChildren = <Widget>[];
          for (int c = 0; c < widget.gridSize; c++) {
            rowChildren.add(Container(
              width: tileSize,
              height: tileSize,
              margin: const EdgeInsets.all(1.0),
              decoration: BoxDecoration(
                color: grid[r][c],
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: Colors.black12, width: 0.5),
              ),
            ));
          }
          return Row(mainAxisSize: MainAxisSize.min, children: rowChildren);
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseGameScreen(
      title: 'Gravity Shift',
      gameId: 'gravity_shift',
      gameConfig: {
        'gridSize': widget.gridSize,
        'difficulty': widget.difficulty,
        'moveMode': widget.moveMode,
      },
      highScoreLabel: 'Best',
      highScoreValue: bestScore != null ? '$bestScore moves' : '--',
      currentScoreLabel: 'Moves',
      currentScoreValue: '$_moves${widget.moveMode == 'challenge' ? ' / $_moveLimit' : ''}',
      statusText: _isGameWon ? 'Puzzle solved!' : 'Tap a direction to shift tiles.',
      isGameWon: _isGameWon,
      isGameOver: _isGameOver && !_isGameWon,
      victoryMessage: 'Solved in $_moves moves!',
      gameOverMessage: 'Move limit exceeded! Try again.',
      onReset: _initializeGame,
      onUndo: _history.isNotEmpty ? _undoMove : null,
      isGameInProgress: _moves > 0 && !_isGameOver,
      onHelp: _showHelpDialog,
      topHudExtra: Column(
        children: [
          const Text('Target Pattern:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          _buildGrid(_targetPattern, tileSize: (110.0 / widget.gridSize).clamp(9.0, 16.0)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          // Board padding 8 + 2 per cell margin; one row of arrows needs ~56.
          const controlsHeight = 56.0;
          final n = widget.gridSize;
          final byHeight = (box.maxHeight - controlsHeight - 8) / n - 2;
          final byWidth = (box.maxWidth - 8) / n - 2;
          final tile = min(min(byHeight, byWidth), (260.0 / n).clamp(24.0, 48.0)).clamp(8.0, 48.0);
          final canMove = !(_isGameOver || _isGameWon);
          Widget arrow(IconData icon, String tip, int dir) => IconButton.filledTonal(
                icon: Icon(icon),
                tooltip: tip,
                onPressed: canMove ? () => _applyGravityDirection(dir) : null,
                iconSize: 28,
              );
          return Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildGrid(_grid, tileSize: tile),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      arrow(Icons.arrow_back, 'Gravity left', 2),
                      const SizedBox(width: 12),
                      arrow(Icons.arrow_upward, 'Gravity up', 0),
                      const SizedBox(width: 12),
                      arrow(Icons.arrow_downward, 'Gravity down', 1),
                      const SizedBox(width: 12),
                      arrow(Icons.arrow_forward, 'Gravity right', 3),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
