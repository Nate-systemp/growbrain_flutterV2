import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/background_music_manager.dart';
import '../utils/difficulty_utils.dart';
import '../utils/sound_effects_manager.dart';

class LightTapGame extends StatefulWidget {
  final String difficulty;
  final Future<void> Function({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })?
  onGameComplete;
  final bool requirePinOnExit;

  const LightTapGame({
    Key? key,
    required this.difficulty,
    this.onGameComplete,
    this.requirePinOnExit = false,
  }) : super(key: key);

  @override
  _LightTapGameState createState() => _LightTapGameState();
}

class _LightTapGameState extends State<LightTapGame>
    with TickerProviderStateMixin {
  // Game state
  List<int> sequence = [];
  List<int> userSequence = [];
  int currentLevel = 1;
  int maxLevel = 10;
  bool isShowingSequence = false;
  bool isWaitingForInput = false;
  bool gameStarted = false;
  bool gameOver = false;
  bool showingCountdown = false;
  int countdownNumber = 3;
  int score = 0;
  int correctSequences = 0;
  int wrongTaps = 0;
  int roundsPlayed = 0;
  int totalRounds = 5;
  DateTime gameStartTime = DateTime.now();

  // Game configuration based on difficulty
  int gridSize = 4; // 2x2 grid by default
  int sequenceLength = 1;
  int maxSequenceLength = 8;
  int sequenceSpeed = 800; // milliseconds per light
  String _normalizedDifficulty = 'Easy';

  // UI state
  List<bool> lightStates = [];
  List<bool> tapStates = []; // For tap animation feedback
  List<AnimationController> animationControllers = [];
  List<Animation<double>> scaleAnimations = [];

  // App color scheme
  final Color primaryColor = Color(0xFF5B6F4A);
  final Color accentColor = Color(0xFFFFD740);
  final Color backgroundColor = Color(0xFFF5F5DC);
  final Color surfaceColor = Colors.white;
  final Color errorColor = Color(0xFFE57373);
  final Color successColor = Color(0xFF81C784);
  // Header gradient end color (matches Find Me)
  final Color headerGradientEnd = Color(0xFF6B7F5A);

  // Light colors for the game
  final List<Color> lightColors = [
    Color(0xFF4CAF50), // Green
    Color(0xFF2196F3), // Blue
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFFF44336), // Red
    Color(0xFFFFEB3B), // Yellow
    Color(0xFF00BCD4), // Cyan
    Color(0xFF795548), // Brown
    Color(0xFFE91E63), // Pink
  ];

  final Color inactiveLightColor = Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    // Start background music for this game
    BackgroundMusicManager().startGameMusic('Light Tap');
    // Normalize difficulty once
    _normalizedDifficulty = DifficultyUtils.normalizeDifficulty(widget.difficulty);
    // DEBUG: trace normalized difficulty at init
    // ignore: avoid_print
    print(
      '[LightTap] init difficulty="${widget.difficulty}" normalized="$_normalizedDifficulty"',
    );
    _initializeGame();
  }

  @override
  void dispose() {
    for (var controller in animationControllers) {
      controller.dispose();
    }
    // Stop background music when leaving the game
    BackgroundMusicManager().stopMusic();
    super.dispose();
  }

  void _initializeGame() {
    // Configure game based on normalized internal difficulty value
    switch (_normalizedDifficulty) {
      case 'Starter':
        gridSize = 4; // 2x2 grid
        maxSequenceLength = 5;
        sequenceSpeed = 1000;
        break;
      case 'Growing':
        gridSize = 6; // 2x3 grid
        maxSequenceLength = 7;
        sequenceSpeed = 800;
        break;
      case 'Challenged':
        gridSize = 9; // 3x3 grid
        maxSequenceLength = 10;
        sequenceSpeed = 600;
        break;
      default:
        gridSize = 4;
        maxSequenceLength = 5;
        sequenceSpeed = 1000;
        break;
    }

    // Initialize light states
    lightStates = List.generate(gridSize, (index) => false);
    tapStates = List.generate(gridSize, (index) => false);

    // Set total rounds per session according to difficulty
    switch (_normalizedDifficulty) {
      case 'Starter':
        totalRounds = 3; // Starter
        break;
      case 'Growing':
        totalRounds = 5; // Growing
        break;
      case 'Challenged':
        totalRounds = 7; // Challenged
        break;
      default:
        totalRounds = 5;
        break;
    }

    // Initialize animations for color transitions only
    animationControllers = List.generate(
      gridSize,
      (index) => AnimationController(
        duration: Duration(milliseconds: 300), // smooth color transition
        vsync: this,
      ),
    );

    scaleAnimations = animationControllers
        .map(
          (controller) => Tween<double>(begin: 1.0, end: 1.0).animate(
            CurvedAnimation(
              parent: controller,
              curve: Curves.easeInOut,
            ),
          ),
        )
        .toList();
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
      
      await Future.delayed(Duration(milliseconds: 1000));
    }
    
    // After countdown, start the actual game
    if (mounted) {
      setState(() {
        showingCountdown = false;
        gameStarted = true;
        gameOver = false;
        currentLevel = 1;
        roundsPlayed = 0;
        score = 0;
        correctSequences = 0;
        wrongTaps = 0;
        gameStartTime = DateTime.now();
        sequence.clear();
        userSequence.clear();
      });

      _nextLevel();
    }
  }

  void _nextLevel() {
    // If we've completed the configured number of rounds, end the session
    if (roundsPlayed >= totalRounds) {
      _endGame(true);
      return;
    }

    setState(() {
      sequenceLength = math.min(currentLevel + 1, maxSequenceLength);
      userSequence.clear();
      isWaitingForInput = false;
    });

    _generateNewSequence();
    _showSequence();
  }

  void _generateNewSequence() {
    final random = math.Random();
    sequence = List.generate(
      sequenceLength,
      (index) => random.nextInt(gridSize),
    );
  }

  void _showSequence() async {
    setState(() {
      isShowingSequence = true;
      isWaitingForInput = false;
    });

    // Wait a moment before starting
    await Future.delayed(Duration(milliseconds: 500));

    // Show each light in sequence
    for (int i = 0; i < sequence.length; i++) {
      if (!mounted) return;

      final lightIndex = sequence[i];

      // Light up
      setState(() {
        lightStates[lightIndex] = true;
      });

      await Future.delayed(Duration(milliseconds: sequenceSpeed ~/ 2));

      // Light off
      setState(() {
        lightStates[lightIndex] = false;
      });

      await Future.delayed(Duration(milliseconds: sequenceSpeed ~/ 2));
    }

    // Ready for user input
    setState(() {
      isShowingSequence = false;
      isWaitingForInput = true;
    });
  }

  void _onLightTap(int index) {
    if (!isWaitingForInput || isShowingSequence) return;

    // Trigger tap animation
    _animateTap(index);

    // Light up immediately on tap
    setState(() {
      lightStates[index] = true;
    });

    // Turn off light after a short delay
    Future.delayed(Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          lightStates[index] = false;
        });
      }
    });

    userSequence.add(index);

    // Check if the tap is correct
    if (userSequence.length <= sequence.length) {
      final currentIndex = userSequence.length - 1;

      if (userSequence[currentIndex] == sequence[currentIndex]) {
        // Correct tap
        setState(() {
          score += 10;
        });

        // Check if sequence is complete
        if (userSequence.length == sequence.length) {
          setState(() {
            correctSequences++;
            roundsPlayed++;
            currentLevel++;
            isWaitingForInput = false;
          });

          // Play success sound effect with voice
          SoundEffectsManager().playSuccessWithVoice();

          // Show success feedback
          _showFeedback(true);

          // If we've completed the required rounds, end session; otherwise continue
          Future.delayed(Duration(milliseconds: 1500), () {
            if (!mounted) return;
            if (roundsPlayed >= totalRounds) {
              _endGame(true);
            } else {
              _nextLevel();
            }
          });
        }
      } else {
        // Wrong tap
        setState(() {
          wrongTaps++;
          roundsPlayed++;
          isWaitingForInput = false;
        });

        // Play wrong sound effect
        SoundEffectsManager().playWrong();

        _showFeedback(false);

        // Continue to next round unless we've finished the configured rounds
        Future.delayed(Duration(milliseconds: 1500), () {
          if (!mounted) return;
          if (roundsPlayed >= totalRounds) {
            _endGame(true);
          } else {
            // Proceed to next round
            _nextLevel();
          }
        });
      }
    }
  }

  void _showFeedback(bool isCorrect) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCorrect ? Icons.check_circle : Icons.cancel,
              color: isCorrect ? successColor : errorColor,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              isCorrect ? 'Great Job!' : 'Try Again!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            if (isCorrect) ...[
              SizedBox(height: 8),
              Text(
                'Level ${currentLevel} Complete!',
                style: TextStyle(fontSize: 16, color: primaryColor),
              ),
            ],
          ],
        ),
      ),
    );

    // Auto-close dialog
    Future.delayed(Duration(milliseconds: 1000), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _endGame(bool completed) async {
    setState(() {
      gameOver = true;
      isWaitingForInput = false;
      isShowingSequence = false;
    });

    final completionTime = DateTime.now().difference(gameStartTime).inSeconds;
    // Compute accuracy as correct / total attempts (correct + wrong). If no attempts, accuracy = 0.
    final totalAttempts = correctSequences + wrongTaps;
    int accuracy = 0;
    if (totalAttempts > 0) {
      accuracy = ((correctSequences / totalAttempts) * 100).round();
    }
    // Clamp to 0..100 just in case
    accuracy = accuracy.clamp(0, 100);

    // Call completion callback
    if (widget.onGameComplete != null) {
      await widget.onGameComplete!(
        accuracy: accuracy,
        completionTime: completionTime,
        challengeFocus: 'Memory',
        gameName: 'Light Tap',
        difficulty: _normalizedDifficulty,
      );
    }

    _showGameOverDialog(completed, accuracy, completionTime);
  }

  void _resetGame() {
    setState(() {
      currentLevel = 1;
      score = 0;
      correctSequences = 0;
      wrongTaps = 0;
      roundsPlayed = 0;
      sequence.clear();
      userSequence.clear();
      isShowingSequence = false;
      isWaitingForInput = false;
      gameStarted = false;
      gameOver = false;
      showingCountdown = false;
    });
    
    _initializeGame();
  }

  void _showGameOverDialog(bool completed, int accuracy, int completionTime) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                completed ? Icons.celebration : Icons.lightbulb_outline,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              completed ? 'Amazing! 🌟' : 'Great Effort! 💡',
              style: TextStyle(
                color: primaryColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatRow(Icons.star_rounded, 'Score', '$score points'),
              const SizedBox(height: 12),
              _buildStatRow(Icons.track_changes, 'Accuracy', '$accuracy%'),
              const SizedBox(height: 12),
              _buildStatRow(Icons.timer, 'Time', '${completionTime}s'),
              const SizedBox(height: 12),
              _buildStatRow(Icons.trending_up, 'Level Reached', '$currentLevel'),
            ],
          ),
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
                        backgroundColor: primaryColor,
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
                  backgroundColor: primaryColor,
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
      ),
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

  int _getGridColumns() {
    switch (gridSize) {
      case 4:
        return 2; // 2x2
      case 6:
        return 2; // 2x3
      case 9:
        return 3; // 3x3
      default:
        return 2;
    }
  }

  int _getGridRows() {
    switch (gridSize) {
      case 4:
        return 2; // 2x2
      case 6:
        return 3; // 2x3
      case 9:
        return 3; // 3x3
      default:
        return 2;
    }
  }

  void _handleBackButton(BuildContext context) {
    if (widget.requirePinOnExit) {
      _showTeacherPinDialog(context);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _showTeacherPinDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _TeacherPinDialog(
          onPinVerified: () {
            Navigator.of(dialogContext).pop(); // Close dialog
            // Exit session and go to home screen after PIN verification
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/home', (route) => false);
          },
          onCancel: () {
            Navigator.of(
              dialogContext,
            ).pop(); // Just close dialog, stay in game
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
          title: Text(
            'Light Tap - ${DifficultyUtils.getDifficultyDisplayName(widget.difficulty)}',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: primaryColor,
          iconTheme: IconThemeData(color: Colors.white),
          elevation: 0,
          automaticallyImplyLeading: false, // This removes the back button
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Game info (styled to match Find Me theme)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, headerGradientEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
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
                      Column(
                        children: [
                          Icon(Icons.flag, color: accentColor, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            'Level',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '$currentLevel',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Icon(Icons.score, color: accentColor, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            'Score',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '$score',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Icon(Icons.list, color: accentColor, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            'Sequence',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${userSequence.length}/${sequenceLength}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // Status text
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStatusText(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),

                SizedBox(height: 24),

                // Game grid
                Expanded(
                  child: showingCountdown 
                      ? _buildCountdownScreen()
                      : (gameStarted ? _buildGameGrid() : _buildStartScreen()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getStatusText() {
    if (!gameStarted) {
      return 'Tap "Start Game" to begin!';
    } else if (isShowingSequence) {
      return 'Watch the sequence carefully...';
    } else if (isWaitingForInput) {
      return 'Repeat the sequence by tapping the lights!';
    } else {
      return 'Get ready for the next sequence...';
    }
  }

  Widget _buildCountdownScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Get Ready!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          SizedBox(height: 40),
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$countdownNumber',
                style: TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          SizedBox(height: 40),
          Text(
            'The game will start soon...',
            style: TextStyle(
              fontSize: 18,
              color: primaryColor.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lightbulb_outline, size: 100, color: accentColor),
          SizedBox(height: 24),
          Text(
            'Light Tap Memory Game',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'How to Play:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '1. Watch the sequence of lights\n'
                  '2. Memorize the pattern\n'
                  '3. Tap the lights in the same order\n'
                  '4. Sequences get longer each level!',
                  style: TextStyle(fontSize: 14, color: primaryColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton(
            onPressed: _startGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: Text(
              'Start Game',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameGrid() {
    final columns = _getGridColumns();
    final rows = _getGridRows();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSize = math.min(constraints.maxWidth, constraints.maxHeight);
        final gridSize = maxSize * 0.8;
        final buttonSize = (gridSize / math.max(columns, rows)) - 12;

        return Center(
          child: Container(
            width: gridSize,
            height: gridSize,
            child: GridView.builder(
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: this.gridSize,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _onLightTap(index),
                  child: AnimatedScale(
                    scale: tapStates[index] ? 0.95 : (lightStates[index] ? 1.05 : 1.0),
                    duration: Duration(milliseconds: 150),
                    curve: Curves.easeInOut,
                    child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      gradient: lightStates[index]
                          ? LinearGradient(
                              colors: [
                                lightColors[index % lightColors.length],
                                lightColors[index % lightColors.length].withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : LinearGradient(
                              colors: [
                                Colors.white,
                                Color(0xFFF5F5F5),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: lightStates[index]
                            ? lightColors[index % lightColors.length].withOpacity(0.3)
                            : Color(0xFFE0E0E0),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: lightStates[index]
                              ? lightColors[index % lightColors.length].withOpacity(0.4)
                              : Colors.black.withOpacity(0.08),
                          blurRadius: lightStates[index] ? 12 : 6,
                          offset: Offset(0, lightStates[index] ? 6 : 3),
                          spreadRadius: lightStates[index] ? 2 : 0,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Background pattern
                        if (lightStates[index])
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.3),
                                    Colors.transparent,
                                  ],
                                  center: Alignment.topLeft,
                                  radius: 1.0,
                                ),
                              ),
                            ),
                          ),
                        // Main content
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Icon based on index
                              Icon(
                                _getLightIcon(index),
                                size: buttonSize * 0.25,
                                color: lightStates[index]
                                    ? Colors.white
                                    : primaryColor.withOpacity(0.7),
                              ),
                              SizedBox(height: 4),
                              // Light name
                              Text(
                                _getLightName(index),
                                style: TextStyle(
                                  fontSize: buttonSize * 0.12,
                                  fontWeight: FontWeight.w600,
                                  color: lightStates[index]
                                      ? Colors.white
                                      : primaryColor.withOpacity(0.8),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        // Pulse effect when active
                        if (lightStates[index])
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.6),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // Method to animate tap feedback
  void _animateTap(int index) {
    setState(() {
      tapStates[index] = true;
    });
    
    // Reset tap state after animation
    Future.delayed(Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          tapStates[index] = false;
        });
      }
    });
  }

  // Helper method to get icon for each light position
  IconData _getLightIcon(int index) {
    final icons = [
      Icons.star,           // 0 - Star
      Icons.favorite,       // 1 - Heart  
      Icons.flash_on,       // 2 - Lightning
      Icons.brightness_high, // 3 - Sun
      Icons.nightlight,     // 4 - Moon
      Icons.local_fire_department, // 5 - Fire
      Icons.water_drop,     // 6 - Water
      Icons.eco,            // 7 - Leaf
      Icons.diamond,        // 8 - Diamond
    ];
    return icons[index % icons.length];
  }

  // Helper method to get name for each light position
  String _getLightName(int index) {
    final names = [
      'Star',      // 0
      'Heart',     // 1
      'Lightning', // 2
      'Sun',       // 3
      'Moon',      // 4
      'Fire',      // 5
      'Water',     // 6
      'Leaf',      // 7
      'Diamond',   // 8
    ];
    return names[index % names.length];
  }
}

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
      setState(() {
        _error = 'PIN must be 6 digits';
      });
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

      // PIN is correct
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
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: const Color(0xFF5B6F4A), size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Teacher PIN Required',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF5B6F4A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Enter your 6-digit PIN to exit the session and access teacher features.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••••',
                hintStyle: TextStyle(color: Colors.grey[400], letterSpacing: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: const Color(0xFF5B6F4A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: const Color(0xFF5B6F4A),
                    width: 2,
                  ),
                ),
                errorText: _error,
                errorStyle: const TextStyle(fontSize: 14),
              ),
              onSubmitted: (_) => _verifyPin(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      if (widget.onCancel != null) {
                        widget.onCancel!();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyPin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B6F4A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Verify',
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
        ),
      ),
    );
  }
}
