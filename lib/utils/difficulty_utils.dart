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
        return 'Easy';
      case 'growing':
        return 'Medium';
      case 'challenged':
        return 'Hard';
      default:
        return 'Easy';
    }
  }
}
