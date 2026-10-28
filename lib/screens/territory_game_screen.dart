import 'dart:math';
import 'package:flutter/material.dart';
import 'base_game_screen.dart';
import 'mixins/config_high_score_mixin.dart';

/// Territory Game
///
/// Expand your territory from a starting cell across weighted grid cells
/// (values 1-3). You may only claim cells orthogonally adjacent to your
/// existing territory. Land EXACTLY on the target score in as few moves as
/// possible (overshooting busts). Hidden traps (negative cells) and an
/// optional rival add friction.
class TerritoryGameScreen extends StatefulWidget {
  final int gridSize;
  final int targetArea;
  final String moveMode; // 'zen' or 'challenge'
  final int? maxMoves; // optional override for challenge mode
  final String traps; // 'off' | 'low' | 'high'
  final bool rival;
  final bool testMode;
  final List<int>? testValues; // negative entries are traps

  const TerritoryGameScreen({
    super.key,
    required this.gridSize,
    required this.targetArea,
    required this.moveMode,
    this.maxMoves,
    this.traps = 'off',
    this.rival = false,
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
        'traps': widget.traps,
        'rival': widget.rival,
      };

  final Random _rand = Random();
  late List<int> _values; // real values; negative = trap
  late List<int> _shown; // what unclaimed cells display (traps get a decoy)
  late Set<int> _claimed; // linear cell indices
  late Set<int> _rivalCells;
  ({Set<int> claimed, Set<int> rival, int score, int moves})? _prev;
  late int _score;
  late int _targetScore;
  late int _moves;
  int? _effectiveMaxMoves;
  bool _gameOver = false;
  bool _won = false;
  bool _bust = false;

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
    final trapChance = switch (widget.traps) { 'low' => 0.05, 'high' => 0.1, _ => 0.0 };
    List<int> values;
    if (widget.testMode && widget.testValues != null && widget.testValues!.length == total) {
      values = List<int>.from(widget.testValues!);
    } else if (widget.testMode) {
      values = List<int>.generate(total, (i) => (i % 3) + 1);
    } else {
      values = List<int>.generate(
          total,
          (i) => i != 0 && _rand.nextDouble() < trapChance
              ? -(_rand.nextInt(2) + 1)
              : _rand.nextInt(3) + 1);
    }
    final shown = [for (final v in values) v < 0 ? _rand.nextInt(3) + 1 : v];

    final target = widget.testMode ? widget.targetArea : _reachableTarget(values, widget.targetArea);

    int? moveCap;
    if (widget.moveMode == 'challenge') {
      final maxCells = max(1, total - 1);
      final defaultCap = ((target + 1) ~/ 2 + 2).clamp(1, maxCells);
      moveCap = (widget.maxMoves ?? defaultCap).clamp(1, maxCells);
    }

    void apply() {
      _values = values;
      _shown = shown;
      _claimed = {0}; // start with top-left cell in territory
      _rivalCells = widget.rival ? {total - 1} : {};
      _prev = null;
      _bust = false;
      _score = 0;
      _targetScore = target;
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

  bool _touches(Set<int> cells, int index) {
    if (cells.contains(index)) return false;
    final r = index ~/ widget.gridSize;
    final c = index % widget.gridSize;
    for (final other in cells) {
      if ((r - other ~/ widget.gridSize).abs() + (c - other % widget.gridSize).abs() == 1) return true;
    }
    return false;
  }

  bool _isAdjacentToClaimed(int index) =>
      _touches(_claimed, index) && !_rivalCells.contains(index);

  /// Grows random connected sets from the start and returns the reachable
  /// total closest to [want], so an exact-match win always exists (without
  /// the rival, who may block it).
  int _reachableTarget(List<int> v, int want) {
    final total = v.length;
    int? best;
    for (var trial = 0; trial < 20; trial++) {
      final owned = {0};
      var sum = 0;
      while (owned.length < total) {
        final frontier = [for (var i = 0; i < total; i++) if (_touches(owned, i)) i];
        final pick = frontier[_rand.nextInt(frontier.length)];
        owned.add(pick);
        sum += v[pick];
        if (sum >= 1 && (best == null || (sum - want).abs() < (best - want).abs())) best = sum;
      }
    }
    return best ?? max(1, want);
  }

  void _rivalMove() {
    final total = widget.gridSize * widget.gridSize;
    final options = [
      for (var i = 0; i < total; i++)
        if (!_claimed.contains(i) && _touches(_rivalCells, i)) i
    ]..shuffle(_rand);
    if (options.isEmpty) return;
    // Greedy on the displayed (decoy-including) value, like a player would.
    options.sort((a, b) => _shown[b].compareTo(_shown[a]));
    _rivalCells.add(options.first);
  }

  void _undo() {
    final p = _prev;
    if (p == null || _gameOver) return;
    setState(() {
      _claimed = {...p.claimed};
      _rivalCells = {...p.rival};
      _score = p.score;
      _moves = p.moves;
      _prev = null;
    });
  }

  void _handleTap(int index) {
    if (_gameOver) return;
    if (!_isAdjacentToClaimed(index)) return;
    final total = widget.gridSize * widget.gridSize;

    setState(() {
      _prev = (claimed: {..._claimed}, rival: {..._rivalCells}, score: _score, moves: _moves);
      _claimed.add(index);
      _score += _values[index];
      _moves++;
      if (_score == _targetScore) {
        _won = true;
        _gameOver = true;
      } else if (_score > _targetScore) {
        _bust = true;
        _gameOver = true;
      } else {
        if (widget.rival) _rivalMove();
        final stuck = !List.generate(total, (i) => i).any(_isAdjacentToClaimed);
        if (stuck ||
            (widget.moveMode == 'challenge' &&
                _effectiveMaxMoves != null &&
                _moves >= _effectiveMaxMoves!)) {
          _gameOver = true;
        }
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
              Text('Land EXACTLY on the target value in as few moves as possible. Going over busts you.'),
              SizedBox(height: 12),
              Text('Rules:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '1. Your territory starts at the top-left corner (★).\n'
                '2. You may only claim cells orthogonally adjacent (highlighted) to your territory.\n'
                '3. Each cell adds its value (1–3) to your captured total.\n'
                '4. Some cells are hidden traps that subtract 1–2 when claimed (they show a fake value until then).\n'
                '5. If the Rival is on, it claims a cell (red) after each of your moves, starting from the opposite corner.\n'
                '6. Undo reverts your last move. In Challenge Mode, hit the target before running out of moves.',
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
        final rivalOwned = _rivalCells.contains(idx);
        final val = claimed ? _values[idx] : _shown[idx];
        return GestureDetector(
          onTap: () => _handleTap(idx),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: rivalOwned
                  ? Colors.redAccent.shade100
                  : claimed
                  ? (val < 0 ? Colors.orangeAccent.shade200 : Colors.greenAccent.shade400)
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
                idx == 0 ? '★' : rivalOwned ? '' : '$val',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: widget.gridSize > 8 ? 12 : widget.gridSize > 5 ? 16 : 20,
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
        'traps': widget.traps,
        'rival': widget.rival,
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
      onUndo: _undo,
      gameOverMessage: _bust ? 'Bust! You went over the target.' : 'Game Over - No more moves.',
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
