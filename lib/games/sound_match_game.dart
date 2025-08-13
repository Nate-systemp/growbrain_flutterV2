import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';

class SoundMatchGame extends StatefulWidget {
  final String difficulty;
  final Function({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })? onGameComplete;

  const SoundMatchGame({
    Key? key,
    required this.difficulty,
    this.onGameComplete,
  }) : super(key: key);

  @override
  _SoundMatchGameState createState() => _SoundMatchGameState();
}

class SoundItem {
  final String name;
  final String emoji;
  final String description;
  
  SoundItem({
    required this.name,
    required this.emoji,
    required this.description,
  });
}

class _SoundMatchGameState extends State<SoundMatchGame> {
  int _currentRound = 1;
  int _score = 0;
  int _correctAnswers = 0;
  late SoundItem _currentSound;
  List<SoundItem> _currentOptions = [];
  bool _isAnswering = false;
  DateTime? _gameStartTime;

  final List<SoundItem> _allSounds = [
    SoundItem(name: 'Dog', emoji: '🐕', description: 'Woof woof!'),
    SoundItem(name: 'Cat', emoji: '🐱', description: 'Meow meow!'),
    SoundItem(name: 'Bird', emoji: '🐦', description: 'Tweet tweet!'),
    SoundItem(name: 'Cow', emoji: '🐄', description: 'Moo moo!'),
    SoundItem(name: 'Car', emoji: '🚗', description: 'Vroom vroom!'),
    SoundItem(name: 'Train', emoji: '🚂', description: 'Choo choo!'),
    SoundItem(name: 'Rain', emoji: '🌧️', description: 'Pitter patter!'),
    SoundItem(name: 'Thunder', emoji: '⛈️', description: 'Boom boom!'),
    SoundItem(name: 'Bell', emoji: '🔔', description: 'Ding dong!'),
    SoundItem(name: 'Drum', emoji: '🥁', description: 'Bang bang!'),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize with first round immediately
    _initializeGame();
  }

  void _initializeGame() {
    // Generate first round options immediately
    _currentSound = _allSounds[Random().nextInt(_allSounds.length)];
    
    List<SoundItem> options = [_currentSound];
    List<SoundItem> otherSounds = _allSounds.where((s) => s.name != _currentSound.name).toList();
    otherSounds.shuffle();
    options.addAll(otherSounds.take(3));
    options.shuffle();
    
    setState(() {
      _currentOptions = options;
      _currentRound = 1;
      _score = 0;
      _correctAnswers = 0;
      _gameStartTime = DateTime.now();
    });
  }

  void _generateNewRound() {
    if (_currentRound > 5) {
      _endGame();
      return;
    }

    // Select random current sound
    _currentSound = _allSounds[Random().nextInt(_allSounds.length)];
    
    // Create options (including correct answer)
    List<SoundItem> options = [_currentSound];
    List<SoundItem> otherSounds = _allSounds.where((s) => s.name != _currentSound.name).toList();
    otherSounds.shuffle();
    options.addAll(otherSounds.take(3));
    options.shuffle();
    
    setState(() {
      _currentOptions = options;
      _isAnswering = false;
    });
    
    // Auto-play sound after a short delay
    Future.delayed(Duration(milliseconds: 500), _playCurrentSound);
  }

  void _playCurrentSound() {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🔊 ${_currentSound.description}'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF5B6F4A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _selectOption(SoundItem selectedItem) {
    if (_isAnswering) return;
    
    setState(() {
      _isAnswering = true;
    });
    
    HapticFeedback.lightImpact();
    
    bool isCorrect = selectedItem.name == _currentSound.name;
    
    if (isCorrect) {
      setState(() {
        _score += 20;
        _correctAnswers++;
      });
      
      _showFeedback('🎉 Correct! Great job!', Colors.green);
      
      Future.delayed(Duration(seconds: 1), () {
        setState(() {
          _currentRound++;
        });
        _generateNewRound();
      });
    } else {
      _showFeedback('❌ Try again! Listen carefully.', Colors.red);
      
      Future.delayed(Duration(seconds: 1), () {
        setState(() {
          _isAnswering = false;
        });
      });
    }
  }

  void _showFeedback(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontWeight: FontWeight.bold)),
        duration: Duration(seconds: 1),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _endGame() {
    int completionTime = _gameStartTime != null 
        ? DateTime.now().difference(_gameStartTime!).inSeconds 
        : 0;
    int accuracy = _correctAnswers > 0 ? ((_correctAnswers / 5) * 100).round() : 0;

    if (widget.onGameComplete != null) {
      widget.onGameComplete!(
        accuracy: accuracy,
        completionTime: completionTime,
        challengeFocus: 'Auditory Processing',
        gameName: 'Sound Match',
        difficulty: widget.difficulty,
      );
    }
    
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3), // Same as Picture Words - beige/cream
      appBar: AppBar(
        title: Text('🔊 Sound Match - ${widget.difficulty.toUpperCase()}'),
        backgroundColor: Color(0xFF5B6F4A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _buildGameContent(),
      ),
    );
  }

  Widget _buildGameContent() {
    return Column(
      children: [
        // Score row - very compact
        Container(
          padding: const EdgeInsets.all(4),
          color: const Color(0xFFF3F3F3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInfoCard('🎯 Score', '$_score', const Color(0xFFF3F3F3)),
              _buildInfoCard('🏁 Round', '$_currentRound/5', const Color(0xFFF3F3F3)),
              _buildInfoCard('✅ Correct', '$_correctAnswers', const Color(0xFFF3F3F3)),
            ],
          ),
        ),
        
        // Current sound instruction - compact
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF5B6F4A),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          ),
          child: Column(
            children: [
              Text(
                '👆 Listen and pick the matching picture!',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              ElevatedButton.icon(
                onPressed: _playCurrentSound,
                icon: const Icon(Icons.volume_up, size: 16),
                label: const Text('🔊 Play Sound'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD740),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        
        // Compact 2x2 grid - use Flexible to take only needed space
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: _currentOptions.isEmpty 
              ? Center(child: Text('No choices loaded!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))
              : GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 3.5, // Balanced aspect ratio
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                  children: _currentOptions.map((item) => _buildCompactSoundOption(item)).toList(),
                ),
          ),
        ),
        
        // Small spacer to fill bottom gap without cutting off content
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildInfoCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSoundOption(SoundItem item) {
    return GestureDetector(
      onTap: () => _selectOption(item),
      child: Container(
        margin: const EdgeInsets.all(0.5), // Minimal margin
        decoration: BoxDecoration(
          color: Colors.grey.shade300, // More gray to look clickable
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: _isAnswering && item.name == _currentSound.name 
                ? Colors.green 
                : Colors.grey.shade500, // Darker border
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Bigger emoji
            Text(
              item.emoji,
              style: const TextStyle(fontSize: 20), // Increased from 12 to 20
            ),
            const SizedBox(width: 4),
            // Bigger text next to emoji
            Flexible(
              child: Text(
                item.name,
                style: const TextStyle(
                  fontSize: 10, // Increased from 7 to 10
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
