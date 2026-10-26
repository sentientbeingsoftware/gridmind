import 'package:flutter/material.dart';
import 'dart:math';
import '../utils/grid_utils.dart';
import '../services/app_persistence_service.dart';
import 'mixins/config_high_score_mixin.dart';
import 'base_game_screen.dart';

class ShapeShiftGameScreen extends StatefulWidget {
  final int gridSize;
  final int colorCount;
  final String moveMode; // 'zen', 'challenge'
  final bool testMode;
  final List<List<Color>>? testTargetPattern;
  final List<List<Color>>? testPlayerGrid;

  const ShapeShiftGameScreen({
    super.key,
    required this.gridSize,
    required this.colorCount,
    required this.moveMode,
    this.testMode = false,
    this.testTargetPattern,
    this.testPlayerGrid,
  });

  @override
  State<ShapeShiftGameScreen> createState() => _ShapeShiftGameScreenState();
}

class _ShapeShiftGameScreenState extends State<ShapeShiftGameScreen> with ConfigHighScoreMixin<ShapeShiftGameScreen> {
  @override
  String get highScoreGameId => 'shape_shift';
  @override
  bool get highScoreLowerIsBetter => true;
  @override
  Map<String, dynamic> get highScoreConfig => {
        'gridSize': widget.gridSize.toDouble(),
        'colorCount': widget.colorCount.toDouble(),
        'moveMode': widget.moveMode,
      };
  final Random _rand = Random();

  late List<List<Color>> _grid;
  late List<List<Color>> _targetPattern;

  int _moves = 0;
  int _moveLimit = 0;
  bool _isGameOver = false;
  bool _isGameWon = false;

  int? _selectedRow;
  int? _selectedCol;

  final List<List<List<Color>>> _history = [];

  @override
  void initState() {
    super.initState();
    if (widget.testMode && widget.testTargetPattern != null && widget.testPlayerGrid != null) {
      // Synchronous initialization for testing
      _grid = List.generate(
        widget.gridSize,
        (r) => List<Color>.from(widget.testPlayerGrid![r]),
      );
      _targetPattern = List.generate(
        widget.gridSize,
        (r) => List<Color>.from(widget.testTargetPattern![r]),
      );
      _moves = 0;
      _moveLimit = 15;
      bestScore = null;
      _isGameOver = false;
      _isGameWon = false;
      _history.clear();
      _selectedRow = null;
      _selectedCol = null;
    } else {
      // Temporary setup to prevent LateInitializationErrors during first frame
      _grid = List.generate(
        widget.gridSize,
        (_) => List.generate(widget.gridSize, (_) => Colors.grey),
      );
      _targetPattern = List.generate(
        widget.gridSize,
        (_) => List.generate(widget.gridSize, (_) => Colors.grey),
      );
      _initializeGame();
    }
  }

  Future<void> _initializeGame() async {
    if (widget.testMode && widget.testTargetPattern != null && widget.testPlayerGrid != null) {
      setState(() {
        _grid = List.generate(
          widget.gridSize,
          (r) => List<Color>.from(widget.testPlayerGrid![r]),
        );
        _targetPattern = List.generate(
          widget.gridSize,
          (r) => List<Color>.from(widget.testTargetPattern![r]),
        );
        _moves = 0;
        _moveLimit = 15;
        bestScore = null;
        _isGameOver = false;
        _isGameWon = false;
        _history.clear();
        _selectedRow = null;
        _selectedCol = null;
      });
      return;
    }

    final colors = await AppPersistenceService.getPaletteForGame(colorCount: widget.colorCount);
    final stored = await loadBestScore();
    if (!mounted) return;

    final palette = colors.isNotEmpty
        ? colors
        : [Colors.indigo, Colors.blue, Colors.teal, Colors.purple, Colors.pink];

    // Generate random target grid
    final activeColors = palette.take(widget.colorCount).toList();
    final target = List.generate(
      widget.gridSize,
      (_) => List.generate(widget.gridSize, (_) => activeColors[_rand.nextInt(activeColors.length)]),
    );

    // Shuffle the target to create solvable scrambled grid
    final shuffles = widget.gridSize * 3;
    final grid = _generateShuffledGrid(target, shuffles, activeColors);

    setState(() {
      _grid = grid;
      _targetPattern = target;
      _moves = 0;
      _moveLimit = shuffles + 5;
      bestScore = stored;
      _isGameOver = false;
      _isGameWon = false;
      _history.clear();
      _selectedRow = null;
      _selectedCol = null;
    });
  }

  List<List<Color>> _generateShuffledGrid(List<List<Color>> target, int swapCount, List<Color> activeColors) {
    final grid = List.generate(
      widget.gridSize,
      (r) => List<Color>.from(target[r]),
    );

    int successfulSwaps = 0;
    while (successfulSwaps < swapCount) {
      int r1 = _rand.nextInt(widget.gridSize);
      int c1 = _rand.nextInt(widget.gridSize);

      int dir = _rand.nextInt(4);
      int r2 = r1;
      int c2 = c1;

      if (dir == 0) {
        r2 = r1 - 1;
      } else if (dir == 1) {
        r2 = r1 + 1;
      } else if (dir == 2) {
        c2 = c1 - 1;
      } else if (dir == 3) {
        c2 = c1 + 1;
      }

      if (r2 >= 0 && r2 < widget.gridSize && c2 >= 0 && c2 < widget.gridSize) {
        if (grid[r1][c1] != grid[r2][c2]) {
          final temp = grid[r1][c1];
          grid[r1][c1] = grid[r2][c2];
          grid[r2][c2] = temp;
          successfulSwaps++;
        }
      }
    }
    return grid;
  }

  bool _isAdjacent(int r1, int c1, int r2, int c2) {
    return (r1 - r2).abs() + (c1 - c2).abs() == 1;
  }

  void _onCellTap(int r, int c) {
    if (_isGameOver || _isGameWon) return;

    setState(() {
      if (_selectedRow == null) {
        _selectedRow = r;
        _selectedCol = c;
      } else if (_selectedRow == r && _selectedCol == c) {
        // Deselect
        _selectedRow = null;
        _selectedCol = null;
      } else {
        // Check if adjacent to swap
        if (_isAdjacent(_selectedRow!, _selectedCol!, r, c)) {
          // Push to history
          final copy = List.generate(
            widget.gridSize,
            (row) => List<Color>.from(_grid[row]),
          );
          _history.add(copy);

          // Swap colors
          final temp = _grid[r][c];
          _grid[r][c] = _grid[_selectedRow!][_selectedCol!];
          _grid[_selectedRow!][_selectedCol!] = temp;

          _moves++;
          _selectedRow = null;
          _selectedCol = null;

          _checkGameStatus();
        } else {
          // Change selection to newly tapped cell
          _selectedRow = r;
          _selectedCol = c;
        }
      }
    });
  }

  void _undoMove() {
    if (_history.isEmpty || _isGameOver || _isGameWon) return;

    setState(() {
      _grid = _history.removeLast();
      _moves = _moves > 0 ? _moves - 1 : 0;
      _selectedRow = null;
      _selectedCol = null;
    });
  }

  void _checkGameStatus() {
    bool isWon = GridUtils.areGridsEqual(_grid, _targetPattern);

    if (isWon) {
      _isGameWon = true;
      _saveHighScore();
    } else if (widget.moveMode == 'challenge' && _moves >= _moveLimit) {
      _isGameOver = true;
    }
  }

  Future<void> _saveHighScore() async {
    await submitScore(_moves);
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.indigoAccent),
            SizedBox(width: 8),
            Text('How to Play Shape Shift'),
          ],
        ),
        content: Scrollbar(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Goal:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Rearrange the colors on the player board so that it exactly matches the target pattern displayed in the header HUD.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'How to Shift Tiles:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  '1. Tap any colored cell to select it. It will receive a highlighted yellow border.\n'
                  '2. Tap any adjacent cell (up, down, left, or right) to swap the colors of the two tiles.\n'
                  '3. Tapping a non-adjacent cell transfers selection to that cell. Tapping the selected cell again deselects it.',
                ),
                if (widget.moveMode == 'challenge') ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Challenge Mode:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  Text('Recreate the blueprint in fewer than $_moveLimit moves!'),
                ],
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BaseGameScreen(
      title: 'Shape Shift',
      gameId: 'shape_shift',
      gameConfig: {
        'gridSize': widget.gridSize,
        'colorCount': widget.colorCount,
        'moveMode': widget.moveMode,
      },
      highScoreLabel: 'Best',
      highScoreValue: bestScore != null ? '$bestScore moves' : '--',
      currentScoreLabel: 'Moves',
      currentScoreValue: '$_moves',
      statusText: widget.moveMode == 'challenge'
          ? 'Limit: $_moves/$_moveLimit'
          : 'Zen Mode (Unlimited)',
      isGameWon: _isGameWon,
      isGameOver: _isGameOver && !_isGameWon,
      victoryMessage: 'Solved in $_moves moves!',
      gameOverMessage: 'Failed! Exceeded move limit of $_moveLimit!',
      onReset: _initializeGame,
      onUndo: _history.isNotEmpty ? _undoMove : null,
      onHelp: _showHelpDialog,
      isGameInProgress: _moves > 0 && !_isGameOver,
      topHudExtra: Column(
        children: [
          const Text(
            'Target Pattern:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Container(
            width: 75,
            height: 75,
            padding: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
            ),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: widget.gridSize,
                crossAxisSpacing: 1.5,
                mainAxisSpacing: 1.5,
              ),
              itemCount: widget.gridSize * widget.gridSize,
              itemBuilder: (context, idx) {
                final r = idx ~/ widget.gridSize;
                final c = idx % widget.gridSize;
                if (r >= _targetPattern.length || c >= _targetPattern[r].length) {
                  return const SizedBox();
                }
                final color = _targetPattern[r][c];
                return Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 300,
          height: 300,
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
              if (r >= _grid.length || c >= _grid[r].length) {
                return const SizedBox();
              }
              final color = _grid[r][c];
              final isSelected = _selectedRow == r && _selectedCol == c;

              return GestureDetector(
                onTap: () => _onCellTap(r, c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.amberAccent : theme.colorScheme.outline.withValues(alpha: 0.1),
                      width: isSelected ? 3.5 : 1.0,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.swap_horiz,
                          size: widget.gridSize > 4 ? 16 : 24,
                          color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                        )
                      : null,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
