import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';

class RhymeTimeGame extends StatefulWidget {
  final String difficulty;
  final Function({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })? onGameComplete;

  const RhymeTimeGame({
    Key? key,
    required this.difficulty,
    this.onGameComplete,
  }) : super(key: key);

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

class _RhymeTimeGameState extends State<RhymeTimeGame> {
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
  
  // Rhyme groups organized by difficulty
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
    ],
    'medium': [
      {'window': 'indo', 'bingo': 'indo'},
      {'flower': 'ower', 'tower': 'ower', 'power': 'ower'},
      {'happy': 'appy', 'snappy': 'appy'},
      {'chicken': 'icken', 'thicken': 'icken'},
      {'butter': 'utter', 'mutter': 'utter', 'flutter': 'utter'},
      {'apple': 'apple', 'grapple': 'apple'},
      {'paper': 'aper', 'caper': 'aper'},
      {'water': 'ater', 'matter': 'atter'},
    ],
    'hard': [
      {'enough': 'uff', 'rough': 'uff', 'tough': 'uff'},
      {'weight': 'ate', 'straight': 'ate', 'create': 'ate'},
      {'bought': 'ought', 'thought': 'ought', 'caught': 'ought'},
      {'listen': 'isten', 'glisten': 'isten'},
      {'ocean': 'tion', 'motion': 'tion', 'potion': 'tion'},
      {'through': 'ough', 'threw': 'ew'},
      {'heart': 'art', 'part': 'art', 'start': 'art'},
      {'break': 'ake', 'cake': 'ake', 'make': 'ake'},
    ],
  };
  
  Random random = Random();
  
  // Soft, accessible colors for children with cognitive impairments
  final Color unselectedColor = Color(0xFFF8F9FA); // Very light gray
  final Color selectedColor = Color(0xFFFFF176); // Soft yellow
  final Color matchedColor = Color(0xFF81C784); // Soft green

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  void _initializeGame() {
    // Set difficulty parameters
    switch (widget.difficulty.toLowerCase()) {
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
    
    _setupWords();
  }

  void _setupWords() {
    currentWords.clear();
    
    String difficultyKey = widget.difficulty.toLowerCase();
    List<Map<String, String>> availableGroups = rhymeGroups[difficultyKey] ?? rhymeGroups['easy']!;
    
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
        currentWords.add(RhymeWord(
          word: wordsInGroup[i],
          rhymeGroup: rhymePattern,
        ));
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
        backgroundColor: Color(0xFFF8F9FA),
        title: Text('Rhyme Time Instructions', style: TextStyle(color: Color(0xFF2C3E50))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Find pairs of rhyming words!',
              style: TextStyle(color: Color(0xFF2C3E50), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              '• Tap two words that rhyme\n• Find all rhyming pairs to win\n• Words that sound similar rhyme!',
              style: TextStyle(color: Color(0xFF2C3E50)),
              textAlign: TextAlign.left,
            ),
            SizedBox(height: 8),
            Text(
              'Pairs to find: $totalPairs',
              style: TextStyle(color: Color(0xFF2C3E50), fontWeight: FontWeight.bold),
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

  void _onWordTapped(RhymeWord word) {
    if (!canSelect || !gameActive || word.isMatched) return;
    
    HapticFeedback.lightImpact();
    
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
        score += (timeLeft > 0 ? timeLeft ~/ 10 + 10 : 10); // Bonus for remaining time
      });
      
      HapticFeedback.mediumImpact();
      
      if (correctMatches == totalPairs) {
        gameTimer?.cancel();
        _endGame();
      } else {
        _resetSelection();
      }
    } else {
      // No rhyme - reset selection
      HapticFeedback.lightImpact();
      
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
    double accuracyDouble = wrongAttempts > 0 ? (correctMatches / wrongAttempts) * 100 : 100;
    int accuracy = accuracyDouble.round();
    int completionTime = DateTime.now().difference(gameStartTime).inSeconds;
    
    // Call completion callback if provided
    if (widget.onGameComplete != null) {
      widget.onGameComplete!(
        accuracy: accuracy,
        completionTime: completionTime,
        challengeFocus: 'Verbal',
        gameName: 'Rhyme Time',
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
      backgroundColor: Color(0xFFF8F9FA), // Soft light background
      appBar: AppBar(
        title: Text('Rhyme Time - ${widget.difficulty}'),
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
                        Text('Time: ${timeLeft}s', style: TextStyle(fontSize: 16, color: timeLeft <= 10 ? Color(0xFFE57373) : Color(0xFF2C3E50), fontWeight: FontWeight.bold)),
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
          Icons.music_note,
          size: 80,
          color: Color(0xFFCE93D8),
        ),
        SizedBox(height: 20),
        Text(
          'Rhyme Time',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 20),
        Text(
          'Difficulty: ${widget.difficulty}',
          style: TextStyle(fontSize: 24, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 20),
        Text(
          'Find $totalPairs rhyming pairs',
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
        // Instructions for current round
        Container(
          padding: EdgeInsets.all(16),
          margin: EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Color(0xFFE1F5FE),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Tap two words that rhyme together!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        
        // Words Grid
        Expanded(
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.0,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: currentWords.length,
            itemBuilder: (context, index) {
              return _buildWordCard(currentWords[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWordCard(RhymeWord word) {
    Color cardColor;
    if (word.isMatched) {
      cardColor = matchedColor;
    } else if (word.isSelected) {
      cardColor = selectedColor;
    } else {
      cardColor = unselectedColor;
    }
    
    return GestureDetector(
      onTap: () => _onWordTapped(word),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: word.isSelected ? Color(0xFF2C3E50) : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            word.word,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: word.isMatched ? Colors.white : Color(0xFF2C3E50),
            ),
            textAlign: TextAlign.center,
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
          'Fantastic Rhyming!',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 20),
        Text(
          'Final Score: $score',
          style: TextStyle(fontSize: 24, color: Color(0xFF2C3E50)),
        ),
        Text(
          'All $totalPairs pairs found!',
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
          'Pairs found: $correctMatches/$totalPairs',
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
