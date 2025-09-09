import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/background_music_manager.dart';
import '../utils/sound_effects_manager.dart';
import '../utils/difficulty_utils.dart';

enum TicTacToeDifficulty { easy, medium, hard }

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
  })
  onGameComplete;

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

class _TicTacToeGameScreenState extends State<TicTacToeGameScreen> {
  List<String> board = List.filled(9, '');
  bool xTurn = true;
  bool gameOver = false;
  String winner = '';
  late TicTacToeDifficulty difficulty;
  int win = 0, loss = 0, draw = 0;

  // Best of 3 match state
  int matchPlayerWins = 0;
  int matchAIWins = 0;
  int matchDraws = 0;
  int matchGame = 1;
  bool matchOver = false;

  @override
  void initState() {
    super.initState();
    // Start background music for this game
    BackgroundMusicManager().startGameMusic('TicTacToe');
    // Convert string difficulty to enum
    switch (widget.difficulty.toLowerCase()) {
      case 'easy':
        difficulty = TicTacToeDifficulty.easy;
        break;
      case 'medium':
        difficulty = TicTacToeDifficulty.medium;
        break;
      case 'hard':
        difficulty = TicTacToeDifficulty.hard;
        break;
      default:
        difficulty = TicTacToeDifficulty.easy;
    }
    _loadRecords();
  }

  @override
  void dispose() {
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

  void _makeMove(int idx) {
    if (board[idx] != '' || gameOver) return;
    setState(() {
      board[idx] = xTurn ? 'square' : 'triangle';
      xTurn = !xTurn;
    });
    _checkGameOver();
    if (!gameOver && !xTurn) {
      Future.delayed(const Duration(milliseconds: 400), _aiMove);
    }
  }

  void _aiMove() {
    int move = _findBestMove();
    setState(() {
      board[move] = 'triangle';
      xTurn = true;
    });
    _checkGameOver();
  }

  int _findBestMove() {
    // Easy: random, Medium: block/win, Hard: minimax
    List<int> empty = [];
    for (int i = 0; i < 9; i++) if (board[i] == '') empty.add(i);
    if (difficulty == TicTacToeDifficulty.easy) {
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
    if (difficulty == TicTacToeDifficulty.medium) {
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
      // Play success sound with voice effect
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
    if (matchPlayerWins == 2 || matchAIWins == 2 || matchGame == 3) {
      setState(() {
        matchOver = true;
      });
      await Future.delayed(const Duration(milliseconds: 500));
      String result;
      if (matchPlayerWins > matchAIWins) {
        result = 'Congratulations! You won the best of 3!';
      } else if (matchAIWins > matchPlayerWins) {
        result = 'AI won the best of 3!';
      } else {
        result = 'It\'s a draw!';
      }
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Match Over'),
            content: Text(
              '$result\n\nPlayer: $matchPlayerWins\nAI: $matchAIWins\nDraws: $matchDraws',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                  widget.onGameComplete(
                    accuracy: 100 * matchPlayerWins ~/ matchGame,
                    completionTime: 30 * matchGame,
                    challengeFocus: widget.challengeFocus,
                    gameName: widget.gameName,
                    difficulty: widget.difficulty,
                  );
                },
                child: const Text('OK'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _resetMatch();
                },
                child: const Text('Play Again'),
              ),
            ],
          ),
        );
      }
    } else {
      setState(() {
        matchGame++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('TicTacToe (vs AI)'),
        backgroundColor: Colors.orange,
        actions: [
          PopupMenuButton<TicTacToeDifficulty>(
            icon: const Icon(Icons.settings),
            onSelected: (d) => setState(() => difficulty = d),
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: TicTacToeDifficulty.easy,
                child: Text('Easy'),
              ),
              const PopupMenuItem(
                value: TicTacToeDifficulty.medium,
                child: Text('Medium'),
              ),
              const PopupMenuItem(
                value: TicTacToeDifficulty.hard,
                child: Text('Hard'),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Difficulty: ${DifficultyUtils.getDifficultyDisplayName(widget.difficulty)}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 12),
            Text('Game $matchGame of 3', style: const TextStyle(fontSize: 18)),
            Text(
              'Player: $matchPlayerWins  |  AI: $matchAIWins  |  Draws: $matchDraws',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                ),
                itemCount: 9,
                itemBuilder: (context, idx) => GestureDetector(
                  onTap: () => _makeMove(idx),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange, width: 2),
                    ),
                    child: Center(
                      child: board[idx] == 'square'
                          ? Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            )
                          : board[idx] == 'triangle'
                          ? CustomPaint(
                              size: const Size(40, 40),
                              painter: TrianglePainter(),
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
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: matchOver ? null : _resetBoard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Next Game'),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            Card(
              color: Colors.white,
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.orange),
                    const SizedBox(width: 12),
                    Text('Wins: $win', style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 18),
                    const Icon(Icons.close, color: Colors.purple),
                    const SizedBox(width: 12),
                    Text('Losses: $loss', style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 18),
                    const Icon(Icons.remove, color: Colors.grey),
                    const SizedBox(width: 12),
                    Text('Draws: $draw', style: const TextStyle(fontSize: 18)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.purple
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
