import 'dart:math';
import 'package:flutter/material.dart';
import 'mixins/config_high_score_mixin.dart';
import 'base_game_screen.dart';

/// Grid Miner Game
///
/// A premium exploration and resource-collection roguelike grid game.
/// The player controls a miner on a grid to collect resources under energy and move limits.
class GridMinerGameScreen extends StatefulWidget {
  final int gridSize;
  final String difficulty; // 'easy', 'medium', 'hard'
  final String moveMode; // 'zen' or 'challenge'
  final int? maxMoves; // optional override
  final bool testMode;

  const GridMinerGameScreen({
    super.key,
    required this.gridSize,
    required this.difficulty,
    required this.moveMode,
    this.maxMoves,
    this.testMode = false,
  });

  @override
  State<GridMinerGameScreen> createState() => _GridMinerGameScreenState();
}

class _GridMinerGameScreenState extends State<GridMinerGameScreen> with ConfigHighScoreMixin<GridMinerGameScreen> {
  @override
  String get highScoreGameId => 'grid_miner';
  @override
  bool get highScoreLowerIsBetter => false;
  @override
  Map<String, dynamic> get highScoreConfig => {
        'gridSize': widget.gridSize.toDouble(),
        'difficulty': widget.difficulty,
        'moveMode': widget.moveMode,
      };
  final Random _rand = Random();

  // Grid states
  late List<List<String>> _board; // 'E' (empty), 'R' (resource), 'H' (hazard), 'P' (energy pack)
  late List<List<bool>> _explored;
  late int _playerRow;
  late int _playerCol;

  late int _energy;
  late int _score; // resources collected
  late int _totalResources;
  late int _moves;
  late int _moveLimit;

  // What the last move uncovered: 'R', 'H', 'P' or 'E'; shown as a banner
  // and as an icon on the cell until the next move.
  String? _lastEvent;
  int? _lastEventRow;
  int? _lastEventCol;
  int _lastEventAmount = 0;

  bool _isGameOver = false;
  bool _isGameWon = false;

  // History stack for undo moves
  final List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _board = [];
    _explored = [];
    _playerRow = 0;
    _playerCol = 0;
    _energy = 100;
    _score = 0;
    _totalResources = 0;
    _moves = 0;
    _moveLimit = 0;
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    final stored = await loadBestScore();
    if (!mounted) return;

    // Initialize board
    final size = widget.gridSize;
    final board = List.generate(size, (_) => List.generate(size, (_) => 'E'));
    final explored = List.generate(size, (_) => List.generate(size, (_) => false));

    // Player starts at bottom-left corner
    final startRow = size - 1;
    const startCol = 0;
    explored[startRow][startCol] = true;

    int resourcesCount = 0;

    if (widget.testMode) {
      // Deterministic board for tests
      board[0][1] = 'R'; // Resource at top-middle
      board[0][2] = 'H'; // Hazard at top-right
      board[1][0] = 'P'; // Energy pack at middle-left
      board[2][2] = 'R'; // Resource at bottom-right
      resourcesCount = 2;
    } else {
      // Procedural generation
      // Probabilities based on difficulty
      double resourceProb = 0.25;
      double hazardProb = widget.difficulty == 'easy'
          ? 0.10
          : (widget.difficulty == 'medium' ? 0.18 : 0.25);
      double energyProb = widget.difficulty == 'easy'
          ? 0.15
          : (widget.difficulty == 'medium' ? 0.12 : 0.08);

      for (int r = 0; r < size; r++) {
        for (int c = 0; c < size; c++) {
          if (r == startRow && c == startCol) continue; // Start cell is empty

          final roll = _rand.nextDouble();
          if (roll < resourceProb) {
            board[r][c] = 'R';
            resourcesCount++;
          } else if (roll < resourceProb + hazardProb) {
            board[r][c] = 'H';
          } else if (roll < resourceProb + hazardProb + energyProb) {
            board[r][c] = 'P';
          }
        }
      }

      // Safeguard: Ensure there is at least 1 resource on board
      if (resourcesCount == 0) {
        board[0][size - 1] = 'R';
        resourcesCount = 1;
      }
    }

    // Set move limit: Easy gets more moves, Hard gets fewer
    int limit = widget.maxMoves ?? (size * size * (widget.difficulty == 'easy' ? 2.0 : 1.5)).round();

    setState(() {
      _board = board;
      _explored = explored;
      _playerRow = startRow;
      _playerCol = startCol;
      _energy = 100;
      _score = 0;
      _totalResources = resourcesCount;
      _moves = 0;
      _moveLimit = limit;
      bestScore = stored;
      _isGameOver = false;
      _isGameWon = false;
      _history.clear();
      _lastEvent = null;
      _lastEventRow = null;
      _lastEventCol = null;
    });
  }

  void _saveSnapshot() {
    final exploredCopy = List.generate(
      widget.gridSize,
      (r) => List<bool>.from(_explored[r]),
    );
    final boardCopy = List.generate(
      widget.gridSize,
      (r) => List<String>.from(_board[r]),
    );

    _history.add({
      'playerRow': _playerRow,
      'playerCol': _playerCol,
      'explored': exploredCopy,
      'board': boardCopy,
      'energy': _energy,
      'score': _score,
      'moves': _moves,
      'isGameOver': _isGameOver,
      'isGameWon': _isGameWon,
      'lastEvent': _lastEvent,
      'lastEventRow': _lastEventRow,
      'lastEventCol': _lastEventCol,
      'lastEventAmount': _lastEventAmount,
    });
  }

  void _undo() {
    if (_history.isEmpty || _isGameOver || _isGameWon) return;

    setState(() {
      final snap = _history.removeLast();
      _playerRow = snap['playerRow'] as int;
      _playerCol = snap['playerCol'] as int;
      _explored = snap['explored'] as List<List<bool>>;
      _board = snap['board'] as List<List<String>>;
      _energy = snap['energy'] as int;
      _score = snap['score'] as int;
      _moves = snap['moves'] as int;
      _isGameOver = snap['isGameOver'] as bool;
      _isGameWon = snap['isGameWon'] as bool;
      _lastEvent = snap['lastEvent'] as String?;
      _lastEventRow = snap['lastEventRow'] as int?;
      _lastEventCol = snap['lastEventCol'] as int?;
      _lastEventAmount = snap['lastEventAmount'] as int;
    });
  }

  bool _isAdjacent(int r, int c) {
    return (r - _playerRow).abs() + (c - _playerCol).abs() == 1;
  }

  void _moveMiner(int targetRow, int targetCol) async {
    if (_isGameOver || _isGameWon) return;
    if (!_isAdjacent(targetRow, targetCol)) return;

    _saveSnapshot();

    final cellContent = _board[targetRow][targetCol];

    int energyCost = widget.difficulty == 'easy'
        ? 4
        : (widget.difficulty == 'medium' ? 6 : 8);

    setState(() {
      _playerRow = targetRow;
      _playerCol = targetCol;
      _explored[targetRow][targetCol] = true;
      _moves++;

      // Manage energy (Zen mode does not consume energy)
      if (widget.moveMode == 'challenge') {
        _energy = max(0, _energy - energyCost);
      }

      _lastEvent = cellContent;
      _lastEventRow = targetRow;
      _lastEventCol = targetCol;
      _lastEventAmount = 0;

      // Process cell contents
      if (cellContent == 'R') {
        _score++;
        _board[targetRow][targetCol] = 'E'; // Clear item
      } else if (cellContent == 'H') {
        if (widget.moveMode == 'challenge') {
          _energy = max(0, _energy - 20); // Extra hazard damage
          _lastEventAmount = -20;
        }
        _board[targetRow][targetCol] = 'E'; // Trigger hazard, then empty
      } else if (cellContent == 'P') {
        if (widget.moveMode == 'challenge') {
          _energy = min(100, _energy + 30); // Collect power cell
          _lastEventAmount = 30;
        }
        _board[targetRow][targetCol] = 'E'; // Empty cell
      }

      // Check win/loss triggers
      if (_score >= _totalResources) {
        _isGameWon = true;
      } else if (widget.moveMode == 'challenge') {
        if (_energy <= 0 || _moves >= _moveLimit) {
          _isGameOver = true;
        }
      }
    });

    if (_isGameWon || _isGameOver) {
      await submitScore(_score);
    }
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case 'R':
        return Icons.diamond;
      case 'H':
        return Icons.local_fire_department;
      default:
        return Icons.bolt;
    }
  }

  Color _eventColor(String type) {
    switch (type) {
      case 'R':
        return Colors.amber;
      case 'H':
        return Colors.deepOrange;
      default:
        return Colors.greenAccent;
    }
  }

  String _eventText() {
    final challenge = widget.moveMode == 'challenge';
    switch (_lastEvent) {
      case 'R':
        return 'Resource collected! +1';
      case 'H':
        return challenge ? 'Hazard! -20 energy' : 'Hazard! (no damage in Zen)';
      case 'P':
        return challenge ? 'Energy pack! +30 energy' : 'Energy pack! (not needed in Zen)';
      default:
        return 'Empty cell';
    }
  }

  Widget _buildEventBanner(ThemeData theme) {
    final type = _lastEvent;
    return SizedBox(
      height: 28,
      child: type == null
          ? const SizedBox.shrink()
          : Row(
              key: const ValueKey('grid-miner-event'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (type != 'E') ...[
                  Icon(_eventIcon(type), size: 18, color: _eventColor(type)),
                  const SizedBox(width: 6),
                ],
                Text(
                  _eventText(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: type == 'E' ? null : _eventColor(type),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Dynamic stats formatting
    final moveInfo = widget.moveMode == 'challenge'
        ? '$_moves/$_moveLimit'
        : '$_moves (Zen)';

    return BaseGameScreen(
      title: 'Grid Miner',
      gameId: 'grid_miner',
      gameConfig: {
        'gridSize': widget.gridSize,
        'difficulty': widget.difficulty,
        'moveMode': widget.moveMode,
        if (widget.maxMoves != null) 'maxMoves': widget.maxMoves,
      },
      highScoreLabel: 'Best Score',
      highScoreValue: bestScore?.toString() ?? '--',
      currentScoreLabel: 'Score',
      currentScoreValue: '$_score/$_totalResources',
      statusText: widget.moveMode == 'challenge' ? '⚡ Energy: $_energy%' : 'Unlimited Energy (Zen)',
      statusTextColor: widget.moveMode == 'challenge'
          ? (_energy > 50
              ? Colors.greenAccent
              : (_energy > 20 ? Colors.orangeAccent : Colors.redAccent))
          : theme.colorScheme.primary,
      isGameWon: _isGameWon,
      isGameOver: _isGameOver,
      victoryMessage: 'Victory! All resources collected.',
      gameOverMessage: _energy <= 0 ? 'Out of Energy!' : 'Out of Moves!',
      onReset: _initializeGame,
      onUndo: _history.isNotEmpty ? _undo : null,
      isGameInProgress: _moves > 0 && !_isGameOver && !_isGameWon,
      topHudExtra: widget.moveMode == 'challenge'
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _energy / 100,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: _energy > 50
                      ? Colors.green
                      : (_energy > 20 ? Colors.orange : Colors.red),
                ),
              ),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Moves: $moveInfo',
              style: theme.textTheme.titleMedium,
            ),
          ),
          _buildEventBanner(theme),
          Container(
            width: 320,
            height: 320,
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
            ),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: widget.gridSize,
                mainAxisSpacing: 4.0,
                crossAxisSpacing: 4.0,
              ),
              itemCount: widget.gridSize * widget.gridSize,
              itemBuilder: (context, index) {
                final r = index ~/ widget.gridSize;
                final c = index % widget.gridSize;

                if (_board.isEmpty ||
                    r >= _board.length ||
                    c >= _board[r].length ||
                    r >= _explored.length ||
                    c >= _explored[r].length) {
                  return const SizedBox();
                }

                final isPlayerHere = _playerRow == r && _playerCol == c;
                final isLastEventCell = _lastEvent != null &&
                    _lastEvent != 'E' &&
                    _lastEventRow == r &&
                    _lastEventCol == c;
                final isExplored = _explored[r][c];
                final type = _board[r][c];

                // Render styles based on state
                Color cellColor = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
                Widget? contentWidget;

                if (!isExplored) {
                  // Shrouded fog of war
                  cellColor = Colors.grey.shade900;
                  contentWidget = Icon(
                    Icons.help_outline,
                    size: widget.gridSize > 5 ? 16 : 24,
                    color: Colors.white24,
                  );
                } else {
                  if (type == 'R') {
                    cellColor = Colors.amber.shade700;
                    contentWidget = Icon(
                      Icons.diamond,
                      size: widget.gridSize > 5 ? 18 : 26,
                      color: Colors.white,
                    );
                  } else if (type == 'H') {
                    cellColor = Colors.red.shade900;
                    contentWidget = Icon(
                      Icons.local_fire_department,
                      size: widget.gridSize > 5 ? 18 : 26,
                      color: Colors.orangeAccent,
                    );
                  } else if (type == 'P') {
                    cellColor = Colors.green.shade800;
                    contentWidget = Icon(
                      Icons.bolt,
                      size: widget.gridSize > 5 ? 18 : 26,
                      color: Colors.white,
                    );
                  } else {
                    // Empty explored cell
                    cellColor = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8);
                  }
                }

                return Semantics(
label: 'Row ${r + 1}, column ${c + 1}, ${isPlayerHere ? "you are here" : !isExplored ? "unexplored" : type == "R" ? "resource" : type == "H" ? "hazard" : type == "P" ? "energy pack" : "empty"}',
button: true,
onTap: () => _moveMiner(r, c),
excludeSemantics: true,
child: GestureDetector(
                  onTap: () => _moveMiner(r, c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: cellColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isPlayerHere
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withValues(alpha: 0.15),
                        width: isPlayerHere ? 3.0 : 1.0,
                      ),
                    ),
                    child: Center(
                      child: isPlayerHere
                          ? Stack(
                              alignment: Alignment.center,
                              children: [
                                if (isLastEventCell)
                                  Icon(
                                    _eventIcon(_lastEvent!),
                                    size: widget.gridSize > 5 ? 26 : 38,
                                    color: _eventColor(_lastEvent!).withValues(alpha: 0.55),
                                  ),
                                Icon(
                                  Icons.engineering,
                                  size: widget.gridSize > 5 ? 20 : 28,
                                  color: theme.colorScheme.primary,
                                ),
                              ],
                            )
                          : contentWidget,
                    ),
                  ),
                ),
);
              },
            ),
          ),
        ],
      ),
    );
  }
}
