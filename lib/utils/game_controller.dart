import 'package:flutter/material.dart';

/// Interface for game controllers that can be paused/resumed
abstract class GameController {
  void pauseGame();
  void resumeGame();
  bool get isPaused;
}

/// Widget that wraps games and provides pause/resume functionality
class GameWrapper extends StatefulWidget {
  final Widget child;
  final GameController? controller;
  
  const GameWrapper({
    Key? key,
    required this.child,
    this.controller,
  }) : super(key: key);
  
  @override
  State<GameWrapper> createState() => _GameWrapperState();
}

class _GameWrapperState extends State<GameWrapper> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Global game controller that can be accessed by the session flow manager
class GlobalGameController {
  static GameController? _currentController;
  
  static void setController(GameController controller) {
    _currentController = controller;
  }
  
  static void clearController() {
    _currentController = null;
  }
  
  static void pauseCurrentGame() {
    _currentController?.pauseGame();
  }
  
  static void resumeCurrentGame() {
    _currentController?.resumeGame();
  }
  
  static bool get isCurrentGamePaused => _currentController?.isPaused ?? false;
}
