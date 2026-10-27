import 'dart:math';
import 'package:flutter/material.dart';
import 'base_game_screen.dart';
import 'mixins/config_high_score_mixin.dart';

/// Territory Game
///
/// Expand your territory from a starting cell across weighted grid cells
/// (values 1-3). You may only claim cells orthogonally adjacent to your
/// existing territory. Reach the target score in as few moves as possible
/// (or before running out of moves in Challenge mode).
class TerritoryGameScreen extends StatefulWidget {
  final int gridSize;
  final int targetArea;
  final String moveMode; // 'zen' or 'challenge'
  final int? maxMoves; // optional override for challenge mode
  final bool testMode;
  final List<int>? testValues;

  const TerritoryGameScreen({
    super.key,
    required this.gridSize,
    required this.targetArea,
    required this.moveMode,
    this.maxMoves,
    this.testMode = false,
    this.testValues,
  });

  @override
  State<TerritoryGameScreen> createState() => _TerritoryGameScreenState();
}

class _TerritoryGameScreenState extends State<TerritoryGameScreen>
    with ConfigHighScoreMixin<TerritoryGameScreen> {
  @override
  String get highScoreGameId => 'territory';
  @override
  bool get highScoreLowerIsBetter => true; // fewest moves to reach target
  @override
  Map<String, dynamic> get highScoreConfig => {
        'gridSize': widget.gridSize.toDouble(),
        'targetArea': widget.targetArea.toDouble(),
        'moveMode': widget.moveMode,
      };

  final Random _rand = Random();
  late List<int> _values;
  late Set<int> _claimed; // linear cell indices
  late int _score;
  late int _targetScore;
  late int _moves;
  int? _effectiveMaxMoves;
  bool _gameOver = false;
  bool _won = false;

  @override
  void initState() {
    super.initState();
    _reset(initial: true);
    _loadBest();
  }

  Future<void> _loadBest() async {
    final stored = await loadBestScore();
    if (mounted) setState(() => bestScore = stored);
  }

  void _reset({bool initial = false}) {
    final total = widget.gridSize * widget.gridSize;
    List<int> values;
    if (widget.testMode && widget.testValues != null && widget.testValues!.length == total) {
      values = List<int>.from(widget.testValues!);
    } else if (widget.testMode) {
      values = List<int>.generate(total, (i) => (i % 3) + 1);
    } else {
      values = List<int>.generate(total, (_) => _rand.nextInt(3) + 1);
    }

    final totalBoardSum = values.fold<int>(0, (a, b) => a + b);
    final maxAchievable = max(1, totalBoardSum - values[0]);
    final clampedTarget = widget.targetArea.clamp(1, maxAchievable);

    int? moveCap;
    if (widget.moveMode == 'challenge') {
      final maxCells = max(1, total - 1);
      final defaultCap = ((clampedTarget + 1) ~/ 2 + 2).clamp(1, maxCells);
      moveCap = (widget.maxMoves ?? defaultCap).clamp(1, maxCells);
    }

    void apply() {
      _values = values;
      _claimed = {0}; // start with top-left cell in territory
      _score = 0;
      _targetScore = clampedTarget;
      _moves = 0;
      _effectiveMaxMoves = moveCap;
      _gameOver = false;
      _won = false;
    }

    if (initial) {
      apply();
    } else {
      setState(apply);
    }
  }

  bool _isAdjacentToClaimed(int index) {
    if (_claimed.contains(index)) return false;
    final r = index ~/ widget.gridSize;
    final c = index % widget.gridSize;
    for (final claimedIdx in _claimed) {
      final cr = claimedIdx ~/ widget.gridSize;
      final cc = claimedIdx % widget.gridSize;
      if ((r - cr).abs() + (c - cc).abs() == 1) return true;
    }
    return false;
  }

  void _handleTap(int index) {
    if (_gameOver) return;
    if (!_isAdjacentToClaimed(index)) return;

    setState(() {
      _claimed.add(index);
      _score += _values[index];
      _moves++;
      final allClaimed = _claimed.length >= widget.gridSize * widget.gridSize;
      if (_score >= _targetScore) {
        _won = true;
        _gameOver = true;
      } else if (allClaimed ||
          (widget.moveMode == 'challenge' &&
              _effectiveMaxMoves != null &&
              _moves >= _effectiveMaxMoves!)) {
        _gameOver = true;
      }
    });
    if (_won) submitScore(_moves);
  }

  void _showHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.teal),
            SizedBox(width: 8),
            Expanded(child: Text('How to Play Territory')),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Goal:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Expand your territory to reach the target value in as few moves as possible.'),
              SizedBox(height: 12),
              Text('Rules:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '1. Your territory starts at the top-left corner (★).\n'
                '2. You may only claim cells orthogonally adjacent (highlighted) to your territory.\n'
                '3. Each cell adds its value (1–3) to your captured total.\n'
                '4. In Challenge Mode, reach the target value before running out of moves.',
              ),
            ],
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

  Widget _buildGrid(ThemeData theme) {
    final total = widget.gridSize * widget.gridSize;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.gridSize,
        childAspectRatio: 1.0,
      ),
      itemCount: total,
      itemBuilder: (context, idx) {
        final claimed = _claimed.contains(idx);
        final frontier = _isAdjacentToClaimed(idx);
        final val = _values[idx];
        return GestureDetector(
          onTap: () => _handleTap(idx),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: claimed
                  ? Colors.greenAccent.shade400
                  : frontier
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
              border: frontier
                  ? Border.all(color: theme.colorScheme.primary, width: 2)
                  : null,
            ),
            child: Center(
              child: Text(
                idx == 0 ? '★' : '$val',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: widget.gridSize > 5 ? 16 : 20,
                  color: claimed
                      ? Colors.black87
                      : frontier
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BaseGameScreen(
      title: 'Territory',
      gameId: 'territory',
      gameConfig: {
        'gridSize': widget.gridSize,
        'targetArea': widget.targetArea,
        'moveMode': widget.moveMode,
        if (_effectiveMaxMoves != null) 'maxMoves': _effectiveMaxMoves,
      },
      currentScoreLabel: widget.moveMode == 'challenge' ? 'Moves' : 'Score',
      currentScoreValue: widget.moveMode == 'challenge' && _effectiveMaxMoves != null
          ? '$_moves/$_effectiveMaxMoves'
          : '$_moves',
      highScoreValue: bestScore != null ? '$bestScore moves' : '--',
      statusText: 'Captured $_score/$_targetScore',
      isGameWon: _won,
      isGameOver: _gameOver && !_won,
      victoryMessage: 'Victory! Territory captured.',
      gameOverMessage: 'Game Over - No more moves.',
      onReset: _reset,
      onHelp: _showHelpDialog,
      isGameInProgress: _moves > 0 && !_gameOver,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: min(MediaQuery.of(context).size.width * 0.9, 320),
              height: min(MediaQuery.of(context).size.width * 0.9, 320),
              child: _buildGrid(theme),
            ),
          ],
        ),
      ),
    );
  }
}
