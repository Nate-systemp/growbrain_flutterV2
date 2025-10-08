import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/background_music_manager.dart';
import '../utils/sound_effects_manager.dart';
import '../utils/difficulty_utils.dart';
import '../utils/help_tts_manager.dart';

class FruitShuffleGame extends StatefulWidget {
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

  List<Fruit?> visibleFruitsInBags = [];
  int shuffleAnimationStep = 0;
  Timer? shuffleTimer;

  late AnimationController _shakeController;
  late AnimationController _revealController;
  late AnimationController _fruitFlyController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _revealAnimation;
  late Animation<Offset> _fruitFlyAnimation;

  bool _isAnimating = false;
  Fruit? _animatingFruit;

  final List<Map<String, dynamic>> fruitTypes = const [
    {'name': 'Apple', 'emoji': '🍎'},
    {'name': 'Banana', 'emoji': '🍌'},
    {'name': 'Orange', 'emoji': '🍊'},
    {'name': 'Grapes', 'emoji': '🍇'},
    {'name': 'Strawberry', 'emoji': '🍓'},
    {'name': 'Cherry', 'emoji': '🍒'},
    {'name': 'Pineapple', 'emoji': '🍍'},
    {'name': 'Watermelon', 'emoji': '🍉'},
  ];

  bool showingCountdown = false;
  int countdownNumber = 3;

  bool showingGo = false;
  late final AnimationController _goController;
  late final Animation<double> _goOpacity;
  late final Animation<double> _goScale;

  bool showingStatus = false;
  String overlayText = '';
  Color overlayColor = Colors.green;
  Color overlayTextColor = Colors.white;

  int timerSeconds = 0;
  bool timerActive = false;

  bool showSimpleInstruction = false;

  final Color primaryColor = const Color(0xFF7A5833);
  final Color accentColor = const Color(0xFFF5C16C);

  @override
  void initState() {
    super.initState();
    BackgroundMusicManager().startGameMusic('Fruit Shuffle');
    difficulty = widget.difficulty;
    _normalizedDifficulty = DifficultyUtils.normalizeDifficulty(widget.difficulty);
    stopwatch = Stopwatch();
    _setupDifficulty();
    _initializeGame();

    _shakeController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _revealController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _fruitFlyController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);

    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn));
    _revealAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _revealController, curve: Curves.easeInOut));
    _fruitFlyAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(CurvedAnimation(parent: _fruitFlyController, curve: Curves.easeInOutCubic));

    _goController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _goOpacity = CurvedAnimation(parent: _goController, curve: Curves.easeInOut);
    _goScale = Tween<double>(begin: 0.90, end: 1.0).animate(CurvedAnimation(parent: _goController, curve: Curves.easeOutBack));
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
    fruits = fruitTypes.take(totalFruits).map((type) => Fruit(name: type['name'], emoji: type['emoji'])).toList();
    bags = List.generate(totalFruits, (index) => Bag(number: index + 1, correctFruit: fruits[index]));
    shuffledCorrectMatches = List.from(fruits)..shuffle(Random());
    for (int i = 0; i < bags.length; i++) {
      bags[i].correctFruit = shuffledCorrectMatches[i];
    }
    availableFruits = List.from(fruits);
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
      timerSeconds = 0;
      timerActive = false;
    });
  }

  void _startGame() {
    setState(() {
      showingCountdown = true;
      countdownNumber = 3;
    });
    _showCountdown();
  }

  void _tickTimer() async {
    while (timerActive && mounted && stopwatch.isRunning) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) break;
      setState(() => timerSeconds = stopwatch.elapsed.inSeconds);
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

  Future<void> _showStatusOverlay({required String text, required Color color, Color textColor = Colors.white}) async {
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
    setState(() => showingStatus = false);
  }

  void _showCountdown() async {
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => countdownNumber = i);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    setState(() {
      showingCountdown = false;
      gameStarted = true;
    });
    await _showGoOverlay();
    _startShuffle();
  }

  void _startShuffle() {
    setState(() {
      shuffling = true;
      shuffleAnimationStep = 0;
    });
    _runShuffleAnimation();
  }

  void _runShuffleAnimation() {
    shuffleTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (shuffleAnimationStep >= 8) {
        setState(() {
          shuffleAnimationStep++;
          for (int i = 0; i < totalFruits; i++) {
            visibleFruitsInBags[i] = bags[i].correctFruit;
          }
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              shuffling = false;
              matchingPhase = true;
              visibleFruitsInBags = List.filled(totalFruits, null);
            });
            stopwatch.start();
            timerActive = true;
            _tickTimer();
          }
        });

        timer.cancel();
        return;
      }

      setState(() {
        shuffleAnimationStep++;
        for (int i = 0; i < totalFruits; i++) {
          if (Random().nextDouble() > 0.3) {
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

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final slotWidth = screenWidth / (totalFruits + 1);
    final basketCenterX = slotWidth * (targetBagIndex + 1);
    final startX = screenWidth / 2;
    final startY = screenHeight * 0.75;
    final endX = basketCenterX;
    final endY = screenHeight * 0.35;
    final deltaX = endX - startX;
    final deltaY = endY - startY;

    _fruitFlyAnimation = Tween<Offset>(begin: Offset.zero, end: Offset(deltaX, deltaY)).animate(CurvedAnimation(parent: _fruitFlyController, curve: Curves.easeInOutCubic));

    _fruitFlyController.forward().then((_) {
      setState(() {
        bags[targetBagIndex].placedFruit = fruit;
        _isAnimating = false;
        _animatingFruit = null;
      });
      _fruitFlyController.reset();
      if (bags.every((bag) => bag.placedFruit != null || bag.isRevealed)) {
        _checkMatches();
      }
    });
  }

  void _removeFruitFromBag(Bag bag) {
    if (!matchingPhase || gameCompleted || bag.placedFruit == null) return;
    setState(() {
      availableFruits.add(bag.placedFruit!);
      bag.placedFruit = null;
    });
  }

  void _checkMatches() {
    totalAttempts++;
    int correct = 0;
    for (int i = 0; i < bags.length; i++) {
      if (bags[i].isRevealed || bags[i].placedFruit?.name == bags[i].correctFruit.name) {
        correct++;
      }
    }

    if (correct == totalFruits) {
      SoundEffectsManager().playSuccessWithVoice();
      _showStatusOverlay(text: '✓', color: Colors.green, textColor: Colors.white).then((_) {
        _completeGame(true);
      });
    } else {
      setState(() {
        wrongAttempts++;
        correctMatchesCount = correct;
      });
      SoundEffectsManager().playWrong();
      _showStatusOverlay(text: 'X', color: Colors.red, textColor: Colors.white).then((_) {
        _resetForNextAttempt();
        if (wrongAttempts >= maxWrongAttempts && hintsUsed < totalFruits) {
          _showHint();
        }
      });
    }
  }

  void _resetForNextAttempt() {
    setState(() {
      availableFruits..clear()..addAll(fruits);
      for (var bag in bags) {
        bag.placedFruit = null;
      }
      visibleFruitsInBags = List.filled(totalFruits, null);
    });
  }

  void _showHint() {
    final unrevealed = <int>[];
    for (int i = 0; i < bags.length; i++) {
      if (!bags[i].isRevealed) unrevealed.add(i);
    }
    if (unrevealed.isNotEmpty) {
      final randomIndex = unrevealed[Random().nextInt(unrevealed.length)];
      setState(() {
        bags[randomIndex].isRevealed = true;
        hintsUsed++;
        visibleFruitsInBags[randomIndex] = bags[randomIndex].correctFruit;
        wrongAttempts = 0;
      });
    }
  }

  void _completeGame(bool success) {
    stopwatch.stop();
    gameCompleted = true;
    if (widget.onGameComplete != null) {
      final int accuracy = totalFruits > 0 ? ((correctMatchesCount / totalFruits) * 100).round() : 0;
      final int completionTime = stopwatch.elapsed.inSeconds;
      widget.onGameComplete!(
        accuracy: accuracy,
        completionTime: completionTime,
        challengeFocus: widget.challengeFocus,
        gameName: widget.gameName,
        difficulty: _normalizedDifficulty,
      );
    }
    _showGameOverDialog(success);
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
    stopwatch.stop();
    shuffleTimer?.cancel();
    _shakeController.dispose();
    _revealController.dispose();
    _fruitFlyController.dispose();
    _goController.dispose();
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
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(image: AssetImage('assets/memorybg.png'), fit: BoxFit.cover),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0x667A5833), Color(0x337A5833)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                ),
              ),
            ),
            Positioned.fill(
              child: showingCountdown ? _buildCountdownScreen() : (!gameStarted ? _buildStartScreenWithInstruction() : _buildGameContent()),
            ),
            if (gameStarted) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 550, left: 50),
                  child: _infoCircle(label: 'Time', value: '${timerSeconds}s', circleSize: 104, valueFontSize: 30, labelFontSize: 26),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 550, right: 60),
                  child: _infoCircle(label: 'Tries', value: '$totalAttempts', circleSize: 104, valueFontSize: 30, labelFontSize: 26),
                ),
              ),
              
            ],
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
                              const Text('Get Ready!', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accentColor,
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.30), offset: const Offset(0, 8), blurRadius: 0, spreadRadius: 8)],
                                ),
                                child: Center(child: Text('GO!', style: TextStyle(color: primaryColor, fontSize: 54, fontWeight: FontWeight.bold))),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.30), offset: const Offset(0, 8), blurRadius: 0, spreadRadius: 8)],
                            ),
                            child: Center(child: Text(overlayText, style: TextStyle(color: overlayTextColor, fontSize: 72, fontWeight: FontWeight.bold))),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_isAnimating && _animatingFruit != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _fruitFlyAnimation,
                    builder: (context, child) {
                      final screenWidth = MediaQuery.of(context).size.width;
                      final screenHeight = MediaQuery.of(context).size.height;
                      final left = screenWidth / 2 - 55 + _fruitFlyAnimation.value.dx;
                      final top = screenHeight * 0.75 - 55 + _fruitFlyAnimation.value.dy;
                      return Stack(
                        children: [
                          Positioned(
                            left: left,
                            top: top,
                            child: Material(
                              elevation: 10,
                              shape: const CircleBorder(),
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFE0E0E0), width: 3),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))],
                                  gradient: const RadialGradient(colors: [Color(0xFFFAFAFA), Colors.white], stops: [0.0, 1.0]),
                                ),
                                child: Center(child: Text(_animatingFruit!.emoji, style: const TextStyle(fontSize: 68))),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            // Need Help button - ONLY when in-game (not on start/instructions/countdown)
            if (gameStarted && !showingCountdown)
              Positioned(
                left: 24,
                bottom: 24,
                child: _buildHelpButton(),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildHelpButton() {
    return FloatingActionButton.extended(
      heroTag: 'helpBtn',
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      icon: const Icon(Icons.help_outline),
      label: const Text('Need Help?'),
      onPressed: () {
        bool showSimple = false;
        // Speak the initial help text
        HelpTtsManager().speak('Watch carefully as fruits shuffle in the baskets. Then, drag each fruit to its correct basket based on what you saw.');
        
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) {
              return WillPopScope(
                onWillPop: () async {
                  HelpTtsManager().stop();
                  return true;
                },
                child: Dialog(
                  backgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD740),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 24,
                          spreadRadius: 0,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: SizedBox(
                  width: 320,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.help_outline, color: primaryColor, size: 28),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Need Help?',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: primaryColor,
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
                            showSimple
                                ? 'Watch fruits shuffle inside the baskets. After shuffling, drag the correct fruit to each basket as fast as you can!'
                                : 'Watch carefully as fruits shuffle in the baskets. Then, drag each fruit to its correct basket based on what you saw.',
                            style: TextStyle(
                              fontSize: 16,
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (showSimple)
                          const SizedBox(height: 16),
                        if (showSimple)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'That\'s the simpler explanation!',
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.6),
                                      blurRadius: 0,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: TextButton(
                                  onPressed: () {
                                    if (!showSimple) {
                                      setState(() {
                                        showSimple = true;
                                        // Speak the simpler explanation
                                        HelpTtsManager().speak('Watch fruits shuffle inside the baskets. After shuffling, drag the correct fruit to each basket as fast as you can!');
                                      });
                                    } else {
                                      HelpTtsManager().stop();
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: primaryColor,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    showSimple ? 'Close' : 'More Help?',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildGameContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (shuffling) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.start, children: bags.map((bag) => _buildBag(bag)).toList()),
            ),
          ],
          if (matchingPhase && !gameCompleted) ...[
            SizedBox(
              width: double.infinity,
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.start, children: bags.map((bag) => _buildBag(bag)).toList()),
            ),
            const SizedBox(height: 240),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: availableFruits.where((fruit) => !bags.any((bag) => bag.isRevealed && bag.correctFruit.name == fruit.name)).map((fruit) => _buildAnimatedFruit(fruit)).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStartScreenWithInstruction() {
    final size = MediaQuery.of(context).size;
    final bool isTablet = size.shortestSide >= 600;
    final double panelMaxWidth = isTablet ? 560.0 : 420.0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: min(size.width * 0.9, panelMaxWidth)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), offset: const Offset(0, 12), blurRadius: 24, spreadRadius: 2)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Fruit Shuffle', style: TextStyle(color: primaryColor, fontSize: isTablet ? 42 : 34, fontWeight: FontWeight.w900, letterSpacing: 0.5), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Container(
                width: isTablet ? 100 : 84,
                height: isTablet ? 100 : 84,
                decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor, boxShadow: [BoxShadow(color: accentColor.withOpacity(0), blurRadius: 20, spreadRadius: 6)]),
                child: Icon(Icons.shopping_basket, size: isTablet ? 56 : 48, color: primaryColor),
              ),
              const SizedBox(height: 16),
              Text('Watch carefully!', style: TextStyle(color: primaryColor, fontSize: isTablet ? 22 : 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: showSimpleInstruction
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: Text(
                  'Watch fruits shuffle inside the baskets. After shuffling, drag the correct fruit to each basket as fast as you can!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: primaryColor.withOpacity(0.9), fontSize: isTablet ? 18 : 15, height: 1.35),
                ),
                secondChild: Text(
                  'Look at the fruits as they move in the baskets. Remember which fruit goes in which basket. Then tap the fruits to put them back!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: primaryColor.withOpacity(0.9), fontSize: isTablet ? 18 : 15, height: 1.35, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    showSimpleInstruction = !showSimpleInstruction;
                  });
                },
                icon: Icon(Icons.help_outline, color: primaryColor),
                label: Text(
                  showSimpleInstruction
                      ? 'Show Original Instruction'
                      : 'Need a simpler explanation?',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: isTablet ? 16 : 14,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: primaryColor,
                    padding: EdgeInsets.symmetric(vertical: isTablet ? 18 : 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                  ),
                  child: Text('START GAME', style: TextStyle(fontSize: isTablet ? 22 : 18, fontWeight: FontWeight.w900)),
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
          const Text('Get Ready!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 40),
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor, boxShadow: [BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)]),
            child: Center(child: Text('$countdownNumber', style: TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: primaryColor))),
          ),
          const SizedBox(height: 40),
          Text('The game will start soon...', style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _infoCircle({required String label, required String value, double circleSize = 88, double valueFontSize = 18, double labelFontSize = 12}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: Colors.white, fontSize: labelFontSize, fontWeight: FontWeight.w800, shadows: [Shadow(color: Colors.black.withOpacity(0.45), offset: const Offset(2, 2), blurRadius: 0)])),
        const SizedBox(height: 8),
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), offset: const Offset(0, 6), blurRadius: 0, spreadRadius: 4)]),
          alignment: Alignment.center,
          child: Text(value, style: TextStyle(color: primaryColor, fontSize: valueFontSize, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }

  void _showGameOverDialog(bool success) {
    final accuracy = totalFruits > 0 ? ((correctMatchesCount / totalFruits) * 100).round() : 0;
    final completionTime = stopwatch.elapsed.inSeconds;
    timerActive = false;

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
              decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.30), blurRadius: 14, offset: const Offset(0, 6))]),
              child: const Icon(Icons.shopping_basket, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 16),
            Text('Amazing! 🌟', style: TextStyle(color: primaryColor, fontSize: 26, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatRow(Icons.star_rounded, 'Matches', '$correctMatchesCount'),
              const SizedBox(height: 12),
              _buildStatRow(Icons.flash_on, 'Attempts', '$totalAttempts'),
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
                      label: const Text('Play Again', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 4),
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
                      label: Text('Exit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: primaryColor, width: 2), padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
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
                label: const Text('Next Game', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 4),
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
        Container(width: 32, height: 32, decoration: BoxDecoration(color: accentColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: primaryColor, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(color: primaryColor, fontSize: 14, fontWeight: FontWeight.w500))),
        Text(value, style: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildBag(Bag bag) {
    final bagIndex = bag.number - 1;
    final visibleFruit = visibleFruitsInBags[bagIndex];

    return SizedBox(
      width: 140,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 140, height: 140),
          const SizedBox(height: 10),
          Container(
            width: 140,
            height: 160,
            decoration: BoxDecoration(
              color: const Color(0xFFD2B48C),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8), bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(2, 2))],
            ),
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: BasketWeavePainter())),
                Positioned(top: 8, left: 10, right: 10, child: Container(height: 6, decoration: BoxDecoration(color: const Color(0xFFCD853F), borderRadius: BorderRadius.circular(3)))),
                if (bag.placedFruit != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: GestureDetector(
                        onTap: () => _removeFruitFromBag(bag),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)), BoxShadow(color: Colors.white.withOpacity(0.8), blurRadius: 4, offset: const Offset(0, -2))],
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Text(bag.placedFruit!.emoji, style: const TextStyle(fontSize: 64)),
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
                          color: Colors.green.shade100.withOpacity(0.9),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.green.shade300, width: 2),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)), BoxShadow(color: Colors.white.withOpacity(0.8), blurRadius: 4, offset: const Offset(0, -2))],
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Text(bag.correctFruit.emoji, style: const TextStyle(fontSize: 64)),
                      ),
                    ),
                  )
                else if (shuffling && visibleFruit != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3))]),
                        padding: const EdgeInsets.all(8),
                        child: Text(visibleFruit.emoji, style: const TextStyle(fontSize: 64)),
                      ),
                    ),
                  )
                else if (shuffleAnimationStep == 9 && visibleFruit != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]),
                        padding: const EdgeInsets.all(8),
                        child: Text(visibleFruit.emoji, style: const TextStyle(fontSize: 64)),
                      ),
                    ),
                  )
                else
                  Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFCD853F), width: 2)),
                      child: Center(child: Text('${bag.number}', style: const TextStyle(color: Color(0xFFCD853F), fontSize: 32, fontWeight: FontWeight.bold))),
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
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE0E0E0), width: 3),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))],
          gradient: const RadialGradient(colors: [Color(0xFFFAFAFA), Colors.white], stops: [0.0, 1.0]),
        ),
        child: Center(child: Text(fruit.emoji, style: const TextStyle(fontSize: 68))),
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
      showingCountdown = false;
      countdownNumber = 3;
      timerSeconds = 0;
      timerActive = false;
    });
    stopwatch.reset();
    shuffleTimer?.cancel();
    for (var bag in bags) {
      bag.placedFruit = null;
      bag.isRevealed = false;
    }
    _initializeGame();
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
    final paint = Paint()..color = const Color(0xFFCD853F)..strokeWidth = 1.2..style = PaintingStyle.stroke;
    for (double y = 20; y < size.height - 10; y += 8) {
      canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), paint);
    }
    for (double x = 15; x < size.width - 8; x += 12) {
      canvas.drawLine(Offset(x, 20), Offset(x, size.height - 10), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
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