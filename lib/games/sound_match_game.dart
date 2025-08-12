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

class _SoundMatchGameState extends State<SoundMatchGame> {
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
  
  // Soft, accessible colors for children with cognitive impairments
  final Color cardBackColor = Color(0xFF90CAF9); // Soft blue
  final Color cardFlippedColor = Color(0xFFFFF176); // Soft yellow
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
    gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA), // Soft light background
      appBar: AppBar(
        title: Text('Sound Match - ${widget.difficulty}'),
        backgroundColor: Color(0xFF90CAF9), // Soft blue
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
                      Text('Attempts: $attempts', style: TextStyle(fontSize: 14, color: Color(0xFF2C3E50))),
                    ],
                  ),
                  Text('Matches: $matchesFound/$totalPairs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
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
