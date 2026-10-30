import '../utils/color_names.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../services/app_persistence_service.dart';
import 'mixins/config_high_score_mixin.dart';
import 'base_game_screen.dart';

class ColorFloodGameScreen extends StatefulWidget {
  final int gridSize;
  final int colorCount;
  final String moveMode; // 'zen', 'challenge'
  final bool testMode;
  final List<List<Color>>? testGrid;

  const ColorFloodGameScreen({
    super.key,
    required this.gridSize,
    required this.colorCount,
    required this.moveMode,
    this.testMode = false,
    this.testGrid,
  });

  @override
  State<ColorFloodGameScreen> createState() => _ColorFloodGameScreenState();
}

class _ColorFloodGameScreenState extends State<ColorFloodGameScreen> with ConfigHighScoreMixin<ColorFloodGameScreen> {
  @override
  String get highScoreGameId => 'color_flood';
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
  int _moves = 0;
  int _moveLimit = 0;
  bool _isGameOver = false;
  bool _isGameWon = false;

  final List<List<List<Color>>> _history = [];
  List<Color> _palette = [];

  @override
  void initState() {
    super.initState();
    if (widget.testMode && widget.testGrid != null) {
      _grid = List.generate(
        widget.gridSize,
        (r) => List<Color>.from(widget.testGrid![r]),
      );
      _palette = [Colors.red, Colors.blue, Colors.green, Colors.yellow];
      _moves = 0;
      _moveLimit = 10;
      bestScore = null;
      _isGameOver = false;
      _isGameWon = false;
      _history.clear();
    } else {
      _grid = List.generate(
        widget.gridSize,
        (_) => List.generate(widget.gridSize, (_) => Colors.grey),
      );
      _initializeGame();
    }
  }

  Future<void> _initializeGame() async {
    if (widget.testMode && widget.testGrid != null) {
      setState(() {
        _grid = List.generate(
          widget.gridSize,
          (r) => List<Color>.from(widget.testGrid![r]),
        );
        _palette = [Colors.red, Colors.blue, Colors.green, Colors.yellow];
        _moves = 0;
        _moveLimit = 10;
        bestScore = null;
        _isGameOver = false;
        _isGameWon = false;
        _history.clear();
      });
      return;
    }

    final colors = await AppPersistenceService.getPaletteForGame(colorCount: widget.colorCount);
    final stored = await loadBestScore();
    if (!mounted) return;

    final palette = colors.isNotEmpty
        ? colors
        : [Colors.indigo, Colors.blue, Colors.teal, Colors.purple, Colors.pink, Colors.orange];

    final activeColors = palette.take(widget.colorCount).toList();

    // Generate random colored grid
    final grid = List.generate(
      widget.gridSize,
      (_) => List.generate(widget.gridSize, (_) => activeColors[_rand.nextInt(activeColors.length)]),
    );

    // Calculate move limit
    final calculatedLimit = (widget.gridSize * (1.2 + widget.colorCount * 0.15)).round() + 2;

    setState(() {
      _grid = grid;
      _moves = 0;
      _moveLimit = calculatedLimit;
      bestScore = stored;
      _isGameOver = false;
      _isGameWon = false;
      _history.clear();
      _palette = palette;
    });
  }

  void _floodFill(Color newColor) {
    if (_isGameOver || _isGameWon || _grid.isEmpty) return;
    final oldColor = _grid[0][0];
    if (oldColor == newColor) return;

    // Save history
    final copy = List.generate(
      widget.gridSize,
      (row) => List<Color>.from(_grid[row]),
    );
    _history.add(copy);

    setState(() {
      _moves++;
      _floodFillBFS(oldColor, newColor);
      _checkGameStatus();
    });
  }

  void _floodFillBFS(Color oldColor, Color newColor) {
    final List<Point<int>> queue = [const Point(0, 0)];
    final Set<Point<int>> visited = {const Point(0, 0)};

    _grid[0][0] = newColor;

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final r = current.x;
      final c = current.y;

      final directions = [
        const Point(-1, 0),
        const Point(1, 0),
        const Point(0, -1),
        const Point(0, 1),
      ];

      for (final dir in directions) {
        final nr = r + dir.x;
        final nc = c + dir.y;
        final np = Point(nr, nc);

        if (nr >= 0 && nr < widget.gridSize && nc >= 0 && nc < widget.gridSize) {
          if (!visited.contains(np) && _grid[nr][nc] == oldColor) {
            _grid[nr][nc] = newColor;
            visited.add(np);
            queue.add(np);
          }
        }
      }
    }
  }

  void _undoMove() {
    if (_history.isEmpty || _isGameOver || _isGameWon) return;

    setState(() {
      _grid = _history.removeLast();
      _moves = _moves > 0 ? _moves - 1 : 0;
    });
  }

  void _checkGameStatus() {
    final targetColor = _grid[0][0];
    bool allMatch = true;

    for (int r = 0; r < widget.gridSize; r++) {
      for (int c = 0; c < widget.gridSize; c++) {
        if (_grid[r][c] != targetColor) {
          allMatch = false;
          break;
        }
      }
      if (!allMatch) break;
    }

    if (allMatch) {
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
            Icon(Icons.help_outline, color: Colors.teal),
            SizedBox(width: 8),
            Text('How to Play Color Flood'),
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
                  'Flood the entire board with a single color starting from the top-left cell.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'How to Play:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  '1. Use the color selection buttons at the bottom of the screen.\n'
                  '2. Tapping a color changes the top-left cell and all connected cells of the same color to the new color.\n'
                  '3. Connected cells expand outward, allowing you to flood adjacent cells recursively.',
                ),
                if (widget.moveMode == 'challenge') ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Challenge Mode:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  Text('Unify the entire grid in fewer than $_moveLimit moves!'),
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
    final activeColors = _palette.take(widget.colorCount).toList();

    return BaseGameScreen(
      title: 'Color Flood',
      gameId: 'color_flood',
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Flexible: the board takes only the height the palette leaves over.
            Flexible(
              child: LayoutBuilder(
              builder: (gridContext, constraints) {
                final maxSize = min(constraints.maxWidth, constraints.maxHeight);
                final double gridSizePx = min(400.0, maxSize);
                return Container(
                  width: gridSizePx,
                  height: gridSizePx,
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
                      mainAxisSpacing: 3.0,
                      crossAxisSpacing: 3.0,
                    ),
                    itemCount: widget.gridSize * widget.gridSize,
                    itemBuilder: (context, index) {
                      final r = index ~/ widget.gridSize;
                      final c = index % widget.gridSize;
                      if (r >= _grid.length || c >= _grid[r].length) {
                        return const SizedBox();
                      }
                      final color = _grid[r][c];
                      return Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12.0,
              runSpacing: 12.0,
              alignment: WrapAlignment.center,
              children: activeColors.map((color) {
                final isCurrent = _grid.isNotEmpty && _grid[0][0] == color;
                return Semantics(
label: 'Flood with ${colorName(color)}${isCurrent ? ", current color" : ""}',
button: true,
child: GestureDetector(
                  onTap: () => _floodFill(color),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCurrent ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.5), // visible on light and dark
                        width: isCurrent ? 3.0 : 1.5,
                      ),
                      boxShadow: [
                        if (isCurrent)
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                  ),
                ),
);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
