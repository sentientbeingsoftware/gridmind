import 'package:flutter/material.dart';
import 'dart:math';
import '../services/app_persistence_service.dart';
import 'mixins/config_high_score_mixin.dart';
import 'base_game_screen.dart';

class MissingPieceGameScreen extends StatefulWidget {
  final int gridSize;
  final String contentType; // 'numbers' or 'colors'
  final int initialHiddenCount;
  final int lives;
  final bool testMode;
  final List<String>? testValues; // Deterministic values: e.g. ["1","2",...] or Color hex strings
  final List<int>? testHiddenIndices;

  const MissingPieceGameScreen({
    super.key,
    required this.gridSize,
    required this.contentType,
    required this.initialHiddenCount,
    required this.lives,
    this.testMode = false,
    this.testValues,
    this.testHiddenIndices,
  });

  @override
  State<MissingPieceGameScreen> createState() => _MissingPieceGameScreenState();
}

class _MissingPieceGameScreenState extends State<MissingPieceGameScreen> with ConfigHighScoreMixin<MissingPieceGameScreen> {
  @override
  String get highScoreGameId => 'missing_piece';
  @override
  bool get highScoreLowerIsBetter => false;
  @override
  Map<String, dynamic> get highScoreConfig => {
        'gridSize': widget.gridSize.toDouble(),
        'contentType': widget.contentType,
        'initialHiddenCount': widget.initialHiddenCount.toDouble(),
        'lives': widget.lives.toDouble(),
      };
  final Random _rand = Random();

  late List<String> _gridValues; // Flat list of cell values representing the grid
  final List<int> _hiddenIndices = [];
  final Map<int, String> _playerAnswers = {}; // Map of index -> player's selected value

  int _score = 0;
  int _livesLeft = 3;
  int _hiddenCount = 1;
  int _activeHiddenIndex = -1; // Currently selected hidden cell to fill

  bool _showingPattern = true;
  bool _isGameOver = false;
  bool _isGameWon = false;

  List<Color> _palette = [];
  final List<String> _numberOptions = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];

  @override
  void initState() {
    super.initState();
    _livesLeft = widget.lives;
    _hiddenCount = widget.initialHiddenCount;
    // Pre-initialize grid list synchronously to avoid LateInitializationError
    _gridValues = List.generate(
      widget.gridSize * widget.gridSize,
      (_) => widget.contentType == 'numbers' ? '1' : '0',
    );
    if (widget.testMode && widget.testValues != null && widget.testHiddenIndices != null) {
      _palette = [Colors.red, Colors.green, Colors.blue, Colors.orange];
      bestScore = null;
      _score = 0;
      _livesLeft = widget.lives;
      _hiddenCount = widget.initialHiddenCount;
      _gridValues = List.from(widget.testValues!);
      _hiddenIndices.clear();
      _hiddenIndices.addAll(widget.testHiddenIndices!);
      _playerAnswers.clear();
      _activeHiddenIndex = _hiddenIndices.first;
      _showingPattern = false;
      _isGameOver = false;
      _isGameWon = false;
    } else {
      _initializeGame();
    }
  }

  Future<void> _initializeGame() async {
    final colors = await AppPersistenceService.getPaletteForGame(colorCount: widget.contentType == 'colors' ? 8 : 4);
    final high = await loadBestScore();
    if (!mounted) return;

    if (widget.testMode && widget.testValues != null && widget.testHiddenIndices != null) {
      return;
    }

    setState(() {
      _palette = colors.isNotEmpty ? colors : [Colors.red, Colors.green, Colors.blue, Colors.orange, Colors.purple, Colors.teal, Colors.pink, Colors.amber];
      bestScore = high;
      _score = 0;
      _livesLeft = widget.lives;
      _hiddenCount = widget.initialHiddenCount;
      _isGameOver = false;
      _isGameWon = false;
    });

    _startNextRound();
  }

  void _startNextRound() {
    _playerAnswers.clear();
    _hiddenIndices.clear();

    final size = widget.gridSize * widget.gridSize;

    // 1. Generate grid values
    List<String> values = [];
    if (widget.contentType == 'numbers') {
      values = List.generate(size, (_) => (_rand.nextInt(9) + 1).toString());
    } else {
      values = List.generate(size, (_) => _rand.nextInt(_palette.length).toString());
    }

    // 2. Decide hidden cell indices
    List<int> availableIndices = List.generate(size, (i) => i);
    availableIndices.shuffle(_rand);
    int targetHidden = min(_hiddenCount, size - 1);
    _hiddenIndices.addAll(availableIndices.sublist(0, targetHidden));
    _activeHiddenIndex = _hiddenIndices.first;

    setState(() {
      _gridValues = values;
      _showingPattern = true;
    });

    // 3. Display pattern for 3 seconds, then hide the pieces
    if (widget.testMode) {
      setState(() {
        _showingPattern = false;
      });
    } else {
      double durationMs = 2000.0 + widget.gridSize * 400.0;
      Future.delayed(Duration(milliseconds: durationMs.round()), () {
        if (!mounted) return;
        setState(() {
          _showingPattern = false;
        });
      });
    }
  }

  void _handleCellTap(int idx) {
    if (_showingPattern || _isGameOver || _isGameWon) return;
    if (_hiddenIndices.contains(idx)) {
      setState(() {
        _activeHiddenIndex = idx;
      });
    }
  }

  void _selectChoiceValue(String value) {
    if (_activeHiddenIndex == -1 || _showingPattern || _isGameOver || _isGameWon) return;

    final targetVal = _gridValues[_activeHiddenIndex];

    setState(() {
      if (value == targetVal) {
        _playerAnswers[_activeHiddenIndex] = value;

        final remaining = _hiddenIndices.where((idx) => !_playerAnswers.containsKey(idx)).toList();
        if (remaining.isNotEmpty) {
          _activeHiddenIndex = remaining.first;
        } else {
          _activeHiddenIndex = -1;
          _score++;
          if (_score % 2 == 0) {
            _hiddenCount = min(_hiddenCount + 1, (widget.gridSize * widget.gridSize) ~/ 2);
          }
          _showRoundSuccess();
        }
      } else {
        _wrongChoice();
      }
    });
  }

  void _wrongChoice() {
    _livesLeft--;
    if (_livesLeft <= 0) {
      _isGameOver = true;
      _isGameWon = false;
      _saveHighScore();
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect Value! Try again.'),
          duration: Duration(milliseconds: 600),
        ),
      );
    }
  }

  void _showRoundSuccess() {
    if (widget.testMode) {
      _startNextRound();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Excellent Memory! Next Level.'),
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

  Color _getColorFromValue(String val) {
    int? idx = int.tryParse(val);
    if (idx != null && idx >= 0 && idx < _palette.length) {
      return _palette[idx];
    }
    return Colors.grey;
  }

  Widget _buildCellContent(int idx, Color themeColor) {
    final val = _gridValues[idx];
    final isHidden = _hiddenIndices.contains(idx);
    final hasAnswer = _playerAnswers.containsKey(idx);

    if (_showingPattern) {
      if (widget.contentType == 'numbers') {
        return Center(
          child: Text(
            val,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        );
      } else {
        return Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _getColorFromValue(val),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }
    } else {
      if (isHidden) {
        if (hasAnswer) {
          if (widget.contentType == 'numbers') {
            return Center(
              child: Text(
                val,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            );
          } else {
            return Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _getColorFromValue(val),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green, width: 3),
              ),
            );
          }
        } else {
          final isActive = _activeHiddenIndex == idx;
          return Center(
            child: Text(
              '?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isActive ? themeColor : Colors.grey,
              ),
            ),
          );
        }
      } else {
        if (widget.contentType == 'numbers') {
          return Center(
            child: Text(
              val,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
          );
        } else {
          return Container(
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _getColorFromValue(val).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeColor = _palette.isNotEmpty ? _palette[0] : theme.colorScheme.primary;
    final size = widget.gridSize * widget.gridSize;

    return BaseGameScreen(
      title: 'Missing Piece',
      gameId: 'missing_piece',
      gameConfig: {
        'gridSize': widget.gridSize,
        'contentType': widget.contentType,
        'initialHiddenCount': widget.initialHiddenCount,
        'lives': widget.lives,
      },
      highScoreLabel: 'Best',
      highScoreValue: bestScore != null ? '$bestScore pts' : '-',
      currentScoreLabel: 'Score',
      currentScoreValue: '$_score',
      statusText: _showingPattern ? 'MEMORIZE THE GRID' : 'IDENTIFY MISSING PIECES',
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
                    itemCount: size,
                    itemBuilder: (context, index) {
                      final isHidden = _hiddenIndices.contains(index);
                      final hasAnswer = _playerAnswers.containsKey(index);
                      final isActive = _activeHiddenIndex == index;

                      Color tileBg = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
                      if (!_showingPattern && isHidden) {
                        if (hasAnswer) {
                          tileBg = Colors.green.withValues(alpha: 0.05);
                        } else {
                          tileBg = isActive 
                              ? themeColor.withValues(alpha: 0.15) 
                              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2);
                        }
                      }

                      return GestureDetector(
                        onTap: () => _handleCellTap(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: tileBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (!_showingPattern && isHidden && isActive)
                                  ? themeColor
                                  : theme.colorScheme.outline.withValues(alpha: 0.25),
                              width: (!_showingPattern && isHidden && isActive) ? 2.5 : 1.0,
                            ),
                          ),
                          child: _buildCellContent(index, themeColor),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          if (!_showingPattern && !_isGameOver)
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Select value for active (?) cell:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  if (widget.contentType == 'numbers')
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: _numberOptions.map((opt) {
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _selectChoiceValue(opt),
                          child: Text(opt),
                        );
                      }).toList(),
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: List.generate(_palette.length, (idx) {
                        final colorVal = _palette[idx];
                        return GestureDetector(
                          onTap: () => _selectChoiceValue(idx.toString()),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: colorVal,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: colorVal.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                ],
              ),
            ),
          if (_showingPattern)
            const SizedBox(height: 110)
          else
            const SizedBox(height: 0),
        ],
      ),
    );
  }
}
