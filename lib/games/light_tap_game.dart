import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/background_music_manager.dart';
import '../utils/difficulty_utils.dart';

class LightTapGame extends StatefulWidget {
  final String difficulty;
  final Future<void> Function({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })? onGameComplete;

  const LightTapGame({Key? key, required this.difficulty, this.onGameComplete}) : super(key: key);

  @override
  _LightTapGameState createState() => _LightTapGameState();
}

class _LightTapGameState extends State<LightTapGame> with TickerProviderStateMixin {
  // Game state
  List<int> sequence = [];
  List<int> userSequence = [];
  int currentLevel = 1;
  int maxLevel = 10;
  bool isShowingSequence = false;
  bool isWaitingForInput = false;
  bool gameStarted = false;
  bool gameOver = false;
  int score = 0;
  int correctSequences = 0;
  int wrongTaps = 0;
  DateTime gameStartTime = DateTime.now();
  
  // Game configuration based on difficulty
  int gridSize = 4; // 2x2 grid by default
  int sequenceLength = 1;
  int maxSequenceLength = 8;
  int sequenceSpeed = 800; // milliseconds per light
  
  // UI state
  List<bool> lightStates = [];
  List<AnimationController> animationControllers = [];
  List<Animation<double>> scaleAnimations = [];
  
  // App color scheme
  final Color primaryColor = Color(0xFF5B6F4A);
  final Color accentColor = Color(0xFFFFD740);
  final Color backgroundColor = Color(0xFFF5F5F5);
  final Color surfaceColor = Colors.white;
  final Color errorColor = Color(0xFFE57373);
  final Color successColor = Color(0xFF81C784);
  
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
    // Configure game based on difficulty
    switch (widget.difficulty) {
      case 'Easy':
        gridSize = 4; // 2x2 grid
        maxSequenceLength = 5;
        sequenceSpeed = 1000;
        break;
      case 'Medium':
        gridSize = 6; // 2x3 grid
        maxSequenceLength = 7;
        sequenceSpeed = 800;
        break;
      case 'Hard':
        gridSize = 9; // 3x3 grid
        maxSequenceLength = 10;
        sequenceSpeed = 600;
        break;
    }
    
    // Initialize light states
    lightStates = List.generate(gridSize, (index) => false);
    
    // Initialize animations
    animationControllers = List.generate(gridSize, (index) => 
      AnimationController(
        duration: Duration(milliseconds: 200),
        vsync: this,
      )
    );
    
    scaleAnimations = animationControllers.map((controller) =>
      Tween<double>(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(parent: controller, curve: Curves.elasticOut)
      )
    ).toList();
  }
  
  void _startGame() {
    setState(() {
      gameStarted = true;
      gameOver = false;
      currentLevel = 1;
      score = 0;
      correctSequences = 0;
      wrongTaps = 0;
      gameStartTime = DateTime.now();
      sequence.clear();
      userSequence.clear();
    });
    
    _nextLevel();
  }
  
  void _nextLevel() {
    if (currentLevel > maxLevel) {
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
    sequence = List.generate(sequenceLength, (index) => random.nextInt(gridSize));
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
      animationControllers[lightIndex].forward();
      
      await Future.delayed(Duration(milliseconds: sequenceSpeed ~/ 2));
      
      // Light off
      setState(() {
        lightStates[lightIndex] = false;
      });
      animationControllers[lightIndex].reverse();
      
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
    
    // Animate the tapped light
    animationControllers[index].forward().then((_) {
      animationControllers[index].reverse();
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
            currentLevel++;
            isWaitingForInput = false;
          });
          
          // Show success feedback
          _showFeedback(true);
          
          // Move to next level after delay
          Future.delayed(Duration(milliseconds: 1500), () {
            if (mounted) {
              _nextLevel();
            }
          });
        }
      } else {
        // Wrong tap
        setState(() {
          wrongTaps++;
          isWaitingForInput = false;
        });
        
        _showFeedback(false);
        
        // End game or retry based on difficulty
        Future.delayed(Duration(milliseconds: 1500), () {
          if (mounted) {
            _endGame(false);
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
                style: TextStyle(
                  fontSize: 16,
                  color: primaryColor,
                ),
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
    final accuracy = wrongTaps == 0 ? 100 : ((correctSequences / (correctSequences + wrongTaps)) * 100).round();
    
    // Call completion callback
    if (widget.onGameComplete != null) {
      await widget.onGameComplete!(
        accuracy: accuracy,
        completionTime: completionTime,
        challengeFocus: 'Memory',
        gameName: 'Light Tap',
        difficulty: widget.difficulty,
      );
    }
    
    _showGameOverDialog(completed, accuracy, completionTime);
  }
  
  void _showGameOverDialog(bool completed, int accuracy, int completionTime) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text(
          completed ? 'Congratulations!' : 'Game Over',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (completed)
              Icon(Icons.celebration, color: accentColor, size: 64)
            else
              Icon(Icons.lightbulb_outline, color: primaryColor, size: 64),
            SizedBox(height: 16),
            Text(
              'Score: $score',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text('Accuracy: $accuracy%'),
            Text('Time: ${completionTime}s'),
            Text('Level Reached: $currentLevel'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text('Back to Menu', style: TextStyle(color: primaryColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startGame();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text('Play Again'),
          ),
        ],
      ),
    );
  }
  
  int _getGridColumns() {
    switch (gridSize) {
      case 4: return 2; // 2x2
      case 6: return 2; // 2x3
      case 9: return 3; // 3x3
      default: return 2;
    }
  }
  
  int _getGridRows() {
    switch (gridSize) {
      case 4: return 2; // 2x2
      case 6: return 3; // 2x3
      case 9: return 3; // 3x3
      default: return 2;
    }
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
                // Game info
                Container(
                  padding: EdgeInsets.all(16),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            'Level',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$currentLevel',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            'Score',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$score',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            'Sequence',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${userSequence.length}/${sequenceLength}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
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
                  child: gameStarted ? _buildGameGrid() : _buildStartScreen(),
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
  
  Widget _buildStartScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 100,
            color: accentColor,
          ),
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
                  style: TextStyle(
                    fontSize: 14,
                    color: primaryColor,
                  ),
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
                return AnimatedBuilder(
                  animation: scaleAnimations[index],
                  builder: (context, child) {
                    return Transform.scale(
                      scale: scaleAnimations[index].value,
                      child: GestureDetector(
                        onTap: () => _onLightTap(index),
                        child: Container(
                          decoration: BoxDecoration(
                            color: lightStates[index] 
                                ? lightColors[index % lightColors.length]
                                : inactiveLightColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: lightStates[index]
                                    ? lightColors[index % lightColors.length].withOpacity(0.5)
                                    : Colors.black.withOpacity(0.1),
                                blurRadius: lightStates[index] ? 8 : 4,
                                offset: Offset(0, lightStates[index] ? 4 : 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: buttonSize * 0.2,
                                fontWeight: FontWeight.bold,
                                color: lightStates[index] ? Colors.white : primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
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
