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
  })? onGameComplete;

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

class _PuzzleGameState extends State<PuzzleGame>
    with TickerProviderStateMixin {
  List<PuzzleTile> tiles = [];
  int gridSize = 3;
  int moves = 0;
  int timeElapsed = 0;
  bool gameStarted = false;
  bool gameCompleted = false;
  bool isPuzzleSolved = false;
  bool showNextGameButton = false;
  late DateTime startTime;
  Timer? gameTimer;
  Timer? nextGameTimer;
  String _normalizedDifficulty = 'Starter';
  bool showSimpleInstruction = false;

  // Countdown state
  bool showingCountdown = false;
  int countdownNumber = 3;

  // GO overlay
  bool showingGo = false;
  late final AnimationController _goController;
  late final Animation<double> _goOpacity;
  late final Animation<double> _goScale;

  // Status overlay
  bool showingStatus = false;
  String overlayText = '';
  Color overlayColor = Colors.green;
  Color overlayTextColor = Colors.white;

  // Animation controllers for tile sliding
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  int? slidingTileIndex;
  Offset? slidingFromPosition;
  Offset? slidingToPosition;
  bool isAnimating = false;

  Random random = Random();

  // App color scheme
  final Color primaryColor = Color(0xFF5B6F4A);
  final Color accentColor = Color(0xFFFFD740);
  final Color backgroundColor = Color(0xFFF5F5DC);
  final Color tileColor = Color(0xFF8B7355);
  final Color tileTextColor = Color(0xFF3E2723);
  final Color emptyTileColor = Color(0xFF3E2723);

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _slideController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );

    _goController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _goOpacity = CurvedAnimation(parent: _goController, curve: Curves.easeInOut);
    _goScale = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(parent: _goController, curve: Curves.easeOutBack),
    );

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
    // Normalize difficulty
    _normalizedDifficulty = DifficultyUtils.normalizeDifficulty(widget.difficulty);

    // Set grid size based on difficulty
    switch (_normalizedDifficulty) {
      case 'Starter':
        gridSize = 3;
        break;
      case 'Growing':
        gridSize = 4;
        break;
      case 'Challenged':
        gridSize = 5;
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

    int totalTiles = gridSize * gridSize;

    // Create tiles (0 represents the empty space)
    for (int i = 0; i < totalTiles; i++) {
      tiles.add(PuzzleTile(value: i, currentPosition: i));
    }

    // If game has started, shuffle the puzzle
    if (gameStarted) {
      _shufflePuzzle();
    }

    setState(() {});
  }

  void _shufflePuzzle() {
    // Shuffle by making valid moves to ensure solvability
    int shuffleMoves = gridSize * gridSize * 10;

    for (int i = 0; i < shuffleMoves; i++) {
      List<int> validMoves = _getValidMoves();
      if (validMoves.isNotEmpty) {
        int randomMove = validMoves[random.nextInt(validMoves.length)];
        _moveTile(randomMove, animate: false);
      }
    }

    // Reset moves counter after shuffling
    moves = 0;
  }

  List<int> _getValidMoves() {
    int emptyIndex = tiles.indexWhere((tile) => tile.isEmpty);
    int emptyRow = emptyIndex ~/ gridSize;
    int emptyCol = emptyIndex % gridSize;
    List<int> validMoves = [];

    // Check adjacent positions
    if (emptyRow > 0) {
      validMoves.add(emptyIndex - gridSize); // Up
    }
    if (emptyRow < gridSize - 1) {
      validMoves.add(emptyIndex + gridSize); // Down
    }
    if (emptyCol > 0) {
      validMoves.add(emptyIndex - 1); // Left
    }
    if (emptyCol < gridSize - 1) {
      validMoves.add(emptyIndex + 1); // Right
    }

    return validMoves;
  }

  bool _canMoveTile(int tileIndex) {
    int emptyIndex = tiles.indexWhere((tile) => tile.isEmpty);
    int tileRow = tileIndex ~/ gridSize;
    int tileCol = tileIndex % gridSize;
    int emptyRow = emptyIndex ~/ gridSize;
    int emptyCol = emptyIndex % gridSize;

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
      // Setup animation
      setState(() {
        isAnimating = true;
        slidingTileIndex = tileIndex;
        slidingFromPosition = _getPositionOffset(tileIndex);
        slidingToPosition = _getPositionOffset(emptyIndex);
      });

      _slideAnimation = Tween<Offset>(
        begin: slidingFromPosition!,
        end: slidingToPosition!,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      ));

      _slideController.reset();
      _slideController.forward().then((_) {
        // Complete the move
        setState(() {
          PuzzleTile temp = tiles[tileIndex];
          tiles[tileIndex] = tiles[emptyIndex];
          tiles[emptyIndex] = temp;

          tiles[tileIndex].currentPosition = tileIndex;
          tiles[emptyIndex].currentPosition = emptyIndex;

          moves++;

          // Reset animation state
          slidingTileIndex = null;
          slidingFromPosition = null;
          slidingToPosition = null;
          isAnimating = false;

          // Play sound and haptic feedback
          SoundEffectsManager().playPuzzleClickSound();
          HapticFeedback.lightImpact();

          // Check if puzzle is solved
          if (_checkIfSolved()) {
            _onPuzzleSolved();
          }
        });
      });
    } else {
      // Move without animation (for shuffling)
      setState(() {
        PuzzleTile temp = tiles[tileIndex];
        tiles[tileIndex] = tiles[emptyIndex];
        tiles[emptyIndex] = temp;

        tiles[tileIndex].currentPosition = tileIndex;
        tiles[emptyIndex].currentPosition = emptyIndex;

        if (gameStarted && animate) {
          moves++;

          SoundEffectsManager().playPuzzleClickSound();
          HapticFeedback.lightImpact();

          if (_checkIfSolved()) {
            _onPuzzleSolved();
          }
        }
      });
    }
  }

  Offset _getPositionOffset(int index) {
    int row = index ~/ gridSize;
    int col = index % gridSize;
    double tileSize = 80.0; // Approximate tile size
    double spacing = 4.0;
    return Offset(
      col * (tileSize + spacing),
      row * (tileSize + spacing),
    );
  }

  bool _checkIfSolved() {
    for (int i = 0; i < tiles.length - 1; i++) {
      if (tiles[i].value != i + 1) {
        return false;
      }
    }
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
      setState(() {
        countdownNumber = i;
      });
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

    SoundEffectsManager().playSuccessWithVoice();
    HapticFeedback.heavyImpact();

    // Calculate accuracy based on optimal moves vs actual moves
    int optimalMoves = gridSize * gridSize * 2; // Rough estimate
    int accuracy = ((optimalMoves / moves.clamp(1, double.infinity)) * 100)
        .clamp(0, 100)
        .toInt();

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
            if (widget.onGameComplete == null) ...[
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
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
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
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
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

    // Show skip button after 2 minutes if in session mode
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
      showSimpleInstruction = false;
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
                      Navigator.of(context).pop();
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
                      
                      // Mark game as completed with skip
                      setState(() {
                        gameCompleted = true;
                        isPuzzleSolved = false; // Not actually solved
                      });
                      
                      // Stop timers
                      gameTimer?.cancel();
                      nextGameTimer?.cancel();
                      
                      // Give a default accuracy for skipped games
                      int accuracy = 30; // Low accuracy for skip
                      
                      if (widget.onGameComplete != null) {
                        widget.onGameComplete!(
                          accuracy: accuracy,
                          completionTime: timeElapsed,
                          challengeFocus: 'Problem-solving and spatial reasoning',
                          gameName: 'Puzzle Game',
                          difficulty: _normalizedDifficulty,
                        );
                      }
                      
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
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Go back to previous screen
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
    if (widget.onGameComplete == null) {
      // Demo mode - can exit freely
      Navigator.of(context).pop();
    } else {
      // Session mode - require teacher PIN
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
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          },
          onCancel: () {
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  Widget _buildHelpButton() {
    return FloatingActionButton.extended(
      heroTag: 'helpBtn',
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      icon: const Icon(Icons.help_outline),
      label: const Text('Need Help?'),
      onPressed: () {
        bool showSimple = false;
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) => Dialog(
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD740),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 24,
                      spreadRadius: 0,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 320,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
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
                              child: const Icon(Icons.help_outline, color: Color(0xFF5B6F4A), size: 28),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Need Help?',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF5B6F4A),
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
                            showSimple
                                ? 'Tap any tile next to the empty dark box to move it there. Keep moving tiles until all numbers are in order from 1 to ${gridSize * gridSize - 1}!'
                                : 'Slide the tiles to arrange them in order from 1 to ${gridSize * gridSize - 1}. Tap a tile next to the empty space to move it.',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF5B6F4A),
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (showSimple)
                          const SizedBox(height: 16),
                        if (showSimple)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'That\'s the simpler explanation!',
                              style: TextStyle(
                                color: Color(0xFF5B6F4A),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF5B6F4A).withOpacity(0.6),
                                      blurRadius: 0,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: TextButton(
                                  onPressed: () {
                                    if (!showSimple) {
                                      setState(() => showSimple = true);
                                    } else {
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF5B6F4A),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    showSimple ? 'Close' : 'More Help?',
                                    style: const
                                    TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
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
              // Show Need Help button ONLY when in-game
              if (gameStarted && !showingCountdown && !gameCompleted)
                Positioned(
                  left: 24,
                  bottom: 24,
                  child: _buildHelpButton(),
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
                  color: tileTextColor,
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
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: showSimpleInstruction
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: Text(
                  'Slide the tiles to arrange them in order from 1 to ${gridSize * gridSize - 1}. Tap a tile next to the empty space to move it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: primaryColor.withOpacity(0.85),
                    fontSize: isTablet ? 18 : 15,
                    height: 1.35,
                  ),
                ),
                secondChild: Text(
                  'Tap any tile next to the empty dark box to move it there. Keep moving tiles until all numbers are in order from 1 to ${gridSize * gridSize - 1}!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: primaryColor.withOpacity(0.9),
                    fontSize: isTablet ? 18 : 15,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    showSimpleInstruction = !showSimpleInstruction;
                  });
                },
                icon: Icon(Icons.help_outline, color: primaryColor),
                label: Text(
                  showSimpleInstruction
                      ? 'Show Original Instruction'
                      : 'Need a simpler explanation?',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: isTablet ? 16 : 14,
                  ),
                ),
              ),
              const SizedBox(height: 10),
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
        // Main puzzle area
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
        // Game stats
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
        // Skip button (appears after 2 minutes in session mode)
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
        // Grid background
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
        // Animated sliding tile
        if (isAnimating && slidingTileIndex != null)
          AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return _buildSlidingTile();
            },
          ),
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

    // Hide the tile that's currently animating
    if (isAnimating && slidingTileIndex == index) {
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
    if (slidingTileIndex == null) return SizedBox.shrink();

    PuzzleTile tile = tiles[slidingTileIndex!];
    
    return Positioned(
      left: _slideAnimation.value.dx,
      top: _slideAnimation.value.dy,
      child: Container(
        width: 80, // Approximate tile size
        height: 80,
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
  }
}

// Teacher PIN Dialog
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

      final doc = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(user.uid)
          .get();

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
                  style: TextStyle(
                      fontSize: 16,
                      color: const Color(0xFF5B6F4A),
                      fontWeight: FontWeight.w600),
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
                  style: const TextStyle(
                      fontSize: 24,
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5B6F4A)),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    hintStyle: TextStyle(
                        color: const Color(0xFF5B6F4A).withOpacity(0.4),
                        letterSpacing: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: const Color(0xFF5B6F4A), width: 2)),
                    errorText: _error,
                    errorStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
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
                        boxShadow: [
                          BoxShadow(
                              color: Colors.grey.withOpacity(0.6),
                              blurRadius: 0,
                              spreadRadius: 0,
                              offset: Offset(0, 4))
                        ],
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
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF5B6F4A).withOpacity(0.6),
                              blurRadius: 0,
                              spreadRadius: 0,
                              offset: Offset(0, 4))
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyPin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5B6F4A),
                          foregroundColor: const Color(0xFFFFD740),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFFFFD740))))
                            : const Text('Verify',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w900)),
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