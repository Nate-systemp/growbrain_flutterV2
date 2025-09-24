import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import '../utils/background_music_manager.dart';
import '../utils/sound_effects_manager.dart';
import '../utils/difficulty_utils.dart';

class SoundMatchGame extends StatefulWidget {
  final String difficulty;
  final Function({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })?
  onGameComplete;

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
  final String soundPath;

  SoundItem({
    required this.name,
    required this.emoji,
    required this.soundPath,
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
  late String _normalizedDifficulty;
  bool _gameStarted = false;
  late AudioPlayer _audioPlayer;
  bool _showingCountdown = false;
  int _countdownNumber = 3;
  bool _showingHearIcon = false;
  bool _showPlayButton = false;
  
  // App color scheme
  final Color primaryColor = const Color(0xFF5B6F4A);
  final Color accentColor = const Color(0xFFFFD740);
  final Color backgroundColor = const Color(0xFFF5F5DC);

  final List<SoundItem> _allSounds = [
    SoundItem(name: 'Dog', emoji: '🐕', soundPath: 'assets/soundfxforsoundmatch/dog bark.wav'),
    SoundItem(name: 'Cat', emoji: '🐱', soundPath: 'assets/soundfxforsoundmatch/cat meow.ogg'),
    SoundItem(name: 'Bird', emoji: '🐦', soundPath: 'assets/soundfxforsoundmatch/bird tweet.wav'),
    SoundItem(name: 'Cow', emoji: '🐄', soundPath: 'assets/soundfxforsoundmatch/cows moo.wav'),
    SoundItem(name: 'Car', emoji: '🚗', soundPath: 'assets/soundfxforsoundmatch/car broom.wav'),
    SoundItem(name: 'Train', emoji: '🚂', soundPath: 'assets/soundfxforsoundmatch/train choo choo.mp3'),
    SoundItem(name: 'Rain', emoji: '🌧️', soundPath: 'assets/soundfxforsoundmatch/rain pitta patter.wav'),
    SoundItem(name: 'Thunder', emoji: '⛈️', soundPath: 'assets/soundfxforsoundmatch/thunder sound.ogg'),
    SoundItem(name: 'Bell', emoji: '🔔', soundPath: 'assets/soundfxforsoundmatch/bell sound.wav'),
    SoundItem(name: 'Drum', emoji: '🥁', soundPath: 'assets/soundfxforsoundmatch/drum sounds.mp3'),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize audio player
    _audioPlayer = AudioPlayer();
    // Start background music for this game
    BackgroundMusicManager().startGameMusic('Sound Match');
    _normalizedDifficulty = DifficultyUtils.normalizeDifficulty(widget.difficulty);
    // Don't initialize game automatically
  }

  @override
  void dispose() {
    // Dispose audio player
    _audioPlayer.dispose();
    // Stop background music when leaving the game
    BackgroundMusicManager().stopMusic();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _gameStarted = true;
      _gameStartTime = DateTime.now();
    });
    _initializeGame();
  }

  void _initializeGame() {
    // Generate first round options
    _currentSound = _allSounds[Random().nextInt(_allSounds.length)];

    List<SoundItem> options = [_currentSound];
    List<SoundItem> otherSounds = _allSounds
        .where((s) => s.name != _currentSound.name)
        .toList();
    otherSounds.shuffle();
    options.addAll(otherSounds.take(3));
    options.shuffle();

    setState(() {
      _currentOptions = options;
      _currentRound = 1;
      _score = 0;
      _correctAnswers = 0;
    });
    
    // Start countdown before playing first sound
    _startCountdown();
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
    List<SoundItem> otherSounds = _allSounds
        .where((s) => s.name != _currentSound.name)
        .toList();
    otherSounds.shuffle();
    options.addAll(otherSounds.take(3));
    options.shuffle();

    setState(() {
      _currentOptions = options;
      _isAnswering = false;
    });

    // Start countdown before playing sound
    _startCountdown();
  }

  void _startCountdown() {
    setState(() {
      _showingCountdown = true;
      _countdownNumber = 3;
    });

    Timer.periodic(Duration(seconds: 1), (timer) {
      if (_countdownNumber > 1) {
        setState(() {
          _countdownNumber--;
        });
      } else {
        timer.cancel();
        setState(() {
          _showingCountdown = false;
        });
        // Play sound after countdown
        Future.delayed(Duration(milliseconds: 300), _playCurrentSound);
      }
    });
  }

  void _playCurrentSound() async {
    HapticFeedback.mediumImpact();
    
    // Show hear icon, hide play button
    setState(() {
      _showingHearIcon = true;
      _showPlayButton = false;
    });
    
    try {
      // Play the actual sound file
      // Remove 'assets/' prefix for AssetSource
      String soundPath = _currentSound.soundPath.replaceFirst('assets/', '');
      await _audioPlayer.play(AssetSource(soundPath));
      
      // Hide hear icon and show play button after 2 seconds
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showingHearIcon = false;
            _showPlayButton = true;
          });
        }
      });
    } catch (e) {
      print('Error playing sound: $e');
      // Hide hear icon and show play button on error
      setState(() {
        _showingHearIcon = false;
        _showPlayButton = true;
      });
      // Only show error snackbar if there's an actual error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error playing ${_currentSound.name} sound'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _onPlayButtonPressed() {
    // Hide play button and start countdown
    setState(() {
      _showPlayButton = false;
    });
    _startCountdown();
  }

  void _selectOption(SoundItem selectedItem) {
    if (!_gameStarted || _isAnswering) return;

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

      // Play success sound with voice effect
      SoundEffectsManager().playSuccessWithVoice();

      _showFeedback('🎉 Correct! Great job!', Colors.green);

      Future.delayed(Duration(seconds: 1), () {
        setState(() {
          _currentRound++;
        });
        _generateNewRound();
      });
    } else {
      // Play wrong sound effect
      SoundEffectsManager().playWrong();
      
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
    int accuracy = _correctAnswers > 0
        ? ((_correctAnswers / 5) * 100).round()
        : 0;

    if (widget.onGameComplete != null) {
      widget.onGameComplete!(
        accuracy: accuracy,
        completionTime: completionTime,
        challengeFocus: 'Auditory Processing',
        gameName: 'Sound Match',
        difficulty: _normalizedDifficulty,
      );
    }

    _showGameOverDialog(accuracy, completionTime);
  }

  void _resetGame() {
    setState(() {
      _score = 0;
      _correctAnswers = 0;
      _currentRound = 1;
      _gameStarted = false;
      _showPlayButton = true;
      _showingHearIcon = false;
      _showingCountdown = false;
      _isAnswering = false;
    });
    
    _generateNewRound();
  }

  void _showGameOverDialog(int accuracy, int completionTime) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.headphones_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Great Listening! 🎧✨',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatRow(Icons.star_rounded, 'Final Score', '$_score points'),
                const SizedBox(height: 12),
                _buildStatRow(Icons.flag_circle, 'Rounds Completed', '5/5'),
                const SizedBox(height: 12),
                _buildStatRow(Icons.track_changes, 'Accuracy', '$accuracy%'),
                const SizedBox(height: 12),
                _buildStatRow(Icons.timer, 'Time Used', '${completionTime}s'),
              ],
            ),
          ),
          actions: [
            // Different actions for demo mode vs session mode
            if (widget.onGameComplete == null) ...[
              // Demo mode: Show Play Again and Exit buttons
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _resetGame();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.refresh, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Play Again',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          Navigator.of(context).pop(); // Exit game
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.exit_to_app, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Exit',
                              style: TextStyle(
                                fontSize: 16,
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
            ] else ...[
              // Session mode: Show Next Game button
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Exit game and return to session screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Next Game',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primaryColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: primaryColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _handleBackButton(BuildContext context) {
    // If this is a demo game (onGameComplete is null), allow direct navigation back
    if (widget.onGameComplete == null) {
      Navigator.of(context).pop();
    } else {
      // Only show PIN dialog for actual student sessions
      _showTeacherPinDialog(context);
    }
  }

  void _showTeacherPinDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _TeacherPinDialog(
          onPinVerified: () {
            Navigator.of(dialogContext).pop(); // Close dialog
            // Exit session and go to home screen after PIN verification
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/home', (route) => false);
          },
          onCancel: () {
            Navigator.of(
              dialogContext,
            ).pop(); // Just close dialog, stay in game
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackButton(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(
          0xFFFDFBEF,
        ), // Light creamy yellow background
        body: SafeArea(child: _buildGameContent()),
      ),
    );
  }

  Widget _buildGameContent() {
    if (!_gameStarted) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Round and Correct counters
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Round',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '$_currentRound/5',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Correct',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '$_correctAnswers',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 40),
          // Game icon and title
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.headphones,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Text(
              'Listen carefully!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Text(
              'Listen to sounds and match them with pictures!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 4,
            ),
            onPressed: _startGame,
            child: const Text(
              'Start !',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // Header bar - Dark olive green style
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Score: $_score',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Round: $_currentRound/5',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // Game area - Light creamy yellow background
        Expanded(
          child: Stack(
            children: [
              Column(
                children: [
                  // Top instruction area
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Listen and pick the matching picture!',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5B6F4A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  
                  // Center area for hear icon and play button
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Play sound button - only show when _showPlayButton is true AND hear icon is hidden
                          if (_showPlayButton && !_showingHearIcon)
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withOpacity(0.3),
                                    spreadRadius: 2,
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _onPlayButtonPressed,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  foregroundColor: primaryColor,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.volume_up, size: 24),
                                label: const Text(
                                  'Play Sound',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Bottom options area
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: _currentOptions.isEmpty
                        ? const Center(
                            child: Text(
                              'Loading game...',
                              style: TextStyle(
                                color: Color(0xFF5B6F4A),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // First row
                              if (_currentOptions.length >= 2)
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSoundOption(_currentOptions[0]),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildSoundOption(_currentOptions[1]),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 16),
                              // Second row
                              if (_currentOptions.length >= 4)
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSoundOption(_currentOptions[2]),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildSoundOption(_currentOptions[3]),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                  ),
              ],
            ),
              // Countdown overlay
              if (_showingCountdown)
                Center(
                  child: Text(
                    '$_countdownNumber',
                    style: const TextStyle(
                      fontSize: 120,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5B6F4A),
                    ),
                  ),
                ),
              // Hear icon overlay
              if (_showingHearIcon)
                Center(
                  child: AnimatedOpacity(
                    opacity: _showingHearIcon ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 500),
                    child: Image.asset(
                      'assets/hear.png',
                      width: 400,
                      height: 400,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSoundOption(SoundItem item) {
    bool isCorrect = _isAnswering && item.name == _currentSound.name;

    Color shapeColor;
    if (isCorrect) {
      shapeColor = const Color(0xFF8FBC8F); // Light green for correct
    } else {
      shapeColor = const Color(0xFF5B6F4A); // Dark olive green for normal
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectOption(item),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 70, // Slightly taller for better touch target
          decoration: BoxDecoration(
            color: shapeColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Emoji with fixed width for alignment
                SizedBox(
                  width: 30,
                  child: Center(
                    child: Text(
                      item.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Text taking remaining space
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.left,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeacherPinDialog extends StatefulWidget {
  final VoidCallback onPinVerified;
  final VoidCallback? onCancel;

  const _TeacherPinDialog({required this.onPinVerified, this.onCancel});

  @override
  State<_TeacherPinDialog> createState() => _TeacherPinDialogState();
}

class _TeacherPinDialogState extends State<_TeacherPinDialog> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _verifyPin() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final pin = _pinController.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        _error = 'Not logged in.';
        _isLoading = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(user.uid)
          .get();
      final savedPin = doc.data()?['pin'];

      if (savedPin == null) {
        setState(() {
          _error = 'No PIN set. Please create one.';
          _isLoading = false;
        });
        return;
      }

      if (pin != savedPin) {
        setState(() {
          _error = 'Incorrect PIN.';
          _isLoading = false;
        });
        return;
      }

      widget.onPinVerified();
    } catch (e) {
      setState(() {
        _error = 'Failed to check PIN.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 300, // Fixed width to prevent stretching
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Green header bar with shield icon and title
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12), // Reduced from 16
              decoration: const BoxDecoration(
                color: Color(0xFF5B6F4A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.shield,
                    color: Colors.white,
                    size: 20,
                  ), // Reduced from 24
                  const SizedBox(width: 8),
                  const Text(
                    'Teacher PIN Required',
                    style: TextStyle(
                      fontSize: 16, // Reduced from 18
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Content area
            Padding(
              padding: const EdgeInsets.all(16), // Reduced from 20
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter your 6-digit PIN to exit the session and access teacher features.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                    ), // Reduced from 14
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16), // Reduced from 20
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18, // Reduced from 20
                      letterSpacing: 6,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '••••••',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        letterSpacing: 6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: const Color(0xFF5B6F4A),
                          width: 2,
                        ),
                      ),
                      errorText: _error,
                      errorStyle: const TextStyle(
                        fontSize: 11,
                      ), // Reduced from 12
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, // Reduced from 16
                        vertical: 10, // Reduced from 12
                      ),
                    ),
                    onSubmitted: (_) => _verifyPin(),
                  ),
                  const SizedBox(height: 16), // Reduced from 20
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            if (widget.onCancel != null) {
                              widget.onCancel!();
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ), // Reduced from 12
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ), // Reduced from 14
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyPin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5B6F4A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ), // Reduced from 12
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 14, // Reduced from 16
                                  width: 14, // Reduced from 16
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Verify',
                                  style: TextStyle(
                                    fontSize: 13, // Reduced from 14
                                    fontWeight: FontWeight.bold,
                                  ),
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
    );
  }
}
