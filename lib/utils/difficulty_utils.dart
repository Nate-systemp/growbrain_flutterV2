/// Utility functions for handling difficulty levels across games
class DifficultyUtils {
  /// Normalizes any difficulty input to the standard system
  static String normalizeDifficulty(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
      case 'start':
      case 'starter':
        return 'Starter';
      case 'medium':
      case 'grow':
      case 'growing':
        return 'Growing';
      case 'hard':
      case 'challenge':
      case 'challenged':
      case 'challange': // tolerate common typo
        return 'Challenged';
      default:
        return 'Starter';
    }
  }

  /// Gets display name (same as normalize now)
  static String getDifficultyDisplayName(String difficulty) {
    return normalizeDifficulty(difficulty);
  }

  /// Converts from any format to normalized format
  static String getDifficultyInternalValue(String displayName) {
    return normalizeDifficulty(displayName);
  }
}
