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
                  width: 600,
                  margin: const EdgeInsets.symmetric(
                    vertical: 72,
                    horizontal: 12,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 48,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF6E3),
                    borderRadius: BorderRadius.circular(40),
                  
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 0,
                        offset: const Offset(0, 10),
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
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF00A651),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // Student Name
                      Text(
                        widget.student['fullName'] ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                          color: Colors.black.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      // Divider with label
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 3,
                              color: const Color(0xFF00A651),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Your Results',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF00A651),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              height: 3,
                              color: const Color(0xFF00A651),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // Stats with icons
                      _buildStatRow(
                        icon: Icons.emoji_events,
                        iconColor: Colors.amber,
                        label: 'SCORE',
                        value: '${avgAccuracy.toStringAsFixed(0)}%',
                      ),
                      const SizedBox(height: 24),
                      _buildStatRow(
                        icon: Icons.schedule,
                        iconColor: Colors.orange,
                        label: 'TIME',
                        value: avgCompletionTime >= 60
                            ? '${(avgCompletionTime / 60).round()}mins'
                            : '${avgCompletionTime.toStringAsFixed(0)}s',
                      ),
                      const SizedBox(height: 24),
                      _buildGamesRow(totalGames),
                      const SizedBox(height: 32),
                      // Motivational message
                      Text(
                        'Great job, ${widget.student['fullName']?.split(' ').first ?? ''}! You\'re improving!',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF00A651),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      // Home Button
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/home',
                            (route) => false,
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 23,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFA500),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6B4423),
                                offset: const Offset(0, 6),
                                blurRadius: 0,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                offset: const Offset(0, 8),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.home,
                                size: 28,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'HOME',
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                  color: Colors.white,
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
          ),
        ],
      ),
    );
  }
  Widget _buildStatRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 40, color: iconColor),
        const SizedBox(width: 16),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.black.withOpacity(0.8),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF00A651),
          ),
        ),
      ],
    );
  }

  Widget _buildGamesRow(int totalGames) {
    return Row(
      children: [
        Icon(Icons.sports_esports, size: 40, color: const Color(0xFF2D5A3D)),
        const SizedBox(width: 16),
        Text(
          'GAMES',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.black.withOpacity(0.8),
          ),
        ),
        const Spacer(),
        Row(
          children: List.generate(3, (index) {
            if (index < totalGames) {
              return Icon(
                Icons.star,
                size: 36,
                color: Colors.amber,
              );
            } else {
              return Icon(
                Icons.star,
                size: 36,
                color: Colors.grey.withOpacity(0.5),
              );
            }
          }).expand((star) => [star, const SizedBox(width: 8)]).toList()
            ..removeLast(),
        ),
      ],
    );
  }
}