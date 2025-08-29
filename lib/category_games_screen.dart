import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'games/light_tap_game.dart';
import 'games/who_moved_game.dart';
import 'games/find_me_game.dart';
import 'games/fruit_shuffle_game.dart';
import 'games/match_cards_game.dart';
import 'games/object_hunt_game.dart';
import 'games/picture_words_game.dart';
import 'games/puzzle_game.dart';
import 'games/rhyme_time_game.dart';
import 'games/riddle_game.dart';
import 'games/sound_match_game.dart';
import 'games/tictactoe_game.dart';

class CategoryGamesScreen extends StatefulWidget {
  final String category;
  final bool isDemoMode;

  const CategoryGamesScreen({
    Key? key,
    required this.category,
    this.isDemoMode = false,
  }) : super(key: key);

  @override
  _CategoryGamesScreenState createState() => _CategoryGamesScreenState();
}

class _CategoryGamesScreenState extends State<CategoryGamesScreen> {
  // Define category to game mappings
  final Map<String, List<Map<String, dynamic>>> categoryGames = {
    'Attention': [
      {
        'name': 'Light Tap',
        'icon': Icons.lightbulb_outline,
        'color': Colors.amber,
        'game': LightTapGame(difficulty: 'Easy', requirePinOnExit: false),
      },
      {
        'name': 'Who Moved',
        'icon': Icons.swap_horiz,
        'color': Colors.blue,
        'game': WhoMovedGame(difficulty: 'Easy'),
      },
      {
        'name': 'Find Me',
        'icon': Icons.search,
        'color': Colors.green,
        'game': FindMeGame(difficulty: 'Easy'),
      },
    ],
    'Verbal': [
      {
        'name': 'Rhyme Time',
        'icon': Icons.music_note,
        'color': Colors.purple,
        'game': RhymeTimeGame(difficulty: 'Easy'),
      },
      {
        'name': 'Picture Words',
        'icon': Icons.image,
        'color': Colors.orange,
        'game': PictureWordsGame(difficulty: 'Easy'),
      },
      {
        'name': 'Riddle',
        'icon': Icons.psychology,
        'color': Colors.teal,
        'game': RiddleGame(difficulty: 'Easy'),
      },
    ],
    'Memory': [
      {
        'name': 'Match Cards',
        'icon': Icons.style,
        'color': Colors.red,
        'game': MatchCardsGame(
          difficulty: 'Easy',
          challengeFocus: 'Memory',
          gameName: 'Match Cards',
        ),
      },
      {
        'name': 'Fruit Shuffle',
        'icon': Icons.local_florist,
        'color': Colors.pink,
        'game': FruitShuffleGame(
          difficulty: 'Easy',
          challengeFocus: 'Memory',
          gameName: 'Fruit Shuffle',
        ),
      },
      {
        'name': 'Sound Match',
        'icon': Icons.hearing,
        'color': Colors.indigo,
        'game': SoundMatchGame(difficulty: 'Easy'),
      },
    ],
    'Logic': [
      {
        'name': 'Puzzle',
        'icon': Icons.extension,
        'color': Colors.deepOrange,
        'game': PuzzleGame(difficulty: 'Easy'),
      },
      {
        'name': 'Tic Tac Toe',
        'icon': Icons.grid_on,
        'color': Colors.cyan,
        'game': TicTacToeGameScreen(
          difficulty: 'Easy',
          challengeFocus: 'Logic',
          gameName: 'Tic Tac Toe',
          onGameComplete: ({required int accuracy, required int completionTime, required String challengeFocus, required String gameName, required String difficulty}) {},
        ),
      },
      {
        'name': 'Object Hunt',
        'icon': Icons.visibility,
        'color': Colors.brown,
        'game': ObjectHuntGame(difficulty: 'Easy'),
      },
    ],
  };

  @override
  Widget build(BuildContext context) {
    final games = categoryGames[widget.category] ?? [];
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: const Color(0xFF5B6F4A),
      appBar: AppBar(
        title: Text(
          '${widget.category} Games${widget.isDemoMode ? ' (Demo)' : ''}',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: const Color(0xFF5B6F4A),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenSize.width * 0.08,
            vertical: 40,
          ),
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              childAspectRatio: 0.95,
            ),
            itemCount: games.length,
            itemBuilder: (context, index) {
              final game = games[index];
              return _GameCard(
                icon: game['icon'] as IconData,
                iconColor: game['color'] as Color,
                label: game['name'] as String,
                onTap: () => _startGame(context, game),
              );
            },
          ),
        ),
      ),
    );
  }

  void _startGame(BuildContext context, Map<String, dynamic> game) {
    if (widget.isDemoMode) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => _getDemoGameWidget(game),
        ),
      );
    } else {
      _showDifficultyDialog(context, game);
    }
  }

  Widget _getDemoGameWidget(Map<String, dynamic> game) {
    final gameWidget = game['game'] as Widget;
    if (gameWidget is LightTapGame) {
      return LightTapGame(
        difficulty: 'Starter',
        onGameComplete: null,
      );
    } else if (gameWidget is WhoMovedGame) {
      return WhoMovedGame(
        difficulty: 'Starter',
        onGameComplete: null,
      );
    } else if (gameWidget is FindMeGame) {
      return FindMeGame(
        difficulty: 'Starter',
        onGameComplete: null,
      );
    }
    return gameWidget;
  }

  void _showDifficultyDialog(BuildContext context, Map<String, dynamic> game) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Container(
          width: 340,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Text(
                    'Select Difficulty',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Nunito',
                      color: Color(0xFF393C48),
                    ),
                  ),
                ),
              ),
              ListTile(
                title: Text('Starter'),
                onTap: () => _startGameWithDifficulty(context, game, 'Starter'),
              ),
              ListTile(
                title: Text('Growing'),
                onTap: () => _startGameWithDifficulty(context, game, 'Growing'),
              ),
              ListTile(
                title: Text('Challenge'),
                onTap: () => _startGameWithDifficulty(context, game, 'Challenge'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startGameWithDifficulty(BuildContext context, Map<String, dynamic> game, String difficulty) {
    Navigator.of(context).pop();
    
    final gameName = game['name'] as String;
    final gameWidget = _createGameWithDifficulty(gameName, difficulty);
    
    if (gameWidget != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => gameWidget,
        ),
      );
    }
  }

  Widget? _createGameWithDifficulty(String gameName, String difficulty) {
    switch (gameName) {
      case 'Light Tap':
        return LightTapGame(
          difficulty: difficulty,
          onGameComplete: _recordGameProgress,
        );
      case 'Who Moved':
        return WhoMovedGame(
          difficulty: difficulty,
          onGameComplete: _recordGameProgress,
        );
      case 'Find Me':
        return FindMeGame(
          difficulty: difficulty,
          onGameComplete: _recordGameProgress,
        );
      case 'Rhyme Time':
        return RhymeTimeGame(
          difficulty: difficulty,
          onGameComplete: _recordGameProgress,
        );
      case 'Picture Words':
        return PictureWordsGame(
          difficulty: difficulty,
          onGameComplete: _recordGameProgress,
        );
      case 'Riddle':
        return RiddleGame(
          difficulty: difficulty,
          onGameComplete: _recordGameProgress,
        );
      case 'Match Cards':
        return MatchCardsGame(
          difficulty: difficulty,
          challengeFocus: 'Memory',
          gameName: 'Match Cards',
          onGameComplete: _recordGameProgress,
        );
      case 'Fruit Shuffle':
        return FruitShuffleGame(
          difficulty: difficulty,
          challengeFocus: 'Memory',
          gameName: 'Fruit Shuffle',
          onGameComplete: _recordGameProgress,
        );
      case 'Sound Match':
        return SoundMatchGame(
          difficulty: difficulty,
          onGameComplete: _recordGameProgress,
        );
      case 'Puzzle':
        return PuzzleGame(
          difficulty: difficulty,
          onGameComplete: _recordGameProgress,
        );
      case 'Tic Tac Toe':
        return TicTacToeGameScreen(
          difficulty: difficulty,
          challengeFocus: 'Logic',
          gameName: 'Tic Tac Toe',
          onGameComplete: _recordGameProgress,
        );
      case 'Object Hunt':
        return ObjectHuntGame(
          difficulty: difficulty,
          onGameComplete: _recordGameProgress,
        );
      default:
        return null;
    }
  }

  Future<void> _recordGameProgress({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  }) async {
    if (widget.isDemoMode) {
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('students')
          .doc(user.uid)
          .collection('game_progress')
          .add({
        'accuracy': accuracy,
        'completionTime': completionTime,
        'challengeFocus': challengeFocus,
        'gameName': gameName,
        'difficulty': difficulty,
        'timestamp': FieldValue.serverTimestamp(),
        'category': widget.category,
      });
    } catch (e) {
      print('Error recording game progress: $e');
    }
  }
}

class _GameCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _GameCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F3F3),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 48,
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF444444),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}