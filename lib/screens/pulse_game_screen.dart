import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'base_game_screen.dart';
import 'mixins/config_high_score_mixin.dart';

/// Pulse Game
///
/// A rhythmic tapping game where a "pulse" travels across a grid.
/// The player must tap the highlighted cell exactly when the pulse
/// reaches it. The pulse moves at a configurable speed. The game
/// ends when the player makes a mistake or successfully taps a target
/// number of pulses.
class PulseGameScreen extends StatefulWidget {
  final int gridSize;
  final String speed; // 'slow', 'normal', 'fast'
  final bool testMode;
  final List<List<bool>>? testPattern; // optional deterministic pattern for tests

  const PulseGameScreen({
    super.key,
    required this.gridSize,
    required this.speed,
    this.testMode = false,
    this.testPattern,
  });

  @override
  State<PulseGameScreen> createState() => _PulseGameScreenState();
}

class _PulseGameScreenState extends State<PulseGameScreen> with ConfigHighScoreMixin<PulseGameScreen> {
  @override
  String get highScoreGameId => 'pulse';
  @override
  bool get highScoreLowerIsBetter => false;
  @override
  Map<String, dynamic> get highScoreConfig => {
        'gridSize': widget.gridSize.toDouble(),
        'speed': widget.speed,
      };

  late int _gridSize;
  late Duration _tickDuration;
  late Timer _timer;
  int _currentIndex = 0; // linear index of highlighted cell
  int _score = 0;
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    _gridSize = widget.gridSize;
    _tickDuration = _durationFromSpeed(widget.speed);
    _startTimer();
    _loadBest();
  }

  Future<void> _loadBest() async {
    final stored = await loadBestScore();
    if (mounted) setState(() => bestScore = stored);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Duration _durationFromSpeed(String speed) {
    switch (speed) {
      case 'slow':
        return const Duration(milliseconds: 800);
      case 'fast':
        return const Duration(milliseconds: 300);
      case 'normal':
      default:
        return const Duration(milliseconds: 500);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(_tickDuration, (_) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % (_gridSize * _gridSize);
      });
    });
  }

  void _handleTap(int index) {
    if (_gameOver) return;
    if (index == _currentIndex) {
      // correct tap
      setState(() {
        _score++;
        // Immediately move to next cell to give feedback
        _currentIndex = (_currentIndex + 1) % (_gridSize * _gridSize);
      });
    } else {
      // mistake – game over
      setState(() {
        _gameOver = true;
        _timer.cancel();
      });
      submitScore(_score);
    }
  }

  Widget _buildGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _gridSize,
        childAspectRatio: 1.0,
      ),
      itemCount: _gridSize * _gridSize,
      itemBuilder: (context, index) {
        final isActive = index == _currentIndex;
        return GestureDetector(
          onTap: () => _handleTap(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isActive ? Colors.orangeAccent : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Colors.orangeAccent.withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
          ),
        );
      },
    );
  }

  void _resetGame() {
    setState(() {
      _score = 0;
      _currentIndex = 0;
      _gameOver = false;
    });
    _timer.cancel();
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return BaseGameScreen(
      title: 'Pulse',
      gameId: 'pulse',
      gameConfig: {
        'gridSize': widget.gridSize,
        'speed': widget.speed,
      },
      highScoreValue: bestScore?.toString() ?? '--',
      currentScoreLabel: 'Score',
      currentScoreValue: '$_score',
      isGameOver: _gameOver,
      gameOverMessage: 'Game Over! Final Score: $_score',
      onReset: _resetGame,
      isGameInProgress: _score > 0 && !_gameOver,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: LayoutBuilder(builder: (context, box) {
                // Square, limited by both width and height (wide windows are short).
                final side = min(MediaQuery.of(context).size.width * 0.9, box.maxHeight);
                return SizedBox(width: side, height: side, child: _buildGrid());
              }),
            ),
          ],
        ),
      ),
    );
  }
}
