import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/background_music_manager.dart';
import '../utils/difficulty_utils.dart';
import '../utils/sound_effects_manager.dart';

enum ShapeType {
  circle,
  square,
  triangle,
  diamond,
  pentagon,
  hexagon,
  star,
  oval,
}

class GameShape {
  ShapeType type;                                                       
  Color color;
  bool isMoved;

  GameShape({required this.type, required this.color, this.isMoved = false});
}

class WhoMovedGame extends StatefulWidget {
  final String difficulty;
  final String? challengeFocus;
  final String? gameName;
  final Future<void> Function({  
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })?
  onGameComplete;

  const WhoMovedGame({
    super.key,
    required this.difficulty,
    this.challengeFocus,
    this.gameName,
    this.onGameComplete,
  });

  @override
  _WhoMovedGameState createState() => _WhoMovedGameState();
}

class _WhoMovedGameState extends State<WhoMovedGame>
    with TickerProviderStateMixin {
  List<GameShape> shapes = [];
  int movedShapeIndex = -1;
  int? selectedShapeIndex;
  List<bool> tapStates = []; // For tap animation feedback
  int score = 0;
  int timer = 0;
  int roundsPlayed = 0;
  int correctAnswers = 0;
  late DateTime gameStartTime;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _resultAnimationController;
  late Animation<double> _resultScaleAnimation;
  late Animation<double> _resultBounceAnimation;
  bool gameStarted = false;
  bool showingAnimation = false;
  bool canSelect = false;
  bool gameCompleted = false;
  bool showingCountdown = false;
  int countdownNumber = 3;
  bool showingResult = false;
  String resultText = '';
  bool isCorrectResult = false;
  String _normalizedDifficulty = 'Starter';

  // App color scheme
  final Color primaryColor = const Color(0xFF5B6F4A);
  final Color accentColor = const Color(0xFFFFD740);
  final Color backgroundColor = const Color(0xFFF5F5DC);
  final Color headerGradientEnd = const Color(0xFF6B7F5A);
  final Color surfaceColor = const Color(0xFFF5F5DC);

  ShapeType? previousMovedShapeType;
  static const int totalRounds = 3;

  int get numberOfShapes {
    switch (_normalizedDifficulty) {
      case 'Starter':
        return 3;
      case 'Growing':
        return 5;
      case 'Challenged':
        return 8;
      default:
        return 3;
    }
  }

  int get timerDuration {
    int baseDuration;
    switch (_normalizedDifficulty) {
      case 'Starter':
        baseDuration = 30;
        break;
      case 'Growing':
        baseDuration = 25;
        break;
      case 'Challenged':
        baseDuration = 20;
        break;
      default:
        baseDuration = 30;
    }
    int reduction = (roundsPlayed) * 5;
    return math.max(10, baseDuration - reduction);
  }

  Duration get shakeDuration {
    double baseDurationSeconds;
    switch (_normalizedDifficulty) {
      case 'Starter':
        baseDurationSeconds = 1.0;
        break;
      case 'Growing':
        baseDurationSeconds = 0.8;
        break;
      case 'Challenged':
        baseDurationSeconds = 0.6;
        break;
      default:
        baseDurationSeconds = 1.0;
    }
    double speedIncrease = (roundsPlayed) * 0.15;
    double finalDuration = math.max(0.3, baseDurationSeconds - speedIncrease);
    return Duration(milliseconds: (finalDuration * 1000).round());
  }

  @override
  void initState() {
    super.initState();
    gameStartTime = DateTime.now();
    BackgroundMusicManager().startGameMusic('Who Moved?');
    // Normalize difficulty (accept display names like "Growing"/"Starter")
    _normalizedDifficulty = DifficultyUtils.normalizeDifficulty(widget.difficulty);

    // DEBUG: log normalized difficulty
    // ignore: avoid_print
    print(
      '[WhoMoved] init difficulty="${widget.difficulty}" normalized="$_normalizedDifficulty"',
    );

    _shakeController = AnimationController(
      duration: shakeDuration,
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    // Initialize result animation controller
    _resultAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _resultScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _resultAnimationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    
    _resultBounceAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _resultAnimationController,
        curve: const Interval(0.6, 1.0, curve: Curves.bounceOut),
      ),
    );

    _initializeGame();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _resultAnimationController.dispose();
    BackgroundMusicManager().stopMusic();
    super.dispose();
  }

  void _initializeGame() {
    final colors = [
      const Color(0xFF5B6F4A),
      const Color(0xFFFFD740),
      const Color(0xFF8BC34A),
      const Color(0xFFFF9800),
      const Color(0xFF2196F3),
      const Color(0xFF9C27B0),
      const Color(0xFFE91E63),
      const Color(0xFF607D8B),
    ];

    final availableTypes = ShapeType.values
        .where((t) => t != ShapeType.circle)
        .toList();
    availableTypes.shuffle();

    shapes.clear();
    final selectedTypes = <ShapeType>[];
    while (selectedTypes.length < numberOfShapes) {
      selectedTypes.addAll(availableTypes);
    }
    selectedTypes.shuffle();
    final typesToUse = selectedTypes.take(numberOfShapes).toList();

    for (int i = 0; i < numberOfShapes; i++) {
      shapes.add(
        GameShape(type: typesToUse[i], color: colors[i % colors.length]),
      );
    }
    
    // Initialize tap states
    tapStates = List.generate(numberOfShapes, (index) => false);

    final rand = math.Random();
    int candidate = rand.nextInt(numberOfShapes);
    const int maxAttempts = 8;
    int attempts = 0;
    while (previousMovedShapeType != null &&
        shapes[candidate].type == previousMovedShapeType &&
        attempts < maxAttempts) {
      candidate = rand.nextInt(numberOfShapes);
      attempts++;
    }
    movedShapeIndex = candidate;
    previousMovedShapeType = shapes[movedShapeIndex].type;

    selectedShapeIndex = null;
    canSelect = false;
    showingAnimation = false;
  }

  void _startRoundTimer() {
    setState(() {
      timer = timerDuration;
    });
    _runTimer();
  }

  void _runTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && timer > 0 && canSelect && !gameCompleted) {
        setState(() {
          timer--;
        });
        _runTimer();
      } else if (timer <= 0 && canSelect) {
        _handleTimeUp();
      }
    });
  }

  void _handleTimeUp() {
    setState(() {
      canSelect = false;
    });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: primaryColor,
        title: const Text('Time\'s Up!', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You ran out of time for this round.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: accentColor),
            onPressed: () {
              Navigator.of(context).pop();
              _nextRound();
            },
            child: const Text('Next Round'),
          ),
        ],
      ),
    );
  }

  void _startGame() {
    _shakeController.dispose();
    _shakeController = AnimationController(
      duration: shakeDuration,
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    setState(() {
      gameStarted = true;
      showingCountdown = true;
      showingAnimation = false;
      canSelect = false;
      timer = 0;
      countdownNumber = 3;
    });

    // DEBUG: starting round
    // ignore: avoid_print
    print(
      '[WhoMoved] start round ${roundsPlayed + 1} with speed=${shakeDuration.inMilliseconds}ms',
    );

    // Start countdown sequence
    _startCountdown();
  }

  void _startCountdown() {
    // Show countdown 3, 2, 1
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && countdownNumber > 1) {
        setState(() {
          countdownNumber--;
        });
        _startCountdown();
      } else if (mounted) {
        // Countdown finished, start the shaking animation
        setState(() {
          showingCountdown = false;
          showingAnimation = true;
        });
        
        Future.delayed(const Duration(milliseconds: 500), () async {
          if (mounted) {
            await _shakeController.forward();
            // Add a small pause after shake
            await Future.delayed(const Duration(milliseconds: 400));
            if (mounted) {
              setState(() {
                showingAnimation = false;
                canSelect = true;
              });
              _startRoundTimer();
            }
          }
        });
      }
    });
  }

  void _selectShape(int index) {
    if (!canSelect) return;

    // Trigger tap animation
    _animateTap(index);

    setState(() {
      selectedShapeIndex = index;
      canSelect = false;
    });

    if (index == movedShapeIndex) {
      score += 10;
      correctAnswers++;
      SoundEffectsManager().playSuccessWithVoice();
      _showResult(true);
    } else {
      SoundEffectsManager().playWrong();
      _showResult(false);
    }
  }

  void _showResult(bool correct) {
    setState(() {
      showingResult = true;
      isCorrectResult = correct;
      resultText = correct ? 'Correct!' : 'Wrong!';
    });

    // Start the animation
    _resultAnimationController.reset();
    _resultAnimationController.forward();

    // Hide result text after 3 seconds and proceed to next round
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          showingResult = false;
        });
        _resultAnimationController.reset();
        _nextRound();
      }
    });
  }

  void _nextRound() {
    setState(() {
      roundsPlayed++;
    });

    if (roundsPlayed >= totalRounds) {
      _endGame();
      return;
    }

    _shakeController.reset();
    // Prepare next round and start it immediately (don't show intro again)
    setState(() {
      timer = 0;
    });

    _initializeGame();

    // Small delay to allow UI to settle, then start the next round automatically
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        // DEBUG: auto-starting next round
        // ignore: avoid_print
        print('[WhoMoved] auto-starting next round ${roundsPlayed + 1}');
        _startGame();
      }
    });
  }

  void _endGame() {
    setState(() {
      gameCompleted = true;
      canSelect = false;
    });

    if (widget.onGameComplete != null) {
      final completionTime = DateTime.now().difference(gameStartTime).inSeconds;
      int accuracy = 0;
      if (roundsPlayed > 0) {
        final safeCorrect = math.min(correctAnswers, roundsPlayed);
        accuracy = ((safeCorrect / roundsPlayed) * 100).round();
      }
      accuracy = accuracy.clamp(0, 100);
      widget.onGameComplete!(
        accuracy: accuracy,
        completionTime: completionTime,
        challengeFocus: widget.challengeFocus ?? 'Memory',
        gameName: widget.gameName ?? 'Who Moved?',
        difficulty: _normalizedDifficulty,
      );
    }

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
              child: const Icon(
                Icons.emoji_events,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Excellent Work! 🎉',
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
              _buildStatRow(Icons.flag_circle, 'Rounds Completed', '$correctAnswers/$totalRounds'),
              const SizedBox(height: 12),
              _buildStatRow(Icons.star_rounded, 'Final Score', '$score points'),
              const SizedBox(height: 12),
              _buildStatRow(Icons.speed, 'Accuracy', '${((correctAnswers / totalRounds) * 100).round()}%'),
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

  void _resetGame() {
    setState(() {
      score = 0;
      timer = 0;
      gameStarted = false;
      roundsPlayed = 0;
      correctAnswers = 0;
      gameCompleted = false;
      canSelect = false;
      showingAnimation = false;
      showingCountdown = false;
      countdownNumber = 3;
      showingResult = false;
      resultText = '';
      isCorrectResult = false;
    });
    gameStartTime = DateTime.now();
    _shakeController.reset();
    _initializeGame();
  }

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

  Widget _buildShapeGrid() {
    int columns;
    double shapeSize;
    switch (numberOfShapes) {
      case 3:
        columns = 3;
        shapeSize = 270.0;
        break;
      case 5:
        columns = 3;
        shapeSize = 240.0;
        break;
      case 8:
        columns = 2;
        shapeSize = 260.0;
        break;
      default:
        columns = 3;
        shapeSize = 190.0;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double availableWidth = constraints.maxWidth;
        double spacing = numberOfShapes == 8 ? 12.0 : 18.0;
        double maxShapeSize =
            (availableWidth - (columns - 1) * spacing) / columns;
        shapeSize = math.min(shapeSize, maxShapeSize - 16);

        return Wrap(
          alignment: WrapAlignment.center,
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(numberOfShapes, (index) {
            bool isSelected = selectedShapeIndex == index;
            bool isMoved = index == movedShapeIndex && showingAnimation;

            return AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                double shakeOffset = 0;
                if (isMoved) {
                  shakeOffset =
                      math.sin(_shakeAnimation.value * math.pi * 8) *
                      2; // Shake 18px
                }
                return Transform.translate(
                  offset: Offset(shakeOffset, 0),
                  child: GestureDetector(
                    onTap: () => _selectShape(index),
                    child: AnimatedScale(
                      scale: tapStates[index] ? 0.9 : 1.0,
                      duration: Duration(milliseconds: 150),
                      curve: Curves.easeInOut,
                      child: Container(
                        width: shapeSize,
                        height: shapeSize,
                        child: Center(
                          child: CustomShapeWidget(
                            shape: shapes[index],
                            size: shapeSize,
                            isSelected: isSelected,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
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
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, headerGradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              foregroundColor: Colors.white,
              title: Text(
                'Who Moved? - ${DifficultyUtils.getDifficultyDisplayName(widget.difficulty)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              elevation: 0,
              centerTitle: true,
              automaticallyImplyLeading: false,
            ),
            body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, headerGradientEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Score: $score',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Round: ${roundsPlayed + 1}/$totalRounds',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        canSelect && timer > 0
                            ? 'Time: ${timer}s'
                            : showingAnimation
                            ? 'Get Ready...'
                            : '',
                        style: TextStyle(
                          color: timer <= 5 && canSelect
                              ? Colors.red
                              : Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        if (!gameStarted) ...[
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.visibility,
                                  size: 80,
                                  color: Color(0xFF5B6F4A),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        spreadRadius: 1,
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'Round-based Challenge!',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF5B6F4A),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        spreadRadius: 1,
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'Complete 3 rounds. Each round gets faster!\nOne shape will shake. Can you spot which one?',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                if (roundsPlayed > 0) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF5B6F4A,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Round ${roundsPlayed + 1} - Speed: ${shakeDuration.inMilliseconds}ms - Timer: ${timerDuration}s',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF5B6F4A),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                const SizedBox(height: 30),
                                ElevatedButton(
                                  onPressed: _startGame,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF5B6F4A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 40,
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                  ),
                                  child: const Text(
                                    'Start Round',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              showingCountdown
                                  ? 'Get ready...'
                                  : showingAnimation
                                  ? 'Watch the shaking shape!'
                                  : canSelect
                                  ? 'Which shape was shaking?'
                                  : 'Memorize the positions...',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5B6F4A),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: Stack(
                              children: [
                                Center(child: _buildShapeGrid()),
                                if (showingCountdown)
                                  Center(
                                    child: Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.9),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.3),
                                            spreadRadius: 2,
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          countdownNumber.toString(),
                                          style: const TextStyle(
                                            fontSize: 80,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF5B6F4A),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (showingResult)
                                  Center(
                                    child: AnimatedBuilder(
                                      animation: _resultAnimationController,
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale: _resultScaleAnimation.value * _resultBounceAnimation.value,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                                            decoration: BoxDecoration(
                                              color: isCorrectResult 
                                                  ? Colors.green.withOpacity(0.9)
                                                  : Colors.red.withOpacity(0.9),
                                              borderRadius: BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.3),
                                                  spreadRadius: 2,
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              resultText,
                                              style: const TextStyle(
                                                fontSize: 48,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
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
    );
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

class CustomShapeWidget extends StatelessWidget {
  final GameShape shape;
  final double size;
  final bool isSelected;

  const CustomShapeWidget({
    super.key, 
    required this.shape, 
    required this.size,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: ShapePainter(shape.type, shape.color, isSelected),
    );
  }
}

class ShapePainter extends CustomPainter {
  final ShapeType shapeType;
  final Color color;
  final bool isSelected;

  ShapePainter(this.shapeType, this.color, this.isSelected);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    // Create gradient colors based on the base color
    final lightColor = Color.lerp(color, Colors.white, 0.3)!;
    final darkColor = Color.lerp(color, Colors.black, 0.2)!;

    // Gradient fill
    final gradientPaint = Paint()
      ..shader = RadialGradient(
        colors: [lightColor, color, darkColor],
        stops: const [0.0, 0.7, 1.0],
        center: const Alignment(-0.3, -0.3),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    // Enhanced border with gradient
    final borderGradient = LinearGradient(
      colors: [
        Colors.white.withOpacity(0.8),
        Colors.white.withOpacity(0.4),
        Colors.white.withOpacity(0.8),
      ],
      stops: const [0.0, 0.5, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final borderPaint = Paint()
      ..shader = borderGradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Multiple shadow layers for depth
    final shapePath = _getShapePath(shapeType, center, radius);
    
    // Selection highlight - draw glowing outline if selected
    if (isSelected) {
      // Outer glow using the shape's color
      final glowColor = Color.lerp(color, Colors.white, 0.4)!;
      canvas.drawShadow(
        _getShapePath(shapeType, center, radius + 8),
        glowColor.withOpacity(0.8),
        12,
        false,
      );
      canvas.drawShadow(
        _getShapePath(shapeType, center, radius + 4),
        glowColor.withOpacity(0.6),
        8,
        false,
      );
    }
    
    // Deep shadow
    canvas.drawShadow(
      shapePath.shift(const Offset(3, 3)),
      Colors.black.withOpacity(0.25),
      8,
      false,
    );
    
    // Medium shadow
    canvas.drawShadow(
      shapePath.shift(const Offset(1, 1)),
      Colors.black.withOpacity(0.15),
      4,
      false,
    );
    
    // Soft shadow
    canvas.drawShadow(
      shapePath,
      Colors.black.withOpacity(0.08),
      2,
      false,
    );

    // Draw main shape with gradient
    canvas.drawPath(shapePath, gradientPaint);
    
    // Inner highlight for 3D effect
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    final innerPath = _getShapePath(shapeType, center, radius * 0.85);
    canvas.drawPath(innerPath, highlightPaint);
    
    // Draw border
    canvas.drawPath(shapePath, borderPaint);
    
    // Selection outline - draw bright outline if selected
    if (isSelected) {
      final selectionPaint = Paint()
        ..color = Color.lerp(color, Colors.white, 0.6)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      
      final outlinePath = _getShapePath(shapeType, center, radius + 2);
      canvas.drawPath(outlinePath, selectionPaint);
    }
  }

  Path _getShapePath(ShapeType type, Offset center, double radius) {
    switch (type) {
      case ShapeType.circle:
        return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
      case ShapeType.square:
        return Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: center,
              width: radius * 1.6,
              height: radius * 1.6,
            ),
            Radius.circular(radius * 0.35),
          ),
        );
      case ShapeType.triangle:
        final path = Path();
        path.moveTo(center.dx, center.dy - radius);
        path.lineTo(center.dx - radius, center.dy + radius * 0.8);
        path.lineTo(center.dx + radius, center.dy + radius * 0.8);
        path.close();
        return path;
      case ShapeType.diamond:
        final path = Path();
        path.moveTo(center.dx, center.dy - radius);
        path.lineTo(center.dx + radius * 0.8, center.dy);
        path.lineTo(center.dx, center.dy + radius);
        path.lineTo(center.dx - radius * 0.8, center.dy);
        path.close();
        return path;
      case ShapeType.pentagon:
        final path = Path();
        for (int i = 0; i < 5; i++) {
          final angle = (i * 2 * math.pi / 5) - math.pi / 2;
          final x = center.dx + radius * math.cos(angle);
          final y = center.dy + radius * math.sin(angle);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        return path;
      case ShapeType.hexagon:
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = (i * 2 * math.pi / 6) - math.pi / 2;
          final x = center.dx + radius * math.cos(angle);
          final y = center.dy + radius * math.sin(angle);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        return path;
      case ShapeType.star:
        final path = Path();
        for (int i = 0; i < 5; i++) {
          final outerAngle = (i * 2 * math.pi / 5) - math.pi / 2;
          final innerAngle = ((i + 0.5) * 2 * math.pi / 5) - math.pi / 2;
          final outerX = center.dx + radius * math.cos(outerAngle);
          final outerY = center.dy + radius * math.sin(outerAngle);
          final innerX = center.dx + (radius * 0.5) * math.cos(innerAngle);
          final innerY = center.dy + (radius * 0.5) * math.sin(innerAngle);
          if (i == 0) {
            path.moveTo(outerX, outerY);
          } else {
            path.lineTo(outerX, outerY);
          }
          path.lineTo(innerX, innerY);
        }
        path.close();
        return path;
      case ShapeType.oval:
        return Path()..addOval(
          Rect.fromCenter(
            center: center,
            width: radius * 2,
            height: radius * 1.2,
          ),
        );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
