import '../utils/announce.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import '../services/app_persistence_service.dart';
import 'mixins/config_high_score_mixin.dart';
import 'base_game_screen.dart';

class SumGridGameScreen extends StatefulWidget {
  final int gridSize;
  final String gameMode; // 'timed' or 'classic'
  final String targetMode; // 'fixed' or 'random'

  const SumGridGameScreen({
    super.key,
    required this.gridSize,
    required this.gameMode,
    required this.targetMode,
  });

  @override
  State<SumGridGameScreen> createState() => _SumGridGameScreenState();
}

class _SumGridGameScreenState extends State<SumGridGameScreen> with ConfigHighScoreMixin<SumGridGameScreen> {
  @override
  String get highScoreGameId => 'sumgrid';
  @override
  bool get highScoreLowerIsBetter => widget.gameMode == 'classic';
  @override
  Map<String, dynamic> get highScoreConfig => {
        'gridSize': widget.gridSize.toDouble(),
        'gameMode': widget.gameMode,
        'targetMode': widget.targetMode,
      };
  final Random _rand = Random();

  late List<List<int>> _grid;
  final List<Point<int>> _selectedCells = [];
  
  int _score = 0;
  int _moves = 0;
  int _targetSum = 10;
  
  // Timer state (Timed Mode)
  int _secondsLeft = 60;
  Timer? _timer;
  
  // Classic mode state
  int _targetsCleared = 0;
  static const int kClassicTargetCount = 10;

  bool _isGameOver = false;
  bool _isGameWon = false;
  bool _dragging = false;

  List<Color> _palette = [];

  @override
  void initState() {
    super.initState();
    // Synchronously initialize the grid to avoid LateInitializationError during the first build frame
    _grid = List.generate(
      widget.gridSize,
      (_) => List.generate(widget.gridSize, (_) => 1),
    );
    _initializeGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeGame() async {
    // Load palette
    final colors = await AppPersistenceService.getPaletteForGame(colorCount: 9);
    // Load high score
    final high = await loadBestScore();
    if (!mounted) return;

    setState(() {
      _palette = colors;
      bestScore = high;
      _grid = List.generate(
        widget.gridSize,
        (_) => List.generate(widget.gridSize, (_) => _rand.nextInt(9) + 1),
      );
      _score = 0;
      _moves = 0;
      _targetsCleared = 0;
      _secondsLeft = 60;
      _isGameOver = false;
      _isGameWon = false;
      _selectedCells.clear();
      _generateNewTarget();
    });

    if (widget.gameMode == 'timed') {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        setState(() {
          _secondsLeft = 0;
          _isGameOver = true;
          _timer?.cancel();
        });
        _saveHighScore();
      }
    });
  }

  void _generateNewTarget() {
    if (widget.targetMode == 'fixed') {
      _targetSum = 10;
    } else {
      // Pick a random target between 10 and 22
      _targetSum = _rand.nextInt(13) + 10;
    }
  }

  int get _currentSelectionSum {
    int sum = 0;
    for (var pt in _selectedCells) {
      sum += _grid[pt.x][pt.y];
    }
    return sum;
  }

  bool _isAdjacent(Point<int> p1, Point<int> p2) {
    return (p1.x - p2.x).abs() + (p1.y - p2.y).abs() == 1;
  }

  void _handleCellTouchStart(int r, int c) {
    if (_isGameOver || _isGameWon) return;
    setState(() {
      _dragging = true;
      _selectedCells.clear();
      _selectedCells.add(Point(r, c));
    });
    // Check match for single cell
    if (_currentSelectionSum == _targetSum) {
      _handleSuccessMatch();
    }
  }

  void _handleCellTouchUpdate(int r, int c) {
    if (!_dragging || _isGameOver || _isGameWon || _selectedCells.isEmpty) return;
    final cell = Point(r, c);
    
    // Ignore if last selected is same as current touch point
    if (_selectedCells.last == cell) return;

    // Undo path if player drags back to the second to last cell
    if (_selectedCells.length > 1 && _selectedCells[_selectedCells.length - 2] == cell) {
      setState(() {
        _selectedCells.removeLast();
      });
      return;
    }

    // Only allow selecting if it is adjacent to the last selected, and hasn't been selected yet
    if (_isAdjacent(_selectedCells.last, cell) && !_selectedCells.contains(cell)) {
      setState(() {
        _selectedCells.add(cell);
      });
      
      // Real-time evaluation
      final sum = _currentSelectionSum;
      if (sum == _targetSum) {
        _handleSuccessMatch();
      } else if (sum > _targetSum) {
        _handleFailMatch();
      }
    }
  }

  /// Screen-reader path: each activation adds a cell to the selection (or
  /// starts one), using the same rules as a drag. Activating the previous cell
  /// removes the last one.
  void _semanticSelect(int r, int c) {
    if (_isGameOver || _isGameWon) return;
    final cell = Point(r, c);
    if (_selectedCells.isEmpty) {
      _handleCellTouchStart(r, c);
      if (_selectedCells.isNotEmpty) announce(context, 'Started at row ${r + 1}, column ${c + 1}. Sum $_currentSelectionSum of $_targetSum.');
      return;
    }
    final before = _selectedCells.length;
    final scoreBefore = _score;
    _handleCellTouchUpdate(r, c);
    if (_score != scoreBefore) {
      announce(context, 'Match! New target $_targetSum.');
    } else if (_selectedCells.isEmpty) {
      announce(context, 'Sum went over the target. Selection cleared.');
    } else if (_selectedCells.length == before && _selectedCells.last != cell) {
      announce(context, 'Not next to your last cell. Pick a neighbouring cell.');
    } else {
      announce(context, 'Sum $_currentSelectionSum of $_targetSum.');
    }
  }

  void _semanticClear() {
    if (_selectedCells.isEmpty) return;
    _handleCellTouchEnd();
    announce(context, 'Selection cleared.');
  }

  void _handleCellTouchEnd() {
    setState(() {
      _dragging = false;
      _selectedCells.clear();
    });
  }

  void _handleSuccessMatch() {
    _moves++;
    final cellsCount = _selectedCells.length;
    final pointsGained = cellsCount * 10 + (_targetSum * 2);

    setState(() {
      _score += pointsGained;
      _targetsCleared++;
      
      // Remove matches and let blocks fall down (Gravity mechanism)
      final sortedSelection = List<Point<int>>.from(_selectedCells)
        ..sort((a, b) => a.x.compareTo(b.x));

      for (var pt in sortedSelection) {
        _grid[pt.x][pt.y] = 0;
      }

      // Apply falling logic per column
      for (int c = 0; c < widget.gridSize; c++) {
        List<int> colValues = [];
        for (int r = 0; r < widget.gridSize; r++) {
          if (_grid[r][c] != 0) {
            colValues.add(_grid[r][c]);
          }
        }
        while (colValues.length < widget.gridSize) {
          colValues.insert(0, _rand.nextInt(9) + 1); // Insert at top
        }
        for (int r = 0; r < widget.gridSize; r++) {
          _grid[r][c] = colValues[r];
        }
      }

      _selectedCells.clear();
      _dragging = false;

      // Check game mode transitions
      if (widget.gameMode == 'classic' && _targetsCleared >= kClassicTargetCount) {
        _isGameWon = true;
        _isGameOver = true;
        _saveHighScore();
      } else {
        _generateNewTarget();
        if (widget.gameMode == 'timed') {
          _secondsLeft = min(99, _secondsLeft + (cellsCount * 2));
        }
      }
    });
  }

  void _handleFailMatch() {
    _moves++;
    setState(() {
      _selectedCells.clear();
      _dragging = false;
    });
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sum Exceeded Target!'),
        duration: Duration(milliseconds: 600),
      ),
    );
  }

  Future<void> _saveHighScore() async {
    await submitScore(highScoreLowerIsBetter ? _moves : _score);
  }

  Color _getTileColor(int val) {
    if (_palette.isEmpty) return Colors.grey;
    final idx = (val - 1) % _palette.length;
    return _palette[idx];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentSum = _currentSelectionSum;

    final isClassic = widget.gameMode == 'classic';
    final scoreText = '$_score';

    return BaseGameScreen(
      title: 'Sum Grid',
      gameId: 'sumgrid',
      gameConfig: {
        'gridSize': widget.gridSize,
        'gameMode': widget.gameMode,
        'targetMode': widget.targetMode,
      },
      highScoreLabel: isClassic ? 'Best Moves' : 'Best Score',
      highScoreValue: bestScore != null ? '$bestScore' : '-',
      currentScoreLabel: isClassic ? 'Moves' : 'Score',
      currentScoreValue: isClassic ? '$_moves' : scoreText,
      statusText: widget.gameMode == 'timed'
          ? 'Time: ${_secondsLeft}s'
          : 'Targets: $_targetsCleared/$kClassicTargetCount',
      isGameWon: _isGameWon,
      isGameOver: _isGameOver && !_isGameWon,
      victoryMessage: 'Target Sums Cleared in $_moves moves!',
      gameOverMessage: widget.gameMode == 'timed' ? 'Time Out! Final Score: $_score' : 'Game Over!',
      onReset: _initializeGame,
      isGameInProgress: isClassic ? (_moves > 0 && !_isGameOver) : !_isGameOver,
      topHudExtra: Column(
        children: [
          Text(
            'TARGET: $_targetSum',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Current Sum: $currentSum',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: currentSum > _targetSum ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
      child: Center(
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
            ),
            child: Builder(
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
                      _handleCellTouchStart(r, c);
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
                      _handleCellTouchUpdate(r, c);
                    }
                  },
                  onPanEnd: (_) => _handleCellTouchEnd(),
                  onTapDown: (details) {
                    final RenderBox? rBox = gridContext.findRenderObject() as RenderBox?;
                    if (rBox == null) return;
                    final local = rBox.globalToLocal(details.globalPosition);
                    final cellW = rBox.size.width / widget.gridSize;
                    final cellH = rBox.size.height / widget.gridSize;
                    final c = (local.dx / cellW).floor();
                    final r = (local.dy / cellH).floor();
                    if (r >= 0 && r < widget.gridSize && c >= 0 && c < widget.gridSize) {
                      _handleCellTouchStart(r, c);
                    }
                  },
                  onTapUp: (_) => _handleCellTouchEnd(),
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
                      final val = _grid[r][c];
                      final isSelected = _selectedCells.contains(Point(r, c));
                      final tileColor = _getTileColor(val);

                      return Semantics(label: 'Row ${r + 1}, column ${c + 1}, $val${isSelected ? ", selected" : ""}', button: true, onTap: () => _semanticSelect(r, c), customSemanticsActions: {const CustomSemanticsAction(label: 'Clear selection'): _semanticClear}, child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              tileColor,
                              tileColor.withValues(alpha: 0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected 
                                ? Colors.white 
                                : theme.colorScheme.outline.withValues(alpha: 0.2),
                            width: isSelected ? 3.0 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: tileColor.withValues(alpha: 0.6),
                                    blurRadius: 8.0,
                                    spreadRadius: 2.0,
                                  )
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4.0,
                                    offset: const Offset(2, 2),
                                  )
                                ],
                        ),
                        child: Center(
                          child: Text(
                            '$val',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: tileColor.computeLuminance() > 0.5 
                                  ? Colors.black 
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ));
                    },
                  ),
                );
              }
            ),
          ),
        ),
      ),
    );
  }
}
