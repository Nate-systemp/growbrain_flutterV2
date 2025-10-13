import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'utils/sound_effects_manager.dart';

class CongratulationsScreen extends StatefulWidget {
  final Map<String, dynamic> student;
  final List<Map<String, dynamic>> sessionRecords;

  const CongratulationsScreen({
    Key? key,
    required this.student,
    required this.sessionRecords,
  }) : super(key: key);

  @override
  State<CongratulationsScreen> createState() => _CongratulationsScreenState();
}

class _CongratulationsScreenState extends State<CongratulationsScreen>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _sparkleController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _sparkleAnimation;

  @override
  void initState() {
    super.initState();

    // Play congratulations sound effect
    SoundEffectsManager().playCongratulations();

    // Simple animations only
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _bounceAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeOut),
    );

    _sparkleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sparkleController, curve: Curves.easeInOut),
    );

    // Start animations
    _bounceController.forward();
    _sparkleController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate stats
    final avgAccuracy = widget.sessionRecords.isNotEmpty
        ? widget.sessionRecords
                  .map((r) => (r['accuracy'] as num?)?.toDouble() ?? 0.0)
                  .reduce((a, b) => a + b) /
              widget.sessionRecords.length
        : 0.0;
    final avgCompletionTime = widget.sessionRecords.isNotEmpty
        ? widget.sessionRecords
                  .map((r) => (r['completionTime'] as num?)?.toDouble() ?? 0.0)
                  .reduce((a, b) => a + b) /
              widget.sessionRecords.length
        : 0.0;
    final totalGames = widget.sessionRecords.length;

    // For game icons in circles
    List<Widget> gameCircles = List.generate(5, (i) {
      if (i < widget.sessionRecords.length) {
        final record = widget.sessionRecords[i];
        final gameName = record['game']?.toString() ?? '';
        final icon = _getGameIcon(gameName);
        return Container(
          width: 42,
          height: 42,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.black.withOpacity(0.18), width: 2),
          ),
          child: Center(
            child: Icon(icon, size: 20, color: Colors.black.withOpacity(0.7)),
          ),
        );
      } else {
        return Container(
          width: 42,
          height: 42,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.black.withOpacity(0.18), width: 2),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF5B6F4A),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/background.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  width: 820,
                  height: 650,
                  margin: const EdgeInsets.symmetric(
                    vertical: 72,
                    horizontal: 12,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 72,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF6E3),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: const Color(0xFF3BB3FF),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(255, 27, 48, 22).withOpacity(0.45), // dark green
                        blurRadius: 0,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        'Congratulations',
                        style: GoogleFonts.poppins(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          color: Colors.black.withOpacity(0.85),
                          shadows: [
                            Shadow(
                              color: const Color.fromARGB(255, 48, 48, 48).withOpacity(0.18),
                              offset: Offset(0, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      // Student Name
                      Text(
                        widget.student['fullName'] ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: Colors.black.withOpacity(0.9),
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.10),
                              offset: Offset(0, 2),
                              blurRadius: 1,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      // Divider with label
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 7,
                              color: Colors.black.withOpacity(.7),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Your Results',
                            style: GoogleFonts.poppins(
                              fontSize: 38,
                              fontWeight: FontWeight.w700,
                              color: Colors.black.withOpacity(0.7),
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              height: 7,
                              color: Colors.black.withOpacity(.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 58),
                      // Stats
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SCORE',
                                  style: GoogleFonts.poppins(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'TIME',
                                  style: GoogleFonts.poppins(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'GAMES',
                                  style: GoogleFonts.poppins(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${avgAccuracy.toStringAsFixed(0)}%',
                                  style: GoogleFonts.poppins(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black.withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  avgCompletionTime >= 60
                                      ? '${(avgCompletionTime / 60).round()}mins'
                                      : '${avgCompletionTime.toStringAsFixed(0)}s',
                                  style: GoogleFonts.poppins(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black.withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: gameCircles,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      // Home Button
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5B6F4A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          icon: const Icon(Icons.home, size: 24),
                          label: Text(
                            'HOME',
                            style: GoogleFonts.poppins(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/home',
                              (route) => false,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper for icon per game name - aligned with game icons
  IconData _getGameIcon(String gameName) {
    switch (gameName.toLowerCase()) {
      case 'who moved?':
        return Icons.visibility;
      case 'light tap':
        return Icons.touch_app;
      case 'find me':
        return Icons.search;
      case 'sound match':
        return Icons.music_note;
      case 'rhyme time':
        return Icons.record_voice_over;
      case 'picture words':
        return Icons.image;
      case 'match cards':
        return Icons.style;
      case 'fruit shuffle':
        return Icons.apple;
      case 'object hunt':
        return Icons.explore;
      case 'tictactoe':
        return Icons.grid_3x3;
      case 'puzzle':
        return Icons.extension;
      case 'riddle game':
        return Icons.question_mark;
      default:
        return Icons.gamepad;
    }
  }
}