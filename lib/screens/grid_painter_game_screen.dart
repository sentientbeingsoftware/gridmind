import 'package:flutter/material.dart';
import 'dart:math';
import '../services/app_persistence_service.dart';
import 'mixins/config_high_score_mixin.dart';
import 'base_game_screen.dart';

/// Preset Blueprint representation
class Blueprint {
  final String name;
  final List<List<bool>> pattern;
  Blueprint(this.name, this.pattern);
}

/// Dynamic preset library for different grid sizes
class GridPainterBlueprints {
  static final Map<int, List<Blueprint>> presets = {
    3: [
      Blueprint('Cross', [
        [true, false, true],
        [false, true, false],
        [true, false, true],
      ]),
      Blueprint('Box', [
        [true, true, true],
        [true, false, true],
        [true, true, true],
      ]),
      Blueprint('Arrow', [
        [false, true, false],
        [true, true, true],
        [false, true, false],
      ]),
    ],
    4: [
      Blueprint('Checkers', [
        [true, false, true, false],
        [false, true, false, true],
        [true, false, true, false],
        [false, true, false, true],
      ]),
      Blueprint('Diamond', [
        [false, true, true, false],
        [true, false, false, true],
        [true, false, false, true],
        [false, true, true, false],
      ]),
      Blueprint('Smile', [
        [true, false, false, true],
        [false, false, false, false],
        [true, false, false, true],
        [false, true, true, false],
      ]),
    ],
    5: [
      Blueprint('Heart', [
        [false, true, false, true, false],
        [true, true, true, true, true],
        [true, true, true, true, true],
        [false, true, true, true, false],
        [false, false, true, false, false],
      ]),
      Blueprint('Space Invader', [
        [true, false, false, false, true],
        [false, true, false, true, false],
        [true, true, true, true, true],
        [false, true, true, true, false],
        [true, false, true, false, true],
      ]),
      Blueprint('Tree', [
        [false, false, true, false, false],
        [false, true, true, true, false],
        [true, true, true, true, true],
        [false, false, true, false, false],
        [false, false, true, false, false],
      ]),
      Blueprint('House', [
        [false, false, true, false, false],
        [false, true, true, true, false],
        [true, true, true, true, true],
        [true, false, true, false, true],
        [true, true, true, true, true],
      ]),
    ],
    6: [
      Blueprint('Star', [
        [false, false, true, true, false, false],
        [false, true, true, true, true, false],
        [true, true, true, true, true, true],
        [false, true, true, true, true, false],
        [false, false, true, true, false, false],
        [false, true, false, false, true, false],
      ]),
      Blueprint('Anchor', [
        [false, false, true, true, false, false],
        [false, false, true, true, false, false],
        [true, false, true, true, false, true],
        [true, true, true, true, true, true],
        [false, true, true, true, true, false],
        [false, false, true, true, false, false],
      ]),
      Blueprint('Smile 6x6', [
        [false, true, false, false, true, false],
        [false, true, false, false, true, false],
        [false, false, false, false, false, false],
        [true, false, false, false, false, true],
        [false, true, true, true, true, false],
        [false, false, false, false, false, false],
      ]),
    ]
  };
}

enum BrushMode { draw, erase, navigate }

class GridPainterGameScreen extends StatefulWidget {
  final int gridSize;
  final String gameMode; // 'show' or 'picross'
  final String moveMode; // 'zen' or 'challenge'
  final bool testMode;
  final List<List<bool>>? testBlueprint;

  const GridPainterGameScreen({
    super.key,
    required this.gridSize,
    required this.gameMode,
    required this.moveMode,
    this.testMode = false,
    this.testBlueprint,
  });

  @override
  State<GridPainterGameScreen> createState() => _GridPainterGameScreenState();
}

class _GridPainterGameScreenState extends State<GridPainterGameScreen> with ConfigHighScoreMixin<GridPainterGameScreen> {
  @override
  String get highScoreGameId => 'grid_painter';
  @override
  bool get highScoreLowerIsBetter => true;
  @override
  Map<String, dynamic> get highScoreConfig => {
        'gridSize': widget.gridSize.toDouble(),
        'gameMode': widget.gameMode,
        'moveMode': widget.moveMode,
      };
  final Random _rand = Random();

  late List<List<bool>> _grid; // Active player board
  late List<List<bool>> _targetBlueprint; // The layout target
  String _blueprintName = 'Custom Art';

  int _moves = 0;
  int _moveLimit = 0;

  int _brushRow = 0;
  int _brushCol = 0;
  BrushMode _brushMode = BrushMode.draw;

  bool _isGameOver = false;
  bool _isGameWon = false;

  List<Color> _palette = [];
  late List<List<int>> _rowClues;
  late List<List<int>> _colClues;

  @override
  void initState() {
    super.initState();
    if (widget.testMode && widget.testBlueprint != null) {
      _palette = [Colors.indigo, Colors.blue];
      bestScore = null;
      _moves = 0;
      _brushRow = 0;
      _brushCol = 0;
      _brushMode = BrushMode.draw;
      _grid = List.generate(widget.gridSize, (_) => List.generate(widget.gridSize, (_) => false));
      _targetBlueprint = widget.testBlueprint!;
      _rowClues = _calculateCluesForPattern(_targetBlueprint);
      _colClues = _calculateCluesForPattern(_transposePattern(_targetBlueprint));
      _moveLimit = (widget.gridSize * widget.gridSize * 1.6).round() + 5;
      _isGameOver = false;
      _isGameWon = false;
    } else {
      _grid = List.generate(widget.gridSize, (_) => List.generate(widget.gridSize, (_) => false));
      _targetBlueprint = List.generate(widget.gridSize, (_) => List.generate(widget.gridSize, (_) => false));
      _rowClues = List.generate(widget.gridSize, (_) => [0]);
      _colClues = List.generate(widget.gridSize, (_) => [0]);
      _initializeGame();
    }
  }

  Future<void> _initializeGame() async {
    if (widget.testMode && widget.testBlueprint != null) {
      setState(() {
        _palette = [Colors.indigo, Colors.blue];
        bestScore = null;
        _moves = 0;
        _brushRow = 0;
        _brushCol = 0;
        _brushMode = BrushMode.draw;
        _grid = List.generate(widget.gridSize, (_) => List.generate(widget.gridSize, (_) => false));
        _targetBlueprint = widget.testBlueprint!;
        _rowClues = _calculateCluesForPattern(_targetBlueprint);
        _colClues = _calculateCluesForPattern(_transposePattern(_targetBlueprint));
        _moveLimit = (widget.gridSize * widget.gridSize * 1.6).round() + 5;
        _isGameOver = false;
        _isGameWon = false;
      });
      return;
    }

    final colors = await AppPersistenceService.getPaletteForGame(colorCount: 5);
    final stored = await loadBestScore();
    if (!mounted) return;

    List<List<bool>> targetPattern;
    String name = 'Procedural Art';
    final presets = GridPainterBlueprints.presets[widget.gridSize];
    if (presets != null && presets.isNotEmpty) {
      final selected = presets[_rand.nextInt(presets.length)];
      targetPattern = List.generate(widget.gridSize, (r) => List.from(selected.pattern[r]));
      name = selected.name;
    } else {
      targetPattern = _generateProceduralBlueprint(widget.gridSize);
    }

    setState(() {
      _palette = colors.isNotEmpty ? colors : [Colors.indigo, Colors.blue, Colors.teal, Colors.purple, Colors.pink];
      bestScore = stored;
      _blueprintName = name;
      _moves = 0;
      _brushRow = 0;
      _brushCol = 0;
      _brushMode = BrushMode.draw;
      _grid = List.generate(widget.gridSize, (_) => List.generate(widget.gridSize, (_) => false));
      _targetBlueprint = targetPattern;
      _rowClues = _calculateCluesForPattern(_targetBlueprint);
      _colClues = _calculateCluesForPattern(_transposePattern(_targetBlueprint));
      
      _moveLimit = (widget.gridSize * widget.gridSize * 1.6).round() + 5;
      
      _isGameOver = false;
      _isGameWon = false;
    });
  }

  List<List<bool>> _generateProceduralBlueprint(int size) {
    List<List<bool>> pattern = List.generate(size, (_) => List.generate(size, (_) => false));
    int targetPainted = (size * size * (0.35 + _rand.nextDouble() * 0.25)).round();
    int count = 0;
    int attempts = 0;
    while (count < targetPainted && attempts < 1000) {
      attempts++;
      int r = _rand.nextInt(size);
      int c = _rand.nextInt(size);
      if (!pattern[r][c]) {
        pattern[r][c] = true;
        count++;
      }
    }
    return pattern;
  }

  List<List<int>> _calculateCluesForPattern(List<List<bool>> pattern) {
    List<List<int>> clues = [];
    for (int r = 0; r < pattern.length; r++) {
      List<int> rowClue = [];
      int currentRun = 0;
      for (int c = 0; c < pattern[r].length; c++) {
        if (pattern[r][c]) {
          currentRun++;
        } else {
          if (currentRun > 0) {
            rowClue.add(currentRun);
            currentRun = 0;
          }
        }
      }
      if (currentRun > 0) {
        rowClue.add(currentRun);
      }
      clues.add(rowClue.isEmpty ? [0] : rowClue);
    }
    return clues;
  }

  List<List<bool>> _transposePattern(List<List<bool>> pattern) {
    int rows = pattern.length;
    int cols = pattern[0].length;
    List<List<bool>> transposed = List.generate(cols, (_) => List.generate(rows, (_) => false));
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        transposed[c][r] = pattern[r][c];
      }
    }
    return transposed;
  }

  void _moveBrush(int dr, int dc) {
    final nextR = _brushRow + dr;
    final nextC = _brushCol + dc;
    _moveBrushTo(nextR, nextC);
  }

  void _moveBrushTo(int r, int c) {
    if (_isGameOver || _isGameWon) return;
    if (r < 0 || r >= widget.gridSize || c < 0 || c >= widget.gridSize) return;

    setState(() {
      _brushRow = r;
      _brushCol = c;
      _moves++;

      if (_brushMode == BrushMode.draw) {
        _grid[r][c] = true;
      } else if (_brushMode == BrushMode.erase) {
        _grid[r][c] = false;
      }

      _checkGameStatus();
    });
  }

  void _toggleCurrentCell() {
    if (_isGameOver || _isGameWon) return;
    setState(() {
      _grid[_brushRow][_brushCol] = !_grid[_brushRow][_brushCol];
      _moves++;
      _checkGameStatus();
    });
  }

  void _checkGameStatus() {
    bool allMatch = true;
    for (int r = 0; r < widget.gridSize; r++) {
      for (int c = 0; c < widget.gridSize; c++) {
        if (_grid[r][c] != _targetBlueprint[r][c]) {
          allMatch = false;
          break;
        }
      }
    }

    if (allMatch) {
      _isGameWon = true;
      _saveHighScore();
    } else if (widget.moveMode == 'challenge' && _moves >= _moveLimit) {
      _isGameOver = true;
    }
  }

  Future<void> _saveHighScore() async {
    await submitScore(_moves);
  }

  bool _isRowCompleted(int r) {
    for (int c = 0; c < widget.gridSize; c++) {
      if (_grid[r][c] != _targetBlueprint[r][c]) {
        return false;
      }
    }
    return true;
  }

  bool _isColCompleted(int c) {
    for (int r = 0; r < widget.gridSize; r++) {
      if (_grid[r][c] != _targetBlueprint[r][c]) {
        return false;
      }
    }
    return true;
  }

  void _handleGridPan(Offset localPosition, BoxConstraints constraints) {
    final cellWidth = constraints.maxWidth / widget.gridSize;
    final cellHeight = constraints.maxHeight / widget.gridSize;

    final col = (localPosition.dx / cellWidth).floor();
    final row = (localPosition.dy / cellHeight).floor();

    if (row >= 0 && row < widget.gridSize && col >= 0 && col < widget.gridSize) {
      if (row != _brushRow || col != _brushCol) {
        final isAdjacent = (row - _brushRow).abs() + (col - _brushCol).abs() == 1;
        if (isAdjacent) {
          _moveBrushTo(row, col);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeColor = _palette.isNotEmpty ? _palette[0] : theme.colorScheme.primary;
    final backgroundOff = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2);

    const double rowCluesWidth = 60.0;
    const double columnCluesHeight = 50.0;

    final showTarget = widget.gameMode == 'show';

    return BaseGameScreen(
      title: 'Grid Painter',
      gameId: 'grid_painter',
      gameConfig: {
        'gridSize': widget.gridSize,
        'gameMode': widget.gameMode,
        'moveMode': widget.moveMode,
      },
      highScoreLabel: 'Best',
      highScoreValue: bestScore != null ? '$bestScore moves' : '--',
      currentScoreLabel: 'Moves',
      currentScoreValue: '$_moves',
      statusText: widget.moveMode == 'challenge'
          ? 'Limit: $_moves/$_moveLimit'
          : 'Zen Mode',
      isGameWon: _isGameWon,
      isGameOver: _isGameOver && !_isGameWon,
      victoryMessage: 'Solved in $_moves moves!',
      gameOverMessage: 'Failed! Exceeded move limit of $_moveLimit!',
      onReset: _initializeGame,
      isGameInProgress: _moves > 0 && !_isGameOver,
      topHudExtra: Column(
        children: [
          if (showTarget) ...[
            Text(
              'Target: $_blueprintName',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Container(
              width: 75,
              height: 75,
              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                color: Colors.indigo.shade900,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: widget.gridSize,
                  crossAxisSpacing: 1.5,
                  mainAxisSpacing: 1.5,
                ),
                itemCount: widget.gridSize * widget.gridSize,
                itemBuilder: (context, idx) {
                  final r = idx ~/ widget.gridSize;
                  final c = idx % widget.gridSize;
                  final isPainted = _targetBlueprint[r][c];
                  return Container(
                    decoration: BoxDecoration(
                      color: isPainted ? Colors.cyan : Colors.transparent,
                      border: Border.all(color: Colors.white10, width: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            const Text(
              'Pure Picross Mode',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 4),
            const Text(
              'Deduce pattern from side clues!',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 8),
          if (!_isGameOver && !_isGameWon)
            SegmentedButton<BrushMode>(
              segments: const <ButtonSegment<BrushMode>>[
                ButtonSegment<BrushMode>(
                  value: BrushMode.draw,
                  label: Text('Draw'),
                  icon: Icon(Icons.brush),
                ),
                ButtonSegment<BrushMode>(
                  value: BrushMode.erase,
                  label: Text('Erase'),
                  icon: Icon(Icons.delete_outline),
                ),
                ButtonSegment<BrushMode>(
                  value: BrushMode.navigate,
                  label: Text('Move'),
                  icon: Icon(Icons.open_with),
                ),
              ],
              selected: <BrushMode>{_brushMode},
              onSelectionChanged: (Set<BrushMode> selected) {
                setState(() {
                  _brushMode = selected.first;
                  if (_brushMode == BrushMode.draw) {
                    _grid[_brushRow][_brushCol] = true;
                  }
                });
              },
            ),
        ],
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.contain,
                child: Container(
                  width: 362,
                  height: 352,
                  decoration: BoxDecoration(
                    color: backgroundOff,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: rowCluesWidth, height: columnCluesHeight),
                          SizedBox(
                            width: 300,
                            height: columnCluesHeight,
                            child: Row(
                              children: List.generate(widget.gridSize, (c) {
                                final isFinished = _isColCompleted(c);
                                return Container(
                                  width: 300.0 / widget.gridSize,
                                  alignment: Alignment.bottomCenter,
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.bottomCenter,
                                    child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: _colClues[c].map((v) {
                                      return Text(
                                        v == 0 ? '.' : '$v',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isFinished ? Colors.green : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          SizedBox(
                            width: rowCluesWidth,
                            height: 300,
                            child: Column(
                              children: List.generate(widget.gridSize, (r) {
                                final isFinished = _isRowCompleted(r);
                                return Container(
                                  height: 300.0 / widget.gridSize,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: _rowClues[r].map((v) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                        child: Text(
                                          v == 0 ? '.' : '$v',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isFinished ? Colors.green : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          Container(
                            width: 300,
                            height: 300,
                            padding: const EdgeInsets.all(4.0),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return GestureDetector(
                                  onPanStart: (details) => _handleGridPan(details.localPosition, constraints),
                                  onPanUpdate: (details) => _handleGridPan(details.localPosition, constraints),
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
                                      final isPainted = _grid[r][c];
                                      final isBrushHere = _brushRow == r && _brushCol == c;

                                      Color cellColor = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
                                      if (isPainted) {
                                        cellColor = themeColor;
                                      }

                                      return Semantics(label: 'Row ${r + 1}, column ${c + 1}, ${isPainted ? "painted" : "empty"}${isBrushHere ? ", brush here" : ""}', button: true, child: GestureDetector(
                                        onTap: () => _moveBrushTo(r, c),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: cellColor,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isBrushHere 
                                                  ? Colors.amberAccent 
                                                  : theme.colorScheme.outline.withValues(alpha: 0.1),
                                              width: isBrushHere ? 3.0 : 1.0,
                                            ),
                                          ),
                                          child: isBrushHere
                                              ? Icon(
                                                  _brushMode == BrushMode.draw
                                                      ? Icons.brush
                                                      : _brushMode == BrushMode.erase
                                                          ? Icons.delete_outline
                                                          : Icons.open_with,
                                                  size: 20,
                                                  color: cellColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                                                )
                                              : null,
                                        ),
                                      ));
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!_isGameOver && !_isGameWon)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        IconButton.filledTonal(
                          icon: const Icon(Icons.keyboard_arrow_up),
                          tooltip: 'Move brush up',
                          onPressed: () => _moveBrush(-1, 0),
                        ),
                        Row(
                          children: [
                            IconButton.filledTonal(
                              icon: const Icon(Icons.keyboard_arrow_left),
                          tooltip: 'Move brush left',
                              onPressed: () => _moveBrush(0, -1),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _toggleCurrentCell,
                              borderRadius: BorderRadius.circular(24),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                                child: const Icon(Icons.circle_outlined, size: 18, semanticLabel: 'Toggle current cell'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.keyboard_arrow_right),
                          tooltip: 'Move brush right',
                              onPressed: () => _moveBrush(0, 1),
                            ),
                          ],
                        ),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.keyboard_arrow_down),
                          tooltip: 'Move brush down',
                          onPressed: () => _moveBrush(1, 0),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
