import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/background_music_manager.dart';
import '../utils/sound_effects_manager.dart';
import '../utils/difficulty_utils.dart';
import '../teacher_pin_modal.dart';

class PictureWordsGame extends StatefulWidget {
  final String difficulty;
  final Function({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })?
  onGameComplete;

  const PictureWordsGame({
    Key? key,
    required this.difficulty,
    this.onGameComplete,
  }) : super(key: key);

  @override
  _PictureWordsGameState createState() => _PictureWordsGameState();
}

class WordPictureItem {
  final String word;
  final String imagePath;
  final int id;
  bool isMatched;
  bool isSelected;

  WordPictureItem({
    required this.word,
    required this.imagePath,
    required this.id,
    this.isMatched = false,
    this.isSelected = false,
  });
}

class _PictureWordsGameState extends State<PictureWordsGame>
    with TickerProviderStateMixin {
  List<WordPictureItem> gameItems = [];
  List<String> wordList = [];
  List<String> imageList = [];
  int? selectedWordIndex;
  int? selectedImageIndex;
  int score = 0;
  int correctMatches = 0;
  int wrongAttempts = 0;
  int totalPairs = 4;
  int timeLeft = 0;
  Timer? gameTimer;
  bool gameStarted = false;
  bool gameComplete = false;
  DateTime? startTime;
  bool gameActive = false;
  bool canSelect = true;
  late DateTime gameStartTime;
  String _normalizedDifficulty = 'easy';

  // Animation controllers for enhanced UI
  late AnimationController _cardAnimationController;
  late AnimationController _scoreAnimationController;
  late Animation<double> _cardAnimation;
  late Animation<double> _scoreAnimation;

  // Word-image pairs organized by difficulty
  final Map<String, List<Map<String, String>>> wordImagePairs = {
    'easy': [
      {'word': 'cat', 'image': '🐱'},
      {'word': 'dog', 'image': '🐶'},
      {'word': 'car', 'image': '🚗'},
      {'word': 'tree', 'image': '🌳'},
      {'word': 'house', 'image': '🏠'},
      {'word': 'sun', 'image': '☀️'},
      {'word': 'book', 'image': '📖'},
      {'word': 'ball', 'image': '⚽'},
      {'word': 'apple', 'image': '🍎'},
      {'word': 'fish', 'image': '🐠'},
      {'word': 'bird', 'image': '🐦'},
      {'word': 'cake', 'image': '🎂'},
      {'word': 'star', 'image': '⭐'},
      {'word': 'flower', 'image': '🌸'},
      {'word': 'moon', 'image': '🌙'},
    ],
    'medium': [
      {'word': 'elephant', 'image': '🐘'},
      {'word': 'butterfly', 'image': '🦋'},
      {'word': 'guitar', 'image': '🎸'},
      {'word': 'bicycle', 'image': '🚲'},
      {'word': 'airplane', 'image': '✈️'},
      {'word': 'rainbow', 'image': '🌈'},
      {'word': 'computer', 'image': '💻'},
      {'word': 'sandwich', 'image': '🥪'},
      {'word': 'telephone', 'image': '📞'},
      {'word': 'umbrella', 'image': '☂️'},
      {'word': 'mountain', 'image': '⛰️'},
      {'word': 'football', 'image': '🏈'},
      {'word': 'glasses', 'image': '👓'},
      {'word': 'rocket', 'image': '🚀'},
      {'word': 'pizza', 'image': '🍕'},
    ],
    'hard': [
      {'word': 'microscope', 'image': '🔬'},
      {'word': 'stethoscope', 'image': '🩺'},
      {'word': 'helicopter', 'image': '🚁'},
      {'word': 'telescope', 'image': '🔭'},
      {'word': 'ambulance', 'image': '🚑'},
      {'word': 'thermometer', 'image': '🌡️'},
      {'word': 'calculator', 'image': '🧮'},
      {'word': 'lighthouse', 'image': '🗼'},
      {'word': 'construction', 'image': '🚧'},
      {'word': 'refrigerator', 'image': '🧊'},
      {'word': 'grandfather', 'image': '👴'},
      {'word': 'grandmother', 'image': '👵'},
      {'word': 'basketball', 'image': '🏀'},
      {'word': 'skateboard', 'image': '🛹'},
      {'word': 'submarine', 'image': '🚇'},
    ],
  };

  Random random = Random();

  // Attention category theme colors (matching Find Me game)
  final Color backgroundColor = Color(0xFFF5F5DC); // Beige background
  final Color primaryColor = Color(0xFF5B6F4A); // Forest green
  final Color accentColor = Color(0xFFFFD740); // Golden yellow
  final Color wordSectionColor = Color(0xFF6B7F5A); // Lighter green
  final Color imageSectionColor = Color(0xFF7B8F6A); // Medium green
  final Color selectedColor = Color(0xFFFFD740); // Golden yellow
  final Color matchedColor = Color(0xFF81C784); // Success green
  final Color cardColor = Color(0xFFFFFFFF); // White

  @override
  void initState() {
    super.initState();
    // Start background music for this game
    BackgroundMusicManager().startGameMusic('Picture Words');
    _initializeAnimations();
    _initializeGame();
  }

  void _initializeAnimations() {
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scoreAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _cardAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _cardAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _scoreAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _scoreAnimationController,
        curve: Curves.elasticOut,
      ),
    );
  }

  void _initializeGame() {
    // Normalize difficulty
    _normalizedDifficulty = DifficultyUtils.normalizeDifficulty(
      widget.difficulty,
    );
    // Set difficulty parameters
    switch (_normalizedDifficulty) {
      case 'Starter':
        totalPairs = 4; // 4 pairs
        timeLeft = 0; // No timer for Starter
        break;
      case 'Growing':
        totalPairs = 6; // 6 pairs
        timeLeft = 150; // 2.5 minutes
        break;
      case 'Challenged':
        totalPairs = 8; // 8 pairs
        timeLeft = 120; // 2 minutes
        break;
      default:
        totalPairs = 4;
        timeLeft = 0;
    }

    _setupGame();
  }

  void _setupGame() {
    gameItems.clear();
    wordList.clear();
    imageList.clear();

    // Use normalized difficulty key (we stored it in _initializeGame)
    String difficultyKey = _normalizedDifficulty.toLowerCase();
    List<Map<String, String>> availablePairs =
        wordImagePairs[difficultyKey] ?? wordImagePairs['easy']!;

    // Select random pairs
    List<Map<String, String>> selectedPairs = List.from(availablePairs);
    selectedPairs.shuffle();
    selectedPairs = selectedPairs.take(totalPairs).toList();

    // Create game items and separate lists
    for (int i = 0; i < selectedPairs.length; i++) {
      var pair = selectedPairs[i];
      gameItems.add(
        WordPictureItem(word: pair['word']!, imagePath: pair['image']!, id: i),
      );
      wordList.add(pair['word']!);
      imageList.add(pair['image']!);
    }

    // Shuffle the separate lists
    wordList.shuffle();
    imageList.shuffle();

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
      selectedWordIndex = null;
      selectedImageIndex = null;

      // Reset all items
      for (var item in gameItems) {
        item.isMatched = false;
        item.isSelected = false;
      }
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
          'Picture Words Instructions',
          style: TextStyle(color: Color(0xFF2C3E50)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Match words with their pictures!',
              style: TextStyle(color: Color(0xFF2C3E50), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              '• Tap a word from the blue section\n• Then tap its matching picture from the purple section\n• Match all ${totalPairs} pairs to win!',
              style: TextStyle(color: Color(0xFF2C3E50)),
              textAlign: TextAlign.left,
            ),
            if (timeLeft > 0) ...[
              SizedBox(height: 8),
              Text(
                'Time limit: ${timeLeft}s',
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
              if (timeLeft > 0) {
                _startTimer();
              }
            },
            child: Text(
              'Start Playing!',
              style: TextStyle(color: Color(0xFF81C784)),
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

  void _onWordTapped(int index) {
    if (!canSelect || !gameActive) return;

    String word = wordList[index];
    WordPictureItem? item = gameItems.firstWhere(
      (item) => item.word == word && !item.isMatched,
    );

    if (item.isMatched) return;

    HapticFeedback.lightImpact();

    setState(() {
      // Clear previous word selection
      if (selectedWordIndex != null) {
        selectedWordIndex = null;
      }

      selectedWordIndex = index;
    });
  }

  void _onImageTapped(int index) {
    if (!canSelect || !gameActive || selectedWordIndex == null) return;

    String image = imageList[index];
    WordPictureItem? item = gameItems.firstWhere(
      (item) => item.imagePath == image && !item.isMatched,
    );

    if (item.isMatched) return;

    HapticFeedback.lightImpact();

    setState(() {
      selectedImageIndex = index;
      canSelect = false;
    });

    wrongAttempts++;

    // Check for match after a short delay
    Timer(Duration(milliseconds: 800), () {
      _checkForMatch();
    });
  }

  void _checkForMatch() {
    String selectedWord = wordList[selectedWordIndex!];
    String selectedImage = imageList[selectedImageIndex!];

    // Find the items
    WordPictureItem? wordItem = gameItems.firstWhere(
      (item) => item.word == selectedWord,
    );
    WordPictureItem? imageItem = gameItems.firstWhere(
      (item) => item.imagePath == selectedImage,
    );

    if (wordItem.id == imageItem.id) {
      // Match found!
      setState(() {
        wordItem.isMatched = true;
        imageItem.isMatched = true;
        correctMatches++;
        score += (timeLeft > 0
            ? timeLeft ~/ 10 + 15
            : 15); // Bonus for remaining time
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
      // No match - reset selection
      HapticFeedback.lightImpact();

      // Play wrong sound effect
      SoundEffectsManager().playWrong();

      Timer(Duration(milliseconds: 500), () {
        _resetSelection();
      });
    }
  }

  void _resetSelection() {
    setState(() {
      selectedWordIndex = null;
      selectedImageIndex = null;
      canSelect = true;
    });
  }

  void _endGame() {
    setState(() {
      gameActive = false;
    });

    gameTimer?.cancel();

    // Calculate game statistics
    // wrongAttempts actually counts all attempts, not just wrong ones
    double accuracyDouble = wrongAttempts > 0
        ? (correctMatches / wrongAttempts) * 100
        : 0;
    int accuracy = accuracyDouble.round();
    int completionTime = DateTime.now().difference(gameStartTime).inSeconds;

    // Call completion callback if provided
    if (widget.onGameComplete != null) {
      widget.onGameComplete!(
        accuracy: accuracy,
        completionTime: completionTime,
        challengeFocus: 'Verbal',
        gameName: 'Picture Words',
        difficulty: _normalizedDifficulty,
      );
    }

    // Auto-advance without showing end screen
    Navigator.pop(context);
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    _cardAnimationController.dispose();
    _scoreAnimationController.dispose();
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
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/verbalbg.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
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
                            'Picture Words - Starter',
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
                          color: const Color(
                            0xFF4A5A3A,
                          ), // Slightly darker green
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
                    padding: const EdgeInsets.all(16.0),
                    child: gameStarted ? _buildGameArea() : _buildStartScreen(),
                  ),
                ),
              ],
            ),
          ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                      '1/1',
                      style: const TextStyle(
                        fontSize: 16,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                      '$correctMatches',
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
          child: const Icon(Icons.menu_book, size: 60, color: Colors.white),
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
            'Match carefully!',
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
          child: const Text(
            'Match words with pictures!',
            style: TextStyle(
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
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            elevation: 4,
          ),
          onPressed: () {
            setState(() {
              gameStarted = true;
            });
            _startGame();
          },
          child: const Text(
            'Start !',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildGameArea() {
    if (!gameActive && correctMatches == totalPairs) {
      return _buildCompletionScreen();
    }

    if (!gameActive && timeLeft <= 0) {
      return _buildTimeUpScreen();
    }

    return Column(
      children: [
        // Instructions
        Text(
          'Tap a word, then tap its matching picture!',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 30),

        // Game Layout - Two Sections
        Expanded(
          child: Row(
            children: [
              // Left Section - Words
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFF5B6F4A,
                    ), // Dark olive green background
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Improved WORDS header
                      Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFD4AF37,
                          ), // Muted gold instead of bright yellow
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(11),
                            topRight: Radius.circular(11),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 3,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.menu_book,
                              size: 16,
                              color: Colors.black87,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'WORDS',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(6),
                          child: Column(
                            children: [
                              for (int i = 0; i < wordList.length; i++)
                                Expanded(child: _buildWordCard(i)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Right Section - Images
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFF5B6F4A,
                    ), // Dark olive green background
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Improved PICTURES header
                      Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8FBC8F), // Light green header
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(11),
                            topRight: Radius.circular(11),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 3,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'PICTURES',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(6),
                          child: Column(
                            children: [
                              for (int i = 0; i < imageList.length; i++)
                                Expanded(child: _buildImageCard(i)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWordCard(int index) {
    String word = wordList[index];
    WordPictureItem? item = gameItems.firstWhere((item) => item.word == word);

    bool isSelected = selectedWordIndex == index;
    bool isMatched = item.isMatched;

    Color cardBgColor;
    if (isMatched) {
      cardBgColor = const Color(0xFF8FBC8F); // Light green for matched
    } else if (isSelected) {
      cardBgColor = const Color(
        0xFFD4AF37,
      ); // Muted gold for selected instead of bright yellow
    } else {
      cardBgColor = Colors.white; // White for unselected
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onTap: () => _onWordTapped(index),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              word,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isMatched || isSelected
                    ? Colors.white
                    : const Color(0xFF5B6F4A), // Dark olive green text
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageCard(int index) {
    String image = imageList[index];
    WordPictureItem? item = gameItems.firstWhere(
      (item) => item.imagePath == image,
    );

    bool isSelected = selectedImageIndex == index;
    bool isMatched = item.isMatched;

    Color cardBgColor;
    Color borderColor;
    double elevation;

    if (isMatched) {
      cardBgColor = const Color(0xFF8FBC8F); // Light green for matched
      borderColor = const Color(
        0xFFD4AF37,
      ); // Muted gold border instead of bright yellow
      elevation = 8;
    } else if (isSelected) {
      cardBgColor = const Color(
        0xFFD4AF37,
      ); // Muted gold for selected instead of bright yellow
      borderColor = const Color(0xFF5B6F4A); // Dark olive green border
      elevation = 6;
    } else {
      cardBgColor = Colors.white; // White for unselected
      borderColor = const Color(0xFF5B6F4A); // Dark olive green border
      elevation = 3;
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: GestureDetector(
        onTap: () => _onImageTapped(index),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: isSelected || isMatched ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: elevation,
                offset: Offset(0, elevation / 2),
                spreadRadius: isSelected || isMatched ? 1 : 0,
              ),
              if (isSelected || isMatched)
                BoxShadow(
                  color:
                      (isMatched
                              ? const Color(0xFF8FBC8F)
                              : const Color(
                                  0xFFD4AF37,
                                )) // Muted gold instead of bright yellow
                          .withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: isMatched || isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [cardBgColor, cardBgColor.withOpacity(0.8)],
                    )
                  : null,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Enhanced emoji display
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isMatched || isSelected
                          ? Colors.white.withOpacity(0.2)
                          : const Color(0xFFF8F9FA),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      image,
                      style: TextStyle(
                        fontSize: 32,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.2),
                            offset: Offset(1, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isSelected || isMatched) ...[
                    SizedBox(height: 4),
                    Icon(
                      isMatched ? Icons.check_circle : Icons.touch_app,
                      size: 16,
                      color: Colors.white,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionScreen() {
    // Schedule dialog to show after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showGameOverDialog(true);
    });
    return Container(); // Return empty container since dialog handles the UI
  }

  void _resetGame() {
    setState(() {
      score = 0;
      correctMatches = 0;
      wrongAttempts = 0;
      gameStarted = false;
      gameComplete = false;
      gameActive = false;
      selectedWordIndex = null;
      selectedImageIndex = null;
      canSelect = true;
    });

    gameTimer?.cancel();

    // Reset all game items
    for (var item in gameItems) {
      item.isMatched = false;
    }

    _setupGame();
  }

  void _showGameOverDialog(bool isCompletion) {
    final completionTime = DateTime.now().difference(gameStartTime).inSeconds;
    // wrongAttempts actually counts all attempts, not just wrong ones
    final double accuracyDouble = wrongAttempts > 0
        ? (correctMatches / wrongAttempts) * 100
        : 0;

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
                  color: const Color(0xFF5B6F4A),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5B6F4A).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  isCompletion ? Icons.celebration : Icons.timer_off,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isCompletion ? 'Perfect Match! 🎯✨' : 'Time\'s Up! ⏰',
                style: TextStyle(
                  color: const Color(0xFF5B6F4A),
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
                _buildStatRow(
                  Icons.star_rounded,
                  'Final Score',
                  '$score points',
                ),
                const SizedBox(height: 12),
                _buildStatRow(
                  Icons.favorite_rounded,
                  'Pairs Matched',
                  '$correctMatches/$totalPairs',
                ),
                const SizedBox(height: 12),
                _buildStatRow(
                  Icons.track_changes,
                  'Accuracy',
                  '${accuracyDouble.toStringAsFixed(1)}%',
                ),
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
                          backgroundColor: const Color(0xFF5B6F4A),
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
                    Navigator.of(
                      context,
                    ).pop(); // Exit game and return to session screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B6F4A),
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

  Widget _buildTimeUpScreen() {
    // Schedule dialog to show after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showGameOverDialog(false);
    });
    return Container(); // Return empty container since dialog handles the UI
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD740).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF5B6F4A), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: const Color(0xFF5B6F4A),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: const Color(0xFF5B6F4A),
            fontSize: 16,
            fontWeight: FontWeight.bold,
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
        width: 300, // Fixed width to prevent stretching
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
                              vertical: 10,
                            ), // Reduced from 12
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ), // Reduced from 14
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyPin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5B6F4A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ), // Reduced from 12
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 14, // Reduced from 16
                                  width: 14, // Reduced from 16
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Verify',
                                  style: TextStyle(
                                    fontSize: 13, // Reduced from 14
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
