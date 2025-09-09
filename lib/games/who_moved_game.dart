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
  int score = 0;
  int timer = 0;
  int roundsPlayed = 0;
  int correctAnswers = 0;
  late DateTime gameStartTime;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool gameStarted = false;
  bool showingAnimation = false;
  bool canSelect = false;
  bool gameCompleted = false;
  final Color primaryColor = const Color(0xFF5B6F4A);
  final Color accentColor = const Color(0xFFFFD740);
  final Color backgroundColor = const Color(0xFFF5F5DC);
  final Color headerGradientEnd = const Color(0xFF6B7F5A);
  final Color surfaceColor = const Color(0xFFF5F5DC);

  ShapeType? previousMovedShapeType;
  static const int totalRounds = 3;

  int get numberOfShapes {
    switch (widget.difficulty) {
      case 'Easy':
        return 3;
      case 'Medium':
        return 5;
      case 'Hard':
        return 8;
      default:
        return 3;
    }
  }

  int get timerDuration {
    int baseDuration;
    switch (widget.difficulty) {
      case 'Easy':
        baseDuration = 30;
        break;
      case 'Medium':
        baseDuration = 25;
        break;
      case 'Hard':
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
    switch (widget.difficulty) {
      case 'Easy':
        baseDurationSeconds = 1.0;
        break;
      case 'Medium':
        baseDurationSeconds = 0.8;
        break;
      case 'Hard':
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
    _shakeController = AnimationController(
      duration: shakeDuration,
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    _initializeGame();
  }

  @override
  void dispose() {
    _shakeController.dispose();
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
      showingAnimation = true;
      canSelect = false;
      timer = 0;
    });

    Future.delayed(const Duration(seconds: 2), () async {
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

  void _selectShape(int index) {
    if (!canSelect) return;

    setState(() {
      selectedShapeIndex = index;
      canSelect = false;
    });
      
      SoundEffectsManager().playSuccessWithVoice();
    
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: primaryColor,
        title: Text(
          correct ? 'Correct!' : 'Wrong!',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          correct
              ? 'Well done! You spotted the moving shape.'
              : 'The moving shape was a different one.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: accentColor),
            onPressed: () {
              Navigator.of(context).pop();
              _nextRound();
            },
            child: const Text('Next'),
          ),
        ],
      ),
    );
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
    setState(() {
      gameStarted = false;
      timer = 0;
    });
    _initializeGame();
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
        difficulty: widget.difficulty,
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Complete!'),
        content: Text(
          'You completed all $totalRounds rounds!\nCorrect answers: $correctAnswers/$totalRounds\nFinal score: $score',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Back to Menu'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
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
    });
    gameStartTime = DateTime.now();
    _shakeController.reset();
    _initializeGame();
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
                    child: Container(
                      width: canSelect ? shapeSize + 16 : shapeSize,
                      height: canSelect ? shapeSize + 16 : shapeSize,
                      decoration: BoxDecoration(
                        color: canSelect
                            ? Colors.white.withOpacity(0.8)
                            : Colors.transparent,
                        border: isSelected
                            ? Border.all(color: Colors.red, width: 3)
                            : canSelect
                            ? Border.all(
                                color: Colors.grey.withOpacity(0.3),
                                width: 1,
                              )
                            : null,
                        borderRadius: canSelect
                            ? BorderRadius.circular(12)
                            : null,
                        boxShadow: canSelect
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: CustomShapeWidget(
                          shape: shapes[index],
                          size: canSelect ? shapeSize - 8 : shapeSize,
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
    _showTeacherPinDialog(context);
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
        backgroundColor: const Color(0xFFF5F5DC),
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
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
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
                                const Text(
                                  'Round-based Challenge!',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF5B6F4A),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Complete 3 rounds. Each round gets faster!\nOne shape will shake. Can you spot which one?',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
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
                          Text(
                            showingAnimation
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
                          const SizedBox(height: 20),
                          Expanded(child: Center(child: _buildShapeGrid())),
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

  const CustomShapeWidget({super.key, required this.shape, required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: ShapePainter(shape.type, shape.color),
    );
  }
}
class ShapePainter extends CustomPainter {
  final ShapeType shapeType;
  final Color color;

  ShapePainter(this.shapeType, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Solid fill
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // White border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;

    // Soft shadow
    canvas.drawShadow(
      _getShapePath(shapeType, center, radius),
      Colors.black.withOpacity(0.13),
      10,
      false,
    );

    // Draw shape
    final shapePath = _getShapePath(shapeType, center, radius);
    canvas.drawPath(shapePath, paint);
    canvas.drawPath(shapePath, borderPaint);
  }

  Path _getShapePath(ShapeType type, Offset center, double radius) {
    switch (type) {
      case ShapeType.circle:
        return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
      case ShapeType.square:
        return Path()..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: radius * 1.6, height: radius * 1.6),
          Radius.circular(radius * 0.35),
        ));
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
        return Path()..addOval(Rect.fromCenter(center: center, width: radius * 2, height: radius * 1.2));
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}