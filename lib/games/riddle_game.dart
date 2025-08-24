import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import '../utils/background_music_manager.dart';
import '../utils/difficulty_utils.dart';

class RiddleGame extends StatefulWidget {
  final String difficulty;
  final Function({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })? onGameComplete;

  const RiddleGame({
    Key? key,
    required this.difficulty,
    this.onGameComplete,
  }) : super(key: key);

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
  
  // Riddle sets organized by difficulty
  final Map<String, List<Riddle>> riddleSets = {
    'easy': [
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
        question: "I'm cold, white, and fall from the sky in winter. What am I?",
        correctAnswer: "Snow",
        options: ["Rain", "Snow", "Hail", "Ice"],
        visualHint: "❄️",
        explanation: "Snow is cold, white, and falls from winter clouds!",
      ),
    ],
    'medium': [
      Riddle(
        question: "I have keys but no locks. I have space but no room. You can enter but not go inside. What am I?",
        correctAnswer: "Keyboard",
        options: ["Piano", "Computer", "Keyboard", "House"],
        visualHint: "⌨️",
        explanation: "A keyboard has keys, spacebar, and enter key but no physical locks or rooms!",
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
        explanation: "A clock has hands (hour and minute hands) but cannot clap!",
      ),
      Riddle(
        question: "I get wet while drying. What am I?",
        correctAnswer: "Towel",
        options: ["Sponge", "Towel", "Hair", "Clothes"],
        visualHint: "🏖️",
        explanation: "A towel gets wet when it dries other things!",
      ),
      Riddle(
        question: "I'm light as a feather, yet the strongest person can't hold me for long. What am I?",
        correctAnswer: "Breath",
        options: ["Air", "Breath", "Feather", "Paper"],
        visualHint: "💨",
        explanation: "Your breath is very light, but you can't hold it for very long!",
      ),
      Riddle(
        question: "I have a neck but no head. What am I?",
        correctAnswer: "Bottle",
        options: ["Shirt", "Bottle", "Guitar", "Giraffe"],
        visualHint: "🍶",
        explanation: "A bottle has a neck (the narrow part) but no head!",
      ),
    ],
    'hard': [
      Riddle(
        question: "The more you take away from me, the bigger I become. What am I?",
        correctAnswer: "Hole",
        options: ["Hole", "Debt", "Problem", "Shadow"],
        visualHint: "🕳️",
        explanation: "When you dig a hole, the more dirt you take away, the bigger the hole gets!",
      ),
      Riddle(
        question: "I'm not alive, but I grow. I don't have lungs, but I need air. I don't have a mouth, but water kills me. What am I?",
        correctAnswer: "Fire",
        options: ["Plant", "Fire", "Balloon", "Cloud"],
        visualHint: "🔥",
        explanation: "Fire grows larger, needs oxygen (air), but water extinguishes it!",
      ),
      Riddle(
        question: "What has many teeth but cannot bite?",
        correctAnswer: "Comb",
        options: ["Saw", "Comb", "Gear", "Zipper"],
        visualHint: "💇",
        explanation: "A comb has many teeth (the thin parts) but cannot bite!",
      ),
      Riddle(
        question: "I have cities, but no houses. I have mountains, but no trees. I have water, but no fish. What am I?",
        correctAnswer: "Map",
        options: ["Map", "Globe", "Picture", "Book"],
        visualHint: "🗺️",
        explanation: "A map shows cities, mountains, and water, but not the actual houses, trees, or fish!",
      ),
      Riddle(
        question: "What comes once in a minute, twice in a moment, but never in a thousand years?",
        correctAnswer: "Letter M",
        options: ["Time", "Letter M", "Sound", "Breath"],
        visualHint: "🔤",
        explanation: "The letter 'M' appears once in 'minute', twice in 'moment', but never in 'thousand years'!",
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
  
  // Soft, accessible colors
  final Color backgroundColor = Color(0xFFF8F9FA);
  final Color questionColor = Color(0xFFE1F5FE); // Light blue
  final Color optionColor = Color(0xFFFFFFFF); // White
  final Color selectedColor = Color(0xFFFFF176); // Soft yellow
  final Color correctColor = Color(0xFF81C784); // Soft green
  final Color wrongColor = Color(0xFFEF9A9A); // Soft red

  @override
  void initState() {
    super.initState();
    // Start background music for this game
    BackgroundMusicManager().startGameMusic('Riddle Game');
    _initializeGame();
  }

  void _initializeGame() {
    // Set difficulty parameters
    switch (widget.difficulty.toLowerCase()) {
      case 'easy':
        totalRiddles = 5;
        timePerRiddle = 0; // No timer for easy
        break;
      case 'medium':
        totalRiddles = 6;
        timePerRiddle = 45; // 45 seconds per riddle
        break;
      case 'hard':
        totalRiddles = 8;
        timePerRiddle = 30; // 30 seconds per riddle
        break;
      default:
        totalRiddles = 5;
        timePerRiddle = 0;
    }
    
    _setupRiddles();
  }

  void _setupRiddles() {
    gameRiddles.clear();
    
    String difficultyKey = widget.difficulty.toLowerCase();
    List<Riddle> availableRiddles = List.from(riddleSets[difficultyKey] ?? riddleSets['easy']!);
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
        title: Text('Riddle Instructions', style: TextStyle(color: Color(0xFF2C3E50))),
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
                style: TextStyle(color: Color(0xFFE57373), fontWeight: FontWeight.bold),
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
            child: Text('Start Solving!', style: TextStyle(color: Color(0xFF81C784))),
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
    } else {
      wrongAnswers++;
      HapticFeedback.lightImpact();
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
          style: TextStyle(color: isCorrect ? Color(0xFF81C784) : Color(0xFFE57373)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isCorrect) ...[
              Text(
                'The correct answer was: ${gameRiddles[currentRiddleIndex].correctAnswer}',
                style: TextStyle(color: Color(0xFF2C3E50), fontWeight: FontWeight.bold),
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
              currentRiddleIndex < totalRiddles - 1 ? 'Next Riddle' : 'See Results',
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
    double accuracyDouble = totalRiddles > 0 ? (correctAnswers / totalRiddles) * 100 : 0;
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
        title: Text('Riddle Game - ${DifficultyUtils.getDifficultyDisplayName(widget.difficulty)}'),
        backgroundColor: Color(0xFFCE93D8), // Soft purple
        foregroundColor: Colors.white,
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
                      Text('Score: $score', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                      Text('Correct: $correctAnswers', style: TextStyle(fontSize: 14, color: Color(0xFF2C3E50))),
                    ],
                  ),
                  Text('Riddle: ${currentRiddleIndex + 1}/$totalRiddles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                  if (timePerRiddle > 0 && gameActive && !riddleAnswered)
                    Column(
                      children: [
                        Text('Time: ${timeLeft}s', style: TextStyle(fontSize: 16, color: timeLeft <= 5 ? Color(0xFFE57373) : Color(0xFF2C3E50), fontWeight: FontWeight.bold)),
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
        Icon(
          Icons.quiz,
          size: 80,
          color: Color(0xFFCE93D8),
        ),
        SizedBox(height: 20),
        Text(
          'Riddle Game',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 20),
        Text(
          'Difficulty: ${DifficultyUtils.getDifficultyDisplayName(widget.difficulty)}',
          style: TextStyle(fontSize: 24, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 20),
        Text(
          'Solve $totalRiddles brain-teasing riddles!',
          style: TextStyle(fontSize: 18, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 40),
        ElevatedButton(
          onPressed: _startGame,
          child: Text('Start Riddles'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF81C784),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            children: currentRiddle.options.map((option) => _buildAnswerOption(option)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerOption(String option) {
    bool isSelected = selectedAnswer == option;
    bool isCorrect = riddleAnswered && option == gameRiddles[currentRiddleIndex].correctAnswer;
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  color: (isCorrect || isWrong) ? Colors.white : Color(0xFF2C3E50),
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
    double accuracy = totalRiddles > 0 ? (correctAnswers / totalRiddles) * 100 : 0;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.psychology,
          size: 80,
          color: Color(0xFF81C784),
        ),
        SizedBox(height: 20),
        Text(
          'Riddles Complete!',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 20),
        Text(
          'Final Score: $score',
          style: TextStyle(fontSize: 24, color: Color(0xFF2C3E50)),
        ),
        Text(
          'Correct: $correctAnswers/$totalRiddles',
          style: TextStyle(fontSize: 20, color: Color(0xFF2C3E50)),
        ),
        Text(
          'Accuracy: ${accuracy.toStringAsFixed(1)}%',
          style: TextStyle(fontSize: 20, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 40),
        ElevatedButton(
          onPressed: () {
            _initializeGame();
            setState(() {
              gameStarted = false;
            });
          },
          child: Text('New Riddles'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF81C784),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.onGameComplete != null ? 'Next Game' : 'Back to Menu'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFCE93D8),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
