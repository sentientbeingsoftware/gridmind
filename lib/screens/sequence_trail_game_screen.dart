import '../utils/game_pause.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import '../services/app_persistence_service.dart';
import 'mixins/config_high_score_mixin.dart';
import 'base_game_screen.dart';

class SequenceTrailGameScreen extends StatefulWidget {
  final int gridSize;
  final double timeLimit; // Seconds per number
  final bool enableDecoys;
  final bool enableMoving;
  final int lives;
  final bool testMode;
  final List<int>? testLayout; // Flat layout: -1 for empty, numbers >= 1 for active targets, -2 for decoy
  final List<double>? testLifetimes;

  const SequenceTrailGameScreen({
    super.key,
    required this.gridSize,
    required this.timeLimit,
    required this.enableDecoys,
    required this.enableMoving,
    required this.lives,
    this.testMode = false,
    this.testLayout,
    this.testLifetimes,
  });

  @override
  State<SequenceTrailGameScreen> createState() => _SequenceTrailGameScreenState();
}

class _SequenceTrailGameScreenState extends State<SequenceTrailGameScreen> with ConfigHighScoreMixin<SequenceTrailGameScreen> {
  @override
  String get highScoreGameId => 'sequence_trail';
  @override
  bool get highScoreLowerIsBetter => false;
  @override
  Map<String, dynamic> get highScoreConfig => {
        'gridSize': widget.gridSize.toDouble(),
        'timeLimit': widget.timeLimit,
        'enableDecoys': widget.enableDecoys,
        'enableMoving': widget.enableMoving,
        'lives': widget.lives.toDouble(),
      };
  final Random _rand = Random();

  late List<int> _grid; // Grid representation: -1 for empty, values >= 1 for sequence targets, -2 for decoys
  late List<double> _lifetimes; // Floating remaining lifetimes [0.0..1.0]

  int _score = 0;
  int _livesLeft = 3;
  int _trailLength = 4;
  int _nextTargetNumber = 1;

  bool _isGameOver = false;
  bool _isGameWon = false;

  Timer? _tickTimer;
  Timer? _moveTimer;

  List<Color> _palette = [];

  @override
  void initState() {
    super.initState();
    _livesLeft = widget.lives;
    if (widget.testMode && widget.testLayout != null) {
      _palette = [Colors.indigo, Colors.blue];
      bestScore = null;
      _score = 0;
      _livesLeft = widget.lives;
      _trailLength = 3;
      _nextTargetNumber = 1;
      _grid = List.from(widget.testLayout!);
      _lifetimes = widget.testLifetimes != null 
          ? List.from(widget.testLifetimes!) 
          : List.generate(widget.gridSize * widget.gridSize, (_) => 1.0);
      _isGameOver = false;
      _isGameWon = false;
    } else {
      _grid = List.generate(widget.gridSize * widget.gridSize, (_) => -1);
      _lifetimes = List.generate(widget.gridSize * widget.gridSize, (_) => 1.0);
      _initializeGame();
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _moveTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeGame() async {
    if (widget.testMode && widget.testLayout != null) {
      _tickTimer?.cancel();
      _moveTimer?.cancel();
      setState(() {
        _palette = [Colors.indigo, Colors.blue];
        bestScore = null;
        _score = 0;
        _livesLeft = widget.lives;
        _trailLength = 3;
        _nextTargetNumber = 1;
        _grid = List.from(widget.testLayout!);
        _lifetimes = widget.testLifetimes != null 
            ? List.from(widget.testLifetimes!) 
            : List.generate(widget.gridSize * widget.gridSize, (_) => 1.0);
        _isGameOver = false;
        _isGameWon = false;
      });
      return;
    }

    final colors = await AppPersistenceService.getPaletteForGame(colorCount: 5);
    final high = await loadBestScore();
    if (!mounted) return;

    setState(() {
      _palette = colors.isNotEmpty ? colors : [Colors.indigo, Colors.blue, Colors.teal, Colors.purple, Colors.pink];
      bestScore = high;
      _score = 0;
      _livesLeft = widget.lives;
      _trailLength = 4;
      _isGameOver = false;
      _isGameWon = false;
    });

    _startNextRound();
  }

  void _startNextRound() {
    _tickTimer?.cancel();
    _moveTimer?.cancel();

    final size = widget.gridSize * widget.gridSize;
    List<int> grid = List.generate(size, (_) => -1);
    List<double> lifetimes = List.generate(size, (_) => 1.0);

    List<int> indices = List.generate(size, (i) => i);
    indices.shuffle(_rand);

    int actualTrailLength = min(_trailLength, size - 3);
    for (int i = 0; i < actualTrailLength; i++) {
      int cellIdx = indices[i];
      grid[cellIdx] = i + 1; // Numbers 1, 2, 3, ...
    }

    if (widget.enableDecoys) {
      int decoyCount = max(1, widget.gridSize - 1);
      for (int i = 0; i < decoyCount; i++) {
        int cellIdx = indices[actualTrailLength + i];
        grid[cellIdx] = -2;
      }
    }

    setState(() {
      _grid = grid;
      _lifetimes = lifetimes;
      _nextTargetNumber = 1;
    });

    _startTimers();
  }

  void _startTimers() {
    if (widget.testMode) return;

    _tickTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isGameOver || _isGameWon) {
        timer.cancel();
        return;
      }
      if (GamePause.isPaused) return;

      bool timeExpired = false;
      setState(() {
        for (int i = 0; i < _grid.length; i++) {
          if (_grid[i] >= 1) {
            _lifetimes[i] -= 0.1 / widget.timeLimit;
            if (_lifetimes[i] <= 0.0) {
              _lifetimes[i] = 0.0;
              timeExpired = true;
            }
          }
        }
      });

      if (timeExpired) {
        _handleTimeExpired();
      }
    });

    if (widget.enableMoving) {
      _moveTimer = Timer.periodic(const Duration(milliseconds: 1600), (timer) {
        if (_isGameOver || _isGameWon) {
          timer.cancel();
          return;
        }
        if (GamePause.isPaused) return;
        _teleportActiveNumbers();
      });
    }
  }

  void _teleportActiveNumbers() {
    setState(() {
      final size = _grid.length;
      List<int> activeValues = [];
      List<double> activeLifetimes = [];

      for (int i = 0; i < size; i++) {
        if (_grid[i] != -1) {
          activeValues.add(_grid[i]);
          activeLifetimes.add(_lifetimes[i]);
          _grid[i] = -1;
        }
      }

      List<int> availableIndices = List.generate(size, (i) => i);
      availableIndices.shuffle(_rand);

      for (int i = 0; i < activeValues.length; i++) {
        int targetIdx = availableIndices[i];
        _grid[targetIdx] = activeValues[i];
        _lifetimes[targetIdx] = activeLifetimes[i];
      }
    });
  }

  void _handleTimeExpired() {
    _tickTimer?.cancel();
    _moveTimer?.cancel();

    setState(() {
      _livesLeft--;
      if (_livesLeft <= 0) {
        _isGameOver = true;
        _saveHighScore();
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Time Expired! Restarting Round.'),
            duration: Duration(milliseconds: 800),
          ),
        );
        _startNextRound();
      }
    });
  }

  void _handleCellTap(int idx) {
    if (_isGameOver || _isGameWon) return;

    final cellVal = _grid[idx];
    if (cellVal == -1) return;

    if (cellVal == -2) {
      _handleIncorrectTap();
      return;
    }

    setState(() {
      if (cellVal == _nextTargetNumber) {
        _grid[idx] = -1; // Remove from board
        _nextTargetNumber++;

        int maxTarget = _grid.reduce(max);
        if (maxTarget == -1) {
          _score++;
          _trailLength++;
          _showRoundSuccess();
        }
      } else {
        _handleIncorrectTap();
      }
    });
  }

  void _handleIncorrectTap() {
    setState(() {
      _livesLeft--;
      if (_livesLeft <= 0) {
        _isGameOver = true;
        _tickTimer?.cancel();
        _moveTimer?.cancel();
        _saveHighScore();
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wrong Selection! Penalty.'),
            duration: Duration(milliseconds: 700),
          ),
        );
      }
    });
  }

  void _showRoundSuccess() {
    _tickTimer?.cancel();
    _moveTimer?.cancel();

    if (widget.testMode) {
      _startNextRound();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sequence Cleared! Speeding Up.'),
        duration: Duration(milliseconds: 800),
        backgroundColor: Colors.green,
      ),
    );
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      _startNextRound();
    });
  }

  Future<void> _saveHighScore() async {
    await submitScore(_score);
  }

  Color _getTileColor(int val, Color themeColor) {
    if (val == -2) {
      return Colors.red.shade400;
    }
    if (val == _nextTargetNumber) {
      return themeColor;
    }
    return themeColor.withValues(alpha: 0.6);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeColor = _palette.isNotEmpty ? _palette[0] : theme.colorScheme.primary;
    final offBg = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);

    return BaseGameScreen(
      title: 'Sequence Trail',
      gameId: 'sequence_trail',
      gameConfig: {
        'gridSize': widget.gridSize,
        'timeLimit': widget.timeLimit,
        'enableDecoys': widget.enableDecoys,
        'enableMoving': widget.enableMoving,
        'lives': widget.lives,
      },
      highScoreLabel: 'Best',
      highScoreValue: bestScore != null ? '$bestScore pts' : '-',
      currentScoreLabel: 'Score',
      currentScoreValue: '$_score',
      statusText: 'Current Target: $_nextTargetNumber',
      isGameOver: _isGameOver,
      gameOverMessage: 'Game Over!',
      onReset: _initializeGame,
      isGameInProgress: (_score > 0 || _livesLeft < widget.lives) && !_isGameOver,
      topHudExtra: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Lives: ${"❤️" * _livesLeft}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
      child: Column(
        children: [
          if (_isGameOver) ...[
            Text(
              'Score achieved: $_score points!',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  margin: const EdgeInsets.all(16.0),
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: offBg,
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
                      final val = _grid[index];
                      final lifetime = _lifetimes[index];

                      if (val == -1) {
                        return Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        );
                      }

                      final isNext = val == _nextTargetNumber;
                      final tileColor = _getTileColor(val, themeColor);

                      return Semantics(label: 'Row ${index ~/ widget.gridSize + 1}, column ${index % widget.gridSize + 1}, number $val${isNext ? ", next" : ""}', button: true, child: GestureDetector(
                        onTap: () => _handleCellTap(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: tileColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isNext ? Colors.white : Colors.transparent,
                              width: isNext ? 2.5 : 1.0,
                            ),
                          ),
                          child: Stack(
                            children: [
                              if (val >= 1)
                                Positioned.fill(
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: CircularProgressIndicator(
                                      value: lifetime,
                                      strokeWidth: 3.5,
                                      color: Colors.white24,
                                      backgroundColor: Colors.transparent,
                                    ),
                                  ),
                                ),
                              Center(
                                child: Text(
                                  val == -2 ? 'X' : '$val',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: tileColor.computeLuminance() > 0.5 
                                        ? Colors.black87 
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ));
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
