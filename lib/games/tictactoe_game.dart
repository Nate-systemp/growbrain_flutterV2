import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import '../utils/background_music_manager.dart';
import '../utils/sound_effects_manager.dart';
import '../utils/difficulty_utils.dart';

enum TicTacToeDifficulty { starter, growing, challenged }

class TicTacToeGameScreen extends StatefulWidget {
  final String difficulty;
  final String challengeFocus;
  final String gameName;
  final Function({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })? onGameComplete;

  const TicTacToeGameScreen({
    Key? key,
    required this.difficulty,
    required this.challengeFocus,
    required this.gameName,
    required this.onGameComplete,
  }) : super(key: key);

  @override
  State<TicTacToeGameScreen> createState() => _TicTacToeGameScreenState();
}

class _TicTacToeGameScreenState extends State<TicTacToeGameScreen> with TickerProviderStateMixin {
  List<String> board = List.filled(9, '');
  bool xTurn = true;
  bool gameOver = false;
  String winner = '';
  late TicTacToeDifficulty difficulty;
  int win = 0, loss = 0, draw = 0;
  bool gameStarted = false;
  DateTime? lastClickTime;

  // Countdown state
  bool showingCountdown = false;
  int countdownNumber = 3;

  // GO overlay
  bool showingGo = false;
  late final AnimationController _goController;
  late final Animation<double> _goOpacity;
  late final Animation<double> _goScale;

  // App color scheme
  final Color primaryColor = const Color(0xFF5B6F4A);
  final Color accentColor = const Color(0xFFFFD740);
  final Color backgroundColor = const Color(0xFFF5F5DC);

  // Best of 3 match state
  int matchPlayerWins = 0;
  int matchAIWins = 0;
  int matchDraws = 0;
  int matchGame = 1;
  bool matchOver = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize GO animation controller
    _goController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _goOpacity = CurvedAnimation(parent: _goController, curve: Curves.easeInOut);
    _goScale = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(parent: _goController, curve: Curves.easeOutBack),
    );
    
    // Start background music for this game
    BackgroundMusicManager().startGameMusic('TicTacToe');
    // Normalize incoming/display difficulty and convert to enum
    final _diff = DifficultyUtils.normalizeDifficulty(widget.difficulty).toLowerCase();
    // Convert string difficulty to enum
    switch (_diff) {
      case 'starter':
        difficulty = TicTacToeDifficulty.starter;
        break;
      case 'growing':
        difficulty = TicTacToeDifficulty.growing;
        break;
      case 'challenged':
        difficulty = TicTacToeDifficulty.challenged;
        break;
      default:
        difficulty = TicTacToeDifficulty.starter;
    }
    _loadRecords();
  }

  @override
  void dispose() {
    _goController.dispose();
    // Stop background music when leaving the game
    BackgroundMusicManager().stopMusic();
    super.dispose();
  }

  void _loadRecords() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('tictactoe_records')
        .doc(user.uid)
        .get();
    if (doc.exists) {
      setState(() {
        win = doc['win'] ?? 0;
        loss = doc['loss'] ?? 0;
        draw = doc['draw'] ?? 0;
      });
    }
  }

  void _saveRecord(String result) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref = FirebaseFirestore.instance
        .collection('tictactoe_records')
        .doc(user.uid);
    if (result == 'win') win++;
    if (result == 'loss') loss++;
    if (result == 'draw') draw++;
    await ref.set({'win': win, 'loss': loss, 'draw': draw});
  }

  void _resetBoard() {
    setState(() {
      board = List.filled(9, '');
      xTurn = true;
      gameOver = false;
      winner = '';
      lastClickTime = null;
    });
  }

  void _resetMatch() {
    setState(() {
      matchPlayerWins = 0;
      matchAIWins = 0;
      matchDraws = 0;
      matchGame = 1;
      matchOver = false;
      _resetBoard();
    });
  }

  void _resetGame() {
    _resetMatch();
    setState(() {
      gameStarted = false;
      showingCountdown = false;
    });
  }

  void _startGame() {
    setState(() {
      showingCountdown = true;
      countdownNumber = 3;
    });
    _showCountdown();
  }

  void _showCountdown() async {
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => countdownNumber = i);
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    if (mounted) {
      setState(() {
        showingCountdown = false;
        gameStarted = true;
      });
      await _showGoOverlay();
    }
  }

  Future<void> _showGoOverlay() async {
    if (!mounted) return;
    setState(() => showingGo = true);
    await _goController.forward();
    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    await _goController.reverse();
    if (!mounted) return;
    setState(() => showingGo = false);
  }

  void _makeMove(int idx) {
    if (!gameStarted || board[idx] != '' || gameOver || showingGo) return;

    // Add click interval to prevent spam clicking
    DateTime now = DateTime.now();
    if (lastClickTime != null &&
        now.difference(lastClickTime!).inMilliseconds < 300) {
      return;
    }
    lastClickTime = now;

    setState(() {
      board[idx] = xTurn ? 'square' : 'triangle';
      xTurn = !xTurn;
    });
    _checkGameOver();
    if (!gameOver && !xTurn) {
      Future.delayed(const Duration(seconds: 1), _aiMove);
    }
  }

  void _aiMove() {
    if (!mounted || gameOver) return;
    int move = _findBestMove();
    setState(() {
      board[move] = 'triangle';
      xTurn = true;
    });
    _checkGameOver();
  }

  int _findBestMove() {
    List<int> empty = [];
    for (int i = 0; i < 9; i++) if (board[i] == '') empty.add(i);
    if (difficulty == TicTacToeDifficulty.starter) {
      empty.shuffle();
      return empty.first;
    }
    // Medium: block or win
    for (int i in empty) {
      board[i] = 'triangle';
      if (_checkWinner('triangle')) {
        board[i] = '';
        return i;
      }
      board[i] = '';
    }
    for (int i in empty) {
      board[i] = 'square';
      if (_checkWinner('square')) {
        board[i] = '';
        return i;
      }
      board[i] = '';
    }
    if (difficulty == TicTacToeDifficulty.growing) {
      empty.shuffle();
      return empty.first;
    }
    // Hard: minimax
    int bestScore = -1000;
    int bestMove = empty.first;
    for (int i in empty) {
      board[i] = 'triangle';
      int score = _minimax(false);
      board[i] = '';
      if (score > bestScore) {
        bestScore = score;
        bestMove = i;
      }
    }
    return bestMove;
  }

  int _minimax(bool isMax) {
    if (_checkWinner('triangle')) return 1;
    if (_checkWinner('square')) return -1;
    if (board.every((e) => e != '')) return 0;
    List<int> empty = [];
    for (int i = 0; i < 9; i++) if (board[i] == '') empty.add(i);
    if (isMax) {
      int best = -1000;
      for (int i in empty) {
        board[i] = 'triangle';
        best = best > _minimax(false) ? best : _minimax(false);
        board[i] = '';
      }
      return best;
    } else {
      int best = 1000;
      for (int i in empty) {
        board[i] = 'square';
        best = best < _minimax(true) ? best : _minimax(true);
        board[i] = '';
      }
      return best;
    }
  }

  bool _checkWinner(String player) {
    const wins = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];
    for (var w in wins) {
      if (board[w[0]] == player &&
          board[w[1]] == player &&
          board[w[2]] == player) {
        return true;
      }
    }
    return false;
  }

  void _checkGameOver() {
    if (_checkWinner('square')) {
      setState(() {
        gameOver = true;
        winner = 'You win!';
        matchPlayerWins++;
      });
      SoundEffectsManager().playSuccessWithVoice();
      _saveRecord('win');
      _handleMatchProgress();
    } else if (_checkWinner('triangle')) {
      setState(() {
        gameOver = true;
        winner = 'AI wins!';
        matchAIWins++;
      });
      _saveRecord('loss');
      _handleMatchProgress();
    } else if (board.every((e) => e != '')) {
      setState(() {
        gameOver = true;
        winner = 'Draw!';
        matchDraws++;
      });
      _saveRecord('draw');
      _handleMatchProgress();
    }
  }

  void _handleMatchProgress() async {
    // Wait a moment to show the result
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (matchPlayerWins == 2 || matchAIWins == 2 || matchGame == 3) {
      setState(() {
        matchOver = true;
      });
      if (context.mounted) {
        _showMatchOverDialog();
      }
    } else {
      // Move to next game
      setState(() {
        matchGame++;
      });
      // Reset board for next game
      _resetBoard();
    }
  }

  void _showMatchOverDialog() {
    String result;
    if (matchPlayerWins > matchAIWins) {
      result = 'Amazing! 🌟';
    } else if (matchAIWins > matchPlayerWins) {
      result = 'Good Try! 💪';
    } else {
      result = 'It\'s a Draw! 🤝';
    }

    int accuracy = ((matchPlayerWins / 3) * 100).round();

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
                matchPlayerWins > matchAIWins ? Icons.celebration : Icons.emoji_events,
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
              _buildStatRow(Icons.emoji_events, 'Player Wins', '$matchPlayerWins'),
              const SizedBox(height: 12),
              _buildStatRow(Icons.smart_toy, 'AI Wins', '$matchAIWins'),
              const SizedBox(height: 12),
              _buildStatRow(Icons.handshake, 'Draws', '$matchDraws'),
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
                    completionTime: 30 * matchGame,
                    challengeFocus: widget.challengeFocus,
                    gameName: widget.gameName,
                    difficulty: widget.difficulty,
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
            SafeArea(
              child: showingCountdown
                  ? _buildCountdownScreen()
                  : (!gameStarted ? _buildStartScreen() : _buildGameScreen()),
            ),
            // GO overlay
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
                              const Text(
                                'Get Ready!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black26,
                                      offset: Offset(2, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
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
                                      color: primaryColor,
                                      fontSize: 54,
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

  Widget _buildCountdownScreen() {
    return Center(
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
              color: const Color(0xFF3E2723), // Dark brown
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
                '$countdownNumber',
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
              color: Colors.white.withOpacity(0.9),
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
                'Tic Tac Toe',
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
                  Icons.grid_3x3,
                  size: isTablet ? 56 : 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Beat the AI!',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: isTablet ? 22 : 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Play against the AI in a best of 3 match! You are squares ⬜, AI is triangles 🔺. Get three in a row to win!',
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

  Widget _buildGameScreen() {
    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Game $matchGame of 3',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        offset: Offset(1, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Turn Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: xTurn
                        ? const Color(0xFFE8F5E8)
                        : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: xTurn
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFFF9800),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (xTurn) ...[
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Your Turn',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CustomPaint(
                            painter: TrianglePainter(color: primaryColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'AI Thinking...',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8)
                    ],
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1,
                    ),
                    itemCount: 9,
                    itemBuilder: (context, idx) => GestureDetector(
                      onTap: xTurn ? () => _makeMove(idx) : null,
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: xTurn ? Colors.white : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: xTurn ? primaryColor : Colors.grey[300]!,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(xTurn ? 0.1 : 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: board[idx] == 'square'
                              ? Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: accentColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                )
                              : board[idx] == 'triangle'
                                  ? CustomPaint(
                                      size: const Size(40, 40),
                                      painter: TrianglePainter(color: primaryColor),
                                    )
                                  : const SizedBox(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (gameOver && !matchOver)
                  Column(
                    children: [
                      Text(
                        winner,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              offset: Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: matchOver ? null : _resetBoard,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          'Next Game',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        // HUD - Left side (Player Wins)
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 90),
            child: _infoCircle(
              label: 'Player',
              value: '$matchPlayerWins',
              circleSize: 80,
              valueFontSize: 28,
              labelFontSize: 16,
            ),
          ),
        ),
        // HUD - Right side (AI Wins)
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 90),
            child: _infoCircle(
              label: 'AI',
              value: '$matchAIWins',
              circleSize: 80,
              valueFontSize: 28,
              labelFontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoCircle({
    required String label,
    required String value,
    double circleSize = 80,
    double valueFontSize = 24,
    double labelFontSize = 14,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: labelFontSize,
            fontWeight: FontWeight.w800,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.45),
                offset: const Offset(2, 2),
                blurRadius: 0,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            color: Colors.white,
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
              color: primaryColor,
              fontSize: valueFontSize,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class TrianglePainter extends CustomPainter {
  final Color color;

  TrianglePainter({this.color = Colors.purple});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
