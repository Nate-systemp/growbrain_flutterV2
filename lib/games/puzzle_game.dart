import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import '../utils/background_music_manager.dart';
import '../utils/sound_effects_manager.dart';
import '../utils/difficulty_utils.dart';

class PuzzleGame extends StatefulWidget {
  final String difficulty;
  final Function({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })? onGameComplete;

  const PuzzleGame({
    Key? key,
    required this.difficulty,
    this.onGameComplete,
  }) : super(key: key);

  @override
  _PuzzleGameState createState() => _PuzzleGameState();
}

class PuzzlePiece {
  final int id;
  final String emoji;
  final int correctRow;
  final int correctCol;
  int currentRow;
  int currentCol;
  bool isPlaced;
  bool isDragging;
  
  PuzzlePiece({
    required this.id,
    required this.emoji,
    required this.correctRow,
    required this.correctCol,
    required this.currentRow,
    required this.currentCol,
    this.isPlaced = false,
    this.isDragging = false,
  });
}

class _PuzzleGameState extends State<PuzzleGame> {
  List<PuzzlePiece> puzzlePieces = [];
  List<List<PuzzlePiece?>> puzzleGrid = [];
  List<PuzzlePiece> availablePieces = [];
  int gridSize = 2; // 2x2 for easy
  int score = 0;
  int movesCount = 0;
  int placedPieces = 0;
  bool gameStarted = false;
  bool gameActive = false;
  bool showReference = true;
  late DateTime gameStartTime;
  Timer? gameTimer;
  int timeLeft = 0;
  String currentPuzzleTheme = 'Animals';
  
  Random random = Random();
  
  // Puzzle themes with emoji patterns
  final Map<String, Map<String, dynamic>> puzzleThemes = {
    'Animals': {
      '2x2': [
        ['🐱', '🐶'],
        ['🐭', '🐸'],
      ],
      '3x3': [
        ['🐱', '🐶', '🐰'],
        ['🐭', '🐸', '🐯'],
        ['🦁', '🐼', '🐨'],
      ],
      '4x4': [
        ['🐱', '🐶', '🐰', '🐹'],
        ['🐭', '🐸', '🐯', '🦊'],
        ['🦁', '🐼', '🐨', '🐷'],
        ['🐮', '🐵', '🐔', '🦆'],
      ],
    },
    'Nature': {
      '2x2': [
        ['🌸', '🌳'],
        ['🌻', '🍄'],
      ],
      '3x3': [
        ['🌸', '🌳', '🌺'],
        ['🌻', '🍄', '🌿'],
        ['🌵', '🌾', '🍀'],
      ],
      '4x4': [
        ['🌸', '🌳', '🌺', '🌴'],
        ['🌻', '🍄', '🌿', '🌷'],
        ['🌵', '🌾', '🍀', '🌼'],
        ['🌱', '🌲', '🌹', '🌙'],
      ],
    },
    'Food': {
      '2x2': [
        ['🍎', '🍌'],
        ['🍊', '🍇'],
      ],
      '3x3': [
        ['🍎', '🍌', '🍊'],
        ['🍇', '🍓', '🥝'],
        ['🍑', '🍒', '🥭'],
      ],
      '4x4': [
        ['🍎', '🍌', '🍊', '🍇'],
        ['🍓', '🥝', '🍑', '🍒'],
        ['🥭', '🍍', '🥥', '🍉'],
        ['🍋', '🍈', '🫐', '🍅'],
      ],
    },
  };
  
  // Soft, accessible colors
  final Color backgroundColor = Color(0xFFF8F9FA);
  final Color gridColor = Color(0xFFE0E0E0);
  final Color pieceColor = Color(0xFFFFFFFF);
  final Color placedColor = Color(0xFF81C784); // Soft green
  final Color dragColor = Color(0xFFFFF176); // Soft yellow

  @override
  void initState() {
    super.initState();
    // Start background music for this game
    BackgroundMusicManager().startGameMusic('Puzzle');
    _initializeGame();
  }

  void _initializeGame() {
    // Set difficulty parameters
    switch (widget.difficulty.toLowerCase()) {
      case 'easy':
        gridSize = 2; // 2x2 = 4 pieces
        showReference = true;
        timeLeft = 0; // No timer for easy
        break;
      case 'medium':
        gridSize = 3; // 3x3 = 9 pieces
        showReference = false; // Optional reference
        timeLeft = 180; // 3 minutes
        break;
      case 'hard':
        gridSize = 4; // 4x4 = 16 pieces
        showReference = false; // No reference
        timeLeft = 300; // 5 minutes
        break;
      default:
        gridSize = 2;
        showReference = true;
        timeLeft = 0;
    }
    
    _setupPuzzle();
  }

  void _setupPuzzle() {
    puzzlePieces.clear();
    availablePieces.clear();
    placedPieces = 0;
    movesCount = 0;
    
    // Select random theme
    List<String> themes = puzzleThemes.keys.toList();
    currentPuzzleTheme = themes[random.nextInt(themes.length)];
    
    String gridKey = '${gridSize}x${gridSize}';
    List<List<String>> pattern = puzzleThemes[currentPuzzleTheme]![gridKey];
    
    // Initialize grid
    puzzleGrid = List.generate(gridSize, 
      (row) => List.generate(gridSize, (col) => null)
    );
    
    // Create puzzle pieces
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        int pieceId = row * gridSize + col;
        puzzlePieces.add(PuzzlePiece(
          id: pieceId,
          emoji: pattern[row][col],
          correctRow: row,
          correctCol: col,
          currentRow: -1, // Not placed initially
          currentCol: -1,
        ));
      }
    }
    
    // Shuffle pieces for available pieces list
    availablePieces = List.from(puzzlePieces);
    availablePieces.shuffle();
    
    setState(() {});
  }

  void _startGame() {
    setState(() {
      gameStarted = true;
      gameActive = true;
      gameStartTime = DateTime.now();
      score = 0;
      movesCount = 0;
      placedPieces = 0;
    });
    
    _showInstructions();
  }

  void _showInstructions() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFFF8F9FA),
        title: Text('Puzzle Instructions', style: TextStyle(color: Color(0xFF2C3E50))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Assemble the puzzle!',
              style: TextStyle(color: Color(0xFF2C3E50), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              '• Drag pieces from the bottom area\n• Drop them in the correct grid positions\n• Complete the ${gridSize}x${gridSize} ${currentPuzzleTheme.toLowerCase()} pattern\n• ${showReference ? "Reference image is shown" : "No reference - use your memory!"}',
              style: TextStyle(color: Color(0xFF2C3E50)),
              textAlign: TextAlign.left,
            ),
            if (timeLeft > 0) ...[
              SizedBox(height: 8),
              Text(
                'Time limit: ${timeLeft ~/ 60}m ${timeLeft % 60}s',
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
            child: Text('Start Puzzle!', style: TextStyle(color: Color(0xFF81C784))),
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

  void _onPiecePlaced(PuzzlePiece piece, int targetRow, int targetCol) {
    if (!gameActive) return;
    
    movesCount++;
    
    // Remove piece from its current position if it was placed
    if (piece.currentRow >= 0 && piece.currentCol >= 0) {
      puzzleGrid[piece.currentRow][piece.currentCol] = null;
      placedPieces--;
    }
    
    // Remove any piece currently in the target position
    if (puzzleGrid[targetRow][targetCol] != null) {
      var displaced = puzzleGrid[targetRow][targetCol]!;
      displaced.currentRow = -1;
      displaced.currentCol = -1;
      displaced.isPlaced = false;
      availablePieces.add(displaced);
      placedPieces--;
    }
    
    // Place the new piece
    puzzleGrid[targetRow][targetCol] = piece;
    piece.currentRow = targetRow;
    piece.currentCol = targetCol;
    piece.isPlaced = true;
    availablePieces.remove(piece);
    placedPieces++;
    
    // Check if piece is in correct position
    if (targetRow == piece.correctRow && targetCol == piece.correctCol) {
      score += 20; // Bonus for correct placement
      HapticFeedback.mediumImpact();
      // Play success sound with voice effect
      SoundEffectsManager().playSuccessWithVoice();
    } else {
      HapticFeedback.lightImpact();
    }
    
    setState(() {});
    
    // Check if puzzle is complete
    if (_isPuzzleComplete()) {
      gameTimer?.cancel();
      _puzzleComplete();
    }
  }

  bool _isPuzzleComplete() {
    if (placedPieces != gridSize * gridSize) return false;
    
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        var piece = puzzleGrid[row][col];
        if (piece == null || piece.correctRow != row || piece.correctCol != col) {
          return false;
        }
      }
    }
    return true;
  }

  void _puzzleComplete() {
    // Bonus points for completion
    score += 100;
    if (timeLeft > 0) {
      score += timeLeft; // Time bonus
    }
    
    HapticFeedback.heavyImpact();
    _endGame();
  }

  void _endGame() {
    setState(() {
      gameActive = false;
    });
    
    gameTimer?.cancel();
    
    // Calculate game statistics
    int totalPieces = gridSize * gridSize;
    double accuracyDouble = totalPieces > 0 ? (placedPieces / totalPieces) * 100 : 0;
    int accuracy = accuracyDouble.round();
    int completionTime = DateTime.now().difference(gameStartTime).inSeconds;
    
    // Call completion callback if provided
    if (widget.onGameComplete != null) {
      widget.onGameComplete!(
        accuracy: accuracy,
        completionTime: completionTime,
        challengeFocus: 'Logic',
        gameName: 'Puzzle',
        difficulty: widget.difficulty,
      );
    }
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    // Stop background music when leaving the game
    BackgroundMusicManager().stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Puzzle - ${DifficultyUtils.getDifficultyDisplayName(widget.difficulty)}'),
        backgroundColor: Color(0xFFFFCC80), // Soft orange
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
                      Text('Moves: $movesCount', style: TextStyle(fontSize: 14, color: Color(0xFF2C3E50))),
                    ],
                  ),
                  Column(
                    children: [
                      Text('Placed: $placedPieces/${gridSize * gridSize}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                      Text('Theme: $currentPuzzleTheme', style: TextStyle(fontSize: 14, color: Color(0xFF2C3E50))),
                    ],
                  ),
                  if (timeLeft > 0)
                    Column(
                      children: [
                        Text('Time: ${timeLeft ~/ 60}:${(timeLeft % 60).toString().padLeft(2, '0')}', 
                             style: TextStyle(fontSize: 16, color: timeLeft <= 30 ? Color(0xFFE57373) : Color(0xFF2C3E50), fontWeight: FontWeight.bold)),
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
          Icons.extension,
          size: 80,
          color: Color(0xFFFFCC80),
        ),
        SizedBox(height: 20),
        Text(
          'Puzzle Game',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 20),
        Text(
          'Difficulty: ${DifficultyUtils.getDifficultyDisplayName(widget.difficulty)}',
          style: TextStyle(fontSize: 24, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 20),
        Text(
          '${gridSize}x${gridSize} ${currentPuzzleTheme} puzzle',
          style: TextStyle(fontSize: 18, color: Color(0xFF2C3E50)),
        ),
        if (showReference)
          Text(
            'Reference image shown',
            style: TextStyle(fontSize: 16, color: Color(0xFF81C784)),
          ),
        SizedBox(height: 40),
        ElevatedButton(
          onPressed: _startGame,
          child: Text('Start Puzzle'),
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
    if (!gameActive && _isPuzzleComplete()) {
      return _buildWinScreen();
    }
    
    if (!gameActive) {
      return _buildTimeUpScreen();
    }
    
    return Column(
      children: [
        // Reference image (if enabled)
        if (showReference) ...[
          Container(
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Color(0xFFE8F5E8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'Reference Image',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                ),
                SizedBox(height: 8),
                _buildReferenceGrid(),
              ],
            ),
          ),
        ],
        
        // Puzzle Grid
        Expanded(
          flex: 2,
          child: Container(
            padding: EdgeInsets.all(16),
            child: _buildPuzzleGrid(),
          ),
        ),
        
        // Available Pieces
        Container(
          height: 120,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFFF3E5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                'Drag Pieces Here',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
              ),
              SizedBox(height: 8),
              Expanded(
                child: _buildAvailablePieces(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReferenceGrid() {
    String gridKey = '${gridSize}x${gridSize}';
    List<List<String>> pattern = puzzleThemes[currentPuzzleTheme]![gridKey];
    
    return Container(
      width: 120,
      height: 120,
      child: GridView.builder(
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: gridSize,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: gridSize * gridSize,
        itemBuilder: (context, index) {
          int row = index ~/ gridSize;
          int col = index % gridSize;
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                pattern[row][col],
                style: TextStyle(fontSize: 16),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPuzzleGrid() {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridSize,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: gridSize * gridSize,
      itemBuilder: (context, index) {
        int row = index ~/ gridSize;
        int col = index % gridSize;
        return _buildGridSlot(row, col);
      },
    );
  }

  Widget _buildGridSlot(int row, int col) {
    PuzzlePiece? piece = puzzleGrid[row][col];
    bool isCorrect = piece != null && piece.correctRow == row && piece.correctCol == col;
    
    return DragTarget<PuzzlePiece>(
      onAccept: (piece) => _onPiecePlaced(piece, row, col),
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            color: piece != null 
                ? (isCorrect ? placedColor : pieceColor)
                : gridColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: candidateData.isNotEmpty ? dragColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: piece != null
              ? Center(
                  child: Text(
                    piece.emoji,
                    style: TextStyle(fontSize: 24),
                  ),
                )
              : Center(
                  child: Icon(
                    Icons.add,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                ),
        );
      },
    );
  }

  Widget _buildAvailablePieces() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: availablePieces.map((piece) => _buildDraggablePiece(piece)).toList(),
      ),
    );
  }

  Widget _buildDraggablePiece(PuzzlePiece piece) {
    return Draggable<PuzzlePiece>(
      data: piece,
      child: _buildPieceWidget(piece, false),
      feedback: _buildPieceWidget(piece, true),
      childWhenDragging: Container(
        width: 60,
        height: 60,
        margin: EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildPieceWidget(PuzzlePiece piece, bool isDragging) {
    return Container(
      width: 60,
      height: 60,
      margin: EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDragging ? dragColor : pieceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFE0E0E0)),
        boxShadow: isDragging ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ] : [],
      ),
      child: Center(
        child: Text(
          piece.emoji,
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  Widget _buildWinScreen() {
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
          'Puzzle Complete!',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
        SizedBox(height: 20),
        Text(
          'Final Score: $score',
          style: TextStyle(fontSize: 24, color: Color(0xFF2C3E50)),
        ),
        Text(
          'Moves: $movesCount',
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
          child: Text('New Puzzle'),
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
            backgroundColor: Color(0xFFFFCC80),
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
          'Pieces placed: $placedPieces/${gridSize * gridSize}',
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
            backgroundColor: Color(0xFFFFCC80),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
