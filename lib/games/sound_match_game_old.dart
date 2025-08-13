import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';

class SoundMatchGame extends StatefulWidget {
  final String difficulty;
  final Function({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })? onGameComplete;

  const SoundMatchGame({
    Key? key,
    required this.difficulty,
    this.onGameComplete,
  }) : super(key: key);

  @override
  _SoundMatchGameState createState() => _SoundMatchGameState();
}

class SoundCard {
  final int id;
  final String soundName;
  final String displayText;
  final IconData icon;
  bool isFlipped;
  bool isMatched;
  
  SoundCard({
    required this.id,
    required this.soundName,
    required this.displayText,
    required this.icon,
    this.isFlipped = false,
    this.isMatched = false,
  });
}

class _SoundMatchGameState extends State<SoundMatchGame>
    with TickerProviderStateMixin {
  List<SoundCard> cards = [];
  SoundCard? firstFlippedCard;
  SoundCard? secondFlippedCard;
  bool canTap = true;
  int score = 0;
  int attempts = 0;
  int matchesFound = 0;
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
  
  // Sound categories with emojis and descriptions
  final List<Map<String, dynamic>> sounds = [
    {'name': 'dog', 'text': 'Dog Bark', 'icon': Icons.pets},
    {'name': 'cat', 'text': 'Cat Meow', 'icon': Icons.pets_outlined},
    {'name': 'bird', 'text': 'Bird Tweet', 'icon': Icons.flutter_dash},
    {'name': 'cow', 'text': 'Cow Moo', 'icon': Icons.agriculture},
    {'name': 'piano', 'text': 'Piano Note', 'icon': Icons.piano},
    {'name': 'guitar', 'text': 'Guitar Strum', 'icon': Icons.music_note},
    {'name': 'drum', 'text': 'Drum Beat', 'icon': Icons.album},
    {'name': 'bell', 'text': 'Bell Ring', 'icon': Icons.notifications},
    {'name': 'rain', 'text': 'Rain Drop', 'icon': Icons.water_drop},
    {'name': 'wind', 'text': 'Wind Blow', 'icon': Icons.air},
    {'name': 'car', 'text': 'Car Horn', 'icon': Icons.directions_car},
    {'name': 'phone', 'text': 'Phone Ring', 'icon': Icons.phone},
    {'name': 'clock', 'text': 'Clock Tick', 'icon': Icons.access_time},
    {'name': 'water', 'text': 'Water Flow', 'icon': Icons.waves},
    {'name': 'fire', 'text': 'Fire Crackle', 'icon': Icons.local_fire_department},
    {'name': 'thunder', 'text': 'Thunder Boom', 'icon': Icons.flash_on},
  ];
  
  // Attention category theme colors
  final Color primaryColor = Color(0xFF5B6F4A); // Dark green
  final Color backgroundColor = Color(0xFFF5F5DC); // Beige/cream
  final Color accentColor = Color(0xFFFFD740); // Golden yellow
  final Color cardBackColor = Color(0xFFF5F5DC); // Cream background
  final Color cardFlippedColor = Color(0xFFFFD740); // Golden yellow for flipped
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
        totalPairs = 4;
        timeLeft = 0; // No timer for easy
        break;
      case 'medium':
        totalPairs = 6;
        timeLeft = 180; // 3 minutes
        break;
      case 'hard':
        totalPairs = 8;
        timeLeft = 120; // 2 minutes
        break;
      default:
        totalPairs = 4;
        timeLeft = 0;
    }
    
    _setupCards();
  }

  void _setupCards() {
    cards.clear();
    
    // Select random sounds
    List<Map<String, dynamic>> selectedSounds = List.from(sounds);
    selectedSounds.shuffle();
    selectedSounds = selectedSounds.take(totalPairs).toList();
    
    int cardId = 0;
    // Create pairs
    for (var sound in selectedSounds) {
      // First card of pair
      cards.add(SoundCard(
        id: cardId++,
        soundName: sound['name'],
        displayText: sound['text'],
        icon: sound['icon'],
      ));
      // Second card of pair
      cards.add(SoundCard(
        id: cardId++,
        soundName: sound['name'],
        displayText: sound['text'],
        icon: sound['icon'],
      ));
    }
    
    // Shuffle all cards
    cards.shuffle();
    setState(() {});
  }

  void _startGame() {
    setState(() {
      gameStarted = true;
      gameActive = true;
      gameStartTime = DateTime.now();
      score = 0;
      attempts = 0;
      matchesFound = 0;
      canTap = true;
      
      // Reset all cards
      for (var card in cards) {
        card.isFlipped = false;
        card.isMatched = false;
      }
      
      firstFlippedCard = null;
      secondFlippedCard = null;
    });
    
    _showInstructions();
  }

  void _showInstructions() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFFF8F9FA),
        title: Text('Sound Match Instructions', style: TextStyle(color: Color(0xFF2C3E50))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Find matching sound pairs!',
              style: TextStyle(color: Color(0xFF2C3E50), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              '• Tap cards to flip and hear sounds\n• Remember the sounds and find pairs\n• Match all pairs to win!',
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

  void _playSound(String soundName, String displayText) {
    // Simulate sound playing with haptic feedback
    HapticFeedback.lightImpact();
    
    // Show sound feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔊 $displayText'),
          duration: Duration(milliseconds: 800),
          backgroundColor: Color(0xFF90CAF9),
        ),
      );
    }
  }

  void _onCardTapped(SoundCard card) {
    if (!canTap || !gameActive || card.isMatched || card.isFlipped) return;
    
    setState(() {
      card.isFlipped = true;
    });
    
    _playSound(card.soundName, card.displayText);
    
    if (firstFlippedCard == null) {
      // First card flipped
      firstFlippedCard = card;
    } else if (secondFlippedCard == null && card != firstFlippedCard) {
      // Second card flipped
      secondFlippedCard = card;
      canTap = false;
      attempts++;
      
      // Check for match after a short delay
      Timer(Duration(milliseconds: 1500), () {
        _checkForMatch();
      });
    }
  }

  void _checkForMatch() {
    if (firstFlippedCard!.soundName == secondFlippedCard!.soundName) {
      // Match found!
      setState(() {
        firstFlippedCard!.isMatched = true;
        secondFlippedCard!.isMatched = true;
        matchesFound++;
        score += (timeLeft > 0 ? timeLeft ~/ 10 + 10 : 10); // Bonus for remaining time
      });
      
      HapticFeedback.mediumImpact();
      
      if (matchesFound == totalPairs) {
        gameTimer?.cancel();
        _endGame();
      } else {
        _resetFlippedCards();
      }
    } else {
      // No match - flip cards back
      HapticFeedback.lightImpact();
      
      Timer(Duration(milliseconds: 1000), () {
        setState(() {
          firstFlippedCard!.isFlipped = false;
          secondFlippedCard!.isFlipped = false;
        });
        _resetFlippedCards();
      });
    }
  }

  void _resetFlippedCards() {
    setState(() {
      firstFlippedCard = null;
      secondFlippedCard = null;
      canTap = true;
    });
  }

  void _endGame() {
    setState(() {
      gameActive = false;
    });
    
    gameTimer?.cancel();
    
    // Calculate game statistics
    double accuracyDouble = attempts > 0 ? (matchesFound / attempts) * 100 : 0;
    int accuracy = accuracyDouble.round();
    int completionTime = DateTime.now().difference(gameStartTime).inSeconds;
    
    // Call completion callback if provided
    if (widget.onGameComplete != null) {
      widget.onGameComplete!(
        accuracy: accuracy,
        completionTime: completionTime,
        challengeFocus: 'Verbal',
        gameName: 'Sound Match',
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
          'Sound Match - ${widget.difficulty}',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 50, // Compact header
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Compact Header with Stats
            _buildCompactHeader(),
            
            // Game Area
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: gameStarted ? _buildCompactGameArea() : _buildCompactStartScreen(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCompactStat(Icons.star, score.toString(), 'Score'),
          _buildCompactStat(Icons.check_circle, '$matchesFound/$totalPairs', 'Pairs'),
          if (timeLeft > 0)
            _buildCompactStat(
              Icons.timer, 
              '${timeLeft}s', 
              'Time',
              color: timeLeft <= 10 ? Colors.red[300]! : Colors.white,
            ),
          _buildCompactStat(Icons.touch_app, attempts.toString(), 'Tries'),
        ],
      ),
    );
  }

  Widget _buildCompactStat(IconData icon, String value, String label, {Color? color}) {
    final textColor = color ?? Colors.white;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: textColor, size: 16),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: textColor.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStartScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                Icons.volume_up,
                size: 60,
                color: primaryColor,
              ),
              SizedBox(height: 12),
              Text(
                'Sound Match',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Match sounds that sound alike!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Difficulty: ${widget.difficulty} • $totalPairs pairs',
                style: TextStyle(
                  fontSize: 12,
                  color: primaryColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24),
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
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            elevation: 4,
          ),
          child: Text(
            'Start Game',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactGameArea() {
    if (!gameActive && matchesFound == totalPairs) {
      return _buildCompactEndScreen();
    }
    
    if (!gameActive && timeLeft <= 0) {
      return _buildCompactTimeUpScreen();
    }
    
    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getGridColumns(),
        childAspectRatio: 1.1, // Slightly taller for compact cards
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        return _buildCompactCard(cards[index]);
      },
    );
  }

  int _getGridColumns() {
    // Optimize grid layout based on total pairs
    if (totalPairs <= 4) return 4; // 2x4 grid for easy
    if (totalPairs <= 6) return 4; // 3x4 grid for medium  
    return 4; // 4x4 grid for hard
  }

  Widget _buildCompactCard(SoundCard card) {
    Color cardColor;
    if (card.isMatched) {
      cardColor = matchedColor;
    } else if (card.isFlipped) {
      cardColor = cardFlippedColor;
    } else {
      cardColor = cardBackColor;
    }

    return GestureDetector(
      onTap: () => _onCardTapped(card),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: card.isFlipped ? accentColor : primaryColor.withOpacity(0.3),
            width: card.isFlipped ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              card.isFlipped || card.isMatched ? card.icon : Icons.music_note,
              size: 24,
              color: card.isMatched ? Colors.white : 
                     card.isFlipped ? primaryColor : Colors.grey[400],
            ),
            SizedBox(height: 4),
            if (card.isFlipped || card.isMatched)
              Text(
                card.displayText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: card.isMatched ? Colors.white : primaryColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactEndScreen() {
    final accuracy = attempts > 0 ? ((matchesFound / attempts) * 100).round() : 100;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                Icons.celebration,
                size: 50,
                color: primaryColor,
              ),
              SizedBox(height: 12),
              Text(
                'Great Job!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Score: $score',
                style: TextStyle(fontSize: 16, color: primaryColor),
              ),
              Text(
                'Accuracy: $accuracy%',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () {
                _initializeGame();
                setState(() {
                  gameStarted = false;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text('Play Again', style: TextStyle(fontSize: 14)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: primaryColor,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text('Back to Menu', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactTimeUpScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                Icons.timer_off,
                size: 50,
                color: primaryColor,
              ),
              SizedBox(height: 12),
              Text(
                'Time\'s Up!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Score: $score',
                style: TextStyle(fontSize: 16, color: primaryColor),
              ),
              Text(
                'Matches: $matchesFound/$totalPairs',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () {
                _initializeGame();
                setState(() {
                  gameStarted = false;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text('Try Again', style: TextStyle(fontSize: 14)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: primaryColor,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text('Back to Menu', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ],
    );
  }
}
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.headphones,
          size: 80,
          color: Color(0xFF90CAF9),
        ),
        SizedBox(height: 20),
        Text(
          'Sound Match',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 20),
        Text(
          'Difficulty: ${widget.difficulty}',
          style: TextStyle(fontSize: 24, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 20),
        Text(
          'Find $totalPairs matching sound pairs',
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
    if (!gameActive && matchesFound == totalPairs) {
      return _buildEndScreen();
    }
    
    if (!gameActive && timeLeft <= 0) {
      return _buildTimeUpScreen();
    }
    
    int crossAxisCount = totalPairs <= 4 ? 3 : 4;
    
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        return _buildCard(cards[index]);
      },
    );
  }

  Widget _buildCard(SoundCard card) {
    Color cardColor;
    if (card.isMatched) {
      cardColor = matchedColor;
    } else if (card.isFlipped) {
      cardColor = cardFlippedColor;
    } else {
      cardColor = cardBackColor;
    }
    
    return GestureDetector(
      onTap: () => _onCardTapped(card),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              card.isFlipped || card.isMatched ? card.icon : Icons.volume_up,
              size: 40,
              color: card.isMatched ? Colors.white : Color(0xFF2C3E50),
            ),
            SizedBox(height: 8),
            Text(
              card.isFlipped || card.isMatched ? card.displayText : '?',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: card.isMatched ? Colors.white : Color(0xFF2C3E50),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndScreen() {
    double accuracyDouble = attempts > 0 ? (matchesFound / attempts) * 100 : 0;
    
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
          'Excellent Memory!',
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
            backgroundColor: Color(0xFF90CAF9),
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
          'Matches found: $matchesFound/$totalPairs',
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
            backgroundColor: Color(0xFF90CAF9),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
