import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../utils/background_music_manager.dart';
import '../utils/sound_effects_manager.dart';
import '../utils/difficulty_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/help_tts_manager.dart';

class SoundMatchGame extends StatefulWidget {
  final String difficulty;
  final Function({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })? onGameComplete;

  const SoundMatchGame({Key? key, required this.difficulty, this.onGameComplete}) : super(key: key);

  @override
  _SoundMatchGameState createState() => _SoundMatchGameState();
}

class SoundItem {
  final String name;
  final String emoji;
  final String soundPath;

  SoundItem({required this.name, required this.emoji, required this.soundPath});
}

class _SoundMatchGameState extends State<SoundMatchGame> with TickerProviderStateMixin {
  int _currentRound = 1;
  int _correctAnswers = 0;
  int _totalAttempts = 0;
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
  bool _hearIconAnimating = false;
  bool _showPlayButton = false;
  bool showSimpleInstruction = false;

  // Match Cards–style UI additions
  bool _showingGo = false;
  late final AnimationController _goController;
  late final Animation<double> _goOpacity;
  late final Animation<double> _goScale;

  bool _showingStatus = false;
  String _overlayText = '';
  Color _overlayColor = Colors.green;
  Color _overlayTextColor = Colors.white;

  final Color primaryColor = const Color(0xFF7A5833);
  final Color accentColor = const Color(0xFFF5C16C);

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
    _audioPlayer = AudioPlayer();
    BackgroundMusicManager().startGameMusic('Sound Match');
    _normalizedDifficulty = DifficultyUtils.normalizeDifficulty(widget.difficulty);
    _goController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _goOpacity = CurvedAnimation(parent: _goController, curve: Curves.easeInOut);
    _goScale = Tween<double>(begin: 0.90, end: 1.0).animate(CurvedAnimation(parent: _goController, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _goController.dispose();
    BackgroundMusicManager().stopMusic();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _showingCountdown = true;
      _countdownNumber = 3;
    });
    _showCountdown();
  }

  Future<void> _showGoOverlay() async {
    if (!mounted) return;
    setState(() => _showingGo = true);
    // Speak "GO!"
    SoundEffectsManager().speakGo();
    await _goController.forward();
    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    await _goController.reverse();
    if (!mounted) return;
    setState(() => _showingGo = false);
  }

  Future<void> _showStatusOverlay({required String text, required Color color, Color textColor = Colors.white}) async {
    if (!mounted) return;
    setState(() {
      _overlayText = text;
      _overlayColor = color;
      _overlayTextColor = textColor;
      _showingStatus = true;
    });
    await _goController.forward();
    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    await _goController.reverse();
    if (!mounted) return;
    setState(() => _showingStatus = false);
  }

  void _showCountdown() async {
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _countdownNumber = i);
      // Speak the countdown number
      SoundEffectsManager().speakCountdown(i);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    setState(() {
      _showingCountdown = false;
      _gameStarted = true;
      _gameStartTime = DateTime.now();
      _currentRound = 1;
      _correctAnswers = 0;
      _totalAttempts = 0;
    });
    await _showGoOverlay();
    _initializeGame();
  }

  void _initializeGame() {
    _currentSound = _allSounds[Random().nextInt(_allSounds.length)];
    List<SoundItem> options = [_currentSound];
    List<SoundItem> otherSounds = _allSounds.where((s) => s.name != _currentSound.name).toList()..shuffle();
    options.addAll(otherSounds.take(3));
    options.shuffle();
    setState(() => _currentOptions = options);
    // Play sound immediately on first round (already had countdown)
    Future.delayed(const Duration(milliseconds: 300), _playCurrentSound);
  }

  void _generateNewRound() {
    if (_currentRound > 5) {
      _endGame();
      return;
    }
    _currentSound = _allSounds[Random().nextInt(_allSounds.length)];
    List<SoundItem> options = [_currentSound];
    List<SoundItem> otherSounds = _allSounds.where((s) => s.name != _currentSound.name).toList()..shuffle();
    options.addAll(otherSounds.take(3));
    options.shuffle();
    setState(() {
      _currentOptions = options;
      _isAnswering = false;
    });
    _startRoundCountdown();
  }

  void _startRoundCountdown() {
    setState(() {
      _showingCountdown = true;
      _countdownNumber = 3;
      _showPlayButton = false;
    });
    // Speak initial countdown number
    SoundEffectsManager().speakCountdown(_countdownNumber);
    
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownNumber > 1) {
        setState(() => _countdownNumber--);
        // Speak the countdown number
        SoundEffectsManager().speakCountdown(_countdownNumber);
      } else {
        timer.cancel();
        setState(() => _showingCountdown = false);
        Future.delayed(const Duration(milliseconds: 300), _playCurrentSound);
      }
    });
  }

  void _playCurrentSound() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _hearIconAnimating = true;
      _showPlayButton = false;
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) setState(() => _showingHearIcon = true);
    });
    try {
      String soundPath = _currentSound.soundPath.replaceFirst('assets/', '');
      await _audioPlayer.play(AssetSource(soundPath));
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _showingHearIcon = false);
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) setState(() {
              _hearIconAnimating = false;
              _showPlayButton = true;
            });
          });
        }
      });
    } catch (e) {
      print('Error playing sound: $e');
      setState(() {
        _showingHearIcon = false;
        _hearIconAnimating = false;
        _showPlayButton = true;
      });
    }
  }

  void _onPlayButtonPressed() {
    _playCurrentSound();
  }

  void _selectOption(SoundItem selectedItem) {
    if (!_gameStarted || _isAnswering) return;
    setState(() {
      _isAnswering = true;
      _totalAttempts++;
    });
    HapticFeedback.lightImpact();
    bool isCorrect = selectedItem.name == _currentSound.name;

    if (isCorrect) {
      setState(() => _correctAnswers++);
      SoundEffectsManager().playSuccessWithVoice();
      _showStatusOverlay(text: '✓', color: Colors.green, textColor: Colors.white).then((_) {
        setState(() => _currentRound++);
        _generateNewRound();
      });
    } else {
      SoundEffectsManager().playWrong();
      _showStatusOverlay(text: 'X', color: Colors.red, textColor: Colors.white).then((_) {
        setState(() => _isAnswering = false);
      });
    }
  }

  void _endGame() {
    int completionTime = _gameStartTime != null ? DateTime.now().difference(_gameStartTime!).inSeconds : 0;
    int accuracy = _totalAttempts > 0 ? ((_correctAnswers / _totalAttempts) * 100).round() : 0;
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
      _correctAnswers = 0;
      _totalAttempts = 0;
      _currentRound = 1;
      _gameStarted = false;
      _showPlayButton = true;
      _showingHearIcon = false;
      _hearIconAnimating = false;
      _showingCountdown = false;
      _isAnswering = false;
    });
  }

  void _showGameOverDialog(int accuracy, int completionTime) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        title: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.30), blurRadius: 14, offset: const Offset(0, 6))]),
              child: const Icon(Icons.headphones_rounded, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 16),
            Text('Amazing! 🌟', style: TextStyle(color: primaryColor, fontSize: 26, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatRow(Icons.star_rounded, 'Correct', '$_correctAnswers'),
              const SizedBox(height: 12),
              _buildStatRow(Icons.flash_on, 'Attempts', '$_totalAttempts'),
              const SizedBox(height: 12),
              _buildStatRow(Icons.track_changes, 'Accuracy', '$accuracy%'),
              const SizedBox(height: 12),
              _buildStatRow(Icons.timer, 'Time', '${completionTime}s'),
            ],
          ),
        ),
        actions: [
          if (widget.onGameComplete == null) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _resetGame();
                      },
                      icon: const Icon(Icons.refresh, size: 22),
                      label: const Text('Play Again', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      },
                      icon: Icon(Icons.exit_to_app, size: 22, color: primaryColor),
                      label: Text('Exit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: primaryColor, width: 2), padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 22),
                label: const Text('Next Game', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: accentColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: primaryColor, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(color: primaryColor, fontSize: 14, fontWeight: FontWeight.w500))),
        Text(value, style: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _infoCircle({required String label, required String value, double circleSize = 88, double valueFontSize = 18, double labelFontSize = 12}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: Colors.white, fontSize: labelFontSize, fontWeight: FontWeight.w800, shadows: [Shadow(color: Colors.black.withOpacity(0.45), offset: const Offset(2, 2), blurRadius: 0)])),
        const SizedBox(height: 8),
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), offset: const Offset(0, 6), blurRadius: 0, spreadRadius: 4)]),
          alignment: Alignment.center,
          child: Text(value, style: TextStyle(color: primaryColor, fontSize: valueFontSize, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }

  Widget _buildHelpButton() {
    return FloatingActionButton.extended(
      heroTag: 'helpBtn',
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      icon: const Icon(Icons.help_outline),
      label: const Text('Need Help?'),
      onPressed: () {
        bool showSimple = false;
        // Speak the initial help text
        HelpTtsManager().speak('Listen to sounds and match them with the correct picture. Use your ears to find the right answer!');
        
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) {
              return WillPopScope(
                onWillPop: () async {
                  HelpTtsManager().stop();
                  return true;
                },
                child: Dialog(
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 24,
                      spreadRadius: 0,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 320,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.help_outline, color: primaryColor, size: 28),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Need Help?',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            showSimple
                                ? 'Listen to the sound and tap the picture that makes that sound. Use your ears to find the right picture!'
                                : 'Listen to sounds and match them with the correct picture. Use your ears to find the right answer!',
                            style: TextStyle(
                              fontSize: 16,
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (showSimple)
                          const SizedBox(height: 16),
                        if (showSimple)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'That\'s the simpler explanation!',
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.6),
                                      blurRadius: 0,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: TextButton(
                                  onPressed: () {
                                    if (!showSimple) {
                                      setState(() {
                                        showSimple = true;
                                        // Speak the simpler explanation
                                        HelpTtsManager().speak('Listen to the sound and tap the picture that makes that sound. Use your ears to find the right picture!');
                                      });
                                    } else {
                                      HelpTtsManager().stop();
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: primaryColor,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    showSimple ? 'Close' : 'More Help?',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                  ),
                ),
              );
            },
          ),
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
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/memorybg.png'), fit: BoxFit.cover)),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0x667A5833), Color(0x337A5833)], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
              ),
              Positioned.fill(
                child: _showingCountdown ? _buildCountdownScreen() : (!_gameStarted ? _buildStartScreenWithInstruction() : _buildGameContent()),
              ),
              if (_gameStarted) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 550, right: 180),
                    child: _infoCircle(label: 'Tries', value: '$_totalAttempts', circleSize: 104, valueFontSize: 30, labelFontSize: 26),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 550, left: 180),
                    child: _infoCircle(label: 'Correct', value: '$_correctAnswers/5', circleSize: 104, valueFontSize: 30, labelFontSize: 26),
                  ),
                ),
              ],
              if (_showingGo)
                Positioned.fill(
                  child: IgnorePointer(
                    child: FadeTransition(
                      opacity: _goOpacity,
                      child: Container(
                        color: Colors.black.withOpacity(0.12),
                        child: Center(
                          child: ScaleTransition(
                            scale: _goScale,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Get Ready!', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.30), offset: const Offset(0, 8), blurRadius: 0, spreadRadius: 8)]),
                                  child: Center(child: Text('GO!', style: TextStyle(color: primaryColor, fontSize: 54, fontWeight: FontWeight.bold))),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_showingStatus)
                Positioned.fill(
                  child: IgnorePointer(
                    child: FadeTransition(
                      opacity: _goOpacity,
                      child: Container(
                        color: Colors.black.withOpacity(0.12),
                        child: Center(
                          child: ScaleTransition(
                            scale: _goScale,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: _overlayColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.30), offset: const Offset(0, 8), blurRadius: 0, spreadRadius: 8)]),
                              child: Center(child: Text(_overlayText, style: TextStyle(color: _overlayTextColor, fontSize: 72, fontWeight: FontWeight.bold))),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Show Need Help button ONLY when in-game (not on start/instructions/countdown)
              if (_gameStarted && !_showingCountdown)
                Positioned(
                  left: 24,
                  bottom: 24,
                  child: _buildHelpButton(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleBackButton(BuildContext context) {
    if (widget.onGameComplete == null) {
      Navigator.of(context).pop();
    } else {
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
            Navigator.of(dialogContext).pop();
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          },
          onCancel: () {
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  Widget _buildGameContent() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), spreadRadius: 1, blurRadius: 4, offset: const Offset(0, 2))]),
            child: Text('Listen and pick the matching picture!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor), textAlign: TextAlign.center),
          ),
        ),
        Expanded(
          flex: 2,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_showPlayButton && !_showingHearIcon && !_showingCountdown)
                  AnimatedScale(
                    scale: _showPlayButton ? 1.0 : 0.8,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.elasticOut,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [accentColor, accentColor.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        boxShadow: [BoxShadow(color: accentColor.withOpacity(0.4), spreadRadius: 3, blurRadius: 12, offset: const Offset(0, 6)), BoxShadow(color: Colors.white.withOpacity(0.2), spreadRadius: 1, blurRadius: 4, offset: const Offset(0, -2))],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: _onPlayButtonPressed,
                          customBorder: const CircleBorder(),
                          splashColor: Colors.white.withOpacity(0.3),
                          highlightColor: Colors.white.withOpacity(0.1),
                          child: Container(width: 120, height: 120, child: Center(child: Text('Play\nSound', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor, letterSpacing: 0.5, height: 1.2)))),
                        ),
                      ),
                    ),
                  ),
                if (_showingCountdown)
                  Text('$_countdownNumber', style: const TextStyle(fontSize: 120, fontWeight: FontWeight.bold, color: Colors.white)),
                if (_hearIconAnimating)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOut,
                    transform: Matrix4.translationValues(0, _showingHearIcon ? 0 : 100, 0),
                    child: AnimatedOpacity(opacity: _showingHearIcon ? 1.0 : 0.0, duration: const Duration(milliseconds: 400), child: Image.asset('assets/hear.png', width: 400, height: 400, fit: BoxFit.contain)),
                  ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          child: _currentOptions.isEmpty
              ? Center(child: Text('Loading game...', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(children: _currentOptions.map((option) {
                    int index = _currentOptions.indexOf(option);
                    return Padding(padding: EdgeInsets.only(left: index == 0 ? 0 : 8, right: 8), child: _buildSoundOption(option));
                  }).toList()),
                ),
        ),
      ],
    );
  }

  Widget _buildStartScreenWithInstruction() {
    final size = MediaQuery.of(context).size;
    final bool isTablet = size.shortestSide >= 600;
    final double panelMaxWidth = isTablet ? 560.0 : 420.0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: min(size.width * 0.9, panelMaxWidth)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), offset: const Offset(0, 12), blurRadius: 24, spreadRadius: 2)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Sound Match', style: TextStyle(color: primaryColor, fontSize: isTablet ? 42 : 34, fontWeight: FontWeight.w900, letterSpacing: 0.5), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Container(
                width: isTablet ? 100 : 84,
                height: isTablet ? 100 : 84,
                decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor, boxShadow: [BoxShadow(color: accentColor.withOpacity(0), blurRadius: 20, spreadRadius: 6)]),
                child: Icon(Icons.headphones_rounded, size: isTablet ? 56 : 48, color: primaryColor),
              ),
              const SizedBox(height: 16),
              Text('Listen carefully!', style: TextStyle(color: primaryColor, fontSize: isTablet ? 22 : 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: showSimpleInstruction
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: Text(
                  'Listen to sounds and match them with the correct picture. Use your ears to find the right answer!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: primaryColor.withOpacity(0.9), fontSize: isTablet ? 18 : 15, height: 1.35),
                ),
                secondChild: Text(
                  'Listen to the sound and tap the picture that makes that sound. Use your ears to find the right picture!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: primaryColor.withOpacity(0.9), fontSize: isTablet ? 18 : 15, height: 1.35, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    showSimpleInstruction = !showSimpleInstruction;
                  });
                },
                icon: Icon(Icons.help_outline, color: primaryColor),
                label: Text(
                  showSimpleInstruction
                      ? 'Show Original Instruction'
                      : 'Need a simpler explanation?',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: isTablet ? 16 : 14,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: primaryColor,
                    padding: EdgeInsets.symmetric(vertical: isTablet ? 18 : 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                  ),
                  child: Text('START GAME', style: TextStyle(fontSize: isTablet ? 22 : 18, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Get Ready!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 40),
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor, boxShadow: [BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)]),
            child: Center(child: Text('$_countdownNumber', style: TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: primaryColor))),
          ),
          const SizedBox(height: 40),
          Text('The game will start soon...', style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSoundOption(SoundItem item) {
    bool isCorrect = _isAnswering && item.name == _currentSound.name;
    Color shapeColor = isCorrect ? const Color(0xFF8FBC8F) : primaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectOption(item),
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 120,
          height: 130,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: isCorrect ? const Color(0xFF8FBC8F).withOpacity(0.3) : Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: isCorrect ? const Color(0xFF8FBC8F) : Colors.white.withOpacity(0.4), width: 3),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 40, shadows: [Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 2)]))),
              ),
              const SizedBox(height: 8),
              Text(item.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isCorrect ? const Color(0xFF8FBC8F) : Colors.white), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

// PIN DIALOG CLASS
class _TeacherPinDialog extends StatefulWidget {
  final VoidCallback onPinVerified;
  final VoidCallback? onCancel;

  const _TeacherPinDialog({required this.onPinVerified, this.onCancel});

  @override
  State<_TeacherPinDialog> createState() => _TeacherPinDialogState();
}

class _TeacherPinDialogState extends State<_TeacherPinDialog> {
  final TextEditingController _pinController = TextEditingController();
  String? _error;
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verifyPin() async {
    final pin = _pinController.text.trim();
    if (pin.length != 6 || !RegExp(r'^[0-9]{6}').hasMatch(pin)) {
      setState(() => _error = 'PIN must be 6 digits');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Not logged in.';
          _isLoading = false;
        });
        return;
      }
      final doc = await FirebaseFirestore.instance.collection('teachers').doc(user.uid).get();
      final savedPin = doc.data()?['pin'];
      if (savedPin == null) {
        setState(() {
          _error = 'No PIN set. Please contact your administrator.';
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
        _error = 'Failed to verify PIN. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Color.fromARGB(255, 181, 187, 17),
              blurRadius: 0,
              spreadRadius: 0,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD740),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B6F4A).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.lock, color: const Color(0xFF5B6F4A), size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Teacher PIN Required',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF5B6F4A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Enter your 6-digit PIN to exit the session and access teacher features.',
                  style: TextStyle(fontSize: 16, color: const Color(0xFF5B6F4A), fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5B6F4A).withOpacity(0.2),
                      blurRadius: 0,
                      spreadRadius: 0,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold, color: Color(0xFF5B6F4A)),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    hintStyle: TextStyle(color: const Color(0xFF5B6F4A).withOpacity(0.4), letterSpacing: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: const Color(0xFF5B6F4A), width: 2)),
                    errorText: _error,
                    errorStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                  onSubmitted: (_) => _verifyPin(),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.6), blurRadius: 0, spreadRadius: 0, offset: Offset(0, 4))],
                      ),
                      child: TextButton(
                        onPressed: () {
                          if (widget.onCancel != null) {
                            widget.onCancel!();
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF5B6F4A),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: const Color(0xFF5B6F4A).withOpacity(0.6), blurRadius: 0, spreadRadius: 0, offset: Offset(0, 4))],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyPin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5B6F4A),
                          foregroundColor: const Color(0xFFFFD740),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD740))))
                            : const Text('Verify', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}