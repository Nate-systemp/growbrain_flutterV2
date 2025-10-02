import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import '../utils/background_music_manager.dart';
import '../utils/sound_effects_manager.dart';
import '../utils/difficulty_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PuzzleGame extends StatefulWidget {
  final String difficulty;
  final Function({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })?
  onGameComplete;

  const PuzzleGame({Key? key, required this.difficulty, this.onGameComplete})
    : super(key: key);

  @override
  _PuzzleGameState createState() => _PuzzleGameState();
}

class PuzzleTile {
  final int value; // The number on the tile (0 for empty)
  int currentPosition; // Current position in the grid

  PuzzleTile({required this.value, required this.currentPosition});

  bool get isEmpty => value == 0;
}

class _PuzzleGameState extends State<PuzzleGame> with TickerProviderStateMixin {
  List<PuzzleTile> tiles = [];
  int gridSize = 3; // 3x3 for Starter
  int moves = 0;
  int timeElapsed = 0;
  bool gameStarted = false;
  bool gameCompleted = false;
  bool isPuzzleSolved = false;
  bool showNextGameButton = false; // Show after 2 minutes
  late DateTime startTime;
  Timer? gameTimer;
  Timer? nextGameTimer; // Timer for showing next game button
  String _normalizedDifficulty = 'Starter';

  // Countdown state
  bool showingCountdown = false;
  int countdownNumber = 3;

  // GO overlay
  bool showingGo = false;
  late final AnimationController _goController;
  late final Animation<double> _goOpacity;
  late final Animation<double> _goScale;

  // Status overlay (✓ or X)
  bool showingStatus = false;
  String overlayText = '';
  Color overlayColor = Colors.green;
  Color overlayTextColor = Colors.white;

  // Animation controllers
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;
  int? slidingFromIndex;
  int? slidingToIndex;
  bool isAnimating = false;

  Random random = Random();

  // Colors matching your app theme
  final Color primaryColor = Color(0xFF5B6F4A);
  final Color accentColor = Color(0xFFFFD740);
  final Color backgroundColor = Color(0xFFF5F5DC);
  final Color tileColor = Color(0xFF8B7355); // Brown color like in the image
  final Color tileTextColor = Color(0xFF3E2723); // Dark brown for numbers
  final Color emptyTileColor = Color(0xFF3E2723); // Very dark brown for empty

  @override
  void initState() {
    super.initState();
    // Initialize animation controller
    _slideController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    // Initialize GO animation controller
    _goController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _goOpacity = CurvedAnimation(parent: _goController, curve: Curves.easeInOut);
    _goScale = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(parent: _goController, curve: Curves.easeOutBack),
    );

    // Start background music for this game
    BackgroundMusicManager().startGameMusic('Puzzle');
    _initializeGame();
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    nextGameTimer?.cancel();
    _slideController.dispose();
    _goController.dispose();
    BackgroundMusicManager().stopMusic();
    super.dispose();
  }

  void _initializeGame() {
    // Normalize difficulty and set parameters
    _normalizedDifficulty = DifficultyUtils.normalizeDifficulty(widget.difficulty);

    switch (_normalizedDifficulty) {
      case 'Starter': // Start
        gridSize = 3; // 3x3 grid (8 tiles + 1 empty)
        break;
      case 'Growing': // Growing
        gridSize = 4; // 4x4 grid (15 tiles + 1 empty)
        break;
      case 'Challenged': // Challenged
        gridSize = 5; // 5x5 grid (24 tiles + 1 empty)
        break;
      default:
        gridSize = 3;
    }

    _initializePuzzle();
  }

  void _initializePuzzle() {
    tiles.clear();
    moves = 0;
    timeElapsed = 0;
    gameCompleted = false;
    isPuzzleSolved = false;

    // Create tiles (0 represents the empty space)
    int totalTiles = gridSize * gridSize;
    for (int i = 0; i < totalTiles; i++) {
      tiles.add(PuzzleTile(value: i, currentPosition: i));
    }

    // Shuffle the puzzle (only if starting a game)
    if (gameStarted) {
      _shufflePuzzle();
    }

    setState(() {});
  }

  void _shufflePuzzle() {
    // Perform valid moves to shuffle (ensures puzzle is solvable)
    int shuffleMoves =
        gridSize * gridSize * 10; // More shuffles for more challenging difficulty

    for (int i = 0; i < shuffleMoves; i++) {
      List<int> validMoves = _getValidMoves();
      if (validMoves.isNotEmpty) {
        int randomMove = validMoves[random.nextInt(validMoves.length)];
        _moveTile(randomMove, animate: false);
      }
    }

    // Reset move counter after shuffling
    moves = 0;
  }

  List<int> _getValidMoves() {
    int emptyIndex = tiles.indexWhere((tile) => tile.isEmpty);
    int emptyRow = emptyIndex ~/ gridSize;
    int emptyCol = emptyIndex % gridSize;
    List<int> validMoves = [];

    // Check up
    if (emptyRow > 0) {
      validMoves.add(emptyIndex - gridSize);
    }
    // Check down
    if (emptyRow < gridSize - 1) {
      validMoves.add(emptyIndex + gridSize);
    }
    // Check left
    if (emptyCol > 0) {
      validMoves.add(emptyIndex - 1);
    }
    // Check right
    if (emptyCol < gridSize - 1) {
      validMoves.add(emptyIndex + 1);
    }

    return validMoves;
  }

  bool _canMoveTile(int tileIndex) {
    int emptyIndex = tiles.indexWhere((tile) => tile.isEmpty);
    int tileRow = tileIndex ~/ gridSize;
    int tileCol = tileIndex % gridSize;
    int emptyRow = emptyIndex ~/ gridSize;
    int emptyCol = emptyIndex % gridSize;

    // Check if tile is adjacent to empty space
    bool sameRow = tileRow == emptyRow;
    bool sameCol = tileCol == emptyCol;
    bool adjacentRow = (tileRow - emptyRow).abs() == 1;
    bool adjacentCol = (tileCol - emptyCol).abs() == 1;

    return (sameRow && adjacentCol) || (sameCol && adjacentRow);
  }

  void _moveTile(int tileIndex, {bool animate = true}) {
    if (!_canMoveTile(tileIndex) || isAnimating) return;

    int emptyIndex = tiles.indexWhere((tile) => tile.isEmpty);

    if (animate && gameStarted) {
      // Set up sliding animation
      setState(() {
        isAnimating = true;
        slidingFromIndex = tileIndex;
        slidingToIndex = emptyIndex;
      });

      // Create slide animation - simple linear movement
      _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
      );

      // Start animation
      _slideController.reset();
      _slideController.forward().then((_) {
        // After animation completes, actually swap the tiles
        setState(() {
          PuzzleTile temp = tiles[tileIndex];
          tiles[tileIndex] = tiles[emptyIndex];
          tiles[emptyIndex] = temp;

          // Update positions
          tiles[tileIndex].currentPosition = tileIndex;
          tiles[emptyIndex].currentPosition = emptyIndex;

          moves++;

          // Reset animation state
          slidingFromIndex = null;
          slidingToIndex = null;
          isAnimating = false;

          // Play puzzle click sound effect
          SoundEffectsManager().playPuzzleClickSound();
          HapticFeedback.lightImpact();

          // Check if puzzle is solved
          if (_checkIfSolved()) {
            _onPuzzleSolved();
          }
        });
      });
    } else {
      // No animation - just swap tiles immediately
      setState(() {
        PuzzleTile temp = tiles[tileIndex];
        tiles[tileIndex] = tiles[emptyIndex];
        tiles[emptyIndex] = temp;

        // Update positions
        tiles[tileIndex].currentPosition = tileIndex;
        tiles[emptyIndex].currentPosition = emptyIndex;

        if (gameStarted && animate) {
          moves++;

          // Play puzzle click sound effect
          SoundEffectsManager().playPuzzleClickSound();
          HapticFeedback.lightImpact();

          // Check if puzzle is solved
          if (_checkIfSolved()) {
            _onPuzzleSolved();
          }
        }
      });
    }
  }

  bool _checkIfSolved() {
    for (int i = 0; i < tiles.length - 1; i++) {
      if (tiles[i].value != i + 1) {
        return false;
      }
    }
    // Last tile should be empty (value = 0)
    return tiles.last.isEmpty;
  }

  void _startGame() {
    setState(() {
      showingCountdown = true;
      countdownNumber = 3;
    });
    _showCountdown();
  }

  void _showCountdown() async {
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => countdownNumber = i);
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    if (mounted) {
      setState(() {
        showingCountdown = false;
        gameStarted = true;
        gameCompleted = false;
        startTime = DateTime.now();
        moves = 0;
        timeElapsed = 0;
      });

      _initializePuzzle();
      await _showGoOverlay();
      _startTimer();
    }
  }

  Future<void> _showGoOverlay() async {
    if (!mounted) return;
    setState(() => showingGo = true);
    await _goController.forward();
    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    await _goController.reverse();
    if (!mounted) return;
    setState(() => showingGo = false);
  }

  void _onPuzzleSolved() {
    setState(() {
      isPuzzleSolved = true;
      gameCompleted = true;
    });

    gameTimer?.cancel();

    // Play congratulations sound
    SoundEffectsManager().playSuccessWithVoice();
    HapticFeedback.heavyImpact();

    // Calculate accuracy based on optimal moves
    int optimalMoves = gridSize * gridSize * 2; // Rough estimate
    int accuracy = ((optimalMoves / moves.clamp(1, double.infinity)) * 100)
        .clamp(0, 100)
        .toInt();

    // Call completion callback
    if (widget.onGameComplete != null) {
      widget.onGameComplete!(
        accuracy: accuracy,
        completionTime: timeElapsed,
        challengeFocus: 'Problem-solving and spatial reasoning',
        gameName: 'Puzzle Game',
        difficulty: _normalizedDifficulty,
      );
    }

    _showCompletionDialog();
  }

  void _showCompletionDialog() {
    // Calculate accuracy based on optimal moves
    int optimalMoves = gridSize * gridSize * 2;
    int accuracy = ((optimalMoves / moves.clamp(1, double.infinity)) * 100)
        .clamp(0, 100)
        .toInt();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.30),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.celebration,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Amazing! 🌟',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatRow(Icons.touch_app, 'Moves', '$moves'),
                const SizedBox(height: 12),
                _buildStatRow(Icons.track_changes, 'Accuracy', '$accuracy%'),
                const SizedBox(height: 12),
                _buildStatRow(Icons.timer, 'Time', _formatTime(timeElapsed)),
              ],
            ),
          ),
          actions: [
            // Different actions for demo mode vs session mode
            if (widget.onGameComplete == null) ...[
              // Demo mode: Big, full-width buttons
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _resetGame();
                        },
                        icon: const Icon(Icons.refresh, size: 22),
                        label: const Text(
                          'Play Again',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          Navigator.of(context).pop(); // Exit game
                        },
                        icon: Icon(Icons.exit_to_app, size: 22, color: primaryColor),
                        label: Text(
                          'Exit',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: primaryColor, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Session mode: Show Next Game button
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Exit game and return to session screen
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 22),
                  label: const Text(
                    'Next Game',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primaryColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: primaryColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }


  void _startTimer() {
    gameTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!gameCompleted) {
        setState(() {
          timeElapsed++;
        });
      }
    });
    
    // Start timer for showing "Next Game" button after 2 minutes (120 seconds)
    // Only show in session mode (when onGameComplete is not null)
    if (widget.onGameComplete != null) {
      nextGameTimer = Timer(Duration(seconds: 120), () {
        if (!gameCompleted && mounted) {
          setState(() {
            showNextGameButton = true;
          });
        }
      });
    }
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _resetGame() {
    gameTimer?.cancel();
    nextGameTimer?.cancel();
    setState(() {
      gameStarted = false;
      gameCompleted = false;
      isPuzzleSolved = false;
      moves = 0;
      timeElapsed = 0;
      showNextGameButton = false;
    });
    _initializePuzzle();
  }

  void _skipToNextGame() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Skip to Next Game?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'Are you sure you want to skip this puzzle and move to the next game?',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Just close dialog
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'No',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      
                      // Mark game as completed and trigger completion flow
                      setState(() {
                        gameCompleted = true;
                        isPuzzleSolved = false; // Not actually solved, just skipped
                      });
                      
                      // Cancel timers
                      gameTimer?.cancel();
                      nextGameTimer?.cancel();
                      
                      // Calculate a lower accuracy since puzzle wasn't completed
                      int accuracy = 30; // Give some points for effort
                      
                      // Call completion callback to move to next game
                      if (widget.onGameComplete != null) {
                        widget.onGameComplete!(
                          accuracy: accuracy,
                          completionTime: timeElapsed,
                          challengeFocus: 'Problem-solving and spatial reasoning',
                          gameName: 'Puzzle Game',
                          difficulty: _normalizedDifficulty,
                        );
                      }
                      
                      // Show completion dialog to simulate normal game completion
                      _showSkipCompletionDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: primaryColor,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Yes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showSkipCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Game Skipped! 📝',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.skip_next, color: accentColor, size: 64),
              SizedBox(height: 16),
              Text(
                'Moving to next game...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Time: ${_formatTime(timeElapsed)}',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Close game screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: primaryColor,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Next Game',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleBackButton(BuildContext context) {
    // If this is a demo game (onGameComplete is null), allow direct navigation back
    if (widget.onGameComplete == null) {
      Navigator.of(context).pop();
    } else {
      // Only show PIN dialog for actual student sessions
      _showTeacherPinDialog(context);
    }
  }

  void _showTeacherPinDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _TeacherPinDialog(
          onPinVerified: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/home', (route) => false);
          },
          onCancel: () {
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackButton(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/logicbg.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      SizedBox(height: 20),
                      Expanded(
                        child: showingCountdown
                            ? _buildCountdownScreen()
                            : (gameStarted ? _buildGameArea() : _buildStartScreen()),
                      ),
                    ],
                  ),
                ),
              ),
              // GO overlay
              if (showingGo)
                Positioned.fill(
                  child: IgnorePointer(
                    child: FadeTransition(
                      opacity: _goOpacity,
                      child: Container(
                        color: Colors.black.withOpacity(0.12),
                        child: Center(
                          child: ScaleTransition(
                            scale: _goScale,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Get Ready!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black26,
                                        offset: Offset(2, 2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: accentColor,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.30),
                                        offset: const Offset(0, 8),
                                        blurRadius: 0,
                                        spreadRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'GO!',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontSize: 54,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Get Ready!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(2, 2),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 0,
                  offset: Offset(0, 6),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$countdownNumber',
                style: TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                  color: tileTextColor, // Dark brown
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'The game will start soon...',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: accentColor, size: 24),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStartScreen() {
    final size = MediaQuery.of(context).size;
    final bool isTablet = size.shortestSide >= 600;
    final double panelMaxWidth = isTablet ? 560.0 : 420.0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: min(size.width * 0.9, panelMaxWidth),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: primaryColor.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.25),
                offset: const Offset(0, 12),
                blurRadius: 24,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.5),
                offset: const Offset(0, -4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Puzzle Game',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: isTablet ? 42 : 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                width: isTablet ? 100 : 84,
                height: isTablet ? 100 : 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 0,
                      offset: Offset(0, 4),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.extension,
                  size: isTablet ? 56 : 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Solve the puzzle!',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: isTablet ? 22 : 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Slide the tiles to arrange them in order from 1 to ${gridSize * gridSize - 1}. Tap a tile next to the empty space to move it.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryColor.withOpacity(0.85),
                  fontSize: isTablet ? 18 : 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: isTablet ? 18 : 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                    shadowColor: primaryColor.withOpacity(0.5),
                  ),
                  child: Text(
                    'START GAME',
                    style: TextStyle(
                      fontSize: isTablet ? 22 : 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameArea() {
    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: 500,
            ),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryColor.withOpacity(0.3), width: 2),
                ),
                child: _buildPuzzleGrid(),
              ),
            ),
          ),
        ),
        // Left side - Time info circle
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 104),
            child: _infoCircle(
              label: 'Time',
              value: _formatTime(timeElapsed),
              circleSize: 104,
              valueFontSize: 30,
              labelFontSize: 26,
            ),
          ),
        ),
        // Right side - Moves info circle
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 104),
            child: _infoCircle(
              label: 'Moves',
              value: '$moves',
              circleSize: 104,
              valueFontSize: 30,
              labelFontSize: 26,
            ),
          ),
        ),
        // Show "Next Game" button after 2 minutes - positioned at bottom right of puzzle area
        if (showNextGameButton && !gameCompleted)
          Positioned(
            bottom: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: _skipToNextGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: primaryColor,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.skip_next, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Next Game',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _infoCircle({
    required String label,
    required String value,
    double circleSize = 88,
    double valueFontSize = 18,
    double labelFontSize = 12,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.brown,
            fontSize: labelFontSize,
            fontWeight: FontWeight.w800,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.45),
                offset: const Offset(2, 2),
                blurRadius: 0,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                offset: const Offset(0, 6),
                blurRadius: 0,
                spreadRadius: 4,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: TextStyle(
              color: Colors.brown,
              fontSize: valueFontSize,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPuzzleGrid() {
    return Stack(
      children: [
        GridView.builder(
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridSize,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: gridSize * gridSize,
          itemBuilder: (context, index) {
            return _buildTile(index);
          },
        ),
        _buildSlidingTile(),
      ],
    );
  }

  Widget _buildTile(int index) {
    PuzzleTile tile = tiles[index];

    if (tile.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: emptyTileColor,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    // If this tile is sliding, show empty space
    if (slidingFromIndex == index && isAnimating) {
      return Container(
        decoration: BoxDecoration(
          color: emptyTileColor,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (gameStarted && !gameCompleted && !isAnimating) {
          _moveTile(index);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tileColor, tileColor.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '${tile.value}',
            style: TextStyle(
              fontSize: gridSize == 3 ? 32 : (gridSize == 4 ? 24 : 20),
              fontWeight: FontWeight.bold,
              color: tileTextColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlidingTile() {
    if (!isAnimating || slidingFromIndex == null || slidingToIndex == null) {
      return SizedBox.shrink();
    }

    PuzzleTile tile = tiles[slidingFromIndex!];

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        // Calculate grid positions
        int fromRow = slidingFromIndex! ~/ gridSize;
        int fromCol = slidingFromIndex! % gridSize;
        int toRow = slidingToIndex! ~/ gridSize;
        int toCol = slidingToIndex! % gridSize;

        // Get the actual grid container size (AspectRatio with padding)
        double gridContainerSize = MediaQuery.of(context).size.width * 0.4;
        double padding = 12;
        double availableSize = gridContainerSize - (padding * 2);

        // Calculate tile size based on available space
        double tileSize = availableSize / gridSize;
        double spacing = 4;

        // Calculate start position (accounting for padding)
        double startX = padding + fromCol * (tileSize + spacing);
        double startY = padding + fromRow * (tileSize + spacing);

        // Calculate end position (accounting for padding)
        double endX = padding + toCol * (tileSize + spacing);
        double endY = padding + toRow * (tileSize + spacing);

        // Interpolate position based on animation value
        double progress = _slideAnimation.value;
        double currentX = startX + (endX - startX) * progress;
        double currentY = startY + (endY - startY) * progress;

        return Positioned(
          left: currentX,
          top: currentY,
          child: Container(
            width: tileSize,
            height: tileSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tileColor, tileColor.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 6,
                  offset: Offset(3, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${tile.value}',
                style: TextStyle(
                  fontSize: gridSize == 3 ? 32 : (gridSize == 4 ? 24 : 20),
                  fontWeight: FontWeight.bold,
                  color: tileTextColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// PIN DIALOG CLASS
class _TeacherPinDialog extends StatefulWidget {
  final VoidCallback onPinVerified;
  final VoidCallback? onCancel;

  const _TeacherPinDialog({required this.onPinVerified, this.onCancel});

  @override
  State<_TeacherPinDialog> createState() => _TeacherPinDialogState();
}

class _TeacherPinDialogState extends State<_TeacherPinDialog> {
  final TextEditingController _pinController = TextEditingController();
  String? _error;
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verifyPin() async {
    final pin = _pinController.text.trim();
    if (pin.length != 6 || !RegExp(r'^[0-9]{6}').hasMatch(pin)) {
      setState(() => _error = 'PIN must be 6 digits');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Not logged in.';
          _isLoading = false;
        });
        return;
      }
      final doc = await FirebaseFirestore.instance.collection('teachers').doc(user.uid).get();
      final savedPin = doc.data()?['pin'];
      if (savedPin == null) {
        setState(() {
          _error = 'No PIN set. Please contact your administrator.';
          _isLoading = false;
        });
        return;
      }
      if (pin != savedPin) {
        setState(() {
          _error = 'Incorrect PIN.';
          _isLoading = false;
        });
        return;
      }
      widget.onPinVerified();
    } catch (e) {
      setState(() {
        _error = 'Failed to verify PIN. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Color.fromARGB(255, 181, 187, 17),
              blurRadius: 0,
              spreadRadius: 0,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD740),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B6F4A).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.lock, color: const Color(0xFF5B6F4A), size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Teacher PIN Required',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF5B6F4A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Enter your 6-digit PIN to exit the session and access teacher features.',
                  style: TextStyle(fontSize: 16, color: const Color(0xFF5B6F4A), fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5B6F4A).withOpacity(0.2),
                      blurRadius: 0,
                      spreadRadius: 0,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold, color: Color(0xFF5B6F4A)),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    hintStyle: TextStyle(color: const Color(0xFF5B6F4A).withOpacity(0.4), letterSpacing: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: const Color(0xFF5B6F4A), width: 2)),
                    errorText: _error,
                    errorStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                  onSubmitted: (_) => _verifyPin(),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.6), blurRadius: 0, spreadRadius: 0, offset: Offset(0, 4))],
                      ),
                      child: TextButton(
                        onPressed: () {
                          if (widget.onCancel != null) {
                            widget.onCancel!();
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF5B6F4A),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: const Color(0xFF5B6F4A).withOpacity(0.6), blurRadius: 0, spreadRadius: 0, offset: Offset(0, 4))],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyPin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5B6F4A),
                          foregroundColor: const Color(0xFFFFD740),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD740))))
                            : const Text('Verify', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
