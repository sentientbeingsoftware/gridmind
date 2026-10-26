import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../services/app_persistence_service.dart';
import 'mixins/config_high_score_mixin.dart';
import 'base_game_screen.dart';

class GridRunnerGameScreen extends StatefulWidget {
  final int gridSize;
  final String speed; // 'slow', 'normal', 'fast'
  final int gemCount;
  final bool testMode;
  final List<Point<int>>? testGems;
  final Point<int>? testStart;

  const GridRunnerGameScreen({
    super.key,
    required this.gridSize,
    required this.speed,
    required this.gemCount,
    this.testMode = false,
    this.testGems,
    this.testStart,
  });

  @override
  State<GridRunnerGameScreen> createState() => _GridRunnerGameScreenState();
}

class _GridRunnerGameScreenState extends State<GridRunnerGameScreen> with ConfigHighScoreMixin<GridRunnerGameScreen> {
  @override
  String get highScoreGameId => 'grid_runner';
  @override
  bool get highScoreLowerIsBetter => true;
  @override
  Map<String, dynamic> get highScoreConfig => {
        'gridSize': widget.gridSize.toDouble(),
        'speed': widget.speed,
        'gemCount': widget.gemCount.toDouble(),
      };
  final Random _rand = Random();

  late List<List<bool>> _trail;
  late List<Point<int>> _gems;
  late Point<int> _runner;
  Point<int> _direction = const Point(0, 0); // Start stationary until player selects direction

  int _moves = 0;
  bool _isGameOver = false;
  bool _isGameWon = false;

  Timer? _timer;
  List<Color> _palette = [];

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _getSpeedMs() {
    switch (widget.speed) {
      case 'slow':
        return 500;
      case 'fast':
        return 200;
      case 'normal':
      default:
        return 350;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_isGameOver || _isGameWon) return;

    _timer = Timer.periodic(Duration(milliseconds: _getSpeedMs()), (timer) {
      if (_direction.x == 0 && _direction.y == 0) return; // Wait for first input
      _tick();
    });
  }

  Future<void> _initializeGame() async {
    _timer?.cancel();

    // Initialize state variables synchronously to avoid LateInitializationError during the first frame build
    _trail = List.generate(
      widget.gridSize,
      (_) => List.generate(widget.gridSize, (_) => false),
    );

    if (widget.testMode) {
      _runner = widget.testStart ?? Point(widget.gridSize ~/ 2, widget.gridSize ~/ 2);
      _gems = widget.testGems != null ? List<Point<int>>.from(widget.testGems!) : [const Point(0, 0)];
    } else {
      // Pick center starting point
      _runner = Point(widget.gridSize ~/ 2, widget.gridSize ~/ 2);
      _gems = [];

      // Generate random unique gem positions (avoiding start point)
      int targetGems = min(widget.gemCount, widget.gridSize * widget.gridSize - 1);
      int gemAttempts = 0;
      while (_gems.length < targetGems && gemAttempts < 1000) {
        gemAttempts++;
        final gp = Point(_rand.nextInt(widget.gridSize), _rand.nextInt(widget.gridSize));
        if (gp != _runner && !_gems.contains(gp)) {
          _gems.add(gp);
        }
      }
    }

    _trail[_runner.x][_runner.y] = true;
    _direction = const Point(0, 0); // Stationary start
    _moves = 0;
    _isGameOver = false;
    _isGameWon = false;

    // Asynchronous loading of high score and palette config.
    // The widget can build safely now since all late fields are initialized.
    final colors = await AppPersistenceService.getPaletteForGame(colorCount: 5);
    final stored = await loadBestScore();
    // Starting the timer after dispose would leak a periodic timer.
    if (!mounted) return;

    setState(() {
      bestScore = stored;
      _palette = colors.isNotEmpty
          ? colors
          : [Colors.indigo, Colors.blue, Colors.teal, Colors.purple, Colors.pink];
    });

    _startTimer();
  }

  void _tick() {
    if (_isGameOver || _isGameWon) return;

    final nextPos = Point(_runner.x + _direction.x, _runner.y + _direction.y);

    // Collision check: boundary walls or self trail intersection
    if (nextPos.x < 0 ||
        nextPos.x >= widget.gridSize ||
        nextPos.y < 0 ||
        nextPos.y >= widget.gridSize ||
        _trail[nextPos.x][nextPos.y]) {
      _timer?.cancel();
      setState(() {
        _isGameOver = true;
      });
      return;
    }

    setState(() {
      _runner = nextPos;
      _trail[_runner.x][_runner.y] = true;
      _moves++;

      // Check if stepped on a gem
      if (_gems.contains(_runner)) {
        _gems.remove(_runner);
        if (_gems.isEmpty) {
          _timer?.cancel();
          _isGameWon = true;
          _saveHighScore();
        }
      }
    });
  }

  Future<void> _saveHighScore() async {
    await submitScore(_moves);
  }

  void _changeDirection(Point<int> newDir) {
    if (_isGameOver || _isGameWon) return;

    // Block 180 degree reverses when runner is moving
    if (_direction.x != 0 || _direction.y != 0) {
      if (newDir.x == -_direction.x && newDir.y == -_direction.y) {
        return;
      }
    }

    setState(() {
      _direction = newDir;
    });

    // Run first tick immediately to make input feel snappy!
    _tick();
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('How to Play Grid Runner'),
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
                  'Collect all glowing gems on the grid in as few moves as possible.',
                ),
                SizedBox(height: 12),
                Text(
                  'Rules:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '1. Use the directional D-pad controls below the board to select your direction.\n'
                  '2. The runner will move automatically in the selected direction.\n'
                  '3. You leave a trailing line behind you. Crossing your own trail or hitting the grid walls will cause a crash (Game Over!).\n'
                  '4. 180-degree reversals are blocked to prevent self-collision.',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeColor = _palette.isNotEmpty ? _palette[0] : theme.colorScheme.primary;

    return BaseGameScreen(
      title: 'Grid Runner',
      gameId: 'grid_runner',
      gameConfig: {
        'gridSize': widget.gridSize,
        'speed': widget.speed,
        'gemCount': widget.gemCount,
      },
      highScoreLabel: 'Best',
      highScoreValue: bestScore != null ? '$bestScore steps' : '--',
      currentScoreLabel: 'Steps',
      currentScoreValue: '$_moves',
      statusText: _direction.x == 0 && _direction.y == 0
          ? 'Tap D-pad arrow to start running!'
          : 'Gems left: ${_gems.length}',
      isGameWon: _isGameWon,
      isGameOver: _isGameOver && !_isGameWon,
      victoryMessage: 'Success! Solved in $_moves steps!',
      gameOverMessage: 'Crashed! Game Over.',
      onReset: _initializeGame,
      isGameInProgress: _moves > 0 && !_isGameOver,
      onHelp: _showHelpDialog,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 300,
              height: 300,
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
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
                itemBuilder: (context, index) {
                  final r = index ~/ widget.gridSize;
                  final c = index % widget.gridSize;
                  if (r >= _trail.length || c >= _trail[r].length) {
                    return const SizedBox();
                  }

                  final isRunner = _runner.x == r && _runner.y == c;
                  final isGem = _gems.contains(Point(r, c));
                  final isTrailed = _trail[r][c];

                  Color cellColor = Colors.transparent;
                  if (isRunner) {
                    cellColor = Colors.orangeAccent;
                  } else if (isGem) {
                    cellColor = Colors.transparent;
                  } else if (isTrailed) {
                    cellColor = themeColor.withValues(alpha: 0.4);
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: cellColor,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isRunner 
                            ? Colors.orange 
                            : (isTrailed ? themeColor.withValues(alpha: 0.2) : theme.colorScheme.outline.withValues(alpha: 0.05)),
                        width: isRunner ? 2.0 : 0.5,
                      ),
                    ),
                    child: isGem
                        ? Center(
                            child: Container(
                              width: widget.gridSize > 8 ? 8 : 12,
                              height: widget.gridSize > 8 ? 8 : 12,
                              decoration: const BoxDecoration(
                                color: Colors.amberAccent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber,
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : (isRunner
                            ? const Icon(Icons.circle, size: 10, color: Colors.white)
                            : null),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            // Arcaded D-pad below the board
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.keyboard_arrow_up),
                      onPressed: () => _changeDirection(const Point(-1, 0)),
                    ),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          icon: const Icon(Icons.keyboard_arrow_left),
                          onPressed: () => _changeDirection(const Point(0, -1)),
                        ),
                        const SizedBox(width: 48),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.keyboard_arrow_right),
                          onPressed: () => _changeDirection(const Point(0, 1)),
                        ),
                      ],
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.keyboard_arrow_down),
                      onPressed: () => _changeDirection(const Point(1, 0)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
