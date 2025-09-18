import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../utils/background_music_manager.dart';
import '../utils/sound_effects_manager.dart';
import '../utils/difficulty_utils.dart';

class RhymeTimeGame extends StatefulWidget {
  final String difficulty;
  final Function({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })?
  onGameComplete;

  const RhymeTimeGame({Key? key, required this.difficulty, this.onGameComplete})
    : super(key: key);

  @override
  _RhymeTimeGameState createState() => _RhymeTimeGameState();
}

class RhymeWord {
  final String word;
  final String rhymeGroup;
  bool isSelected;
  bool isMatched;

  RhymeWord({
    required this.word,
    required this.rhymeGroup,
    this.isSelected = false,
    this.isMatched = false,
  });
}

class _RhymeTimeGameState extends State<RhymeTimeGame>
    with TickerProviderStateMixin {
  List<RhymeWord> currentWords = [];
  RhymeWord? firstSelectedWord;
  RhymeWord? secondSelectedWord;
  bool canSelect = true;
  int score = 0;
  int correctMatches = 0;
  int wrongAttempts = 0;
  int totalPairs = 0;
  late DateTime gameStartTime;
  Timer? gameTimer;
  int timeLeft = 0;
  bool gameStarted = false;
  bool gameActive = false;
  String _normalizedDifficulty = 'easy';

  // Text-to-speech instance
  late FlutterTts flutterTts;

  // Animation controllers for enhanced UX
  late AnimationController _cardAnimationController;
  late AnimationController _scoreAnimationController;
  late AnimationController _celebrationController;

  // Enhanced rhyme groups organized by difficulty
  final Map<String, List<Map<String, String>>> rhymeGroups = {
    'easy': [
      {'cat': 'at', 'hat': 'at', 'bat': 'at', 'mat': 'at'},
      {'dog': 'og', 'frog': 'og', 'log': 'og', 'hog': 'og'},
      {'car': 'ar', 'star': 'ar', 'far': 'ar', 'jar': 'ar'},
      {'bee': 'ee', 'tree': 'ee', 'free': 'ee', 'see': 'ee'},
      {'run': 'un', 'fun': 'un', 'sun': 'un', 'bun': 'un'},
      {'red': 'ed', 'bed': 'ed', 'fed': 'ed', 'led': 'ed'},
      {'big': 'ig', 'pig': 'ig', 'fig': 'ig', 'wig': 'ig'},
      {'sit': 'it', 'hit': 'it', 'fit': 'it', 'pit': 'it'},
      {'cake': 'ake', 'make': 'ake', 'lake': 'ake', 'wake': 'ake'},
      {'ball': 'all', 'call': 'all', 'fall': 'all', 'wall': 'all'},
      {'boat': 'oat', 'coat': 'oat', 'goat': 'oat', 'float': 'oat'},
      {'rain': 'ain', 'pain': 'ain', 'train': 'ain', 'brain': 'ain'},
    ],
    'medium': [
      {'window': 'indo', 'bingo': 'indo'},
      {'flower': 'ower', 'tower': 'ower', 'power': 'ower', 'shower': 'ower'},
      {'happy': 'appy', 'snappy': 'appy', 'clappy': 'appy'},
      {'chicken': 'icken', 'thicken': 'icken', 'quicken': 'icken'},
      {
        'butter': 'utter',
        'mutter': 'utter',
        'flutter': 'utter',
        'clutter': 'utter',
      },
      {'apple': 'apple', 'grapple': 'apple', 'chapel': 'apple'},
      {'paper': 'aper', 'caper': 'aper', 'taper': 'aper'},
      {'water': 'ater', 'matter': 'atter', 'chatter': 'atter'},
      {'cookie': 'ookie', 'rookie': 'ookie', 'bookie': 'ookie'},
      {'monkey': 'onkey', 'donkey': 'onkey', 'honkey': 'onkey'},
      {'purple': 'urple', 'circle': 'ircle', 'hurdle': 'urdle'},
      {'tiger': 'iger', 'finger': 'inger', 'singer': 'inger'},
    ],
    'hard': [
      {'enough': 'uff', 'rough': 'uff', 'tough': 'uff', 'stuff': 'uff'},
      {'weight': 'ate', 'straight': 'ate', 'create': 'ate', 'relate': 'ate'},
      {
        'bought': 'ought',
        'thought': 'ought',
        'caught': 'ought',
        'fought': 'ought',
      },
      {'listen': 'isten', 'glisten': 'isten', 'christen': 'isten'},
      {'ocean': 'tion', 'motion': 'tion', 'potion': 'tion', 'devotion': 'tion'},
      {'through': 'ough', 'threw': 'ew', 'knew': 'ew', 'grew': 'ew'},
      {'heart': 'art', 'part': 'art', 'start': 'art', 'smart': 'art'},
      {'break': 'ake', 'cake': 'ake', 'make': 'ake', 'mistake': 'ake'},
      {'beautiful': 'iful', 'wonderful': 'erful', 'powerful': 'erful'},
      {'elephant': 'ant', 'important': 'ant', 'pleasant': 'ant'},
      {'celebration': 'ation', 'education': 'ation', 'vacation': 'ation'},
      {'butterfly': 'fly', 'dragonfly': 'fly', 'firefly': 'fly'},
    ],
  };

  Random random = Random();

  // Attention category theme colors
  final Color primaryColor = Color(0xFF5B6F4A); // Dark green
  final Color backgroundColor = Color(0xFFF5F5DC); // Beige/cream
  final Color accentColor = Color(0xFFFFD740); // Golden yellow
  final Color unselectedColor = Color(0xFFF5F5DC); // Cream background
  final Color selectedColor = Color(0xFFFFD740); // Golden yellow for selection
  final Color matchedColor = Color(0xFF5B6F4A); // Dark green for matches

  @override
  void initState() {
    super.initState();

    // Start background music for this game
    BackgroundMusicManager().startGameMusic('Rhyme Time');

    // Initialize text-to-speech
    _initializeTts();

    // Initialize animation controllers
    _cardAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _scoreAnimationController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _celebrationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _initializeGame();
  }

  void _initializeTts() async {
    flutterTts = FlutterTts();
    
    // Configure TTS settings
    await flutterTts.setLanguage('en-US');
    await flutterTts.setSpeechRate(0.6); // Slower rate for clear pronunciation
    await flutterTts.setVolume(0.8);
    await flutterTts.setPitch(1.0);
  }

  Future<void> _speakWord(String word) async {
    try {
      await flutterTts.speak(word);
    } catch (e) {
      print('Error speaking word: $e');
    }
  }

  void _initializeGame() {
    // Normalize difficulty and set parameters
    final diffKey = DifficultyUtils.getDifficultyInternalValue(
      widget.difficulty,
    ).toLowerCase();
    _normalizedDifficulty = diffKey;
    // Set difficulty parameters
    switch (diffKey) {
      case 'easy':
        totalPairs = 3; // 3 pairs = 6 words
        timeLeft = 0; // No timer for easy
        break;
      case 'medium':
        totalPairs = 4; // 4 pairs = 8 words
        timeLeft = 120; // 2 minutes
        break;
      case 'hard':
        totalPairs = 5; // 5 pairs = 10 words
        timeLeft = 90; // 1.5 minutes
        break;
      default:
        totalPairs = 3;
        timeLeft = 0;
    }

    _setupWords(diffKey);
  }

  void _setupWords(String difficultyKey) {
    currentWords.clear();
    List<Map<String, String>> availableGroups =
        rhymeGroups[difficultyKey] ?? rhymeGroups['easy']!;

    // Select random rhyme groups
    List<Map<String, String>> selectedGroups = List.from(availableGroups);
    selectedGroups.shuffle();
    selectedGroups = selectedGroups.take(totalPairs).toList();

    // Add words from each group
    for (var group in selectedGroups) {
      String rhymePattern = group.values.first;
      List<String> wordsInGroup = group.keys.toList();

      // Take 2 words from each group to make a pair
      for (int i = 0; i < 2 && i < wordsInGroup.length; i++) {
        currentWords.add(
          RhymeWord(word: wordsInGroup[i], rhymeGroup: rhymePattern),
        );
      }
    }

    // Shuffle all words
    currentWords.shuffle();
    setState(() {});
  }

  void _startGame() {
    setState(() {
      gameStarted = true;
      gameActive = true;
      gameStartTime = DateTime.now();
      score = 0;
      correctMatches = 0;
      wrongAttempts = 0;
      canSelect = true;

      // Reset all words
      for (var word in currentWords) {
        word.isSelected = false;
        word.isMatched = false;
      }

      firstSelectedWord = null;
      secondSelectedWord = null;
    });

    _showInstructions();
  }

  void _showInstructions() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text(
          'Rhyme Time Instructions',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        content: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryColor.withOpacity(0.2)),
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.music_note, size: 48, color: primaryColor),
              SizedBox(height: 12),
              Text(
                'Find pairs of rhyming words!',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '• Tap two words that rhyme\n• Find all rhyming pairs to win\n• Words that sound similar rhyme!\n• 🔊 Tap words to hear pronunciation\n• Get bonus points for speed!',
                  style: TextStyle(color: primaryColor, fontSize: 14),
                  textAlign: TextAlign.left,
                ),
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Icon(Icons.flag, color: accentColor, size: 20),
                      Text(
                        'Pairs: $totalPairs',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (timeLeft > 0)
                    Column(
                      children: [
                        Icon(Icons.timer, color: Colors.orange, size: 20),
                        Text(
                          'Time: ${timeLeft}s',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (timeLeft > 0) {
                _startTimer();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Start Playing!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _startTimer() {
    gameTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        timeLeft--;
      });

      if (timeLeft <= 0) {
        timer.cancel();
        _timeUp();
      }
    });
  }

  void _timeUp() {
    setState(() {
      gameActive = false;
    });
    _endGame();
  }

  void _onWordTapped(RhymeWord word) {
    if (!canSelect || !gameActive || word.isMatched) return;

    HapticFeedback.lightImpact();
    
    // Speak the word when tapped
    _speakWord(word.word);

    if (firstSelectedWord == null) {
      // First word selected
      setState(() {
        firstSelectedWord = word;
        word.isSelected = true;
      });
    } else if (firstSelectedWord == word) {
      // Same word tapped, deselect
      setState(() {
        firstSelectedWord = null;
        word.isSelected = false;
      });
    } else if (secondSelectedWord == null) {
      // Second word selected
      setState(() {
        secondSelectedWord = word;
        word.isSelected = true;
        canSelect = false;
      });

      wrongAttempts++;

      // Check for rhyme after a short delay
      Timer(Duration(milliseconds: 800), () {
        _checkForRhyme();
      });
    }
  }

  void _checkForRhyme() {
    if (firstSelectedWord!.rhymeGroup == secondSelectedWord!.rhymeGroup) {
      // Rhyme found!
      setState(() {
        firstSelectedWord!.isMatched = true;
        secondSelectedWord!.isMatched = true;
        correctMatches++;

        // Enhanced scoring system
        int baseScore = 50;
        int timeBonus = timeLeft > 0
            ? (timeLeft ~/ 5)
            : 0; // More generous time bonus
        int accuracyBonus = wrongAttempts <= 2
            ? 25
            : 0; // Accuracy bonus for few mistakes
        // Use normalized difficulty key already computed in initializer
        int difficultyBonus = _normalizedDifficulty == 'hard'
            ? 30
            : _normalizedDifficulty == 'medium'
            ? 20
            : 10;

        score += baseScore + timeBonus + accuracyBonus + difficultyBonus;
      });

      // Trigger celebration animation
      _celebrationController.forward().then((_) {
        _celebrationController.reset();
      });

      HapticFeedback.mediumImpact();

      // Play success sound with voice effect
      SoundEffectsManager().playSuccessWithVoice();

      if (correctMatches == totalPairs) {
        gameTimer?.cancel();
        _endGame();
      } else {
        _resetSelection();
      }
    } else {
      // No rhyme - reset selection
      HapticFeedback.lightImpact();
      
      // Play wrong sound effect
      SoundEffectsManager().playWrong();

      Timer(Duration(milliseconds: 500), () {
        setState(() {
          firstSelectedWord!.isSelected = false;
          secondSelectedWord!.isSelected = false;
        });
        _resetSelection();
      });
    }
  }

  void _resetSelection() {
    setState(() {
      firstSelectedWord = null;
      secondSelectedWord = null;
      canSelect = true;
    });
  }

  void _endGame() {
    setState(() {
      gameActive = false;
    });

    gameTimer?.cancel();

    // Calculate game statistics
    double accuracyDouble = wrongAttempts > 0
        ? (correctMatches / wrongAttempts) * 100
        : 100;
    int accuracy = accuracyDouble.round();
    int completionTime = DateTime.now().difference(gameStartTime).inSeconds;

    // Call completion callback if provided
    if (widget.onGameComplete != null) {
      widget.onGameComplete!(
        accuracy: accuracy,
        completionTime: completionTime,
        challengeFocus: 'Verbal',
        gameName: 'Rhyme Time',
        difficulty: _normalizedDifficulty,
      );
    }

    // Auto-advance without showing end screen
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _cardAnimationController.dispose();
    _scoreAnimationController.dispose();
    _celebrationController.dispose();
    gameTimer?.cancel();
    // Stop text-to-speech
    flutterTts.stop();
    // Stop background music when leaving the game
    BackgroundMusicManager().stopMusic();
    super.dispose();
  }

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
            Navigator.of(dialogContext).pop(); // Close dialog
            // Exit session and go to home screen after PIN verification
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/home', (route) => false);
          },
          onCancel: () {
            Navigator.of(
              dialogContext,
            ).pop(); // Just close dialog, stay in game
          },
        );
      },
    );
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
        backgroundColor: const Color(
          0xFFFDFBEF,
        ), // Light creamy yellow background
        body: SafeArea(
          child: Column(
            children: [
              // Header bar - Dark olive green style
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B6F4A), // Dark olive green header
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Score: $score',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Column(
                      children: [
                        const Text(
                          'Rhyme Time - Starter',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Round: $correctMatches/$totalPairs',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A5A3A), // Slightly darker green
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        timeLeft > 0 ? '${timeLeft}s' : 'Get Ready...',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Game area
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: gameStarted ? _buildGameArea() : _buildStartScreen(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStartScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B6F4A), // Dark olive green background
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.music_note, size: 60, color: Colors.white),
              ),
              SizedBox(height: 16),
              Text(
                'Rhyme Time Game',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF5B6F4A), // Dark olive green text
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Find words that rhyme!',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            setState(() {
              gameStarted = true;
            });
            _startGame();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5B6F4A), // Dark olive green button
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 5,
          ),
          child: Text(
            'Start Game',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // ...existing code...

  Widget _buildGameArea() {
    if (!gameActive && correctMatches == totalPairs) {
      return _buildEndScreen();
    }

    if (!gameActive && timeLeft <= 0) {
      return _buildTimeUpScreen();
    }

    return Column(
      children: [
        Text(
          'Tap two words that rhyme together!',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.volume_up_rounded, size: 16, color: Colors.grey[600]),
            SizedBox(width: 4),
            Text(
              'Tap any word to hear its pronunciation',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        SizedBox(height: 30),

        // Enhanced Words Grid
        Expanded(
          child: Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 24,
              runSpacing: 24,
              children: List.generate(currentWords.length, (index) {
                return _buildWordCard(currentWords[index]);
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWordCard(RhymeWord word) {
    Color cardColor;
    if (word.isMatched) {
      cardColor = const Color(0xFF8FBC8F); // Light green for matched
    } else if (word.isSelected) {
      cardColor = const Color(0xFFFFD700); // Bright yellow for selected
    } else {
      cardColor = const Color(0xFF5B6F4A); // Dark olive green for normal
    }

    return GestureDetector(
      onTap: () => _onWordTapped(word),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 120,
        height: 70,
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: word.isMatched
                ? Colors.green.shade700
                : word.isSelected
                ? Colors.amber.shade700
                : Colors.white,
            width: word.isMatched || word.isSelected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(word.isSelected ? 0.25 : 0.12),
              blurRadius: word.isSelected ? 12 : 6,
              offset: Offset(0, word.isSelected ? 6 : 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                word.word,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: word.isMatched
                      ? Colors.white
                      : word.isSelected
                      ? Colors.black
                      : Colors.white,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 2),
              Icon(
                Icons.volume_up_rounded,
                size: 16,
                color: (word.isMatched
                        ? Colors.white
                        : word.isSelected
                        ? Colors.black
                        : Colors.white)
                    .withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // ...existing code...

  Widget _buildEndScreen() {
    double accuracyDouble = wrongAttempts > 0
        ? (correctMatches / wrongAttempts) * 100
        : 100;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.celebration, size: 80, color: primaryColor),
        SizedBox(height: 20),
        Text(
          'Fantastic Rhyming!',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        SizedBox(height: 20),
        Text(
          'Final Score: $score',
          style: TextStyle(fontSize: 24, color: primaryColor),
        ),
        Text(
          'All $totalPairs pairs found!',
          style: TextStyle(fontSize: 20, color: primaryColor),
        ),
        Text(
          'Accuracy: ${accuracyDouble.toStringAsFixed(1)}%',
          style: TextStyle(fontSize: 20, color: primaryColor),
        ),
        SizedBox(height: 40),
        ElevatedButton(
          onPressed: () {
            _initializeGame();
            setState(() {
              gameStarted = false;
            });
          },
          child: Text('Play Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            widget.onGameComplete != null ? 'Next Game' : 'Back to Menu',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: primaryColor,
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeUpScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.timer_off, size: 80, color: primaryColor),
        SizedBox(height: 20),
        Text(
          'Time\'s Up!',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        SizedBox(height: 20),
        Text(
          'Score: $score',
          style: TextStyle(fontSize: 24, color: primaryColor),
        ),
        Text(
          'Pairs found: $correctMatches/$totalPairs',
          style: TextStyle(fontSize: 20, color: primaryColor),
        ),
        SizedBox(height: 40),
        ElevatedButton(
          onPressed: () {
            _initializeGame();
            setState(() {
              gameStarted = false;
            });
          },
          child: Text('Try Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            widget.onGameComplete != null ? 'Next Game' : 'Back to Menu',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: primaryColor,
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

class _TeacherPinDialog extends StatefulWidget {
  final VoidCallback onPinVerified;
  final VoidCallback? onCancel;

  const _TeacherPinDialog({required this.onPinVerified, this.onCancel});

  @override
  State<_TeacherPinDialog> createState() => _TeacherPinDialogState();
}

class _TeacherPinDialogState extends State<_TeacherPinDialog> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _verifyPin() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final pin = _pinController.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        _error = 'Not logged in.';
        _isLoading = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(user.uid)
          .get();
      final savedPin = doc.data()?['pin'];

      if (savedPin == null) {
        setState(() {
          _error = 'No PIN set. Please create one.';
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
        _error = 'Failed to check PIN.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400, // Fixed width to prevent stretching
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Green header bar with shield icon and title
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12), // Reduced from 16
              decoration: const BoxDecoration(
                color: Color(0xFF5B6F4A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.shield,
                    color: Colors.white,
                    size: 20,
                  ), // Reduced from 24
                  const SizedBox(width: 8),
                  const Text(
                    'Teacher PIN Required',
                    style: TextStyle(
                      fontSize: 16, // Reduced from 18
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Content area
            Padding(
              padding: const EdgeInsets.all(16), // Reduced from 20
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter your 6-digit PIN to exit the session and access teacher features.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                    ), // Reduced from 14
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16), // Reduced from 20
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18, // Reduced from 20
                      letterSpacing: 6,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '••••••',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        letterSpacing: 6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: const Color(0xFF5B6F4A),
                          width: 2,
                        ),
                      ),
                      errorText: _error,
                      errorStyle: const TextStyle(
                        fontSize: 11,
                      ), // Reduced from 12
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, // Reduced from 16
                        vertical: 10, // Reduced from 12
                      ),
                    ),
                    onSubmitted: (_) => _verifyPin(),
                  ),
                  const SizedBox(height: 16), // Reduced from 20
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            if (widget.onCancel != null) {
                              widget.onCancel!();
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 26, // Mas malaki para tablet
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 24, // Mas malaking font
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24), // Mas malawak na pagitan
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyPin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5B6F4A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 26, // Mas malaki para tablet
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 32, // Mas malaking spinner
                                  width: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Verify',
                                  style: TextStyle(
                                    fontSize: 24, // Mas malaking font
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
