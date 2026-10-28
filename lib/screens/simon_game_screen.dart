import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../models/pattern_speed.dart';
import '../services/game_effects.dart';
import '../services/app_persistence_service.dart';
import 'base_game_screen.dart';
import 'mixins/config_high_score_mixin.dart';

/// Main game screen for the Simon memory game
/// Implements the classic Simon pattern-matching gameplay where players
/// must remember and repeat increasingly longer sequences
class SimonGameScreen extends StatefulWidget {
  /// Number of buttons/squares in the game grid
  final int numberOfSquares;

  /// Speed at which the pattern sequence is displayed
  final PatternSpeed patternSpeed;

  /// Optional list of colors to use for testing, overriding the default palette
  final List<Color>? testColors;

  /// Whether to skip the initial delay when adding the first sequence element
  final bool skipInitialDelay;

  /// Whether to run in test mode (skip timers and update state immediately)
  final bool testMode;

  const SimonGameScreen({
    super.key,
    required this.numberOfSquares,
    required this.patternSpeed,
    this.testColors,
    this.skipInitialDelay = false,
    this.testMode = false,
  });

  @override
  State<SimonGameScreen> createState() => _SimonGameScreenState();
}

/// State class for the Simon game screen
/// Manages game logic, sequence generation, user input validation, and UI state
class _SimonGameScreenState extends State<SimonGameScreen> with ConfigHighScoreMixin<SimonGameScreen> {
  @override
  String get highScoreGameId => 'simon';
  @override
  bool get highScoreLowerIsBetter => false;
  @override
  Map<String, dynamic> get highScoreConfig => {
        'numberOfSquares': widget.numberOfSquares.toDouble(),
        'patternSpeed': widget.patternSpeed,
      };
  /// List of unique colors for each button in the game
  /// Generated dynamically based on the number of squares
  List<Color>? _colors;

  /// The sequence that the player must remember and repeat
  /// Each integer represents the index of a button in the grid
  final List<int> _sequence = [];

  /// The player's current input sequence
  /// Used to validate against the generated sequence
  final List<int> _userInput = [];

  /// Random number generator for sequence generation
  final Random _random = Random();

  /// Whether the game is currently waiting for player input
  /// Controls when the player can interact with buttons
  bool _waitingForInput = false;

  /// Index of the currently highlighted button (-1 if none)
  /// Used for visual feedback during sequence playback and player taps
  int _highlighted = -1;

  /// Timer for controlling individual button flash durations
  /// Ensures proper timing of visual feedback
  Timer? _flashTimer;

  /// Duration for how long each button flashes during sequence playback
  /// Set based on the selected pattern speed
  late Duration _sequenceFlashDuration;

  /// Delay between button flashes in the sequence
  /// Provides visual separation between sequence elements
  late Duration _betweenSequenceFlashDelay;

  /// Duration for player tap feedback
  /// Shorter than sequence flashes for responsive feel
  static const Duration _playerTapFlashDuration = Duration(milliseconds: 250);

  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    if (widget.testColors != null) {
      _colors = widget.testColors;
    } else {
      _initColors();
    }
    _setPatternTimings();
    _sequence.clear();
    _loadHighScore();
    if (widget.skipInitialDelay) {
      _addToSequence();
    } else {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _addToSequence();
        }
      });
    }
  }

  Future<void> _initColors() async {
    List<Color> palette = await AppPersistenceService.getPaletteForGame(colorCount: widget.numberOfSquares);
    if (!mounted) return;
    if (palette.length < widget.numberOfSquares) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough colors in palette. Using random colors.')),
      );
    }
    setState(() {
      _colors = palette;
    });
  }

  Future<void> _loadHighScore() async {
    final stored = await loadBestScore();
    if (mounted) {
      setState(() {
        bestScore = stored;
      });
    }
  }

  Future<void> _updateHighScoreIfNeeded() async {
    int currentScore = _sequence.isNotEmpty ? _sequence.length - 1 : 0;
    await submitScore(currentScore);
  }

  @override
  void dispose() {
    // Clean up timer to prevent memory leaks
    _flashTimer?.cancel();
    super.dispose();
  }

  /// Sets the timing parameters based on the selected pattern speed
  /// Slower speeds give players more time to observe the pattern
  void _setPatternTimings() {
    switch (widget.patternSpeed) {
      case PatternSpeed.slow:
        _sequenceFlashDuration = const Duration(milliseconds: 800);
        _betweenSequenceFlashDelay = const Duration(milliseconds: 400);
        break;
      case PatternSpeed.normal:
        _sequenceFlashDuration = const Duration(milliseconds: 500);
        _betweenSequenceFlashDelay = const Duration(milliseconds: 250);
        break;
      case PatternSpeed.fast:
        _sequenceFlashDuration = const Duration(milliseconds: 300);
        _betweenSequenceFlashDelay = const Duration(milliseconds: 150);
        break;
    }
  }

  /// Adds a new random button to the sequence
  /// Called when the player successfully completes the current sequence
  void _addToSequence() {
    if (!mounted) return;
    setState(() {
      // Add a random button index to the sequence
      _sequence.add(_random.nextInt(widget.numberOfSquares));
      // Clear player input for the new sequence
      _userInput.clear();
      // Set waiting state to false during sequence playback
      _waitingForInput = false;
    });
    // Play the updated sequence for the player
    _playSequence();
  }

  /// Flashes a specific button for a given duration
  /// Used for both sequence playback and player tap feedback
  Future<void> _flashSquare(
    int index,
    Duration duration, {
    bool playSound = false,
  }) async {
    if (!mounted) return;

    // Set the highlighted button
    setState(() {
      _highlighted = index;
    });

    if (playSound) GameEffects.instance.note(index);

    // Cancel any existing flash timer
    _flashTimer?.cancel();

    // Set timer to remove highlight after duration
    _flashTimer = Timer(duration, () {
      if (mounted) {
        setState(() {
          _highlighted = -1;
        });
      }
    });

    // Wait for the flash duration to complete
    await Future.delayed(duration);
  }

  /// Plays the current sequence for the player to observe
  /// Flashes each button in the sequence with appropriate timing
  Future<void> _playSequence() async {
    if (widget.testMode) {
      // Instantly show the sequence for tests, no timers
      setState(() {
        _waitingForInput = true;
        _highlighted = -1;
      });
      return;
    }
    // Initial delay before sequence starts
    await Future.delayed(_betweenSequenceFlashDelay);

    // Flash each button in the sequence
    for (int indexInSequence in _sequence) {
      if (!mounted) return;
      await _flashSquare(
        indexInSequence,
        _sequenceFlashDuration,
        playSound: true,
      );
      // Delay between sequence elements
      await Future.delayed(_betweenSequenceFlashDelay);
    }

    // Enable player input after sequence is complete
    if (!mounted) return;
    setState(() {
      _waitingForInput = true;
    });
  }

  /// Handles player taps on game buttons
  /// Validates input against the sequence and manages game progression
  void _handleTap(int index) {
    // Only accept input when waiting and no button is currently flashing
    if (!_waitingForInput ||
        (_highlighted != -1 && _flashTimer?.isActive == true) ||
        _gameOver) {
      return;
    }

    // Provide visual feedback for the tap
    _flashSquare(index, _playerTapFlashDuration, playSound: true);

    // Add the tap to player's input sequence
    _userInput.add(index);

    // Check if the tap matches the expected sequence element
    if (_userInput.last != _sequence[_userInput.length - 1]) {
      // Wrong input - game over
      setState(() {
        _gameOver = true;
        _waitingForInput = false;
      });
      _updateHighScoreIfNeeded();
      return;
    }

    // Check if the player has completed the current sequence
    if (_userInput.length == _sequence.length) {
      setState(() {
        _waitingForInput = false;
      });
      // Add a new element to the sequence after a delay
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _addToSequence();
        }
      });
    }
  }

  void _resetGame() {
    setState(() {
      _sequence.clear();
      _userInput.clear();
      _highlighted = -1;
      _waitingForInput = false;
      _gameOver = false;
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _addToSequence();
      }
    });
  }

  /// Returns a list of row lengths for a balanced grid layout
  /// Prefers equal number of tiles on top and bottom row when possible
  List<int> _getBalancedRowLengths(int total) {
    if (total <= 0) return [];
    // Try to split into 2 rows as evenly as possible
    int top = (total / 2).ceil();
    int bottom = total - top;
    if (bottom == 0) return [top];
    // For 3+ rows, generalize: minimize max-min row length
    // For now, just 2 rows for up to 8, 3 rows for 9+
    if (total <= 8) {
      return [top, bottom];
    } else {
      int perRow = (total / 3).floor();
      int rem = total - perRow * 3;
      List<int> rows = List.filled(3, perRow);
      for (int i = 0; i < rem; i++) {
        rows[i]++;
      }
      return rows;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_colors == null || _colors!.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate dynamic button size based on screen dimensions and grid layout
    // Uses square root to estimate optimal grid dimensions
    int crossAxisCount = sqrt(widget.numberOfSquares).ceil();
    double buttonSize =
        (screenWidth / crossAxisCount) -
        (16 * 1.5); // Account for margins and spacing

    // Clamp button size between minimum and maximum values for usability
    buttonSize = max(
      60, // Minimum button size for touch targets
      min(buttonSize, screenHeight * 0.15), // Maximum 15% of screen height
    );

    final score = _sequence.isNotEmpty ? _sequence.length - 1 : 0;

    return BaseGameScreen(
      title: 'Simon Game',
      gameId: 'simon',
      gameConfig: {
        'numberOfSquares': widget.numberOfSquares,
        'patternSpeed': widget.patternSpeed.toString().split('.').last,
      },
      highScoreLabel: 'Best',
      highScoreValue: bestScore?.toString() ?? '--',
      currentScoreLabel: 'Score',
      currentScoreValue: '$score',
      statusText: _waitingForInput
          ? "Your Turn"
          : (_sequence.isEmpty
              ? "Getting Ready..."
              : "Watch the Pattern"),
      isGameOver: _gameOver,
      gameOverMessage: 'Wrong move! Final score: $score',
      onReset: _resetGame,
      isGameInProgress: _sequence.isNotEmpty && !_gameOver,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Game button grid
              if (widget.numberOfSquares > 0 && _colors != null && _colors!.isNotEmpty)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: () {
                    final rowLengths = _getBalancedRowLengths(widget.numberOfSquares);
                    int colorIdx = 0;
                    return rowLengths.map((rowLen) {
                      final row = Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(rowLen, (i) {
                          int index = colorIdx + i;
                          Color color = _colors!.isNotEmpty && index < _colors!.length
                              ? _colors![index]
                              : Colors.grey;
                          if (_highlighted == index) {
                            color = Color.alphaBlend(
                              Colors.white.withValues(alpha: 0.6),
                              color,
                            );
                          }
                          return GestureDetector(
                            onTap: () => _handleTap(index),
                            child: Container(
                              width: buttonSize,
                              height: buttonSize,
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(
                                  widget.numberOfSquares > 6 ? 8 : 12,
                                ),
                                border: Border.all(
                                  color: _highlighted == index
                                      ? Colors.white70
                                      : Colors.black38,
                                  width: _highlighted == index ? 3 : 1.5,
                                ),
                                boxShadow: _highlighted == index
                                    ? [
                                        BoxShadow(
                                          color: _colors!.isNotEmpty && index < _colors!.length
                                              ? _colors![index].withValues(alpha: 0.5)
                                              : Colors.grey.withValues(alpha: 0.5),
                                          blurRadius: 10.0,
                                          spreadRadius: 1.0,
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 3.0,
                                          spreadRadius: 1.0,
                                          offset: const Offset(2, 2),
                                        ),
                                      ],
                              ),
                            ),
                          );
                        }),
                      );
                      colorIdx += rowLen;
                      return row;
                    }).toList();
                  }(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
