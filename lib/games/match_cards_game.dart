import 'package:flutter/material.dart';
import 'dart:math';
import '../utils/background_music_manager.dart';
import '../utils/sound_effects_manager.dart';
import '../utils/difficulty_utils.dart';

class MatchCardsGame extends StatefulWidget {
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
  const MatchCardsGame({
    Key? key,
    required this.difficulty,
    this.onGameComplete,
    required this.challengeFocus,
    required this.gameName,
  }) : super(key: key);

  @override
  State<MatchCardsGame> createState() => _MatchCardsGameState();
}

class _MatchCardsGameState extends State<MatchCardsGame> {
  late List<_CardModel> cards;
  int? firstFlipped;
  int? secondFlipped;
  bool waiting = false;
  int gridRows = 2;
  int gridCols = 3;
  int timerSeconds = 0;
  bool timerActive = false;
  late final List<IconData> iconSet;
  late int numPairs;
  late String difficulty;
  String _normalizedDifficulty = 'easy';
  late Stopwatch stopwatch;
  int attempts = 0;
  int matches = 0;
  bool gameStarted = false;

  // App color scheme
  final Color primaryColor = const Color(0xFF5B6F4A);
  final Color accentColor = const Color(0xFFFFD740);
  final Color backgroundColor = const Color(0xFFF5F5DC);
  final Color surfaceColor = const Color(0xFFF5F5DC);

  @override
  void initState() {
    super.initState();
    // Start background music for this game
    BackgroundMusicManager().startGameMusic('Match Cards');
    difficulty = widget.difficulty;
    _normalizedDifficulty = DifficultyUtils.getDifficultyInternalValue(
      widget.difficulty,
    );
    stopwatch = Stopwatch();
    _setupDifficulty();
    _initGame();
    // Don't auto-start the game anymore
  }

  void _setupDifficulty() {
    // Use a set of fruit icons, repeat if needed
    final allIcons = [
      Icons.apple, // Apple
      Icons.emoji_food_beverage, // Lemon (as a stand-in)
      Icons.local_pizza, // Orange slice (as a stand-in)
      Icons.emoji_nature, // Grapes (as a stand-in)
      Icons.eco, // Leafy/fruit (as a stand-in)
      Icons.egg, // Egg (as a stand-in for fruit)
      Icons.emoji_emotions, // Berry (as a stand-in)
      Icons.brightness_1, // Circle (as a generic fruit)
      Icons.bubble_chart, // Bubbles (as a stand-in for grapes)
      Icons.spa, // Spa leaf (as a stand-in)
    ];
    if (difficulty == 'Easy') {
      numPairs = 3;
      gridRows = 2;
      gridCols = 3;
      iconSet = allIcons.sublist(0, 3);
    } else if (difficulty == 'Medium') {
      numPairs = 6;
      gridRows = 3;
      gridCols = 4;
      iconSet = allIcons.sublist(0, 6);
    } else {
      numPairs = 10;
      gridRows = 4;
      gridCols = 5;
      iconSet = allIcons.sublist(0, 10);
    }
  }

  void _initGame() {
    final all = <_CardModel>[];
    for (final icon in iconSet) {
      all.add(_CardModel(icon: icon));
      all.add(_CardModel(icon: icon));
    }
    all.shuffle(Random());
    setState(() {
      cards = all;
      firstFlipped = null;
      secondFlipped = null;
      waiting = false;
      timerSeconds = 0;
    });
  }

  void _tickTimer() async {
    while (timerActive && mounted && stopwatch.isRunning) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) break;
      setState(() {
        timerSeconds = stopwatch.elapsed.inSeconds;
      });
    }
  }

  void _startGame() {
    setState(() {
      gameStarted = true;
    });
    stopwatch.start();
    timerActive = true;
    _tickTimer();
  }

  void _onCardTap(int idx) async {
    if (!gameStarted || waiting || cards[idx].isMatched || cards[idx].isFaceUp)
      return;
    setState(() => cards[idx].isFaceUp = true);
    if (firstFlipped == null) {
      firstFlipped = idx;
    } else if (secondFlipped == null && idx != firstFlipped) {
      secondFlipped = idx;
      waiting = true;
      attempts++;
      await Future.delayed(const Duration(milliseconds: 700));
      if (cards[firstFlipped!].icon == cards[secondFlipped!].icon) {
        setState(() {
          cards[firstFlipped!].isMatched = true;
          cards[secondFlipped!].isMatched = true;
        });
        matches++;
        // Play success sound with voice effect
        SoundEffectsManager().playSuccessWithVoice();
        // Check if all matched
        if (cards.every((c) => c.isMatched)) {
          stopwatch.stop();
          timerActive = false;
          Future.delayed(const Duration(milliseconds: 500), () {
            if (widget.onGameComplete != null) {
              final int accuracy = attempts > 0
                  ? ((matches / attempts) * 100).round()
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
          });
        }
      } else {
        // Play wrong sound effect
        SoundEffectsManager().playWrong();
        setState(() {
          cards[firstFlipped!].isFaceUp = false;
          cards[secondFlipped!].isFaceUp = false;
        });
      }
      setState(() {
        firstFlipped = null;
        secondFlipped = null;
        waiting = false;
      });
    }
  }

  @override
  void dispose() {
    timerActive = false;
    stopwatch.stop();
    // Stop background music when leaving the game
    BackgroundMusicManager().stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final gridWidth = (gridCols * 100).toDouble().clamp(320, screenWidth * 0.8);
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Decorative icons
          Positioned(
            top: 32,
            left: 32,
            child: Icon(
              Icons.lightbulb,
              color: Colors.black.withOpacity(0.08),
              size: 48,
            ),
          ),
          Positioned(
            top: 80,
            right: 60,
            child: Icon(
              Icons.cloud,
              color: Colors.black.withOpacity(0.08),
              size: 44,
            ),
          ),
          Positioned(
            bottom: 60,
            left: 60,
            child: Icon(
              Icons.calculate,
              color: Colors.black.withOpacity(0.08),
              size: 44,
            ),
          ),
          Positioned(
            bottom: 40,
            right: 40,
            child: Transform.rotate(
              angle: -0.3,
              child: Icon(
                Icons.abc,
                color: Colors.black.withOpacity(0.08),
                size: 54,
              ),
            ),
          ),
          // App bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppBar(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              title: Text(
                'Match Cards - ${widget.difficulty}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              elevation: 0,
              centerTitle: true,
            ),
          ),
          // Main game content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header with timer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Matches: $matches/${numPairs}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (difficulty == 'Hard')
                          Text(
                            'Time: ${timerSeconds}s',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: !gameStarted
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.psychology,
                                  size: 80,
                                  color: primaryColor,
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Memory Match!',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Flip cards to find matching pairs.\nRemember where each card is!',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 30),
                                ElevatedButton(
                                  onPressed: _startGame,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
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
                                    'Start Game',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Center(
                            child: SizedBox(
                              width: gridWidth.toDouble(),
                              child: GridView.builder(
                                shrinkWrap: true,
                                itemCount: cards.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: gridCols,
                                      mainAxisSpacing: 16,
                                      crossAxisSpacing: 16,
                                    ),
                                itemBuilder: (context, idx) {
                                  final card = cards[idx];
                                  return GestureDetector(
                                    onTap: () => _onCardTap(idx),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        color: card.isMatched
                                            ? accentColor
                                            : (card.isFaceUp
                                                  ? Colors.white
                                                  : primaryColor),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.1,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: card.isFaceUp || card.isMatched
                                            ? Icon(
                                                card.icon,
                                                color: card.isMatched
                                                    ? primaryColor
                                                    : primaryColor,
                                                size: 40,
                                              )
                                            : const Text(
                                                '?',
                                                style: TextStyle(
                                                  fontSize: 32,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardModel {
  final IconData icon;
  bool isFaceUp = false;
  bool isMatched = false;
  _CardModel({required this.icon});
}
