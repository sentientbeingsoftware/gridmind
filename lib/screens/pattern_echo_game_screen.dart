import '../utils/game_pause.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../services/app_persistence_service.dart';
import 'mixins/config_high_score_mixin.dart';
import 'base_game_screen.dart';

class PatternEchoGameScreen extends StatefulWidget {
  final int gridSize;
  final String transformationMode; // 'none', 'rotate', 'mirror', 'mixed'
  final String displayMode;        // 'mental' or 'visual'
  final int lives;
  final bool testMode;
  final List<Point<int>>? testPattern;
  final String? testTransformation;

  const PatternEchoGameScreen({
    super.key,
    required this.gridSize,
    required this.transformationMode,
    required this.displayMode,
    required this.lives,
    this.testMode = false,
    this.testPattern,
    this.testTransformation,
  });

  @override
  State<PatternEchoGameScreen> createState() => _PatternEchoGameScreenState();
}

class _PatternEchoGameScreenState extends State<PatternEchoGameScreen> with ConfigHighScoreMixin<PatternEchoGameScreen> {
  @override
  String get highScoreGameId => 'pattern_echo';
  @override
  bool get highScoreLowerIsBetter => false;
  @override
  Map<String, dynamic> get highScoreConfig => {
        'gridSize': widget.gridSize.toDouble(),
        'transformationMode': widget.transformationMode,
        'displayMode': widget.displayMode,
        'lives': widget.lives.toDouble(),
      };
  final Random _rand = Random();

  List<Point<int>> _targetPattern = [];
  final List<Point<int>> _selectedCells = [];
  final List<Point<int>> _wrongCells = [];

  int _score = 0;
  int _livesLeft = 3;
  int _patternLength = 3;

  bool _showingPattern = false;
  bool _isGameOver = false;
  bool _isGameWon = false;

  // Active transformation for the current round
  String _activeTransformation = 'none'; // 'none', 'rotate90', 'rotate180', 'rotate270', 'mirrorX', 'mirrorY'
  double _gridRotationTurns = 0.0;
  double _gridScaleX = 1.0;
  double _gridScaleY = 1.0;

  List<Color> _palette = [];

  @override
  void initState() {
    super.initState();
    _livesLeft = widget.lives;
    if (widget.testMode && widget.testPattern != null) {
      _palette = [Colors.amber, Colors.blue];
      bestScore = null;
      _score = 0;
      _livesLeft = widget.lives;
      _isGameOver = false;
      _isGameWon = false;
      _targetPattern = List.from(widget.testPattern!);
      _activeTransformation = widget.testTransformation ?? 'none';
      _showingPattern = false;
      if (widget.displayMode == 'visual') {
        switch (_activeTransformation) {
          case 'rotate90':
            _gridRotationTurns = 0.25;
            break;
          case 'rotate180':
            _gridRotationTurns = 0.50;
            break;
          case 'rotate270':
            _gridRotationTurns = 0.75;
            break;
          case 'mirrorX':
            _gridScaleX = -1.0;
            break;
          case 'mirrorY':
            _gridScaleY = -1.0;
            break;
        }
      }
    } else {
      _initializeGame();
    }
  }

  Future<void> _initializeGame() async {
    final colors = await AppPersistenceService.getPaletteForGame(colorCount: 4);
    final high = await loadBestScore();
    if (!mounted) return;

    if (widget.testMode && widget.testPattern != null) {
      return;
    }

    setState(() {
      _palette = colors.isNotEmpty ? colors : [Colors.amber, Colors.blue];
      bestScore = high;
      _score = 0;
      _livesLeft = widget.lives;
      _patternLength = 3;
      _isGameOver = false;
      _isGameWon = false;
    });

    _startNextRound();
  }

  void _startNextRound() {
    _selectedCells.clear();
    _wrongCells.clear();

    // 1. Choose a transformation for this round
    String trans = 'none';
    if (widget.testMode && widget.testTransformation != null) {
      trans = widget.testTransformation!;
    } else {
      if (widget.transformationMode == 'rotate') {
        const rotations = ['rotate90', 'rotate180', 'rotate270'];
        trans = rotations[_rand.nextInt(rotations.length)];
      } else if (widget.transformationMode == 'mirror') {
        const mirrors = ['mirrorX', 'mirrorY'];
        trans = mirrors[_rand.nextInt(mirrors.length)];
      } else if (widget.transformationMode == 'mixed') {
        const allTrans = ['rotate90', 'rotate180', 'rotate270', 'mirrorX', 'mirrorY', 'none'];
        trans = allTrans[_rand.nextInt(allTrans.length)];
      }
    }

    // 2. Generate random cell coordinates
    List<Point<int>> pattern = [];
    if (widget.testMode && widget.testPattern != null) {
      pattern = List.from(widget.testPattern!);
    } else {
      final allCells = <Point<int>>[];
      for (int r = 0; r < widget.gridSize; r++) {
        for (int c = 0; c < widget.gridSize; c++) {
          allCells.add(Point(r, c));
        }
      }
      allCells.shuffle(_rand);
      int targetLength = min(_patternLength, widget.gridSize * widget.gridSize - 1);
      pattern = allCells.sublist(0, targetLength);
    }

    setState(() {
      _targetPattern = pattern;
      _activeTransformation = trans;
      _showingPattern = true;

      // Reset visual transformations for the show phase
      _gridRotationTurns = 0.0;
      _gridScaleX = 1.0;
      _gridScaleY = 1.0;
    });

    // 3. Keep pattern visible for a duration, then hide it and apply visual transformation
    if (widget.testMode) {
      setState(() {
        _showingPattern = false;
        _applyVisualTransformation();
      });
    } else {
      Future.delayed(const Duration(milliseconds: 1800), () async {
        await GamePause.hold();
        if (!mounted) return;
        setState(() {
          _showingPattern = false;
          _applyVisualTransformation();
        });
      });
    }
  }

  void _applyVisualTransformation() {
    if (widget.displayMode != 'visual') return;

    setState(() {
      switch (_activeTransformation) {
        case 'rotate90':
          _gridRotationTurns = 0.25;
          break;
        case 'rotate180':
          _gridRotationTurns = 0.50;
          break;
        case 'rotate270':
          _gridRotationTurns = 0.75;
          break;
        case 'mirrorX':
          _gridScaleX = -1.0;
          break;
        case 'mirrorY':
          _gridScaleY = -1.0;
          break;
        default:
          _gridRotationTurns = 0.0;
          _gridScaleX = 1.0;
          _gridScaleY = 1.0;
      }
    });
  }

  Point<int> _transformCell(Point<int> cell) {
    if (widget.displayMode == 'visual') {
      return cell;
    }

    final n = widget.gridSize;
    switch (_activeTransformation) {
      case 'rotate90':
        return Point(cell.y, n - 1 - cell.x);
      case 'rotate180':
        return Point(n - 1 - cell.x, n - 1 - cell.y);
      case 'rotate270':
        return Point(n - 1 - cell.y, cell.x);
      case 'mirrorX':
        return Point(cell.x, n - 1 - cell.y);
      case 'mirrorY':
        return Point(n - 1 - cell.x, cell.y);
      default:
        return cell;
    }
  }

  List<Point<int>> get _transformedTargets {
    return _targetPattern.map((p) => _transformCell(p)).toList();
  }

  void _handleCellTap(int r, int c) {
    if (_showingPattern || _isGameOver || _isGameWon) return;
    final tapped = Point(r, c);

    if (_selectedCells.contains(tapped) || _wrongCells.contains(tapped)) return;

    final targets = _transformedTargets;

    setState(() {
      if (targets.contains(tapped)) {
        _selectedCells.add(tapped);

        if (_selectedCells.length == targets.length) {
          _score++;
          _patternLength++;
          _showRoundSuccess();
        }
      } else {
        _wrongCells.add(tapped);
        _livesLeft--;

        if (_livesLeft <= 0) {
          _isGameOver = true;
          _isGameWon = false;
          _saveHighScore();
        }
      }
    });
  }

  void _showRoundSuccess() {
    if (widget.testMode) {
      _startNextRound();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pattern Cleared! Level Up!'),
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

  String _getTransformationText() {
    switch (_activeTransformation) {
      case 'rotate90':
        return 'Rotate 90° Clockwise';
      case 'rotate180':
        return 'Rotate 180°';
      case 'rotate270':
        return 'Rotate 270° Clockwise';
      case 'mirrorX':
        return 'Mirror Horizontally';
      case 'mirrorY':
        return 'Mirror Vertically';
      default:
        return 'No Transformation';
    }
  }

  Color _getTileColor(int r, int c, Color offColor, Color themeColor) {
    final cell = Point(r, c);

    if (_showingPattern) {
      if (_targetPattern.contains(cell)) {
        return themeColor;
      }
    } else {
      if (_selectedCells.contains(cell)) {
        return Colors.green;
      }
      if (_wrongCells.contains(cell)) {
        return Colors.red;
      }
    }
    return offColor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeColor = _palette.isNotEmpty ? _palette[0] : theme.colorScheme.primary;
    final offColor = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);

    return BaseGameScreen(
      title: 'Pattern Echo',
      gameId: 'pattern_echo',
      gameConfig: {
        'gridSize': widget.gridSize,
        'transformationMode': widget.transformationMode,
        'displayMode': widget.displayMode,
        'lives': widget.lives,
      },
      highScoreLabel: 'Best',
      highScoreValue: bestScore != null ? '$bestScore pts' : '-',
      currentScoreLabel: 'Score',
      currentScoreValue: '$_score',
      statusText: _showingPattern ? 'MEMORIZE PATTERN' : 'RECREATE THE PATTERN',
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
          const SizedBox(height: 6),
          if (!_showingPattern && widget.transformationMode != 'none')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
              ),
              child: Text(
                '${widget.displayMode == 'mental' ? "MENTAL: " : "VISUAL: "} ${_getTransformationText()}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isGameOver) ...[
                Text(
                  'Final Score: $_score points!',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
              ],
              AspectRatio(
                aspectRatio: 1.0,
                child: AnimatedRotation(
                  turns: _gridRotationTurns,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOutBack,
                  child: AnimatedScale(
                    scale: 1.0,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOutBack,
                    child: Transform(
                      transform: Matrix4.diagonal3Values(_gridScaleX, _gridScaleY, 1.0),
                      alignment: Alignment.center,
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
                            final tileColor = _getTileColor(r, c, offColor, themeColor);
                            final isTargetInShow = _showingPattern && _targetPattern.contains(Point(r, c));

                            return Semantics(label: 'Row ${r + 1}, column ${c + 1}${isTargetInShow ? ", part of the pattern" : ""}${_selectedCells.contains(Point(r, c)) ? ", chosen" : ""}', button: true, child: GestureDetector(
                              onTap: () => _handleCellTap(r, c),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                                decoration: BoxDecoration(
                                  color: tileColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: (isTargetInShow || _selectedCells.contains(Point(r, c)) || _wrongCells.contains(Point(r, c)))
                                        ? Colors.white
                                        : theme.colorScheme.outline.withValues(alpha: 0.25),
                                    width: isTargetInShow ? 2.5 : 1.0,
                                  ),
                                  boxShadow: isTargetInShow
                                      ? [
                                          BoxShadow(
                                            color: themeColor.withValues(alpha: 0.5),
                                            blurRadius: 10.0,
                                            spreadRadius: 2.0,
                                          )
                                        ]
                                      : (_selectedCells.contains(Point(r, c))
                                          ? [
                                              const BoxShadow(
                                                color: Colors.green,
                                                blurRadius: 8.0,
                                                spreadRadius: 1.0,
                                              )
                                            ]
                                          : []),
                                ),
                              ),
                            ));
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
