import 'package:flutter/material.dart';
import 'dart:math';
import '../services/app_persistence_service.dart';
import 'mixins/config_high_score_mixin.dart';
import '../utils/grid_utils.dart';
import 'base_game_screen.dart';

class BinaryLightsGameScreen extends StatefulWidget {
  final int gridSize;
  final String gameMode; // 'classic' (all off) or 'pattern' (match target)
  final String moveMode; // 'zen' (no limit) or 'challenge' (limit moves)
  final bool testMode;
  final List<List<bool>>? testStartGrid;
  final List<List<bool>>? testTargetGrid;

  const BinaryLightsGameScreen({
    super.key,
    required this.gridSize,
    required this.gameMode,
    required this.moveMode,
    this.testMode = false,
    this.testStartGrid,
    this.testTargetGrid,
  });

  @override
  State<BinaryLightsGameScreen> createState() => _BinaryLightsGameScreenState();
}

class _BinaryLightsGameScreenState extends State<BinaryLightsGameScreen> with ConfigHighScoreMixin<BinaryLightsGameScreen> {
  @override
  String get highScoreGameId => 'binarylights';
  @override
  bool get highScoreLowerIsBetter => true;
  @override
  Map<String, dynamic> get highScoreConfig => {
        'gridSize': widget.gridSize.toDouble(),
        'gameMode': widget.gameMode,
        'moveMode': widget.moveMode,
      };
  final Random _rand = Random();

  late List<List<bool>> _grid;
  late List<List<bool>> _targetGrid;

  int _moves = 0;
  int _targetMoves = 0;
  bool _isGameOver = false;
  bool _isGameWon = false;

  List<Color> _palette = [];

  @override
  void initState() {
    super.initState();
    if (widget.testMode && widget.testStartGrid != null && widget.testTargetGrid != null) {
      _palette = [Colors.amber, Colors.blue];
      bestScore = null;
      _grid = GridUtils.cloneGrid(widget.testStartGrid!);
      _targetGrid = GridUtils.cloneGrid(widget.testTargetGrid!);
      _moves = 0;
      _targetMoves = 5;
      _isGameOver = false;
      _isGameWon = false;
    } else {
      // Synchronously pre-initialize to prevent LateInitializationError
      _grid = List.generate(
        widget.gridSize,
        (_) => List.generate(widget.gridSize, (_) => false),
      );
      _targetGrid = List.generate(
        widget.gridSize,
        (_) => List.generate(widget.gridSize, (_) => false),
      );
      _initializeGame();
    }
  }

  Future<void> _initializeGame() async {
    final colors = await AppPersistenceService.getPaletteForGame(colorCount: 4);
    final high = await loadBestScore();
    if (!mounted) return;

    if (widget.testMode && widget.testStartGrid != null && widget.testTargetGrid != null) {
      return;
    }

    setState(() {
      _palette = colors.isNotEmpty ? colors : [Colors.amber, Colors.blue];
      bestScore = high;
      _moves = 0;
      _isGameOver = false;
      _isGameWon = false;

      // 1. Generate target grid
      if (widget.gameMode == 'classic') {
        _targetGrid = List.generate(
          widget.gridSize,
          (_) => List.generate(widget.gridSize, (_) => false),
        );
      } else {
        _targetGrid = List.generate(
          widget.gridSize,
          (_) => List.generate(widget.gridSize, (_) => _rand.nextBool()),
        );
      }

      // 2. Generate current starting grid by applying random toggles to target
      _grid = GridUtils.cloneGrid(_targetGrid);

      // Apply random cell toggles to ensure solvability
      int shuffles = widget.gridSize * widget.gridSize;
      shuffles = max(shuffles, 5); // Ensure at least 5 toggles
      _targetMoves = 0;

      for (int i = 0; i < shuffles; i++) {
        int r = _rand.nextInt(widget.gridSize);
        int c = _rand.nextInt(widget.gridSize);
        _toggleCellAndNeighbors(_grid, r, c);
        _targetMoves++;
      }

      // Re-shuffle if it's already solved
      int reshuffleAttempts = 0;
      while (GridUtils.areGridsEqual(_grid, _targetGrid) && reshuffleAttempts < 100) {
        reshuffleAttempts++;
        for (int i = 0; i < 3; i++) {
          int r = _rand.nextInt(widget.gridSize);
          int c = _rand.nextInt(widget.gridSize);
          _toggleCellAndNeighbors(_grid, r, c);
          _targetMoves++;
        }
      }
    });
  }

  void _toggleCellAndNeighbors(List<List<bool>> grid, int r, int c) {
    grid[r][c] = !grid[r][c];
    if (r > 0) grid[r - 1][c] = !grid[r - 1][c];
    if (r < widget.gridSize - 1) grid[r + 1][c] = !grid[r + 1][c];
    if (c > 0) grid[r][c - 1] = !grid[r][c - 1];
    if (c < widget.gridSize - 1) grid[r][c + 1] = !grid[r][c + 1];
  }

  void _handleCellTap(int r, int c) {
    if (_isGameOver || _isGameWon) return;

    setState(() {
      _toggleCellAndNeighbors(_grid, r, c);
      _moves++;

      if (GridUtils.areGridsEqual(_grid, _targetGrid)) {
        _isGameWon = true;
        _isGameOver = true;
        _saveHighScore();
      } else if (widget.moveMode == 'challenge' && _moves >= _targetMoves * 2) {
        _isGameOver = true;
        _isGameWon = false;
      }
    });
  }

  Future<void> _saveHighScore() async {
    await submitScore(_moves);
  }

  Color _getOnColor() {
    return _palette.isNotEmpty ? _palette[0] : Colors.amber;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onColor = _getOnColor();
    final offColor = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);

    final showTarget = widget.gameMode == 'pattern';

    return BaseGameScreen(
      title: 'Binary Lights',
      gameId: 'binarylights',
      gameConfig: {
        'gridSize': widget.gridSize,
        'gameMode': widget.gameMode,
        'moveMode': widget.moveMode,
      },
      highScoreLabel: 'Best',
      highScoreValue: bestScore != null ? '$bestScore moves' : '-',
      currentScoreLabel: 'Moves',
      currentScoreValue: '$_moves',
      statusText: widget.moveMode == 'challenge'
          ? 'Limit: $_moves/${_targetMoves * 2}'
          : 'Goal: ${widget.gameMode == 'classic' ? 'Turn all lights off!' : 'Match the pattern!'}',
      isGameWon: _isGameWon,
      isGameOver: _isGameOver && !_isGameWon,
      victoryMessage: 'Solved in $_moves moves!',
      gameOverMessage: 'Failed! Exceeded move limit of ${_targetMoves * 2} moves!',
      onReset: _initializeGame,
      isGameInProgress: _moves > 0 && !_isGameOver,
      topHudExtra: showTarget
          ? Column(
              children: [
                Text(
                  'TARGET PATTERN',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.primary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 100,
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
                      mainAxisSpacing: 2.0,
                      crossAxisSpacing: 2.0,
                    ),
                    itemCount: widget.gridSize * widget.gridSize,
                    itemBuilder: (context, idx) {
                      int r = idx ~/ widget.gridSize;
                      int c = idx % widget.gridSize;
                      bool isOn = _targetGrid[r][c];
                      return Container(
                        decoration: BoxDecoration(
                          color: isOn ? onColor : Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    },
                  ),
                ),
              ],
            )
          : null,
      child: Center(
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
            ),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: widget.gridSize,
                mainAxisSpacing: 6.0,
                crossAxisSpacing: 6.0,
              ),
              itemCount: widget.gridSize * widget.gridSize,
              itemBuilder: (context, index) {
                final r = index ~/ widget.gridSize;
                final c = index % widget.gridSize;
                final isOn = _grid[r][c];
                final tileColor = isOn ? onColor : offColor;

                return Semantics(
label: 'Row ${r + 1}, column ${c + 1}, light ${isOn ? "on" : "off"}',
button: true,
child: GestureDetector(
                  onTap: () => _handleCellTap(r, c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: tileColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isOn ? Colors.white : theme.colorScheme.outline.withValues(alpha: 0.25),
                        width: isOn ? 2.0 : 1.0,
                      ),
                      boxShadow: isOn
                          ? [
                              BoxShadow(
                                color: onColor.withValues(alpha: 0.5),
                                blurRadius: 10.0,
                                spreadRadius: 1.0,
                              )
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Icon(
                        isOn ? Icons.lightbulb : Icons.lightbulb_outline,
                        size: widget.gridSize > 5 ? 24 : 32,
                        color: isOn
                            ? (onColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white)
                            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
);
              },
            ),
          ),
        ),
      ),
    );
  }
}
