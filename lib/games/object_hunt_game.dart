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

  GridCell({
    required this.row,
    required this.col,
    this.fruit,
    this.isRevealed = false,
    this.isShaking = false,
    this.isTarget = false,
  });
}

class _ObjectHuntGameState extends State<ObjectHuntGame>
    with TickerProviderStateMixin {
  List<List<GridCell>> grid = [];
  List<String> availableFruits = [
    '🍎',
    '🍊',
    '🍌',
    '🍇',
    '🍓',
    '🍑',
    '🥝',
    '🍉',
    '🥭',
    '🍍',
    '🥥',
    '🍒',
    '🍈',
    '🍋',
    '🍐',
    '🫐',
  ];
  List<String> targetFruits = [];
  int score = 0;
  int foundCount = 0;
  int totalTargets = 0;
  int countdown = 0;
  int countdownNumber = 0;
  bool gameStarted = false;
  bool gameActive = false;
  int currentCol = 0; // Track which column player should guess next (0-4)
  late DateTime gameStartTime;
  Timer? gameTimer;
  int timeLeft = 0;
  Random random = Random();
  String _normalizedDifficulty = 'easy';

  // Animation controllers
  late AnimationController _shakeController;
  late AnimationController _revealController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _revealAnimation;

  // App color scheme - Green theme
  final Color primaryColor = const Color(0xFF2E7D32); // Dark green
  final Color accentColor = const Color(0xFF4CAF50); // Medium green
  final Color successColor = const Color(0xFF66BB6A); // Light green
  final Color errorColor = const Color(0xFFE57373); // Light red
  final Color backgroundColor = const Color(0xFFE8F5E8); // Very light green
  final Color cardColor = const Color(0xFFFFFFFF); // White
  final Color borderColor = const Color(0xFFC8E6C9); // Light green border

  @override
  void initState() {
    super.initState();
    BackgroundMusicManager().startGameMusic('Object Hunt');
    _normalizedDifficulty = DifficultyUtils.normalizeDifficulty(
      widget.difficulty,
    );

    // Initialize animation controllers
    _shakeController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _revealController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _revealAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _revealController, curve: Curves.easeInOut),
    );

    _initializeGame();
  }

  void _initializeGame() {
    // Set difficulty parameters
    switch (_normalizedDifficulty) {
      case 'Starter':
        totalTargets = 5; // All 5 columns
        timeLeft = 120; // 2 minutes
        break;
      case 'Growing':
        totalTargets = 5; // All 5 columns
        timeLeft = 150; // 2.5 minutes
        break;
      case 'Challenged':
        totalTargets = 5; // All 5 columns
        timeLeft = 180; // 3 minutes
        break;
      default:
        totalTargets = 5;
        timeLeft = 120;
    }

    _setupGrid();
  }

  void _setupGrid() {
  // Create 4x5 grid
  grid.clear();
  targetFruits.clear();
  foundCount = 0;
  score = 0;

  for (int row = 0; row < 4; row++) {
    List<GridCell> rowCells = [];
    for (int col = 0; col < 5; col++) {
      rowCells.add(GridCell(row: row, col: col));
    }
    grid.add(rowCells);
  }

  // Select random target fruits
  availableFruits.shuffle();
  targetFruits = availableFruits.take(totalTargets).toList();

  // Place fruits randomly in each column (one fruit per column)
  List<String> fruitsToPlace = List.from(targetFruits);
  fruitsToPlace.shuffle();

  int placed = 0;
  for (int col = 0; col < 5; col++) {
    int row = random.nextInt(4);
    grid[row][col].fruit = fruitsToPlace[col % fruitsToPlace.length];
    grid[row][col].isTarget = true;
    placed++;
  }

  // ✅ totalTargets is already set by difficulty (5 columns)
  // So no need for a separate totalObjects variable anymore.
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
        gameActive = true;
        foundCount = 0;
        score = 0;
        currentCol = 0;
        gameStartTime = DateTime.now();

        // Reset cells
        for (int row = 0; row < 4; row++) {
          for (int col = 0; col < 5; col++) {
            grid[row][col].isRevealed = false;
            grid[row][col].isShaking = false;
          }
        }
      });

      _startTimer();
    }
  });
}


  void _showInstructions() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text(
          'Object Hunt Challenge',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Find these $totalTargets fruits:',
              style: TextStyle(color: primaryColor, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: targetFruits
                  .map((fruit) => Text(fruit, style: TextStyle(fontSize: 24)))
                  .toList(),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '• Guess column by column starting from column 1\n• Found fruits reveal immediately\n• Empty boxes shake then restart from column 1\n• Continue until time expires or game completed',
                style: TextStyle(color: primaryColor, fontSize: 14),
                textAlign: TextAlign.left,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              'Start Game!',
              style: TextStyle(
                color: successColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startTimer() {
  timeLeft = 60; // or whatever duration you want
  gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    setState(() {
      timeLeft--;
    });

    if (timeLeft <= 0) {
      timer.cancel();
      setState(() {
        gameActive = false;
      });

      final timeTaken = DateTime.now().difference(gameStartTime!).inSeconds;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => GameOverDialog(
          title: "Time’s Up!",
          message: "You found $foundCount objects in $timeTaken seconds!",
          onPlayAgain: () {
            Navigator.pop(context);
            _startGame();
          },
          onExit: () {
            Navigator.pop(context); // close dialog
            Navigator.pop(context); // back to menu
          },
        ),
      );
    }
  });
}


void _onCellTapped(int row, int col) {
  if (!gameActive || grid[row][col].isRevealed) return;

  // Only allow clicking on the current column
  if (col != currentCol) return;

  HapticFeedback.lightImpact();
  _revealCell(row, col);
}



 void _revealCell(int row, int col) {
  if (grid[row][col].fruit != null) {
    // Found a fruit!
    setState(() {
      grid[row][col].isRevealed = true;
      foundCount++;
      score += 20;
      currentCol++; // Move to next column
    });

    _revealController.forward().then((_) {
      _revealController.reset();
    });

    HapticFeedback.mediumImpact();
    SoundEffectsManager().playSuccessWithVoice();

    // ✅ Check win
    if (foundCount >= totalTargets) {
      gameTimer?.cancel();
      _endGame();
    }

    // ✅ Otherwise move to next col
    else if (currentCol >= 5) {
      gameTimer?.cancel();
      _endGame();
    }

  } else {
    // Empty box - shake animation then restart
    setState(() {
      grid[row][col].isShaking = true;
    });

    SoundEffectsManager().playWrong();

    _shakeController.forward().then((_) {
      _shakeController.reset();
      if (mounted) {
        setState(() {
          grid[row][col].isShaking = false;
        });
        _restartGame();
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
    BackgroundMusicManager().stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            image: AssetImage('assets/logicbg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            // Custom AppBar
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 16,
                right: 16,
                bottom: 16,
              ),
            ),
            // Body content
     Expanded(
  child: Padding(
    padding: EdgeInsets.all(20),
    child: Stack(
      children: [
        gameStarted ? _buildGrid() : _buildStartScreen(),
        if (countdownNumber > 0) _buildCountdownScreen(),
      ],
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
  return Positioned.fill(  // 👈 ensures it covers the entire screen
    child: Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Get Ready!',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black26,
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
                fontSize: 18,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
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


Widget _buildCountdownOverlay() {
  return Container(
    color: Colors.black.withOpacity(0.6),
    child: Center(
      child: Text(
        countdown == 0 ? "GO!" : "$countdown",
        style: TextStyle(
          fontSize: 80,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [
            Shadow(
              offset: Offset(0, 4),
              blurRadius: 8,
              color: Colors.black.withOpacity(0.7),
            ),
          ],
        ),
      ),
    ),
  );
}


  Widget _buildCell(int row, int col) {
    GridCell cell = grid[row][col];

    return GestureDetector(
      onTap: () => _onCellTapped(row, col),
      child: AnimatedBuilder(
        animation: Listenable.merge([_shakeAnimation, _revealAnimation]),
        builder: (context, child) {
          double shakeOffset = 0;
          if (cell.isShaking) {
            shakeOffset = _shakeAnimation.value * (random.nextBool() ? 1 : -1);
          }

          return Transform.translate(
            offset: Offset(shakeOffset, 0),
            child: AnimatedContainer(
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
              child: Center(child: _buildCellContent(row, col)),
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

  Widget _buildCellContent(int row, int col) {
    GridCell cell = grid[row][col];

    if (cell.isRevealed && cell.fruit != null) {
      // Show the fruit with bigger size
      return Text(cell.fruit!, style: TextStyle(fontSize: 66));
    } else {
      // Box is not revealed - show question mark
      return Text(
        '?',
        style: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: Color(0xFF666666),
        ),
      );
    }
  }

  Widget _buildWinScreen() {
    return Container(); // Return empty container since dialog is handled in _endGame()
  }

  Widget _buildTimeUpScreen() {
    return Container(); // Return empty container since dialog is handled in _endGame()
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
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: const Color(0xFF2E7D32), // same dark green as TicTacToe
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                won ? "You Win!" : "Game Over",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "You found $foundCount objects\nin $timeTaken seconds",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Accuracy: $accuracy%",
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _startGame();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2E7D32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Play Again"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // close dialog
                      Navigator.pop(context); // back to menu
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Exit"),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
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
class GameOverDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onPlayAgain;
  final VoidCallback onExit;

  const GameOverDialog({
    Key? key,
    required this.title,
    required this.message,
    required this.onPlayAgain,
    required this.onExit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFF2E7D32), // green theme
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: onPlayAgain,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Play Again"),
                ),
                ElevatedButton(
                  onPressed: onExit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Exit"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
