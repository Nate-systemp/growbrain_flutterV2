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
  })? onGameComplete;

  const FindMeGame({
    super.key,
    required this.difficulty,
    this.onGameComplete,
  });

  @override
  State<FindMeGame> createState() => _FindMeGameState();
}

class _FindMeGameState extends State<FindMeGame>
    with TickerProviderStateMixin {
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
  int round = 1;
  static const int maxRounds = 5;
  int tappedIndex = -1;

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

    _cardAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.elasticOut,
    ));

    _scoreAnimation = Tween<double>(
      begin: 1.0,
      end: 1.5,
    ).animate(CurvedAnimation(
      parent: _scoreAnimationController,
      curve: Curves.elasticOut,
    ));

    _tapAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(
      parent: _tapAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  void _initializeGame() {
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
    switch (widget.difficulty.toLowerCase()) {
      case 'easy':
        baseObjectCount = 4;
        break;
      case 'medium':
        baseObjectCount = 6;
        break;
      case 'hard':
        baseObjectCount = 9;
        break;
      default:
        baseObjectCount = 6;
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
      gameObjects.add(GameObject(
        id: i,
        icon: object['icon'],
        name: object['name'],
        isTarget: false,
      ));
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
        _wrongAnswer();
      }
    });
  }

  void _correctAnswer() {
    setState(() {
      score += 10;
      correctAnswers++;
    });

    // Play success sound effect
    SoundEffectsManager().playSuccess();

    _scoreAnimationController.forward().then((_) {
      _scoreAnimationController.reverse();
    });

    _nextRound();
  }

  void _wrongAnswer() {
    setState(() {
      timeLeft = (timeLeft - 5).clamp(0, 60);
    });

    // Play wrong sound effect
    SoundEffectsManager().playWrong();

    // Show feedback animation
    _cardAnimationController.reverse().then((_) {
      _cardAnimationController.forward();
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
        difficulty: widget.difficulty,
      );
    }

    _showGameOverDialog();
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF5B6F4A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Nice Job! 😊',
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
              Icon(
                Icons.emoji_events,
                color: const Color(0xFFFFD740),
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Final Score: $score',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Rounds Completed: $round',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          actions: [
            Container(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Close game and return to session
                },
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD740),
                  foregroundColor: const Color(0xFF5B6F4A),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Continue',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
    _showTeacherPinDialog(context);
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
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          },
          onCancel: () {
            Navigator.of(dialogContext).pop(); // Just close dialog, stay in game
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
                Expanded(
                  child: Center(
                    child: _buildTargetDisplay(),
                  ),
                ),
              if (gameStarted && !gameEnded && !isShowingTarget)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: _buildInstructions(),
                    ),
                  ),
                ),
              if (gameStarted && !gameEnded && !isShowingTarget)
                Expanded(
                  child: Stack(
                    children: [
                      _buildGameGrid(),
                    ],
                  ),
                ),
              if (!gameStarted)
                Expanded(
                  child: Center(
                    child: _buildStartCubeButton(),
                  ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF5B6F4A),
            const Color(0xFF6B7F5A),
          ],
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
        Icon(
          icon,
          color: const Color(0xFFFFD740),
          size: 24,
        ),
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
          return Transform.scale(
            scale: animation.value,
            child: content,
          );
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
                border: Border.all(
                  color: const Color(0xFF5B6F4A),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    targetObject!.icon,
                    size: 32,
                    color: const Color(0xFF5B6F4A),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    targetObject!.name,
                    style: TextStyle(
                      color: const Color(0xFF5B6F4A),
                      fontSize: 14,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF5B6F4A).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF5B6F4A).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: const Color(0xFF5B6F4A),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tap the ${targetObject?.name ?? "object"} you just saw!',
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
        child: CircularProgressIndicator(
          color: const Color(0xFF5B6F4A),
        ),
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
            double availableWidth = constraints.maxWidth - (spacing * (crossAxisCount + 1));
            double availableHeight = constraints.maxHeight - (spacing * (rowCount + 1));
            
            double cardWidth = availableWidth / crossAxisCount;
            double cardHeight = availableHeight / rowCount;
            double cardSize = min(cardWidth, cardHeight);
            
            // Set maximum card sizes based on object count for better readability
            if (gameObjects.length <= 4) {
              cardSize = min(cardSize, 120.0);
            } else if (gameObjects.length <= 6) {
              cardSize = min(cardSize, 110.0);
            } else if (gameObjects.length <= 9) {
              cardSize = min(cardSize, 100.0);
            } else {
              cardSize = min(cardSize, 90.0);
            }
            
            // Ensure minimum readable size
            cardSize = max(cardSize, 70.0);

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
                  colors: isTapped ? [
                    const Color(0xFFFFD740).withValues(alpha: 0.3),
                    const Color(0xFFFFD740).withValues(alpha: 0.1),
                  ] : [
                    Colors.white,
                    const Color(0xFFF8F8F8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isTapped 
                    ? const Color(0xFFFFD740)
                    : const Color(0xFF5B6F4A).withValues(alpha: 0.2),
                  width: isTapped ? 3.0 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isTapped ? 0.15 : 0.06),
                    blurRadius: isTapped ? 8 : 4,
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
                    color: const Color(0xFF5B6F4A),
                  ),
                  SizedBox(height: cardSize * 0.08),
                  Text(
                    object.name,
                    style: TextStyle(
                      color: const Color(0xFF5B6F4A),
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
    // Square cube with play icon and a small label below
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _startGame,
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: const Color(0xFF5B6F4A),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 44,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Start Game',
          style: TextStyle(
            color: const Color(0xFF5B6F4A),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TeacherPinDialog extends StatefulWidget {
  final VoidCallback onPinVerified;
  final VoidCallback? onCancel;

  const _TeacherPinDialog({
    required this.onPinVerified,
    this.onCancel,
  });

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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.security,
                  color: const Color(0xFF5B6F4A),
                  size: 32,
                ),
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
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
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
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  letterSpacing: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: const Color(0xFF5B6F4A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: const Color(0xFF5B6F4A), width: 2),
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
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
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
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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


