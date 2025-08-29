import 'dart:math' as math;
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
    
    // Simple animations only
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _bounceAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.easeOut,
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
      backgroundColor: const Color(0xFFF8F9FA), // Light clean background
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // Simple celebration header
                AnimatedBuilder(
                  animation: _bounceAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _bounceAnimation.value,
                      child: _buildSimpleCelebrationHeader(),
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Clear stats section
                _buildSimpleStatsSection(),

                const SizedBox(height: 24),

                // Game records section
                if (widget.sessionRecords.isNotEmpty)
                  _buildSimpleGameRecordsSection(),

                const SizedBox(height: 40),

                // Big, clear action button
                _buildSimpleActionButton(),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleCelebrationHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Simple celebration row - no complex animations
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 48)),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7), // Soft yellow background
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B), width: 2),
                ),
                child: const Text('🏆', style: TextStyle(fontSize: 48)),
              ),
              const SizedBox(width: 16),
              const Text('🎉', style: TextStyle(fontSize: 48)),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Big happy face
          const Text('😊', style: TextStyle(fontSize: 80)),
          
          const SizedBox(height: 24),
          
          // Clear, simple text
          const Text(
            'GREAT JOB!',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Color(0xFF059669), // Green for success
              letterSpacing: 2,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFDF7), // Light green background
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF059669), width: 1),
            ),
            child: const Text(
              'You finished all your games! 🎮',
              style: TextStyle(
                fontSize: 20,
                color: Color(0xFF065F46), // Dark green text
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Student name - simple and clear
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6), // Clear blue
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${widget.student['fullName'] ?? 'Amazing Student'}!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStatsSection() {
    if (widget.sessionRecords.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('🎮', style: TextStyle(fontSize: 32)),
            ),
            const SizedBox(width: 16),
            const Text(
              'Ready to start!',
              style: TextStyle(
                fontSize: 20,
                color: Color(0xFF374151),
                fontWeight: FontWeight.w600,
              ),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFDF7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bar_chart,
                  color: Color(0xFF059669),
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Your Results',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Simple stat cards in a row
          Row(
            children: [
              Expanded(
                child: _buildSimpleStatCard(
                  '${avgAccuracy.toStringAsFixed(0)}%',
                  'Score',
                  Icons.star,
                  const Color(0xFF059669), // Green
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSimpleStatCard(
                  '${avgCompletionTime.toStringAsFixed(0)}s',
                  'Time',
                  Icons.timer,
                  const Color(0xFF3B82F6), // Blue
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSimpleStatCard(
                  '$totalGames',
                  'Games',
                  Icons.games,
                  const Color(0xFF8B5CF6), // Purple
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStatCard(String value, String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleGameRecordsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: Color(0xFFF59E0B),
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Games You Played',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Show only top 3 games to avoid overwhelming
          ...widget.sessionRecords.take(3).map((record) => 
            _buildSimpleRecordCard(record)
          ).toList(),
        ],
      ),
    );
  }

  Widget _buildSimpleRecordCard(Map<String, dynamic> record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Row(
        children: [
          // Game icon with clear background
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _getGameColor(record['game'] ?? '').withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getGameColor(record['game'] ?? '').withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                _getGameEmoji(record['game'] ?? ''),
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(width: 20),
          
          // Game info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record['game'] ?? 'Game',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${record['difficulty'] ?? 'Easy'} Level',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Time: ${record['completionTime'] ?? 0} seconds',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Score badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF059669),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'Score',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${record['accuracy'] ?? 0}%',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleActionButton() {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6), // Clear blue
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: () {
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.home, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            const Text(
              'Go Back Home',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getGameColor(String gameName) {
    switch (gameName.toLowerCase()) {
      case 'match cards':
        return const Color(0xFFEF4444); // Red
      case 'tictactoe':
        return const Color(0xFF10B981); // Green
      case 'puzzle':
        return const Color(0xFF8B5CF6); // Purple
      case 'riddle game':
        return const Color(0xFFF59E0B); // Orange
      case 'word grid':
        return const Color(0xFF3B82F6); // Blue
      case 'scrabble':
        return const Color(0xFF059669); // Teal
      default:
        return const Color(0xFF6B7280); // Gray
    }
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
}