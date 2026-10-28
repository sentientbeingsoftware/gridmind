import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../services/app_persistence_service.dart';
import 'base_game_screen.dart';
import 'mixins/config_high_score_mixin.dart';

class ChainReactionGameScreen extends StatefulWidget {
  final int gridSize;
  final String difficulty; // 'easy', 'medium', 'hard'
  final String moveMode; // 'zen', 'challenge'
  final bool testMode;
  final List<List<int>>? testGrid;
  final Point<int>? testStartTap;
  final int? testMaxTaps;

  const ChainReactionGameScreen({
    super.key,
    required this.gridSize,
    required this.difficulty,
    required this.moveMode,
    this.testMode = false,
    this.testGrid,
    this.testStartTap,
    this.testMaxTaps,
  });

  @override
  State<ChainReactionGameScreen> createState() =>
      _ChainReactionGameScreenState();
}

class _ChainReactionGameScreenState extends State<ChainReactionGameScreen>
    with
        TickerProviderStateMixin,
        ConfigHighScoreMixin<ChainReactionGameScreen> {
  @override
  String get highScoreGameId => 'chain_reaction';
  @override
  bool get highScoreLowerIsBetter => true;
  @override
  Map<String, dynamic> get highScoreConfig => {
        'gridSize': widget.gridSize.toDouble(),
        'difficulty': widget.difficulty,
        'moveMode': widget.moveMode,
      };
  final Random _rand = Random();

  late List<List<int>> _grid;
  int _taps = 0;
  int _tapLimit = 0;
  bool _isGameOver = false;
  bool _isGameWon = false;
  bool _isReacting = false;

  List<Color> _palette = [];
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (!widget.testMode) {
      _pulseController.repeat(reverse: true);
    }

    _initializeGame();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  int _getCapacity(int r, int c) {
    if (widget.gridSize <= 1) return 4;
    int neighbors = 0;
    if (r > 0) neighbors++;
    if (r < widget.gridSize - 1) neighbors++;
    if (c > 0) neighbors++;
    if (c < widget.gridSize - 1) neighbors++;
    return neighbors;
  }

  bool _isBoardEmpty() {
    for (int r = 0; r < widget.gridSize; r++) {
      for (int c = 0; c < widget.gridSize; c++) {
        if (_grid[r][c] > 0) return false;
      }
    }
    return true;
  }

  void _initializeGame() {
    // Determine tap limit
    if (widget.testMode) {
      _tapLimit = widget.testMaxTaps ?? 5;
    } else {
      switch (widget.difficulty) {
        case 'easy':
          _tapLimit = widget.gridSize * 2 + 4;
          break;
        case 'hard':
          _tapLimit = widget.gridSize + 2;
          break;
        case 'medium':
        default:
          _tapLimit = (widget.gridSize * 1.5).round() + 2;
          break;
      }
    }

    // Synchronous initial grid creation to prevent LateInitializationErrors during first frame
    if (widget.testMode && widget.testGrid != null) {
      _grid = List.generate(
        widget.gridSize,
        (r) => List<int>.from(widget.testGrid![r]),
      );
    } else {
      _grid = List.generate(
        widget.gridSize,
        (r) => List.generate(widget.gridSize, (c) {
          final capacity = _getCapacity(r, c);
          double probability;
          switch (widget.difficulty) {
            case 'easy':
              probability = 0.35;
              break;
            case 'hard':
              probability = 0.70;
              break;
            case 'medium':
            default:
              probability = 0.50;
              break;
          }

          if (_rand.nextDouble() < probability) {
            // Generate value from 1 to capacity - 1
            return _rand.nextInt(capacity - 1) + 1;
          }
          return 0;
        }),
      );
    }

    _taps = 0;
    _isGameOver = false;
    _isGameWon = false;
    _isReacting = false;

    // Trigger async loading of settings / configs
    _loadPersistenceData();

    // In testMode, if testStartTap is provided, run it automatically
    if (widget.testMode && widget.testStartTap != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleCellTap(widget.testStartTap!.x, widget.testStartTap!.y);
      });
    }
  }

  Future<void> _loadPersistenceData() async {
    final colors = await AppPersistenceService.getPaletteForGame(colorCount: 5);
    final stored = await loadBestScore();

    if (mounted) {
      setState(() {
        bestScore = stored;
        _palette = colors.isNotEmpty
            ? colors
            : [
                Colors.indigo,
                Colors.blue,
                Colors.teal,
                Colors.purple,
                Colors.pink
              ];
      });
    }
  }

  Future<void> _saveHighScore() async {
    if (widget.testMode) return;

    await submitScore(_taps);
  }

  void _handleCellTap(int r, int c) {
    if (_isGameOver || _isGameWon || _isReacting) return;

    setState(() {
      _grid[r][c]++;
      _taps++;
    });

    _processChainReaction();
  }

  Future<void> _processChainReaction() async {
    setState(() {
      _isReacting = true;
    });

    bool hasExploded = true;
    int limitSafety = 0; // Prevent infinite loops in case of unexpected state

    while (hasExploded && limitSafety < 500) {
      limitSafety++;
      final explodingCells = <Point<int>>[];

      for (int r = 0; r < widget.gridSize; r++) {
        for (int c = 0; c < widget.gridSize; c++) {
          final capacity = _getCapacity(r, c);
          if (_grid[r][c] >= capacity) {
            explodingCells.add(Point(r, c));
          }
        }
      }

      if (explodingCells.isEmpty) {
        hasExploded = false;
        break;
      }

      if (!mounted) return;
      setState(() {
        // Build new state grid
        final newGrid = List.generate(
          widget.gridSize,
          (r) => List<int>.from(_grid[r]),
        );

        for (final cell in explodingCells) {
          final capacity = _getCapacity(cell.x, cell.y);
          newGrid[cell.x][cell.y] = max(0, newGrid[cell.x][cell.y] - capacity);

          // Flying dots: each dot travels in its orthogonal direction across
          // empty cells until it hits an occupied cell (or leaves the board).
          const deltas = [
            Point(-1, 0),
            Point(1, 0),
            Point(0, -1),
            Point(0, 1),
          ];
          for (final d in deltas) {
            int nr = cell.x + d.x;
            int nc = cell.y + d.y;
            while (nr >= 0 &&
                nr < widget.gridSize &&
                nc >= 0 &&
                nc < widget.gridSize) {
              if (_grid[nr][nc] > 0) {
                newGrid[nr][nc]++;
                break;
              }
              nr += d.x;
              nc += d.y;
            }
          }
        }

        _grid = newGrid;
      });

      // Check win condition (all cleared)
      if (_isBoardEmpty()) {
        setState(() {
          _isGameWon = true;
          _isReacting = false;
        });
        _saveHighScore();
        return;
      }

      // Briefly pause to animate the cascade tick
      if (!widget.testMode) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      if (!mounted) return;
    }

    if (!mounted) return;
    setState(() {
      _isReacting = false;
    });

    // Check game over condition
    if (widget.moveMode == 'challenge' && _taps >= _tapLimit && !_isGameWon) {
      setState(() {
        _isGameOver = true;
      });
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.purpleAccent),
            SizedBox(width: 8),
            Text('How to Play Chain Reaction'),
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
                  'Clear all atoms/orbs from the grid in as few taps as possible.',
                ),
                SizedBox(height: 12),
                Text(
                  'Rules:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '1. Tap any grid cell to add one orb/atom to it.\n'
                  '2. Each cell has a Critical Mass threshold based on its neighbors:\n'
                  '   - Corners: 2 atoms\n'
                  '   - Edges: 3 atoms\n'
                  '   - Center: 4 atoms\n'
                  '3. When a cell reaches its critical mass, it explodes, firing 1 atom in each orthogonal direction across empty cells until it hits an occupied cell.\n'
                  '4. Distributed atoms can trigger adjacent cells to also explode, starting a Chain Reaction!\n'
                  '5. Atoms traveling off the edge of the grid are destroyed. Use this to clear the board.\n'
                  '6. In Challenge Mode, clear the board before running out of taps.',
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

  Widget _buildOrbLayout(int count, Color color) {
    if (count == 0) return const SizedBox();

    final double dotSize = widget.gridSize > 6 ? 8 : 12;

    switch (count) {
      case 1:
        return Center(
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      case 2:
        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
        );
      case 3:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: dotSize,
                    height: dotSize,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: dotSize,
                    height: dotSize,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ],
              ),
            ],
          ),
        );
      default: // 4 or more
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: dotSize,
                    height: dotSize,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: dotSize,
                    height: dotSize,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: dotSize,
                    height: dotSize,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: dotSize,
                    height: dotSize,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeColor =
        _palette.isNotEmpty ? _palette[0] : theme.colorScheme.primary;

    return BaseGameScreen(
      title: 'Chain Reaction',
      gameId: 'chain_reaction',
      gameConfig: {
        'gridSize': widget.gridSize,
        'difficulty': widget.difficulty,
        'moveMode': widget.moveMode,
      },
      highScoreLabel: 'Best',
      highScoreValue: bestScore != null ? '$bestScore taps' : '--',
      currentScoreLabel: 'Taps',
      currentScoreValue:
          '$_taps${widget.moveMode == 'challenge' ? ' / $_tapLimit' : ''}',
      statusText: _isReacting
          ? 'Explosion chain propagating...'
          : 'Tap any cell to seed a chain reaction!',
      isGameWon: _isGameWon,
      isGameOver: _isGameOver && !_isGameWon,
      victoryMessage: 'Chain Reaction complete! Solved in $_taps taps!',
      gameOverMessage: 'Out of taps! Try again.',
      onReset: _initializeGame,
      isGameInProgress: _taps > 0 && !_isGameOver,
      onHelp: _showHelpDialog,
      child: Center(
        child: Container(
          width: 300,
          height: 300,
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.15)),
          ),
          child: AbsorbPointer(
            absorbing: _isReacting,
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
                final count = _grid[r][c];
                final capacity = _getCapacity(r, c);
                final isCritical = (capacity - count == 1);

                Color orbColor = themeColor;

                if (count > 0) {
                  if (capacity - count == 1) {
                    orbColor = Colors.redAccent;
                  } else if (capacity - count == 2) {
                    orbColor = Colors.orangeAccent;
                  } else {
                    orbColor = Colors.tealAccent;
                  }
                }

                return Semantics(
label: 'Row ${r + 1}, column ${c + 1}, $count of $capacity',
button: true,
child: GestureDetector(
                  onTap: () => _handleCellTap(r, c),
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      double scale = 1.0;
                      if (isCritical && !_isReacting) {
                        scale = 1.0 + 0.05 * _pulseController.value;
                      }

                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isCritical
                                ? Colors.redAccent.withValues(
                                    alpha: 0.05 + 0.05 * _pulseController.value)
                                : theme.colorScheme.outline
                                    .withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCritical
                                  ? Colors.redAccent.withValues(
                                      alpha: 0.4 + 0.4 * _pulseController.value)
                                  : (count > 0
                                      ? orbColor.withValues(alpha: 0.3)
                                      : theme.colorScheme.outline
                                          .withValues(alpha: 0.1)),
                              width: isCritical ? 2.0 : 1.0,
                            ),
                          ),
                          child: _buildOrbLayout(count, orbColor),
                        ),
                      );
                    },
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
