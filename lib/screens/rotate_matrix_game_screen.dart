import 'package:flutter/material.dart';
import 'dart:math';
import '../services/app_persistence_service.dart';
import 'mixins/config_high_score_mixin.dart';
import 'base_game_screen.dart';

class RotateMatrixGameScreen extends StatefulWidget {
  final int gridSize;
  final String difficulty; // 'easy', 'medium', 'hard'
  final String moveMode; // 'zen', 'challenge'
  final bool testMode;
  final List<List<Color>>? testGrid;
  final List<List<Color>>? testTarget;
  final int? testMaxMoves;

  const RotateMatrixGameScreen({
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
  State<RotateMatrixGameScreen> createState() => _RotateMatrixGameScreenState();
}

class _RotateMatrixGameScreenState extends State<RotateMatrixGameScreen> with ConfigHighScoreMixin<RotateMatrixGameScreen> {
  @override
  String get highScoreGameId => 'rotate_matrix';
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

  int _selectedQuadrant = 0; // 0: Top-Left, 1: Top-Right, 2: Bottom-Left, 3: Bottom-Right

  final List<List<List<Color>>> _history = [];
  List<Color> _palette = [];

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  void _initializeGame() {
    _history.clear();
    _selectedQuadrant = 0;

    // Determine move limit
    if (widget.testMode) {
      _moveLimit = widget.testMaxMoves ?? 10;
    } else {
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
          break;
      }
      _moveLimit = scrambleSteps + 3;
    }

    if (widget.testMode && widget.testGrid != null && widget.testTarget != null) {
      _grid = List.generate(
        widget.gridSize,
        (r) => List<Color>.from(widget.testGrid![r]),
      );
      _targetPattern = List.generate(
        widget.gridSize,
        (r) => List<Color>.from(widget.testTarget![r]),
      );
      _palette = [Colors.red, Colors.blue, Colors.green, Colors.yellow];
      _moves = 0;
      _isGameOver = false;
      _isGameWon = false;
      _loadPersistenceData(); // Load high scores if any
    } else {
      // Create default mock grids to prevent LateInitializationError
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

      // Trigger full async generation and DB loading
      _generateAndLoad();
    }
  }

  Future<void> _generateAndLoad() async {
    final colors = await AppPersistenceService.getPaletteForGame(colorCount: 4);
    final palette = colors.isNotEmpty
        ? colors
        : [Colors.indigo, Colors.blue, Colors.teal, Colors.purple];

    // Generate a varied multi-colour target pattern so quadrant rotations
    // always change the board (solid-colour quadrants were invariant under rotation).
    List<List<Color>> target;
    do {
      target = List.generate(widget.gridSize, (r) {
        return List.generate(widget.gridSize, (c) {
          return palette[_rand.nextInt(palette.length)];
        });
      });
    } while (_hasRotationallySymmetricQuadrant(target));

    // Active grid starts as a copy of the target pattern
    var active = List.generate(widget.gridSize, (r) {
      return List<Color>.from(target[r]);
    });

    // Scramble the active board by performing random valid rotations
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
        break;
    }

    for (int attempt = 0; attempt < 20; attempt++) {
      var candidate = List.generate(
        widget.gridSize,
        (r) => List<Color>.from(target[r]),
      );
      int stepsApplied = 0;
      int lastQuad = -1;
      bool lastCw = false;
      while (stepsApplied < scrambleSteps) {
        final quad = _rand.nextInt(4);
        final clockwise = _rand.nextBool();
        if (quad == lastQuad && clockwise != lastCw) continue;
        candidate = _performScrambleRotate(candidate, quad, clockwise);
        lastQuad = quad;
        lastCw = clockwise;
        stepsApplied++;
      }
      active = candidate;
      if (!_areGridsEqual(active, target) && !_isOneMoveFromTarget(active, target)) {
        break;
      }
    }
    if (_areGridsEqual(active, target) || _isOneMoveFromTarget(active, target)) {
      active = _performScrambleRotate(target, 0, true);
      active = _performScrambleRotate(active, 3, true);
    }

    final stored = await loadBestScore();

    if (mounted) {
      setState(() {
        _grid = active;
        _targetPattern = target;
        _palette = palette;
        bestScore = stored;
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

  bool _hasRotationallySymmetricQuadrant(List<List<Color>> grid) {
    for (int q = 0; q < 4; q++) {
      final rotated = _performScrambleRotate(grid, q, true);
      if (_areGridsEqual(grid, rotated)) return true;
    }
    return false;
  }

  bool _isOneMoveFromTarget(List<List<Color>> grid, List<List<Color>> target) {
    for (int q = 0; q < 4; q++) {
      for (final cw in [true, false]) {
        if (_areGridsEqual(_performScrambleRotate(grid, q, cw), target)) {
          return true;
        }
      }
    }
    return false;
  }

  List<List<Color>> _performScrambleRotate(List<List<Color>> currentGrid, int quadrantIndex, bool clockwise) {
    final Q = widget.gridSize ~/ 2;
    final rStart = (quadrantIndex ~/ 2) * Q;
    final cStart = (quadrantIndex % 2) * Q;

    final result = List.generate(widget.gridSize, (r) => List<Color>.from(currentGrid[r]));

    final oldSub = List.generate(Q, (i) => List<Color>.generate(Q, (j) => currentGrid[rStart + i][cStart + j]));
    final newSub = List.generate(Q, (i) => List<Color>.generate(Q, (j) => Colors.transparent));

    for (int i = 0; i < Q; i++) {
      for (int j = 0; j < Q; j++) {
        if (clockwise) {
          newSub[i][j] = oldSub[Q - 1 - j][i];
        } else {
          newSub[i][j] = oldSub[j][Q - 1 - i];
        }
      }
    }

    for (int i = 0; i < Q; i++) {
      for (int j = 0; j < Q; j++) {
        result[rStart + i][cStart + j] = newSub[i][j];
      }
    }

    return result;
  }

  void _rotateQuadrant(int quadrantIndex, bool clockwise) {
    if (_isGameOver || _isGameWon) return;

    // Save historical state for Undo
    _history.add(List.generate(widget.gridSize, (r) => List<Color>.from(_grid[r])));

    final nextGrid = _performScrambleRotate(_grid, quadrantIndex, clockwise);

    setState(() {
      _grid = nextGrid;
      _moves++;
      _checkIfSolved();
    });

    if (_isGameWon) {
      _saveHighScore();
    } else if (widget.moveMode == 'challenge' && _moves >= _moveLimit) {
      setState(() {
        _isGameOver = true;
      });
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

  String _getQuadrantLabel(int index) {
    switch (index) {
      case 0:
        return 'Selected: Top-Left Quadrant';
      case 1:
        return 'Selected: Top-Right Quadrant';
      case 2:
        return 'Selected: Bottom-Left Quadrant';
      case 3:
        return 'Selected: Bottom-Right Quadrant';
      default:
        return '';
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text('How to Play Rotate Matrix'),
          ],
        ),
        content: const Scrollbar(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Goal:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Rearrange the colored blocks to match the target pattern.',
                ),
                SizedBox(height: 12),
                Text(
                  'Rules:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '1. The grid is split into four quadrant matrices (Top-Left, Top-Right, Bottom-Left, Bottom-Right).\n'
                  '2. Tap any cell on the grid to select its quadrant.\n'
                  '3. Tap the Rotate Left (↺) or Rotate Right (↻) buttons below to spin the active quadrant 90 degrees.\n'
                  '4. Recreate the solid color layout shown in the target pattern thumbnail.\n'
                  '5. In Challenge Mode, solve the puzzle within the move limit.',
                ),
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

  Widget _buildGridDisplay(
    List<List<Color>> grid, {
    required double tileSize,
  }) {
    final Q = widget.gridSize ~/ 2;
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
            rowChildren.add(
              Container(
                width: tileSize,
                height: tileSize,
                margin: const EdgeInsets.all(1.0),
                decoration: BoxDecoration(
                  color: grid[r][c],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
            if (c == Q - 1) {
              rowChildren.add(const SizedBox(width: 4));
            }
          }
          final rowWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: rowChildren,
          );

          if (r == Q - 1) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                rowWidget,
                const SizedBox(height: 4),
              ],
            );
          }
          return rowWidget;
        }),
      ),
    );
  }

  Widget _buildMainGrid(double tileSize) {
    final theme = Theme.of(context);
    final themeColor = _palette.isNotEmpty ? _palette[0] : theme.colorScheme.primary;
    final Q = widget.gridSize ~/ 2;

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.gridSize, (rowIndex) {
          final rowChildren = <Widget>[];
          for (int colIndex = 0; colIndex < widget.gridSize; colIndex++) {
            final color = _grid[rowIndex][colIndex];
            final cellQuadrant = (rowIndex ~/ Q) * 2 + (colIndex ~/ Q);
            final isSelected = cellQuadrant == _selectedQuadrant;

            final border = isSelected
                ? Border.all(color: themeColor, width: 2.5)
                : Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15), width: 1.0);

            rowChildren.add(
              Semantics(
                label: 'Row ${rowIndex + 1}, column ${colIndex + 1}, ${_getQuadrantLabel(cellQuadrant)}${isSelected ? ", selected" : ""}',
                button: true,
                excludeSemantics: true,
                onTap: () {
                  if (_isGameOver || _isGameWon) return;
                  setState(() => _selectedQuadrant = cellQuadrant);
                },
                child: GestureDetector(
                onTap: () {
                  if (_isGameOver || _isGameWon) return;
                  setState(() {
                    _selectedQuadrant = cellQuadrant;
                  });
                },
                child: Container(
                  width: tileSize,
                  height: tileSize,
                  margin: const EdgeInsets.all(2.0),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: border,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: themeColor.withValues(alpha: 0.35),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                ),
              ),
              ),
            );

            if (colIndex == Q - 1) {
              rowChildren.add(const SizedBox(width: 12));
            }
          }

          final rowWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: rowChildren,
          );

          if (rowIndex == Q - 1) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                rowWidget,
                const SizedBox(height: 12),
              ],
            );
          }

          return rowWidget;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeColor = _palette.isNotEmpty ? _palette[0] : theme.colorScheme.primary;

    return BaseGameScreen(
      title: 'Rotate Matrix',
      gameId: 'rotate_matrix',
      gameConfig: {
        'gridSize': widget.gridSize,
        'difficulty': widget.difficulty,
        'moveMode': widget.moveMode,
      },
      highScoreLabel: 'Best',
      highScoreValue: bestScore != null ? '$bestScore moves' : '--',
      currentScoreLabel: 'Moves',
      currentScoreValue: '$_moves${widget.moveMode == 'challenge' ? ' / $_moveLimit' : ''}',
      statusText: _isGameWon
          ? 'Puzzle solved!'
          : 'Tap quadrant to select, then rotate it!',
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
          const Text(
            'Target Pattern:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          _buildGridDisplay(_targetPattern, tileSize: (110.0 / widget.gridSize).clamp(9.0, 16.0)),
        ],
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMainGrid((260.0 / widget.gridSize).clamp(24.0, 48.0)),
              const SizedBox(height: 20),
              Text(
                _getQuadrantLabel(_selectedQuadrant),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: themeColor,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.rotate_left),
                    onPressed: (_isGameOver || _isGameWon)
                        ? null
                        : () => _rotateQuadrant(_selectedQuadrant, false),
                    iconSize: 32,
                  ),
                  const SizedBox(width: 32),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.rotate_right),
                    onPressed: (_isGameOver || _isGameWon)
                        ? null
                        : () => _rotateQuadrant(_selectedQuadrant, true),
                    iconSize: 32,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
