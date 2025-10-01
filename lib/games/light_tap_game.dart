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
  bool showingGo = false; //bago
  late final AnimationController _goController;
  late final Animation<double> _goOpacity;
  late final Animation<double> _goScale;
  // HUD pop-in animation
  late final AnimationController _hudController;
  late final Animation<double> _hudOpacity;
  late final Animation<double> _hudScale;
  bool showHud = false;
  // Status overlay (check/X) state
  bool showingStatus = false;
  String overlayText = '';
  Color overlayColor = Colors.green;
  Color overlayTextColor = Colors.white;
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
  final Color primaryColor = const Color(0xFF5B6F4A);
  final Color accentColor = const Color(0xFFFFD740);
  final Color backgroundColor = const Color(0xFF5B6F4A); // darker game bg
  final Color surfaceColor = Colors.white;
  final Color errorColor = const Color(0xFFE57373);
  final Color successColor = const Color(0xFF81C784);
  // Header gradient end color (matches Find Me)
  final Color headerGradientEnd = const Color(0xFF6B7F5A);

  // Pastel light colors mapped to icons for accessibility (SPED-friendly)
  // Order matches _getLightIcon/_getLightName: Star, Heart, Lightning, Sun, Moon, Fire, Water, Leaf, Diamond
  final List<Color> lightColors = [
    const Color(0xFFFFF9C4), // Star - soft yellow
    const Color(0xFFFFCDD2), // Heart - light red/pink
    const Color(0xFFFFE082), // Lightning - soft amber
    const Color(0xFFFFECB3), // Sun - warm light orange
    const Color(0xFFCFD8DC), // Moon - soft blue grey
    const Color(0xFFFFCCBC), // Fire - soft orange
    const Color(0xFFB3E5FC), // Water - light blue
    const Color(0xFFC8E6C9), // Leaf - light green
    const Color(0xFFE1BEE7), // Diamond - light purple
  ];

  final Color inactiveLightColor = const Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    // Start background music for this game
    BackgroundMusicManager().startGameMusic('Light Tap');
//new
    _goController = AnimationController(
     vsync: this,
     duration: const Duration(milliseconds: 350),
   );
   _goOpacity = CurvedAnimation(parent: _goController, curve: Curves.easeInOut);
   _goScale = Tween<double>(begin: 0.90, end: 1.0).animate(
     CurvedAnimation(parent: _goController, curve: Curves.easeOutBack),
     
   );
   // HUD animation init
   _hudController = AnimationController(
     vsync: this,
     duration: const Duration(milliseconds: 350),
   );
   _hudOpacity = CurvedAnimation(parent: _hudController, curve: Curves.easeInOut);
   _hudScale = Tween<double>(begin: 0.85, end: 1.0).animate(
     CurvedAnimation(parent: _hudController, curve: Curves.easeOutBack),
   );
    // Normalize difficulty once
    _normalizedDifficulty = DifficultyUtils.normalizeDifficulty(
      widget.difficulty,
    );
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
    _goController.dispose();//bgo
    _hudController.dispose();
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
        duration: const Duration(milliseconds: 300), // smooth color transition
        vsync: this,
      ),
    );

    scaleAnimations = animationControllers
        .map(
          (controller) => Tween<double>(begin: 1.0, end: 1.0).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeInOut),
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

      await Future.delayed(const Duration(milliseconds: 1000));
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
        showHud = true;
      });

      _hudController.forward();
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
    await Future.delayed(const Duration(milliseconds: 500));

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
    //eto bago sa
    if (!mounted) return;
    await _showGoOverlay();

    // Ready for user input
    setState(() {
      isShowingSequence = false;
      isWaitingForInput = true;
    });
  }

  //bago sa baba
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

  // Generic status overlay for correct/wrong feedback
  Future<void> _showStatusOverlay({
    required String text,
    required Color color,
    Color textColor = Colors.white,
  }) async {
    if (!mounted) return;
    setState(() {
      overlayText = text;
      overlayColor = color;
      overlayTextColor = textColor;
      showingStatus = true;
    });
    await _goController.forward();
    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    await _goController.reverse();
    if (!mounted) return;
    setState(() {
      showingStatus = false;
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
    Future.delayed(const Duration(milliseconds: 200), () {
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

          // Show green check overlay
          _showStatusOverlay(text: '✓', color: Colors.green, textColor: Colors.white);

          // Pause briefly, then continue
          Future.delayed(const Duration(milliseconds: 1000), () {
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

        // Show red "X" overlay
        _showStatusOverlay(text: 'X', color: Colors.red, textColor: Colors.white);

        // Pause briefly before next round
        Future.delayed(const Duration(milliseconds: 1000), () {
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
            const SizedBox(height: 16),
            Text(
              isCorrect ? 'Great Job!' : 'Try Again!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            if (isCorrect) ...[
              const SizedBox(height: 8),
              Text(
                'Level $currentLevel Complete!',
                style: TextStyle(fontSize: 16, color: primaryColor),
              ),
            ],
          ],
        ),
      ),
    );

    // Auto-close dialog
    Future.delayed(const Duration(milliseconds: 1000), () {
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
      // In session mode, the session screen handles showing the congrats dialog
      // So we don't show our own game over dialog to avoid overlap
      return;
    }

    // Only show game over dialog in demo mode
    if (widget.onGameComplete == null) {
      _showGameOverDialog(completed, accuracy, completionTime);
    }
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
      showHud = false;
    });

    _hudController.reset();
    _initializeGame();
  }

  void _showGameOverDialog(bool completed, int accuracy, int completionTime) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
                completed ? Icons.celebration : Icons.lightbulb_outline,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              completed ? 'Amazing! 🌟' : 'Great Effort! 💡',
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
              _buildStatRow(Icons.star_rounded, 'Score', '$score points'),
              const SizedBox(height: 12),
              _buildStatRow(Icons.track_changes, 'Accuracy', '$accuracy%'),
              const SizedBox(height: 12),
              _buildStatRow(Icons.timer, 'Time', '${completionTime}s'),
              const SizedBox(height: 12),
              _buildStatRow(
                Icons.trending_up,
                'Level Reached',
                '$currentLevel',
              ),
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

  // ---------- NEW: Updated build to match requested circular UI ----------
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _handleBackButton(context);
        return false;
      },
      // ...existing code...
     child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: backgroundColor,
        appBar: AppBar(
          // keep title hidden, make app bar transparent so background image shows through
          title: const SizedBox.shrink(),
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          automaticallyImplyLeading: false,
        ),

        //Use a Container with DecorationImage so assets/background.png is the screen background
        // ...existing code...
        //Use a Container with DecorationImage so assets/background.png is the screen background
        body: Container(
          decoration: BoxDecoration(
            color: backgroundColor, // fallback color
            image: const DecorationImage(
              image: AssetImage('assets/background.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // main UI column
                Column(
                  children: [
                                        // Instruction area (center)
                    Expanded(
                      child: showingCountdown
                          ? _buildCountdownScreen()
                          : (gameStarted
                                ? _buildGameGrid()
                                : _buildStartScreenWithInstruction()),
                    ),
                    // bottom spacer (score circle removed)
                    const SizedBox(height: 0),
                  ],
                ),

                // Side indicators at the vertical middle (show only in-game, with pop animation)
                if (showHud) ...[
                  FadeTransition(
                    opacity: _hudOpacity,
                    child: ScaleTransition(
                      scale: _hudScale,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 104),
                          child: _infoCircle(
                            label: 'Round',
                            value: '${math.min(roundsPlayed + 1, totalRounds)}/$totalRounds',
                            circleSize: 104,
                            valueFontSize: 30,
                            labelFontSize: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                  FadeTransition(
                    opacity: _hudOpacity,
                    child: ScaleTransition(
                      scale: _hudScale,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 104),
                          child: _infoCircle(
                            label: 'Correct',
                            value: '$correctSequences',
                            circleSize: 104,
                            valueFontSize: 30,
                            labelFontSize: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                // "Go!" overlay shown briefly after sequence
                 if (showingGo)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: FadeTransition(
                        opacity: _goOpacity,
                        child: Container(
                          color: Colors.black.withOpacity(0.12), // gentler dim
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
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Yellow GO circle with solid (no-blur) shadow
                                  Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: accentColor, // yellow circle
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.30),
                                          offset: const Offset(0, 8),
                                          blurRadius: 0,    // no blur -> solid shadow edge
                                          spreadRadius: 8,  // thickness of solid shadow
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

                // Status overlay for correct/wrong feedback
                 if (showingStatus)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: FadeTransition(
                        opacity: _goOpacity,
                        child: Container(
                          color: Colors.black.withOpacity(0.12),
                          child: Center(
                            child: ScaleTransition(
                              scale: _goScale,
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: overlayColor,
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
                                    overlayText,
                                    style: TextStyle(
                                      color: overlayTextColor,
                                      fontSize: 72,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
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
      ),
    );
  }

  // ...existing code...
  Widget _buildStartScreenWithInstruction() {
    final size = MediaQuery.of(context).size;
    final bool isTablet = size.shortestSide >= 600;
    final double panelMaxWidth = isTablet ? 560.0 : 420.0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(size.width * 0.9, panelMaxWidth),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                offset: const Offset(0, 12),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Light Tap',
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
                  color: accentColor,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0),
                      blurRadius: 20,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.remove_red_eye_outlined,
                  size: isTablet ? 56 : 48,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Watch carefully!',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: isTablet ? 22 : 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Watch the sequence of glowing lights. When it\'s your turn, tap the same lights in the same order.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryColor.withOpacity(0.9),
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
                    backgroundColor: accentColor,
                    foregroundColor: primaryColor,
                    padding: EdgeInsets.symmetric(
                      vertical: isTablet ? 18 : 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                  child: Text(
                    'START GAME',
                    style: TextStyle(
                      fontSize: isTablet ? 22 : 18,
                      fontWeight: FontWeight.w900,
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
  // ...existing code...

  // ...existing code...
  Widget _infoCircle({
    required String label,
    required String value,
    double circleSize = 88,
    double valueFontSize = 18,
    double labelFontSize = 12,
  }) {
    return Column(
      children: [
        // Label on top (larger, bold)
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: labelFontSize,
            fontWeight: FontWeight.w800,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.45),
                offset: Offset(2, 2),
                blurRadius: 0,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Circle with sharp solid drop shadow (blurRadius = 0)
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
                blurRadius: 0, // sharp solid shadow
                spreadRadius: 4,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: TextStyle(
              color: primaryColor,
              fontSize: valueFontSize,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
  // ...existing code...

  Widget _bigCircle({required Widget child}) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: headerGradientEnd,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            offset: const Offset(0, 6),
            blurRadius: 8,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _smallCircle({required Widget child}) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: primaryColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            offset: const Offset(0, 4),
            blurRadius: 6,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  // ---------- Existing UI builders reused below ----------

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
          ),
        ),
        const SizedBox(height: 40),
        Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFD740),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD740).withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$countdownNumber',
              style: const TextStyle(
                fontSize: 80,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5B6F4A),
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
        final gridSz = maxSize * 0.8;
        final buttonSize = (gridSz / math.max(columns, rows)) - 12;

        return Center(
          child: SizedBox(
            width: gridSz,
            height: gridSz,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: gridSize,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _onLightTap(index),
                  child: AnimatedScale(
                    scale: tapStates[index]
                        ? 0.95
                        : (lightStates[index] ? 1.05 : 1.0),
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeInOut,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: lightStates[index]
                            ? lightColors[index % lightColors.length].withOpacity(0.10)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                                                    Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: buttonSize * 0.38,
                                  height: buttonSize * 0.38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: lightColors[index % lightColors.length].withOpacity(0.15),
                                    border: Border.all(
                                      color: lightStates[index]
                                          ? lightColors[index % lightColors.length].withOpacity(0.55)
                                          : lightColors[index % lightColors.length].withOpacity(0.35),
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _getLightIcon(index),
                                    size: buttonSize * 0.22,
                                    color: _iconColorForIndex(index, lightStates[index]),
                                  ),
                                ),
                                const SizedBox(height: 4),
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
    Future.delayed(const Duration(milliseconds: 150), () {
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
      Icons.star, // 0 - Star
      Icons.favorite, // 1 - Heart
      Icons.flash_on, // 2 - Lightning
      Icons.brightness_high, // 3 - Sun
      Icons.nightlight, // 4 - Moon
      Icons.local_fire_department, // 5 - Fire
      Icons.water_drop, // 6 - Water
      Icons.eco, // 7 - Leaf
      Icons.diamond, // 8 - Diamond
    ];
    return icons[index % icons.length];
  }

  // Helper method to get name for each light position
  String _getLightName(int index) {
    final names = [
      'Star', // 0
      'Heart', // 1
      'Lightning', // 2
      'Sun', // 3
      'Moon', // 4
      'Fire', // 5
      'Water', // 6
      'Leaf', // 7
      'Diamond', // 8
    ];
    return names[index % names.length];
  }

  // Produce a lighter, hue-aligned icon color for better visibility without being harsh
  Color _iconColorForIndex(int index, bool active) {
    final base = lightColors[index % lightColors.length];
    final hsl = HSLColor.fromColor(base);
    final double targetLightness = active ? 0.62 : 0.58; // lighter to reduce darkness on tiles
    final double targetSaturation = (hsl.saturation + 0.18).clamp(0.45, 0.65); // moderate saturation
    return HSLColor.fromAHSL(1.0, hsl.hue, targetSaturation, targetLightness).toColor();
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
                const Icon(Icons.security, color: Color(0xFF5B6F4A), size: 32),
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
                  borderSide: const BorderSide(color: Color(0xFF5B6F4A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF5B6F4A),
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
// ...existing code...