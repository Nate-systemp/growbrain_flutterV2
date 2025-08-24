import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/background_music_manager.dart';
import '../utils/difficulty_utils.dart';

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
  late Animation<double> _cardAnimation;
  late Animation<double> _scoreAnimation;

  List<GameObject> gameObjects = [];
  GameObject? targetObject;
  int score = 0;
  int timeLeft = 60;
  Timer? gameTimer;
  Timer? showTimer;
  bool gameStarted = false;
  bool gameEnded = false;
  bool isShowingTarget = false;
  int round = 1;
  static const int maxRounds = 5;

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
  }

  void _initializeGame() {
    _generateGameObjects();
    _selectTarget();
  }

  void _generateGameObjects() {
    final List<Map<String, dynamic>> objectData = [
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
    ];

    gameObjects.clear();
    final selectedObjects = List.from(objectData);
    selectedObjects.shuffle();

    // Object count based on difficulty
    int objectCount;
    switch (widget.difficulty.toLowerCase()) {
      case 'easy':
        objectCount = 4;
        break;
      case 'medium':
        objectCount = 6;
        break;
      case 'hard':
        objectCount = 9;
        break;
      default:
        objectCount = 6;
    }
    
    for (int i = 0; i < objectCount; i++) {
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

    // Show target for 3 seconds
    showTimer = Timer(const Duration(seconds: 3), () {
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

  void _onObjectTapped(GameObject object) {
    if (!gameStarted || gameEnded || isShowingTarget) return;

    if (object.isTarget) {
      _correctAnswer();
    } else {
      _wrongAnswer();
    }
  }

  void _correctAnswer() {
    setState(() {
      score += 10;
    });

    _scoreAnimationController.forward().then((_) {
      _scoreAnimationController.reverse();
    });

    _nextRound();
  }

  void _wrongAnswer() {
    setState(() {
      timeLeft = (timeLeft - 5).clamp(0, 60);
    });

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
    });

    _generateGameObjects();
    _selectTarget();

    // Show new target for 2 seconds (decreasing time)
    showTimer = Timer(Duration(seconds: 3 - (round ~/ 3)), () {
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
      final accuracy = gameObjects.isNotEmpty ? ((score / gameObjects.length) * 100).round() : 0;
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
            'Game Over!',
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
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _resetGame();
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
                      'Play Again',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Exit',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
    });
    _cardAnimationController.reset();
    _scoreAnimationController.reset();
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
          automaticallyImplyLeading: false, // This removes the back button
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                if (isShowingTarget) _buildTargetDisplay(),
                if (!isShowingTarget && gameStarted && !gameEnded) 
                  _buildInstructions(),
                const SizedBox(height: 20),
                Expanded(child: _buildGameGrid()),
                if (!gameStarted) _buildStartButton(),
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
      padding: const EdgeInsets.all(16),
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
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tap the ${targetObject?.name ?? "object"} you just saw!',
              style: TextStyle(
                color: const Color(0xFF5B6F4A),
                fontSize: 16,
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

    // Determine grid layout based on difficulty
    int crossAxisCount;
    switch (widget.difficulty.toLowerCase()) {
      case 'easy':
        crossAxisCount = 2; // 2x2 for 4 objects
        break;
      case 'medium':
        crossAxisCount = 3; // 2x3 for 6 objects  
        break;
      case 'hard':
        crossAxisCount = 3; // 3x3 for 9 objects
        break;
      default:
        crossAxisCount = 3;
    }
    
    int rowCount = (gameObjects.length / crossAxisCount).ceil();

    return AnimatedBuilder(
      animation: _cardAnimation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // Calculate compact card size that fits all items on screen
            double spacing = 6.0; // Reduced spacing for more compact layout
            double availableWidth = constraints.maxWidth - (spacing * (crossAxisCount + 1));
            double availableHeight = constraints.maxHeight - (spacing * (rowCount + 1));
            
            double cardWidth = availableWidth / crossAxisCount;
            double cardHeight = availableHeight / rowCount;
            double cardSize = min(cardWidth, cardHeight);
            
            // Make cards more compact - reduce maximum size
            cardSize = min(cardSize, 80.0); // Reduced from 100px to 80px
            
            return Center(
              child: Container(
                padding: EdgeInsets.all(spacing),
                child: Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  alignment: WrapAlignment.center,
                  children: gameObjects.map((object) {
                    return Transform.scale(
                      scale: _cardAnimation.value,
                      child: SizedBox(
                        width: cardSize,
                        height: cardSize,
                        child: _buildCompactGameCard(object, cardSize),
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

  Widget _buildCompactGameCard(GameObject object, double cardSize) {
    return GestureDetector(
      onTap: () => _onObjectTapped(object),
      child: Container(
        width: cardSize,
        height: cardSize,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              const Color(0xFFF8F8F8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF5B6F4A).withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              object.icon,
              size: cardSize * 0.35, // Dynamic icon size based on card size
              color: const Color(0xFF5B6F4A),
            ),
            SizedBox(height: cardSize * 0.08),
            Text(
              object.name,
              style: TextStyle(
                color: const Color(0xFF5B6F4A),
                fontSize: cardSize * 0.12, // Dynamic font size
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: ElevatedButton(
        onPressed: _startGame,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5B6F4A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_arrow,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              'Start Game',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
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
