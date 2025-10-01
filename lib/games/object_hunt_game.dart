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

    // Place one fruit in each column
    for (int col = 0; col < 5; col++) {
      // Place one fruit in this column at random row
      int row = random.nextInt(4);
      grid[row][col].fruit = fruitsToPlace[col % fruitsToPlace.length];
      grid[row][col].isTarget = true;
    }

    setState(() {});
  }

  void _startGame() {
    setState(() {
      gameStarted = true;
      gameActive = true;
      foundCount = 0;
      score = 0;
      currentCol = 0; // Start from column 0
      gameStartTime = DateTime.now();

      // Reset all cells
      for (int row = 0; row < 4; row++) {
        for (int col = 0; col < 5; col++) {
          grid[row][col].isRevealed = false;
          grid[row][col].isShaking = false;
        }
      }
    });

    _startTimer();
    _showInstructions();
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
    gameTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        timeLeft--;
      });

      if (timeLeft <= 0) {
        timer.cancel();
        _endGame();
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

      // Check if all columns are completed
      if (currentCol >= 5) {
        gameTimer?.cancel();
        _endGame();
      }
    } else {
      // Empty box - shake animation then restart
      setState(() {
        grid[row][col].isShaking = true;
      });

      _shakeController.forward().then((_) {
        _shakeController.reset();
        if (mounted) {
          setState(() {
            grid[row][col].isShaking = false;
          });
          // Restart after shake animation
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

    // Calculate game statistics
    double accuracyDouble = totalTargets > 0
        ? (foundCount / totalTargets) * 100
        : 0;
    int accuracy = accuracyDouble.round();
    int completionTime = DateTime.now().difference(gameStartTime).inSeconds;

    // Call completion callback if provided
    if (widget.onGameComplete != null) {
      widget.onGameComplete!(
        accuracy: accuracy,
        completionTime: completionTime,
        challengeFocus: 'Memory & Attention',
        gameName: 'Object Hunt',
        difficulty: _normalizedDifficulty,
      );
    }

    // Show completion dialog after calling onGameComplete
    if (foundCount >= 5) {
      // Game completed successfully
      _showGameOverDialog(true, accuracy, completionTime);
    } else {
      // Time up
      _showGameOverDialog(false, accuracy, completionTime);
    }
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
    return Scaffold(
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
              decoration: BoxDecoration(color: primaryColor),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      'Object Hunt - ${DifficultyUtils.getDifficultyDisplayName(widget.difficulty)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the back button
                ],
              ),
            ),
            // Body content
            Expanded(
              child: SafeArea(
                child: Column(
                  children: [
                    // Score and Timer Display
                    Container(
                      margin: EdgeInsets.all(20),
                      padding: EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.1),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Score
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 18,
                                  color: Color(0xFFFFB300),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '$score',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Found Count
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: successColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: successColor, width: 2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search,
                                  size: 18,
                                  color: successColor,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '$foundCount/5',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: successColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Timer
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: timeLeft <= 30
                                  ? errorColor.withOpacity(0.1)
                                  : Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: timeLeft <= 30
                                    ? errorColor.withOpacity(0.3)
                                    : Color(0xFFE9ECEF),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer,
                                  size: 18,
                                  color: timeLeft <= 30
                                      ? errorColor
                                      : primaryColor,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '${timeLeft}s',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: timeLeft <= 30
                                        ? errorColor
                                        : primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Game Area
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: gameStarted ? _buildGrid() : _buildStartScreen(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartScreen() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(30),
        margin: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_view, size: 80, color: Colors.white),
            SizedBox(height: 20),
            Text(
              'Object Hunt',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.8),
                    offset: Offset(2, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Memory Challenge',
              style: TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.8),
                    offset: Offset(1, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
            SizedBox(height: 15),
            Text(
              'Complete all 5 columns before time runs out',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.8),
                    offset: Offset(1, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: _startGame,
              child: Text('Start Game'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    if (!gameActive && foundCount == totalTargets) {
      return _buildWinScreen();
    }

    if (!gameActive) {
      return _buildTimeUpScreen();
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.15),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Grid
            Expanded(
              child: AspectRatio(
                aspectRatio: 5 / 4,
                child: Column(
                  children: List.generate(4, (row) {
                    return Expanded(
                      child: Row(
                        children: List.generate(5, (col) {
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.all(2),
                              child: _buildCell(row, col),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
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

  void _showGameOverDialog(
    bool isCompletion,
    int accuracy,
    int completionTime,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  isCompletion ? Icons.emoji_events : Icons.timer_off,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isCompletion ? 'Excellent Memory! 🧠✨' : 'Time\'s Up! ⏰',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatRow(
                  Icons.star_rounded,
                  'Final Score',
                  '$score points',
                ),
                const SizedBox(height: 12),
                _buildStatRow(
                  Icons.grid_view,
                  'Columns Completed',
                  isCompletion ? '5/5' : '$foundCount/5',
                ),
                const SizedBox(height: 12),
                _buildStatRow(
                  Icons.track_changes,
                  'Accuracy',
                  '${((foundCount / 5) * 100).round()}%',
                ),
                const SizedBox(height: 12),
                _buildStatRow(Icons.timer, 'Time Used', '${completionTime}s'),
              ],
            ),
          ),
          actions: [
            // Different actions for demo mode vs session mode
            if (widget.onGameComplete == null) ...[
              // Demo mode: Show Play Again and Exit buttons
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _resetGame();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.refresh, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Play Again',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          Navigator.of(context).pop(); // Exit game
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.exit_to_app, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Exit',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Session mode: Show Next Game button
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(
                      context,
                    ).pop(); // Exit game and return to session screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Next Game',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
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
