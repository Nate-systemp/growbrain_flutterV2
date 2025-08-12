import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';

class FindMeGame extends StatefulWidget {
  final String difficulty;
  final Future<void> Function({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })? onGameComplete;

  const FindMeGame({Key? key, required this.difficulty, this.onGameComplete}) : super(key: key);

  @override
  _FindMeGameState createState() => _FindMeGameState();
}

class GameCharacter {
  final int id;
  final String name;
  final Color baseColor;
  final String accessory;
  final bool hasScarf;
  final Color scarfColor;
  final bool hasHat;
  final bool hasDifferentEyes;
  
  GameCharacter({
    required this.id,
    required this.name,
    required this.baseColor,
    this.accessory = '',
    this.hasScarf = false,
    this.scarfColor = Colors.transparent,
    this.hasHat = false,
    this.hasDifferentEyes = false,
  });
}

class _FindMeGameState extends State<FindMeGame> with TickerProviderStateMixin {
  int score = 0;
  int round = 1;
  int maxRounds = 10;
  bool gameActive = false;
  bool gameStarted = false;
  bool showingTarget = false;
  bool shuffling = false;
  bool canSelect = false;
  GameCharacter? targetCharacter;
  List<GameCharacter> allCharacters = [];
  List<GameCharacter> shuffledCharacters = [];
  Timer? revealTimer;
  Timer? shuffleTimer;
  AnimationController? shuffleController;
  Random random = Random();
  int characterCount = 6;
  int revealDuration = 3000; // milliseconds
  int shuffleDuration = 2000;
  int correctSelections = 0;
  int wrongSelections = 0;
  DateTime gameStartTime = DateTime.now();
  
  // Soft, accessible colors for children with cognitive impairments
  final List<Color> baseColors = [
    Color(0xFFFFF176), // Soft yellow
    Color(0xFF81C784), // Soft green
    Color(0xFF90CAF9), // Soft blue
    Color(0xFFEF9A9A), // Soft red
    Color(0xFFCE93D8), // Soft purple
    Color(0xFFFFCC80), // Soft orange
  ];
  
  final List<Color> accessoryColors = [
    Color(0xFFEF9A9A), // Soft red
    Color(0xFF90CAF9), // Soft blue
    Color(0xFF81C784), // Soft green
    Color(0xFFCE93D8), // Soft purple
    Color(0xFFFFCC80), // Soft orange
  ];

  @override
  void initState() {
    super.initState();
    shuffleController = AnimationController(
      duration: Duration(milliseconds: shuffleDuration),
      vsync: this,
    );
    _initializeGame();
  }

  void _initializeGame() {
    switch (widget.difficulty) {
      case 'Easy':
        characterCount = 6;
        revealDuration = 3000;
        shuffleDuration = 1500; // Slow shuffle
        maxRounds = 8;
        break;
      case 'Medium':
        characterCount = 10;
        revealDuration = 2500;
        shuffleDuration = 2500; // Moderate shuffle
        maxRounds = 10;
        break;
      case 'Hard':
        characterCount = 16;
        revealDuration = 2000;
        shuffleDuration = 3500; // Fast shuffle
        maxRounds = 12;
        break;
    }
  }

  void _startGame() {
    setState(() {
      gameActive = true;
      gameStarted = true;
      score = 0;
      round = 1;
      correctSelections = 0;
      wrongSelections = 0;
      gameStartTime = DateTime.now();
    });
    _showInstructions();
  }

  void _showInstructions() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFFF8F9FA),
        title: Text('Instructions', style: TextStyle(color: Color(0xFF2C3E50))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Watch carefully! A target character will be shown.',
              style: TextStyle(fontSize: 16, color: Color(0xFF2C3E50)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              'After it hides and all characters shuffle, find and tap the same character!',
              style: TextStyle(fontSize: 16, color: Color(0xFF2C3E50)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              _getDifficultyDescription(),
              style: TextStyle(fontSize: 14, color: Color(0xFF2C3E50), fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _nextRound();
            },
            child: Text('Start', style: TextStyle(color: Color(0xFF81C784))),
          ),
        ],
      ),
    );
  }

  String _getDifficultyDescription() {
    switch (widget.difficulty) {
      case 'Easy':
        return 'Characters will have obvious differences.';
      case 'Medium':
        return 'Characters will have small differences like accessories.';
      case 'Hard':
        return 'Characters will look very similar with tiny differences.';
      default:
        return '';
    }
  }

  void _nextRound() {
    if (round <= maxRounds && gameActive) {
      setState(() {
        showingTarget = false;
        shuffling = false;
        canSelect = false;
      });
      _generateCharacters();
      _revealTarget();
    } else {
      _endGame();
    }
  }

  void _generateCharacters() {
    allCharacters.clear();
    
    // Generate target character
    targetCharacter = _generateTargetCharacter();
    allCharacters.add(targetCharacter!);
    
    // Generate similar decoy characters
    for (int i = 1; i < characterCount; i++) {
      allCharacters.add(_generateSimilarCharacter(i, targetCharacter!));
    }
    
    // Create shuffled list
    shuffledCharacters = List.from(allCharacters);
    shuffledCharacters.shuffle(random);
  }

  GameCharacter _generateTargetCharacter() {
    Color baseColor = baseColors[random.nextInt(baseColors.length)];
    
    switch (widget.difficulty) {
      case 'Easy':
        return GameCharacter(
          id: 0,
          name: _getCharacterType(),
          baseColor: baseColor,
        );
        
      case 'Medium':
        bool hasScarf = random.nextBool();
        return GameCharacter(
          id: 0,
          name: _getCharacterType(),
          baseColor: baseColor,
          hasScarf: hasScarf,
          scarfColor: hasScarf ? accessoryColors[random.nextInt(accessoryColors.length)] : Colors.transparent,
          accessory: !hasScarf ? _getAccessory() : '',
        );
        
      case 'Hard':
        return GameCharacter(
          id: 0,
          name: _getCharacterType(),
          baseColor: baseColor,
          hasScarf: true,
          scarfColor: accessoryColors[random.nextInt(accessoryColors.length)],
          hasHat: random.nextBool(),
          hasDifferentEyes: random.nextBool(),
          accessory: _getAccessory(),
        );
        
      default:
        return GameCharacter(id: 0, name: 'duck', baseColor: baseColor);
    }
  }

  GameCharacter _generateSimilarCharacter(int id, GameCharacter target) {
    switch (widget.difficulty) {
      case 'Easy':
        // Easy: Big visual differences
        Color differentColor = baseColors[random.nextInt(baseColors.length)];
        while (differentColor == target.baseColor) {
          differentColor = baseColors[random.nextInt(baseColors.length)];
        }
        return GameCharacter(
          id: id,
          name: _getCharacterType(),
          baseColor: differentColor,
        );
        
      case 'Medium':
        // Medium: Small differences (same color, different accessories OR same accessories, different color)
        if (random.nextBool()) {
          // Same color, different accessories
          return GameCharacter(
            id: id,
            name: target.name,
            baseColor: target.baseColor,
            hasScarf: !target.hasScarf,
            scarfColor: target.hasScarf ? Colors.transparent : accessoryColors[random.nextInt(accessoryColors.length)],
            accessory: target.accessory.isEmpty ? _getAccessory() : '',
          );
        } else {
          // Different color, similar accessories
          Color differentColor = _getSimilarColor(target.baseColor);
          return GameCharacter(
            id: id,
            name: target.name,
            baseColor: differentColor,
            hasScarf: target.hasScarf,
            scarfColor: target.scarfColor,
            accessory: target.accessory,
          );
        }
        
      case 'Hard':
        // Hard: Nearly identical with tiny differences
        if (random.nextDouble() < 0.3) {
          // Same everything except scarf color
          Color differentScarfColor = accessoryColors[random.nextInt(accessoryColors.length)];
          while (differentScarfColor == target.scarfColor) {
            differentScarfColor = accessoryColors[random.nextInt(accessoryColors.length)];
          }
          return GameCharacter(
            id: id,
            name: target.name,
            baseColor: target.baseColor,
            hasScarf: target.hasScarf,
            scarfColor: differentScarfColor,
            hasHat: target.hasHat,
            hasDifferentEyes: target.hasDifferentEyes,
            accessory: target.accessory,
          );
        } else if (random.nextDouble() < 0.5) {
          // Same everything except hat
          return GameCharacter(
            id: id,
            name: target.name,
            baseColor: target.baseColor,
            hasScarf: target.hasScarf,
            scarfColor: target.scarfColor,
            hasHat: !target.hasHat,
            hasDifferentEyes: target.hasDifferentEyes,
            accessory: target.accessory,
          );
        } else {
          // Same everything except eyes
          return GameCharacter(
            id: id,
            name: target.name,
            baseColor: target.baseColor,
            hasScarf: target.hasScarf,
            scarfColor: target.scarfColor,
            hasHat: target.hasHat,
            hasDifferentEyes: !target.hasDifferentEyes,
            accessory: target.accessory,
          );
        }
        
      default:
        return GameCharacter(id: id, name: 'duck', baseColor: Colors.yellow);
    }
  }

  String _getCharacterType() {
    List<String> types = ['duck', 'cat', 'dog', 'bird', 'fish'];
    return types[random.nextInt(types.length)];
  }

  String _getAccessory() {
    List<String> accessories = ['bow', 'glasses', 'crown', 'flower', ''];
    return accessories[random.nextInt(accessories.length)];
  }

  Color _getSimilarColor(Color baseColor) {
    // Return a slightly different shade of similar color
    if (baseColor == Color(0xFFFFF176)) return Color(0xFFFFEB3B); // Yellow variations
    if (baseColor == Color(0xFF81C784)) return Color(0xFF4CAF50); // Green variations
    if (baseColor == Color(0xFF90CAF9)) return Color(0xFF2196F3); // Blue variations
    if (baseColor == Color(0xFFEF9A9A)) return Color(0xFFF44336); // Red variations
    if (baseColor == Color(0xFFCE93D8)) return Color(0xFF9C27B0); // Purple variations
    if (baseColor == Color(0xFFFFCC80)) return Color(0xFFFF9800); // Orange variations
    return baseColors[random.nextInt(baseColors.length)];
  }

  void _revealTarget() {
    setState(() {
      showingTarget = true;
    });
    
    revealTimer = Timer(Duration(milliseconds: revealDuration), () {
      _hideAndShuffle();
    });
  }

  void _hideAndShuffle() {
    setState(() {
      showingTarget = false;
      shuffling = true;
    });
    
    _performShuffle();
    
    shuffleTimer = Timer(Duration(milliseconds: shuffleDuration), () {
      setState(() {
        shuffling = false;
        canSelect = true;
      });
      
      // Auto-advance after timeout (15 seconds to find)
      Timer(Duration(seconds: 15), () {
        if (canSelect && gameActive) {
          _handleTimeOut();
        }
      });
    });
  }

  void _performShuffle() {
    shuffleController?.forward().then((_) {
      shuffleController?.reset();
    });
    
    // Multiple shuffle passes based on difficulty
    int shuffleCount = widget.difficulty == 'Easy' ? 2 : 
                      widget.difficulty == 'Medium' ? 4 : 6;
    
    for (int i = 0; i < shuffleCount; i++) {
      Timer(Duration(milliseconds: i * 300), () {
        if (mounted) {
          setState(() {
            shuffledCharacters.shuffle(random);
          });
        }
      });
    }
    
    // Add some fake movements for distraction in hard mode
    if (widget.difficulty == 'Hard') {
      Timer(Duration(milliseconds: shuffleDuration - 500), () {
        if (mounted) {
          setState(() {
            // Small position adjustments for distraction
            shuffledCharacters.shuffle(random);
          });
        }
      });
    }
  }

  void _handleCharacterTap(GameCharacter character) {
    if (!canSelect || !gameActive) return;
    
    setState(() {
      canSelect = false;
    });
    
    if (character.id == targetCharacter!.id) {
      // Correct character found!
      int timeBonus = _calculateTimeBonus();
      setState(() {
        score += (20 + timeBonus);
        correctSelections++;
      });
      _showFeedback(true, timeBonus);
    } else {
      // Wrong character
      setState(() {
        score = max(0, score - 10);
        wrongSelections++;
      });
      _showFeedback(false, 0);
    }
  }

  int _calculateTimeBonus() {
    // Simple time bonus calculation
    return random.nextInt(10) + 5;
  }

  void _handleTimeOut() {
    setState(() {
      canSelect = false;
      score = max(0, score - 5);
      wrongSelections++;
    });
    _showFeedback(false, 0);
  }

  void _showFeedback(bool correct, int timeBonus) {
    String message = correct ? 
      'Great! You found the target!' : 
      'Oops! That\'s not the right character.';
    
    if (timeBonus > 0) {
      message += '\n+$timeBonus time bonus!';
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFFF8F9FA),
        title: Text(
          correct ? 'Well Done!' : 'Try Again!',
          style: TextStyle(color: correct ? Color(0xFF81C784) : Color(0xFFEF9A9A)),
        ),
        content: Text(
          message,
          style: TextStyle(color: Color(0xFF2C3E50)),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                round++;
              });
              _nextRound();
            },
            child: Text('Continue', style: TextStyle(color: Color(0xFF81C784))),
          ),
        ],
      ),
    );
  }

  void _endGame() {
    setState(() {
      gameActive = false;
    });
    revealTimer?.cancel();
    shuffleTimer?.cancel();
    
    // Calculate accuracy and completion time
    double accuracy = correctSelections + wrongSelections > 0 ? (correctSelections / (correctSelections + wrongSelections)) * 100 : 0;
    int completionTime = DateTime.now().difference(gameStartTime).inSeconds;
    
    // Call completion callback if provided
    if (widget.onGameComplete != null) {
      widget.onGameComplete!(
        accuracy: accuracy.round(),
        completionTime: completionTime,
        challengeFocus: 'Attention',
        gameName: 'Find Me',
        difficulty: widget.difficulty,
      );
    }
  }

  @override
  void dispose() {
    revealTimer?.cancel();
    shuffleTimer?.cancel();
    shuffleController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA), // Soft light background
      appBar: AppBar(
        title: Text('Find Me - ${widget.difficulty}'),
        backgroundColor: Color(0xFFCE93D8), // Soft purple
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Score Display
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Text('Score: $score', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                    ],
                  ),
                  Text('Round: $round/$maxRounds', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                  Column(
                    children: [
                      if (showingTarget) 
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFFFFF176),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('MEMORIZE!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                        ),
                      if (shuffling) 
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFFFFCC80),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('SHUFFLING...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                        ),
                      if (canSelect) 
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFF81C784),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('FIND IT!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Game Area
            Expanded(
              child: Center(
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
        Text(
          'Find Me',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 20),
        Text(
          'Difficulty: ${widget.difficulty}',
          style: TextStyle(fontSize: 24, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 40),
        ElevatedButton(
          onPressed: _startGame,
          child: Text('Start Game'),
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

  Widget _buildGameArea() {
    if (!gameActive) {
      return _buildEndScreen();
    }
    
    if (showingTarget) {
      return _buildTargetReveal();
    }
    
    return _buildCharacterGrid();
  }

  Widget _buildTargetReveal() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Remember this character:',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 40),
        Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            color: Color(0xFFFFF176).withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Color(0xFFFFF176), width: 4),
          ),
          child: Center(
            child: _buildCharacterWidget(targetCharacter!, isTarget: true),
          ),
        ),
        SizedBox(height: 40),
        Text(
          'Get ready to find it after shuffling!',
          style: TextStyle(fontSize: 18, color: Color(0xFF2C3E50)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCharacterGrid() {
    int crossAxisCount = widget.difficulty == 'Easy' ? 3 : 
                        widget.difficulty == 'Medium' ? 4 : 4;
    
    return Padding(
      padding: EdgeInsets.all(20),
      child: AnimatedBuilder(
        animation: shuffleController ?? const AlwaysStoppedAnimation(0),
        builder: (context, child) {
          return Transform.scale(
            scale: shuffling ? 1.0 + shuffleController!.value * 0.05 : 1.0,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
              ),
              itemCount: shuffledCharacters.length,
              itemBuilder: (context, index) {
                GameCharacter character = shuffledCharacters[index];
                return GestureDetector(
                  onTap: () => _handleCharacterTap(character),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Color(0xFFE0E0E0), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _buildCharacterWidget(character),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCharacterWidget(GameCharacter character, {bool isTarget = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Main character body
            Container(
              width: isTarget ? 80 : 50,
              height: isTarget ? 80 : 50,
              decoration: BoxDecoration(
                color: character.baseColor,
                shape: BoxShape.circle,
                border: Border.all(color: Color(0xFF2C3E50), width: 2),
              ),
              child: Center(
                child: Icon(
                  _getCharacterIcon(character.name),
                  color: Colors.white,
                  size: isTarget ? 40 : 25,
                ),
              ),
            ),
            
            // Hat
            if (character.hasHat)
              Positioned(
                top: isTarget ? -5 : -3,
                child: Container(
                  width: isTarget ? 30 : 20,
                  height: isTarget ? 15 : 10,
                  decoration: BoxDecoration(
                    color: Color(0xFF2C3E50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            
            // Different eyes
            if (character.hasDifferentEyes)
              Positioned(
                top: isTarget ? 20 : 12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: isTarget ? 6 : 4,
                      height: isTarget ? 6 : 4,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: isTarget ? 8 : 6),
                    Container(
                      width: isTarget ? 4 : 3,
                      height: isTarget ? 4 : 3,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        
        // Scarf
        if (character.hasScarf)
          Container(
            margin: EdgeInsets.only(top: 5),
            width: isTarget ? 60 : 40,
            height: isTarget ? 8 : 6,
            decoration: BoxDecoration(
              color: character.scarfColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white, width: 1),
            ),
          ),
        
        // Accessory text
        if (character.accessory.isNotEmpty)
          Text(
            character.accessory,
            style: TextStyle(
              fontSize: isTarget ? 10 : 8,
              color: Color(0xFF2C3E50),
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  IconData _getCharacterIcon(String characterType) {
    switch (characterType) {
      case 'duck':
        return Icons.pets;
      case 'cat':
        return Icons.pets;
      case 'dog':
        return Icons.pets;
      case 'bird':
        return Icons.flutter_dash;
      case 'fish':
        return Icons.set_meal;
      default:
        return Icons.face;
    }
  }

  Widget _buildEndScreen() {
    double accuracy = correctSelections + wrongSelections > 0 ? 
        (correctSelections / (correctSelections + wrongSelections)) * 100 : 0;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Game Complete!',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 20),
        Text(
          'Final Score: $score',
          style: TextStyle(fontSize: 24, color: Color(0xFF2C3E50)),
        ),
        Text(
          'Accuracy: ${accuracy.toStringAsFixed(1)}%',
          style: TextStyle(fontSize: 20, color: Color(0xFF2C3E50)),
        ),
        Text(
          'Found: $correctSelections/${correctSelections + wrongSelections}',
          style: TextStyle(fontSize: 20, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 40),
        ElevatedButton(
          onPressed: () {
            setState(() {
              score = 0;
              round = 1;
              gameStarted = false;
              correctSelections = 0;
              wrongSelections = 0;
            });
          },
          child: Text('Play Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFCE93D8),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Back to Menu'),
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
