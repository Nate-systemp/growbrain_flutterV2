import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import '../utils/background_music_manager.dart';
import '../utils/sound_effects_manager.dart';
import '../utils/difficulty_utils.dart';

class FruitShuffleGame extends StatefulWidget {
  final String difficulty;
  final void Function({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })?
  onGameComplete;
  final String challengeFocus;
  final String gameName;

  const FruitShuffleGame({
    Key? key,
    required this.difficulty,
    this.onGameComplete,
    required this.challengeFocus,
    required this.gameName,
  }) : super(key: key);

  @override
  State<FruitShuffleGame> createState() => _FruitShuffleGameState();
}

class _FruitShuffleGameState extends State<FruitShuffleGame> with TickerProviderStateMixin {
  late List<Fruit> fruits;
  late List<Bag> bags;
  late List<Fruit> availableFruits;
  late List<Fruit> shuffledCorrectMatches;
  late Stopwatch stopwatch;
  bool gameStarted = false;
  bool shuffling = false;
  bool matchingPhase = false;
  bool gameCompleted = false;
  int wrongAttempts = 0;
  int hintsUsed = 0;
  int maxWrongAttempts = 5;
  int totalAttempts = 0;
  int correctMatchesCount = 0;
  int totalFruits = 4;
  late String difficulty;
  late String _normalizedDifficulty;

  // Shuffling animation variables
  List<Fruit?> visibleFruitsInBags = [];
  int shuffleAnimationStep = 0;
  Timer? shuffleTimer;

  // Animation controllers
  late AnimationController _shakeController;
  late AnimationController _revealController;
  late AnimationController _fruitFlyController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _revealAnimation;
  late Animation<Offset> _fruitFlyAnimation;

  // Animation state
  bool _isAnimating = false;
  Fruit? _animatingFruit;
  Offset? _startPosition;
  Offset? _endPosition;

  // Fruit types
  final List<Map<String, dynamic>> fruitTypes = [
    {'name': 'Apple', 'emoji': '🍎'},
    {'name': 'Banana', 'emoji': '🍌'},
    {'name': 'Orange', 'emoji': '🍊'},
    {'name': 'Grapes', 'emoji': '🍇'},
    {'name': 'Strawberry', 'emoji': '🍓'},
    {'name': 'Cherry', 'emoji': '🍒'},
    {'name': 'Pineapple', 'emoji': '🍍'},
    {'name': 'Watermelon', 'emoji': '🍉'},
  ];

  @override
  void initState() {
    super.initState();
    // Start background music for this game
    BackgroundMusicManager().startGameMusic('Fruit Shuffle');
    difficulty = widget.difficulty;
    _normalizedDifficulty = DifficultyUtils.normalizeDifficulty(widget.difficulty);
    stopwatch = Stopwatch();
    _setupDifficulty();
    _initializeGame();

    // Initialize animation controllers
    _shakeController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _revealController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _fruitFlyController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _revealAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _revealController, curve: Curves.easeInOut),
    );

    _fruitFlyAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fruitFlyController,
      curve: Curves.easeInOutCubic,
    ));
  }

  void _setupDifficulty() {
    final normalizedDifficulty = DifficultyUtils.normalizeDifficulty(difficulty);
    if (normalizedDifficulty == 'Starter') {
      totalFruits = 3;
      maxWrongAttempts = 5;
    } else if (normalizedDifficulty == 'Growing') {
      totalFruits = 4;
      maxWrongAttempts = 4;
    } else {
      totalFruits = 5;
      maxWrongAttempts = 3;
    }
  }

  void _initializeGame() {
    // Create fruits based on difficulty
    fruits = fruitTypes
        .take(totalFruits)
        .map(
          (type) => Fruit(
            name: type['name'],
            emoji: type['emoji'],
          ),
        )
        .toList();

    // Create bags
    bags = List.generate(
      totalFruits,
      (index) => Bag(number: index + 1, correctFruit: fruits[index]),
    );

    // Shuffle the correct matches
    shuffledCorrectMatches = List.from(fruits);
    shuffledCorrectMatches.shuffle(Random());

    // Update bags with shuffled correct fruits
    for (int i = 0; i < bags.length; i++) {
      bags[i].correctFruit = shuffledCorrectMatches[i];
    }

    // Available fruits for selection (bottom row)
    availableFruits = List.from(fruits);

    // Initialize visible fruits in bags (initially empty)
    visibleFruitsInBags = List.filled(totalFruits, null);

    setState(() {
      gameStarted = false;
      shuffling = false;
      matchingPhase = false;
      gameCompleted = false;
      wrongAttempts = 0;
      hintsUsed = 0;
      totalAttempts = 0;
      correctMatchesCount = 0;
      shuffleAnimationStep = 0;
    });
  }

  void _startShuffle() {
    setState(() {
      shuffling = true;
      gameStarted = true;
      shuffleAnimationStep = 0;
    });

    // Start shuffling animation
    _runShuffleAnimation();
  }

  void _runShuffleAnimation() {
    shuffleTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (shuffleAnimationStep >= 8) {
        // Show final positions briefly
        setState(() {
          shuffleAnimationStep++;
          // Show all final fruits in their correct positions
          for (int i = 0; i < totalFruits; i++) {
            visibleFruitsInBags[i] = bags[i].correctFruit;
          }
        });

        // Wait 2 seconds to show final positions, then hide and start game
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              shuffling = false;
              matchingPhase = true;
              // Hide all fruits from bags to start memory game
              visibleFruitsInBags = List.filled(totalFruits, null);
            });
            stopwatch.start();
          }
        });

        timer.cancel();
        return;
      }

      setState(() {
        shuffleAnimationStep++;
        // Show random fruits in bags during shuffle (more frequent)
        for (int i = 0; i < totalFruits; i++) {
          if (Random().nextDouble() > 0.3) {
            // 70% chance to show fruit
            visibleFruitsInBags[i] = fruits[Random().nextInt(fruits.length)];
          } else {
            visibleFruitsInBags[i] = null;
          }
        }
      });
    });
  }

  void _selectFruit(Fruit fruit) {
    if (!matchingPhase || gameCompleted || _isAnimating) return;

    // Find the first empty bag that is not revealed (not a hint)
    int emptyBagIndex = bags.indexWhere((bag) => bag.placedFruit == null && !bag.isRevealed);
    if (emptyBagIndex != -1) {
      _startFruitFlyAnimation(fruit, emptyBagIndex);
    }
  }

  void _startFruitFlyAnimation(Fruit fruit, int targetBagIndex) {
    setState(() {
      _isAnimating = true;
      _animatingFruit = fruit;
      availableFruits.remove(fruit);
    });

    // Calculate more accurate animation path
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate basket positions more accurately
    double basketWidth = 100;
    double totalBasketsWidth = totalFruits * basketWidth;
    double spacing = (screenWidth - totalBasketsWidth) / (totalFruits + 1);
    double basketCenterX = spacing + (targetBagIndex * (basketWidth + spacing)) + (basketWidth / 2);
    
    // Start position (bottom fruit plate area)
    double startX = screenWidth / 2;
    double startY = screenHeight * 0.75; // Bottom area
    
    // End position (target basket center)
    double endX = basketCenterX;
    double endY = screenHeight * 0.35; // Basket area
    
    // Calculate relative movement
    double deltaX = endX - startX;
    double deltaY = endY - startY;

    // Update animation tween with accurate positions
    _fruitFlyAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(deltaX, deltaY),
    ).animate(CurvedAnimation(
      parent: _fruitFlyController,
      curve: Curves.easeInOutCubic,
    ));

    // Start the animation
    _fruitFlyController.forward().then((_) {
      // Animation completed, place fruit in bag
      setState(() {
        bags[targetBagIndex].placedFruit = fruit;
        _isAnimating = false;
        _animatingFruit = null;
      });
      
      _fruitFlyController.reset();

      // Check if all non-revealed bags have fruits placed
      if (bags.every((bag) => bag.placedFruit != null || bag.isRevealed)) {
        _checkMatches();
      }
    });
  }

  void _removeFruitFromBag(Bag bag) {
    if (!matchingPhase || gameCompleted || bag.placedFruit == null) return;

    setState(() {
      // Add the fruit back to available fruits
      availableFruits.add(bag.placedFruit!);
      // Remove the fruit from the bag
      bag.placedFruit = null;
    });
  }

  void _checkMatches() {
    totalAttempts++;
    int correct = 0;

    for (int i = 0; i < bags.length; i++) {
      // Count as correct if:
      // 1. Placed fruit matches correct fruit, OR
      // 2. Bag is revealed (hint) - automatically correct
      if (bags[i].isRevealed || bags[i].placedFruit?.name == bags[i].correctFruit.name) {
        correct++;
      }
    }

    if (correct == totalFruits) {
      // All correct!
      // Play success sound with voice effect
      SoundEffectsManager().playSuccessWithVoice();
      _completeGame(true);
    } else {
      // Wrong matches
      setState(() {
        wrongAttempts++;
        correctMatchesCount = correct;
      });

      // Reset for next attempt
      _resetForNextAttempt();

      // Check if hint should be shown
      if (wrongAttempts >= maxWrongAttempts && hintsUsed < totalFruits) {
        _showHint();
      }
    }
  }

  void _resetForNextAttempt() {
    setState(() {
      // Return fruits to bottom
      availableFruits.clear();
      availableFruits.addAll(fruits);

      // Clear placed fruits
      for (var bag in bags) {
        bag.placedFruit = null;
      }

      // Keep fruits hidden on bags (memory challenge)
      visibleFruitsInBags = List.filled(totalFruits, null);
    });
  }

  void _showHint() {
    // Find a bag that hasn't been revealed yet
    List<int> unrevealedBags = [];
    for (int i = 0; i < bags.length; i++) {
      if (!bags[i].isRevealed) {
        unrevealedBags.add(i);
      }
    }

    if (unrevealedBags.isNotEmpty) {
      int randomIndex = unrevealedBags[Random().nextInt(unrevealedBags.length)];
      setState(() {
        bags[randomIndex].isRevealed = true;
        hintsUsed++;
        // Show the revealed fruit on the bag
        visibleFruitsInBags[randomIndex] = bags[randomIndex].correctFruit;
        // Reset wrong attempts counter after giving hint
        wrongAttempts = 0;
      });
    }
  }

  void _completeGame(bool success) {
    stopwatch.stop();
    gameCompleted = true;

    if (widget.onGameComplete != null) {
      final int accuracy = totalAttempts > 0
          ? ((correctMatchesCount / (totalAttempts * totalFruits)) * 100)
                .round()
          : 100;
      final int completionTime = stopwatch.elapsed.inSeconds;

      widget.onGameComplete!(
        accuracy: accuracy,
        completionTime: completionTime,
        challengeFocus: widget.challengeFocus,
        gameName: widget.gameName,
        difficulty: _normalizedDifficulty,
      );
    }
    
    // Show completion dialog
    _showGameOverDialog(success);
  }

  @override
  void dispose() {
    stopwatch.stop();
    shuffleTimer?.cancel();
    _shakeController.dispose();
    _revealController.dispose();
    _fruitFlyController.dispose();
    BackgroundMusicManager().stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF64744B), // Muted green background
      body: Stack(
        children: [
          // Main game content (lower layer)
          Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    // Decorative elements
                    Positioned(
                      top: 32,
                      left: 32,
                      child: Icon(
                        Icons.apple,
                        color: Colors.black.withValues(alpha: 0.08),
                        size: 48,
                      ),
                    ),
                    Positioned(
                      top: 80,
                      right: 60,
                      child: Icon(
                        Icons.eco,
                        color: Colors.black.withValues(alpha: 0.08),
                        size: 44,
                      ),
                    ),

                    // Back button
                    Positioned(
                      top: 32,
                      left: 24,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF393C48),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 12,
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            fontFamily: 'Nunito',
                          ),
                          shadowColor: Colors.black.withValues(alpha: 0.18),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, size: 28),
                        label: const Text('Back'),
                      ),
                    ),

                    // Help button
                    Positioned(
                      top: 32,
                      right: 24,
                      child: Row(
                        children: [
                          const Text(
                            'Need Help?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.help, color: Colors.blue, size: 24),
                          ),
                        ],
                      ),
                    ),

                    // Main game content
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                // Game status
                if (!gameStarted)
                  Column(
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
                                    '1/${totalAttempts + 1}',
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
                                    '$correctMatchesCount',
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
                          Icons.shuffle,
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
                          'Watch carefully!',
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
                          'Watch fruits shuffle, then remember their positions!',
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
                        onPressed: _startShuffle,
                        child: const Text(
                          'Start !',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                if (shuffling)
                  Column(
                    children: [
                      const SizedBox(height: 20),
                      // Bags row during shuffle - Fixed positioning
                      Container(
                        width: double.infinity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: bags.map((bag) => _buildBag(bag)).toList(),
                        ),
                      ),
                    ],
                  ),

                if (matchingPhase && !gameCompleted)
                  Column(
                    children: [
                      // Bags row - Fixed positioning
                      Container(
                        width: double.infinity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: bags.map((bag) => _buildBag(bag)).toList(),
                        ),
                      ),
                      const SizedBox(height: 200),

                      // Available fruits row (excluding revealed fruits)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: availableFruits
                            .where((fruit) {
                              // Don't show fruits that are revealed as hints
                              return !bags.any((bag) => 
                                bag.isRevealed && bag.correctFruit.name == fruit.name);
                            })
                            .map((fruit) => _buildAnimatedFruit(fruit))
                            .toList(),
                      ),

                    ],
                  ),

                // Completion screen removed - now handled by dialog
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Flying fruit animation overlay (TOP LAYER - above everything)
          if (_isAnimating && _animatingFruit != null)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _fruitFlyAnimation,
                  builder: (context, child) {
                    double screenWidth = MediaQuery.of(context).size.width;
                    double screenHeight = MediaQuery.of(context).size.height;
                    
                    // Start at bottom center, move according to animation
                    double left = screenWidth / 2 - 55 + _fruitFlyAnimation.value.dx;
                    double top = screenHeight * 0.75 - 55 + _fruitFlyAnimation.value.dy;
                    
                    return Container(
                      child: Stack(
                        children: [
                          Positioned(
                            left: left,
                            top: top,
                            child: Material(
                              elevation: 10, // High elevation to stay on top
                              shape: const CircleBorder(),
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFE0E0E0),
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                  gradient: const RadialGradient(
                                    colors: [
                                      Color(0xFFFAFAFA),
                                      Colors.white,
                                    ],
                                    stops: [0.0, 1.0],
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _animatingFruit!.emoji,
                                    style: const TextStyle(fontSize: 68),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBag(Bag bag) {
    final bagIndex = bag.number - 1;
    final visibleFruit = visibleFruitsInBags[bagIndex];

    return SizedBox(
      width: 100, // Fixed width to prevent movement
      child: Column(
        mainAxisSize: MainAxisSize.min, // Prevent expansion
        children: [
          // Empty space above basket (fruits will go inside basket now)
          const SizedBox(width: 100, height: 100),

          const SizedBox(height: 10),

          // Basket - Fixed container with no animations
          Container(
            width: 100,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFD2B48C), // Light tan/beige basket color
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(25),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
          child: Stack(
            children: [
              // Basket weave pattern
              Positioned.fill(
                child: CustomPaint(
                  painter: BasketWeavePainter(),
                ),
              ),
              // Handle
              Positioned(
                top: 8,
                left: 10,
                right: 10,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCD853F), // Medium brown handle
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Fruit inside basket (if placed or revealed)
              if (bag.placedFruit != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: GestureDetector(
                      onTap: () => _removeFruitFromBag(bag),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.8),
                              blurRadius: 4,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          bag.placedFruit!.emoji,
                          style: const TextStyle(fontSize: 50),
                        ),
                      ),
                    ),
                  ),
                )
              else if (bag.isRevealed)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green.shade100.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.green.shade300,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.8),
                            blurRadius: 4,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        bag.correctFruit.emoji,
                        style: const TextStyle(fontSize: 50),
                      ),
                    ),
                  ),
                )
              else if (shuffling && visibleFruit != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        visibleFruit.emoji,
                        style: const TextStyle(fontSize: 50),
                      ),
                    ),
                  ),
                )
              else if (shuffleAnimationStep == 9 && visibleFruit != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        visibleFruit.emoji,
                        style: const TextStyle(fontSize: 50),
                      ),
                    ),
                  ),
                )
              else
                // Number (only show when no fruit is in basket)
                Center(
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFCD853F),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${bag.number}',
                        style: const TextStyle(
                          color: Color(0xFFCD853F),
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildAnimatedFruit(Fruit fruit) {
    return GestureDetector(
      onTap: () => _selectFruit(fruit),
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          // Plate background
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFE0E0E0),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          gradient: const RadialGradient(
            colors: [
              Color(0xFFFAFAFA), // Light center
              Colors.white,      // White edge
            ],
            stops: [0.0, 1.0],
          ),
        ),
        child: Center(
          child: Text(
            fruit.emoji,
            style: const TextStyle(fontSize: 68),
          ),
        ),
      ),
    );
  }

  Widget _buildFruit(Fruit fruit) {
    return GestureDetector(
      onTap: () => _selectFruit(fruit),
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          // Plate background
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFE0E0E0),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          gradient: const RadialGradient(
            colors: [
              Color(0xFFFAFAFA), // Light center
              Colors.white,      // White edge
            ],
            stops: [0.0, 1.0],
          ),
        ),
        child: Center(
          child: Text(
            fruit.emoji,
            style: const TextStyle(fontSize: 68),
          ),
        ),
      ),
    );
  }

  void _resetGame() {
    setState(() {
      gameStarted = false;
      shuffling = false;
      matchingPhase = false;
      gameCompleted = false;
      wrongAttempts = 0;
      hintsUsed = 0;
      totalAttempts = 0;
      correctMatchesCount = 0;
      shuffleAnimationStep = 0;
      _isAnimating = false;
      _animatingFruit = null;
    });
    
    stopwatch.reset();
    shuffleTimer?.cancel();
    
    // Reset bags
    for (var bag in bags) {
      bag.placedFruit = null;
      bag.isRevealed = false;
    }
    
    _initializeGame();
  }

  void _showGameOverDialog(bool success) {
    final accuracy = totalAttempts > 0
        ? ((correctMatchesCount / (totalAttempts * totalFruits)) * 100).round()
        : 100;
    final completionTime = stopwatch.elapsed.inSeconds;
    
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
                  color: const Color(0xFF64744B),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF64744B).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.celebration,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Fruit Master! 🍎✨',
                style: TextStyle(
                  color: const Color(0xFF64744B),
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
                _buildStatRow(Icons.star_rounded, 'Final Score', '${correctMatchesCount * 10} points'),
                const SizedBox(height: 12),
                _buildStatRow(Icons.apple, 'Fruits Matched', '$correctMatchesCount/$totalFruits'),
                const SizedBox(height: 12),
                _buildStatRow(Icons.track_changes, 'Accuracy', '$accuracy%'),
                const SizedBox(height: 12),
                _buildStatRow(Icons.timer, 'Time Used', '${completionTime}s'),
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
                          backgroundColor: const Color(0xFF64744B),
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
                    backgroundColor: const Color(0xFF64744B),
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
            color: Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF64744B), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: const Color(0xFF64744B),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: const Color(0xFF64744B),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class Fruit {
  final String name;
  final String emoji;

  Fruit({required this.name, required this.emoji});
}

class Bag {
  final int number;
  Fruit correctFruit;
  Fruit? placedFruit;
  bool isRevealed = false;

  Bag({required this.number, required this.correctFruit});
}

class BasketWeavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCD853F)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Draw horizontal weave lines
    for (double y = 20; y < size.height - 10; y += 8) {
      canvas.drawLine(
        Offset(8, y),
        Offset(size.width - 8, y),
        paint,
      );
    }

    // Draw vertical weave lines
    for (double x = 15; x < size.width - 8; x += 12) {
      canvas.drawLine(
        Offset(x, 20),
        Offset(x, size.height - 10),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
