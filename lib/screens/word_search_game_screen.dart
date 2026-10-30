import '../utils/game_pause.dart';
import '../utils/announce.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'mixins/config_high_score_mixin.dart';
import 'base_game_screen.dart';

class WordPlacement {
  final String word;
  final List<Point<int>> cells;
  final Color color;

  WordPlacement({
    required this.word,
    required this.cells,
    required this.color,
  });
}

class WordSearchGameScreen extends StatefulWidget {
  final int gridSize;
  final int wordCount;
  final String moveMode; // 'zen' or 'challenge'
  final String category;  // 'Random', 'Animals', 'Fruits', 'Colors', 'GridMind', 'Programming'
  final bool testMode;
  final List<List<String>>? testGrid;
  final List<String>? testWords;

  const WordSearchGameScreen({
    super.key,
    required this.gridSize,
    required this.wordCount,
    required this.moveMode,
    required this.category,
    this.testMode = false,
    this.testGrid,
    this.testWords,
  });

  @override
  State<WordSearchGameScreen> createState() => _WordSearchGameScreenState();
}

class _WordSearchGameScreenState extends State<WordSearchGameScreen> with ConfigHighScoreMixin<WordSearchGameScreen> {
  @override
  String get highScoreGameId => 'wordsearch';
  @override
  bool get highScoreLowerIsBetter => false;
  @override
  Map<String, dynamic> get highScoreConfig => {
        'gridSize': widget.gridSize.toDouble(),
        'wordCount': widget.wordCount.toDouble(),
        'moveMode': widget.moveMode,
        'category': widget.category,
      };
  final Random _rand = Random();

  static const Map<String, List<String>> _categories = {
    'Animals': ['CAT', 'DOG', 'LION', 'BEAR', 'WOLF', 'DEER', 'FROG', 'BIRD', 'TIGER', 'DUCK', 'FISH', 'COW', 'PIG', 'ELEPHANT', 'GIRAFFE', 'DOLPHIN', 'PENGUIN', 'KANGAROO', 'MONKEY', 'PANTHER', 'LEOPARD', 'CHEETAH', 'HAMSTER', 'RABBIT', 'SQUIRREL'],
    'Fruits': ['PEAR', 'PLUM', 'FIGS', 'KIWI', 'LIME', 'APPLE', 'GRAPE', 'PEACH', 'BERRY', 'MANGO', 'MELON', 'LEMON', 'BANANA', 'CHERRY', 'ORANGE', 'AVOCADO', 'COCONUT', 'APRICOT', 'PAPAYA', 'PINEAPPLE', 'PEACHES', 'BLUEBERRY'],
    'Colors': ['RED', 'BLUE', 'PINK', 'CYAN', 'GRAY', 'GREEN', 'BLACK', 'WHITE', 'AMBER', 'BROWN', 'ORANGE', 'PURPLE', 'YELLOW', 'VIOLET', 'MAGENTA', 'CRIMSON', 'TURQUOISE', 'INDIGO', 'SCARLET', 'LAVENDER', 'CHARCOAL'],
    'GridMind': ['GRID', 'MIND', 'GAME', 'PLAY', 'MOVE', 'TILES', 'SCORE', 'LEVEL', 'SOLVE', 'PUZZLE', 'MATCH', 'SYSTEM', 'TELEMETRY', 'SETTINGS', 'VICTORY', 'SCREEN', 'PERSISTENCE', 'CHALLENGE', 'CONTROLLER', 'REGISTRY'],
    'Programming': ['CODE', 'DART', 'LOOP', 'BUG', 'TEST', 'CLASS', 'WIDGET', 'FLUTTER', 'LOGIC', 'STACK', 'QUEUE', 'VARIABLE', 'FUNCTION', 'COMPILER', 'REGISTRY', 'INTERFACE', 'DEVELOPER', 'PARAMETER', 'ALGORITHM', 'DATABASE'],
    'Countries': ['CANADA', 'MEXICO', 'BRAZIL', 'FRANCE', 'GERMANY', 'JAPAN', 'EGYPT', 'INDIA', 'CHINA', 'SPAIN', 'ITALY', 'SWEDEN', 'NORWAY', 'FINLAND', 'AUSTRALIA', 'VIETNAM', 'MOROCCO', 'COLOMBIA', 'ARGENTINA', 'SINGAPORE'],
    'Sports': ['SOCCER', 'TENNIS', 'RUGBY', 'HOCKEY', 'CHESS', 'GOLF', 'SKIING', 'ROWING', 'BOXING', 'CRICKET', 'CURLING', 'BASEBALL', 'FOOTBALL', 'SWIMMING', 'ATHLETICS', 'GYMNASTICS', 'BADMINTON', 'VOLLEYBALL', 'WRESTLING'],
    'Space': ['SOLAR', 'PLANET', 'STAR', 'COMET', 'GALAXY', 'ORBIT', 'MOON', 'VENUS', 'MARS', 'SATURN', 'NEBULA', 'COSMOS', 'JUPITER', 'METEOR', 'TELESCOPE', 'ASTRONOMY', 'UNIVERSE', 'ASTEROID', 'SPACESHIP', 'SUPERNOVA'],
    'Food': ['BREAD', 'RICE', 'SUGAR', 'SALT', 'HONEY', 'MELON', 'GRAPE', 'LEMON', 'BANANA', 'CHERRY', 'ORANGE', 'MELON', 'PEACH', 'PLUM', 'KIWI', 'LIME', 'APPLE', 'BERRY', 'APRICOT', 'AVOCADO', 'COCONUT', 'PAPAYA', 'PINEAPPLE', 'CHEESE', 'BUTTER', 'SUGAR', 'WAFFLE', 'PUDDING', 'BURGER', 'SANDWICH'],
    'Science': ['ATOM', 'DNA', 'QUARK', 'PROTON', 'NEUTRON', 'ELECTRON', 'PHOTON', 'NEUTRINO', 'ISOTOPE', 'MOLECULE', 'COMPOUND', 'ELEMENT', 'CATALYST', 'REACTION', 'ENZYME', 'CELL', 'DNA', 'RNA', 'GENE', 'VIRUS', 'BACTERIA', 'ORGANISM', 'SPECIES', 'EVOLUTION', 'FUSION', 'FISSION', 'PARTICLE', 'WAVE'],
  };

  late List<List<String>> _grid;
  late List<String> _targetWords;
  late List<WordPlacement> _placedWords;
  
  final List<String> _foundWords = [];
  final List<WordPlacement> _foundPlacements = [];

  bool _isGameOver = false;
  bool _isGameWon = false;

  int _score = 0; // In challenge mode, this represents remaining time when won. In zen mode, it represents completions.
  int _hintsUsed = 0;
  Point<int>? _hintCell;
  String? _hintWord;
  Timer? _hintFlashTimer;

  // Drag selection tracking
  bool _dragging = false;
  Point<int>? _startCell;
  Point<int>? _endCell;
  List<Point<int>> _selectedCells = [];

  // Challenge Timer
  Timer? _timer;
  int _timeLeft = 0;
  int _timeLimit = 0;

  @override
  void initState() {
    super.initState();
    _grid = [];
    _targetWords = [];
    _placedWords = [];
    _initializeGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hintFlashTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeGame() async {
    _timer?.cancel();
    _hintFlashTimer?.cancel();

    final stored = await loadBestScore();
    if (!mounted) return;

    bool generationSuccess = false;
    int attempts = 0;

    while (!generationSuccess && attempts < 15) {
      generationSuccess = _generateGridAndWords();
      attempts++;
    }

    _timeLimit = widget.gridSize * 15 + _targetWords.length * 10;
    _timeLeft = _timeLimit;
    _hintsUsed = 0;
    _hintCell = null;
    _foundWords.clear();
    _foundPlacements.clear();
    _selectedCells.clear();
    _dragging = false;
    _isGameOver = false;
    _isGameWon = false;
    _score = 0;

    setState(() {
      bestScore = stored;
    });

    if (widget.moveMode == 'challenge' && !widget.testMode) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isGameOver || _isGameWon) {
        timer.cancel();
        return;
      }
      if (GamePause.isPaused) return;
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _isGameOver = true;
          _score = 0;
          timer.cancel();
          _saveHighScore();
        }
      });
    });
  }

  bool _generateGridAndWords() {
    final size = widget.gridSize;

    if (widget.testMode && widget.testGrid != null && widget.testWords != null) {
      _grid = List.generate(size, (r) => List<String>.from(widget.testGrid![r]));
      _targetWords = List<String>.from(widget.testWords!);
      final placements = <WordPlacement>[];
      for (int wordIdx = 0; wordIdx < _targetWords.length; wordIdx++) {
        final word = _targetWords[wordIdx].toUpperCase();
        final cells = _findWordInGrid(_grid, word);
        if (cells != null) {
          placements.add(WordPlacement(
            word: word,
            cells: cells,
            color: _getWordColor(wordIdx),
          ));
        }
      }
      _placedWords = placements;
      return true;
    }

    final grid = List.generate(size, (_) => List.generate(size, (_) => ' '));
    final placements = <WordPlacement>[];

    List<String> wordsSource = [];
    if (widget.testMode && widget.testWords != null) {
      wordsSource = List<String>.from(widget.testWords!);
    } else {
      String cat = widget.category;
      if (cat == 'Random') {
        final keys = _categories.keys.toList();
        cat = keys[_rand.nextInt(keys.length)];
      }
      final allWords = _categories[cat] ?? [];
      // Filter words fitting the grid size
      wordsSource = allWords.where((w) => w.length <= size).toList();
      wordsSource.shuffle();
    }

    if (wordsSource.isEmpty) {
      wordsSource.add('GRID');
    }

    final directions = [
      const Point(0, 1),   // E
      const Point(0, -1),  // W
      const Point(1, 0),   // S
      const Point(-1, 0),  // N
      const Point(1, 1),   // SE
      const Point(-1, -1), // NW
      const Point(1, -1),  // SW
      const Point(-1, 1),  // NE
    ];

    // Walk the whole pool and skip words that will not fit, until wordCount are placed.
    // A crowded board then ends up with fewer words instead of failing outright.
    for (final candidate in wordsSource) {
      if (placements.length >= widget.wordCount) break;
      final wordIdx = placements.length;
      final word = candidate.toUpperCase();
      // Try random starting positions and directions
      for (int attempt = 0; attempt < 250; attempt++) {
        final startR = _rand.nextInt(size);
        final startC = _rand.nextInt(size);
        final dir = directions[_rand.nextInt(directions.length)];

        if (_canPlaceWord(grid, word, startR, startC, dir)) {
          final cells = _placeWord(grid, word, startR, startC, dir);
          placements.add(WordPlacement(
            word: word,
            cells: cells,
            color: _getWordColor(wordIdx),
          ));
          break;
        }
      }

      // if no spot was found the word is left out and the next one is tried
    }
    if (placements.isEmpty) return false;

    // Fill empty cells with random letters
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (grid[r][c] == ' ') {
          grid[r][c] = alphabet[_rand.nextInt(alphabet.length)];
        }
      }
    }

    _grid = grid;
    _placedWords = placements;
    _targetWords = placements.map((p) => p.word).toList();
    return true;
  }

  List<Point<int>>? _findWordInGrid(List<List<String>> grid, String word) {
    final size = widget.gridSize;
    final directions = [
      const Point(0, 1),   // E
      const Point(0, -1),  // W
      const Point(1, 0),   // S
      const Point(-1, 0),  // N
      const Point(1, 1),   // SE
      const Point(-1, -1), // NW
      const Point(1, -1),  // SW
      const Point(-1, 1),  // NE
    ];

    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        for (final dir in directions) {
          int currR = r;
          int currC = c;
          bool match = true;
          final cells = <Point<int>>[];
          
          for (int i = 0; i < word.length; i++) {
            if (currR < 0 || currR >= size || currC < 0 || currC >= size || grid[currR][currC] != word[i]) {
              match = false;
              break;
            }
            cells.add(Point(currR, currC));
            currR += dir.x;
            currC += dir.y;
          }
          
          if (match) {
            return cells;
          }
        }
      }
    }
    return null;
  }

  bool _canPlaceWord(List<List<String>> grid, String word, int startR, int startC, Point<int> dir) {
    int r = startR;
    int c = startC;
    final size = widget.gridSize;

    for (int i = 0; i < word.length; i++) {
      if (r < 0 || r >= size || c < 0 || c >= size) {
        return false;
      }
      if (grid[r][c] != ' ' && grid[r][c] != word[i]) {
        return false;
      }
      r += dir.x;
      c += dir.y;
    }
    return true;
  }

  List<Point<int>> _placeWord(List<List<String>> grid, String word, int startR, int startC, Point<int> dir) {
    final cells = <Point<int>>[];
    int r = startR;
    int c = startC;
    for (int i = 0; i < word.length; i++) {
      grid[r][c] = word[i];
      cells.add(Point(r, c));
      r += dir.x;
      c += dir.y;
    }
    return cells;
  }

  Color _getWordColor(int index) {
    final colors = [
      Colors.redAccent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.tealAccent,
      Colors.pinkAccent,
      Colors.indigoAccent,
    ];
    return colors[index % colors.length];
  }

  void _handleCellTouchStart(int r, int c) {
    if (_isGameOver || _isGameWon) return;
    setState(() {
      _dragging = true;
      _startCell = Point(r, c);
      _endCell = Point(r, c);
      _selectedCells = [Point(r, c)];
    });
  }

  void _handleCellTouchUpdate(int r, int c) {
    if (!_dragging || _isGameOver || _isGameWon || _startCell == null) return;
    final currentPoint = Point(r, c);
    if (_endCell == currentPoint) return;

    final start = _startCell!;
    final dr = r - start.x;
    final dc = c - start.y;

    setState(() {
      _endCell = currentPoint;
      if (dr == 0 && dc == 0) {
        _selectedCells = [start];
      } else if (dr == 0) {
        // Horizontal selection
        final step = dc.sign;
        _selectedCells = List.generate(
          dc.abs() + 1,
          (i) => Point(start.x, start.y + i * step),
        );
      } else if (dc == 0) {
        // Vertical selection
        final step = dr.sign;
        _selectedCells = List.generate(
          dr.abs() + 1,
          (i) => Point(start.x + i * step, start.y),
        );
      } else if (dr.abs() == dc.abs()) {
        // Diagonal selection
        final stepR = dr.sign;
        final stepC = dc.sign;
        _selectedCells = List.generate(
          dr.abs() + 1,
          (i) => Point(start.x + i * stepR, start.y + i * stepC),
        );
      }
      // If not horizontal, vertical, or diagonal, keep the previous valid selection
    });
  }

  /// Screen-reader path: activate a start cell, then an end cell in a straight
  /// line (row, column or diagonal). Activating the start again cancels.
  void _semanticSelect(int r, int c) {
    if (_isGameOver || _isGameWon) return;
    final p = Point(r, c);
    if (!_dragging || _startCell == null) {
      _handleCellTouchStart(r, c);
      announce(context, 'Start set at row ${r + 1}, column ${c + 1}, letter ${_grid[r][c]}. Activate the last letter of the word.');
      return;
    }
    if (p == _startCell) {
      _handleCellTouchEnd();
      announce(context, 'Selection cancelled.');
      return;
    }
    final dr = r - _startCell!.x, dc = c - _startCell!.y;
    if (dr != 0 && dc != 0 && dr.abs() != dc.abs()) {
      announce(context, 'Not in a straight line from the start. Pick another end cell, or activate the start to cancel.');
      return;
    }
    final foundBefore = _foundWords.length;
    _handleCellTouchUpdate(r, c);
    _handleCellTouchEnd();
    announce(context, _foundWords.length > foundBefore
        ? 'Found ${_foundWords.last}. ${_targetWords.length - _foundWords.length} left.'
        : 'Not a word. Selection cleared.');
  }

  void _handleCellTouchEnd() {
    if (!_dragging) return;
    final selectionStr = _selectedCells.map((p) => _grid[p.x][p.y]).join();
    final reversedSelectionStr = selectionStr.split('').reversed.join();

    String? foundWord;
    WordPlacement? matchedPlacement;

    for (final placement in _placedWords) {
      if (placement.word == selectionStr || placement.word == reversedSelectionStr) {
        // Verify the coordinates match this placement exactly
        final cells = placement.cells;
        bool exactMatch = true;
        for (final p in _selectedCells) {
          if (!cells.contains(p)) {
            exactMatch = false;
            break;
          }
        }
        if (exactMatch && !_foundWords.contains(placement.word)) {
          foundWord = placement.word;
          matchedPlacement = placement;
          break;
        }
      }
    }

    setState(() {
      _dragging = false;
      if (foundWord != null && matchedPlacement != null) {
        _foundWords.add(foundWord);
        _foundPlacements.add(matchedPlacement);
        _selectedCells.clear();
        _checkVictory();
      } else {
        _selectedCells.clear();
      }
      _startCell = null;
      _endCell = null;
    });
  }

  void _checkVictory() {
    if (_foundWords.length >= _targetWords.length) {
      _isGameWon = true;
      _timer?.cancel();

      if (widget.moveMode == 'challenge') {
        _score = _timeLeft;
      } else {
        _score = 1; // Basic completion value
      }
      _saveHighScore();
    }
  }

  Future<void> _saveHighScore() async {
    // Challenge mode stores remaining time, so higher is better.
    await submitScore(_score);
  }

  void _triggerHint() {
    if (_isGameOver || _isGameWon || _hintsUsed >= 3) return;

    // Find first word not yet found
    WordPlacement? hintPlacement;
    for (final placement in _placedWords) {
      if (!_foundWords.contains(placement.word)) {
        hintPlacement = placement;
        break;
      }
    }

    if (hintPlacement != null && hintPlacement.cells.isNotEmpty) {
      setState(() {
        _hintsUsed++;
        _hintCell = hintPlacement!.cells.first;
        _hintWord = hintPlacement.word;
        if (widget.moveMode == 'challenge') {
          // Time penalty for using hint
          _timeLeft = max(0, _timeLeft - 10);
        }
      });

      _hintFlashTimer?.cancel();
      announce(context, 'Hint: ${hintPlacement.word} starts at row ${hintPlacement.cells.first.x + 1}, column ${hintPlacement.cells.first.y + 1}.');
      _hintFlashTimer = Timer(const Duration(milliseconds: 4000), () {
        if (!mounted) return;
        setState(() {
          _hintCell = null;
          _hintWord = null;
        });
      });
    }
  }

  void _undo() {
    if (_foundPlacements.isEmpty || _isGameOver || _isGameWon) return;
    setState(() {
      final removed = _foundPlacements.removeLast();
      _foundWords.remove(removed.word);
      _hintCell = null;
      _hintWord = null;
    });
  }

  bool _isCellInSelection(Point<int> p) {
    return _selectedCells.contains(p);
  }

  bool get _revealMissed => _isGameOver && !_isGameWon;

  bool _isMissedCell(Point<int> p) =>
      _revealMissed && _placedWords.any((w) => !_foundWords.contains(w.word) && w.cells.contains(p));

  Color? _getCellWordColor(Point<int> p) {
    // Return color of the word this cell belongs to (last found takes precedence)
    for (int i = _foundPlacements.length - 1; i >= 0; i--) {
      if (_foundPlacements[i].cells.contains(p)) {
        return _foundPlacements[i].color.withValues(alpha: 0.35);
      }
    }
    return null;
  }

  Color? _getCellWordBorderColor(Point<int> p) {
    for (int i = _foundPlacements.length - 1; i >= 0; i--) {
      if (_foundPlacements[i].cells.contains(p)) {
        return _foundPlacements[i].color;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final hudValue = widget.moveMode == 'challenge'
        ? '${_timeLeft}s'
        : '${_foundWords.length}/${_targetWords.length}';


    return BaseGameScreen(
      title: 'Word Search',
      gameId: 'wordsearch',
      gameConfig: {
        'gridSize': widget.gridSize,
        'wordCount': widget.wordCount,
        'moveMode': widget.moveMode,
        'category': widget.category,
      },
      highScoreLabel: widget.moveMode == 'challenge' ? 'Best Time Left' : 'Best Completed',
      highScoreValue: bestScore != null 
          ? (widget.moveMode == 'challenge' ? '${bestScore}s' : 'Yes') 
          : '-',
      currentScoreLabel: widget.moveMode == 'challenge' ? 'Time Left' : 'Words Found',
      tickOnScoreChange: widget.moveMode != 'challenge', // slot is a countdown there
      currentScoreValue: widget.moveMode == 'challenge' ? hudValue : '${_foundWords.length}/${_targetWords.length}',
      statusText: widget.moveMode == 'challenge'
          ? 'Time remaining: ${_timeLeft}s'
          : 'Zen Mode (Untimed)',
      isGameWon: _isGameWon,
      isGameOver: _isGameOver && !_isGameWon,
      victoryMessage: widget.moveMode == 'challenge' 
          ? 'Victory! Solved in ${_timeLimit - _timeLeft}s!' 
          : 'Victory! All words found!',
      gameOverMessage: 'Out of Time!',
      onReset: _initializeGame,
      onUndo: _foundPlacements.isNotEmpty ? _undo : null,
      isGameInProgress: _foundWords.isNotEmpty && !_isGameOver && !_isGameWon,
      child: Column(
        children: [
          // Word search board container. Flexible: in a wide, short window the
          // square board shrinks to the height available instead of overflowing.
          Flexible(
            child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                ),
                child: Builder(
                  builder: (gridContext) {
                    return GestureDetector(
                      onPanStart: (details) {
                        final RenderBox? rBox = gridContext.findRenderObject() as RenderBox?;
                        if (rBox == null) return;
                        final local = rBox.globalToLocal(details.globalPosition);
                        final cellW = rBox.size.width / widget.gridSize;
                        final cellH = rBox.size.height / widget.gridSize;
                        final c = (local.dx / cellW).floor();
                        final r = (local.dy / cellH).floor();
                        if (r >= 0 && r < widget.gridSize && c >= 0 && c < widget.gridSize) {
                          _handleCellTouchStart(r, c);
                        }
                      },
                      onPanUpdate: (details) {
                        final RenderBox? rBox = gridContext.findRenderObject() as RenderBox?;
                        if (rBox == null) return;
                        final local = rBox.globalToLocal(details.globalPosition);
                        final cellW = rBox.size.width / widget.gridSize;
                        final cellH = rBox.size.height / widget.gridSize;
                        final c = (local.dx / cellW).floor();
                        final r = (local.dy / cellH).floor();
                        if (r >= 0 && r < widget.gridSize && c >= 0 && c < widget.gridSize) {
                          _handleCellTouchUpdate(r, c);
                        }
                      },
                      onPanEnd: (_) => _handleCellTouchEnd(),
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
                          if (_grid.isEmpty || r >= _grid.length || c >= _grid[r].length) {
                            return const SizedBox();
                          }

                          final letter = _grid[r][c];
                          final cellPt = Point(r, c);
                          final isSelecting = _isCellInSelection(cellPt);
                          final wordColor = _getCellWordColor(cellPt);
                          final wordBorderColor = _getCellWordBorderColor(cellPt);
                          final isHint = _hintCell == cellPt;
                          final isMissed = _isMissedCell(cellPt);

                          Color cellBg = Colors.transparent;
                          Border? cellBorder;

                          if (isSelecting) {
                            cellBg = theme.colorScheme.secondaryContainer.withValues(alpha: 0.6);
                            cellBorder = Border.all(color: theme.colorScheme.primary, width: 2.0);
                          } else if (isMissed) {
                            cellBg = Colors.redAccent.withValues(alpha: 0.3);
                            cellBorder = Border.all(color: Colors.redAccent, width: 1.5);
                          } else if (isHint) {
                            cellBg = Colors.amberAccent.withValues(alpha: 0.8);
                            cellBorder = Border.all(color: Colors.amber, width: 3.0);
                          } else if (wordColor != null) {
                            cellBg = wordColor;
                            cellBorder = Border.all(color: wordBorderColor ?? Colors.transparent, width: 1.5);
                          } else {
                            cellBorder = Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.08));
                          }

                          return Semantics(label: 'Row ${r + 1}, column ${c + 1}, letter $letter${wordColor != null ? ", part of a found word" : ""}${isMissed ? ", part of a missed word" : ""}${_startCell == Point(r, c) ? ", start of selection" : ""}', button: true, onTap: () => _semanticSelect(r, c), child: Container(
                            key: ValueKey('cell_${r}_$c'),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: cellBg,
                              borderRadius: BorderRadius.circular(8),
                              border: cellBorder,
                            ),
                            child: Text(
                              letter,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: widget.gridSize > 16
                                    ? 9.0
                                    : widget.gridSize > 12
                                        ? 11.0
                                        : widget.gridSize > 8
                                            ? 14.0
                                            : 17.0,
                                height: 1.0, // titleMedium's 1.5 line height is taller than a cell at 16+ and clips the last row
                                fontWeight: (isSelecting || wordColor != null) ? FontWeight.bold : FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ));
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
            ),
          ),
          
          const SizedBox(height: 16),

          // List of words to find
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Words to Find:',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _targetWords.map((word) {
                      final found = _foundWords.contains(word);
                      final missed = _revealMissed && !found;
                      final hinted = _hintWord == word && !found;
                      final placementIdx = _placedWords.indexWhere((p) => p.word == word);
                      final color = placementIdx != -1 ? _getWordColor(placementIdx) : theme.colorScheme.primary;

                      return Chip(
                        avatar: found ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                        label: Text(
                          word,
                          style: TextStyle(
                            decoration: found ? TextDecoration.lineThrough : null,
                            color: found ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: found 
                            ? color.withValues(alpha: 0.8) 
                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: found
                                ? Colors.transparent
                                : (missed ? Colors.redAccent : (hinted ? Colors.amber : theme.colorScheme.outline.withValues(alpha: 0.15))),
                            width: (missed || hinted) ? 2.5 : 1.0,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  // Hints and actions row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.lightbulb_outline),
                        label: Text('Hint (${3 - _hintsUsed})'),
                        onPressed: (_hintsUsed < 3 && !_isGameOver && !_isGameWon) 
                            ? _triggerHint 
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.tertiaryContainer,
                          foregroundColor: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
