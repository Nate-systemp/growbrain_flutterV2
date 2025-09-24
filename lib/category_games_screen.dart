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
  PageController _pageController = PageController(viewportFraction: 0.6);
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
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
    final isTablet = screenSize.shortestSide >= 600 || screenSize.width >= 900;

    // More generous padding for tablet, tighter for phones
    final horizontalPadding = isTablet
        ? screenSize.width * 0.10
        : screenSize.width * 0.06;
    final topPadding = isTablet ? 56.0 : 24.0;
    final spacing = isTablet ? 36.0 : 20.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isTablet ? 96 : 72),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            gradient: const RadialGradient(
              colors: [Color(0xFF5B6F4A), Color(0xFF2F6B3D)],
              center: Alignment.center,
              radius: 10.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Material(
                color: Colors.white.withOpacity(0.06),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: isTablet ? 28 : 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '${widget.category} Games',
                      style: GoogleFonts.luckiestGuy(
                        color: Colors.white,
                        fontSize: isTablet ? 34 : 22,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.38),
                            offset: Offset(0, 5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (widget.isDemoMode)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.14),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    'DEMO',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),

      // Body with more breathing room
      body: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5B6F4A), Color(0xFF5B6F4A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
              // Instruction card with more breathing room
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: isTablet ? 16 : 12,
                ),
                margin: EdgeInsets.only(bottom: isTablet ? 28 : 18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.videogame_asset,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Choose a game to start — tap the big tile!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: isTablet ? 18 : 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // PSP-Style Horizontal Carousel
              Expanded(
                child: Column(
                  children: [
                    // Navigation arrows
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: _selectedGameIndex > 0 ? _previousGame : null,
                          icon: Icon(
                            Icons.arrow_back_ios,
                            color: _selectedGameIndex > 0 
                                ? Colors.white.withOpacity(0.9)
                                : Colors.white.withOpacity(0.3),
                            size: isTablet ? 32 : 24,
                          ),
                        ),
                        Text(
                          '${_selectedGameIndex + 1} / ${games.length}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: isTablet ? 16 : 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        IconButton(
                          onPressed: _selectedGameIndex < games.length - 1 ? _nextGame : null,
                          icon: Icon(
                            Icons.arrow_forward_ios,
                            color: _selectedGameIndex < games.length - 1 
                                ? Colors.white.withOpacity(0.9)
                                : Colors.white.withOpacity(0.3),
                            size: isTablet ? 32 : 24,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Horizontal carousel
                    Expanded(
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
                          final isSelected = index == _selectedGameIndex;
                          
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            margin: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: isSelected ? 0 : 40,
                            ),
                            child: Transform.scale(
                              scale: isSelected ? 1.0 : 0.85,
                              child: _PSPGameCard(
                                icon: game['icon'] as IconData,
                                iconColor: game['color'] as Color,
                                label: game['name'] as String,
                                onTap: () => _startGame(context, game),
                                isSelected: isSelected,
                                large: isTablet,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Action button for selected game
                    Container(
                      width: double.infinity,
                      height: isTablet ? 60 : 50,
                      margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: ElevatedButton(
                        onPressed: () => _startGame(context, games[_selectedGameIndex]),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF5B6F4A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 8,
                          shadowColor: Colors.black.withOpacity(0.3),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.play_arrow,
                              size: isTablet ? 28 : 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'START ${games[_selectedGameIndex]['name'].toString().toUpperCase()}',
                              style: TextStyle(
                                fontSize: isTablet ? 18 : 16,
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
        onGameComplete:
            ({
              required int accuracy,
              required int completionTime,
              required String challengeFocus,
              required String gameName,
              required String difficulty,
            }) {},
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
    final double cornerRadius = large ? 28 : 24;
    final double iconSize = large ? 100 : 80;
    final double labelFont = large ? 32 : 24;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cornerRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected 
                ? Colors.white.withOpacity(0.95)
                : Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(cornerRadius),
            border: isSelected 
                ? Border.all(color: iconColor, width: 3)
                : Border.all(color: Colors.white.withOpacity(0.3), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated icon container
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: iconSize + (isSelected ? 40 : 30),
                height: iconSize + (isSelected ? 40 : 30),
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      offset: const Offset(0, 4),
                      blurRadius: 8,
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
              
              const SizedBox(height: 20),
              
              // Game title
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: GoogleFonts.luckiestGuy(
                  fontSize: labelFont,
                  color: isSelected ? Colors.black87 : Colors.black54,
                  shadows: isSelected ? [
                    Shadow(
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                      color: iconColor.withOpacity(0.3),
                    ),
                  ] : [],
                ),
                child: Text(
                  label.toUpperCase(),
                  textAlign: TextAlign.center,
                ),
              ),
              
              // Selection indicator
              if (isSelected) ...[
                const SizedBox(height: 12),
                Container(
                  width: 60,
                  height: 4,
                  decoration: BoxDecoration(
                    color: iconColor,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
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
                    color: Colors.black.withOpacity(0.12),
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
                            color: Colors.black.withOpacity(0.14),
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
                                color: Colors.black.withOpacity(0.14),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.16),
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
                                  color: Colors.black.withOpacity(0.14),
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
