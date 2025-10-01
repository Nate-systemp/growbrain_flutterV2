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
  final Color primaryColor = Color.fromARGB(255, 74, 97, 111); // Forest green
  final Color accentColor = Color(0xFFFFD740); // Golden yellow
  final Color wordSectionColor = Color.fromARGB(255, 74, 97, 111); // Lighter green
  final Color imageSectionColor = Color.fromARGB(255, 74, 97, 111); // Medium green
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
  
  if (timeLeft > 0) {
    _startTimer();
  }
  
  await _showGoOverlay();
}
 void _startGame() {
  setState(() {
    showingCountdown = true;
    countdownNumber = 3;
  });
  _showCountdown();
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
  _goController.dispose();  // ADD THIS LINE
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

 @override
Widget build(BuildContext context) {
  int elapsedSeconds = gameStarted ? DateTime.now().difference(gameStartTime).inSeconds : 0;
  
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
            // Main content
            Positioned.fill(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: showingCountdown 
                    ? _buildCountdownScreen() 
                    : (gameStarted ? _buildGameArea() : _buildStartScreen()),
                ),
              ),
            ),
            
            // HUD overlays - Time and Pairs
            if (gameStarted) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 104),
                  child: _infoCircle(label: 'Time', value: '${elapsedSeconds}s', circleSize: 104, valueFontSize: 30, labelFontSize: 26),
                ),
              ),
              
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 104),
                  child: _infoCircle(label: 'Pairs', value: '$correctMatches/$totalPairs', circleSize: 104, valueFontSize: 30, labelFontSize: 26),
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
                              const Text('Get Ready!', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 4)])),
                              const SizedBox(height: 16),
                              Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [accentColor, Colors.white],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(color: primaryColor.withOpacity(0.40), offset: const Offset(0, 8), blurRadius: 20, spreadRadius: 4),
                                    BoxShadow(color: Colors.white.withOpacity(0.3), offset: const Offset(0, -4), blurRadius: 10),
                                  ],
                                ),
                                child: Center(child: Text('GO!', style: TextStyle(color: primaryColor, fontSize: 54, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.white.withOpacity(0.5), offset: Offset(0, 0), blurRadius: 10)]))),
                              ),
                            ],
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
              'Picture Words',
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
                Icons.menu_book,
                size: isTablet ? 56 : 48,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Match words with pictures!',
              style: TextStyle(
                color: primaryColor,
                fontSize: isTablet ? 22 : 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap a word from the left, then tap its matching picture on the right. Match all pairs to win!',
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

  Widget _buildGameArea() {
    if (!gameActive && correctMatches == totalPairs) {
      return _buildCompletionScreen();
    }

    if (!gameActive && timeLeft <= 0) {
      return _buildTimeUpScreen();
    }

    return Column(
      children: [
                
        SizedBox(height: 30),

        // Game Layout - Two Sections
        Expanded(
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Left Section - Words
                Container(
                  width: 280,
                  margin: EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5D98B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFD4B068),
                      width: 0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 0,
                        offset: Offset(20, 15),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // WORDS header
                      Container(
                        
                        padding: EdgeInsets.symmetric(vertical: 15),
                        child: Center(
                          child: Text(
                            'Words',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF4A5568),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(30, 10, 30, 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              for (int i = 0; i < wordList.length; i++)
                                _buildWordCard(i),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Right Section - Images
                Container(
                  width: 280,
                  margin: EdgeInsets.only(left: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8D4F0),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFC8A8D8),
                      width: 0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 0,
                        offset: Offset(20, 15),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // PICTURES header
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Center(
                          child: Text(
                            'Pictures',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF4A5568),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(30, 10, 30, 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              for (int i = 0; i < imageList.length; i++)
                                _buildImageCard(i),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        SizedBox(height: 30),
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

    // Adjust padding based on difficulty
    double verticalPadding = totalPairs <= 4 ? 24 : (totalPairs <= 6 ? 18 : 14);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 2, horizontal: 6),
      child: GestureDetector(
        onTap: () => _onWordTapped(index),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          padding: EdgeInsets.symmetric(horizontal: 30, vertical: verticalPadding),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 0,
                offset: Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              word.toUpperCase(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isMatched || isSelected
                    ? Colors.white
                    : const Color(0xFF5B6F4A), // Dark olive green text
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
    if (isMatched) {
      cardBgColor = const Color(0xFF8FBC8F); // Light green for matched
    } else if (isSelected) {
      cardBgColor = const Color(
        0xFFD4AF37,
      ); // Muted gold for selected instead of bright yellow
    } else {
      cardBgColor = Colors.white; // White for unselected
    }

    // Adjust padding based on difficulty
    double verticalPadding = totalPairs <= 4 ? 14 : (totalPairs <= 6 ? 10 : 8);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 2, horizontal: 6),
      child: GestureDetector(
        onTap: () => _onImageTapped(index),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          padding: EdgeInsets.symmetric(horizontal: 30, vertical: verticalPadding),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 0,
                offset: Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Center(
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
    int accuracy = accuracyDouble.round();

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
                boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.30), blurRadius: 14, offset: const Offset(0, 6))],
              ),
              child: const Icon(Icons.menu_book, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 16),
            Text('Amazing! 🌟', style: TextStyle(color: primaryColor, fontSize: 26, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatRow(Icons.favorite_rounded, 'Pairs', '$correctMatches/$totalPairs'),
              const SizedBox(height: 12),
              _buildStatRow(Icons.flash_on, 'Attempts', '$wrongAttempts'),
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

  Widget _buildTimeUpScreen() {
    // Schedule dialog to show after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showGameOverDialog(false);
    });
    return Container(); // Return empty container since dialog handles the UI
  }
Widget _buildCountdownScreen() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Get Ready!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 4)])),
        const SizedBox(height: 40),
        Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [accentColor, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: primaryColor.withOpacity(0.5), blurRadius: 30, spreadRadius: 5),
              BoxShadow(color: Colors.white.withOpacity(0.3), blurRadius: 15, spreadRadius: 2),
            ],
          ),
          child: Center(child: Text('$countdownNumber', style: TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: primaryColor, shadows: [Shadow(color: Colors.white.withOpacity(0.5), offset: Offset(0, 0), blurRadius: 10)]))),
        ),
        const SizedBox(height: 40),
        Text('The game will start soon...', style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500, shadows: [Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 2)])),
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
