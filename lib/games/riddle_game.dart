import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/background_music_manager.dart';
import '../utils/sound_effects_manager.dart';
import '../utils/difficulty_utils.dart';
import '../utils/help_tts_manager.dart';

class RiddleGame extends StatefulWidget {
  final String difficulty;
  final Function({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })?
  onGameComplete;

  const RiddleGame({Key? key, required this.difficulty, this.onGameComplete})
    : super(key: key);

  @override
  _RiddleGameState createState() => _RiddleGameState();
}

class Riddle {
  final String question;
  final String correctAnswer;
  final List<String> options;
  final String? visualHint;
  final String? explanation;

  Riddle({
    required this.question,
    required this.correctAnswer,
    required this.options,
    this.visualHint,
    this.explanation,
  });
}

class _RiddleGameState extends State<RiddleGame> with TickerProviderStateMixin {
  List<Riddle> gameRiddles = [];
  int currentRiddleIndex = 0;
  int score = 0;
  int correctAnswers = 0;
  int wrongAnswers = 0;
  int totalRiddles = 0;
  bool gameStarted = false;
  bool gameActive = false;
  bool riddleAnswered = false;
  String? selectedAnswer;
  bool showHint = false;
  late DateTime gameStartTime;
  Timer? riddleTimer;
  int timeLeft = 0;
  int timePerRiddle = 0;

  // Countdown state
  bool showingCountdown = false;
  int countdownNumber = 3;

  // GO overlay
  bool showingGo = false;
  late final AnimationController _goController;
  late final Animation<double> _goOpacity;
  late final Animation<double> _goScale;

  // Status overlay (✓ or X)
  bool showingStatus = false;
  String overlayText = '';
  Color overlayColor = Colors.green;
  Color overlayTextColor = Colors.white;

  // Simple instruction toggle
  bool showSimpleInstruction = false;

  Random random = Random();
  
  // App color scheme
  final Color primaryColor = const Color(0xFF5D83B9); // Blue to match background
  final Color accentColor = const Color(0xFFFFD740);

  // Riddle sets organized by difficulty
  final Map<String, List<Riddle>> riddleSets = {
    'Starter': [
      Riddle(
        question: "I'm yellow, long, and monkeys love to eat me. What am I?",
        correctAnswer: "Banana",
        options: ["Banana", "Corn", "Lemon", "Cheese"],
        visualHint: "🍌",
        explanation: "Bananas are yellow, long, and monkeys' favorite food!",
      ),
      Riddle(
        question: "I have four legs and say 'woof woof'. What am I?",
        correctAnswer: "Dog",
        options: ["Cat", "Dog", "Table", "Horse"],
        visualHint: "🐶",
        explanation: "Dogs have four legs and bark 'woof woof'!",
      ),
      Riddle(
        question: "I'm round, red, and grow on trees. What am I?",
        correctAnswer: "Apple",
        options: ["Orange", "Ball", "Apple", "Tomato"],
        visualHint: "🍎",
        explanation: "Apples are round, often red, and grow on apple trees!",
      ),
      Riddle(
        question: "I have wheels and you can ride me. What am I?",
        correctAnswer: "Bicycle",
        options: ["Bicycle", "Car", "Train", "Plane"],
        visualHint: "🚲",
        explanation: "A bicycle has wheels and you can ride it!",
      ),
      Riddle(
        question: "I fly in the sky and have feathers. What am I?",
        correctAnswer: "Bird",
        options: ["Plane", "Bird", "Kite", "Cloud"],
        visualHint: "🐦",
        explanation: "Birds fly in the sky and are covered with feathers!",
      ),
      Riddle(
        question:
            "I'm cold, white, and fall from the sky in winter. What am I?",
        correctAnswer: "Snow",
        options: ["Rain", "Snow", "Hail", "Ice"],
        visualHint: "❄️",
        explanation: "Snow is cold, white, and falls from winter clouds!",
      ),
    ],
    'Growing': [
      Riddle(
        question:
            "I have keys but no locks. I have space but no room. You can enter but not go inside. What am I?",
        correctAnswer: "Keyboard",
        options: ["Piano", "Computer", "Keyboard", "House"],
        visualHint: "⌨️",
        explanation:
            "A keyboard has keys, spacebar, and enter key but no physical locks or rooms!",
      ),
      Riddle(
        question: "I'm tall when I'm young and short when I'm old. What am I?",
        correctAnswer: "Candle",
        options: ["Tree", "Person", "Candle", "Building"],
        visualHint: "🕯️",
        explanation: "A candle starts tall and gets shorter as it burns down!",
      ),
      Riddle(
        question: "I have hands but cannot clap. What am I?",
        correctAnswer: "Clock",
        options: ["Clock", "Robot", "Statue", "Glove"],
        visualHint: "⏰",
        explanation:
            "A clock has hands (hour and minute hands) but cannot clap!",
      ),
      Riddle(
        question: "I get wet while drying. What am I?",
        correctAnswer: "Towel",
        options: ["Sponge", "Towel", "Hair", "Clothes"],
        visualHint: "🏖️",
        explanation: "A towel gets wet when it dries other things!",
      ),
      Riddle(
        question:
            "I'm light as a feather, yet the strongest person can't hold me for long. What am I?",
        correctAnswer: "Breath",
        options: ["Air", "Breath", "Feather", "Paper"],
        visualHint: "💨",
        explanation:
            "Your breath is very light, but you can't hold it for very long!",
      ),
      Riddle(
        question: "I have a neck but no head. What am I?",
        correctAnswer: "Bottle",
        options: ["Shirt", "Bottle", "Guitar", "Giraffe"],
        visualHint: "🍶",
        explanation: "A bottle has a neck (the narrow part) but no head!",
      ),
    ],
    'Challenged': [
      Riddle(
        question:
            "The more you take away from me, the bigger I become. What am I?",
        correctAnswer: "Hole",
        options: ["Hole", "Debt", "Problem", "Shadow"],
        visualHint: "🕳️",
        explanation:
            "When you dig a hole, the more dirt you take away, the bigger the hole gets!",
      ),
      Riddle(
        question:
            "I'm not alive, but I grow. I don't have lungs, but I need air. I don't have a mouth, but water kills me. What am I?",
        correctAnswer: "Fire",
        options: ["Plant", "Fire", "Balloon", "Cloud"],
        visualHint: "🔥",
        explanation:
            "Fire grows larger, needs oxygen (air), but water extinguishes it!",
      ),
      Riddle(
        question: "What has many teeth but cannot bite?",
        correctAnswer: "Comb",
        options: ["Saw", "Comb", "Gear", "Zipper"],
        visualHint: "💇",
        explanation: "A comb has many teeth (the thin parts) but cannot bite!",
      ),
      Riddle(
        question:
            "I have cities, but no houses. I have mountains, but no trees. I have water, but no fish. What am I?",
        correctAnswer: "Map",
        options: ["Map", "Globe", "Picture", "Book"],
        visualHint: "🗺️",
        explanation:
            "A map shows cities, mountains, and water, but not the actual houses, trees, or fish!",
      ),
      Riddle(
        question:
            "What comes once in a minute, twice in a moment, but never in a thousand years?",
        correctAnswer: "Letter M",
        options: ["Time", "Letter M", "Sound", "Breath"],
        visualHint: "🔤",
        explanation:
            "The letter 'M' appears once in 'minute', twice in 'moment', but never in 'thousand years'!",
      ),
      Riddle(
        question: "I'm always in front of you but can't be seen. What am I?",
        correctAnswer: "Future",
        options: ["Air", "Future", "Shadow", "Wind"],
        visualHint: "🔮",
        explanation: "The future is always ahead of you but you cannot see it!",
      ),
    ],
  };

  // App color scheme
  final Color backgroundColor = const Color(0xFFF5F5DC);
  final Color questionColor = const Color(0xFFF5F5DC); // Light cream
  final Color optionColor = Colors.white; // White
  final Color selectedColor = const Color(0xFFFFD740); // Accent yellow
  final Color correctColor = const Color(0xFFC8E6C9); // Light green
  final Color wrongColor = const Color(0xFFFFCDD2); // Light red

  @override
  void initState() {
    super.initState();
    // Start background music for this game
    BackgroundMusicManager().startGameMusic('Riddle Game');
    
    // Initialize animations
    _goController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _goOpacity = CurvedAnimation(parent: _goController, curve: Curves.easeInOut);
    _goScale = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(parent: _goController, curve: Curves.easeOutBack),
    );
    
    _initializeGame();
  }

  void _initializeGame() {
    // Normalize difficulty key and set difficulty parameters
    final diffKey = DifficultyUtils.normalizeDifficulty(widget.difficulty);
    // Set difficulty parameters
    switch (diffKey) {
      case 'Starter':
        totalRiddles = 5;
        timePerRiddle = 0; // No timer for Starter
        break;
      case 'Growing':
        totalRiddles = 6;
        timePerRiddle = 45; // 45 seconds per riddle
        break;
      case 'Challenged':
        totalRiddles = 8;
        timePerRiddle = 30; // 30 seconds per riddle
        break;
      default:
        totalRiddles = 5;
        timePerRiddle = 0;
    }

    _setupRiddles(diffKey);
  }

  void _setupRiddles(String difficultyKey) {
    gameRiddles.clear();

    List<Riddle> availableRiddles = List.from(
      riddleSets[difficultyKey] ?? riddleSets['Starter']!,
    );
    availableRiddles.shuffle();

    // Take required number of riddles
    gameRiddles = availableRiddles.take(totalRiddles).toList();

    currentRiddleIndex = 0;
    setState(() {});
  }

  void _startGame() {
    setState(() {
      showingCountdown = true;
      countdownNumber = 3;
    });
    _showCountdown();
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
      gameActive = true;
      gameStartTime = DateTime.now();
      score = 0;
      correctAnswers = 0;
      wrongAnswers = 0;
      currentRiddleIndex = 0;
      riddleAnswered = false;
      selectedAnswer = null;
      showHint = false;
    });
    await _showGoOverlay();
    _startCurrentRiddle();
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

  void _startCurrentRiddle() {
    setState(() {
      riddleAnswered = false;
      selectedAnswer = null;
      showHint = false;
      timeLeft = timePerRiddle;
    });

    if (timePerRiddle > 0) {
      _startRiddleTimer();
    }
  }

  void _startRiddleTimer() {
    riddleTimer?.cancel();
    riddleTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        timeLeft--;
      });

      if (timeLeft <= 0) {
        timer.cancel();
        _timeUpForRiddle();
      }
    });
  }

  void _timeUpForRiddle() {
    if (!riddleAnswered) {
      wrongAnswers++;
      _showRiddleResult(false, "Time's up!");
    }
  }

  void _onAnswerSelected(String answer) {
    if (riddleAnswered || !gameActive) return;

    riddleTimer?.cancel();
    
    Riddle currentRiddle = gameRiddles[currentRiddleIndex];
    bool isCorrect = answer == currentRiddle.correctAnswer;

    setState(() {
      selectedAnswer = answer;
      riddleAnswered = true;
    });

    if (isCorrect) {
      correctAnswers++;
      score += 20 + (timeLeft > 0 ? timeLeft ~/ 3 : 0); // Time bonus
      HapticFeedback.mediumImpact();
      // Play success sound with voice effect
      SoundEffectsManager().playSuccessWithVoice();
    } else {
      wrongAnswers++;
      HapticFeedback.lightImpact();
      // Play wrong sound effect
      SoundEffectsManager().playWrong();
    }

    _showRiddleResult(isCorrect, currentRiddle.explanation ?? "");
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

  void _showRiddleResult(bool isCorrect, String explanation) {
    // Only show overlay for correct answers
    if (isCorrect) {
      _showStatusOverlay(
        text: '✓',
        color: Colors.green,
        textColor: Colors.white,
      ).then((_) {
        _nextRiddle();
      });
    } else {
      // For wrong answers, just wait a moment then move to next riddle
      Future.delayed(const Duration(milliseconds: 1000)).then((_) {
        _nextRiddle();
      });
    }
  }

  void _nextRiddle() {
    if (currentRiddleIndex < totalRiddles - 1) {
      setState(() {
        currentRiddleIndex++;
      });
      _startCurrentRiddle();
    } else {
      _endGame();
    }
  }

  void _showHintDialog() {
    Riddle currentRiddle = gameRiddles[currentRiddleIndex];
    if (currentRiddle.visualHint == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: 400),
          padding: EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accentColor,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 0,
                offset: Offset(0, 8),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title with icon
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 0,
                          offset: Offset(0, 4),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.lightbulb,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Visual Hint',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              // Emoji hint in a yellow circle
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Color(0xFFF5DDA9),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Color(0xFFE5C77A),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 0,
                      offset: Offset(0, 6),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    currentRiddle.visualHint!,
                    style: TextStyle(fontSize: 70),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              SizedBox(height: 20),
              // Hint text
              Text(
                'Think about what this represents!',
                style: TextStyle(
                  color: Color(0xFF2C3E50),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              // Got it button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: Text(
                    'GOT IT!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
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

  void _endGame() {
    setState(() {
      gameActive = false;
    });

    riddleTimer?.cancel();

    // Calculate game statistics
    double accuracyDouble = totalRiddles > 0
        ? (correctAnswers / totalRiddles) * 100
        : 0;
    int accuracy = accuracyDouble.round();
    int completionTime = DateTime.now().difference(gameStartTime).inSeconds;

    // Call completion callback if provided
    if (widget.onGameComplete != null) {
      widget.onGameComplete!(
        accuracy: accuracy,
        completionTime: completionTime,
        challengeFocus: 'Logic',
        gameName: 'Riddle',
        difficulty: widget.difficulty,
      );
    }
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
    riddleTimer?.cancel();
    _goController.dispose();
    // Stop background music when leaving the game
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
          image: DecorationImage(
            image: AssetImage('assets/verbalbg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                // Body content
                Expanded(
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: showingCountdown
                          ? _buildCountdownScreen()
                          : (gameStarted ? _buildGameArea() : _buildStartScreen()),
                    ),
                  ),
                ),
              ],
            ),
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
                                  shadows: [
                                    Shadow(
                                      color: Colors.black26,
                                      offset: Offset(2, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
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
                                      color: Colors.black.withOpacity(0.3),
                                      offset: const Offset(0, 6),
                                      blurRadius: 0,
                                      spreadRadius: 0,
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
            // Status overlay (✓ or X)
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
            // Need Help button - shown only during gameplay
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
      heroTag: 'riddleHelpBtn',
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      icon: const Icon(Icons.help_outline),
      label: const Text('Need Help?'),
      onPressed: () async {
        bool showSimple = false;
        // Speak the initial help text
        await HelpTtsManager().speak('Read each riddle carefully and choose the correct answer from the options. If you need help, tap the lightbulb icon for a visual hint!');
        
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) {
              return WillPopScope(
                onWillPop: () async {
                  await HelpTtsManager().stop();
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
                            const Expanded(
                              child: Text(
                                'Need Help?',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF5D83B9),
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
                                ? 'Read the riddle carefully. Think about what it could be. Pick the answer that makes the most sense. Use the lightbulb if you need a hint!'
                                : 'Read each riddle carefully and choose the correct answer from the options. If you need help, tap the lightbulb icon for a visual hint!',
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
                                  onPressed: () async {
                                    if (!showSimple) {
                                      setState(() {
                                        showSimple = true;
                                      });
                                      // Speak the simpler explanation
                                      await HelpTtsManager().speak('Read the riddle carefully. Think about what it could be. Pick the answer that makes the most sense. Use the lightbulb if you need a hint!');
                                    } else {
                                      await HelpTtsManager().stop();
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

  Widget _buildStartScreen() {
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
                'Riddle Game',
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
                      color: accentColor.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.psychology,
                  size: isTablet ? 56 : 48,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Solve the riddles!',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: isTablet ? 22 : 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: showSimpleInstruction
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: Text(
                  'Read each riddle carefully and choose the correct answer from the options. If you need help, tap the lightbulb icon for a visual hint!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: primaryColor.withOpacity(0.9),
                    fontSize: isTablet ? 18 : 15,
                    height: 1.35,
                  ),
                ),
                secondChild: Text(
                  'Read the riddle carefully. Think about what it could be. Pick the answer that makes the most sense. Use the lightbulb if you need a hint!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: primaryColor.withOpacity(0.9),
                    fontSize: isTablet ? 18 : 15,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
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
                      letterSpacing: 1.2,
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
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(2, 2),
                  blurRadius: 4,
                ),
              ],
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
                  color: accentColor.withOpacity(0.5),
                  blurRadius: 30,
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
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameArea() {
    if (currentRiddleIndex >= gameRiddles.length) {
      return _buildCompletionScreen();
    }

    Riddle currentRiddle = gameRiddles[currentRiddleIndex];

    return Column(
      children: [
        // Progress indicator
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 0,
                      offset: Offset(0, 4),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.question_mark_rounded, color: primaryColor, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Riddle ${currentRiddleIndex + 1}/$totalRiddles',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (timePerRiddle > 0) ...[
                SizedBox(width: 16),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: timeLeft <= 10 ? Color(0xFFFFCDD2) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 0,
                        offset: Offset(0, 4),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer,
                        color: timeLeft <= 10 ? Colors.red : primaryColor,
                        size: 20,
                      ),
                      SizedBox(width: 6),
                      Text(
                        '${timeLeft}s',
                        style: TextStyle(
                          color: timeLeft <= 10 ? Colors.red : primaryColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Container(
                constraints: BoxConstraints(maxWidth: 600),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Riddle question card
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: questionColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 0,
                            offset: Offset(0, 6),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.question_answer,
                            color: primaryColor,
                            size: 40,
                          ),
                          SizedBox(height: 16),
                          Text(
                            currentRiddle.question,
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (currentRiddle.visualHint != null) ...[
                            SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: riddleAnswered ? null : _showHintDialog,
                              icon: Icon(Icons.lightbulb_outline, size: 20),
                              label: Text(
                                'Show Hint',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: primaryColor,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // Answer options
                    ...currentRiddle.options.map((option) {
                      bool isSelected = selectedAnswer == option;
                      bool isCorrect = option == currentRiddle.correctAnswer;
                      bool showResult = riddleAnswered;

                      Color cardColor;
                      if (showResult) {
                        if (isCorrect) {
                          cardColor = correctColor;
                        } else if (isSelected) {
                          cardColor = wrongColor;
                        } else {
                          cardColor = optionColor;
                        }
                      } else if (isSelected) {
                        cardColor = selectedColor;
                      } else {
                        cardColor = optionColor;
                      }

                      return Container(
                        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: riddleAnswered ? null : () => _onAnswerSelected(option),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 18,
                              ),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: showResult && isCorrect
                                      ? Colors.green.shade700
                                      : (showResult && isSelected
                                          ? Colors.red.shade700
                                          : primaryColor.withOpacity(0.3)),
                                  width: showResult && (isCorrect || isSelected) ? 3 : 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 0,
                                    offset: Offset(0, 4),
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  if (showResult && isCorrect)
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green.shade700,
                                      size: 24,
                                    ),
                                  if (showResult && isSelected && !isCorrect)
                                    Icon(
                                      Icons.cancel,
                                      color: Colors.red.shade700,
                                      size: 24,
                                    ),
                                  if (showResult && (isCorrect || isSelected))
                                    SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),

                    // Show explanation after answering
                    if (riddleAnswered && currentRiddle.explanation != null) ...[
                      SizedBox(height: 20),
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 20),
                        padding: EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: primaryColor,
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                currentRiddle.explanation!,
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionScreen() {
    double accuracyDouble = totalRiddles > 0
        ? (correctAnswers / totalRiddles) * 100
        : 0;
    int accuracy = accuracyDouble.round();
    int completionTime = DateTime.now().difference(gameStartTime).inSeconds;

    // Show completion dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showGameOverDialog(accuracy, completionTime);
      }
    });

    return Container();
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
              child: const Icon(Icons.psychology, color: Colors.white, size: 48),
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
              _buildStatRow(Icons.star_rounded, 'Score', '$score points'),
              const SizedBox(height: 12),
              _buildStatRow(Icons.check_circle, 'Correct', '$correctAnswers/$totalRiddles'),
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
                        setState(() {
                          score = 0;
                          correctAnswers = 0;
                          wrongAnswers = 0;
                          currentRiddleIndex = 0;
                          riddleAnswered = false;
                          selectedAnswer = null;
                          showHint = false;
                          gameStarted = false;
                          gameActive = false;
                          showingCountdown = false;
                        });
                        _initializeGame();
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
                onPressed: () async {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                  
                  if (widget.onGameComplete != null) {
                    await widget.onGameComplete!(
                      accuracy: accuracy,
                      completionTime: completionTime,
                      challengeFocus: 'Logic',
                      gameName: 'Riddle',
                      difficulty: widget.difficulty,
                    );
                  }
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
}

// Teacher PIN Dialog Widget
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
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(255, 181, 187, 17),
              blurRadius: 0,
              spreadRadius: 0,
              offset: const Offset(0, 8),
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
                    child: const Icon(Icons.lock, color: Color(0xFF5B6F4A), size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Teacher PIN Required',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF5B6F4A),
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
                child: const Text(
                  'Enter your 6-digit PIN to exit the session and access teacher features.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF5B6F4A),
                    fontWeight: FontWeight.w600,
                  ),
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
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5B6F4A),
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    hintStyle: TextStyle(
                      color: const Color(0xFF5B6F4A).withOpacity(0.4),
                      letterSpacing: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF5B6F4A),
                        width: 2,
                      ),
                    ),
                    errorText: _error,
                    errorStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
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
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.6),
                            blurRadius: 0,
                            spreadRadius: 0,
                            offset: const Offset(0, 4),
                          ),
                        ],
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF5B6F4A).withOpacity(0.6),
                            blurRadius: 0,
                            spreadRadius: 0,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyPin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5B6F4A),
                          foregroundColor: const Color(0xFFFFD740),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFFFFD740),
                                  ),
                                ),
                              )
                            : const Text(
                                'Verify',
                                style: TextStyle(
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
    );
  }
}