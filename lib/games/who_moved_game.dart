import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';

class WhoMovedGame extends StatefulWidget {
  final String difficulty;
  final void Function({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })? onGameComplete;
  final String challengeFocus;
  final String gameName;

  const WhoMovedGame({
    Key? key,
    required this.difficulty,
    this.onGameComplete,
    required this.challengeFocus,
    required this.gameName,
  }) : super(key: key);

  @override
  State<WhoMovedGame> createState() => _WhoMovedGameState();
}

class _WhoMovedGameState extends State<WhoMovedGame>
    with TickerProviderStateMixin {
  late List<Character> characters;
  late Stopwatch stopwatch;
  bool gameStarted = false;
  bool showingInitialPositions = true;
  bool canSelect = false;
  bool gameCompleted = false;
  int round = 1;
  int totalRounds = 5;
  int correctAnswers = 0;
  int? movedCharacterIndex;
  int? selectedCharacterIndex;
  late String difficulty;
  late int numberOfCharacters;
  late Duration observationTime;
  late Duration movementDuration;

  // Animation controllers
  late AnimationController _moveAnimationController;
  late Animation<Offset> _moveAnimation;

  final List<Map<String, dynamic>> characterTypes = [
    {'name': 'Robot', 'icon': Icons.android, 'color': Color(0xFF81C784)}, // Soft green
    {'name': 'Star', 'icon': Icons.star, 'color': Color(0xFFFFD54F)}, // Soft yellow
    {'name': 'Heart', 'icon': Icons.favorite, 'color': Color(0xFFEF9A9A)}, // Soft red
    {'name': 'Diamond', 'icon': Icons.diamond, 'color': Color(0xFFCE93D8)}, // Soft purple
    {'name': 'Circle', 'icon': Icons.circle, 'color': Color(0xFFA5D6A7)}, // Soft light green
    {'name': 'Square', 'icon': Icons.crop_square, 'color': Color(0xFFFFCC80)}, // Soft orange
    {'name': 'Triangle', 'icon': Icons.change_history, 'color': Color(0xFFF8BBD9)}, // Soft pink
    {'name': 'Hexagon', 'icon': Icons.hexagon, 'color': Color(0xFF80CBC4)}, // Soft teal
    {'name': 'Flower', 'icon': Icons.local_florist, 'color': Color(0xFFE1BEE7)}, // Soft lavender
    {'name': 'Sun', 'icon': Icons.wb_sunny, 'color': Color(0xFFFFF176)}, // Soft light yellow
  ];

  @override
  void initState() {
    super.initState();
    difficulty = widget.difficulty;
    stopwatch = Stopwatch();
    _setupDifficulty();
    _initializeAnimations();
    _initializeGame();
  }

  @override
  void dispose() {
    _moveAnimationController.dispose();
    super.dispose();
  }

  void _setupDifficulty() {
    switch (difficulty) {
      case 'Easy':
        numberOfCharacters = 3;
        observationTime = const Duration(seconds: 3);
        movementDuration = const Duration(milliseconds: 800);
        break;
      case 'Medium':
        numberOfCharacters = 5;
        observationTime = const Duration(seconds: 2);
        movementDuration = const Duration(milliseconds: 600);
        break;
      case 'Hard':
        numberOfCharacters = 8;
        observationTime = const Duration(seconds: 1);
        movementDuration = const Duration(milliseconds: 400);
        break;
      default:
        numberOfCharacters = 3;
        observationTime = const Duration(seconds: 3);
        movementDuration = const Duration(milliseconds: 800);
    }
  }

  void _initializeAnimations() {
    _moveAnimationController = AnimationController(
      duration: movementDuration,
      vsync: this,
    );

    _moveAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, -0.5), // Move up slightly
    ).animate(CurvedAnimation(
      parent: _moveAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  void _initializeGame() {
    // Create characters
    characters = [];
    final shuffledTypes = List.from(characterTypes)..shuffle();
    
    for (int i = 0; i < numberOfCharacters; i++) {
      characters.add(Character(
        name: shuffledTypes[i]['name'],
        icon: shuffledTypes[i]['icon'],
        color: shuffledTypes[i]['color'],
        position: i,
        originalPosition: i,
      ));
    }

    movedCharacterIndex = null;
    selectedCharacterIndex = null;
    canSelect = false;
    _startRound();
  }

  void _startRound() {
    setState(() {
      showingInitialPositions = true;
      canSelect = false;
      selectedCharacterIndex = null;
    });

    // Show initial positions
    Timer(observationTime, () {
      if (mounted) {
        _performMovement();
      }
    });
  }

  void _performMovement() {
    if (!mounted) return;

    setState(() {
      showingInitialPositions = false;
    });

    // Choose a random character to move
    movedCharacterIndex = Random().nextInt(numberOfCharacters);

    // Start movement animation
    _moveAnimationController.forward().then((_) {
      _moveAnimationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            canSelect = true;
          });
        }
      });
    });
  }

  void _selectCharacter(int index) {
    if (!canSelect || gameCompleted) return;

    setState(() {
      selectedCharacterIndex = index;
    });

    // Check if correct
    bool isCorrect = index == movedCharacterIndex;
    if (isCorrect) {
      correctAnswers++;
    }

    // Show feedback briefly
    _showFeedback(isCorrect);

    Timer(const Duration(seconds: 1), () {
      if (mounted) {
        _nextRound();
      }
    });
  }

  void _showFeedback(bool correct) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: correct ? Colors.green[100] : Colors.red[100],
        title: Text(
          correct ? 'Correct!' : 'Try Again!',
          style: TextStyle(
            color: correct ? Colors.green[800] : Colors.red[800],
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          correct 
            ? 'Great observation!' 
            : 'The ${characters[movedCharacterIndex!].name} moved!',
        ),
      ),
    );

    Timer(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }

  void _nextRound() {
    if (round >= totalRounds) {
      _endGame();
    } else {
      setState(() {
        round++;
      });
      _initializeGame();
    }
  }

  void _endGame() {
    if (gameCompleted) return;
    
    setState(() {
      gameCompleted = true;
    });
    
    stopwatch.stop();
    final accuracy = ((correctAnswers / totalRounds) * 100).round();
    final completionTime = stopwatch.elapsed.inSeconds;

    if (widget.onGameComplete != null) {
      widget.onGameComplete!(
        accuracy: accuracy,
        completionTime: completionTime,
        challengeFocus: widget.challengeFocus,
        gameName: widget.gameName,
        difficulty: widget.difficulty,
      );
    }

    // Show final results
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Game Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Rounds: $round/$totalRounds'),
            Text('Correct: $correctAnswers'),
            Text('Accuracy: $accuracy%'),
            Text('Time: ${completionTime}s'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _startGame() {
    setState(() {
      gameStarted = true;
    });
    stopwatch.start();
    _startRound();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF3F4F6), // Soft gray background
      appBar: AppBar(
        title: const Text('Who Moved?'),
        backgroundColor: Color(0xFF90CAF9), // Soft blue
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Game info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoCard('Round', '$round/$totalRounds'),
                  _buildInfoCard('Correct', '$correctAnswers'),
                  _buildInfoCard('Difficulty', difficulty),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Instructions
            if (!gameStarted) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.visibility,
                      size: 48,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Watch carefully!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You will see $numberOfCharacters characters. One of them will move briefly. Can you spot which one moved?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _startGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF81C784), // Soft green
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      child: const Text(
                        'Start Game',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Game area
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 3,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showingInitialPositions) ...[
                          const Text(
                            'Memorize the positions...',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ] else if (!canSelect) ...[
                          const Text(
                            'Watch for movement!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ] else ...[
                          const Text(
                            'Which character moved?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        _buildCharacterGrid(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildCharacterGrid() {
    final crossAxisCount = numberOfCharacters <= 3 ? 3 : 
                          numberOfCharacters <= 6 ? 3 : 4;
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: numberOfCharacters,
      itemBuilder: (context, index) {
        final character = characters[index];
        final isSelected = selectedCharacterIndex == index;
        final isMoved = index == movedCharacterIndex;
        
        Widget characterWidget = GestureDetector(
          onTap: () => _selectCharacter(index),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected 
                ? Colors.blue[200] 
                : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected 
                  ? Colors.blue 
                  : Colors.grey[300]!,
                width: isSelected ? 3 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  character.icon,
                  size: 40,
                  color: character.color,
                ),
                const SizedBox(height: 8),
                Text(
                  character.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );

        // Apply animation to the moved character
        if (isMoved && !showingInitialPositions && !canSelect) {
          return AnimatedBuilder(
            animation: _moveAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: _moveAnimation.value * 50, // Scale the movement
                child: characterWidget,
              );
            },
          );
        }

        return characterWidget;
      },
    );
  }
}

class Character {
  final String name;
  final IconData icon;
  final Color color;
  final int position;
  final int originalPosition;

  Character({
    required this.name,
    required this.icon,
    required this.color,
    required this.position,
    required this.originalPosition,
  });
}
