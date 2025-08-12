import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';

class LightTapGame extends StatefulWidget {
  final String difficulty;
  final Future<void> Function({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })? onGameComplete;

  const LightTapGame({Key? key, required this.difficulty, this.onGameComplete}) : super(key: key);

  @override
  _LightTapGameState createState() => _LightTapGameState();
}

class _LightTapGameState extends State<LightTapGame> {
  int score = 0;
  int round = 1;
  int maxRounds = 10;
  bool gameActive = false;
  bool gameStarted = false;
  bool waitingForTap = false;
  String currentRule = '';
  List<Color> lightColors = [];
  List<bool> lightStates = [];
  Timer? signalTimer;
  Timer? reactionTimer;
  Random random = Random();
  int lightCount = 2;
  int signalInterval = 2000; // milliseconds between signals
  int reactionWindow = 1500; // milliseconds to react
  int combo = 0;
  int lives = 3;
  DateTime gameStartTime = DateTime.now();
  
  // Soft, accessible colors for children with cognitive impairments
  final List<Color> availableColors = [
    Color(0xFFEF9A9A), // Soft red
    Color(0xFF90CAF9), // Soft blue
    Color(0xFFFFF176), // Soft yellow
    Color(0xFF81C784), // Soft green
    Color(0xFFCE93D8), // Soft purple
    Color(0xFFFFCC80), // Soft orange
  ];
  
  final Color offColor = Color(0xFFE0E0E0); // Soft gray for off lights
  
  String lastSignal = '';
  String beforeLastSignal = '';
  bool isComplexPattern = false;
  int correctTaps = 0;
  int wrongTaps = 0;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  void _initializeGame() {
    switch (widget.difficulty) {
      case 'Easy':
        lightCount = 2;
        signalInterval = 2500;
        reactionWindow = 2000;
        maxRounds = 8;
        currentRule = 'Tap when the light is RED';
        break;
      case 'Medium':
        lightCount = 4;
        signalInterval = 1500;
        reactionWindow = 1500;
        maxRounds = 10;
        currentRule = 'Tap when BLUE follows YELLOW';
        break;
      case 'Hard':
        lightCount = 6;
        signalInterval = 800;
        reactionWindow = 1000;
        maxRounds = 12;
        currentRule = 'Tap when RED blinks twice';
        isComplexPattern = true;
        break;
    }
    
    lightColors = List.generate(lightCount, (index) => offColor);
    lightStates = List.generate(lightCount, (index) => false);
  }

  void _startGame() {
    setState(() {
      gameActive = true;
      gameStarted = true;
      score = 0;
      round = 1;
      combo = 0;
      lives = 3;
      correctTaps = 0;
      wrongTaps = 0;
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
              currentRule,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'Watch the lights carefully and tap only when you see the correct pattern!',
              style: TextStyle(color: Color(0xFF2C3E50)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Lives: $lives',
              style: TextStyle(color: Color(0xFF2C3E50), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startSignalPhase();
            },
            child: Text('Start', style: TextStyle(color: Color(0xFF81C784))),
          ),
        ],
      ),
    );
  }

  void _startSignalPhase() {
    _nextSignal();
  }

  void _nextSignal() {
    if (!gameActive || round > maxRounds) {
      _endGame();
      return;
    }

    // Reset lights
    setState(() {
      for (int i = 0; i < lightCount; i++) {
        lightColors[i] = offColor;
        lightStates[i] = false;
      }
      waitingForTap = false;
    });

    // Generate next signal after delay
    Timer(Duration(milliseconds: signalInterval), () {
      if (gameActive) {
        _generateSignal();
      }
    });
  }

  void _generateSignal() {
    switch (widget.difficulty) {
      case 'Easy':
        _generateEasySignal();
        break;
      case 'Medium':
        _generateMediumSignal();
        break;
      case 'Hard':
        _generateHardSignal();
        break;
    }
  }

  void _generateEasySignal() {
    // Easy: Tap when light is RED
    Color signalColor = availableColors[random.nextInt(availableColors.length)];
    int lightIndex = random.nextInt(lightCount);
    
    setState(() {
      lightColors[lightIndex] = signalColor;
      lightStates[lightIndex] = true;
    });
    
    bool isCorrectSignal = signalColor == Color(0xFFEF9A9A); // Soft red
    
    if (isCorrectSignal) {
      setState(() {
        waitingForTap = true;
      });
      
      reactionTimer = Timer(Duration(milliseconds: reactionWindow), () {
        if (waitingForTap) {
          _handleMissedTap();
        }
      });
    }
    
    // Keep light on for a short time
    Timer(Duration(milliseconds: 800), () {
      if (gameActive) {
        setState(() {
          lightColors[lightIndex] = offColor;
          lightStates[lightIndex] = false;
        });
        
        if (!isCorrectSignal && !waitingForTap) {
          _handleCorrectNoTap();
        }
        
        Timer(Duration(milliseconds: 500), () {
          if (gameActive) {
            setState(() {
              round++;
            });
            _nextSignal();
          }
        });
      }
    });
  }

  void _generateMediumSignal() {
    // Medium: Tap when BLUE follows YELLOW
    Color signalColor = availableColors[random.nextInt(availableColors.length)];
    int lightIndex = random.nextInt(lightCount);
    
    setState(() {
      lightColors[lightIndex] = signalColor;
      lightStates[lightIndex] = true;
    });
    
    // Track signal sequence
    beforeLastSignal = lastSignal;
    lastSignal = _colorToString(signalColor);
    
    bool isCorrectPattern = (beforeLastSignal == 'yellow' && lastSignal == 'blue');
    
    if (isCorrectPattern) {
      setState(() {
        waitingForTap = true;
      });
      
      reactionTimer = Timer(Duration(milliseconds: reactionWindow), () {
        if (waitingForTap) {
          _handleMissedTap();
        }
      });
    }
    
    // Keep light on for a short time
    Timer(Duration(milliseconds: 600), () {
      if (gameActive) {
        setState(() {
          lightColors[lightIndex] = offColor;
          lightStates[lightIndex] = false;
        });
        
        if (!isCorrectPattern && !waitingForTap) {
          _handleCorrectNoTap();
        }
        
        Timer(Duration(milliseconds: 300), () {
          if (gameActive) {
            setState(() {
              round++;
            });
            _nextSignal();
          }
        });
      }
    });
  }

  void _generateHardSignal() {
    // Hard: Tap when RED blinks twice
    Color signalColor = availableColors[random.nextInt(availableColors.length)];
    int lightIndex = random.nextInt(lightCount);
    
    if (signalColor == Color(0xFFEF9A9A)) { // Soft red
      // Create double blink pattern
      _createDoubleBlink(lightIndex);
    } else {
      // Regular single light
      setState(() {
        lightColors[lightIndex] = signalColor;
        lightStates[lightIndex] = true;
      });
      
      Timer(Duration(milliseconds: 400), () {
        if (gameActive) {
          setState(() {
            lightColors[lightIndex] = offColor;
            lightStates[lightIndex] = false;
          });
          
          _handleCorrectNoTap();
          
          Timer(Duration(milliseconds: 300), () {
            if (gameActive) {
              setState(() {
                round++;
              });
              _nextSignal();
            }
          });
        }
      });
    }
  }

  void _createDoubleBlink(int lightIndex) {
    // First blink
    setState(() {
      lightColors[lightIndex] = Color(0xFFEF9A9A); // Soft red
      lightStates[lightIndex] = true;
    });
    
    Timer(Duration(milliseconds: 200), () {
      setState(() {
        lightColors[lightIndex] = offColor;
        lightStates[lightIndex] = false;
      });
      
      // Brief pause
      Timer(Duration(milliseconds: 100), () {
        // Second blink
        setState(() {
          lightColors[lightIndex] = Color(0xFFEF9A9A); // Soft red
          lightStates[lightIndex] = true;
          waitingForTap = true;
        });
        
        reactionTimer = Timer(Duration(milliseconds: reactionWindow), () {
          if (waitingForTap) {
            _handleMissedTap();
          }
        });
        
        Timer(Duration(milliseconds: 200), () {
          setState(() {
            lightColors[lightIndex] = offColor;
            lightStates[lightIndex] = false;
          });
          
          if (!waitingForTap) {
            Timer(Duration(milliseconds: 300), () {
              if (gameActive) {
                setState(() {
                  round++;
                });
                _nextSignal();
              }
            });
          }
        });
      });
    });
  }

  String _colorToString(Color color) {
    if (color == Color(0xFFEF9A9A)) return 'red';
    if (color == Color(0xFF90CAF9)) return 'blue';
    if (color == Color(0xFFFFF176)) return 'yellow';
    if (color == Color(0xFF81C784)) return 'green';
    if (color == Color(0xFFCE93D8)) return 'purple';
    if (color == Color(0xFFFFCC80)) return 'orange';
    return 'unknown';
  }

  void _handleScreenTap() {
    if (!gameActive) return;
    
    reactionTimer?.cancel();
    
    if (waitingForTap) {
      // Correct tap!
      setState(() {
        score += (10 + combo * 2);
        combo++;
        correctTaps++;
        waitingForTap = false;
      });
      _showFeedback(true);
    } else {
      // Wrong tap
      setState(() {
        lives--;
        combo = 0;
        wrongTaps++;
      });
      _showFeedback(false);
      
      if (lives <= 0) {
        _endGame();
        return;
      }
    }
  }

  void _handleMissedTap() {
    setState(() {
      combo = 0;
      waitingForTap = false;
      lives--;
    });
    
    if (lives <= 0) {
      _endGame();
    } else {
      Timer(Duration(milliseconds: 500), () {
        if (gameActive) {
          setState(() {
            round++;
          });
          _nextSignal();
        }
      });
    }
  }

  void _handleCorrectNoTap() {
    setState(() {
      score += 5;
      combo++;
    });
    
    Timer(Duration(milliseconds: 100), () {
      if (gameActive) {
        setState(() {
          round++;
        });
        _nextSignal();
      }
    });
  }

  void _showFeedback(bool correct) {
    // Brief visual feedback
    Timer(Duration(milliseconds: 500), () {
      if (gameActive) {
        setState(() {
          round++;
        });
        _nextSignal();
      }
    });
  }

  void _endGame() {
    setState(() {
      gameActive = false;
    });
    signalTimer?.cancel();
    reactionTimer?.cancel();
    
    // Calculate accuracy and completion time
    double accuracy = correctTaps + wrongTaps > 0 ? (correctTaps / (correctTaps + wrongTaps)) * 100 : 0;
    int completionTime = DateTime.now().difference(gameStartTime).inSeconds;
    
    // Call completion callback if provided
    if (widget.onGameComplete != null) {
      widget.onGameComplete!(
        accuracy: accuracy.round(),
        completionTime: completionTime,
        challengeFocus: 'Attention',
        gameName: 'Light Tap',
        difficulty: widget.difficulty,
      );
    }
  }

  @override
  void dispose() {
    signalTimer?.cancel();
    reactionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA), // Soft light background
      appBar: AppBar(
        title: Text('Light Tap - ${widget.difficulty}'),
        backgroundColor: Color(0xFF90CAF9), // Soft blue
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
                      Text('Combo: x$combo', style: TextStyle(fontSize: 14, color: Color(0xFF2C3E50))),
                    ],
                  ),
                  Text('Round: $round/$maxRounds', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                  Column(
                    children: [
                      Text('Lives: $lives', style: TextStyle(fontSize: 16, color: Color(0xFF2C3E50))),
                      if (waitingForTap) 
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFF81C784),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('TAP NOW!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Rule Display
            Container(
              margin: EdgeInsets.symmetric(horizontal: 20),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFE8F5E8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFF81C784), width: 2),
              ),
              child: Text(
                currentRule,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                textAlign: TextAlign.center,
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
          'Light Tap',
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
    if (!gameActive) {
      return _buildEndScreen();
    }
    
    return GestureDetector(
      onTap: _handleScreenTap,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Watch the lights carefully!',
              style: TextStyle(fontSize: 18, color: Color(0xFF2C3E50), fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            
            // Light Grid
            Container(
              padding: EdgeInsets.all(20),
              child: Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: List.generate(lightCount, (index) {
                  return Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: lightColors[index],
                      border: Border.all(color: Color(0xFF2C3E50), width: 3),
                      boxShadow: lightStates[index] ? [
                        BoxShadow(
                          color: lightColors[index].withOpacity(0.6),
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                      ] : [],
                    ),
                  );
                }),
              ),
            ),
            
            SizedBox(height: 40),
            
            Text(
              'Tap anywhere on the screen when you see the correct pattern!',
              style: TextStyle(fontSize: 16, color: Color(0xFF2C3E50)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndScreen() {
    double accuracy = correctTaps + wrongTaps > 0 ? (correctTaps / (correctTaps + wrongTaps)) * 100 : 0;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Game Over!',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 20),
        Text(
          'Final Score: $score',
          style: TextStyle(fontSize: 24, color: Color(0xFF2C3E50)),
        ),
        Text(
          'Best Combo: x$combo',
          style: TextStyle(fontSize: 20, color: Color(0xFF2C3E50)),
        ),
        Text(
          'Accuracy: ${accuracy.toStringAsFixed(1)}%',
          style: TextStyle(fontSize: 20, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 40),
        ElevatedButton(
          onPressed: () {
            setState(() {
              score = 0;
              round = 1;
              combo = 0;
              lives = 3;
              gameStarted = false;
              correctTaps = 0;
              wrongTaps = 0;
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
