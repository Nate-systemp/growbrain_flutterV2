import 'package:flutter/material.dart';
import 'dart:async';

/// Mixin that provides pause/resume functionality for games
mixin GamePauseMixin<T extends StatefulWidget> on State<T> {
  bool _gamePaused = false;
  Timer? _gameTimer;
  
  bool get isGamePaused => _gamePaused;
  
  /// Pause the game - stops all timers and game logic
  void pauseGame() {
    if (!_gamePaused) {
      _gamePaused = true;
      _pauseGameLogic();
    }
  }
  
  /// Resume the game - restarts timers and game logic
  void resumeGame() {
    if (_gamePaused) {
      _gamePaused = false;
      _resumeGameLogic();
    }
  }
  
  /// Override this method in your game to implement pause logic
  void _pauseGameLogic() {
    // Override in game implementations
  }
  
  /// Override this method in your game to implement resume logic
  void _resumeGameLogic() {
    // Override in game implementations
  }
  
  /// Helper method to pause a timer
  void pauseTimer(Timer? timer) {
    timer?.cancel();
  }
  
  /// Helper method to create a pausable timer
  Timer createPausableTimer(Duration duration, void Function() callback) {
    return Timer.periodic(duration, (timer) {
      if (!_gamePaused) {
        callback();
      }
    });
  }
  
  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }
}
