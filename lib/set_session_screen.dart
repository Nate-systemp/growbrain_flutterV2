import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'utils/difficulty_utils.dart';
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
import 'utils/session_volume_manager.dart';
import 'widgets/volume_control_dialog.dart';

class SetSessionScreen extends StatefulWidget {
  final Map<String, dynamic> student;
  const SetSessionScreen({Key? key, required this.student}) : super(key: key);

  @override
  State<SetSessionScreen> createState() => _SetSessionScreenState();
}

class _SetSessionScreenState extends State<SetSessionScreen> {
  final List<String> allGames = ['Attention', 'Verbal', 'Memory', 'Logic'];
  List<String> availableGames = []; // Will be filtered based on student's cognitive needs
  final Set<String> selectedGames = {};
  final Map<String, List<String>> categoryGames = {
    'Attention': ['Who Moved?', 'Light Tap', 'Find Me'],
    'Verbal': ['Sound Match', 'Rhyme Time', 'Picture Words'],
    'Memory': ['Match Cards', 'Fruit Shuffle', 'Object Hunt'],
    'Logic': ['Puzzle', 'TicTacToe', 'Riddle Game'],
  };
  bool _saving = false;
  Map<String, String> gameDifficulties = {};
  // Use SessionVolumeManager for session-specific volumes
  SessionVolumeManager get _volumeManager => SessionVolumeManager.instance;

  // Session tracking
  List<Map<String, dynamic>> sessionRecords = [];
  Set<String> completedGames = {};

  @override
  void initState() {
    super.initState();
    _initializeAvailableGames();
    _loadSession();
  }

  @override
  void dispose() {
    // End session when leaving the screen
    SessionVolumeManager.instance.endSession();
    super.dispose();
  }

  void _initializeAvailableGames() {
    // Filter games based on student's cognitive needs
    availableGames.clear();
    
    // Check which cognitive needs are enabled for this student
    final bool hasAttention = widget.student['attention'] == true;
    final bool hasVerbal = widget.student['verbal'] == true;
    final bool hasMemory = widget.student['memory'] == true;
    final bool hasLogic = widget.student['logic'] == true;
    
    // Add available game categories based on student's needs
    if (hasAttention) availableGames.add('Attention');
    if (hasVerbal) availableGames.add('Verbal');
    if (hasMemory) availableGames.add('Memory');
    if (hasLogic) availableGames.add('Logic');
    
    // If no cognitive needs are selected, show all games (fallback)
    if (availableGames.isEmpty) {
      availableGames.addAll(allGames);
    }
  }

  Future<void> _loadSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final studentId = widget.student['id'] ?? widget.student['fullName'];
    
    // Start session with SessionVolumeManager
    await _volumeManager.startSession(studentId);
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(user.uid)
          .collection('students')
          .doc(studentId)
          .get();
      final data = doc.data();
      if (data != null && data['session'] is List) {
        final sessionData = List<String>.from(data['session']);
        print('Loading session for student: $sessionData'); // Debug print
        setState(() {
          selectedGames.clear();
          selectedGames.addAll(sessionData);
        });
      } else {
        print('No session data found for student'); // Debug print
        setState(() {
          selectedGames.clear();
        });
      }
    } catch (e) {
      print('Error loading session: $e'); // Debug print
      setState(() {
        selectedGames.clear();
      });
    }
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
      // Save session games
      await FirebaseFirestore.instance
          .collection('teachers')
          .doc(user.uid)
          .collection('students')
          .doc(studentId)
          .set({
            'session': selectedGames.toList(),
          }, SetOptions(merge: true));
      
      // Save session volumes through SessionVolumeManager
      await _volumeManager.saveSessionVolumes(studentId);
      
      // Show fun and modern success dialog
      _showModernSuccessDialog();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save session.')));
    }
    setState(() => _saving = false);
  }

  void _showModernSuccessDialog() {
    OverlayEntry? overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (BuildContext context) {
        return ModernSuccessDialog(
          studentName: widget.student['fullName'] ?? 'Student',
          gamesCount: selectedGames.length,
        );
      },
    );
    
    // Insert the overlay
    Overlay.of(context).insert(overlayEntry);
    
    // Remove overlay after animation completes
    Future.delayed(const Duration(milliseconds: 4000), () {
      overlayEntry?.remove();
    });
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
        gameDifficulties: gameDifficulties,
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
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => LightTapGame(
            difficulty: difficulty,
            onGameComplete: _handleGameCompletion,
            requirePinOnExit: true,
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
        initial: gameDifficulties[game] ?? 'Starter',
      ),
    );
    if (result != null) {
      setState(() {
        gameDifficulties[game] = result;
      });
    }
  }

  void _showVolumeControlDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => VolumeControlDialog(
        initialBackgroundMusicVolume: _volumeManager.sessionBackgroundMusicVolume,
        initialSoundEffectsVolume: _volumeManager.sessionSoundEffectsVolume,
        onBackgroundMusicVolumeChanged: (volume) async {
          await _volumeManager.setSessionBackgroundMusicVolume(volume);
          setState(() {}); // Trigger UI update
        },
        onSoundEffectsVolumeChanged: (volume) async {
          await _volumeManager.setSessionSoundEffectsVolume(volume);
          setState(() {}); // Trigger UI update
        },
      ),
    );
  }

  Future<void> _handleGameCompletion({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  }) async {
    // Prevent duplicate game records for the same game in this session
    if (completedGames.contains(gameName)) {
      print('Game $gameName already completed in this session, skipping duplicate record');
      return;
    }
    
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

    // Track session record - only add if not already completed
    setState(() {
      sessionRecords.add(record);
      completedGames.add(gameName);
    });

    print('Session progress: ${completedGames.length}/${selectedGames.length} games completed');
    print('Completed games: ${completedGames.toList()}');
    print('Session records count: ${sessionRecords.length}');

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
    }
  }

 @override
Widget build(BuildContext context) {
  try {
    final studentName = widget.student['fullName'] ?? 'Student';
    return Scaffold(
      // Remove backgroundColor so image is visible
      body: Stack(
        children: [
          // Background image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'), // Make sure this exists!
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Foreground content
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Header
                Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    'set session',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Main content - exact Figma layout
                Expanded(
                  child: Row(
                    children: [
                      // Left panel - exactly like Figma
                      SizedBox(
                        width: 260,
                        child: Column(
                            children: [
                            // Back button
                            Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              ),
                              child: MaterialButton(
                              onPressed: () => Navigator.of(context).pop(),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                Icon(
                                  Icons.arrow_back,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Back',
                                  style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  ),
                                ),
                                ],
                              ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Selected Games panel
                            Expanded(
                              child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white,
                                    Colors.grey[50]!,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.8),
                                    blurRadius: 8,
                                    offset: const Offset(-2, -2),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                // Header with icon
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(0xFF5B6F4A),
                                              const Color(0xFF6B7F5A),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF5B6F4A).withOpacity(0.3),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.games,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Selected Games',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[800],
                                            ),
                                          ),
                                          Text(
                                            'for ${studentName.split(' ').first}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: const Color(0xFF5B6F4A),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Divider line after header
                                Container(
                                  height: 1,
                                  margin: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.grey[300]!,
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Game slots - 2x2 grid layout for selected games
                                Expanded(
                                  child: selectedGames.isEmpty
                                    ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.grey[300]!,
                                                width: 2,
                                                strokeAlign: BorderSide.strokeAlignInside,
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.videogame_asset_outlined,
                                              size: 40,
                                              color: Colors.grey[400],
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No games selected',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Tap on game categories\nto add games',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    : Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      child: GridView.builder(
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                        childAspectRatio: 1.0,
                                      ),
                                      itemCount: selectedGames.length,
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemBuilder: (context, index) {
                                        final game = selectedGames.elementAt(index);
                                        return GestureDetector(
                                        onTap: () => _showSetDifficultyModal(game),
                                        child: Container(
                                          decoration: BoxDecoration(
                                          color: const Color(0xFF5B6F4A),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: _getDifficultyBorderColor(game),
                                            width: 5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                            ),
                                          ],
                                          ),
                                          child: Center(
                                          child: Icon(
                                            _getGameIcon(game),
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                          ),
                                        ),
                                        );
                                      },
                                      ),
                                    ),
                                ),
                                // Move the instruction text to bottom
                                if (selectedGames.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  // Divider line before instructions
                                  Container(
                                    height: 1,
                                    margin: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Colors.grey[300]!,
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Tap on selected games to set difficulty',
                                    maxLines: 1,
                                    overflow: TextOverflow.visible,
                                    style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Difficulty indicators
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildDifficultyIndicator('Starter', Colors.green),
                                      const SizedBox(width: 12),
                                      _buildDifficultyIndicator('Growing', Colors.orange),
                                      const SizedBox(width: 12),
                                      _buildDifficultyIndicator('Challenged', Colors.red),
                                    ],
                                  ),
                                ],
                                ],
                              ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Clear All button
                            Container(
                              width: double.infinity,
                              height: 54,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFE57373),
                                    const Color(0xFFEF5350),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(27),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE57373).withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: MaterialButton(
                                onPressed: () {
                                  setState(() {
                                    selectedGames.clear();
                                    gameDifficulties.clear();
                                    // Don't reset background music setting - it's independent
                                  });
                                },
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(27),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.clear_all,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Clear All',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Volume Control Setting
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                onTap: _showVolumeControlDialog,
                                borderRadius: BorderRadius.circular(20),
                                child: Row(
                                  children: [
                                    Icon(
                                      _volumeManager.sessionBackgroundMusicVolume > 0 || _volumeManager.sessionSoundEffectsVolume > 0 
                                        ? Icons.music_note 
                                        : Icons.music_off,
                                      color: _volumeManager.sessionBackgroundMusicVolume > 0 || _volumeManager.sessionSoundEffectsVolume > 0 
                                        ? const Color(0xFF5B6F4A) 
                                        : Colors.grey,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Volume Control',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.settings,
                                      color: Colors.grey[400],
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Save and Play buttons with images
                            Row(
                              children: [
                              Expanded(
                                child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: MaterialButton(
                                  onPressed: _saving ? null : _saveSession,
                                  shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                    'assets/save.png',
                                    height: 80,
                                    width: 80,
                                    ),
                                    
                                  ],
                                  ),
                                ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: MaterialButton(
                                  onPressed: _showPlayModal,
                                  shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                    'assets/play.png',
                                     height: 100,
                                    width: 80,
                                    ),
                                  ],
                                  ),
                                ),
                                ),
                              ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Right panel - 2x2 category grid centered and compact
                      Expanded(
                        child: Center(
                          child: SizedBox(
                            width: 600,
                            height: 600,
                            child: GridView.count(
                              crossAxisCount: 2,
                              mainAxisSpacing: 20,
                              crossAxisSpacing: 20,
                              childAspectRatio: 1.0,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _buildCategoryCard('Attention'),
                                _buildCategoryCard('Verbal'),
                                _buildCategoryCard('Memory'),
                                _buildCategoryCard('Logic'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  } catch (e, st) {
    debugPrint('Error in SetSessionScreen build: $e\n$st');
    return Scaffold(
      backgroundColor: const Color(0xFF5B6F4A),
      body: const Center(
        child: Text(
          'Error loading session screen',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}
  Widget _buildGameSlot(int index) {
    final hasGame = selectedGames.length > index;
    final game = hasGame ? selectedGames.elementAt(index) : null;
    
    if (!hasGame) {
      return Container(); // Return empty container for slots without games
    }
    
    return GestureDetector(
      onTap: () => _showSetDifficultyModal(game!),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF5B6F4A),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            _getGameIcon(game!),
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String category) {
    final games = categoryGames[category] ?? [];
    final isSelected = selectedGames.any((game) => games.contains(game));
    final isEnabled = availableGames.contains(category);
    
    return GestureDetector(
      onTap: isEnabled ? () => _openCategoryModal(category) : null,
      child: Stack(
        children: [
          // Just the image - no background, no text
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Opacity(
              opacity: isEnabled ? 1.0 : 0.3,
              child: _getCategoryIcon(category),
            ),
          ),
          // Selected indicator (optional)
          if (isSelected)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _getCategoryIcon(String category) {
    switch (category) {
      case 'Attention':
        return Image.asset(
          'assets/attention.png',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      case 'Verbal':
        return Image.asset(
          'assets/verbal.png',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      case 'Memory':
        return Image.asset(
          'assets/memory.png',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      case 'Logic':
        return Image.asset(
          'assets/logic.png',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      default:
        return Icon(Icons.extension, color: Colors.white, size: 30);
    }
  }

  Color _getCategoryIconColor(String category) {
    switch (category) {
      case 'Attention':
        return const Color(0xFFFFD740); // Yellow
      case 'Verbal':
        return const Color(0xFF42A5F5); // Blue  
      case 'Memory':
        return const Color(0xFFFFE0B2); // Light peach/cream
      case 'Logic':
        return const Color(0xFFFFAB91); // Light coral/pink
      default:
        return Colors.grey;
    }
  }

  IconData _getGameIcon(String game) {
    switch (game) {
      case 'Match Cards':
        return Icons.style;
      case 'TicTacToe':
        return Icons.grid_3x3;
      case 'Fruit Shuffle':
        return Icons.shuffle;
      case 'Who Moved?':
        return Icons.visibility;
      case 'Light Tap':
        return Icons.touch_app;
      case 'Find Me':
        return Icons.search;
      case 'Sound Match':
        return Icons.volume_up;
      case 'Rhyme Time':
        return Icons.music_note;
      case 'Picture Words':
        return Icons.image;
      case 'Object Hunt':
        return Icons.explore;
      case 'Puzzle':
        return Icons.extension;
      case 'Riddle Game':
        return Icons.quiz;
      default:
        return Icons.games;
    }
  }

  Color _getDifficultyBorderColor(String game) {
    String difficulty = gameDifficulties[game] ?? 'Starter';
    switch (difficulty.toLowerCase()) {
      case 'starter':
        return Colors.green;
      case 'growing':
        return Colors.orange;
      case 'challenged':
        return Colors.red;
      default:
        return Colors.green; // Default to green for Starter
    }
  }

  Widget _buildDifficultyIndicator(String difficulty, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        difficulty,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCompactSelectedGamesPanel(String studentName) {
    return Column(
      children: [
        // Selected Games panel - more compact
        Container(
          width: double.infinity,
          height: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              // Title
              const Text(
                'Selected Games',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                'for ${studentName.split(' ').first}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap on selected games to set difficulty',
                maxLines: 1,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              
              // Game slots - compact grid
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (int i = 0; i < 5; i++)
                      _CompactGameSlot(
                        game: selectedGames.length > i
                            ? selectedGames.elementAt(i)
                            : null,
                        difficulty: selectedGames.length > i
                            ? gameDifficulties[selectedGames.elementAt(i)] ?? 'Starter'
                            : null,
                        onTap: selectedGames.length > i
                            ? () => _showSetDifficultyModal(selectedGames.elementAt(i))
                            : null,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Action buttons - compact
        Container(
          width: double.infinity,
          height: 45,
          decoration: BoxDecoration(
            color: const Color(0xFFE57373), // Red color
            borderRadius: BorderRadius.circular(25),
          ),
          child: MaterialButton(
            onPressed: () {
              setState(() {
                selectedGames.clear();
                gameDifficulties.clear();
              });
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Text(
              'Clear All',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        
      ],
    );
  }
  
  Widget _buildSelectedGamesPanel(String studentName) {
    return _buildCompactSelectedGamesPanel(studentName);
  }

  Widget _buildCompactGameCategoriesPanel() {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: [
        for (final category in allGames)
          _CompactGameCard(
            label: category,
            icon: _iconForCategory(category),
            color: _colorForCategory(category),
            selected: selectedGames.any(
              (g) => categoryGames[category]!.contains(g),
            ),
            enabled: availableGames.contains(category),
            onTap: availableGames.contains(category) 
                ? () => _openCategoryModal(category)
                : () {},
          ),
      ],
    );
  }
  
  Widget _buildGameCategoriesPanel() {
    return _buildCompactGameCategoriesPanel();
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'Attention':
        return Icons.lightbulb;
      case 'Verbal':
        return Icons.abc;
      case 'Memory':
        return Icons.dashboard;
      case 'Logic':
        return Icons.psychology;
      default:
        return Icons.extension;
    }
  }

  Color _colorForCategory(String category) {
    switch (category) {
      case 'Attention':
        return const Color(0xFFFFD740); // Yellow
      case 'Verbal':
        return const Color(0xFFFF6B6B); // Light red/pink
      case 'Memory':
        return const Color(0xFF4ECDC4); // Teal
      case 'Logic':
        return const Color(0xFFFF8A65); // Orange
      default:
        return Colors.grey;
    }
  }
}

class _GameCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  const _GameCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    this.enabled = true,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  State<_GameCard> createState() => _GameCardState();
}

// Compact Game Slot widget for selected games panel
class _CompactGameSlot extends StatelessWidget {
  final String? game;
  final String? difficulty;
  final VoidCallback? onTap;

  const _CompactGameSlot({Key? key, this.game, this.difficulty, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasGame = game != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: hasGame ? const Color(0xFF5B6F4A) : Colors.grey[300],
          shape: BoxShape.circle,
          border: hasGame ? Border.all(
            color: _getDifficultyBorderColorFromString(difficulty ?? 'Starter'),
            width: 4,
          ) : null,
          boxShadow: hasGame ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Center(
          child: hasGame
              ? Icon(
                  _getGameIcon(game!),
                  color: Colors.white,
                  size: 20,
                )
              : Icon(
                  Icons.add,
                  color: Colors.grey[500],
                  size: 20,
                ),
        ),
      ),
    );
  }

  IconData _getGameIcon(String gameName) {
    // Return appropriate icon based on game name
    switch (gameName) {
      case 'Match Cards':
        return Icons.style;
      case 'TicTacToe':
        return Icons.grid_3x3;
      case 'Fruit Shuffle':
        return Icons.shuffle;
      case 'Who Moved?':
        return Icons.visibility;
      case 'Light Tap':
        return Icons.touch_app;
      case 'Find Me':
        return Icons.search;
      case 'Sound Match':
        return Icons.volume_up;
      case 'Rhyme Time':
        return Icons.music_note;
      case 'Picture Words':
        return Icons.image;
      case 'Object Hunt':
        return Icons.explore;
      case 'Puzzle':
        return Icons.extension;
      case 'Riddle Game':
        return Icons.quiz;
      default:
        return Icons.star;
    }
  }
}

// Compact Game Card for category selection
class _CompactGameCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _CompactGameCard({
    Key? key,
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    this.enabled = true,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: selected ? 3 : 0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: color,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: enabled ? Colors.black87 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameCardState extends State<_GameCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (!widget.enabled) return;
    setState(() {
      _isPressed = true;
    });
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (!widget.enabled) return;
    setState(() {
      _isPressed = false;
    });
    _animationController.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() {
      _isPressed = false;
    });
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.enabled ? _scaleAnimation.value : 1.0,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            child: Container(
              width: 210,
              height: 210,
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              decoration: BoxDecoration(
                gradient: widget.enabled 
                  ? LinearGradient(
                      colors: _isPressed
                        ? [Colors.grey[100]!, Colors.white]
                        : [Colors.white, Colors.grey[50]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [Colors.grey[200]!, Colors.grey[100]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                borderRadius: BorderRadius.circular(36),
                boxShadow: widget.enabled ? [
                  BoxShadow(
                    color: _isPressed 
                      ? Colors.black.withOpacity(0.1)
                      : Colors.black.withOpacity(0.15),
                    blurRadius: _isPressed ? 6 : 12,
                    offset: _isPressed 
                      ? const Offset(1, 4)
                      : const Offset(2, 8),
                  ),
                  if (!_isPressed && widget.selected)
                    BoxShadow(
                      color: widget.color.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                ] : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(1, 4),
                  ),
                ],
                border: widget.selected 
                  ? Border.all(color: widget.color, width: 4) 
                  : Border.all(
                      color: widget.enabled 
                        ? Colors.grey.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.1), 
                      width: 2,
                    ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: widget.enabled
                        ? LinearGradient(
                            colors: [
                              widget.color.withOpacity(0.1),
                              widget.color.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [
                              Colors.grey.withOpacity(0.1),
                              Colors.grey.withOpacity(0.05),
                            ],
                          ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.enabled ? widget.color.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      widget.icon, 
                      size: 50, 
                      color: widget.enabled ? widget.color : Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: widget.enabled 
                        ? LinearGradient(
                            colors: [
                              const Color(0xFFF7F7F7),
                              const Color(0xFFEFEFEF),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )
                        : LinearGradient(
                            colors: [Colors.grey[100]!, Colors.grey[50]!],
                          ),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(32),
                      ),
                      border: Border.all(
                        color: widget.enabled 
                          ? Colors.grey.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.05),
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          widget.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: widget.enabled ? const Color(0xFF393C48) : Colors.grey[500],
                            fontFamily: 'Nunito',
                            letterSpacing: 1.0,
                          ),
                        ),
                        if (!widget.enabled)
                          Positioned(
                            right: 8,
                            child: Icon(
                              Icons.lock,
                              size: 20,
                              color: Colors.grey[600],
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
      },
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

class _YellowButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _YellowButton({required this.label, required this.onTap, Key? key})
    : super(key: key);

  @override
  State<_YellowButton> createState() => _YellowButtonState();
}

class _YellowButtonState extends State<_YellowButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
    _animationController.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() {
      _isPressed = false;
    });
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            child: Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isPressed 
                    ? [const Color(0xFFE6C200), const Color(0xFFFFD740)]
                    : [const Color(0xFFFFD740), const Color(0xFFFFC107)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: _isPressed 
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: const Color(0xFFFFD740).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                border: Border.all(
                  color: const Color(0xFFE6C200),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    fontFamily: 'Nunito',
                    color: _isPressed ? Colors.black54 : Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StyledButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _StyledButton({
    required this.label,
    required this.color,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  State<_StyledButton> createState() => _StyledButtonState();
}

class _StyledButtonState extends State<_StyledButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
    _animationController.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() {
      _isPressed = false;
    });
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isPressed 
                    ? [widget.color.withOpacity(0.8), widget.color]
                    : [widget.color, widget.color.withOpacity(0.8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: _isPressed 
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: widget.color.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                border: Border.all(
                  color: widget.color.withOpacity(0.7),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    fontFamily: 'Nunito',
                    color: _isPressed ? Colors.white70 : Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
  final Map<String, String> gameDifficulties;
  const PlaySessionModal({
    required this.studentName,
    required this.games,
    required this.gameDifficulties,
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
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              g,
                                              style: const TextStyle(fontSize: 18),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF5B6F4A),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              DifficultyUtils.getDifficultyDisplayName(widget.gameDifficulties[g] ?? 'Starter'),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
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
              top: -12,
              right: -12,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 28),
                  ),
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
      case 'Starter':
        return Colors.green;
      case 'Growing':
        return Colors.orange;
      case 'Challenged':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForDifficulty(String difficulty) {
    switch (difficulty) {
      case 'Starter':
        return Icons.sentiment_satisfied;
      case 'Growing':
        return Icons.sentiment_neutral;
      case 'Challenged':
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.help_outline;
    }
  }

  String _getDescriptionForDifficulty(String difficulty) {
    switch (difficulty) {
      case 'Starter':
        return 'Perfect for beginners';
      case 'Growing':
        return 'Good for developing skills';
      case 'Challenged':
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
                      value: 'Starter',
                      groupValue: _difficulty,
                      title: 'Starter',
                      description: _getDescriptionForDifficulty('Starter'),
                      icon: _getIconForDifficulty('Starter'),
                      color: _getColorForDifficulty('Starter'),
                      onChanged: (v) => setState(() => _difficulty = v!),
                    ),
                    const SizedBox(height: 10),
                    _DifficultyOption(
                      value: 'Growing',
                      groupValue: _difficulty,
                      title: 'Growing',
                      description: _getDescriptionForDifficulty('Growing'),
                      icon: _getIconForDifficulty('Growing'),
                      color: _getColorForDifficulty('Growing'),
                      onChanged: (v) => setState(() => _difficulty = v!),
                    ),
                    const SizedBox(height: 10),
                    _DifficultyOption(
                      value: 'Challenged',
                      groupValue: _difficulty,
                      title: 'Challenged',
                      description: _getDescriptionForDifficulty('Challenged'),
                      icon: _getIconForDifficulty('Challenged'),
                      color: _getColorForDifficulty('Challenged'),
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
    // Simple pie chart implementation
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw segments
    paint.color = Colors.green;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      3.14159 * 1.5, // 75% of circle
      true,
      paint,
    );

    paint.color = Colors.red;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14159 * 1.5,
      3.14159 * 0.5, // 25% of circle
      true,
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _LightBulbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    final center = Offset(size.width / 2, size.height / 2);
    
    // Draw lightbulb body (more bulb-like shape)
    final bulbPath = Path();
    bulbPath.addOval(Rect.fromCenter(
      center: Offset(center.dx, center.dy + 2),
      width: size.width * 0.5,
      height: size.width * 0.6,
    ));
    canvas.drawPath(bulbPath, paint);
    
    // Draw bulb base/screw
    paint.color = Colors.grey[400]!;
    final baseRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + size.height * 0.35),
      width: size.width * 0.3,
      height: size.height * 0.15,
    );
    canvas.drawRect(baseRect, paint);
    
    // Draw rays around lightbulb
    paint.color = const Color(0xFFFFD740); // Yellow rays
    paint.strokeWidth = 2;
    paint.style = PaintingStyle.stroke;
    paint.strokeCap = StrokeCap.round;
    
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45) * (3.14159 / 180);
      final startX = center.dx + (size.width * 0.35) * math.cos(angle);
      final startY = center.dy + (size.width * 0.35) * math.sin(angle);
      final endX = center.dx + (size.width * 0.45) * math.cos(angle);
      final endY = center.dy + (size.width * 0.45) * math.sin(angle);
      
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _StrawberryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Draw two strawberries side by side
    _drawStrawberry(canvas, Offset(center.dx - 8, center.dy), size.width * 0.35);
    _drawStrawberry(canvas, Offset(center.dx + 8, center.dy), size.width * 0.35);
    
    // Draw small hearts around strawberries
    final heartPaint = Paint()
      ..color = const Color(0xFFE91E63)
      ..style = PaintingStyle.fill;
    
    _drawHeart(canvas, Offset(center.dx - 12, center.dy - 8), 3, heartPaint);
    _drawHeart(canvas, Offset(center.dx + 12, center.dy - 8), 3, heartPaint);
    _drawHeart(canvas, Offset(center.dx, center.dy + 10), 2, heartPaint);
  }
  
  void _drawStrawberry(Canvas canvas, Offset center, double size) {
    final paint = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.fill;
    
    // Draw strawberry body
    final path = Path();
    path.moveTo(center.dx, center.dy - size * 0.4);
    path.quadraticBezierTo(
      center.dx + size * 0.4, center.dy - size * 0.2,
      center.dx + size * 0.3, center.dy + size * 0.4,
    );
    path.quadraticBezierTo(
      center.dx, center.dy + size * 0.5,
      center.dx - size * 0.3, center.dy + size * 0.4,
    );
    path.quadraticBezierTo(
      center.dx - size * 0.4, center.dy - size * 0.2,
      center.dx, center.dy - size * 0.4,
    );
    path.close();
    canvas.drawPath(path, paint);
    
    // Draw strawberry leaves
    paint.color = const Color(0xFF4CAF50);
    final leafPath = Path();
    leafPath.moveTo(center.dx - size * 0.2, center.dy - size * 0.4);
    leafPath.lineTo(center.dx - size * 0.1, center.dy - size * 0.6);
    leafPath.lineTo(center.dx, center.dy - size * 0.5);
    leafPath.lineTo(center.dx + size * 0.1, center.dy - size * 0.6);
    leafPath.lineTo(center.dx + size * 0.2, center.dy - size * 0.4);
    leafPath.close();
    canvas.drawPath(leafPath, paint);
    
    // Draw seeds
    paint.color = Colors.yellow;
    for (int i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(center.dx + (i % 2 == 0 ? -2 : 2), center.dy + (i < 2 ? -2 : 2)),
        0.8,
        paint,
      );
    }
  }
  
  void _drawHeart(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    path.moveTo(center.dx, center.dy + size);
    path.cubicTo(
      center.dx - size, center.dy,
      center.dx - size, center.dy - size * 0.5,
      center.dx, center.dy - size * 0.3,
    );
    path.cubicTo(
      center.dx + size, center.dy - size * 0.5,
      center.dx + size, center.dy,
      center.dx, center.dy + size,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _BrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF7043)
      ..style = PaintingStyle.fill;
    
    final center = Offset(size.width / 2, size.height / 2);
    
    // Draw brain shape with more realistic curves
    final path = Path();
    
    // Left hemisphere
    path.moveTo(center.dx - size.width * 0.1, center.dy - size.height * 0.3);
    path.quadraticBezierTo(
      center.dx - size.width * 0.4, center.dy - size.height * 0.4,
      center.dx - size.width * 0.35, center.dy - size.height * 0.1,
    );
    path.quadraticBezierTo(
      center.dx - size.width * 0.4, center.dy + size.height * 0.1,
      center.dx - size.width * 0.2, center.dy + size.height * 0.3,
    );
    
    // Bottom connection
    path.quadraticBezierTo(
      center.dx - size.width * 0.1, center.dy + size.height * 0.35,
      center.dx, center.dy + size.height * 0.3,
    );
    
    // Right hemisphere
    path.quadraticBezierTo(
      center.dx + size.width * 0.1, center.dy + size.height * 0.35,
      center.dx + size.width * 0.2, center.dy + size.height * 0.3,
    );
    path.quadraticBezierTo(
      center.dx + size.width * 0.4, center.dy + size.height * 0.1,
      center.dx + size.width * 0.35, center.dy - size.height * 0.1,
    );
    path.quadraticBezierTo(
      center.dx + size.width * 0.4, center.dy - size.height * 0.4,
      center.dx + size.width * 0.1, center.dy - size.height * 0.3,
    );
    
    // Top connection
    path.quadraticBezierTo(
      center.dx, center.dy - size.height * 0.35,
      center.dx - size.width * 0.1, center.dy - size.height * 0.3,
    );
    
    path.close();
    canvas.drawPath(path, paint);
    
    // Add brain folds/wrinkles
    paint.color = const Color(0xFFD84315);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    
    // Left hemisphere wrinkles
    final wrinkle1 = Path();
    wrinkle1.moveTo(center.dx - size.width * 0.25, center.dy - size.height * 0.15);
    wrinkle1.quadraticBezierTo(
      center.dx - size.width * 0.15, center.dy - size.height * 0.05,
      center.dx - size.width * 0.2, center.dy + size.height * 0.1,
    );
    canvas.drawPath(wrinkle1, paint);
    
    // Right hemisphere wrinkles  
    final wrinkle2 = Path();
    wrinkle2.moveTo(center.dx + size.width * 0.25, center.dy - size.height * 0.15);
    wrinkle2.quadraticBezierTo(
      center.dx + size.width * 0.15, center.dy - size.height * 0.05,
      center.dx + size.width * 0.2, center.dy + size.height * 0.1,
    );
    canvas.drawPath(wrinkle2, paint);
    
    // Center division
    canvas.drawLine(
      Offset(center.dx, center.dy - size.height * 0.2),
      Offset(center.dx, center.dy + size.height * 0.2),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
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
                  onPressed: () => Navigator.of(context).pop(localSelected.toList()),
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
                  child: const Text('Select'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Subtle Success Notification Widget
class ModernSuccessDialog extends StatefulWidget {
  final String studentName;
  final int gamesCount;

  const ModernSuccessDialog({
    Key? key,
    required this.studentName,
    required this.gamesCount,
  }) : super(key: key);

  @override
  State<ModernSuccessDialog> createState() => _ModernSuccessDialogState();
}

class _ModernSuccessDialogState extends State<ModernSuccessDialog>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Start from right
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeIn,
    ));
    
    // Start animation
    _slideController.forward();
    
    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        _slideController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 50,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green[200]!,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Session saved!',
                    style: TextStyle(
                      color: Colors.green[800],
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Helper function for getting difficulty border color
Color _getDifficultyBorderColorFromString(String difficulty) {
  switch (difficulty.toLowerCase()) {
    case 'starter':
      return Colors.green;
    case 'growing':
      return Colors.orange;
    case 'challenged':
      return Colors.red;
    default:
      return Colors.green; // Default to green for Starter
  }
}
