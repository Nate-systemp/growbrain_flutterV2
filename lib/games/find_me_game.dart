import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/background_music_manager.dart';
import '../utils/difficulty_utils.dart';
import '../utils/sound_effects_manager.dart';

class FindMeGame extends StatefulWidget {
  final String difficulty;
  final Future<void> Function({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })?
  onGameComplete;

  const FindMeGame({super.key, required this.difficulty, this.onGameComplete});

  @override
  State<FindMeGame> createState() => _FindMeGameState();
}

class _FindMeGameState extends State<FindMeGame> with TickerProviderStateMixin {
  late AnimationController _cardAnimationController;
  late AnimationController _scoreAnimationController;
  late AnimationController _tapAnimationController;
  late Animation<double> _cardAnimation;
  late Animation<double> _scoreAnimation;
  late Animation<double> _tapAnimation;

  List<GameObject> gameObjects = [];
  GameObject? targetObject;
  int score = 0;
  int correctAnswers = 0;
  int timeLeft = 60;
  Timer? gameTimer;
  Timer? showTimer;
  bool gameStarted = false;
  bool gameEnded = false;
  bool isShowingTarget = false;
  bool _isWrongHighlight = false;
  bool _isCorrectHighlight = false;
  int round = 1;
  static const int maxRounds = 5;
  int tappedIndex = -1;
  String _normalizedDifficulty = 'Starter';

  @override
  void initState() {
    super.initState();
    // Start background music for this game
    BackgroundMusicManager().startGameMusic('Find Me');
    _initializeAnimations();
    _initializeGame();
  }

  void _initializeAnimations() {
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scoreAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _tapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _cardAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _scoreAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(
        parent: _scoreAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _tapAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _tapAnimationController, curve: Curves.easeInOut),
    );
  }

  void _initializeGame() {
    _normalizedDifficulty = DifficultyUtils.normalizeDifficulty(widget.difficulty);
    _generateGameObjects();
    _selectTarget();
  }

  void _generateGameObjects() {
    final List<Map<String, dynamic>> allObjectData = [
      // Basic Objects (16)
      {'icon': Icons.sports_soccer, 'name': 'Ball'},
      {'icon': Icons.car_rental, 'name': 'Car'},
      {'icon': Icons.home, 'name': 'House'},
      {'icon': Icons.favorite, 'name': 'Heart'},
      {'icon': Icons.star, 'name': 'Star'},
      {'icon': Icons.pets, 'name': 'Pet'},
      {'icon': Icons.local_florist, 'name': 'Flower'},
      {'icon': Icons.cake, 'name': 'Cake'},
      {'icon': Icons.music_note, 'name': 'Music'},
      {'icon': Icons.sunny, 'name': 'Sun'},
      {'icon': Icons.umbrella, 'name': 'Umbrella'},
      {'icon': Icons.airplane_ticket, 'name': 'Plane'},
      {'icon': Icons.school, 'name': 'School'},
      {'icon': Icons.book, 'name': 'Book'},
      {'icon': Icons.emoji_food_beverage, 'name': 'Cup'},
      {'icon': Icons.face, 'name': 'Face'},

      // Additional Diverse Icons (20)
      {'icon': Icons.apple, 'name': 'Apple'},
      {'icon': Icons.beach_access, 'name': 'Beach'},
      {'icon': Icons.camera_alt, 'name': 'Camera'},
      {'icon': Icons.diamond, 'name': 'Diamond'},
      {'icon': Icons.flash_on, 'name': 'Lightning'},
      {'icon': Icons.park, 'name': 'Tree'},
      {'icon': Icons.sports_esports, 'name': 'Game'},
      {'icon': Icons.headphones, 'name': 'Headphones'},
      {'icon': Icons.ice_skating, 'name': 'Ice Skate'},
      {'icon': Icons.vpn_key, 'name': 'Key'},
      {'icon': Icons.lightbulb, 'name': 'Bulb'},
      {'icon': Icons.map, 'name': 'Map'},
      {'icon': Icons.nightlight, 'name': 'Moon'},
      {'icon': Icons.palette, 'name': 'Paint'},
      {'icon': Icons.rocket_launch, 'name': 'Rocket'},
      {'icon': Icons.sailing, 'name': 'Boat'},
      {'icon': Icons.train, 'name': 'Train'},
      {'icon': Icons.watch, 'name': 'Watch'},
      {'icon': Icons.yard, 'name': 'Garden'},
      {'icon': Icons.zoom_in, 'name': 'Magnify'},

      // Complex Icons (20)
      {'icon': Icons.anchor, 'name': 'Anchor'},
      {'icon': Icons.balance, 'name': 'Scale'},
      {'icon': Icons.castle, 'name': 'Castle'},
      {'icon': Icons.directions_bike, 'name': 'Bike'},
      {'icon': Icons.eco, 'name': 'Leaf'},
      {'icon': Icons.fingerprint, 'name': 'Print'},
      {'icon': Icons.gavel, 'name': 'Hammer'},
      {'icon': Icons.hiking, 'name': 'Hiker'},
      {'icon': Icons.icecream, 'name': 'Ice Cream'},
      {'icon': Icons.keyboard, 'name': 'Keyboard'},
      {'icon': Icons.landscape, 'name': 'Mountain'},
      {'icon': Icons.medical_services, 'name': 'Medical'},
      {'icon': Icons.nature_people, 'name': 'Nature'},
      {'icon': Icons.outdoor_grill, 'name': 'Grill'},
      {'icon': Icons.piano, 'name': 'Piano'},
      {'icon': Icons.quiz, 'name': 'Quiz'},
      {'icon': Icons.restaurant, 'name': 'Food'},
      {'icon': Icons.sports_tennis, 'name': 'Tennis'},
      {'icon': Icons.theater_comedy, 'name': 'Comedy'},
      {'icon': Icons.umbrella_outlined, 'name': 'Parasol'},

      // Advanced Icons (14)
      {'icon': Icons.apartment, 'name': 'Building'},
      {'icon': Icons.brush, 'name': 'Brush'},
      {'icon': Icons.celebration, 'name': 'Party'},
      {'icon': Icons.dashboard, 'name': 'Dashboard'},
      {'icon': Icons.extension, 'name': 'Puzzle'},
      {'icon': Icons.flight_takeoff, 'name': 'Flight'},
      {'icon': Icons.gesture, 'name': 'Gesture'},
      {'icon': Icons.handyman, 'name': 'Tools'},
      {'icon': Icons.inventory, 'name': 'Box'},
      {'icon': Icons.join_inner, 'name': 'Connect'},
      {'icon': Icons.kitchen, 'name': 'Kitchen'},
      {'icon': Icons.language, 'name': 'Globe'},
      {'icon': Icons.memory, 'name': 'Chip'},
      {'icon': Icons.navigation, 'name': 'Compass'},
    ];

    gameObjects.clear();
    tappedIndex = -1; // Reset tapped index

    // Progressive difficulty: increase objects as rounds progress
    int baseObjectCount;
    switch (_normalizedDifficulty) {
      case 'Starter':
        baseObjectCount = 4;
        break;
      case 'Growing':
        baseObjectCount = 6;
        break;
      case 'Challenged':
        baseObjectCount = 9;
        break;
      default:
        baseObjectCount = 4;
        break;
    }

    // Add extra objects in later rounds
    int extraObjects = 0;
    if (round >= 3) extraObjects = 1;
    if (round >= 4) extraObjects = 2;
    if (round >= 5) extraObjects = 3;

    int totalObjects = baseObjectCount + extraObjects;

    // Shuffle and select objects
    final selectedObjects = List.from(allObjectData);
    selectedObjects.shuffle();

    for (int i = 0; i < totalObjects && i < selectedObjects.length; i++) {
      final object = selectedObjects[i];
      gameObjects.add(
        GameObject(
          id: i,
          icon: object['icon'],
          name: object['name'],
          isTarget: false,
        ),
      );
    }
  }

  void _selectTarget() {
    if (gameObjects.isNotEmpty) {
      final random = Random();
      targetObject = gameObjects[random.nextInt(gameObjects.length)];
      targetObject!.isTarget = true;
    }
  }

  void _startGame() {
    setState(() {
      gameStarted = true;
      isShowingTarget = true;
    });

    _cardAnimationController.forward();

    // Progressive difficulty: decrease target display time
    int displayTime = 3;
    if (round >= 3) displayTime = 2;
    if (round >= 5) displayTime = 1;

    showTimer = Timer(Duration(seconds: displayTime), () {
      setState(() {
        isShowingTarget = false;
      });
      _startTimer();
    });
  }

  void _startTimer() {
    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        timeLeft--;
      });

      if (timeLeft <= 0) {
        _endGame();
      }
    });
  }

  void _onObjectTapped(GameObject object, int index) {
    if (!gameStarted || gameEnded || isShowingTarget) return;

    // Trigger tap animation
    setState(() {
      tappedIndex = index;
    });

    _tapAnimationController.forward().then((_) {
      _tapAnimationController.reverse();
    });

    // Small delay for visual feedback
    Timer(const Duration(milliseconds: 100), () {
      if (object.isTarget) {
        _correctAnswer();
      } else {
        _wrongAnswer(index);
      }
    });
  }

  void _correctAnswer() {
    setState(() {
      score += 10;
      correctAnswers++;
      // mark correct so UI can show green feedback
      _isCorrectHighlight = true;
      _isWrongHighlight = false;
    });

    // Play success sound effect with voice
    SoundEffectsManager().playSuccessWithVoice();

    _scoreAnimationController.forward().then((_) {
      _scoreAnimationController.reverse();
    });

    // Pause briefly to show green feedback, then advance to next round
    Timer(const Duration(milliseconds: 700), () {
      // clear correct highlight and advance
      setState(() {
        _isCorrectHighlight = false;
      });
      _nextRound();
    });
  }

  void _wrongAnswer(int index) {
    setState(() {
      // Penalize time
      timeLeft = (timeLeft - 5).clamp(0, 60);
      // Mark which card was wrong so we can show red feedback
      tappedIndex = index;
      _isWrongHighlight = true;
    });

    // Play wrong sound effect
    SoundEffectsManager().playWrong();

    // Brief feedback: pulse the card animation and then clear the wrong highlight
    _cardAnimationController.reverse().then((_) {
      _cardAnimationController.forward();
    });

    // Clear wrong highlight after a short delay so the player sees the red feedback
    Timer(const Duration(milliseconds: 700), () {
      setState(() {
        _isWrongHighlight = false;
        tappedIndex = -1;
      });
    });
  }

  void _nextRound() {
    if (round >= maxRounds) {
      _endGame();
      return;
    }

    setState(() {
      round++;
      isShowingTarget = true;
      tappedIndex = -1; // Reset tapped index for new round
    });

    _generateGameObjects();
    _selectTarget();

    // Progressive difficulty: decrease target display time
    int displayTime = 3;
    if (round >= 3) displayTime = 2;
    if (round >= 5) displayTime = 1;

    showTimer = Timer(Duration(seconds: displayTime), () {
      setState(() {
        isShowingTarget = false;
      });
    });
  }

  void _endGame() {
    gameTimer?.cancel();
    showTimer?.cancel();
    setState(() {
      gameEnded = true;
    });

    // Call completion callback if provided
    if (widget.onGameComplete != null) {
      // Accuracy should be correct answers / total rounds (maxRounds)
      int accuracy = 0;
      if (maxRounds > 0) {
        accuracy = ((correctAnswers / maxRounds) * 100).round();
      }
      accuracy = accuracy.clamp(0, 100);
      final timeTaken = 60 - timeLeft;

      widget.onGameComplete!(
        accuracy: accuracy,
        completionTime: timeTaken,
        challengeFocus: 'Visual attention and memory',
        gameName: 'Find Me',
        difficulty: _normalizedDifficulty,
      );
    }

    _showGameOverDialog();
  }

  void _showGameOverDialog() {
    final accuracy = maxRounds > 0 ? ((correctAnswers / maxRounds) * 100).round() : 0;
    final timeTaken = 60 - timeLeft;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
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
                  color: const Color(0xFF5B6F4A),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5B6F4A).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Fantastic! 🔍✨',
                style: TextStyle(
                  color: const Color(0xFF5B6F4A),
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
              color: const Color(0xFFF5F5DC).withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatRow(Icons.star_rounded, 'Final Score', '$score points'),
                const SizedBox(height: 12),
                _buildStatRow(Icons.flag_circle, 'Rounds Completed', '$round/$maxRounds'),
                const SizedBox(height: 12),
                _buildStatRow(Icons.track_changes, 'Accuracy', '$accuracy%'),
                const SizedBox(height: 12),
                _buildStatRow(Icons.timer, 'Time Used', '${timeTaken}s'),
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
                          backgroundColor: const Color(0xFF5B6F4A),
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
                    backgroundColor: const Color(0xFF5B6F4A),
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
            color: const Color(0xFFFFD740).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF5B6F4A), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: const Color(0xFF5B6F4A),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: const Color(0xFF5B6F4A),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _resetGame() {
    gameTimer?.cancel();
    showTimer?.cancel();
    setState(() {
      score = 0;
      timeLeft = 60;
      round = 1;
      gameStarted = false;
      gameEnded = false;
      isShowingTarget = false;
      tappedIndex = -1;
    });
    _cardAnimationController.reset();
    _scoreAnimationController.reset();
    _tapAnimationController.reset();
    _initializeGame();
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
  void dispose() {
    gameTimer?.cancel();
    showTimer?.cancel();
    _cardAnimationController.dispose();
    _scoreAnimationController.dispose();
    _tapAnimationController.dispose();
    // Stop background music when leaving the game
    BackgroundMusicManager().stopMusic();
    super.dispose();
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
        backgroundColor: const Color(0xFFF5F5DC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF5B6F4A),
          foregroundColor: Colors.white,
          title: Text(
            'Find Me! - ${DifficultyUtils.getDifficultyDisplayName(widget.difficulty)}',
            style: TextStyle(fontWeight: FontWeight.bold),
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
                _buildHeader(),
                const SizedBox(height: 20),
                if (gameStarted && !gameEnded && isShowingTarget)
                  Expanded(child: Center(child: _buildTargetDisplay())),
                // During gameplay we show a short prompt telling the player
                // which object to find. The full "How to Play" card is only
                // shown on the start screen (in _buildStartCubeButton()).
                if (gameStarted && !gameEnded && !isShowingTarget)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: _buildFindPrompt(),
                      ),
                    ),
                  ),
                if (gameStarted && !gameEnded && !isShowingTarget)
                  Expanded(child: Stack(children: [_buildGameGrid()])),
                if (!gameStarted)
                  Expanded(child: Center(child: _buildStartCubeButton())),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF5B6F4A), const Color(0xFF6B7F5A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.score,
            label: 'Score',
            value: score.toString(),
            animation: _scoreAnimation,
          ),
          _buildStatItem(
            icon: Icons.timer,
            label: 'Time',
            value: timeLeft.toString(),
          ),
          _buildStatItem(
            icon: Icons.flag,
            label: 'Round',
            value: '$round/$maxRounds',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    Animation<double>? animation,
  }) {
    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFFFD740), size: 24),
        const SizedBox(height: 4),
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

    if (animation != null) {
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.scale(scale: animation.value, child: content);
        },
      );
    }

    return content;
  }

  Widget _buildTargetDisplay() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD740),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Find This Object:',
            style: TextStyle(
              color: const Color(0xFF5B6F4A),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (targetObject != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF5B6F4A), width: 2),
              ),
              child: Column(
                children: [
                  Icon(
                    targetObject!.icon,
                    size: 62,
                    color: const Color(0xFF5B6F4A),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    targetObject!.name,
                    style: TextStyle(
                      color: const Color(0xFF5B6F4A),
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search, color: const Color(0xFF5B6F4A), size: 20),
              const SizedBox(width: 8),
              Text(
                'How to Play:',
                style: TextStyle(
                  color: const Color(0xFF5B6F4A),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1. Watch the object highlighted for a few seconds.',
            style: TextStyle(color: const Color(0xFF5B6F4A), fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            '2. Memorize the object and its position.',
            style: TextStyle(color: const Color(0xFF5B6F4A), fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            '3. Tap the same object when the grid appears.',
            style: TextStyle(color: const Color(0xFF5B6F4A), fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            '4. Rounds get harder with more objects and less time.',
            style: TextStyle(color: const Color(0xFF5B6F4A), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildFindPrompt() {
    final String promptText = targetObject != null
        ? 'Find the ${targetObject!.name} you just saw.'
        : 'Find the object you just saw.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: const Color(0xFF5B6F4A), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              promptText,
              style: TextStyle(
                color: const Color(0xFF5B6F4A),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameGrid() {
    if (gameObjects.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: const Color(0xFF5B6F4A)),
      );
    }

    return AnimatedBuilder(
      animation: _cardAnimation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // Dynamic grid layout based on object count
            int crossAxisCount;
            if (gameObjects.length <= 4) {
              crossAxisCount = 2; // 2x2
            } else if (gameObjects.length <= 6) {
              crossAxisCount = 3; // 2x3 or 3x2
            } else if (gameObjects.length <= 9) {
              crossAxisCount = 3; // 3x3
            } else if (gameObjects.length <= 12) {
              crossAxisCount = 4; // 3x4 or 4x3
            } else {
              crossAxisCount = 4; // 4x4+
            }

            int rowCount = (gameObjects.length / crossAxisCount).ceil();

            // Calculate optimal card size
            double spacing = 8.0;
            double availableWidth =
                constraints.maxWidth - (spacing * (crossAxisCount + 1));
            double availableHeight =
                constraints.maxHeight - (spacing * (rowCount + 1));

            double cardWidth = availableWidth / crossAxisCount;
            double cardHeight = availableHeight / rowCount;
            double cardSize = min(cardWidth, cardHeight);

            // Set maximum card sizes based on object count for better readability
            if (gameObjects.length <= 4) {
              cardSize = min(cardSize, 180.0);
            } else if (gameObjects.length <= 6) {
              cardSize = min(cardSize, 170.0);
            } else if (gameObjects.length <= 9) {
              cardSize = min(cardSize, 160.0);
            } else {
              cardSize = min(cardSize, 130.0);
            }

            // Ensure minimum readable size
            cardSize = max(cardSize, 100.0);

            return Center(
              child: Container(
                padding: EdgeInsets.all(spacing),
                child: Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  alignment: WrapAlignment.center,
                  children: gameObjects.asMap().entries.map((entry) {
                    int index = entry.key;
                    GameObject object = entry.value;

                    return Transform.scale(
                      scale: _cardAnimation.value,
                      child: SizedBox(
                        width: cardSize,
                        height: cardSize,
                        child: _buildGameCard(object, index, cardSize),
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGameCard(GameObject object, int index, double cardSize) {
    bool isTapped = tappedIndex == index;

    final bool isWrong = _isWrongHighlight && tappedIndex == index;
    final bool isCorrect = _isCorrectHighlight && tappedIndex == index;

    return AnimatedBuilder(
      animation: _tapAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTap: () => _onObjectTapped(object, index),
          child: Transform.scale(
            scale: isTapped ? _tapAnimation.value : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: cardSize,
              height: cardSize,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isCorrect
                      ? [
                          Colors.green.withOpacity(0.12),
                          Colors.green.withOpacity(0.06),
                        ]
                      : isWrong
                      ? [
                          Colors.red.withOpacity(0.12),
                          Colors.red.withOpacity(0.06),
                        ]
                      : isTapped
                      ? [
                          const Color(0xFFFFD740).withValues(alpha: 0.3),
                          const Color(0xFFFFD740).withValues(alpha: 0.1),
                        ]
                      : [Colors.white, const Color(0xFFF8F8F8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCorrect
                      ? Colors.green
                      : isWrong
                      ? Colors.red
                      : isTapped
                      ? const Color(0xFFFFD740)
                      : const Color(0xFF5B6F4A).withValues(alpha: 0.2),
                  width: isCorrect
                      ? 3.0
                      : (isWrong ? 3.0 : (isTapped ? 3.0 : 1.5)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isCorrect
                        ? Colors.green.withOpacity(0.12)
                        : isWrong
                        ? Colors.red.withOpacity(0.12)
                        : Colors.black.withValues(
                            alpha: isTapped ? 0.15 : 0.06,
                          ),
                    blurRadius: isTapped || isWrong || isCorrect ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    object.icon,
                    size: cardSize * 0.35,
                    color: isCorrect
                        ? Colors.green
                        : isWrong
                        ? Colors.red
                        : const Color(0xFF5B6F4A),
                  ),
                  SizedBox(height: cardSize * 0.08),
                  Text(
                    object.name,
                    style: TextStyle(
                      color: isCorrect
                          ? Colors.green
                          : isWrong
                          ? Colors.red
                          : const Color(0xFF5B6F4A),
                      fontSize: cardSize * 0.12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStartCubeButton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Round and Correct counters
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Round',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$round/$maxRounds',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Correct',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$correctAnswers',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 40),
        // Game icon and title
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.search,
            size: 60,
            color: Colors.white,
          ),
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
            'Find the object!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 20),
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
          child: const Text(
            'Look for the target object and tap it quickly!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(
              horizontal: 40,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            elevation: 4,
          ),
          onPressed: _startGame,
          child: const Text(
            'Start !',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
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

class GameObject {
  final int id;
  final IconData icon;
  final String name;
  bool isTarget;

  GameObject({
    required this.id,
    required this.icon,
    required this.name,
    this.isTarget = false,
  });
}
