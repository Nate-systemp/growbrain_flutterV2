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
      {'butter': 'utter', 'mutter': 'utter', 'flutter': 'utter', 'clutter': 'utter'},
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
      {'bought': 'ought', 'thought': 'ought', 'caught': 'ought', 'fought': 'ought'},
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
        backgroundColor: backgroundColor,
        title: Text(
          'Rhyme Time Instructions', 
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
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
              Icon(
                Icons.music_note,
                size: 48,
                color: primaryColor,
              ),
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
                  '• Tap two words that rhyme\n• Find all rhyming pairs to win\n• Words that sound similar rhyme!\n• Get bonus points for speed!',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 14,
                  ),
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
        int timeBonus = timeLeft > 0 ? (timeLeft ~/ 5) : 0; // More generous time bonus
        int accuracyBonus = wrongAttempts <= 2 ? 25 : 0; // Accuracy bonus for few mistakes
        int difficultyBonus = widget.difficulty == 'hard' ? 30 : 
                             widget.difficulty == 'medium' ? 20 : 10;
        
        score += baseScore + timeBonus + accuracyBonus + difficultyBonus;
      });
      
      // Trigger celebration animation
      _celebrationController.forward().then((_) {
        _celebrationController.reset();
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
    _cardAnimationController.dispose();
    _scoreAnimationController.dispose();
    _celebrationController.dispose();
    gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Rhyme Time - ${widget.difficulty}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header with Stats
            _buildHeader(),
            SizedBox(height: 20),
            
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor,
            primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(
            icon: Icons.star,
            label: 'Score',
            value: score.toString(),
            color: accentColor,
          ),
          _buildStatItem(
            icon: Icons.check_circle,
            label: 'Pairs',
            value: '$correctMatches/$totalPairs',
            color: Colors.white,
          ),
          if (timeLeft > 0)
            _buildStatItem(
              icon: Icons.timer,
              label: 'Time',
              value: '${timeLeft}s',
              color: timeLeft <= 10 ? Colors.red[300]! : Colors.white,
            ),
          _buildStatItem(
            icon: Icons.error_outline,
            label: 'Attempts',
            value: wrongAttempts.toString(),
            color: Colors.white70,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.8),
          ),
        ),
      ],
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
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                Icons.music_note,
                size: 80,
                color: primaryColor,
              ),
              SizedBox(height: 16),
              Text(
                'Rhyme Time Game',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Find words that rhyme!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Difficulty: ${widget.difficulty}',
                style: TextStyle(
                  fontSize: 14,
                  color: primaryColor.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Find $totalPairs rhyming pairs',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
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
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 5,
          ),
          child: Text(
            'Start Game',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
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
      child: AnimatedBuilder(
        animation: _cardAnimationController,
        builder: (context, child) {
          return Transform.scale(
            scale: word.isSelected ? 1.05 : 1.0,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: word.isSelected ? accentColor : Colors.transparent,
                  width: word.isSelected ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: word.isSelected ? accentColor.withOpacity(0.3) : Colors.black.withOpacity(0.1),
                    blurRadius: word.isSelected ? 8 : 4,
                    offset: Offset(0, word.isSelected ? 4 : 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  word.word,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: word.isMatched ? Colors.white : primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
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
          color: primaryColor,
        ),
        SizedBox(height: 20),
        Text(
          'Fantastic Rhyming!',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primaryColor),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.onGameComplete != null ? 'Next Game' : 'Back to Menu'),
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: primaryColor,
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
          color: primaryColor,
        ),
        SizedBox(height: 20),
        Text(
          'Time\'s Up!',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primaryColor),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.onGameComplete != null ? 'Next Game' : 'Back to Menu'),
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: primaryColor,
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
