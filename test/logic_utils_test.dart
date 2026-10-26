import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/utils/grid_utils.dart';

void main() {
  group('GridUtils Logic Tests', () {
    test('areGridsEqual returns true for identical grids', () {
      final grid1 = [
        [1, 2],
        [3, 4],
      ];
      final grid2 = [
        [1, 2],
        [3, 4],
      ];
      expect(GridUtils.areGridsEqual(grid1, grid2), isTrue);
    });

    test('areGridsEqual returns false for grids of different shapes', () {
      final grid1 = [
        [1, 2],
        [3, 4],
      ];
      final grid2 = [
        [1, 2, 5],
        [3, 4, 6],
      ];
      expect(GridUtils.areGridsEqual(grid1, grid2), isFalse);

      final grid3 = [
        [1, 2],
      ];
      expect(GridUtils.areGridsEqual(grid1, grid3), isFalse);
    });

    test('areGridsEqual returns false for different grid values', () {
      final grid1 = [
        [1, 2],
        [3, 4],
      ];
      final grid2 = [
        [1, 2],
        [3, 5],
      ];
      expect(GridUtils.areGridsEqual(grid1, grid2), isFalse);
    });

    test('cloneGrid returns a deep copy of the grid', () {
      final original = [
        [1, 2],
        [3, 4],
      ];
      final cloned = GridUtils.cloneGrid(original);

      // Verify values are identical
      expect(GridUtils.areGridsEqual(original, cloned), isTrue);

      // Verify that changing cloned does not change original
      cloned[0][0] = 99;
      expect(original[0][0], equals(1));
      expect(cloned[0][0], equals(99));
    });
  });
}
