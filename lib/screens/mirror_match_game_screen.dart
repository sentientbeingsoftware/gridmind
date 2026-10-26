import 'package:flutter/material.dart';
import 'dart:math';
import '../services/app_persistence_service.dart';
import 'mixins/config_high_score_mixin.dart';
import 'base_game_screen.dart';

class MirrorMatchGameScreen extends StatefulWidget {
  final int gridSize;
  final String symmetryType; // 'vertical', 'horizontal', 'rotational'
  final String moveMode; // 'zen', 'challenge'
  final bool testMode;
  final List<List<bool>>? testPattern;

  const MirrorMatchGameScreen({
    super.key,
    required this.gridSize,
    required this.symmetryType,
    required this.moveMode,
    this.testMode = false,
    this.testPattern,
  });

  @override
  State<MirrorMatchGameScreen> createState() => _MirrorMatchGameScreenState();
}

class _MirrorMatchGameScreenState extends State<MirrorMatchGameScreen> with ConfigHighScoreMixin<MirrorMatchGameScreen> {
  @override
  String get highScoreGameId => 'mirror_match';
  @override
  bool get highScoreLowerIsBetter => true;
  @override
  Map<String, dynamic> get highScoreConfig => {
        'gridSize': widget.gridSize.toDouble(),
        'symmetryType': widget.symmetryType,
        'moveMode': widget.moveMode,
      };
  final Random _rand = Random();

  late List<List<bool>> _grid;
  int _moves = 0;
  int _moveLimit = 0;
  bool _isGameOver = false;
  bool _isGameWon = false;

  final List<List<List<bool>>> _history = [];
  List<Color> _palette = [];

  @override
  void initState() {
    super.initState();
    if (widget.testMode && widget.testPattern != null) {
      _grid = List.generate(
        widget.gridSize,
        (r) => List<bool>.from(widget.testPattern![r]),
      );
      _moves = 0;
      _palette = [Colors.indigo, Colors.blue];
      bestScore = null;
      _isGameOver = false;
      _isGameWon = false;
      _history.clear();

      int staticActiveCount = 0;
      final halfSize = widget.gridSize ~/ 2;
      if (widget.symmetryType == 'vertical') {
        for (int r = 0; r < widget.gridSize; r++) {
          for (int c = 0; c < halfSize; c++) {
            if (_grid[r][c]) staticActiveCount++;
          }
        }
      } else {
        for (int r = 0; r < halfSize; r++) {
          for (int c = 0; c < widget.gridSize; c++) {
            if (_grid[r][c]) staticActiveCount++;
          }
        }
      }
      _moveLimit = staticActiveCount + widget.gridSize + 2;
    } else {
      _grid = List.generate(
        widget.gridSize,
        (_) => List.generate(widget.gridSize, (_) => false),
      );
      _initializeGame();
    }
  }

  Future<void> _initializeGame() async {
    if (widget.testMode && widget.testPattern != null) {
      setState(() {
        _grid = List.generate(
          widget.gridSize,
          (r) => List<bool>.from(widget.testPattern![r]),
        );
        _moves = 0;
        _palette = [Colors.indigo, Colors.blue];
        bestScore = null;
        _isGameOver = false;
        _isGameWon = false;
        _history.clear();

        int staticActiveCount = 0;
        final halfSize = widget.gridSize ~/ 2;
        if (widget.symmetryType == 'vertical') {
          for (int r = 0; r < widget.gridSize; r++) {
            for (int c = 0; c < halfSize; c++) {
              if (_grid[r][c]) staticActiveCount++;
            }
          }
        } else {
          for (int r = 0; r < halfSize; r++) {
            for (int c = 0; c < widget.gridSize; c++) {
              if (_grid[r][c]) staticActiveCount++;
            }
          }
        }
        _moveLimit = staticActiveCount + widget.gridSize + 2;
      });
      return;
    }

    final colors = await AppPersistenceService.getPaletteForGame(colorCount: 5);
    final stored = await loadBestScore();
    if (!mounted) return;

    List<List<bool>> pattern = List.generate(
      widget.gridSize,
      (_) => List.generate(widget.gridSize, (_) => false),
    );

    // Generate random static pattern on the static side
    final halfSize = widget.gridSize ~/ 2;
    int totalStaticCells = widget.symmetryType == 'vertical'
        ? widget.gridSize * halfSize
        : halfSize * widget.gridSize;
    
    int targetActive = (totalStaticCells * (0.35 + _rand.nextDouble() * 0.25)).round();
    if (targetActive < 1) targetActive = 1;

    int activeCount = 0;
    int attempts = 0;
    while (activeCount < targetActive && attempts < 1000) {
      attempts++;
      int r = _rand.nextInt(widget.gridSize);
      int c = _rand.nextInt(widget.gridSize);

      bool isStatic = false;
      if (widget.symmetryType == 'vertical') {
        isStatic = c < halfSize;
      } else {
        isStatic = r < halfSize;
      }

      if (isStatic && !pattern[r][c]) {
        pattern[r][c] = true;
        activeCount++;
      }
    }

    // Calculate move limit based on number of active target cells
    int staticActiveCount = 0;
    if (widget.symmetryType == 'vertical') {
      for (int r = 0; r < widget.gridSize; r++) {
        for (int c = 0; c < halfSize; c++) {
          if (pattern[r][c]) staticActiveCount++;
        }
      }
    } else {
      for (int r = 0; r < halfSize; r++) {
        for (int c = 0; c < widget.gridSize; c++) {
          if (pattern[r][c]) staticActiveCount++;
        }
      }
    }

    setState(() {
      _grid = pattern;
      _moves = 0;
      _moveLimit = staticActiveCount + widget.gridSize + 2;
      bestScore = stored;
      _isGameOver = false;
      _isGameWon = false;
      _history.clear();
      _palette = colors.isNotEmpty
          ? colors
          : [Colors.indigo, Colors.blue, Colors.teal, Colors.purple, Colors.pink];
    });
  }

  bool _isInteractiveCell(int r, int c) {
    final halfSize = widget.gridSize ~/ 2;
    if (widget.symmetryType == 'vertical') {
      return c >= halfSize;
    } else {
      return r >= halfSize;
    }
  }

  void _toggleCell(int r, int c) {
    if (_isGameOver || _isGameWon || !_isInteractiveCell(r, c)) return;

    // Save history
    final copy = List.generate(
      widget.gridSize,
      (row) => List<bool>.from(_grid[row]),
    );
    _history.add(copy);

    setState(() {
      _grid[r][c] = !_grid[r][c];
      _moves++;
      _checkGameStatus();
    });
  }

  void _undoMove() {
    if (_history.isEmpty || _isGameOver || _isGameWon) return;

    setState(() {
      _grid = _history.removeLast();
      _moves = _moves > 0 ? _moves - 1 : 0;
    });
  }

  void _checkGameStatus() {
    bool isWon = true;
    final halfSize = widget.gridSize ~/ 2;

    if (widget.symmetryType == 'vertical') {
      for (int r = 0; r < widget.gridSize; r++) {
        for (int c = 0; c < halfSize; c++) {
          final targetVal = _grid[r][c];
          final playerVal = _grid[r][widget.gridSize - 1 - c];
          if (targetVal != playerVal) {
            isWon = false;
            break;
          }
        }
        if (!isWon) break;
      }
    } else if (widget.symmetryType == 'horizontal') {
      for (int r = 0; r < halfSize; r++) {
        for (int c = 0; c < widget.gridSize; c++) {
          final targetVal = _grid[r][c];
          final playerVal = _grid[widget.gridSize - 1 - r][c];
          if (targetVal != playerVal) {
            isWon = false;
            break;
          }
        }
        if (!isWon) break;
      }
    } else if (widget.symmetryType == 'rotational') {
      for (int r = 0; r < halfSize; r++) {
        for (int c = 0; c < widget.gridSize; c++) {
          final targetVal = _grid[r][c];
          final playerVal = _grid[widget.gridSize - 1 - r][widget.gridSize - 1 - c];
          if (targetVal != playerVal) {
            isWon = false;
            break;
          }
        }
        if (!isWon) break;
      }
    }

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

  Border _buildCellBorder(int r, int c, ThemeData theme) {
    return Border.all(
      color: theme.colorScheme.outline.withValues(alpha: 0.1),
      width: 1.0,
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text('How to Play Mirror Match'),
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
                  'Toggle tiles on the player side of the board so that they perfectly mirror the pattern on the clue side.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Grid Divisions:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  '• Static Clue half: Highlighted with a subtle background and does not respond to taps.\n'
                  '• Interactive Player half: Clean grid layout where you can toggle tiles on and off.\n'
                  '• Symmetry Line: Indicated by the thick yellow axis divider.',
                ),
                const SizedBox(height: 12),
                Text(
                  'Symmetry Rule (${widget.symmetryType.toUpperCase()}):',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (widget.symmetryType == 'vertical')
                  const Text('Reflect elements horizontally across the center vertical line.')
                else if (widget.symmetryType == 'horizontal')
                  const Text('Reflect elements vertically across the center horizontal line.')
                else
                  const Text('Reflect elements rotationally through the center point of the board (rotated 180 degrees).'),
                if (widget.moveMode == 'challenge') ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Challenge Mode:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  Text('Solve the puzzle within the move limit of $_moveLimit moves!'),
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
    final themeColor = _palette.isNotEmpty ? _palette[0] : theme.colorScheme.primary;

    String symmetryLabel = 'Vertical Symmetry';
    if (widget.symmetryType == 'horizontal') {
      symmetryLabel = 'Horizontal Symmetry';
    } else if (widget.symmetryType == 'rotational') {
      symmetryLabel = 'Rotational Symmetry';
    }

    return BaseGameScreen(
      title: 'Mirror Match',
      gameId: 'mirror_match',
      gameConfig: {
        'gridSize': widget.gridSize,
        'symmetryType': widget.symmetryType,
        'moveMode': widget.moveMode,
      },
      highScoreLabel: 'Best',
      highScoreValue: bestScore != null ? '$bestScore moves' : '--',
      currentScoreLabel: 'Moves',
      currentScoreValue: '$_moves',
      statusText: widget.moveMode == 'challenge'
          ? '$symmetryLabel | Limit: $_moves/$_moveLimit'
          : '$symmetryLabel | Zen Mode',
      isGameWon: _isGameWon,
      isGameOver: _isGameOver && !_isGameWon,
      victoryMessage: 'Solved in $_moves moves!',
      gameOverMessage: 'Failed! Exceeded move limit of $_moveLimit!',
      onReset: _initializeGame,
      onUndo: _history.isNotEmpty ? _undoMove : null,
      onHelp: _showHelpDialog,
      isGameInProgress: _moves > 0 && !_isGameOver,
      child: Center(
        child: Container(
          width: 320,
          height: 320,
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
          ),
          child: Stack(
            children: [
              GridView.builder(
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
                  final isInteractive = _isInteractiveCell(r, c);
                  final isPainted = _grid[r][c];

                  Color cellColor;
                  if (isInteractive) {
                    // Interactive side
                    cellColor = isPainted
                        ? themeColor
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
                  } else {
                    // Static side
                    cellColor = isPainted
                        ? themeColor.withValues(alpha: 0.55)
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15);
                  }

                  return GestureDetector(
                    onTap: isInteractive ? () => _toggleCell(r, c) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: cellColor,
                        borderRadius: BorderRadius.circular(6),
                        border: _buildCellBorder(r, c, theme),
                      ),
                      child: !isInteractive
                          ? Icon(
                              Icons.lock_outline,
                              size: widget.gridSize > 6 ? 10 : 14,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                            )
                          : (isPainted
                              ? Icon(
                                  Icons.check,
                                  size: widget.gridSize > 6 ? 12 : 16,
                                  color: cellColor.computeLuminance() > 0.5
                                      ? Colors.black87
                                      : Colors.white,
                                )
                              : null),
                    ),
                  );
                },
              ),
              if (widget.symmetryType == 'vertical')
                Positioned(
                  left: 152 - 1.75,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3.5,
                    color: Colors.amberAccent.shade400,
                  ),
                )
              else
                Positioned(
                  top: 152 - 1.75,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3.5,
                    color: Colors.amberAccent.shade400,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
