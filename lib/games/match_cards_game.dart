import 'package:flutter/material.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  })? onGameComplete;
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

class _MatchCardsGameState extends State<MatchCardsGame>
    with TickerProviderStateMixin {
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
  String _normalizedDifficulty = 'Starter';
  late Stopwatch stopwatch;
  int attempts = 0;
  int matches = 0;
  bool gameStarted = false;

  // Countdown state
  bool showingCountdown = false;
  int countdownNumber = 3;

  // Overlays (GO and Status X/✓)
  bool showingGo = false;
  late final AnimationController _goController;
  late final Animation<double> _goOpacity;
  late final Animation<double> _goScale;

  bool showingStatus = false;
  String overlayText = '';
  Color overlayColor = Colors.green;
  Color overlayTextColor = Colors.white;

  // App color scheme - warm brown theme
  final Color primaryColor = const Color(0xFF7A5833);
  final Color accentColor = const Color(0xFFF5C16C);
  final Color backgroundColor = const Color(0xFFFAF3E8);
  final Color surfaceColor = const Color(0xFFEBD8C0);
  final Color successColor = const Color(0xFF81C784); // green flash for correct match

  @override
  void initState() {
    super.initState();
    // Start background music for this game
    BackgroundMusicManager().startGameMusic('Match Cards');
    difficulty = widget.difficulty;
    _normalizedDifficulty =
        DifficultyUtils.normalizeDifficulty(widget.difficulty);
    stopwatch = Stopwatch();
    _setupDifficulty();
    _initGame();

    // Init overlay animations
    _goController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _goOpacity = CurvedAnimation(parent: _goController, curve: Curves.easeInOut);
    _goScale = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(parent: _goController, curve: Curves.easeOutBack),
    );
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
    _normalizedDifficulty = DifficultyUtils.normalizeDifficulty(difficulty);
    if (_normalizedDifficulty == 'Starter') {
      numPairs = 3;
      gridRows = 2;
      gridCols = 3;
      iconSet = allIcons.sublist(0, 3);
    } else if (_normalizedDifficulty == 'Growing') {
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
      waiting = false;
      firstFlipped = null;
      secondFlipped = null;
      cards = all;
    });
  }

  void _resetGame() {
    setState(() {
      gameStarted = false;
      attempts = 0;
      matches = 0;
      timerSeconds = 0;
      timerActive = false;
      showingCountdown = false;
      countdownNumber = 3;
    });

    stopwatch.reset();
    _initGame();
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

  Future<void> _showGoOverlay() async {
    if (!mounted) return;
    setState(() => showingGo = true);
    await _goController.forward();
    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    await _goController.reverse();
    if (!mounted) return;
    setState(() => showingGo = false);
  }

  Future<void> _showStatusOverlay({
    required String text,
    required Color color,
    Color textColor = Colors.white,
  }) async {
    if (!mounted) return;
    setState(() {
      overlayText = text;
      overlayColor = color;
      overlayTextColor = textColor;
      showingStatus = true;
    });
    await _goController.forward();
    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    await _goController.reverse();
    if (!mounted) return;
    setState(() {
      showingStatus = false;
    });
  }

  void _showCountdown() async {
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() {
        countdownNumber = i;
      });
      await Future.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    setState(() {
      showingCountdown = false;
      gameStarted = true;
    });
    stopwatch.start();
    timerActive = true;
    _tickTimer();
    await _showGoOverlay();
  }

  void _startGame() {
    setState(() {
      showingCountdown = true;
      countdownNumber = 3;
    });
    _showCountdown();
  }

  void _onCardTap(int idx) async {
    if (!gameStarted || waiting || cards[idx].isMatched || cards[idx].isFaceUp) return;
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
          // trigger green flash
          cards[firstFlipped!].isFlashingSuccess = true;
          cards[secondFlipped!].isFlashingSuccess = true;
        });
        matches++;
        // Play success sound with voice effect
        SoundEffectsManager().playSuccessWithVoice();

        // Show green flash briefly
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        setState(() {
          cards[firstFlipped!].isFlashingSuccess = false;
          cards[secondFlipped!].isFlashingSuccess = false;
        });

        // Check if all matched after flash completes
        if (cards.every((c) => c.isMatched)) {
          stopwatch.stop();
          timerActive = false;
          Future.delayed(const Duration(milliseconds: 300), () {
            final int accuracy = attempts > 0 ? ((matches / attempts) * 100).round() : 0;
            final int completionTime = stopwatch.elapsed.inSeconds;

            if (widget.onGameComplete != null) {
              widget.onGameComplete!(
                accuracy: accuracy,
                completionTime: completionTime,
                challengeFocus: widget.challengeFocus,
                gameName: widget.gameName,
                difficulty: _normalizedDifficulty,
              );
            }

            _showGameOverDialog(accuracy, completionTime);
          });
        }
      } else {
        // Play wrong sound effect
        SoundEffectsManager().playWrong();
        setState(() {
          cards[firstFlipped!].isFaceUp = false;
          cards[secondFlipped!].isFaceUp = false;
        });
        await _showStatusOverlay(text: 'X', color: Colors.red, textColor: Colors.white);
      }
      setState(() {
        firstFlipped = null;
        secondFlipped = null;
        waiting = false;
      });
    }
  }

  void _showGameOverDialog(int accuracy, int completionTime) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        title: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.memory,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Amazing! 🌟',
              style: TextStyle(
                color: primaryColor,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatRow(Icons.star_rounded, 'Matches', '$matches'),
              const SizedBox(height: 12),
              _buildStatRow(Icons.flash_on, 'Attempts', '$attempts'),
              const SizedBox(height: 12),
              _buildStatRow(Icons.track_changes, 'Accuracy', '$accuracy%'),
              const SizedBox(height: 12),
              _buildStatRow(Icons.timer, 'Time', '${completionTime}s'),
            ],
          ),
        ),
        actions: [
          if (widget.onGameComplete == null) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _resetGame();
                      },
                      icon: const Icon(Icons.refresh, size: 22),
                      label: const Text(
                        'Play Again',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      },
                      icon: Icon(Icons.exit_to_app, size: 22, color: primaryColor),
                      label: Text(
                        'Exit',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: primaryColor, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 22),
                label: const Text(
                  'Next Game',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primaryColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: primaryColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getIconColor(IconData icon) {
    if (icon == Icons.apple) return const Color(0xFFE57373); // light red
    if (icon == Icons.emoji_food_beverage) return const Color(0xFFFFF176); // light yellow
    if (icon == Icons.local_pizza) return const Color(0xFFFFB74D); // light orange
    if (icon == Icons.emoji_nature) return const Color(0xFFCE93D8); // light purple
    if (icon == Icons.eco) return const Color(0xFFA5D6A7); // light green
    if (icon == Icons.egg) return const Color(0xFFFFE0B2); // eggshell
    if (icon == Icons.emoji_emotions) return const Color(0xFFF48FB1); // pink
    if (icon == Icons.brightness_1) return const Color(0xFF90CAF9); // light blue
    if (icon == Icons.bubble_chart) return const Color(0xFF80CBC4); // teal
    if (icon == Icons.spa) return const Color(0xFFC5E1A5); // light greenish
    return Colors.white;
  }

  Widget _infoCircle({
    required String label,
    required String value,
    double circleSize = 88,
    double valueFontSize = 18,
    double labelFontSize = 12,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: labelFontSize,
            fontWeight: FontWeight.w800,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.45),
                offset: const Offset(2, 2),
                blurRadius: 0,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                offset: const Offset(0, 6),
                blurRadius: 0,
                spreadRadius: 4,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: TextStyle(
              color: primaryColor,
              fontSize: valueFontSize,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStartScreenWithInstruction() {
    final size = MediaQuery.of(context).size;
    final bool isTablet = size.shortestSide >= 600;
    final double panelMaxWidth = isTablet ? 560.0 : 420.0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: min(size.width * 0.9, panelMaxWidth),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                offset: const Offset(0, 12),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Match Cards',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: isTablet ? 42 : 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                width: isTablet ? 100 : 84,
                height: isTablet ? 100 : 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0),
                      blurRadius: 20,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.memory,
                  size: isTablet ? 56 : 48,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Find the pairs!',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: isTablet ? 22 : 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Flip two cards. If they match, they stay open. Remember positions and match all pairs as fast as you can!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryColor.withOpacity(0.9),
                  fontSize: isTablet ? 18 : 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _startGame();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: primaryColor,
                    padding: EdgeInsets.symmetric(
                      vertical: isTablet ? 18 : 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                  child: Text(
                    'START GAME',
                    style: TextStyle(
                      fontSize: isTablet ? 22 : 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Get Ready!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 40),
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$countdownNumber',
                style: TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'The game will start soon...',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // PIN PROTECTION METHODS
  void _handleBackButton(BuildContext context) {
    // If this is a demo game (onGameComplete is null), allow direct navigation back
    if (widget.onGameComplete == null) {
      Navigator.of(context).pop();
    } else {
      // Only show PIN dialog for actual student sessions
      _showTeacherPinDialog(context);
    }
  }

  void _showTeacherPinDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _TeacherPinDialog(
          onPinVerified: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          },
          onCancel: () {
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  @override
  void dispose() {
    timerActive = false;
    stopwatch.stop();
    _goController.dispose();
    // Stop background music when leaving the game
    BackgroundMusicManager().stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final gridWidth = min(screenWidth * 0.9, screenHeight * 0.85);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackButton(context);
        }
      },
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/memorybg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            // Warm overlay to blend with 7A5833 palette
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0x667A5833), Color(0x337A5833)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Main content area (handles countdown, start screen, and game grid)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: showingCountdown
                    ? _buildCountdownScreen()
                    : (!gameStarted
                        ? _buildStartScreenWithInstruction()
                        : Center(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final availableHeight = constraints.maxHeight;
                                final cols = gridCols;
                                final rows = gridRows;
                                const double spacing = 16.0;
                                final double sidePad = spacing; // equal margins to spacing
                                final w = min(gridWidth.toDouble(), constraints.maxWidth);
                                final effectiveW = w - 2 * sidePad;
                                final tileW =
                                    (effectiveW - spacing * (cols - 1)) / cols;
                                final tileHFit = (availableHeight -
                                        spacing * (rows - 1)) /
                                    rows;
                                double aspect = tileW / tileHFit;
                                aspect = aspect.clamp(0.68, 1.30);
                                return SizedBox(
                                  width: w,
                                  child: GridView.builder(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: sidePad),
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    itemCount: cards.length,
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: cols,
                                      mainAxisSpacing: spacing,
                                      crossAxisSpacing: spacing,
                                      childAspectRatio: aspect,
                                    ),
                                    itemBuilder: (context, idx) {
                                      final card = cards[idx];
                                      return GestureDetector(
                                        onTap: () => _onCardTap(idx),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 250,
                                          ),
                                          decoration: BoxDecoration(
                                            color: card.isFlashingSuccess
                                                ? successColor
                                                : (card.isMatched
                                                    ? Colors.white
                                                    : (card.isFaceUp
                                                        ? backgroundColor
                                                        : primaryColor)),
                                            borderRadius:
                                                BorderRadius.circular(22),
                                            border: Border.all(
                                              color: (card.isFaceUp ||
                                                      card.isMatched)
                                                  ? Colors.transparent
                                                  : Colors.white
                                                      .withOpacity(0.18),
                                              width: 3,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.1),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: LayoutBuilder(
                                            builder: (context, constraints) {
                                              final s = constraints.maxWidth <
                                                      constraints.maxHeight
                                                  ? constraints.maxWidth
                                                  : constraints.maxHeight;
                                              final iconSize = s * 0.52;
                                              final qSize = s * 0.50;
                                              return Center(
                                                child: card.isFaceUp ||
                                                        card.isMatched
                                                    ? Icon(
                                                        card.icon,
                                                        color: _getIconColor(
                                                            card.icon),
                                                        size: iconSize,
                                                      )
                                                    : Text(
                                                        '?',
                                                        style: TextStyle(
                                                          fontSize: qSize,
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                      ),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          )),
              ),
            ),

            // Side HUD circles (Time and Paired), centered vertically
            if (gameStarted) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 104),
                  child: _infoCircle(
                    label: 'Time',
                    value: '${timerSeconds}s',
                    circleSize: 104,
                    valueFontSize: 30,
                    labelFontSize: 26,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 104),
                  child: _infoCircle(
                    label: 'Paired',
                    value: '$matches/$numPairs',
                    circleSize: 104,
                    valueFontSize: 30,
                    labelFontSize: 26,
                  ),
                ),
              ),
            ],

            // GO overlay
            if (showingGo)
              Positioned.fill(
                child: IgnorePointer(
                  child: FadeTransition(
                    opacity: _goOpacity,
                    child: Container(
                      color: Colors.black.withOpacity(0.12),
                      child: Center(
                        child: ScaleTransition(
                          scale: _goScale,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Get Ready!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accentColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.30),
                                      offset: const Offset(0, 8),
                                      blurRadius: 0,
                                      spreadRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    'GO!',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: 54,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Status overlay (X/✓)
            if (showingStatus)
              Positioned.fill(
                child: IgnorePointer(
                  child: FadeTransition(
                    opacity: _goOpacity,
                    child: Container(
                      color: Colors.black.withOpacity(0.12),
                      child: Center(
                        child: ScaleTransition(
                          scale: _goScale,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: overlayColor,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.30),
                                  offset: const Offset(0, 8),
                                  blurRadius: 0,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                overlayText,
                                style: TextStyle(
                                  color: overlayTextColor,
                                  fontSize: 72,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
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

class _CardModel {
  final IconData icon;
  bool isFaceUp = false;
  bool isMatched = false;
  bool isFlashingSuccess = false; // transient flash state when matched
  _CardModel({required this.icon});
}

// PIN DIALOG CLASS
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
      setState(() => _error = 'PIN must be 6 digits');
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
      final doc = await FirebaseFirestore.instance.collection('teachers').doc(user.uid).get();
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
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Color.fromARGB(255, 181, 187, 17),
              blurRadius: 0,
              spreadRadius: 0,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD740),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B6F4A).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.lock, color: const Color(0xFF5B6F4A), size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Teacher PIN Required',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF5B6F4A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Enter your 6-digit PIN to exit the session and access teacher features.',
                  style: TextStyle(fontSize: 16, color: const Color(0xFF5B6F4A), fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5B6F4A).withOpacity(0.2),
                      blurRadius: 0,
                      spreadRadius: 0,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold, color: Color(0xFF5B6F4A)),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    hintStyle: TextStyle(color: const Color(0xFF5B6F4A).withOpacity(0.4), letterSpacing: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: const Color(0xFF5B6F4A), width: 2)),
                    errorText: _error,
                    errorStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                  onSubmitted: (_) => _verifyPin(),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.6), blurRadius: 0, spreadRadius: 0, offset: Offset(0, 4))],
                      ),
                      child: TextButton(
                        onPressed: () {
                          if (widget.onCancel != null) {
                            widget.onCancel!();
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF5B6F4A),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: const Color(0xFF5B6F4A).withOpacity(0.6), blurRadius: 0, spreadRadius: 0, offset: Offset(0, 4))],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyPin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5B6F4A),
                          foregroundColor: const Color(0xFFFFD740),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD740))))
                            : const Text('Verify', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
