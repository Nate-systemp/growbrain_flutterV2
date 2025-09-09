/// Utility functions for handling difficulty levels across games
class DifficultyUtils {
  /// Converts internal difficulty values to display names
  static String getDifficultyDisplayName(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return 'Starter';
      case 'medium':
        return 'Growing';
      case 'hard':
        return 'Challenged';
      default:
        return 'Starter';
    }
  }

  /// Converts display names back to internal values (if needed)
  static String getDifficultyInternalValue(String displayName) {
    switch (displayName.toLowerCase()) {
      case 'starter':
      case 'start':
        return 'Easy';
      case 'growing':
      case 'grow':
        return 'Medium';
      case 'challenged':
      case 'challenge':
      case 'challange': // tolerate common typo
        return 'Hard';
      default:
        // If caller passes internal values already (easy/medium/hard), pass through
        switch (displayName.toLowerCase()) {
          case 'easy':
            return 'Easy';
          case 'medium':
            return 'Medium';
          case 'hard':
            return 'Hard';
          default:
            return 'Easy';
        }
    }
  }
}
