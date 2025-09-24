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

class _RiddleGameState extends State<RiddleGame> {
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

  Random random = Random();
  
  // App color scheme
  final Color primaryColor = const Color(0xFF5B6F4A);
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

    _showInstructions();
  }

  void _showInstructions() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFFF8F9FA),
        title: Text(
          'Riddle Instructions',
          style: TextStyle(color: Color(0xFF2C3E50)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Solve the riddles!',
              style: TextStyle(color: Color(0xFF2C3E50), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              '• Read each riddle carefully\n• Choose the correct answer\n• Use visual hints if needed\n• Complete ${totalRiddles} riddles to finish!',
              style: TextStyle(color: Color(0xFF2C3E50)),
              textAlign: TextAlign.left,
            ),
            if (timePerRiddle > 0) ...[
              SizedBox(height: 8),
              Text(
                'Time per riddle: ${timePerRiddle}s',
                style: TextStyle(
                  color: Color(0xFFE57373),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startCurrentRiddle();
            },
            child: Text(
              'Start Solving!',
              style: TextStyle(color: Color(0xFF81C784)),
            ),
          ),
        ],
      ),
    );
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
    setState(() {
      selectedAnswer = answer;
      riddleAnswered = true;
    });

    Riddle currentRiddle = gameRiddles[currentRiddleIndex];
    bool isCorrect = answer == currentRiddle.correctAnswer;

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

  void _showRiddleResult(bool isCorrect, String explanation) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFFF8F9FA),
        title: Text(
          isCorrect ? 'Correct! 🎉' : 'Oops! 😅',
          style: TextStyle(
            color: isCorrect ? Color(0xFF81C784) : Color(0xFFE57373),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isCorrect) ...[
              Text(
                'The correct answer was: ${gameRiddles[currentRiddleIndex].correctAnswer}',
                style: TextStyle(
                  color: Color(0xFF2C3E50),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
            ],
            if (explanation.isNotEmpty) ...[
              Text(
                explanation,
                style: TextStyle(color: Color(0xFF2C3E50)),
                textAlign: TextAlign.center,
              ),
            ],
            SizedBox(height: 12),
            Text(
              'Score: +${isCorrect ? (20 + (timeLeft > 0 ? timeLeft ~/ 3 : 0)) : 0}',
              style: TextStyle(color: Color(0xFF2C3E50), fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _nextRiddle();
            },
            child: Text(
              currentRiddleIndex < totalRiddles - 1
                  ? 'Next Riddle'
                  : 'See Results',
              style: TextStyle(color: Color(0xFF81C784)),
            ),
          ),
        ],
      ),
    );
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
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFFF8F9FA),
        title: Text('Visual Hint', style: TextStyle(color: Color(0xFF2C3E50))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentRiddle.visualHint!,
              style: TextStyle(fontSize: 60),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'Think about what this represents!',
              style: TextStyle(color: Color(0xFF2C3E50)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it!', style: TextStyle(color: Color(0xFF81C784))),
          ),
        ],
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
    // Stop background music when leaving the game
    BackgroundMusicManager().stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Riddle Game - ${DifficultyUtils.getDifficultyDisplayName(widget.difficulty)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Score and Progress Display
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Text(
                        'Score: $score',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      Text(
                        'Correct: $correctAnswers',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Riddle: ${currentRiddleIndex + 1}/$totalRiddles',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  if (timePerRiddle > 0 && gameActive && !riddleAnswered)
                    Column(
                      children: [
                        Text(
                          'Time: ${timeLeft}s',
                          style: TextStyle(
                            fontSize: 16,
                            color: timeLeft <= 5
                                ? Color(0xFFE57373)
                                : Color(0xFF2C3E50),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Game Area
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: gameStarted ? _buildGameArea() : _buildStartScreen(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartScreen() {
    return Column(
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
                      '${currentRiddleIndex + 1}/$totalRiddles',
                      style: const TextStyle(
                        fontSize: 14,
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
                      '$correctAnswers',
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
            Icons.quiz,
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
            'Think carefully!',
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
          child: Text(
            'Solve $totalRiddles brain-teasing riddles!',
            style: const TextStyle(
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
          onPressed: _startGame,
          child: const Text(
            'Start !',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
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
        // Question Area
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(20),
          margin: EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: questionColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                currentRiddle.question,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              if (currentRiddle.visualHint != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _showHintDialog,
                      icon: Icon(Icons.lightbulb_outline),
                      label: Text('Visual Hint'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFFFF176),
                        foregroundColor: Color(0xFF2C3E50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Answer Options
        Expanded(
          child: Column(
            children: currentRiddle.options
                .map((option) => _buildAnswerOption(option))
                .toList(),
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
      child: ElevatedButton(
        onPressed: riddleAnswered ? null : () => _onAnswerSelected(option),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Color(0xFF2C3E50),
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: Row(
          children: [
            if (isCorrect) ...[
              Icon(Icons.check_circle, color: Colors.white, size: 24),
              SizedBox(width: 12),
            ] else if (isWrong) ...[
              Icon(Icons.cancel, color: Colors.white, size: 24),
              SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: (isCorrect || isWrong)
                      ? Colors.white
                      : Color(0xFF2C3E50),
                ),
                textAlign: TextAlign.left,
              ),
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
}
