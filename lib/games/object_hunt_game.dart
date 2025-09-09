import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import '../utils/background_music_manager.dart';
import '../utils/sound_effects_manager.dart';
import '../utils/difficulty_utils.dart';

class ObjectHuntGame extends StatefulWidget {
  final String difficulty;
  final Function({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })? onGameComplete;

  const ObjectHuntGame({
    Key? key,
    required this.difficulty,
    this.onGameComplete,
  }) : super(key: key);

  @override
  _ObjectHuntGameState createState() => _ObjectHuntGameState();
}

class SceneObject {
  final String emoji;
  final String name;
  final Offset position;
  bool isTarget;
  bool isFound;
  bool isHighlighted;
  bool isDistractor;
  
  SceneObject({
    required this.emoji,
    required this.name,
    required this.position,
    this.isTarget = false,
    this.isFound = false,
    this.isHighlighted = false,
    this.isDistractor = false,
  });
}

class _ObjectHuntGameState extends State<ObjectHuntGame> {
  List<SceneObject> sceneObjects = [];
  List<SceneObject> targetObjects = [];
  int score = 0;
  int correctFinds = 0;
  int wrongTaps = 0;
  int totalTargets = 0;
  bool gameStarted = false;
  bool memorizationPhase = true;
  bool searchPhase = false;
  bool gameActive = false;
  late DateTime gameStartTime;
  Timer? gameTimer;
  Timer? phaseTimer;
  int timeLeft = 0;
  int memorizationTime = 0;
  String currentScene = 'Living Room';
  
  Random random = Random();
  
  // Scene configurations with objects
  final Map<String, Map<String, dynamic>> scenes = {
    'Living Room': {
      'background': '🏠',
      'objects': [
        {'emoji': '📺', 'name': 'TV'},
        {'emoji': '🛋️', 'name': 'Sofa'},
        {'emoji': '📚', 'name': 'Books'},
        {'emoji': '🕯️', 'name': 'Candle'},
        {'emoji': '🪴', 'name': 'Plant'},
        {'emoji': '🖼️', 'name': 'Picture'},
        {'emoji': '⏰', 'name': 'Clock'},
        {'emoji': '💡', 'name': 'Lamp'},
        {'emoji': '🎮', 'name': 'Game'},
        {'emoji': '☕', 'name': 'Coffee'},
        {'emoji': '📱', 'name': 'Phone'},
        {'emoji': '🗞️', 'name': 'Paper'},
        {'emoji': '🎵', 'name': 'Music'},
        {'emoji': '🧸', 'name': 'Toy'},
        {'emoji': '🕶️', 'name': 'Glasses'},
      ]
    },
    'Park': {
      'background': '🏞️',
      'objects': [
        {'emoji': '🌳', 'name': 'Tree'},
        {'emoji': '🌸', 'name': 'Flower'},
        {'emoji': '🦋', 'name': 'Butterfly'},
        {'emoji': '🐦', 'name': 'Bird'},
        {'emoji': '⚽', 'name': 'Ball'},
        {'emoji': '🪁', 'name': 'Kite'},
        {'emoji': '🎪', 'name': 'Tent'},
        {'emoji': '🚲', 'name': 'Bike'},
        {'emoji': '🦆', 'name': 'Duck'},
        {'emoji': '🌻', 'name': 'Sunflower'},
        {'emoji': '🍃', 'name': 'Leaf'},
        {'emoji': '🏃', 'name': 'Runner'},
        {'emoji': '🐕', 'name': 'Dog'},
        {'emoji': '🦴', 'name': 'Bone'},
        {'emoji': '🌿', 'name': 'Grass'},
      ]
    },
    'Kitchen': {
      'background': '🏡',
      'objects': [
        {'emoji': '🍎', 'name': 'Apple'},
        {'emoji': '🥛', 'name': 'Milk'},
        {'emoji': '🍞', 'name': 'Bread'},
        {'emoji': '🔪', 'name': 'Knife'},
        {'emoji': '🍳', 'name': 'Pan'},
        {'emoji': '☕', 'name': 'Coffee'},
        {'emoji': '🧂', 'name': 'Salt'},
        {'emoji': '🥄', 'name': 'Spoon'},
        {'emoji': '🍽️', 'name': 'Plate'},
        {'emoji': '🥗', 'name': 'Salad'},
        {'emoji': '🍯', 'name': 'Honey'},
        {'emoji': '🧄', 'name': 'Garlic'},
        {'emoji': '🥕', 'name': 'Carrot'},
        {'emoji': '🍌', 'name': 'Banana'},
        {'emoji': '🧊', 'name': 'Ice'},
      ]
    },
  };
  
  // Soft, accessible colors
  final Color backgroundColor = Color(0xFFF8F9FA);
  final Color targetHighlight = Color(0xFFFFF176); // Soft yellow
  final Color foundColor = Color(0xFF81C784); // Soft green
  final Color wrongColor = Color(0xFFEF9A9A); // Soft red

  @override
  void initState() {
    super.initState();
    // Start background music for this game
    BackgroundMusicManager().startGameMusic('Object Hunt');
    _initializeGame();
  }

  void _initializeGame() {
    // Set difficulty parameters
    switch (widget.difficulty.toLowerCase()) {
      case 'easy':
        totalTargets = 3;
        memorizationTime = 15; // 15 seconds
        timeLeft = 60; // 1 minute search time
        break;
      case 'medium':
        totalTargets = 5;
        memorizationTime = 10; // 10 seconds
        timeLeft = 45; // 45 seconds search time
        break;
      case 'hard':
        totalTargets = 8;
        memorizationTime = 8; // 8 seconds
        timeLeft = 30; // 30 seconds search time
        break;
      default:
        totalTargets = 3;
        memorizationTime = 15;
        timeLeft = 60;
    }
    
    _setupScene();
  }

  void _setupScene() {
    sceneObjects.clear();
    targetObjects.clear();
    
    // Select random scene
    List<String> sceneNames = scenes.keys.toList();
    currentScene = sceneNames[random.nextInt(sceneNames.length)];
    
    var sceneData = scenes[currentScene]!;
    List<Map<String, dynamic>> availableObjects = List.from(sceneData['objects']);
    availableObjects.shuffle();
    
    // Calculate number of objects based on difficulty
    int totalObjects;
    switch (widget.difficulty.toLowerCase()) {
      case 'easy':
        totalObjects = 8; // 3 targets + 5 distractors
        break;
      case 'medium':
        totalObjects = 12; // 5 targets + 7 distractors
        break;
      case 'hard':
        totalObjects = 15; // 8 targets + 7 distractors
        break;
      default:
        totalObjects = 8;
    }
    
    // Take required number of objects
    var selectedObjects = availableObjects.take(totalObjects).toList();
    
    // Create scene objects with random positions
    for (int i = 0; i < selectedObjects.length; i++) {
      var obj = selectedObjects[i];
      sceneObjects.add(SceneObject(
        emoji: obj['emoji'],
        name: obj['name'],
        position: _generateRandomPosition(i),
        isTarget: i < totalTargets, // First objects are targets
        isHighlighted: i < totalTargets, // Start highlighted during memorization
      ));
    }
    
    // Store target objects for reference
    targetObjects = sceneObjects.where((obj) => obj.isTarget).toList();
    
    // Add some distractors for medium/hard
    if (widget.difficulty.toLowerCase() != 'easy') {
      _addDistractors();
    }
    
    setState(() {});
  }

  Offset _generateRandomPosition(int index) {
    // Generate positions in a grid-like pattern with some randomness
    double gridSize = 80.0;
    int columns = 4;
    int row = index ~/ columns;
    int col = index % columns;
    
    double x = 50 + col * gridSize + random.nextDouble() * 20;
    double y = 100 + row * gridSize + random.nextDouble() * 20;
    
    return Offset(x, y);
  }

  void _addDistractors() {
    // Add extra objects that appear during search phase for confusion
    var sceneData = scenes[currentScene]!;
    List<Map<String, dynamic>> availableObjects = List.from(sceneData['objects']);
    
    // Remove already used objects
    for (var sceneObj in sceneObjects) {
      availableObjects.removeWhere((obj) => obj['emoji'] == sceneObj.emoji);
    }
    
    // Add 2-3 distractors for medium/hard
    int distractorCount = widget.difficulty.toLowerCase() == 'medium' ? 2 : 3;
    availableObjects.shuffle();
    
    for (int i = 0; i < distractorCount && i < availableObjects.length; i++) {
      var obj = availableObjects[i];
      sceneObjects.add(SceneObject(
        emoji: obj['emoji'],
        name: obj['name'],
        position: _generateRandomPosition(sceneObjects.length),
        isDistractor: true,
      ));
    }
  }

  void _startGame() {
    setState(() {
      gameStarted = true;
      gameActive = true;
      memorizationPhase = true;
      searchPhase = false;
      gameStartTime = DateTime.now();
      score = 0;
      correctFinds = 0;
      wrongTaps = 0;
      
      // Reset all objects
      for (var obj in sceneObjects) {
        obj.isFound = false;
        obj.isHighlighted = obj.isTarget; // Highlight targets during memorization
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
        title: Text('Object Hunt Instructions', style: TextStyle(color: Color(0xFF2C3E50))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Memorize the highlighted objects!',
              style: TextStyle(color: Color(0xFF2C3E50), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              '• Study the ${totalTargets} highlighted objects\n• Memorize their positions\n• Then find them when highlights disappear\n• Avoid tapping wrong objects!',
              style: TextStyle(color: Color(0xFF2C3E50)),
              textAlign: TextAlign.left,
            ),
            SizedBox(height: 8),
            Text(
              'Scene: $currentScene',
              style: TextStyle(color: Color(0xFF2C3E50), fontWeight: FontWeight.bold),
            ),
            Text(
              'Memorization time: ${memorizationTime}s',
              style: TextStyle(color: Color(0xFFE57373), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startMemorizationPhase();
            },
            child: Text('Start Memorizing!', style: TextStyle(color: Color(0xFF81C784))),
          ),
        ],
      ),
    );
  }

  void _startMemorizationPhase() {
    setState(() {
      memorizationPhase = true;
      // Show highlights on target objects
      for (var obj in sceneObjects) {
        obj.isHighlighted = obj.isTarget;
      }
    });
    
    // Start memorization timer
    phaseTimer = Timer(Duration(seconds: memorizationTime), () {
      _startSearchPhase();
    });
  }

  void _startSearchPhase() {
    setState(() {
      memorizationPhase = false;
      searchPhase = true;
      
      // Hide all highlights
      for (var obj in sceneObjects) {
        obj.isHighlighted = false;
      }
      
      // Show distractors (they were hidden during memorization)
      // This adds to the challenge
    });
    
    // Start search timer
    _startSearchTimer();
  }

  void _startSearchTimer() {
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

  void _onObjectTapped(SceneObject object) {
    if (!searchPhase || !gameActive || object.isFound) return;
    
    HapticFeedback.lightImpact();
    
    if (object.isTarget) {
      // Correct target found!
      setState(() {
        object.isFound = true;
        correctFinds++;
        score += 15 + (timeLeft ~/ 5); // Bonus for remaining time
      });
      
      HapticFeedback.mediumImpact();
      
      // Play success sound with voice effect
      SoundEffectsManager().playSuccessWithVoice();
      
      if (correctFinds == totalTargets) {
        gameTimer?.cancel();
        _endGame();
      }
    } else {
      // Wrong object tapped
      wrongTaps++;
      score = (score - 5).clamp(0, score); // Penalty
      
      // Flash red briefly
      setState(() {
        object.isHighlighted = true;
      });
      
      Timer(Duration(milliseconds: 300), () {
        setState(() {
          object.isHighlighted = false;
        });
      });
      
      HapticFeedback.lightImpact();
    }
  }

  void _endGame() {
    setState(() {
      gameActive = false;
    });
    
    gameTimer?.cancel();
    phaseTimer?.cancel();
    
    // Calculate game statistics
    double accuracyDouble = (correctFinds + wrongTaps) > 0 ? 
        (correctFinds / (correctFinds + wrongTaps)) * 100 : 0;
    int accuracy = accuracyDouble.round();
    int completionTime = DateTime.now().difference(gameStartTime).inSeconds;
    
    // Call completion callback if provided
    if (widget.onGameComplete != null) {
      widget.onGameComplete!(
        accuracy: accuracy,
        completionTime: completionTime,
        challengeFocus: 'Memory',
        gameName: 'Object Hunt',
        difficulty: widget.difficulty,
      );
    }
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    phaseTimer?.cancel();
    // Stop background music when leaving the game
    BackgroundMusicManager().stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Object Hunt - ${DifficultyUtils.getDifficultyDisplayName(widget.difficulty)}'),
        backgroundColor: Color(0xFF90CAF9), // Soft blue
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Score and Status Display
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Text('Score: $score', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                      Text('Wrong: $wrongTaps', style: TextStyle(fontSize: 14, color: Color(0xFF2C3E50))),
                    ],
                  ),
                  Column(
                    children: [
                      Text('Found: $correctFinds/$totalTargets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                      Text('Scene: $currentScene', style: TextStyle(fontSize: 14, color: Color(0xFF2C3E50))),
                    ],
                  ),
                  if (searchPhase)
                    Column(
                      children: [
                        Text('Time: ${timeLeft}s', style: TextStyle(fontSize: 16, color: timeLeft <= 10 ? Color(0xFFE57373) : Color(0xFF2C3E50), fontWeight: FontWeight.bold)),
                      ],
                    ),
                ],
              ),
            ),
            
            // Phase Indicator
            if (memorizationPhase)
              Container(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Color(0xFFFFF9C4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'MEMORIZATION PHASE - Study the highlighted objects!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                  textAlign: TextAlign.center,
                ),
              ),
            
            if (searchPhase)
              Container(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Color(0xFFE1F5FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'SEARCH PHASE - Find the objects you memorized!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                  textAlign: TextAlign.center,
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
        Text(
          scenes[currentScene]?['background'] ?? '🏠',
          style: TextStyle(fontSize: 80),
        ),
        SizedBox(height: 20),
        Text(
          'Object Hunt',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 20),
        Text(
          'Difficulty: ${DifficultyUtils.getDifficultyDisplayName(widget.difficulty)}',
          style: TextStyle(fontSize: 24, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 20),
        Text(
          'Find $totalTargets objects in $currentScene',
          style: TextStyle(fontSize: 18, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 40),
        ElevatedButton(
          onPressed: _startGame,
          child: Text('Start Hunt'),
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
    if (!gameActive && correctFinds == totalTargets) {
      return _buildWinScreen();
    }
    
    if (!gameActive) {
      return _buildTimeUpScreen();
    }
    
    return Stack(
      children: [
        // Scene background
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Color(0xFFF0F7FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFFE0E0E0)),
          ),
          child: Stack(
            children: sceneObjects.map((object) => _buildObjectWidget(object)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildObjectWidget(SceneObject object) {
    // Don't show distractors during memorization phase
    if (memorizationPhase && object.isDistractor) {
      return Container();
    }
    
    Color backgroundColor = Colors.transparent;
    Color borderColor = Colors.transparent;
    
    if (object.isHighlighted && memorizationPhase) {
      backgroundColor = targetHighlight.withOpacity(0.3);
      borderColor = targetHighlight;
    } else if (object.isFound) {
      backgroundColor = foundColor.withOpacity(0.3);
      borderColor = foundColor;
    } else if (object.isHighlighted && searchPhase) {
      backgroundColor = wrongColor.withOpacity(0.3);
      borderColor = wrongColor;
    }
    
    return Positioned(
      left: object.position.dx,
      top: object.position.dy,
      child: GestureDetector(
        onTap: () => _onObjectTapped(object),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Center(
            child: Text(
              object.emoji,
              style: TextStyle(fontSize: 32),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWinScreen() {
    double accuracy = (correctFinds + wrongTaps) > 0 ? 
        (correctFinds / (correctFinds + wrongTaps)) * 100 : 100;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.search,
          size: 80,
          color: Color(0xFF81C784),
        ),
        SizedBox(height: 20),
        Text(
          'Excellent Hunt!',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 20),
        Text(
          'Final Score: $score',
          style: TextStyle(fontSize: 24, color: Color(0xFF2C3E50)),
        ),
        Text(
          'All $totalTargets objects found!',
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
          child: Text('Hunt Again'),
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
          'Found: $correctFinds/$totalTargets objects',
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
