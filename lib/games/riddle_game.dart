import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import '../utils/background_music_manager.dart';
import '../utils/sound_effects_manager.dart';
import '../utils/difficulty_utils.dart';

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
    return Scaffold(
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
          ],
        ),
      ),
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
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: primaryColor.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.25),
                offset: const Offset(0, 12),
                blurRadius: 24,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.5),
                offset: const Offset(0, -4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Riddle Time',
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
                  color: primaryColor,
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
                  Icons.psychology,
                  size: isTablet ? 56 : 48,
                  color: Colors.white,
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
              Text(
                'Read each riddle carefully and choose the correct answer. Use the lightbulb hint if you need help. Complete $totalRiddles riddles to finish!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryColor.withOpacity(0.85),
                  fontSize: isTablet ? 18 : 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isTablet ? 18 : 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                    shadowColor: primaryColor.withOpacity(0.5),
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
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 0,
                  offset: Offset(0, 6),
                  spreadRadius: 0,
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
    if (!gameActive) {
      return _buildEndScreen();
    }

    if (currentRiddleIndex >= gameRiddles.length) {
      return _buildEndScreen();
    }

    Riddle currentRiddle = gameRiddles[currentRiddleIndex];

    return Column(
      children: [
        // Top HUD - Time and Correct counters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoCircle(
                label: 'Time',
                value: timePerRiddle > 0 ? '${timeLeft}s' : '${DateTime.now().difference(gameStartTime).inSeconds}s',
                circleSize: 104,
                valueFontSize: 30,
                labelFontSize: 26,
              ),
              _infoCircle(
                label: 'Correct',
                value: '$correctAnswers/$totalRiddles',
                circleSize: 104,
                valueFontSize: 30,
                labelFontSize: 26,
              ),
            ],
          ),
        ),
        
        SizedBox(height: 20),

        // Question Area - Yellow box with lightbulb
        Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: 650),
            padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            margin: EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: Color(0xFFF5DDA9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Color(0xFFE5C77A),
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
            child: Text(
              currentRiddle.question,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),

        // Lightbulb hint icon below the box
        if (currentRiddle.visualHint != null) ...[
          SizedBox(height: 16),
          GestureDetector(
            onTap: _showHintDialog,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 0,
                    offset: Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(
                Icons.lightbulb_outline,
                color: accentColor,
                size: 30,
              ),
            ),
          ),
        ],

        SizedBox(height: 24),

        // Answer Options - White rounded buttons
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: currentRiddle.options
                    .map((option) => _buildAnswerOption(option))
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerOption(String option) {
    bool isSelected = selectedAnswer == option;
    bool isCorrect =
        riddleAnswered &&
        option == gameRiddles[currentRiddleIndex].correctAnswer;
    bool isWrong = riddleAnswered && isSelected && !isCorrect;

    Color backgroundColor;
    if (isCorrect) {
      backgroundColor = correctColor;
    } else if (isWrong) {
      backgroundColor = wrongColor;
    } else if (isSelected) {
      backgroundColor = selectedColor;
    } else {
      backgroundColor = optionColor;
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 0,
            offset: Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: riddleAnswered ? null : () => _onAnswerSelected(option),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Color(0xFF2C3E50),
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isCorrect) ...[
              Icon(Icons.check_circle, color: Colors.white, size: 24),
              SizedBox(width: 12),
            ] else if (isWrong) ...[
              Icon(Icons.cancel, color: Colors.white, size: 24),
              SizedBox(width: 12),
            ],
            Text(
              option.toUpperCase(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: (isCorrect || isWrong)
                    ? Colors.white
                    : Color(0xFF2C3E50),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndScreen() {
    // Schedule dialog to show after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showGameOverDialog();
    });
    return Container(); // Return empty container since dialog handles the UI
  }

  void _resetGame() {
    setState(() {
      currentRiddleIndex = 0;
      correctAnswers = 0;
      wrongAnswers = 0;
      selectedAnswer = null;
      showHint = false;
      riddleAnswered = false;
      gameStarted = false;
      gameActive = false;
      score = 0;
    });
    
    riddleTimer?.cancel();
    _startGame();
  }

  void _showGameOverDialog() {
    double accuracy = totalRiddles > 0
        ? (correctAnswers / totalRiddles) * 100
        : 0;
    final completionTime = DateTime.now().difference(gameStartTime).inSeconds;
    
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
                  color: const Color(0xFF81C784),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF81C784).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Riddle Master! 🧩✨',
                style: TextStyle(
                  color: const Color(0xFF2C3E50),
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
                _buildStatRow(Icons.star_rounded, 'Final Score', '$score points'),
                const SizedBox(height: 12),
                _buildStatRow(Icons.quiz, 'Riddles Solved', '$correctAnswers/$totalRiddles'),
                const SizedBox(height: 12),
                _buildStatRow(Icons.track_changes, 'Accuracy', '${accuracy.toStringAsFixed(1)}%'),
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
                          backgroundColor: const Color(0xFF81C784),
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
                    backgroundColor: const Color(0xFF81C784),
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
            color: const Color(0xFFCE93D8).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF2C3E50), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: const Color(0xFF2C3E50),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: const Color(0xFF2C3E50),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _infoCircle({required String label, required String value, double circleSize = 88, double valueFontSize = 18, double labelFontSize = 12}) {
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
              color: Colors.blueGrey,
              fontSize: valueFontSize,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}
