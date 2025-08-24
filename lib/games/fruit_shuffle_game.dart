import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import '../utils/background_music_manager.dart';

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

class _FruitShuffleGameState extends State<FruitShuffleGame> {
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

  // Shuffling animation variables
  List<Fruit?> visibleFruitsInBags = [];
  int shuffleAnimationStep = 0;
  Timer? shuffleTimer;

  // Fruit types
  final List<Map<String, dynamic>> fruitTypes = [
    {'name': 'Apple', 'icon': Icons.apple, 'color': Colors.red},
    {
      'name': 'Banana',
      'icon': Icons.emoji_food_beverage,
      'color': Colors.yellow,
    },
    {'name': 'Peach', 'icon': Icons.eco, 'color': Colors.orange},
    {'name': 'Pear', 'icon': Icons.spa, 'color': Colors.green},
    {'name': 'Strawberry', 'icon': Icons.emoji_nature, 'color': Colors.pink},
    {'name': 'Grape', 'icon': Icons.bubble_chart, 'color': Colors.purple},
    {'name': 'Lemon', 'icon': Icons.brightness_1, 'color': Colors.yellow},
    {'name': 'Cherry', 'icon': Icons.emoji_emotions, 'color': Colors.red},
  ];

  @override
  void initState() {
    super.initState();
    // Start background music for this game
    BackgroundMusicManager().startGameMusic('Fruit Shuffle');
    difficulty = widget.difficulty;
    stopwatch = Stopwatch();
    _setupDifficulty();
    _initializeGame();
  }

  void _setupDifficulty() {
    if (difficulty == 'Easy') {
      totalFruits = 3;
      maxWrongAttempts = 5;
    } else if (difficulty == 'Medium') {
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
            icon: type['icon'],
            color: type['color'],
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
    if (!matchingPhase || gameCompleted) return;

    setState(() {
      availableFruits.remove(fruit);
    });

    // Find the first empty bag
    int emptyBagIndex = bags.indexWhere((bag) => bag.placedFruit == null);
    if (emptyBagIndex != -1) {
      setState(() {
        bags[emptyBagIndex].placedFruit = fruit;
      });

      // Check if all fruits are placed
      if (bags.every((bag) => bag.placedFruit != null)) {
        _checkMatches();
      }
    }
  }

  void _checkMatches() {
    totalAttempts++;
    int correct = 0;

    for (int i = 0; i < bags.length; i++) {
      if (bags[i].placedFruit?.name == bags[i].correctFruit.name) {
        correct++;
      }
    }

    if (correct == totalFruits) {
      // All correct!
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
        difficulty: widget.difficulty,
      );
    }
    // Auto-navigate to next game after short delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    stopwatch.stop();
    shuffleTimer?.cancel();
    // Stop background music when leaving the game
    BackgroundMusicManager().stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF64744B), // Muted green background
      body: Stack(
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
                    children: [
                      const Text(
                        'Fruit Shuffle',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Watch fruits shuffle, then remember their positions!',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        onPressed: _startShuffle,
                        child: const Text(
                          'Start Shuffle',
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
                      // Bags row during shuffle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: bags.map((bag) => _buildBag(bag)).toList(),
                      ),
                    ],
                  ),

                if (matchingPhase && !gameCompleted)
                  Column(
                    children: [
                      // Game info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Text(
                            'Wrong: $wrongAttempts/$maxWrongAttempts',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Hints: $hintsUsed',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Bags row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: bags.map((bag) => _buildBag(bag)).toList(),
                      ),
                      const SizedBox(height: 40),

                      // Available fruits row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: availableFruits
                            .map((fruit) => _buildFruit(fruit))
                            .toList(),
                      ),

                      // Hint button
                      if (wrongAttempts >= maxWrongAttempts &&
                          hintsUsed < totalFruits)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _showHint,
                            child: const Text('Get Hint'),
                          ),
                        ),
                    ],
                  ),

                if (gameCompleted)
                  Column(
                    children: [
                      const Text(
                        'Game Completed!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Accuracy: ${totalAttempts > 0 ? ((correctMatchesCount / (totalAttempts * totalFruits)) * 100).round() : 100}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBag(Bag bag) {
    final bagIndex = bag.number - 1;
    final visibleFruit = visibleFruitsInBags[bagIndex];

    return Column(
      children: [
        // Placed fruit, revealed fruit, shuffling fruit, or final reveal
        if (bag.placedFruit != null)
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: bag.placedFruit!.color,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Icon(bag.placedFruit!.icon, color: Colors.white, size: 32),
          )
        else if (bag.isRevealed)
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: bag.correctFruit.color,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Icon(bag.correctFruit.icon, color: Colors.white, size: 32),
          )
        else if (shuffling && visibleFruit != null)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: visibleFruit.color,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Icon(visibleFruit.icon, color: Colors.white, size: 32),
          )
        else if (shuffleAnimationStep == 9 && visibleFruit != null)
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: visibleFruit.color,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Icon(visibleFruit.icon, color: Colors.white, size: 32),
          )
        else
          const SizedBox(width: 60, height: 60),

        const SizedBox(height: 10),

        // Bag
        Container(
          width: 80,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFF8B4513), // Brown bag color
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(3, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${bag.number}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFruit(Fruit fruit) {
    return GestureDetector(
      onTap: () => _selectFruit(fruit),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: fruit.color,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Icon(fruit.icon, color: Colors.white, size: 32),
      ),
    );
  }
}

class Fruit {
  final String name;
  final IconData icon;
  final Color color;

  Fruit({required this.name, required this.icon, required this.color});
}

class Bag {
  final int number;
  Fruit correctFruit;
  Fruit? placedFruit;
  bool isRevealed = false;

  Bag({required this.number, required this.correctFruit});
}
