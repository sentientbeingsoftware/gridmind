import 'package:flutter/material.dart';

/// Enum defining different collapse mechanics for the game
/// Each mechanic determines how blocks fall when matches are cleared
/// This adds variety and different strategic considerations to gameplay
enum CollapseMechanic {
  fromTop, // Blocks fall from the top of the grid
  fromBottom, // Blocks fall from the bottom of the grid
  fromLeft, // Blocks fall from the left side of the grid
  fromRight, // Blocks fall from the right side of the grid
}

/// Complete list of available colors for block generation
/// Provides a wide variety of colors for diverse and visually appealing gameplay
const List<Color> kAllPossibleBlockColors = [
  Colors.red,
  Colors.green,
  Colors.blue,
  Colors.yellow,
  Colors.purple,
  Colors.orange,
  Colors.cyan,
  Colors.pink,
  Colors.teal,
  Colors.amber,
  Colors.indigo,
  Colors.brown,
  Colors.lime,
  Colors.lightBlue,
  Colors.deepPurple,
  Colors.lightGreen,
  Colors.deepOrange,
  Colors.blueGrey,
];

/// Configuration class for a Collapse game level
/// Contains all the parameters that define how a level plays
/// This allows for easy customization and level creation
class CollapseLevel {
  /// Human-readable name for the level
  final String name;

  /// Numeric identifier for the level (0 for custom levels)
  final int levelNumber;

  /// Size of the game grid (e.g., 8 means 8x8 grid)
  final int gridSize;

  /// How blocks collapse when matches are cleared
  final CollapseMechanic mechanic;

  /// Target score to achieve for level completion
  final int targetScore;

  /// Colors available for block generation in this level
  final List<Color> availableColors;

  /// Minimum number of blocks that must match to clear them
  /// Higher values create more challenging gameplay
  final int minMatchCount;
  final int moves;

  CollapseLevel({
    required this.name,
    required this.levelNumber,
    required this.gridSize,
    required this.mechanic,
    required this.targetScore,
    required this.availableColors,
    required this.minMatchCount,
    required this.moves,
  });
} 