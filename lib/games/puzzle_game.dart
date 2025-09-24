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

    // Start background music for this game
    BackgroundMusicManager().startGameMusic('Puzzle');
    _initializeGame();
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    nextGameTimer?.cancel();
    _slideController.dispose();
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
      gameStarted = true;
      gameCompleted = false;
      startTime = DateTime.now();
      moves = 0;
      timeElapsed = 0;
    });

    _initializePuzzle();
    _startTimer();
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
        gameName: 'Sliding Puzzle',
        difficulty: _normalizedDifficulty,
      );
    }

    _showCompletionDialog();
  }

  void _showCompletionDialog() {
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
            'Puzzle Solved! 🎉',
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
              Icon(Icons.emoji_events, color: accentColor, size: 64),
              SizedBox(height: 16),
              Text(
                'Moves: $moves',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Time: ${_formatTime(timeElapsed)}',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          actions: [
            // Different actions for demo mode vs session mode
            if (widget.onGameComplete == null) ...[
              // Demo mode: Show Play Again and Exit buttons
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _resetGame();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.refresh, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Play Again',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          Navigator.of(context).pop(); // Exit game
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.exit_to_app, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Exit',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Exit game and return to session screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Next Game',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
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
                          gameName: 'Sliding Puzzle',
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
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          title: Text(
            'Sliding Puzzle - ${DifficultyUtils.getDifficultyDisplayName(widget.difficulty)}',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildHeader(),
                SizedBox(height: 20),
                Expanded(
                  child: gameStarted ? _buildGameArea() : _buildStartScreen(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, Color(0xFF6B7F5A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.touch_app,
            label: 'Moves',
            value: moves.toString(),
          ),
          _buildStatItem(
            icon: Icons.timer,
            label: 'Time',
            value: _formatTime(timeElapsed),
          ),
          _buildStatItem(
            icon: Icons.grid_on,
            label: 'Grid',
            value: '${gridSize}x${gridSize}',
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${gridSize - 1}',
              style: TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.bold,
                color: tileTextColor,
              ),
            ),
          ),
        ),
        SizedBox(height: 30),
        Text(
          'Sliding Puzzle',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        SizedBox(height: 10),
        Text(
          '${DifficultyUtils.getDifficultyDisplayName(widget.difficulty)} Mode',
          style: TextStyle(fontSize: 20, color: primaryColor.withOpacity(0.8)),
        ),
        SizedBox(height: 10),
        Text(
          '${gridSize}x${gridSize} Grid (${gridSize * gridSize - 1} tiles)',
          style: TextStyle(fontSize: 16, color: primaryColor.withOpacity(0.6)),
        ),
        SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: _startGame,
          icon: Icon(Icons.play_arrow),
          label: Text('Start Game', style: TextStyle(fontSize: 18)),
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: primaryColor,
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameArea() {
    return Stack(
      children: [
        Center(
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

// Teacher PIN Dialog for exiting the game
class _TeacherPinDialog extends StatefulWidget {
  final VoidCallback onPinVerified;
  final VoidCallback onCancel;

  const _TeacherPinDialog({
    Key? key,
    required this.onPinVerified,
    required this.onCancel,
  }) : super(key: key);

  @override
  _TeacherPinDialogState createState() => _TeacherPinDialogState();
}

class _TeacherPinDialogState extends State<_TeacherPinDialog> {
  final TextEditingController _pinController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _verifyPin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final storedPin = doc.data()?['teacherPin'];
        if (storedPin == _pinController.text) {
          widget.onPinVerified();
        } else {
          setState(() {
            _errorMessage = 'Incorrect PIN';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error verifying PIN';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Enter Teacher PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Please enter your teacher PIN to exit the game.'),
          SizedBox(height: 16),
          TextField(
            controller: _pinController,
            obscureText: true,
            maxLength: 4,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter 4-digit PIN',
              border: OutlineInputBorder(),
              errorText: _errorMessage,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: widget.onCancel, child: Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyPin,
          child: _isLoading
              ? CircularProgressIndicator(strokeWidth: 2)
              : Text('Verify'),
        ),
      ],
    );
  }
}
