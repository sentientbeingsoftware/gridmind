/// Enum defining the speed options for pattern-based games like Simon
/// This controls how fast patterns are displayed to the player
enum PatternSpeed { slow, normal, fast }

/// Extension to provide human-readable display names for pattern speeds
/// Converts enum values to user-friendly text for the dropdown
extension PatternSpeedExtension on PatternSpeed {
  String get displayName {
    switch (this) {
      case PatternSpeed.slow:
        return 'Slow';
      case PatternSpeed.normal:
        return 'Normal';
      case PatternSpeed.fast:
        return 'Fast';
    }
  }
} 