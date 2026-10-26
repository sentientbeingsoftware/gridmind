import 'package:flutter/material.dart';
import 'base_game_screen.dart';
import 'mixins/config_high_score_mixin.dart';

/// Territory Game
///
/// A simple area‑control game where the player claims cells on a grid.
/// The goal is to claim a target number of cells (the "territory").
/// The game can be played in Zen (unlimited moves) or Challenge (move limit) mode.
class TerritoryGameScreen extends StatefulWidget {
  final int gridSize;
  final int targetArea;
  final String moveMode; // 'zen' or 'challenge'
  final int? maxMoves; // optional for challenge mode
  final bool testMode;

  const TerritoryGameScreen({
    super.key,
    required this.gridSize,
    required this.targetArea,
    required this.moveMode,
    this.maxMoves,
    this.testMode = false,
  });

  @override
  State<TerritoryGameScreen> createState() => _TerritoryGameScreenState();
}

class _TerritoryGameScreenState extends State<TerritoryGameScreen> with ConfigHighScoreMixin<TerritoryGameScreen> {
  @override
  String get highScoreGameId => 'territory';
  @override
  bool get highScoreLowerIsBetter => true; // fewest moves to claim the target
  @override
  Map<String, dynamic> get highScoreConfig => {
        'gridSize': widget.gridSize.toDouble(),
        'targetArea': widget.targetArea.toDouble(),
        'moveMode': widget.moveMode,
      };

  late Set<int> _claimed; // linear cell indices
  late int _moves;
  bool _gameOver = false;
  bool _won = false;

  @override
  void initState() {
    super.initState();
    _reset();
    _loadBest();
  }

  Future<void> _loadBest() async {
    final stored = await loadBestScore();
    if (mounted) setState(() => bestScore = stored);
  }

  void _reset() {
    setState(() {
      _claimed = {};
      _moves = 0;
      _gameOver = false;
      _won = false;
    });
  }

  void _handleTap(int index) {
    if (_gameOver) return;
    setState(() {
      // Every tap costs a move, including re-taps of a claimed cell, so
      // wasted taps count against the player (and can lose challenge mode).
      _claimed.add(index);
      _moves++;
      if (_claimed.length >= widget.targetArea) {
        _won = true;
        _gameOver = true;
      } else if (widget.moveMode == 'challenge' &&
          widget.maxMoves != null &&
          _moves >= widget.maxMoves!) {
        _gameOver = true;
      }
    });
    if (_won) submitScore(_moves);
  }

  Widget _buildGrid() {
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
        return GestureDetector(
          onTap: () => _handleTap(idx),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: claimed ? Colors.greenAccent : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseGameScreen(
      title: 'Territory',
      gameId: 'territory',
      gameConfig: {
        'gridSize': widget.gridSize,
        'targetArea': widget.targetArea,
        'moveMode': widget.moveMode,
        if (widget.maxMoves != null) 'maxMoves': widget.maxMoves,
      },
      currentScoreLabel: widget.moveMode == 'challenge' ? 'Moves' : 'Score',
      currentScoreValue: widget.moveMode == 'challenge' && widget.maxMoves != null
          ? '$_moves/${widget.maxMoves}'
          : '$_moves',
      highScoreValue: bestScore != null ? '$bestScore moves' : '--',
      statusText: 'Claimed ${_claimed.length}/${widget.targetArea}',
      isGameWon: _won,
      isGameOver: _gameOver && !_won,
      victoryMessage: 'Victory! Territory captured.',
      gameOverMessage: 'Game Over - No more moves.',
      onReset: _reset,
      isGameInProgress: _moves > 0 && !_gameOver,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.width * 0.9,
              child: _buildGrid(),
            ),
          ],
        ),
      ),
    );
  }
}
