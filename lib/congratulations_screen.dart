import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'teacher_management.dart';
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
    
    // Initialize animations
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _bounceAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));
    
    _sparkleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sparkleController,
      curve: Curves.easeInOut,
    ));
    
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
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF87CEEB), // Sky blue
              const Color(0xFF98FB98), // Pale green
              const Color(0xFFFFE4B5), // Moccasin
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // Animated celebration header
                  AnimatedBuilder(
                    animation: _bounceAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _bounceAnimation.value,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Sparkly celebration icons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  AnimatedBuilder(
                                    animation: _sparkleAnimation,
                                    builder: (context, child) {
                                      return Transform.rotate(
                                        angle: _sparkleAnimation.value * 6.28,
                                        child: const Text('🎉', style: TextStyle(fontSize: 32)),
                                      );
                                    },
                                  ),
                                  const Text('🏆', style: TextStyle(fontSize: 48)),
                                  AnimatedBuilder(
                                    animation: _sparkleAnimation,
                                    builder: (context, child) {
                                      return Transform.rotate(
                                        angle: -_sparkleAnimation.value * 6.28,
                                        child: const Text('✨', style: TextStyle(fontSize: 32)),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Big smiley face
                              const Text('😊', style: TextStyle(fontSize: 64)),
                              
                              const SizedBox(height: 16),
                              
                              // Congratulations text
                              const Text(
                                'AMAZING JOB!',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4CAF50),
                                  letterSpacing: 2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              
                              const SizedBox(height: 8),
                              
                              Text(
                                'You completed all games! 🎮',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Student name with fun styling
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFFFFD740),
                                      const Color(0xFFFFC107),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Text(
                                  '${widget.student['fullName'] ?? 'Super Star'}!',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Compact session summary with fun colors
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text('📊', style: TextStyle(fontSize: 24)),
                            const SizedBox(width: 8),
                            const Text(
                              'Your Results',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5B6F4A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildCompactSummaryCards(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Compact game records
                  if (widget.sessionRecords.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Text('🎮', style: TextStyle(fontSize: 24)),
                              const SizedBox(width: 8),
                              const Text(
                                'Games Played',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF5B6F4A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildCompactGameRecords(),
                        ],
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Fun back to home button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4CAF50),
                          const Color(0xFF8BC34A),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      onPressed: () {
                        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🏠', style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          const Text(
                            'Back to Home',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactSummaryCards() {
    if (widget.sessionRecords.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            const Text('🤔', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            const Text(
              'No games played yet!',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final avgAccuracy = widget.sessionRecords
        .map((r) => (r['accuracy'] as num?)?.toDouble() ?? 0.0)
        .reduce((a, b) => a + b) / widget.sessionRecords.length;

    final avgCompletionTime = widget.sessionRecords
        .map((r) => (r['completionTime'] as num?)?.toDouble() ?? 0.0)
        .reduce((a, b) => a + b) / widget.sessionRecords.length;

    final totalGames = widget.sessionRecords.length;

    return Row(
      children: [
        Expanded(
          child: _buildCompactSummaryCard(
            '${avgAccuracy.toStringAsFixed(0)}%',
            'Accuracy',
            '🎯',
            const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCompactSummaryCard(
            '${avgCompletionTime.toStringAsFixed(0)}s',
            'Avg Time',
            '⏱️',
            const Color(0xFF2196F3),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCompactSummaryCard(
            '$totalGames',
            'Games',
            '🎮',
            const Color(0xFF9C27B0),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactSummaryCard(String value, String title, String emoji, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactGameRecords() {
    return Column(
      children: widget.sessionRecords.take(3).map((record) => _buildCompactRecordCard(record)).toList(),
    );
  }

  Widget _buildCompactRecordCard(Map<String, dynamic> record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFFD740),
                  const Color(0xFFFFC107),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                _getGameEmoji(record['game'] ?? ''),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record['game'] ?? 'Unknown Game',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5B6F4A),
                  ),
                ),
                Text(
                  '${record['difficulty'] ?? 'Unknown'} • ${record['completionTime'] ?? 0}s',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${record['accuracy'] ?? 0}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4CAF50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getGameEmoji(String gameName) {
    switch (gameName.toLowerCase()) {
      case 'match cards':
        return '🃏';
      case 'tictactoe':
        return '⭕';
      case 'puzzle':
        return '🧩';
      case 'riddle game':
        return '🤔';
      case 'word grid':
        return '📝';
      case 'scrabble':
        return '🔤';
      case 'anagram':
        return '🔀';
      case 'who moved?':
        return '👀';
      case 'light tap':
        return '💡';
      case 'find me':
        return '🔍';
      case 'fruit shuffle':
        return '🍎';
      case 'object hunt':
        return '🕵️';
      default:
        return '🎮';
    }
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getGameIcon(record['game'] ?? ''),
              color: Colors.orange,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record['game'] ?? 'Unknown Game',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Difficulty: ${record['difficulty'] ?? 'Unknown'}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${record['accuracy'] ?? 0}%',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              Text(
                '${record['completionTime'] ?? 0}s',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getGameIcon(String gameName) {
    switch (gameName.toLowerCase()) {
      case 'match cards':
        return Icons.style;
      case 'tictactoe':
        return Icons.grid_3x3;
      case 'puzzle':
        return Icons.extension;
      case 'riddle game':
        return Icons.question_mark;
      case 'word grid':
        return Icons.grid_4x4;
      case 'scrabble':
        return Icons.grid_on;
      case 'anagram':
        return Icons.shuffle;
      case 'who moved?':
        return Icons.extension;
      case 'light tap':
        return Icons.touch_app;
      case 'find me':
        return Icons.search;
      case 'fruit shuffle':
        return Icons.apple;
      case 'object hunt':
        return Icons.search;
      default:
        return Icons.games;
    }
  }
}
