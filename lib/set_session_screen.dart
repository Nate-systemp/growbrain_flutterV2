import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'games/match_cards_game.dart';
import 'games/tictactoe_game.dart';
import 'games/fruit_shuffle_game.dart';
import 'games/who_moved_game.dart';
import 'games/light_tap_game.dart';
import 'games/find_me_game.dart';
import 'games/sound_match_game.dart';
import 'games/rhyme_time_game.dart';
import 'games/picture_words_game.dart';
import 'games/object_hunt_game.dart';
import 'games/puzzle_game.dart';
import 'games/riddle_game.dart';
import 'congratulations_screen.dart';

class SetSessionScreen extends StatefulWidget {
  final Map<String, dynamic> student;
  const SetSessionScreen({Key? key, required this.student}) : super(key: key);

  @override
  State<SetSessionScreen> createState() => _SetSessionScreenState();
}

class _SetSessionScreenState extends State<SetSessionScreen> {
  final List<String> games = ['Attention', 'Verbal', 'Memory', 'Logic'];
  final Set<String> selectedGames = {};
  final Map<String, List<String>> categoryGames = {
    'Attention': ['Who Moved?', 'Light Tap', 'Find Me'],
    'Verbal': ['Sound Match', 'Rhyme Time', 'Picture Words'],
    'Memory': ['Match Cards', 'Fruit Shuffle', 'Object Hunt'],
    'Logic': ['Puzzle', 'TicTacToe', 'Riddle Game'],
  };
  bool _saving = false;
  Map<String, String> gameDifficulties = {};

  // Session tracking
  List<Map<String, dynamic>> sessionRecords = [];
  Set<String> completedGames = {};

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final studentId = widget.student['id'] ?? widget.student['fullName'];
    try {
      final doc = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(user.uid)
          .collection('students')
          .doc(studentId)
          .get();
      final data = doc.data();
      if (data != null && data['session'] is List) {
        setState(() {
          selectedGames.clear();
          selectedGames.addAll(List<String>.from(data['session']));
        });
      }
    } catch (_) {}
  }

  Future<void> _openCategoryModal(String category) async {
    final result = await showGameSelectionModal(
      context: context,
      category: category,
      games: categoryGames[category]!,
      selectedGames: selectedGames.intersection(
        categoryGames[category]!.toSet(),
      ),
      maxTotal: 5,
      currentTotalSelected: selectedGames.length,
    );
    if (result != null) {
      setState(() {
        // Remove old games from this category
        selectedGames.removeWhere((g) => categoryGames[category]!.contains(g));
        // Add new selected games
        selectedGames.addAll(result);
      });
    }
  }

  Future<void> _saveSession() async {
    setState(() => _saving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not logged in.')));
      setState(() => _saving = false);
      return;
    }
    final studentId = widget.student['id'] ?? widget.student['fullName'];
    try {
      await FirebaseFirestore.instance
          .collection('teachers')
          .doc(user.uid)
          .collection('students')
          .doc(studentId)
          .set({'session': selectedGames.toList()}, SetOptions(merge: true));
      await _loadSession();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Session saved!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save session.')));
    }
    setState(() => _saving = false);
  }

  void _showPlayModal() async {
    // Reset session tracking for new session
    sessionRecords.clear();
    completedGames.clear();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PlaySessionModal(
        studentName: widget.student['fullName'] ?? 'Student',
        games: selectedGames.toList(),
      ),
    );
    if (result == 'play' && selectedGames.contains('Match Cards')) {
      final difficulty = gameDifficulties['Match Cards'] ?? 'Starter';
      final challengeFocus = 'Memory'; // Since Match Cards is under Memory
      final gameName = 'Match Cards';
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MatchCardsGame(
            difficulty: difficulty,
            challengeFocus: challengeFocus,
            gameName: gameName,
            onGameComplete: _handleGameCompletion,
          ),
        ),
      );
    }
    if (result == 'play' && selectedGames.contains('TicTacToe')) {
      final difficulty = gameDifficulties['TicTacToe'] ?? 'Starter';
      final challengeFocus = 'Logic'; // Since TicTacToe is under Logic
      final gameName = 'TicTacToe';
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TicTacToeGameScreen(
            difficulty: difficulty,
            challengeFocus: challengeFocus,
            gameName: gameName,
            onGameComplete: _handleGameCompletion,
          ),
        ),
      );
    }
    if (result == 'play' && selectedGames.contains('Fruit Shuffle')) {
      final difficulty = gameDifficulties['Fruit Shuffle'] ?? 'Starter';
      final challengeFocus = 'Memory'; // Since Fruit Shuffle is under Memory
      final gameName = 'Fruit Shuffle';
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FruitShuffleGame(
            difficulty: difficulty,
            challengeFocus: challengeFocus,
            gameName: gameName,
            onGameComplete: _handleGameCompletion,
          ),
        ),
      );
    }
    if (result == 'play' && selectedGames.contains('Who Moved?')) {
      final difficulty = gameDifficulties['Who Moved?'] ?? 'Starter';
      final challengeFocus = 'Attention'; // Since Who Moved? is under Attention
      final gameName = 'Who Moved?';
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => WhoMovedGame(
            difficulty: difficulty,
            challengeFocus: challengeFocus,
            gameName: gameName,
            onGameComplete: _handleGameCompletion,
          ),
        ),
      );
    }
    if (result == 'play' && selectedGames.contains('Light Tap')) {
      final difficulty = gameDifficulties['Light Tap'] ?? 'Starter';
      final challengeFocus = 'Attention'; // Since Light Tap is under Attention
      final gameName = 'Light Tap';
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => LightTapGame(
            difficulty: difficulty,
            onGameComplete: _handleGameCompletion,
          ),
        ),
      );
    }
    if (result == 'play' && selectedGames.contains('Find Me')) {
      final difficulty = gameDifficulties['Find Me'] ?? 'Starter';
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FindMeGame(
            difficulty: difficulty,
            onGameComplete: _handleGameCompletion,
          ),
        ),
      );
    }
    if (result == 'play' && selectedGames.contains('Sound Match')) {
      final difficulty = gameDifficulties['Sound Match'] ?? 'Starter';
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SoundMatchGame(
            difficulty: difficulty,
            onGameComplete: _handleGameCompletion,
          ),
        ),
      );
    }
    if (result == 'play' && selectedGames.contains('Rhyme Time')) {
      final difficulty = gameDifficulties['Rhyme Time'] ?? 'Starter';
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RhymeTimeGame(
            difficulty: difficulty,
            onGameComplete: _handleGameCompletion,
          ),
        ),
      );
    }
    if (result == 'play' && selectedGames.contains('Picture Words')) {
      final difficulty = gameDifficulties['Picture Words'] ?? 'Starter';
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PictureWordsGame(
            difficulty: difficulty,
            onGameComplete: _handleGameCompletion,
          ),
        ),
      );
    }
    if (result == 'play' && selectedGames.contains('Object Hunt')) {
      final difficulty = gameDifficulties['Object Hunt'] ?? 'Starter';
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ObjectHuntGame(
            difficulty: difficulty,
            onGameComplete: _handleGameCompletion,
          ),
        ),
      );
    }
    if (result == 'play' && selectedGames.contains('Puzzle')) {
      final difficulty = gameDifficulties['Puzzle'] ?? 'Starter';
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PuzzleGame(
            difficulty: difficulty,
            onGameComplete: _handleGameCompletion,
          ),
        ),
      );
    }
    if (result == 'play' && selectedGames.contains('Riddle Game')) {
      final difficulty = gameDifficulties['Riddle Game'] ?? 'Starter';
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RiddleGame(
            difficulty: difficulty,
            onGameComplete: _handleGameCompletion,
          ),
        ),
      );
    }
  }

  void _showSetDifficultyModal(String game) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SetDifficultyModal(
        game: game,
        initial: gameDifficulties[game] ?? 'Easy',
      ),
    );
    if (result != null) {
      setState(() {
        gameDifficulties[game] = result;
      });
    }
  }

  Future<void> _handleGameCompletion({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final studentId = widget.student['id'] ?? widget.student['fullName'];
    final now = DateTime.now();
    final record = {
      'date': now.toIso8601String(),
      'challengeFocus': challengeFocus,
      'game': gameName,
      'difficulty': difficulty,
      'accuracy': accuracy,
      'completionTime': completionTime,
      'lastPlayed': gameName,
    };

    // Save to Firebase
    await FirebaseFirestore.instance
        .collection('teachers')
        .doc(user!.uid)
        .collection('students')
        .doc(studentId)
        .collection('records')
        .add(record);

    // Track session record
    setState(() {
      sessionRecords.add(record);
      completedGames.add(gameName);
    });

    // Check if all games are completed
    if (completedGames.length >= selectedGames.length) {
      // All games completed, show congratulations screen
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => CongratulationsScreen(
              student: widget.student,
              sessionRecords: sessionRecords,
            ),
          ),
        );
      }
      return;
    }

    // Show individual game completion dialog only if single game
    if (selectedGames.length == 1) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Game Complete!'),
          content: Text(
            'Accuracy: $accuracy%\nCompletion Time: ${completionTime}s',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      await showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.blueAccent, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Game Records',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Date: ${record['date']}'),
                          Text('Challenge Focus: ${record['challengeFocus']}'),
                          Text('Game: ${record['game']}'),
                          Text('Difficulty: ${record['difficulty']}'),
                          Text('Accuracy: ${record['accuracy']}'),
                          Text('Completion Time: ${record['completionTime']}'),
                          Text('Last Played: ${record['lastPlayed']}'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: CustomPaint(painter: _PieChartPainter()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 32),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final studentName = widget.student['fullName'] ?? 'Student';
      return Scaffold(
        backgroundColor: const Color(0xFF5B6F4A),
        body: SafeArea(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 700),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Left panel
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // For Teachers button (replaces Back button)
                      Container(
                        width: 240,
                        margin: const EdgeInsets.only(bottom: 18),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 18,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.person_outline, size: 32),
                          label: const Text('For Teachers'),
                        ),
                      ),
                      // Selected Games panel
                      Container(
                        width: 260,
                        height: 380,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.10),
                              blurRadius: 8,
                              offset: const Offset(2, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 0,
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.only(
                                top: 22,
                                bottom: 14,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF7F7F7),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(28),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Selected Games',
                                    style: TextStyle(
                                      fontSize: 22,
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Nunito',
                                    ),
                                  ),
                                  Text(
                                    'for $studentName',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF393C48),
                                      fontFamily: 'Nunito',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Message about clicking games to set difficulty
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Tap on selected games to set difficulty',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                  fontFamily: 'Nunito',
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // 2x3 grid with 5 slots (last slot centered)
                            SizedBox(
                              height: 220,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _SelectedGameSlot(
                                        game: selectedGames.length > 0
                                            ? selectedGames.elementAt(0)
                                            : null,
                                        onSetDifficulty: (g) =>
                                            _showSetDifficultyModal(g),
                                      ),
                                      const SizedBox(width: 28),
                                      _SelectedGameSlot(
                                        game: selectedGames.length > 1
                                            ? selectedGames.elementAt(1)
                                            : null,
                                        onSetDifficulty: (g) =>
                                            _showSetDifficultyModal(g),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 28),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _SelectedGameSlot(
                                        game: selectedGames.length > 2
                                            ? selectedGames.elementAt(2)
                                            : null,
                                        onSetDifficulty: (g) =>
                                            _showSetDifficultyModal(g),
                                      ),
                                      const SizedBox(width: 28),
                                      _SelectedGameSlot(
                                        game: selectedGames.length > 3
                                            ? selectedGames.elementAt(3)
                                            : null,
                                        onSetDifficulty: (g) =>
                                            _showSetDifficultyModal(g),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 28),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _SelectedGameSlot(
                                        game: selectedGames.length > 4
                                            ? selectedGames.elementAt(4)
                                            : null,
                                        faded: true,
                                        onSetDifficulty: (g) =>
                                            _showSetDifficultyModal(g),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Save and Play buttons below the panel
                      SizedBox(
                        width: 220,
                        child: Column(
                          children: [
                            _YellowButton(
                              label: 'Save',
                              onTap: _saving
                                  ? () {}
                                  : () {
                                      _saveSession();
                                    },
                            ),
                            const SizedBox(height: 18),
                            _YellowButton(label: 'Play', onTap: _showPlayModal),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 56),
                  // Main grid
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 520,
                        child: GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 36,
                          crossAxisSpacing: 36,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            for (final category in games)
                              _GameCard(
                                label: category,
                                icon: _iconForCategory(category),
                                color: _colorForCategory(category),
                                selected: selectedGames.any(
                                  (g) => categoryGames[category]!.contains(g),
                                ),
                                onTap: () => _openCategoryModal(category),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('Error in SetSessionScreen build: $e\n$st');
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(
            'Something went wrong. Please restart the app.',
            style: TextStyle(color: Colors.red, fontSize: 20),
          ),
        ),
      );
    }
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'Attention':
        return Icons.lightbulb_outline;
      case 'Verbal':
        return Icons.abc;
      case 'Memory':
        return Icons.style;
      case 'Logic':
        return Icons.psychology;
      default:
        return Icons.extension;
    }
  }

  Color _colorForCategory(String category) {
    switch (category) {
      case 'Attention':
        return Colors.amber;
      case 'Verbal':
        return Colors.redAccent;
      case 'Memory':
        return Colors.blueAccent;
      case 'Logic':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }
}

class _GameCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _GameCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 210,
        height: 210,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.13),
              blurRadius: 10,
              offset: const Offset(2, 8),
            ),
          ],
          border: selected ? Border.all(color: color, width: 5) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: color),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF7F7F7),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF393C48),
                  fontFamily: 'Nunito',
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PuzzleSlot extends StatelessWidget {
  final bool selected;
  final bool faded;
  final double size;
  const _PuzzleSlot({
    this.selected = false,
    this.faded = false,
    this.size = 44,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: faded ? 0.4 : 1.0,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.extension,
            size: size * 0.68,
            color: selected ? Colors.lime[600] : Colors.grey[300],
          ),
        ),
      ),
    );
  }
}

class _YellowButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _YellowButton({required this.label, required this.onTap, Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFD740),
          foregroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            fontFamily: 'Nunito',
          ),
          shadowColor: Colors.black.withOpacity(0.18),
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }
}

class CategoryGamesModal extends StatefulWidget {
  final String category;
  final List<String> games;
  final Set<String> allSelected;
  final int maxTotal;
  const CategoryGamesModal({
    required this.category,
    required this.games,
    required this.allSelected,
    required this.maxTotal,
    Key? key,
  }) : super(key: key);

  @override
  State<CategoryGamesModal> createState() => _CategoryGamesModalState();
}

class _CategoryGamesModalState extends State<CategoryGamesModal> {
  late Set<String> localSelected;

  @override
  void initState() {
    super.initState();
    localSelected = widget.allSelected.intersection(widget.games.toSet());
  }

  IconData _iconForGame(String game) {
    // Placeholder icons for each game
    switch (game) {
      case 'Who Moved?':
      case 'Puzzle':
        return Icons.extension;
      case 'Light Tap':
        return Icons.touch_app;
      case 'Find Me':
        return Icons.search;
      case 'Sound Match':
        return Icons.music_note;
      case 'Rhyme Time':
        return Icons.record_voice_over;
      case 'Picture Words':
        return Icons.image;
      case 'Match Cards':
        return Icons.style;
      case 'Fruit Shuffle':
        return Icons.apple;
      case 'Object Hunt':
        return Icons.search;
      case 'TicTacToe':
        return Icons.grid_3x3;
      case 'Riddle Game':
        return Icons.question_mark;
      default:
        return Icons.extension;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSelectMore =
        widget.allSelected.length - localSelected.length <
        widget.maxTotal - localSelected.length;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 60),
      child: Container(
        width: 600,
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
        decoration: BoxDecoration(
          color: const Color(0xFF5B6F4A),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.category.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red, size: 32),
                  onPressed: () =>
                      Navigator.of(context).pop(localSelected.toList()),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 150,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: widget.games.map((g) {
                  final selected = localSelected.contains(g);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (selected) {
                          localSelected.remove(g);
                        } else if (widget.allSelected.length < widget.maxTotal) {
                          localSelected.add(g);
                        }
                      });
                    },
                    child: Center(
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.13),
                              blurRadius: 8,
                              offset: Offset(1, 4),
                            ),
                          ],
                          border: Border.all(
                            color: selected ? Colors.lime : Colors.grey[300]!,
                            width: 4,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _iconForGame(g),
                              size: 36,
                              color: selected ? Colors.lime[700] : Colors.grey[500],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              g,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: selected ? Colors.lime[700] : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (widget.allSelected.length >= widget.maxTotal && !canSelectMore)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Maximum of 5 games can be selected.',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF393C48),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                onPressed: () =>
                    Navigator.of(context).pop(localSelected.toList()),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryGamesGrid extends StatelessWidget {
  final String category;
  final List<String> games;
  final Set<String> selectedGames;
  final void Function(String) onSelect;
  final VoidCallback onBack;
  const _CategoryGamesGrid({
    required this.category,
    required this.games,
    required this.selectedGames,
    required this.onSelect,
    required this.onBack,
    Key? key,
  }) : super(key: key);

  IconData _iconForGame(String game) {
    switch (game) {
      case 'Who Moved?':
      case 'Puzzle':
        return Icons.extension;
      case 'Light Tap':
        return Icons.touch_app;
      case 'Find Me':
        return Icons.search;
      case 'Word Grid':
        return Icons.grid_4x4;
      case 'Scrabble':
        return Icons.grid_on;
      case 'Anagram':
        return Icons.shuffle;
      case 'Sound Match':
        return Icons.music_note;
      case 'Rhyme Time':
        return Icons.record_voice_over;
      case 'Picture Words':
        return Icons.image;
      case 'Match Cards':
        return Icons.style;
      case 'Fruit Shuffle':
        return Icons.apple;
      case 'Object Hunt':
        return Icons.search;
      case 'TicTacToe':
        return Icons.grid_3x3;
      case 'Riddle Game':
        return Icons.question_mark;
      default:
        return Icons.extension;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double cardWidth = 120;
    final double cardHeight = 130;
    final double iconSize = 48;
    final double fontSize = 18;
    return Expanded(
      child: Stack(
        children: [
          // Main content (game cards or fallback message)
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // X button at the top right
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 18.0, right: 18.0),
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 32,
                      color: Colors.black87,
                    ),
                    onPressed: onBack,
                    tooltip: 'Close',
                  ),
                ),
              ),
              const SizedBox(height: 36),
              // Game cards grid or fallback
              Expanded(
                child: Center(
                  child: games.isEmpty
                      ? Container(
                          width: 260,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.10),
                                blurRadius: 8,
                                offset: const Offset(2, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'No games available in this category.',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : SizedBox(
                          width: cardWidth * 2.7,
                          child: GridView.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: 32,
                            crossAxisSpacing: 32,
                            childAspectRatio: cardWidth / cardHeight,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              for (final game in games)
                                GestureDetector(
                                  onTap: () => onSelect(game),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: cardWidth,
                                    height: cardHeight,
                                    decoration: BoxDecoration(
                                      color: selectedGames.contains(game)
                                          ? Colors.yellow[100]
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: selectedGames.contains(game)
                                            ? Colors.amber
                                            : Colors.grey[300]!,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.10),
                                          blurRadius: 8,
                                          offset: const Offset(2, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _iconForGame(game),
                                          size: iconSize,
                                          color: selectedGames.contains(game)
                                              ? Colors.amber[800]
                                              : Colors.grey[700],
                                        ),
                                        const SizedBox(height: 14),
                                        Text(
                                          game,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: fontSize,
                                            fontWeight: FontWeight.bold,
                                            color: selectedGames.contains(game)
                                                ? Colors.amber[800]
                                                : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
          // Category title at the bottom right
          Positioned(
            bottom: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 8,
                    offset: const Offset(2, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _iconForGame(games.isNotEmpty ? games[0] : ''),
                    size: 28,
                    color: Colors.amber[700],
                  ),
                  const SizedBox(width: 10),
                  Text(
                    category.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF393C48),
                      fontFamily: 'Nunito',
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedGameCard extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _AnimatedGameCard({required this.child, required this.delay, Key? key})
    : super(key: key);

  @override
  State<_AnimatedGameCard> createState() => _AnimatedGameCardState();
}

class _AnimatedGameCardState extends State<_AnimatedGameCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    try {
      return FadeTransition(
        opacity: _fade,
        child: ScaleTransition(scale: _scale, child: widget.child),
      );
    } catch (e, st) {
      debugPrint('Error in _AnimatedGameCard: $e\n$st');
      return widget.child;
    }
  }
}

class _CategoryGameCard extends StatelessWidget {
  final String game;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;
  const _CategoryGameCard({
    required this.game,
    required this.selected,
    required this.icon,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.13),
                    blurRadius: 10,
                    offset: const Offset(2, 8),
                  ),
                ],
                border: Border.all(
                  color: selected ? Colors.lime : Colors.grey[300]!,
                  width: 5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 64,
                    color: selected ? Colors.lime[700] : Colors.grey[500],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    game,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.lime[700] : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (selected)
            Positioned(
              right: 18,
              bottom: 18,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 6,
                      offset: const Offset(2, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.lime,
                  size: 32,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectedGameSlot extends StatelessWidget {
  final String? game;
  final bool faded;
  final void Function(String)? onSetDifficulty;
  const _SelectedGameSlot({
    this.game,
    this.faded = false,
    this.onSetDifficulty,
    Key? key,
  }) : super(key: key);

  IconData _iconForGame(String? game) {
    switch (game) {
      case 'Who Moved?':
      case 'Puzzle':
        return Icons.extension;
      case 'Light Tap':
        return Icons.touch_app;
      case 'Find Me':
        return Icons.search;
      case 'Word Grid':
        return Icons.grid_4x4;
      case 'Scrabble':
        return Icons.grid_on;
      case 'Anagram':
        return Icons.shuffle;
      case 'Sound Match':
        return Icons.music_note;
      case 'Rhyme Time':
        return Icons.record_voice_over;
      case 'Picture Words':
        return Icons.image;
      case 'Match Cards':
        return Icons.style;
      case 'Fruit Shuffle':
        return Icons.apple;
      case 'Object Hunt':
        return Icons.search;
      case 'TicTacToe':
        return Icons.grid_3x3;
      case 'Riddle Game':
        return Icons.question_mark;
      default:
        return Icons.extension;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (game == null) {
      return const SizedBox(width: 54, height: 54);
    } else {
      return Opacity(
        opacity: faded ? 0.4 : 1.0,
        child: GestureDetector(
          onTap: onSetDifficulty != null ? () => onSetDifficulty!(game!) : null,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                _iconForGame(game),
                size: 34,
                color: Colors.lime[600],
              ),
            ),
          ),
        ),
      );
    }
  }
}

class PlaySessionModal extends StatefulWidget {
  final String studentName;
  final List<String> games;
  const PlaySessionModal({
    required this.studentName,
    required this.games,
    Key? key,
  }) : super(key: key);

  @override
  State<PlaySessionModal> createState() => _PlaySessionModalState();
}

class _PlaySessionModalState extends State<PlaySessionModal> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Container(
        width: 500,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 18),
                    child: Text(
                      'Start Game Session for ${widget.studentName}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Session Games
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Session Games',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...widget.games.isEmpty
                                ? [
                                    const Text(
                                      'No games selected.',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ]
                                : widget.games.map(
                                    (g) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Text(
                                        g,
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Would you like to save it for later, or would you prefer to play it now for your student?',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD740),
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            fontFamily: 'Nunito',
                          ),
                          shadowColor: Colors.black.withOpacity(0.18),
                        ),
                        onPressed: () => Navigator.of(context).pop('save'),
                        child: const Text('Save for Later'),
                      ),
                    ),
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 180,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD740),
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            fontFamily: 'Nunito',
                          ),
                          shadowColor: Colors.black.withOpacity(0.18),
                        ),
                        onPressed: () => Navigator.of(context).pop('play'),
                        child: const Text('Play Now'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Close button
            Positioned(
              top: -18,
              right: -18,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 26),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SetDifficultyModal extends StatefulWidget {
  final String game;
  final String initial;
  const SetDifficultyModal({
    required this.game,
    required this.initial,
    Key? key,
  }) : super(key: key);

  @override
  State<SetDifficultyModal> createState() => _SetDifficultyModalState();
}

class _SetDifficultyModalState extends State<SetDifficultyModal> {
  late String _difficulty;

  @override
  void initState() {
    super.initState();
    _difficulty = widget.initial;
  }

  Color _getColorForDifficulty(String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return Colors.green;
      case 'Medium':
        return Colors.orange;
      case 'Hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForDifficulty(String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return Icons.sentiment_satisfied;
      case 'Medium':
        return Icons.sentiment_neutral;
      case 'Hard':
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.help_outline;
    }
  }

  String _getDescriptionForDifficulty(String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return 'Perfect for beginners';
      case 'Medium':
        return 'Good for developing skills';
      case 'Hard':
        return 'For advanced learners';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5B6F4A), Color(0xFF7A9166)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Icon(
                        Icons.tune,
                        size: 32,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set Difficulty',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Nunito',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.game,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFamily: 'Nunito',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Difficulty Options
                Column(
                  children: [
                    _DifficultyOption(
                      value: 'Easy',
                      groupValue: _difficulty,
                      title: 'Starter',
                      description: _getDescriptionForDifficulty('Easy'),
                      icon: _getIconForDifficulty('Easy'),
                      color: _getColorForDifficulty('Easy'),
                      onChanged: (v) => setState(() => _difficulty = v!),
                    ),
                    const SizedBox(height: 10),
                    _DifficultyOption(
                      value: 'Medium',
                      groupValue: _difficulty,
                      title: 'Growing',
                      description: _getDescriptionForDifficulty('Medium'),
                      icon: _getIconForDifficulty('Medium'),
                      color: _getColorForDifficulty('Medium'),
                      onChanged: (v) => setState(() => _difficulty = v!),
                    ),
                    const SizedBox(height: 10),
                    _DifficultyOption(
                      value: 'Hard',
                      groupValue: _difficulty,
                      title: 'Challenged',
                      description: _getDescriptionForDifficulty('Hard'),
                      icon: _getIconForDifficulty('Hard'),
                      color: _getColorForDifficulty('Hard'),
                      onChanged: (v) => setState(() => _difficulty = v!),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Nunito',
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD740),
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Nunito',
                        ),
                        shadowColor: Colors.black.withOpacity(0.3),
                      ),
                      onPressed: () => Navigator.of(context).pop(_difficulty),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
            // Close button
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyOption extends StatelessWidget {
  final String value;
  final String groupValue;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final ValueChanged<String?> onChanged;

  const _DifficultyOption({
    required this.value,
    required this.groupValue,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onChanged,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.white 
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? color 
                : Colors.white.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ] : null,
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.1) : Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? color : Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.black87 : Colors.white,
                      fontFamily: 'Nunito',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.grey[600] : Colors.white.withOpacity(0.8),
                      fontFamily: 'Nunito',
                    ),
                  ),
                ],
              ),
            ),
            // Radio indicator
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : Colors.white.withOpacity(0.5),
                  width: 2,
                ),
                color: isSelected ? color : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue[700]!
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      0,
      3.14 * 1.5,
      true,
      paint,
    );
    final paint2 = Paint()
      ..color = Colors.blue[200]!
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      3.14 * 1.5,
      3.14 * 0.5,
      true,
      paint2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Future<List<String>?> showGameSelectionModal({
  required BuildContext context,
  required String category,
  required List<String> games,
  required Set<String> selectedGames,
  required int maxTotal,
  required int currentTotalSelected,
}) {
  return showDialog<List<String>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _GameSelectionModal(
      category: category,
      games: games,
      selectedGames: selectedGames,
      maxTotal: maxTotal,
      currentTotalSelected: currentTotalSelected,
    ),
  );
}

class _GameSelectionModal extends StatefulWidget {
  final String category;
  final List<String> games;
  final Set<String> selectedGames;
  final int maxTotal;
  final int currentTotalSelected;
  const _GameSelectionModal({
    required this.category,
    required this.games,
    required this.selectedGames,
    required this.maxTotal,
    required this.currentTotalSelected,
    Key? key,
  }) : super(key: key);

  @override
  State<_GameSelectionModal> createState() => _GameSelectionModalState();
}

class _GameSelectionModalState extends State<_GameSelectionModal> {
  late Set<String> localSelected;
  late int _initialLocalCount;
  String _query = '';

  @override
  void initState() {
    super.initState();
    localSelected = Set<String>.from(widget.selectedGames);
    _initialLocalCount = widget.selectedGames.length;
  }

  IconData _iconForGame(String game) {
    switch (game) {
      case 'Who Moved?':
      case 'Puzzle':
        return Icons.extension;
      case 'Light Tap':
        return Icons.touch_app;
      case 'Find Me':
        return Icons.search;
      case 'Word Grid':
        return Icons.grid_4x4;
      case 'Scrabble':
        return Icons.grid_on;
      case 'Anagram':
        return Icons.shuffle;
      case 'Sound Match':
        return Icons.music_note;
      case 'Rhyme Time':
        return Icons.record_voice_over;
      case 'Picture Words':
        return Icons.image;
      case 'Match Cards':
        return Icons.style;
      case 'Fruit Shuffle':
        return Icons.apple;
      case 'Object Hunt':
        return Icons.search;
      case 'TicTacToe':
        return Icons.grid_3x3;
      case 'Riddle Game':
        return Icons.question_mark;
      default:
        return Icons.extension;
    }
  }

  int get _computedTotalSelected =>
      widget.currentTotalSelected - _initialLocalCount + localSelected.length;

  void _toggleSelect(String game) {
    setState(() {
      final already = localSelected.contains(game);
      if (already) {
        localSelected.remove(game);
      } else {
        final totalIfAdded = widget.currentTotalSelected -
            _initialLocalCount +
            localSelected.length +
            1;
        if (totalIfAdded <= widget.maxTotal) {
          localSelected.add(game);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum of 5 games can be selected.'),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    });
  }

  void _clearAll() {
    setState(() => localSelected.clear());
  }

  void _selectAllVisible(List<String> visible) {
    setState(() {
      for (final g in visible) {
        if (!localSelected.contains(g)) {
          final totalIfAdded = widget.currentTotalSelected -
              _initialLocalCount +
              localSelected.length +
              1;
          if (totalIfAdded <= widget.maxTotal) {
            localSelected.add(g);
          } else {
            break;
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayGames = widget.games
        .where((g) => g.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      child: Container(
        width: 520,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5B6F4A), Color(0xFF7A9166)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.category.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_computedTotalSelected}/${widget.maxTotal}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () =>
                      Navigator.of(context).pop(widget.selectedGames.toList()),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Search bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.amber,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, color: Colors.white70),
                  hintText: 'Search games',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 12),
            // Grid of games
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: displayGames.isEmpty
                  ? Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 8,
                            offset: const Offset(2, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'No games match your search.',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : SizedBox(
                      height: 150,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: displayGames.map((g) {
                          final selected = localSelected.contains(g);
                          return GestureDetector(
                            onTap: () => _toggleSelect(g),
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.13),
                                      blurRadius: 8,
                                      offset: Offset(1, 4),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: selected ? Colors.lime : Colors.grey[300]!,
                                    width: 4,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _iconForGame(g),
                                      size: 36,
                                      color: selected ? Colors.lime[700] : Colors.grey[500],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      g,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: selected ? Colors.lime[700] : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            // Footer: counter + actions
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: widget.maxTotal == 0
                              ? 0
                              : _computedTotalSelected / widget.maxTotal,
                          color: Colors.amber[700],
                          backgroundColor: Colors.white24,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Selected: ${_computedTotalSelected} of ${widget.maxTotal}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => _clearAll(),
                  child: const Text(
                    'Clear',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _selectAllVisible(displayGames),
                  child: const Text(
                    'Select All',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      fontFamily: 'Nunito',
                    ),
                    elevation: 4,
                  ),
                  onPressed: () =>
                      Navigator.of(context).pop(localSelected.toList()),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
