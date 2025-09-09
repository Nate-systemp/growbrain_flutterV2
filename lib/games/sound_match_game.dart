import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/background_music_manager.dart';
import '../utils/sound_effects_manager.dart';
import '../utils/difficulty_utils.dart';
import '../teacher_pin_modal.dart';

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
    // Start background music for this game
    BackgroundMusicManager().startGameMusic('Sound Match');
    // Initialize with first round immediately
    _initializeGame();
  }

  @override
  void dispose() {
    // Stop background music when leaving the game
    BackgroundMusicManager().stopMusic();
    super.dispose();
  }

  void _initializeGame() {
    // Generate first round options immediately
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
        difficulty: widget.difficulty,
      );
    }

    // Auto-advance without showing end screen
    Navigator.pop(context);
  }

  void _handleBackButton(BuildContext context) {
    _showTeacherPinDialog(context);
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
    return Column(
      children: [
        // Header bar - Dark olive green style
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF5B6F4A), // Dark olive green header
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
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Column(
                children: [
                  const Text(
                    'Sound Match - Starter',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Round: $_currentRound/5',
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A5A3A), // Slightly darker green
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Get Ready...',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Game area - Light creamy yellow background
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                // Instruction text
                Text(
                  'Listen and pick the matching picture!',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Play sound button
                ElevatedButton.icon(
                  onPressed: _playCurrentSound,
                  icon: const Icon(
                    Icons.volume_up,
                    size: 16,
                    color: Colors.black,
                  ),
                  label: const Text(
                    '🔊 Play Sound',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700), // Bright yellow
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
                const SizedBox(height: 12),

                // Options grid - Fixed size to prevent scrolling
                Expanded(
                  child: _currentOptions.isEmpty
                      ? const Center(
                          child: Text(
                            'No choices loaded!',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : GridView.count(
                          physics:
                              NeverScrollableScrollPhysics(), // Disable scrolling
                          crossAxisCount: 2,
                          childAspectRatio: 2.2, // More compact ratio
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                          children: _currentOptions
                              .map((item) => _buildSoundOption(item))
                              .toList(),
                        ),
                ),
              ],
            ),
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

    return GestureDetector(
      onTap: () => _selectOption(item),
      child: Container(
        decoration: BoxDecoration(
          color: shapeColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(item.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              item.name,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
