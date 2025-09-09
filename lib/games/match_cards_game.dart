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
    stopwatch.start();
    timerActive = true;
    _tickTimer();
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

  void _onCardTap(int idx) async {
    if (waiting || cards[idx].isMatched || cards[idx].isFaceUp) return;
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
      backgroundColor: const Color(0xFF64744B), // Muted/olive green
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
                shadowColor: Colors.black.withOpacity(0.18),
              ),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, size: 28),
              label: const Text('Back'),
            ),
          ),
          // Main game content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (difficulty == 'Hard')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Timer: $timerSeconds s',
                      style: const TextStyle(
                        color: Colors.yellow,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const Text(
                  'Match all pairs!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: gridWidth.toDouble(),
                  child: GridView.builder(
                    shrinkWrap: true,
                    itemCount: cards.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridCols,
                      mainAxisSpacing: 24,
                      crossAxisSpacing: 24,
                    ),
                    itemBuilder: (context, idx) {
                      final card = cards[idx];
                      return GestureDetector(
                        onTap: () => _onCardTap(idx),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: card.isMatched
                                ? Colors.white
                                : (card.isFaceUp
                                      ? Colors.purple
                                      : Colors.purple[300]),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 4,
                                offset: const Offset(2, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: card.isFaceUp || card.isMatched
                                ? Icon(
                                    card.icon,
                                    color: Colors.orange,
                                    size: 54,
                                  )
                                : const Text(
                                    '?',
                                    style: TextStyle(
                                      fontSize: 48,
                                      color: Colors.orange,
                                    ),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
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
