import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';

class PictureWordsGame extends StatefulWidget {
  final String difficulty;
  final Function({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })? onGameComplete;

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

class _PictureWordsGameState extends State<PictureWordsGame> {
  List<WordPictureItem> gameItems = [];
  List<String> wordList = [];
  List<String> imageList = [];
  int? selectedWordIndex;
  int? selectedImageIndex;
  int score = 0;
  int correctMatches = 0;
  int wrongAttempts = 0;
  int totalPairs = 0;
  bool gameStarted = false;
  bool gameActive = false;
  bool canSelect = true;
  late DateTime gameStartTime;
  Timer? gameTimer;
  int timeLeft = 0;
  
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
  
  // Soft, accessible colors for children with cognitive impairments
  final Color backgroundColor = Color(0xFFF8F9FA);
  final Color wordSectionColor = Color(0xFFE1F5FE); // Light blue
  final Color imageSectionColor = Color(0xFFF3E5F5); // Light purple
  final Color selectedColor = Color(0xFFFFF176); // Soft yellow
  final Color matchedColor = Color(0xFF81C784); // Soft green
  final Color cardColor = Color(0xFFFFFFFF); // White

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  void _initializeGame() {
    // Set difficulty parameters
    switch (widget.difficulty.toLowerCase()) {
      case 'easy':
        totalPairs = 4; // 4 pairs
        timeLeft = 0; // No timer for easy
        break;
      case 'medium':
        totalPairs = 6; // 6 pairs
        timeLeft = 150; // 2.5 minutes
        break;
      case 'hard':
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
    
    String difficultyKey = widget.difficulty.toLowerCase();
    List<Map<String, String>> availablePairs = wordImagePairs[difficultyKey] ?? wordImagePairs['easy']!;
    
    // Select random pairs
    List<Map<String, String>> selectedPairs = List.from(availablePairs);
    selectedPairs.shuffle();
    selectedPairs = selectedPairs.take(totalPairs).toList();
    
    // Create game items and separate lists
    for (int i = 0; i < selectedPairs.length; i++) {
      var pair = selectedPairs[i];
      gameItems.add(WordPictureItem(
        word: pair['word']!,
        imagePath: pair['image']!,
        id: i,
      ));
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
        title: Text('Picture Words Instructions', style: TextStyle(color: Color(0xFF2C3E50))),
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
                style: TextStyle(color: Color(0xFFE57373), fontWeight: FontWeight.bold),
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
            child: Text('Start Playing!', style: TextStyle(color: Color(0xFF81C784))),
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
    WordPictureItem? item = gameItems.firstWhere((item) => item.word == word && !item.isMatched);
    
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
    WordPictureItem? item = gameItems.firstWhere((item) => item.imagePath == image && !item.isMatched);
    
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
    WordPictureItem? wordItem = gameItems.firstWhere((item) => item.word == selectedWord);
    WordPictureItem? imageItem = gameItems.firstWhere((item) => item.imagePath == selectedImage);
    
    if (wordItem.id == imageItem.id) {
      // Match found!
      setState(() {
        wordItem.isMatched = true;
        imageItem.isMatched = true;
        correctMatches++;
        score += (timeLeft > 0 ? timeLeft ~/ 10 + 15 : 15); // Bonus for remaining time
      });
      
      HapticFeedback.mediumImpact();
      
      if (correctMatches == totalPairs) {
        gameTimer?.cancel();
        _endGame();
      } else {
        _resetSelection();
      }
    } else {
      // No match - reset selection
      HapticFeedback.lightImpact();
      
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
    double accuracyDouble = wrongAttempts > 0 ? (correctMatches / wrongAttempts) * 100 : 100;
    int accuracy = accuracyDouble.round();
    int completionTime = DateTime.now().difference(gameStartTime).inSeconds;
    
    // Call completion callback if provided
    if (widget.onGameComplete != null) {
      widget.onGameComplete!(
        accuracy: accuracy,
        completionTime: completionTime,
        challengeFocus: 'Verbal',
        gameName: 'Picture Words',
        difficulty: widget.difficulty,
      );
    }
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Picture Words - ${widget.difficulty}'),
        backgroundColor: Color(0xFFCE93D8), // Soft purple
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Score and Timer Display
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Text('Score: $score', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                      Text('Attempts: $wrongAttempts', style: TextStyle(fontSize: 14, color: Color(0xFF2C3E50))),
                    ],
                  ),
                  Text('Pairs: $correctMatches/$totalPairs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                  if (timeLeft > 0)
                    Column(
                      children: [
                        Text('Time: ${timeLeft}s', style: TextStyle(fontSize: 16, color: timeLeft <= 15 ? Color(0xFFE57373) : Color(0xFF2C3E50), fontWeight: FontWeight.bold)),
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
          Icons.menu_book,
          size: 80,
          color: Color(0xFFCE93D8),
        ),
        SizedBox(height: 20),
        Text(
          'Picture Words',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 20),
        Text(
          'Difficulty: ${widget.difficulty}',
          style: TextStyle(fontSize: 24, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 20),
        Text(
          'Match $totalPairs word-picture pairs',
          style: TextStyle(fontSize: 18, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 40),
        ElevatedButton(
          onPressed: _startGame,
          child: Text('Start Game'),
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
    if (!gameActive && correctMatches == totalPairs) {
      return _buildEndScreen();
    }
    
    if (!gameActive && timeLeft <= 0) {
      return _buildTimeUpScreen();
    }
    
    return Column(
      children: [
        // Instructions
        Container(
          padding: EdgeInsets.all(12),
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Color(0xFFE8F5E8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Tap a word, then tap its matching picture!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        
        // Game Layout - Two Sections
        Expanded(
          child: Row(
            children: [
              // Left Section - Words
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: wordSectionColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'WORDS',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(8),
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
                  margin: EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: imageSectionColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'PICTURES',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(8),
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
      cardBgColor = matchedColor;
    } else if (isSelected) {
      cardBgColor = selectedColor;
    } else {
      cardBgColor = cardColor;
    }
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onTap: () => _onWordTapped(index),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Color(0xFF2C3E50) : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(
              word,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isMatched ? Colors.white : Color(0xFF2C3E50),
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
    WordPictureItem? item = gameItems.firstWhere((item) => item.imagePath == image);
    
    bool isSelected = selectedImageIndex == index;
    bool isMatched = item.isMatched;
    
    Color cardBgColor;
    if (isMatched) {
      cardBgColor = matchedColor;
    } else if (isSelected) {
      cardBgColor = selectedColor;
    } else {
      cardBgColor = cardColor;
    }
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onTap: () => _onImageTapped(index),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Color(0xFF2C3E50) : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(
              image,
              style: TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEndScreen() {
    double accuracyDouble = wrongAttempts > 0 ? (correctMatches / wrongAttempts) * 100 : 100;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.celebration,
          size: 80,
          color: Color(0xFF81C784),
        ),
        SizedBox(height: 20),
        Text(
          'Excellent Matching!',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 20),
        Text(
          'Final Score: $score',
          style: TextStyle(fontSize: 24, color: Color(0xFF2C3E50)),
        ),
        Text(
          'All $totalPairs pairs matched!',
          style: TextStyle(fontSize: 20, color: Color(0xFF2C3E50)),
        ),
        Text(
          'Accuracy: ${accuracyDouble.toStringAsFixed(1)}%',
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
          child: Text('Play Again'),
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

  Widget _buildTimeUpScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.timer_off,
          size: 80,
          color: Color(0xFFE57373),
        ),
        SizedBox(height: 20),
        Text(
          'Time\'s Up!',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 20),
        Text(
          'Score: $score',
          style: TextStyle(fontSize: 24, color: Color(0xFF2C3E50)),
        ),
        Text(
          'Pairs matched: $correctMatches/$totalPairs',
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
          child: Text('Try Again'),
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
