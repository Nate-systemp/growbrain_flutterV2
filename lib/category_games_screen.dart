import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
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
  int _selectedGameIndex = 0;
  final PageController _pageController = PageController(
    viewportFraction: 6.0, // <-- ito ang mahalaga!
  );

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Define category to game mappings
  final Map<String, List<Map<String, dynamic>>> categoryGames = {
    'Attention': [
      {
        'name': 'Who Moved',
        'icon': Icons.swap_horiz,
        'color': Colors.blue,
        'game': WhoMovedGame(difficulty: 'Easy'),
      },
      {
        'name': 'Light Tap',
        'icon': Icons.lightbulb_outline,
        'color': Colors.amber,
        'game': LightTapGame(difficulty: 'Easy', requirePinOnExit: false),
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
        'name': 'Sound Match',
        'icon': Icons.hearing,
        'color': Colors.indigo,
        'game': SoundMatchGame(difficulty: 'Easy'),
      },
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
        'name': 'Object Hunt',
        'icon': Icons.visibility,
        'color': Colors.brown,
        'game': ObjectHuntGame(difficulty: 'Easy'),
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
          onGameComplete:
              ({
                required int accuracy,
                required int completionTime,
                required String challengeFocus,
                required String gameName,
                required String difficulty,
              }) {},
        ),
      },
      {
        'name': 'Riddle',
        'icon': Icons.psychology,
        'color': Colors.teal,
        'game': RiddleGame(difficulty: 'Easy'),
      },
    ],
  };
  // ...existing code...
  @override
  Widget build(BuildContext context) {
    final games = categoryGames[widget.category] ?? [];
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600 || screenSize.width >= 900;

    // Select background image based on category
    final String backgroundImage;
    switch (widget.category.trim().toLowerCase()) {
      case 'verbal':
        backgroundImage = 'assets/verbalbg.png';
        break;
      case 'logic':
        backgroundImage = 'assets/logicbg.png';
        break;
      case 'memory':
        backgroundImage = 'assets/memorybg.png';
        break;
      default:
        backgroundImage = 'assets/background.png';
    }

    final horizontalPadding = isTablet
        ? screenSize.width * 0.08
        : screenSize.width * 0.05;
    final topPadding = isTablet ? 40.0 : 20.0;
    final spacing = isTablet ? 28.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(backgroundImage),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            topPadding,
            horizontalPadding,
            36,
          ),
          child: Column(
            children: [
              // Back Button
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Simple white triangle button
                        Container(
                          width: 32.0,
                          height: 32.0,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 3.0,
                                offset: const Offset(1, 1),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.arrow_back_ios,
                              color: Colors.grey[800],
                              size: 14.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        // Back text
                        Text(
                          'Back',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14.0,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 2.0,
                                offset: const Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left Arrow
                        GestureDetector(
                          onTap: _selectedGameIndex > 0
                              ? () => _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                )
                              : null,
                          child: Opacity(
                            opacity: _selectedGameIndex > 0 ? 1.0 : 0.3,
                            child: Image.asset(
                              'assets/arrowleft.png',
                              width: isTablet ? 80 : 50,
                              height: isTablet ? 80 : 50,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Game Card (PageView)
                        Expanded(
                          child: SizedBox(
                            height: isTablet ? 500 : 50,
                            child: PageView.builder(
                              controller: _pageController,
                              onPageChanged: (index) {
                                setState(() {
                                  _selectedGameIndex = index;
                                });
                              },
                              itemCount: games.length,
                              itemBuilder: (context, index) {
                                final game = games[index];
                                return _PSPGameCard(
                                  icon: game['icon'] as IconData,
                                  iconColor: game['color'] as Color,
                                  label: game['name'] as String,
                                  onTap: () => _startGame(context, game),
                                  isSelected: index == _selectedGameIndex,
                                  large: isTablet,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Right Arrow
                        GestureDetector(
                          onTap: _selectedGameIndex < games.length - 1
                              ? () => _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                )
                              : null,
                          child: Opacity(
                            opacity: _selectedGameIndex < games.length - 1
                                ? 1.0
                                : 0.3,
                            child: Image.asset(
                              'assets/arrowright.png',
                              width: isTablet ? 80 : 40,
                              height: isTablet ? 80 : 40,
                            ),
                          ),
                        ),
                      ],
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

  void _previousGame() {
    if (_selectedGameIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextGame() {
    final games = categoryGames[widget.category] ?? [];
    if (_selectedGameIndex < games.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _startGame(BuildContext context, Map<String, dynamic> game) {
    if (widget.isDemoMode) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => _getDemoGameWidget(game)));
    } else {
      _showDifficultyDialog(context, game);
    }
  }

  Widget _getDemoGameWidget(Map<String, dynamic> game) {
    final gameWidget = game['game'] as Widget;
    if (gameWidget is LightTapGame) {
      return LightTapGame(difficulty: 'Starter', onGameComplete: null);
    } else if (gameWidget is WhoMovedGame) {
      return WhoMovedGame(difficulty: 'Starter', onGameComplete: null);
    } else if (gameWidget is FindMeGame) {
      return FindMeGame(difficulty: 'Starter', onGameComplete: null);
    } else if (gameWidget is RhymeTimeGame) {
      return RhymeTimeGame(difficulty: 'Starter', onGameComplete: null);
    } else if (gameWidget is PictureWordsGame) {
      return PictureWordsGame(difficulty: 'Starter', onGameComplete: null);
    } else if (gameWidget is RiddleGame) {
      return RiddleGame(difficulty: 'Starter', onGameComplete: null);
    } else if (gameWidget is MatchCardsGame) {
      return MatchCardsGame(
        difficulty: 'Starter',
        challengeFocus: 'Memory',
        gameName: 'Match Cards',
        onGameComplete: null,
      );
    } else if (gameWidget is FruitShuffleGame) {
      return FruitShuffleGame(
        difficulty: 'Starter',
        challengeFocus: 'Memory',
        gameName: 'Fruit Shuffle',
        onGameComplete: null,
      );
    } else if (gameWidget is SoundMatchGame) {
      return SoundMatchGame(difficulty: 'Starter', onGameComplete: null);
    } else if (gameWidget is PuzzleGame) {
      return PuzzleGame(difficulty: 'Starter', onGameComplete: null);
    } else if (gameWidget is TicTacToeGameScreen) {
      return TicTacToeGameScreen(
        difficulty: 'Starter',
        challengeFocus: 'Logic',
        gameName: 'Tic Tac Toe',
        onGameComplete: null,
      );
    } else if (gameWidget is ObjectHuntGame) {
      return ObjectHuntGame(difficulty: 'Starter', onGameComplete: null);
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
                onTap: () =>
                    _startGameWithDifficulty(context, game, 'Challenge'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startGameWithDifficulty(
    BuildContext context,
    Map<String, dynamic> game,
    String difficulty,
  ) {
    Navigator.of(context).pop();

    final gameName = game['name'] as String;
    final gameWidget = _createGameWithDifficulty(gameName, difficulty);

    if (gameWidget != null) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => gameWidget));
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

class _PSPGameCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;
  final bool large;

  const _PSPGameCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    required this.isSelected,
    this.large = false,
    Key? key,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final double circleSize = large ? 320 : 280;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Light Tap
          if (label.trim().toLowerCase() == 'light tap') ...[
            Container(
              width: circleSize,
              height: circleSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black38,
                    offset: Offset(8, 12),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/lighttap.png',
                  fit: BoxFit.cover,
                  width: circleSize,
                  height: circleSize,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Image.asset(
              'assets/lighttapbutton.png',
              width: large ? 280 : 140,
              fit: BoxFit.contain,
            ),
          ]
          // Who Moved
          else if (label.trim().toLowerCase() == 'who moved') ...[
            Container(
              width: circleSize,
              height: circleSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black38,
                    offset: Offset(8, 12),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/whomoved.png',
                  fit: BoxFit.cover,
                  width: circleSize,
                  height: circleSize,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Image.asset(
              'assets/whomovedbutton.png',
              width: large ? 280 : 140,
              fit: BoxFit.contain,
            ),
          ]
          // Find Me
          else if (label.trim().toLowerCase() == 'find me') ...[
            Container(
              width: circleSize,
              height: circleSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black38,
                    offset: Offset(8, 12),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/findme.png',
                  fit: BoxFit.cover,
                  width: circleSize,
                  height: circleSize,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Image.asset(
              'assets/findmebutton.png',
              width: large ? 280 : 140,
              fit: BoxFit.contain,
            ),
          ]
          // Picture Words
          else if (label.trim().toLowerCase() == 'picture words') ...[
            Container(
              width: circleSize,
              height: circleSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black38,
                    offset: Offset(8, 12),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/picturewords.png',
                  fit: BoxFit.cover,
                  width: circleSize,
                  height: circleSize,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Image.asset(
              'assets/picturewordsbutton.png',
              width: large ? 280 : 140,
              fit: BoxFit.contain,
            ),
          ]
          // Riddle
          else if (label.trim().toLowerCase() == 'riddle') ...[
            Container(
              width: circleSize,
              height: circleSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black38,
                    offset: Offset(8, 12),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/riddletime.png',
                  fit: BoxFit.cover,
                  width: circleSize,
                  height: circleSize,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Image.asset(
              'assets/riddletimebutton.png',
              width: large ? 280 : 140,
              fit: BoxFit.contain,
            ),
          ]
          // Rhyme Time
          else if (label.trim().toLowerCase() == 'rhyme time') ...[
            Container(
              width: circleSize,
              height: circleSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black38,
                    offset: Offset(8, 12),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/rhymetime.png',
                  fit: BoxFit.cover,
                  width: circleSize,
                  height: circleSize,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Image.asset(
              'assets/rhymetimebutton.png',
              width: large ? 280 : 140,
              fit: BoxFit.contain,
            ),
          ]
          // Match Cards
          else if (label.trim().toLowerCase() == 'match cards') ...[
            Container(
              width: circleSize,
              height: circleSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black38,
                    offset: Offset(8, 12),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/matchcards.png',
                  fit: BoxFit.cover,
                  width: circleSize,
                  height: circleSize,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Image.asset(
              'assets/matchcardsbutton.png',
              width: large ? 280 : 140,
              fit: BoxFit.contain,
            ),
          ]
          // Fruit Shuffle
          else if (label.trim().toLowerCase() == 'fruit shuffle') ...[
            Container(
              width: circleSize,
              height: circleSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black38,
                    offset: Offset(8, 12),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/fruitshuffle.png',
                  fit: BoxFit.cover,
                  width: circleSize,
                  height: circleSize,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Image.asset(
              'assets/fruitshufflebutton.png',
              width: large ? 280 : 140,
              fit: BoxFit.contain,
            ),
          ]
          // Sound Match
          else if (label.trim().toLowerCase() == 'sound match') ...[
            Container(
              width: circleSize,
              height: circleSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black38,
                    offset: Offset(8, 12),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/soundmatch.png',
                  fit: BoxFit.cover,
                  width: circleSize,
                  height: circleSize,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Image.asset(
              'assets/soundmatchbutton.png',
              width: large ? 280 : 140,
              fit: BoxFit.contain,
            ),
          ]
          // Puzzle
          else if (label.trim().toLowerCase() == 'puzzle') ...[
            Container(
              width: circleSize,
              height: circleSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black38,
                    offset: Offset(8, 12),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/puzzlegame.png',
                  fit: BoxFit.cover,
                  width: circleSize,
                  height: circleSize,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Image.asset(
              'assets/puzzlegamebutton.png',
              width: large ? 280 : 140,
              fit: BoxFit.contain,
            ),
          ]
          // Tic Tac Toe
          else if (label.trim().toLowerCase() == 'tic tac toe') ...[
            Container(
              width: circleSize,
              height: circleSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black38,
                    offset: Offset(8, 12),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/tictactoe.png',
                  fit: BoxFit.cover,
                  width: circleSize,
                  height: circleSize,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Image.asset(
              'assets/tictactoebutton.png',
              width: large ? 280 : 140,
              fit: BoxFit.contain,
            ),
          ]
          // Object Hunt
          else if (label.trim().toLowerCase() == 'object hunt') ...[
            Container(
              width: circleSize,
              height: circleSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black38,
                    offset: Offset(8, 12),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/objecthunt.png',
                  fit: BoxFit.cover,
                  width: circleSize,
                  height: circleSize,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Image.asset(
              'assets/objecthuntbutton.png',
              width: large ? 280 : 140,
              fit: BoxFit.contain,
            ),
          ]
          // Default
          else
            Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 7),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.38),
                    offset: const Offset(8, 12),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child: Icon(icon, size: large ? 100 : 70, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// Keep the old GameCard for backward compatibility
class _GameCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final bool large;

  const _GameCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.large = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double cornerRadius = large ? 24 : 18;
    final double iconSize = large ? 84 : 58;
    final double labelFont = large ? 28 : 18;

    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // card background with subtle inner border and offset shadow like image
          return Stack(
            children: [
              // Slight offset dark shadow to create "raised" look
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6, right: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0),
                    borderRadius: BorderRadius.circular(cornerRadius + 4),
                  ),
                ),
              ),
              // Main colored tile
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(cornerRadius),
                  ),
                  child: Center(
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(cornerRadius - 6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0),
                            offset: const Offset(0, 6),
                            blurRadius: 12,
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.06),
                            offset: const Offset(-6, -6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Colored rounded panel for icon
                          Container(
                            width: iconSize + 24,
                            height: iconSize + 24,
                            decoration: BoxDecoration(
                              color: iconColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.black.withOpacity(0),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0),
                                  offset: const Offset(0, 6),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                icon,
                                size: iconSize,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Label with Luckiest Guy font and shadow
                          Text(
                            label.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.luckiestGuy(
                              fontSize: labelFont,
                              color: Colors.black87,
                              shadows: [
                                Shadow(
                                  offset: const Offset(0, 2),
                                  blurRadius: 2,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                                Shadow(
                                  offset: const Offset(0, 6),
                                  blurRadius: 12,
                                  color: Colors.black.withOpacity(0),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
