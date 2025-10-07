import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    
  })?
  onGameComplete;

  const ObjectHuntGame({
    Key? key,
    required this.difficulty,
    this.onGameComplete,
  }) : super(key: key);

  @override
  _ObjectHuntGameState createState() => _ObjectHuntGameState();
}

class GridCell {
  final int row;
  final int col;
  String? fruit;
  bool isRevealed;
  bool isShaking;
  bool isTarget;
  bool isFlipping; // Add this flag

  GridCell({
    required this.row,
    required this.col,
    this.fruit,
    this.isRevealed = false,
    this.isShaking = false,
    this.isTarget = false,
    this.isFlipping = false,
  });
}


class _ObjectHuntGameState extends State<ObjectHuntGame>
    with TickerProviderStateMixin {
// Add at the start of your _ObjectHuntGameState
Map<String, AnimationController> _flipControllers = {};
Map<String, Animation<double>> _flipAnimations = {};

  List<List<GridCell>> grid = [];
  List<String> availableFruits = [
    '🍎','🍊','🍌','🍇','🍓','🍑','🥝','🍉','🥭','🍍','🥥','🍒','🍈','🍋','🍐','🫐',
  ];
  List<String> targetFruits = [];
  int score = 0;
  int foundCount = 0;
  int totalTargets = 0;
  int countdownNumber = 0;
  bool gameStarted = false;
  bool gameActive = false;
  int currentCol = 0;
  late DateTime gameStartTime;
  Timer? gameTimer;
  int timeLeft = 0;
  Random random = Random();
  String _normalizedDifficulty = 'easy';

  String formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // Animation controllers
  late AnimationController _shakeController;
  late AnimationController _revealController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _revealAnimation;

  // GO overlay
  bool showingGo = false;
  late AnimationController _goController;
  late Animation<double> _goOpacity;
  late Animation<double> _goScale;

  final Color primaryColor = const Color(0xFF2E7D32);
  final Color accentColor = const Color(0xFF4CAF50);
  final Color successColor = const Color(0xFF66BB6A);
  final Color errorColor = const Color(0xFFE57373);
  final Color backgroundColor = const Color(0xFFE8F5E8);
  final Color cardColor = const Color(0xFFFFFFFF);
  final Color borderColor = const Color(0xFFC8E6C9);

  @override
  void initState() {
    super.initState();
    BackgroundMusicManager().startGameMusic('Object Hunt');
    _normalizedDifficulty = DifficultyUtils.normalizeDifficulty(widget.difficulty);
    _shakeController = AnimationController(duration: Duration(milliseconds: 500), vsync: this,);
    _revealController = AnimationController(duration: Duration(milliseconds: 300), vsync: this,);
    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0)
      .animate(CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn));
    _revealAnimation = Tween<double>(begin: 0.0, end: 1.0)
      .animate(CurvedAnimation(parent: _revealController, curve: Curves.easeInOut));
    _goController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350),);
    _goOpacity = CurvedAnimation(parent: _goController, curve: Curves.easeInOut);
    _goScale = Tween<double>(begin: 0.90, end: 1.0)
      .animate(CurvedAnimation(parent: _goController, curve: Curves.easeOutBack));
    _initializeGame();
  }

  Widget infoCircle({
    required String label,
    required String value,
    double circleSize = 88,
    double valueFontSize = 18,
    double labelFontSize = 12,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF3E2723),
            fontSize: labelFontSize,
            fontWeight: FontWeight.w900,
            
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            color: const Color(0xFF3E2723),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                offset: const Offset(0, 6),
                blurRadius: 0,
                spreadRadius: 4,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: valueFontSize,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

 void _initializeGame() {
  switch (_normalizedDifficulty) {
    case 'Starter':
      totalTargets = 5;
      timeLeft = 180;
      break;
    case 'Growing':
      totalTargets = 5;
      timeLeft = 150;
      break;
    case 'Challenged':
      totalTargets = 5;
      timeLeft = 120;
      break;
    default:
      totalTargets = 5;
      timeLeft = 120;
  }
  _setupGrid();
}


void _setupGrid() {
  // Dispose old controllers first (prevents memory leaks)
  _flipControllers.values.forEach((controller) => controller.dispose());
  _flipControllers.clear();
  _flipAnimations.clear();

  grid.clear();
  targetFruits.clear();
  foundCount = 0;
  score = 0;
  for (int row = 0; row < 4; row++) {
    List<GridCell> rowCells = [];
    for (int col = 0; col < 5; col++) {
      rowCells.add(GridCell(row: row, col: col));
      String key = '$row-$col';
      _flipControllers[key] = AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      );
      _flipAnimations[key] = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _flipControllers[key]!, curve: Curves.easeInOut)
      );
    }
    grid.add(rowCells);
  }
  availableFruits.shuffle();
  targetFruits = availableFruits.take(totalTargets).toList();
  List<String> fruitsToPlace = List.from(targetFruits);
  fruitsToPlace.shuffle();
  int placed = 0;
  for (int col = 0; col < 5; col++) {
    int row = random.nextInt(4);
    grid[row][col].fruit = fruitsToPlace[col % fruitsToPlace.length];
    grid[row][col].isTarget = true;
    placed++;
  }
  totalTargets = placed;
  setState(() {});
}

  void _startGame() {
    setState(() {
      countdownNumber = 3;
      gameStarted = true;
      gameActive = false;
    });

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdownNumber > 1) {
        setState(() => countdownNumber--);
      } else {
        timer.cancel();
        setState(() {
          countdownNumber = 0;
          foundCount = 0;
          score = 0;
          currentCol = 0;
          gameStartTime = DateTime.now();
          for (int row = 0; row < 4; row++) {
            for (int col = 0; col < 5; col++) {
              grid[row][col].isRevealed = false;
              grid[row][col].isShaking = false;
            }
          }
        });
        _showGoOverlay();
      }
    });
  }

 Future<void> _showGoOverlay() async {
  if (!mounted) return;
  setState(() => showingGo = true);
  await _goController.forward();
  await Future.delayed(const Duration(milliseconds: 550));
  if (!mounted) return;
  await _goController.reverse();
  if (!mounted) return;
  setState(() {
    showingGo = false;
    gameActive = true;
    // DO NOT reset timeLeft here! dapat naayos na ito sa _initializeGame bago countdown.
  });
  gameTimer?.cancel();
  _startTimer();
}



void _startTimer() {
  print("Start timer, timeLeft: $timeLeft");
  gameTimer?.cancel(); // ensure nothing is running
  gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    setState(() { 
      timeLeft--; 
      print("Tick timeLeft: $timeLeft");
    });
    if (timeLeft <= 0) {
      print("Stop timer! timeLeft reached 0");
      timer.cancel();
      setState(() { gameActive = false; });
      final timeTaken = DateTime.now().difference(gameStartTime).inSeconds;
      int accuracy = totalTargets > 0 ? ((foundCount / totalTargets) * 100).round() : 0;
      _showGameOverDialog(
        won: false,
        foundCount: foundCount,
        timeTaken: timeTaken,
        accuracy: accuracy,
      );
    }
  });
}




// Track locked columns to prevent multiple taps per column
Set<int> _lockedColumns = {};

void _onCellTapped(int row, int col) {
  if (!gameActive || grid[row][col].isRevealed) return;

  // Disable tap if column is locked (already tapped and not reset)
  if (_lockedColumns.contains(col)) return;

  // Allow tap only in current active column
  if (col != currentCol) return;

  // Lock the tapped column
  _lockedColumns.add(col);

  HapticFeedback.lightImpact();
  String key = '$row-$col';

  if (_flipControllers != null && _flipControllers[key] != null) {
    _flipControllers[key]!.forward().then((_) {
      setState(() {
        grid[row][col].isRevealed = true;
      });
      _revealCell(row, col);
      _flipControllers[key]!.reset();
    });
  } else {
    setState(() {
      grid[row][col].isRevealed = true;
    });
    _revealCell(row, col);
  }
}

void _revealCell(int row, int col) {
  if (grid[row][col].fruit != null) {
    setState(() {
      foundCount++;
      score += 20;
      currentCol++; // Moves to next column (progress game)

      // Unlock next column taps
      _lockedColumns.removeWhere((c) => c != currentCol);
    });

    _revealController.forward().then((_) {
      _revealController.reset();
    });

    HapticFeedback.mediumImpact();
    SoundEffectsManager().playSuccessWithVoice();

    if (foundCount >= totalTargets || currentCol >= 5) {
      gameTimer?.cancel();
      _endGame();
    }
  } else {
    // If wrong box tapped, unlock column so they can try again
    setState(() {
      grid[row][col].isShaking = true;
    });

    SoundEffectsManager().playWrong();

    _shakeController.forward().then((_) {
      _shakeController.reset();
      if (mounted) {
        setState(() {
          grid[row][col].isShaking = false;
          _lockedColumns.remove(col);  // Unlock column for retry
        });
        _restartGame(); // or retry logic here
      }
    });

    HapticFeedback.lightImpact();
  }
}



  void _restartGame() {
    setState(() {
      currentCol = 0;
      foundCount = 0; // Reset the count to 0

      // Hide all revealed boxes
      for (int row = 0; row < 4; row++) {
        for (int col = 0; col < 5; col++) {
          grid[row][col].isRevealed = false;
          grid[row][col].isShaking = false;
        }
      }
    });

    HapticFeedback.heavyImpact();
    // No modal dialog - just silent restart
  }

  void _endGame() {
  setState(() {
    gameActive = false;
  });

  gameTimer?.cancel();

  // Calculate stats
  double accuracyDouble = totalTargets > 0
      ? (foundCount / totalTargets) * 100
      : 0;
  int accuracy = accuracyDouble.round();
  int completionTime = DateTime.now().difference(gameStartTime).inSeconds;

  // Call callback if session mode
  if (widget.onGameComplete != null) {
    widget.onGameComplete!(
      accuracy: accuracy,
      completionTime: completionTime,
      challengeFocus: 'Memory & Attention',
      gameName: 'Object Hunt',
      difficulty: _normalizedDifficulty,
    );
  }

  // ✅ Show TicTacToe-style GameOverDialog
 _showGameOverDialog(
  won: foundCount >= totalTargets,
  foundCount: foundCount,
  timeTaken: DateTime.now().difference(gameStartTime).inSeconds,
  accuracy: accuracy,
);

}


  // PIN PROTECTION METHODS
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
            Navigator.of(dialogContext).pop();
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          },
          onCancel: () {
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

 @override
void dispose() {
  gameTimer?.cancel();
  _shakeController.dispose();
  _revealController.dispose();
  _goController.dispose();
  _flipControllers.values.forEach((controller) => controller.dispose());
  super.dispose();
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/logicbg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            // InfoCircle TIMER - ipakita lang kapag gameActive == true
            if (gameActive)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 104),
                  child: infoCircle(
                    label: "Time",
                    value: formatTime(timeLeft),
                    circleSize: 104,
                    valueFontSize: 30,
                    labelFontSize: 26,
                  ),
                ),
              ),
            Column(
              children: [
                // ... AppBar and other content ...
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Stack(
                      children: [
                        if (countdownNumber == 0)
                          (gameStarted ? _buildGrid() : _buildStartScreen()),
                        if (countdownNumber > 0) _buildCountdownScreen(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
                             
                              const SizedBox(height: 16),
                              Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accentColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.30),
                                      offset: const Offset(0, 8),
                                      blurRadius: 0,
                                      spreadRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    'GO!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 53,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
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
    );
  }

 Widget _buildStartScreen() {
  final size = MediaQuery.of(context).size;
  final bool isTablet = size.shortestSide >= 600;
  final double panelMaxWidth = isTablet ? 560.0 : 420.0;

  return Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: min(size.width * 0.9, panelMaxWidth),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: primaryColor.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.25),
              offset: const Offset(0, 12),
              blurRadius: 24,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.5),
              offset: const Offset(0, -4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Object Hunt',
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
                color: primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 0,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(
                Icons.grid_view,
                size: isTablet ? 56 : 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Memory Challenge',
              style: TextStyle(
                color: primaryColor,
                fontSize: isTablet ? 22 : 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Find all 5 hidden fruits before time runs out!\nGuess column by column and avoid mistakes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: primaryColor.withOpacity(0.85),
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
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    vertical: isTablet ? 18 : 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                  shadowColor: primaryColor.withOpacity(0.5),
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

Widget _buildGrid() {
  return LayoutBuilder(
    builder: (context, constraints) {
      final double maxTileSize = 140; // adjust to shrink/enlarge tiles
      final int rowCount = grid.length;       // 4 rows
      final int colCount = grid[0].length;    // 5 columns
      final int crossAxisCount = colCount;

      final double gridWidth =
          (maxTileSize * crossAxisCount) + ((crossAxisCount - 1) * 8);

      return Center(
        child: SizedBox(
          width: gridWidth,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: rowCount * colCount,
            itemBuilder: (context, index) {
              final row = index ~/ colCount;
              final col = index % colCount;

              return SizedBox(
                width: maxTileSize,
                height: maxTileSize,
                child: _buildCell(row, col), // ✅ use your actual cell builder
              );
            },
          ),
        ),
      );
    },
  );
}
Widget _buildCountdownScreen() {
  return Positioned.fill(
    child: Container(
      color: Colors.black.withOpacity(0),  // Dito ang background na may opacity
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Get Ready!',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF3E2723),
                shadows: [
                  Shadow(
                    color: Colors.transparent,
                    offset: Offset(2, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3E2723),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 0,
                    offset: const Offset(0, 6),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  countdownNumber > 0 ? '$countdownNumber' : "GO!",
                  style: const TextStyle(
                    fontSize: 80,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'The game will start soon...',
              style: TextStyle(
                fontSize: 19,
                color: const Color(0xFF3E2723),
                fontWeight: FontWeight.w700,
                shadows: const [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}





Widget _buildCell(int row, int col) {
  GridCell cell = grid[row][col];
  String key = '$row-$col';

  // Safety fallback if animation map not ready
  final flipAnim = _flipAnimations.containsKey(key) ? _flipAnimations[key]! : AlwaysStoppedAnimation(0.0);

  return GestureDetector(
    onTap: () => _onCellTapped(row, col),
    child: AnimatedBuilder(
      animation: Listenable.merge([_shakeAnimation, _revealAnimation, flipAnim]),
      builder: (context, child) {
        double shakeOffset = 0;
        if (cell.isShaking) {
          shakeOffset = _shakeAnimation.value * (random.nextBool() ? 1 : -1);
        }

        double animValue = flipAnim.value;
        double angle = animValue * pi;

        // Animate color and border as before, use side depending on angle
        Widget content;
        if (angle <= pi / 2) {
          // Card BACK (unrevealed side)
          content = AnimatedContainer(
            duration: Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _getCellColor(row, col),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _getBorderColor(row, col), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Center(child: _buildCellContent(row, col, showFront: false)),
          );
        } else {
          // Card FRONT (revealed side)
          content = AnimatedContainer(
            duration: Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _getCellColor(row, col),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _getBorderColor(row, col), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Center(child: _buildCellContent(row, col, showFront: true)),
          );
        }

        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: content,
          ),
        );
      },
    ),
  );
}



  Color _getCellColor(int row, int col) {
    GridCell cell = grid[row][col];

    // Red background when shaking (wrong guess)
    if (cell.isShaking) {
      return Color(0xFFFFEBEE); // Light red for wrong guess
    }

    // Highlight current column with a subtle green color
    if (col == currentCol && !cell.isRevealed) {
      return Color(0xFFE8F5E8); // Light green for current column
    }

    if (cell.isRevealed) {
      return cell.fruit != null ? Color(0xFFE8F5E8) : Color(0xFFFFEBEE);
    }
    return Color(0xFFFFFFFF);
  }

  Color _getBorderColor(int row, int col) {
    GridCell cell = grid[row][col];

    // Red border when shaking (wrong guess)
    if (cell.isShaking) {
      return Color(0xFFD32F2F); // Red border for wrong guess
    }

    // Highlight current column border
    if (col == currentCol && !cell.isRevealed) {
      return Color(0xFF4CAF50); // Green border for current column
    }

    if (cell.isRevealed) {
      return cell.fruit != null ? successColor : errorColor;
    }
    return borderColor;
  }
Widget _buildCellContent(int row, int col, {required bool showFront}) {
  GridCell cell = grid[row][col];
  // Show fruit emoji on revealed/correct cell
  if (cell.isRevealed && cell.fruit != null) {
    return Text(cell.fruit!, style: TextStyle(fontSize: 66));
  } else {
    // Card back or unrevealed cell = question mark
    return Text('?', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF666666)));
  }
}


  void _resetGame() {
    setState(() {
      currentCol = 0;
      foundCount = 0;
      gameStarted = false;
      gameActive = false;
      score = 0;
    });

    gameTimer?.cancel();
    _setupGrid();
  }

  void _showGameOverDialog({
  required bool won,
  required int foundCount,
  required int timeTaken,
  required int accuracy,
}) {
  String result = won ? 'Amazing! 🌟' : 'Good Try! 💪';

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
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
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.30),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              won ? Icons.celebration : Icons.emoji_events,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            result,
            style: TextStyle(
              color: primaryColor,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow(Icons.search, 'Objects Found', '$foundCount/$totalTargets'),
            const SizedBox(height: 12),
            _buildStatRow(Icons.timer, 'Time', '${timeTaken}s'),
            const SizedBox(height: 12),
            _buildStatRow(Icons.track_changes, 'Accuracy', '$accuracy%'),
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
                      Navigator.of(ctx).pop();
                      _resetGame();
                    },
                    icon: const Icon(Icons.refresh, size: 22),
                    label: const Text(
                      'Play Again',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop();
                    },
                    icon: Icon(Icons.exit_to_app, size: 22, color: primaryColor),
                    label: Text(
                      'Exit',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryColor, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
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
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
                widget.onGameComplete!(
                  accuracy: accuracy,
                  completionTime: timeTaken,
                  challengeFocus: 'Memory & Attention',
                  gameName: 'Object Hunt',
                  difficulty: _normalizedDifficulty,
                );
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 22),
              label: const Text(
                'Next Game',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
              ),
            ),
          ),
        ],
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
            color: accentColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primaryColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: primaryColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// PIN DIALOG CLASS
class _TeacherPinDialog extends StatefulWidget {
  final VoidCallback onPinVerified;
  final VoidCallback? onCancel;

  const _TeacherPinDialog({required this.onPinVerified, this.onCancel});

  @override
  State<_TeacherPinDialog> createState() => _TeacherPinDialogState();
}

class _TeacherPinDialogState extends State<_TeacherPinDialog> {
  final TextEditingController _pinController = TextEditingController();
  String? _error;
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verifyPin() async {
    final pin = _pinController.text.trim();
    if (pin.length != 6 || !RegExp(r'^[0-9]{6}').hasMatch(pin)) {
      setState(() => _error = 'PIN must be 6 digits');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Not logged in.';
          _isLoading = false;
        });
        return;
      }
      final doc = await FirebaseFirestore.instance.collection('teachers').doc(user.uid).get();
      final savedPin = doc.data()?['pin'];
      if (savedPin == null) {
        setState(() {
          _error = 'No PIN set. Please contact your administrator.';
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
        _error = 'Failed to verify PIN. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Color.fromARGB(255, 181, 187, 17),
              blurRadius: 0,
              spreadRadius: 0,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD740),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B6F4A).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.lock, color: const Color(0xFF5B6F4A), size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Teacher PIN Required',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF5B6F4A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Enter your 6-digit PIN to exit the session and access teacher features.',
                  style: TextStyle(fontSize: 16, color: const Color(0xFF5B6F4A), fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5B6F4A).withOpacity(0.2),
                      blurRadius: 0,
                      spreadRadius: 0,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold, color: Color(0xFF5B6F4A)),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    hintStyle: TextStyle(color: const Color(0xFF5B6F4A).withOpacity(0.4), letterSpacing: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: const Color(0xFF5B6F4A), width: 2)),
                    errorText: _error,
                    errorStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                  onSubmitted: (_) => _verifyPin(),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.6), blurRadius: 0, spreadRadius: 0, offset: Offset(0, 4))],
                      ),
                      child: TextButton(
                        onPressed: () {
                          if (widget.onCancel != null) {
                            widget.onCancel!();
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF5B6F4A),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: const Color(0xFF5B6F4A).withOpacity(0.6), blurRadius: 0, spreadRadius: 0, offset: Offset(0, 4))],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyPin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5B6F4A),
                          foregroundColor: const Color(0xFFFFD740),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD740))))
                            : const Text('Verify', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

