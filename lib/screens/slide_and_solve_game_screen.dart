// lib/slide_and_solve_game_screen.dart
import 'package:flutter/material.dart';
import 'dart:math';
import '../services/app_persistence_service.dart';
import '../models/slide_and_solve_models.dart';
import '../utils/grid_utils.dart';
import 'base_game_screen.dart';
import 'mixins/config_high_score_mixin.dart';

/// Main game screen for the Slide and Solve puzzle game
/// Players must rearrange colored tiles by sliding rows and columns
/// to match a target pattern configuration
class SlideAndSolveGameScreen extends StatefulWidget {
  /// Size of the game grid (e.g., 3 means 3x3 grid)
  /// Larger grids increase puzzle complexity and difficulty
  final int gridSize;
  final List<Color>? testColors;
  final bool skipInitialDelay;
  final bool testMode;

  const SlideAndSolveGameScreen({
    super.key,
    required this.gridSize,
    this.testColors,
    this.skipInitialDelay = false,
    this.testMode = false,
  });

  @override
  State<SlideAndSolveGameScreen> createState() =>
      _SlideAndSolveGameScreenState();
}

/// State class for the Slide and Solve game screen
/// Manages game logic, grid manipulation, pattern generation, and UI state
class _SlideAndSolveGameScreenState extends State<SlideAndSolveGameScreen> with ConfigHighScoreMixin<SlideAndSolveGameScreen> {
  @override
  String get highScoreGameId => 'slideandsolve';
  @override
  bool get highScoreLowerIsBetter => true;
  @override
  Map<String, dynamic> get highScoreConfig => {
        'gridSize': widget.gridSize.toDouble(),
      };
  /// Current state of the game grid that the player is manipulating
  /// Each element represents a colored tile
  List<List<Color>>? currentGrid;
  
  /// Target pattern that the player must achieve
  /// This is the goal configuration for winning the game
  List<List<Color>>? targetPattern;
  
  /// The color palette to use for this game, loaded from settings
  List<Color>? _palette;
  
  /// Number of moves the player has made
  /// Used for scoring and tracking progress
  int moves = 0;
  
  /// Whether the puzzle has been solved
  /// Controls game state and UI updates
  bool isSolved = false;
  
  /// Random number generator for pattern generation and shuffling
  final Random random = Random();

  /// Drag gesture tracking variables for row/column sliding
  /// These enable touch-based manipulation of the grid
  DragStartDetails? _dragStartDetails;
  Offset _dragAccumulatedDelta = Offset.zero;
  
  /// Minimum distance required for a drag to be considered a slide
  /// Prevents accidental moves from small touches
  static const double _minDragExtent = 20.0;


  @override
  void initState() {
    super.initState();
    _loadBestMoves();
    _loadPaletteAndInit();
  }

  Future<void> _loadPaletteAndInit() async {
    if (widget.testColors != null) {
      setState(() {
        _palette = widget.testColors;
        targetPattern = _generatePattern(widget.gridSize, overrideColors: widget.testColors);
        currentGrid = _generateShuffledGrid(List.from(targetPattern!), 0); // No shuffle for tests
      });
    } else if (widget.testMode || widget.skipInitialDelay) {
      List<Color> pal = await AppPersistenceService.getPaletteForGame(colorCount: widget.gridSize);
      if (!mounted) return;
      setState(() {
        _palette = pal;
        targetPattern = _generatePattern(widget.gridSize, overrideColors: pal);
        currentGrid = _generateShuffledGrid(List.from(targetPattern!), 0); // No shuffle for tests
      });
    } else {
      List<Color> pal = await AppPersistenceService.getPaletteForGame(colorCount: widget.gridSize);
      if (!mounted) return;
      setState(() {
        _palette = pal;
      });
      _initColorsAndGame();
    }
  }

  Future<void> _initColorsAndGame() async {
    // Palette is already loaded in _palette
    if (_palette == null) {
      List<Color> pal = await AppPersistenceService.getPaletteForGame(colorCount: widget.gridSize);
      if (!mounted) return;
      setState(() {
        _palette = pal;
      });
    }
    initializeGame();
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
    if (isSolved) await submitScore(moves);
  }

  /// Initializes the game by generating the target pattern and shuffled grid
  /// Sets up the initial game state for the player
  void initializeGame() {
    setState(() {
      moves = 0;
      isSolved = false;
      // Generate the target pattern for this grid size using the loaded palette
      targetPattern = _generatePattern(widget.gridSize, overrideColors: _palette);
      // Create a shuffled version of the target pattern
      int shuffles = widget.gridSize * widget.gridSize * 2;
      shuffles = shuffles < 15 ? 15 : shuffles; // Minimum shuffles for playability
      currentGrid = _generateShuffledGrid(targetPattern!, shuffles);
      while (GridUtils.areGridsEqual(currentGrid!, targetPattern!)) {
        currentGrid = _generateShuffledGrid(targetPattern!, shuffles);
      }
    });
  }

  /// Generates a target pattern for the specified grid size
  /// Creates visually distinct and challenging patterns for different grid sizes
  List<List<Color>> _generatePattern(int size, {List<Color>? overrideColors}) {
    List<Color> availableColors = overrideColors != null ? List.from(overrideColors) : List.from(kGameColors);
    availableColors.shuffle(random);
    List<List<Color>> pattern = List.generate(
      size,
      (_) => List.filled(size, Colors.grey),
    );
    int colorIndex = 0;
    int uniqueColorCounter = 0;

    // Create specific patterns for common grid sizes
    if (size == 3 && availableColors.length >= 4) {
      return [
        [availableColors[0], availableColors[1], availableColors[2]],
        [availableColors[3], availableColors[0], availableColors[1]],
        [availableColors[2], availableColors[3], availableColors[0]],
      ];
    } else if (size == 4 && availableColors.length >= 6) {
      return [
        [availableColors[0], availableColors[1], availableColors[2], availableColors[3]],
        [availableColors[4], availableColors[5], availableColors[0], availableColors[1]],
        [availableColors[2], availableColors[3], availableColors[4], availableColors[5]],
        [availableColors[0], availableColors[1], availableColors[2], availableColors[3]],
      ];
    } else if (size == 5 && availableColors.length >= 5) {
      List<List<Color>> generatedPattern = List.generate(
        size,
        (_) => List.filled(size, Colors.transparent),
      );
      for (int i = 0; i < size; i++) {
        for (int j = 0; j < size; j++) {
          generatedPattern[i][j] =
              availableColors[(i * size + j + i) % availableColors.length];
        }
      }
      return generatedPattern;
    }
    // Generic pattern generation for other grid sizes
    for (int i = 0; i < size; i++) {
      for (int j = 0; j < size; j++) {
        if (uniqueColorCounter < availableColors.length) {
          pattern[i][j] = availableColors[uniqueColorCounter++];
        } else {
          pattern[i][j] = availableColors[colorIndex % availableColors.length];
        }
        colorIndex++;
      }
    }
    return pattern;
  }

  /// Creates a shuffled version of the target pattern for the starting grid
  /// Applies random row and column slides to create a solvable puzzle
  List<List<Color>> _generateShuffledGrid(
    List<List<Color>> initialGrid,
    int shuffles,
  ) {
    // Create a deep copy of the initial grid
    List<List<Color>> grid = GridUtils.cloneGrid(initialGrid);
    
    // Apply random shuffles
    for (int i = 0; i < shuffles; i++) {
      bool slideRow = random.nextBool(); // Randomly choose row or column
      int index = random.nextInt(widget.gridSize);
      bool slidePositive = random.nextBool(); // Randomly choose direction
      
      if (slideRow) {
        _performSlideRow(grid, index, slidePositive, false);
      } else {
        _performSlideColumn(grid, index, slidePositive, false);
      }
    }
    return grid;
  }

  /// Performs a row slide operation on the specified grid
  /// Moves all tiles in a row left or right by one position
  void _performSlideRow(
    List<List<Color>> grid,
    int rowIndex,
    bool slideRight,
    bool updateStateAndCheck,
  ) {
    List<Color> row = grid[rowIndex];
    if (row.isEmpty) return; // Safety check
    
    if (slideRight) {
      // Move last element to the beginning
      Color last = row.removeLast();
      row.insert(0, last);
    } else {
      // Move first element to the end
      Color first = row.removeAt(0);
      row.add(first);
    }
    
    if (updateStateAndCheck) {
      setState(() {
        moves++;
        _checkIfSolved();
      });
    }
  }

  /// Performs a column slide operation on the specified grid
  /// Moves all tiles in a column up or down by one position
  void _performSlideColumn(
    List<List<Color>> grid,
    int colIndex,
    bool slideDown,
    bool updateStateAndCheck,
  ) {
    if (grid.isEmpty || grid[0].isEmpty || colIndex >= grid[0].length) {
      return; // Safety check
    }

    // Extract the column as a list for manipulation
    List<Color> columnSnapshot = List.generate(
      widget.gridSize,
      (i) => grid[i][colIndex],
    );
    if (columnSnapshot.isEmpty) return;

    if (slideDown) {
      // Move last element to the top
      Color last = columnSnapshot.removeLast();
      columnSnapshot.insert(0, last);
    } else {
      // Move first element to the bottom
      Color first = columnSnapshot.removeAt(0);
      columnSnapshot.add(first);
    }
    
    // Update the grid with the modified column
    for (int i = 0; i < widget.gridSize; i++) {
      grid[i][colIndex] = columnSnapshot[i];
    }
    
    if (updateStateAndCheck) {
      setState(() {
        moves++;
        _checkIfSolved();
      });
    }
  }

  /// Initiates a row slide operation from player input
  /// Wrapper that prevents moves after the puzzle is solved
  void _slideRow(int rowIndex, bool slideRight) {
    if (isSolved) {
      return;
    }
    _performSlideRow(currentGrid!, rowIndex, slideRight, true);
  }

  /// Initiates a column slide operation from player input
  /// Wrapper that prevents moves after the puzzle is solved
  void _slideColumn(int colIndex, bool slideDown) {
    if (isSolved) {
      return;
    }
    _performSlideColumn(currentGrid!, colIndex, slideDown, true);
  }

  /// Checks if the current grid matches the target pattern
  /// Triggers win condition if the puzzle is solved
  void _checkIfSolved() {
    if (GridUtils.areGridsEqual(currentGrid!, targetPattern!)) {
      setState(() {
        isSolved = true;
      });
      _updateBestMovesIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_palette == null || targetPattern == null || currentGrid == null || targetPattern!.isEmpty || currentGrid!.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // Calculate screen dimensions and available space
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    // --- Tile Size Calculation ---
    // Estimate space needed for non-grid elements (text, spacing, etc.)
    double estimatedNonGridHeight = 220;
    
    // Estimate target grid height
    double targetTileSize = 40.0;

    double cellMargins = 4.0; // Combined margin for each cell

    // Calculate tile size based on available width
    double calculatedTileSizeW =
        (screenWidth -
            32.0 -
            (widget.gridSize * cellMargins)) /
        widget.gridSize;

    // Calculate tile size based on available height
    double calculatedTileSizeH =
        (screenHeight - estimatedNonGridHeight - (widget.gridSize * cellMargins)) /
        widget.gridSize;

    // Ensure tile sizes are positive
    calculatedTileSizeW = calculatedTileSizeW > 0 ? calculatedTileSizeW : 30.0;
    calculatedTileSizeH = calculatedTileSizeH > 0 ? calculatedTileSizeH : 30.0;

    // Use the smaller of width or height to ensure tiles fit
    final double mainTileSize = min(
      calculatedTileSizeW,
      calculatedTileSizeH,
    ).floorToDouble();

    return BaseGameScreen(
      title: 'Slide and Solve',
      gameId: 'slideandsolve',
      gameConfig: {
        'gridSize': widget.gridSize,
      },
      highScoreLabel: 'Best',
      highScoreValue: bestScore != null ? '$bestScore moves' : '-',
      currentScoreLabel: 'Moves',
      currentScoreValue: '$moves',
      statusText: 'Drag rows or columns to match the target pattern',
      isGameWon: isSolved,
      victoryMessage: 'Solved in $moves moves!',
      onReset: initializeGame,
      isGameInProgress: moves > 0 && !isSolved,
      topHudExtra: Column(
        children: [
          const Text(
            'Target Pattern:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          _buildGridDisplay(
            targetPattern!,
            isTarget: true,
            tileSize: targetTileSize,
            currentGridSize: widget.gridSize,
          ),
        ],
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (currentGrid!.isNotEmpty)
                _buildMainGrid(mainTileSize),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainGrid(double tileSize) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.gridSize, (rowIndex) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(widget.gridSize, (colIndex) {
              return GestureDetector(
                onHorizontalDragStart: (details) {
                  if (isSolved) return;
                  _dragStartDetails = details;
                  _dragAccumulatedDelta = Offset.zero;
                },
                onHorizontalDragUpdate: (details) {
                  if (isSolved || _dragStartDetails == null) return;
                  _dragAccumulatedDelta += details.delta;
                },
                onHorizontalDragEnd: (details) {
                  if (isSolved || _dragStartDetails == null) return;
                  if (_dragAccumulatedDelta.dx.abs() > _minDragExtent) {
                    bool slideRight = _dragAccumulatedDelta.dx > 0;
                    _slideRow(rowIndex, slideRight);
                  }
                  _dragStartDetails = null;
                  _dragAccumulatedDelta = Offset.zero;
                },
                onVerticalDragStart: (details) {
                  if (isSolved) return;
                  _dragStartDetails = details;
                  _dragAccumulatedDelta = Offset.zero;
                },
                onVerticalDragUpdate: (details) {
                  if (isSolved || _dragStartDetails == null) return;
                  _dragAccumulatedDelta += details.delta;
                },
                onVerticalDragEnd: (details) {
                  if (isSolved || _dragStartDetails == null) return;
                  if (_dragAccumulatedDelta.dy.abs() > _minDragExtent) {
                    bool slideDown = _dragAccumulatedDelta.dy > 0;
                    _slideColumn(colIndex, slideDown);
                  }
                  _dragStartDetails = null;
                  _dragAccumulatedDelta = Offset.zero;
                },
                child: _buildGridCell(
                  currentGrid![rowIndex][colIndex],
                  tileSize,
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  // _buildGridCell remains the same (it just builds the visual representation of a cell)
  Widget _buildGridCell(Color color, double tileSize) {
    return Container(
      width: tileSize,
      height: tileSize,
      margin: const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.black.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // Renamed _buildGrid to _buildGridDisplay to avoid confusion and pass currentGridSize
  Widget _buildGridDisplay(
    List<List<Color>> gridData, {
    bool isTarget = false,
    required double tileSize,
    required int currentGridSize,
  }) {
    if (gridData.isEmpty || gridData.any((row) => row.isEmpty)) {
      // Return a placeholder if gridData is not ready
      return Text(isTarget ? "Loading target..." : "Loading grid...");
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(currentGridSize, (row) {
        // << USE currentGridSize
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(currentGridSize, (col) {
            // << USE currentGridSize
            // Safety check for gridData dimensions
            Color cellColor = Colors.grey; // Default color
            if (row < gridData.length && col < gridData[row].length) {
              cellColor = gridData[row][col];
            }
            return Container(
              width: tileSize,
              height: tileSize,
              margin: const EdgeInsets.all(2.0),
              decoration: BoxDecoration(
                color: cellColor,
                border: Border.all(
                  color: Colors.black.withValues(alpha: isTarget ? 0.2 : 0.3),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        );
      }),
    );
  }
}
