// lib/collapse_game_screen.dart
import 'package:flutter/semantics.dart';
import '../utils/color_names.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../models/collapse_models.dart';
import 'base_game_screen.dart';
import 'mixins/config_high_score_mixin.dart';

/// Represents a single block in the Collapse game grid
/// Each block has a color, match status, and unique identifier
/// Blocks can be matched, cleared, or marked as empty after clearing
class Block {
  /// Color of the block for visual display and matching
  Color color;
  
  /// Whether this block is part of a current match
  /// Used during match detection and clearing phases
  bool isMatched;
  
  /// Whether this block position is empty after clearing
  /// Used for collapse mechanics to determine where blocks should fall
  bool isEmpty;
  
  /// Unique identifier for the block
  /// Helps Flutter differentiate blocks during animations and state changes
  UniqueKey id;

  /// Constructor for creating a new block
  Block({required this.color, this.isMatched = false, this.isEmpty = false})
    : id = UniqueKey();

  /// Factory constructor for creating an empty block placeholder
  /// Used to represent empty spaces in the grid after blocks are cleared
  factory Block.empty() {
    return Block(color: Colors.transparent, isEmpty: true);
  }
}

/// Main game screen for the Collapse match-3 style game
/// Players match colored blocks to clear them and achieve target scores
/// Features various collapse mechanics and customizable difficulty
class CollapseGameScreen extends StatefulWidget {
  /// Configuration for this game level
  /// Contains all parameters that define how the level plays
  final CollapseLevel level;
  
  final List<Color>? testColors;
  final bool skipInitialDelay;
  final bool testMode;

  const CollapseGameScreen({
    super.key,
    required this.level,
    this.testColors,
    this.skipInitialDelay = false,
    this.testMode = false,
  });
  
  @override
  State<CollapseGameScreen> createState() => _CollapseGameScreenState();
}

/// State class for the Collapse game screen
/// Manages game logic, block matching, collapse mechanics, and UI state
class _CollapseGameScreenState extends State<CollapseGameScreen>
    with TickerProviderStateMixin, ConfigHighScoreMixin<CollapseGameScreen> {
  @override
  String get highScoreGameId => 'collapse';
  @override
  bool get highScoreLowerIsBetter => true;
  @override
  Map<String, dynamic> get highScoreConfig => {
        'gridSize': widget.level.gridSize.toDouble(),
        'mechanic': widget.level.mechanic,
        'targetScore': widget.level.targetScore.toDouble(),
        'minMatchCount': widget.level.minMatchCount.toDouble(),
        'moves': widget.level.moves.toDouble(),
      };
  // TickerProviderStateMixin enables animations for smooth visual feedback
  
  /// 2D grid representing the game board
  /// Each element is either a Block or null (empty space)
  late List<List<Block?>> _grid;
  
  /// Size of the game grid (e.g., 8 means 8x8)
  late int _gridSize;
  
  /// Minimum number of blocks that must match to clear them
  /// Higher values create more challenging gameplay
  late int _minMatch;
  
  /// Current player score
  /// Increases when blocks are matched and cleared
  int _score = 0;
  
  /// Number of moves remaining for the player
  /// Game ends when moves are exhausted
  int _movesLeft = 0;
  
  /// Number of times the board has been shuffled
  /// Limited to prevent infinite shuffling
  int _shuffleCount = 0;
  
  /// Maximum number of shuffles allowed per game
  /// Prevents players from getting stuck with no moves
  final int _maxShuffles = 10;

  /// Drag gesture tracking for block swapping
  /// Enables touch-based block manipulation
  Point<int>? _dragStartBlockPosition;
  Offset _dragAccumulatedDelta = Offset.zero;

  /// Random number generator for block generation and shuffling
  final Random _random = Random();

  /// Visual feedback during drag operations
  /// Tracks which block is being dragged and its offset
  Point<int>? _currentlyDraggedBlockPosition;
  Offset _currentDragOffset = Offset.zero;

  bool _gameWon = false;

  // Add a field to track drag direction
  String? _dragDirection; // 'horizontal' or 'vertical'
  double _tileSize = 40.0; // Default, will be set in build

  /// Shuffles the game board to create new move opportunities
  /// Called when no valid moves are available
  Future<void> _shuffleBoard() async {
    if (!mounted) return;
    
    _shuffleCount++;

    // 1. Collect all existing blocks from the grid
    List<Block?> allBlocks = [];
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        if (_grid[r][c] != null && !_grid[r][c]!.isEmpty) {
          allBlocks.add(_grid[r][c]);
        }
      }
    }

    // 2. Shuffle the collected blocks
    allBlocks.shuffle(_random);

    // 3. Re-populate the grid with shuffled blocks
    int blockIndex = 0;
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        if (_grid[r][c] != null && !_grid[r][c]!.isEmpty) {
          // Only replace existing block positions
          if (blockIndex < allBlocks.length) {
            _grid[r][c] = allBlocks[blockIndex++];
          } else {
            // Fallback: generate new random blocks if needed
            _grid[r][c] = Block(
              color: widget.level.availableColors[_random.nextInt(
                widget.level.availableColors.length,
              )],
            );
          }
        }
      }
    }

    // Update UI with shuffled board
    if (mounted) setState(() {});

    // Process any matches that may have been created by shuffling
    bool matchesAfterShuffleProcessed;
    int safetyBreak = 0;
    do {
      if (!mounted) return;
      matchesAfterShuffleProcessed = await _processMatchesAndCollapse(
        isInitialSetup: true,
      );
      safetyBreak++;
    } while (matchesAfterShuffleProcessed && safetyBreak < 10 && mounted);

    // Check if shuffling resolved the no-moves situation
    await _checkAndHandleNoMoves(isAfterShuffle: true);
  }

  /// Checks if any valid moves are possible and handles no-moves situations
  /// Either shuffles the board or ends the game if no moves are available
  Future<void> _checkAndHandleNoMoves({bool isAfterShuffle = false}) async {
    if (!mounted) return;

    if (!_areAnyMovesPossible()) {
      if (!isAfterShuffle && _shuffleCount < _maxShuffles) {
        // Show shuffle notification to the player
        if (mounted && !widget.testMode) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No moves! Shuffling... (${_shuffleCount + 1}/$_maxShuffles)',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          await Future.delayed(
            const Duration(milliseconds: 500),
          ); // Brief pause before shuffle
        }
        await _shuffleBoard();
      } else {
        // No moves left and shuffles are exhausted
        if (mounted) {
          setState(() {
            _movesLeft = 0;
          });
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize game parameters from level configuration
    _gridSize = widget.level.gridSize;
    _minMatch = widget.level.minMatchCount;
    _movesLeft = widget.level.moves;
    _loadBestMoves();
    if (widget.testColors != null) {
      // Use test colors for deterministic grid
      _grid = List.generate(
        _gridSize,
        (row) => List.generate(
          _gridSize,
          (col) => Block(color: widget.testColors![((row * _gridSize) + col) % widget.testColors!.length]),
        ),
      );
      _score = 0;
      _movesLeft = widget.level.moves;
      _gameWon = false;
      _shuffleCount = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
    } else if (widget.testMode || widget.skipInitialDelay) {
      // Synchronous init for tests
      _grid = List.generate(
        _gridSize,
        (row) => List.generate(
          _gridSize,
          (col) => Block(color: kAllPossibleBlockColors[((row * _gridSize) + col) % kAllPossibleBlockColors.length]),
        ),
      );
      _score = 0;
      _movesLeft = widget.level.moves;
      _gameWon = false;
      _shuffleCount = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
    } else {
      // Initialize grid with empty structure
      _grid = List.generate(
        _gridSize,
        (index) => List.filled(_gridSize, null, growable: false),
        growable: false,
      );
      // Start the game initialization
      _initializeGrid();
    }
  }

  Future<void> _loadBestMoves() async {
    final stored = await loadBestScore();
    if (mounted) {
      setState(() {
        bestScore = stored;
      });
    }
  }

  Future<void> _updateBestMovesIfNeeded() async {
    int movesUsed = widget.level.targetScore > 0 ? (widget.level.moves - _movesLeft) : 0;
    if (_movesLeft >= 0 && movesUsed > 0) await submitScore(movesUsed);
  }

  /// Initializes the game grid with random blocks
  /// Sets up the initial game state and processes any starting matches
  void _initializeGrid() async {
    setState(() {
      _score = 0;
      _movesLeft = widget.level.moves; // Reset moves for new game
      _gameWon = false;
      _shuffleCount = 0;
      
      // Generate random blocks for the entire grid
      _grid = List.generate(
        _gridSize,
        (row) => List.generate(
          _gridSize,
          (col) => Block(
            color: widget.level.availableColors[_random.nextInt(
              widget.level.availableColors.length,
            )],
          ),
        ),
      );
    });

    // Process any initial matches that may have been generated
    bool initialMatchesProcessed;
    int safetyBreak = 0;
    do {
      if (!mounted) return; // Important check within loops in async methods
      initialMatchesProcessed = await _processMatchesAndCollapse(
        isInitialSetup: true,
      );
      safetyBreak++;
    } while (initialMatchesProcessed &&
        safetyBreak < _gridSize * _gridSize); // A reasonable limit

    await _checkAndHandleNoMoves();
  }

  /// Screen-reader equivalent of dragging a block one square: runs the same
  /// end-of-drag logic with a full-tile drag in the given direction.
  Future<void> _semanticSwap(int row, int col, int dRow, int dCol) {
    if (_grid[row][col] == null || _grid[row][col]!.isEmpty) return Future.value();
    _dragStartBlockPosition = Point(row, col);
    _dragDirection = dRow == 0 ? 'horizontal' : 'vertical';
    _dragAccumulatedDelta = Offset(dCol * _tileSize, dRow * _tileSize);
    return _handleDragEnd(DragEndDetails());
  }

  void _handleDragStart(DragStartDetails details, int row, int col) {
    if (_grid[row][col] == null || _grid[row][col]!.isEmpty) return;
    setState(() {
      _dragStartBlockPosition = Point(row, col);
      _dragAccumulatedDelta = Offset.zero;
      _currentlyDraggedBlockPosition = Point(row, col); // For visual feedback
      _currentDragOffset = Offset.zero; // For visual feedback
      _dragDirection = null;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details, int row, int col) {
    if (_dragStartBlockPosition == null ||
        (_dragStartBlockPosition!.x != row ||
            _dragStartBlockPosition!.y != col)) {
      // If drag started on a different block or no drag started, ignore.
      return;
    }
    // Determine drag direction on first update
    if (_dragDirection == null) {
      if (details.delta.dx.abs() > details.delta.dy.abs()) {
        _dragDirection = 'horizontal';
      } else if (details.delta.dy.abs() > details.delta.dx.abs()) {
        _dragDirection = 'vertical';
      }
    }
    // Only allow movement in the determined direction
    Offset delta = details.delta;
    if (_dragDirection == 'horizontal') {
      delta = Offset(delta.dx, 0);
    } else if (_dragDirection == 'vertical') {
      delta = Offset(0, delta.dy);
    } else {
      delta = Offset.zero;
    }
    _dragAccumulatedDelta += delta;
    // Snap drag to one tile size max in the drag direction
    if (_dragDirection == 'horizontal') {
      double snapped = _dragAccumulatedDelta.dx.clamp(-_tileSize, _tileSize);
      setState(() {
        _currentDragOffset = Offset(snapped, 0);
      });
    } else if (_dragDirection == 'vertical') {
      double snapped = _dragAccumulatedDelta.dy.clamp(-_tileSize, _tileSize);
      setState(() {
        _currentDragOffset = Offset(0, snapped);
      });
    }
  }

  Future<void> _handleDragEnd(DragEndDetails details) async {
    if (_dragStartBlockPosition == null || _gameWon) return;

    final startPos = _dragStartBlockPosition!;
    int targetRow = startPos.x;
    int targetCol = startPos.y;
    bool swapped = false;

    // Only allow a one-square move in the drag direction if drag is at least half a tile
    if (_dragDirection == 'horizontal') {
      if (_dragAccumulatedDelta.dx > _tileSize / 2 && startPos.y < _gridSize - 1) {
        // Drag Right
        targetCol++;
        swapped = true;
      } else if (_dragAccumulatedDelta.dx < -_tileSize / 2 && startPos.y > 0) {
        // Drag Left
        targetCol--;
        swapped = true;
      }
    } else if (_dragDirection == 'vertical') {
      if (_dragAccumulatedDelta.dy > _tileSize / 2 && startPos.x < _gridSize - 1) {
        // Drag Down
        targetRow++;
        swapped = true;
      } else if (_dragAccumulatedDelta.dy < -_tileSize / 2 && startPos.x > 0) {
        // Drag Up
        targetRow--;
        swapped = true;
      }
    }

    if (swapped) {
      final Point<int> endPos = Point(targetRow, targetCol);
      _swapBlocks(startPos, endPos);

      // Check if the swap results in a match
      bool validSwap = _formsMatchAround(startPos) || _formsMatchAround(endPos);

      if (validSwap) {
        if (_movesLeft > 0) {
          setState(() => _movesLeft--);
        }
        bool matchesProcessed =
            await _processMatchesAndCollapse(); // Normal processing
        if (matchesProcessed || !validSwap) {
          await _checkAndHandleNoMoves();
        }
      } else {
        // Invalid swap (no match formed), swap back
        _swapBlocks(endPos, startPos); // Swap back immediately
        await _checkAndHandleNoMoves();
      }
    }

    if (!mounted) return;
    setState(() {
      _dragStartBlockPosition = null;
      _dragAccumulatedDelta = Offset.zero;
      _currentlyDraggedBlockPosition = null; // Reset visual feedback
      _currentDragOffset = Offset.zero; // Reset visual feedback
      _dragDirection = null;
    });
  }

  // Helper to check if any moves are possible
  bool _areAnyMovesPossible() {
    if (_grid.isEmpty) return false;

    // Iterate through each block to check for potential swaps
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        if (_grid[r][c] == null || _grid[r][c]!.isEmpty) continue;

        // --- Try swapping HORIZONTALLY (with block to the right) ---
        if (c < _gridSize - 1) {
          // Check if there's a block to the right
          if (_grid[r][c + 1] != null && !_grid[r][c + 1]!.isEmpty) {
            // Simulate swap
            Block? temp = _grid[r][c];
            _grid[r][c] = _grid[r][c + 1];
            _grid[r][c + 1] = temp;

            // Check if this simulated swap forms a match around either of the swapped positions
            if (_formsMatchAround(Point(r, c)) ||
                _formsMatchAround(Point(r, c + 1))) {
              // Swap back immediately - we just needed to check
              temp = _grid[r][c];
              _grid[r][c] = _grid[r][c + 1];
              _grid[r][c + 1] = temp;
              return true; // Found a possible move!
            }
            // Swap back
            temp = _grid[r][c];
            _grid[r][c] = _grid[r][c + 1];
            _grid[r][c + 1] = temp;
          }
        }

        // --- Try swapping VERTICALLY (with block below) ---
        if (r < _gridSize - 1) {
          // Check if there's a block below
          if (_grid[r + 1][c] != null && !_grid[r + 1][c]!.isEmpty) {
            // Simulate swap
            Block? temp = _grid[r][c];
            _grid[r][c] = _grid[r + 1][c];
            _grid[r + 1][c] = temp;

            // Check if this simulated swap forms a match
            if (_formsMatchAround(Point(r, c)) ||
                _formsMatchAround(Point(r + 1, c))) {
              // Swap back
              temp = _grid[r][c];
              _grid[r][c] = _grid[r + 1][c];
              _grid[r + 1][c] = temp;
              return true; // Found a possible move!
            }
            // Swap back
            temp = _grid[r][c];
            _grid[r][c] = _grid[r + 1][c];
            _grid[r + 1][c] = temp;
          }
        }
      }
    }
    return false; // No possible moves found after checking all potential swaps
  }

  /// True when the 2x2 block whose top-left cell is (r, c) is one colour.
  bool _isSquareAt(int r, int c) {
    if (r < 0 || c < 0 || r + 1 >= _gridSize || c + 1 >= _gridSize) {
      return false;
    }
    final b = _grid[r][c];
    if (b == null || b.isEmpty) return false;
    for (final cell in [_grid[r][c + 1], _grid[r + 1][c], _grid[r + 1][c + 1]]) {
      if (cell == null || cell.isEmpty || cell.color != b.color) return false;
    }
    return true;
  }

  // Helper to check if a point is part of any potential match after a swap
  bool _formsMatchAround(Point<int> pos) {
    // Temporarily check horizontal and vertical matches involving this specific block
    if (_grid[pos.x][pos.y] == null || _grid[pos.x][pos.y]!.isEmpty) {
      return false;
    }
    Color color = _grid[pos.x][pos.y]!.color;

    // Any 2x2 square containing this block counts
    for (final dr in [-1, 0]) {
      for (final dc in [-1, 0]) {
        if (_isSquareAt(pos.x + dr, pos.y + dc)) return true;
      }
    }

    // Check horizontal
    int count = 1;
    for (
      int c = pos.y - 1;
      c >= 0 && _grid[pos.x][c]?.color == color && !_grid[pos.x][c]!.isEmpty;
      c--
    ) {
      count++;
    }
    for (
      int c = pos.y + 1;
      c < _gridSize &&
          _grid[pos.x][c]?.color == color &&
          !_grid[pos.x][c]!.isEmpty;
      c++
    ) {
      count++;
    }
    if (count >= _minMatch) {
      return true;
    }

    // Check vertical
    count = 1;
    for (
      int r = pos.x - 1;
      r >= 0 && _grid[r][pos.y]?.color == color && !_grid[r][pos.y]!.isEmpty;
      r--
    ) {
      count++;
    }
    for (
      int r = pos.x + 1;
      r < _gridSize &&
          _grid[r][pos.y]?.color == color &&
          !_grid[r][pos.y]!.isEmpty;
      r++
    ) {
      count++;
    }
    if (count >= _minMatch) {
      return true;
    }

    // T, L and + shapes: the swap may have completed a run that is not through [pos].
    return _findJoinedRuns().contains(pos);
  }

  void _swapBlocks(Point<int> pos1, Point<int> pos2) {
    final temp = _grid[pos1.x][pos1.y];
    _grid[pos1.x][pos1.y] = _grid[pos2.x][pos2.y];
    _grid[pos2.x][pos2.y] = temp;
  }

  // Modified to return bool indicating if any matches were processed
  Future<bool> _processMatchesAndCollapse({bool isInitialSetup = false}) async {
    bool matchesFoundThisIteration;
    int cascadeCount = 0;
    bool anyMatchesProcessedInTurn = false;
    bool needsUIUpdate = false;

    do {
      matchesFoundThisIteration = false;
      List<Point<int>> allMatchedPositions = _findAllMatches();

      if (allMatchedPositions.isNotEmpty) {
        matchesFoundThisIteration = true;
        anyMatchesProcessedInTurn =
            true; // Mark that at least one match was found in this whole turn/cascade
        cascadeCount++;

        for (var pos in allMatchedPositions) {
          if (_grid[pos.x][pos.y] != null && !_grid[pos.x][pos.y]!.isMatched) {
            _grid[pos.x][pos.y]!.isMatched = true;
            if (!isInitialSetup) {
              _score += 10 * cascadeCount; // Simple score, bonus for cascades
              if (!_gameWon && _score >= widget.level.targetScore) {
                _gameWon = true;
                await _updateBestMovesIfNeeded();
                return false; // Stop further processing after win
              }
            }
          }
        }
        needsUIUpdate = true;

        if (!isInitialSetup && !widget.testMode) {
          await Future.delayed(
            const Duration(milliseconds: 60),
          ); // Visual delay
        }

        _clearMarkedBlocks();
        needsUIUpdate = true;

        if (!isInitialSetup && !widget.testMode) {
          await Future.delayed(
            const Duration(milliseconds: 60),
          ); // Visual delay
        }

        _applyCollapse();
        needsUIUpdate = true;

        if (!isInitialSetup && !widget.testMode) {
          await Future.delayed(
            const Duration(milliseconds: 60),
          ); // Visual delay
        }

        _refillGrid();
        needsUIUpdate = true;
      }
    } while (matchesFoundThisIteration && cascadeCount < 10);

    // Batch all UI updates into a single setState call
    if (needsUIUpdate && mounted) {
      setState(() {});
    }

    return anyMatchesProcessedInTurn;
  }

  List<Point<int>> _findAllMatches() {
    List<Point<int>> matchedPositions = [];
    if (_grid.isEmpty) return matchedPositions;

    // Horizontal matches
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c <= _gridSize - _minMatch; c++) {
        // Iterate up to where a match can start
        if (_grid[r][c] == null || _grid[r][c]!.isEmpty) {
          continue;
        }
        Color currentColor = _grid[r][c]!.color;
        List<Point<int>> currentHorizontalMatch = [Point(r, c)];
        for (int k = 1; k < _minMatch; k++) {
          if (_grid[r][c + k] == null ||
              _grid[r][c + k]!.isEmpty ||
              _grid[r][c + k]!.color != currentColor) {
            currentHorizontalMatch.clear(); // Not a match of _minMatch
            break;
          }
          currentHorizontalMatch.add(Point(r, c + k));
        }

        if (currentHorizontalMatch.length >= _minMatch) {
          // Extend the match
          for (int k = c + _minMatch; k < _gridSize; k++) {
            if (_grid[r][k] != null &&
                !_grid[r][k]!.isEmpty &&
                _grid[r][k]!.color == currentColor) {
              currentHorizontalMatch.add(Point(r, k));
            } else {
              break;
            }
          }
          matchedPositions.addAll(currentHorizontalMatch);
          c +=
              currentHorizontalMatch.length -
              1; // Skip already checked blocks in this row
        }
      }
    }

    // Vertical matches
    for (int c = 0; c < _gridSize; c++) {
      for (int r = 0; r <= _gridSize - _minMatch; r++) {
        if (_grid[r][c] == null || _grid[r][c]!.isEmpty) {
          continue;
        }
        Color currentColor = _grid[r][c]!.color;
        List<Point<int>> currentVerticalMatch = [Point(r, c)];
        for (int k = 1; k < _minMatch; k++) {
          if (_grid[r + k][c] == null ||
              _grid[r + k][c]!.isEmpty ||
              _grid[r + k][c]!.color != currentColor) {
            currentVerticalMatch.clear();
            break;
          }
          currentVerticalMatch.add(Point(r + k, c));
        }

        if (currentVerticalMatch.length >= _minMatch) {
          // Extend the match
          for (int k = r + _minMatch; k < _gridSize; k++) {
            if (_grid[k][c] != null &&
                !_grid[k][c]!.isEmpty &&
                _grid[k][c]!.color == currentColor) {
              currentVerticalMatch.add(Point(k, c));
            } else {
              break;
            }
          }
          matchedPositions.addAll(currentVerticalMatch);
          r +=
              currentVerticalMatch.length -
              1; // Skip already checked blocks in this column
        }
      }
    }
    // 2x2 squares always count, whatever the Min Match setting is.
    for (int r = 0; r < _gridSize - 1; r++) {
      for (int c = 0; c < _gridSize - 1; c++) {
        if (_isSquareAt(r, c)) {
          matchedPositions.addAll([
            Point(r, c),
            Point(r, c + 1),
            Point(r + 1, c),
            Point(r + 1, c + 1),
          ]);
        }
      }
    }
    matchedPositions.addAll(_findJoinedRuns());
    // Remove duplicates efficiently
    return matchedPositions.toSet().toList();
  }

  /// Horizontal and vertical runs of 3+ that cross (T, L, +) join into one
  /// shape, which matches when it has at least [_minMatch] distinct cells.
  List<Point<int>> _findJoinedRuns() {
    if (_minMatch <= 3) return const []; // plain runs already match
    final horizontalRuns = <Set<Point<int>>>[];
    final verticalRuns = <Set<Point<int>>>[];
    for (final horizontal in [true, false]) {
      for (int a = 0; a < _gridSize; a++) {
        Point<int> pt(int b) => horizontal ? Point(a, b) : Point(b, a);
        Block? blk(int b) => _grid[pt(b).x][pt(b).y];
        int b = 0;
        while (b < _gridSize) {
          final first = blk(b);
          if (first == null || first.isEmpty) {
            b++;
            continue;
          }
          int e = b + 1;
          while (e < _gridSize && blk(e) != null && !blk(e)!.isEmpty && blk(e)!.color == first.color) {
            e++;
          }
          if (e - b >= 3) (horizontal ? horizontalRuns : verticalRuns).add({for (int i = b; i < e; i++) pt(i)});
          b = e;
        }
      }
    }
    final joined = <Point<int>>[];
    for (final h in horizontalRuns) {
      for (final v in verticalRuns) {
        if (h.intersection(v).isEmpty) continue; // sharing a cell means same colour
        final shape = h.union(v);
        if (shape.length >= _minMatch) joined.addAll(shape);
      }
    }
    return joined;
  }

  void _clearMarkedBlocks() {
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        if (_grid[r][c]?.isMatched == true) {
          _grid[r][c] = Block.empty();
          _grid[r][c]!.isMatched = false; // Reset the flag
        }
      }
    }
  }

  void _applyCollapse() {
    for (int col = 0; col < _gridSize; col++) {
      List<Block?> tempColumn = [];
      // Collect non-empty blocks
      for (int row = _gridSize - 1; row >= 0; row--) {
        if (_grid[row][col] != null && !_grid[row][col]!.isEmpty) {
          tempColumn.add(_grid[row][col]);
        }
      }
      // Fill the rest with empty blocks
      while (tempColumn.length < _gridSize) {
        tempColumn.add(Block.empty());
      }
      // Reverse to fill from top to bottom (simulating collapse downwards)
      for (int row = 0; row < _gridSize; row++) {
        _grid[row][col] = tempColumn[_gridSize - 1 - row];
      }
    }
  }

  void _refillGrid() {
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        if (_grid[r][c]?.isEmpty == true) {
          _grid[r][c] = Block(
            color:
                widget.level.availableColors[_random.nextInt(
                  widget.level.availableColors.length,
                )],
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_grid.isEmpty || _grid[0][0] == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Collapse - ${widget.level.name}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    const double reservedHeight = 220; // info + controls + padding
    final double maxGridHeight = screenHeight - reservedHeight;
    final double maxGridWidth = screenWidth - 32.0;
    final double tileSize = max(20.0, min(maxGridWidth / _gridSize, maxGridHeight / _gridSize));
    _tileSize = tileSize;

    final movesUsed = widget.level.moves - _movesLeft;

    return BaseGameScreen(
      title: 'Collapse - ${widget.level.name}',
      gameId: 'collapse',
      gameConfig: {
        'gridSize': widget.level.gridSize,
        'mechanic': widget.level.mechanic.toString().split('.').last,
        'targetScore': widget.level.targetScore,
        'minMatchCount': widget.level.minMatchCount,
        'moves': widget.level.moves,
      },
      highScoreLabel: 'Best Moves',
      highScoreValue: bestScore?.toString() ?? '-',
      currentScoreLabel: 'Points',
      currentScoreValue: '$_score',
      statusText: 'Moves: $movesUsed / ${widget.level.moves}  |  Target: ${widget.level.targetScore}',
      isGameWon: _gameWon,
      isGameOver: _movesLeft == 0 && !_gameWon,
      victoryMessage: 'Target Reached in $movesUsed moves!',
      gameOverMessage: 'Out of moves! Final Score: $_score',
      onReset: _initializeGrid,
      isGameInProgress: movesUsed > 0 && !_gameWon,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: tileSize * _gridSize,
                height: tileSize * _gridSize,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[800],
                ),
                child: Stack(
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _gridSize * _gridSize,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _gridSize,
                      ),
                      itemBuilder: (context, index) {
                        final row = index ~/ _gridSize;
                        final col = index % _gridSize;
                        final block = _grid[row][col];
                        bool isCurrentlyDragged =
                            _currentlyDraggedBlockPosition?.x == row &&
                            _currentlyDraggedBlockPosition?.y == col;
                        return Semantics(
                          label: 'Row ${row + 1}, column ${col + 1}, ${block == null || block.isEmpty ? "empty" : colorName(block.color)}',
                          customSemanticsActions: block == null || block.isEmpty
                              ? null
                              : {
                                  const CustomSemanticsAction(label: 'Swap left'): () => _semanticSwap(row, col, 0, -1),
                                  const CustomSemanticsAction(label: 'Swap right'): () => _semanticSwap(row, col, 0, 1),
                                  const CustomSemanticsAction(label: 'Swap up'): () => _semanticSwap(row, col, -1, 0),
                                  const CustomSemanticsAction(label: 'Swap down'): () => _semanticSwap(row, col, 1, 0),
                                },
                          child: GestureDetector(
                          onHorizontalDragStart: (details) =>
                              _handleDragStart(details, row, col),
                          onHorizontalDragUpdate: (details) =>
                              _handleDragUpdate(details, row, col),
                          onHorizontalDragEnd: _handleDragEnd,
                          onVerticalDragStart: (details) =>
                              _handleDragStart(details, row, col),
                          onVerticalDragUpdate: (details) =>
                              _handleDragUpdate(details, row, col),
                          onVerticalDragEnd: _handleDragEnd,
                          child: Opacity(
                            opacity: isCurrentlyDragged ? 0.5 : 1.0,
                            child: AnimatedContainer(
                              key: block?.id,
                              duration: const Duration(milliseconds: 100),
                              margin: const EdgeInsets.all(1.5),
                              decoration: BoxDecoration(
                                color: block?.isEmpty == true
                                    ? Colors.grey.shade300
                                    : block?.color ?? Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                                boxShadow: block?.isMatched == true
                                    ? [
                                        BoxShadow(
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
                                          spreadRadius: 2,
                                          blurRadius: 3,
                                        ),
                                      ]
                                    : [],
                              ),
                            ),
                          ),
                        ),
                        );
                      },
                    ),
                    if (_currentlyDraggedBlockPosition != null &&
                        _grid[_currentlyDraggedBlockPosition!.x][_currentlyDraggedBlockPosition!.y] != null)
                      Positioned(
                        left: (_currentlyDraggedBlockPosition!.y * tileSize) + (_dragDirection == 'horizontal' ? _currentDragOffset.dx : 0),
                        top: (_currentlyDraggedBlockPosition!.x * tileSize) + (_dragDirection == 'vertical' ? _currentDragOffset.dy : 0),
                        child: Container(
                          width: tileSize - 3,
                          height: tileSize - 3,
                          margin: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            color: _grid[_currentlyDraggedBlockPosition!.x][_currentlyDraggedBlockPosition!.y]!.color,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.white,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 5,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Drag to swap adjacent blocks to form matches!",
                style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
