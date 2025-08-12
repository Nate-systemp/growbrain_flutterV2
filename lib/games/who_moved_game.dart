import 'package:flutter/material.dart';
import 'dart:math' as math;

enum ShapeType { circle, square, triangle, diamond, pentagon, hexagon, star, oval }

class GameShape {
  ShapeType type;
  Color color;
  bool isMoved;

  GameShape({
    required this.type,
    required this.color,
    this.isMoved = false,
  });
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
  })? onGameComplete;

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
  late AnimationController _spinController;
  late Animation<double> _spinAnimation;
  bool gameStarted = false;
  bool showingAnimation = false;
  bool canSelect = false;
  bool gameCompleted = false;
  
  // Fixed 3 rounds per game
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

  // Get timer duration based on difficulty and round progression
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
    
    // Reduce timer by 5 seconds each round (but minimum 10 seconds)
    int reduction = (roundsPlayed) * 5;
    return math.max(10, baseDuration - reduction);
  }

  // Get spin duration based on difficulty and round progression
  Duration get spinDuration {
    double baseDurationSeconds;
    switch (widget.difficulty) {
      case 'Easy':
        baseDurationSeconds = 3.0;
        break;
      case 'Medium':
        baseDurationSeconds = 2.5;
        break;
      case 'Hard':
        baseDurationSeconds = 2.0;
        break;
      default:
        baseDurationSeconds = 3.0;
    }
    
    // Increase speed (reduce duration) each round by 0.3 seconds (minimum 1 second)
    double speedIncrease = (roundsPlayed) * 0.3;
    double finalDuration = math.max(1.0, baseDurationSeconds - speedIncrease);
    
    return Duration(milliseconds: (finalDuration * 1000).round());
  }

  @override
  void initState() {
    super.initState();
    gameStartTime = DateTime.now();
    _spinController = AnimationController(
      duration: spinDuration, // Will be updated per round
      vsync: this,
    );
    _spinAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _spinController,
      curve: Curves.easeInOut,
    ));

    _initializeGame();
    // Don't start timer automatically - wait for user to start round
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _initializeGame() {
    final colors = [
      const Color(0xFF5B6F4A), // Dark green
      const Color(0xFFFFD740), // Yellow
      const Color(0xFF8BC34A), // Light green
      const Color(0xFFFF9800), // Orange
      const Color(0xFF2196F3), // Blue
      const Color(0xFF9C27B0), // Purple
      const Color(0xFFE91E63), // Pink
      const Color(0xFF607D8B), // Blue grey
    ];

    final shapeTypes = ShapeType.values;
    shapes.clear();

    for (int i = 0; i < numberOfShapes; i++) {
      shapes.add(GameShape(
        type: shapeTypes[i % shapeTypes.length],
        color: colors[i % colors.length],
      ));
    }

    movedShapeIndex = math.Random().nextInt(numberOfShapes);
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
        // Time's up for this round
        _handleTimeUp();
      }
    });
  }

  void _handleTimeUp() {
    setState(() {
      canSelect = false;
    });
    
    // Show time's up dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Time\'s Up!'),
        content: const Text('You ran out of time for this round.'),
        actions: [
          TextButton(
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
    // Update animation controller duration for this round
    _spinController.dispose();
    _spinController = AnimationController(
      duration: spinDuration,
      vsync: this,
    );
    _spinAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _spinController,
      curve: Curves.easeInOut,
    ));

    setState(() {
      gameStarted = true;
      showingAnimation = true;
      canSelect = false;
      timer = 0; // Reset timer display
    });

    // Wait 2 seconds for memorization
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _spinController.forward().then((_) {
          setState(() {
            showingAnimation = false;
            canSelect = true;
          });
          // Start the round timer only after animation completes
          _startRoundTimer();
        });
      }
    });
  }

  void _selectShape(int index) {
    if (!canSelect) return;

    setState(() {
      selectedShapeIndex = index;
      canSelect = false; // Prevent multiple selections
    });

    if (index == movedShapeIndex) {
      score += 10;
      correctAnswers++;
      _showResult(true);
    } else {
      _showResult(false);
    }
  }

  void _showResult(bool correct) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(correct ? 'Correct!' : 'Wrong!'),
        content: Text(correct
            ? 'Well done! You spotted the moving shape.'
            : 'The spinning shape was a different one.'),
        actions: [
          TextButton(
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

    // Check if we've completed all 3 rounds
    if (roundsPlayed >= totalRounds) {
      _endGame();
      return;
    }

    // Reset for next round
    _spinController.reset();
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

    // Call the completion callback if provided
    if (widget.onGameComplete != null) {
      final completionTime = DateTime.now().difference(gameStartTime).inSeconds;
      final accuracy = roundsPlayed > 0 ? ((correctAnswers / roundsPlayed) * 100).round() : 0;
      
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
        content: Text('You completed all $totalRounds rounds!\nCorrect answers: $correctAnswers/$totalRounds\nFinal score: $score'),
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
              _resetGame();
            },
            child: const Text('Play Again'),
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
    _spinController.reset();
    _initializeGame();
  }

  Widget _buildShapeGrid() {
    // Calculate grid dimensions for compact layout
    int columns;
    double shapeSize;
    
    switch (numberOfShapes) {
      case 3:
        columns = 3;
        shapeSize = 80.0;
        break;
      case 5:
        columns = 3;
        shapeSize = 75.0; // Increased from 70.0
        break;
      case 8:
        columns = 4;
        shapeSize = 60.0; // Increased from 50.0
        break;
      default:
        columns = 3;
        shapeSize = 80.0;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use available space efficiently
        double availableWidth = constraints.maxWidth;
        
        // Calculate spacing to use available space
        double spacing = numberOfShapes == 8 ? 6.0 : 10.0; // Increased spacing slightly
        
        // Ensure shapes fit within available space
        double maxShapeSize = (availableWidth - (columns - 1) * spacing) / columns;
        shapeSize = math.min(shapeSize, maxShapeSize - 16); // Account for padding
        
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(numberOfShapes, (index) {
            bool isSelected = selectedShapeIndex == index;
            bool isMoved = index == movedShapeIndex && showingAnimation;
            
            return AnimatedBuilder(
              animation: _spinAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: isMoved ? _spinAnimation.value : 0,
                  child: GestureDetector(
                    onTap: () => _selectShape(index),
                    child: Container(
                      width: canSelect ? shapeSize + 16 : shapeSize, // Add padding only when clickable
                      height: canSelect ? shapeSize + 16 : shapeSize,
                      decoration: BoxDecoration(
                        color: canSelect 
                            ? Colors.white.withOpacity(0.8)
                            : Colors.transparent, // No background during animation
                        border: isSelected
                            ? Border.all(color: Colors.red, width: 3)
                            : canSelect 
                                ? Border.all(color: Colors.grey.withOpacity(0.3), width: 1)
                                : null, // No border during animation
                        borderRadius: canSelect ? BorderRadius.circular(12) : null,
                        boxShadow: canSelect ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ] : null,
                      ),
                      child: Center(
                        child: CustomShapeWidget(
                          shape: shapes[index],
                          size: canSelect ? shapeSize - 8 : shapeSize, // Original size during animation
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC), // Beige background
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B6F4A), // Dark green
        foregroundColor: Colors.white,
        title: Text(
          'Who Moved? - ${widget.difficulty}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Header with score, round, and timer
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B6F4A),
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
                        color: timer <= 5 && canSelect ? Colors.red : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Game area
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 10,
                        offset: const Offset(0, 5),
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
                                'Complete 3 rounds. Each round gets faster!\nOne shape will spin. Can you spot which one?',
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
                                    color: const Color(0xFF5B6F4A).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Round ${roundsPlayed + 1} - Speed: ${spinDuration.inMilliseconds}ms - Timer: ${timerDuration}s',
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
                        // Game status text
                        Text(
                          showingAnimation
                              ? 'Watch the spinning shape!'
                              : canSelect
                                  ? 'Which shape was spinning?'
                                  : 'Memorize the positions...',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5B6F4A),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        
                        // Shapes grid
                        Expanded(
                          child: Center(
                            child: _buildShapeGrid(),
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
    );
  }
}

class CustomShapeWidget extends StatelessWidget {
  final GameShape shape;
  final double size;

  const CustomShapeWidget({
    super.key,
    required this.shape,
    required this.size,
  });

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
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;

    switch (shapeType) {
      case ShapeType.circle:
        canvas.drawCircle(center, radius, paint);
        break;
      case ShapeType.square:
        final rect = Rect.fromCenter(
          center: center,
          width: radius * 1.6,
          height: radius * 1.6,
        );
        canvas.drawRect(rect, paint);
        break;
      case ShapeType.triangle:
        final path = Path();
        path.moveTo(center.dx, center.dy - radius);
        path.lineTo(center.dx - radius, center.dy + radius);
        path.lineTo(center.dx + radius, center.dy + radius);
        path.close();
        canvas.drawPath(path, paint);
        break;
      case ShapeType.diamond:
        final path = Path();
        path.moveTo(center.dx, center.dy - radius);
        path.lineTo(center.dx + radius, center.dy);
        path.lineTo(center.dx, center.dy + radius);
        path.lineTo(center.dx - radius, center.dy);
        path.close();
        canvas.drawPath(path, paint);
        break;
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
        canvas.drawPath(path, paint);
        break;
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
        canvas.drawPath(path, paint);
        break;
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
        canvas.drawPath(path, paint);
        break;
      case ShapeType.oval:
        final rect = Rect.fromCenter(
          center: center,
          width: radius * 2,
          height: radius * 1.2,
        );
        canvas.drawOval(rect, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
