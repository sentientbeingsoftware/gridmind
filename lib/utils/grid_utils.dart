/// Utility functions for grid-based data structures and comparisons.
class GridUtils {
  /// Checks if two two-dimensional grids (lists of lists) are equal in shape and content.
  /// Returns `true` if they are identical, `false` otherwise.
  static bool areGridsEqual<T>(List<List<T>> grid1, List<List<T>> grid2) {
    if (grid1.length != grid2.length) return false;
    for (int i = 0; i < grid1.length; i++) {
      if (grid1[i].length != grid2[i].length) return false;
      for (int j = 0; j < grid1[i].length; j++) {
        if (grid1[i][j] != grid2[i][j]) return false;
      }
    }
    return true;
  }

  /// Creates a deep copy of a two-dimensional grid (list of lists).
  static List<List<T>> cloneGrid<T>(List<List<T>> grid) {
    return List.generate(grid.length, (r) => List.from(grid[r]));
  }
}
