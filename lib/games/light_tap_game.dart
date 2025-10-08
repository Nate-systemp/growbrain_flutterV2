import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/background_music_manager.dart';
import '../utils/difficulty_utils.dart';
import '../utils/sound_effects_manager.dart';
import '../utils/help_tts_manager.dart';

class LightTapGame extends StatefulWidget {
  final String difficulty;
  final Future<void> Function({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })?
  onGameComplete;
  final bool requirePinOnExit;

  const LightTapGame({
    Key? key,
    required this.difficulty,
    this.onGameComplete,
    this.requirePinOnExit = false,
  }) : super(key: key);

  @override
  _LightTapGameState createState() => _LightTapGameState();
}

class _LightTapGameState extends State<LightTapGame>
    with TickerProviderStateMixin {
  // Game state
  List<int> sequence = [];
  List<int> userSequence = [];
  int currentLevel = 1;
  int maxLevel = 10;
  bool isShowingSequence = false;
  bool isWaitingForInput = false;
  bool gameStarted = false;
  bool gameOver = false;
  bool showingCountdown = false;
  bool showSimpleInstruction = false;
  int countdownNumber = 3;
  int score = 0;
  int correctSequences = 0;
  int wrongTaps = 0;
  int roundsPlayed = 0;
  int totalRounds = 5;
  DateTime gameStartTime = DateTime.now();
  bool showingGo = false;
  late final AnimationController _goController;
  late final Animation<double> _goOpacity;
  late final Animation<double> _goScale;
  late final AnimationController _hudController;
  late final Animation<double> _hudOpacity;
  late final Animation<double> _hudScale;
  bool showHud = false;
  bool showingStatus = false;
  String overlayText = '';
  Color overlayColor = Colors.green;
  Color overlayTextColor = Colors.white;
  int gridSize = 4;
  int sequenceLength = 1;
  int maxSequenceLength = 8;
  int sequenceSpeed = 800;
  String _normalizedDifficulty = 'Easy';

  List<bool> lightStates = [];
  List<bool> tapStates = [];
  List<AnimationController> animationControllers = [];
  List<Animation<double>> scaleAnimations = [];

  final Color primaryColor = const Color(0xFF5B6F4A);
  final Color accentColor = const Color(0xFFFFD740);
  final Color backgroundColor = const Color(0xFF5B6F4A);
  final Color surfaceColor = Colors.white;
  final Color errorColor = const Color(0xFFE57373);
  final Color successColor = const Color(0xFF81C784);
  final Color headerGradientEnd = const Color(0xFF6B7F5A);

  final List<Color> lightColors = [
    const Color(0xFFFFF9C4),
    const Color(0xFFFFCDD2),
    const Color(0xFFFFE082),
    const Color(0xFFFFECB3),
    const Color(0xFFCFD8DC),
    const Color(0xFFFFCCBC),
    const Color(0xFFB3E5FC),
    const Color(0xFFC8E6C9),
    const Color(0xFFE1BEE7),
  ];

  final Color inactiveLightColor = const Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    BackgroundMusicManager().startGameMusic('Light Tap');
    
    _goController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _goOpacity = CurvedAnimation(parent: _goController, curve: Curves.easeInOut);
    _goScale = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(parent: _goController, curve: Curves.easeOutBack),
    );
    
    _hudController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _hudOpacity = CurvedAnimation(parent: _hudController, curve: Curves.easeInOut);
    _hudScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _hudController, curve: Curves.easeOutBack),
    );
    
    _normalizedDifficulty = DifficultyUtils.normalizeDifficulty(widget.difficulty);
    print('[LightTap] init difficulty="${widget.difficulty}" normalized="$_normalizedDifficulty"');
    _initializeGame();
  }

  @override
  void dispose() {
    for (var controller in animationControllers) {
      controller.dispose();
    }
    _goController.dispose();
    _hudController.dispose();
    BackgroundMusicManager().stopMusic();
    super.dispose();
  }

  void _initializeGame() {
    switch (_normalizedDifficulty) {
      case 'Starter':
        gridSize = 4;
        maxSequenceLength = 5;
        sequenceSpeed = 1000;
        break;
      case 'Growing':
        gridSize = 6;
        maxSequenceLength = 7;
        sequenceSpeed = 800;
        break;
      case 'Challenged':
        gridSize = 9;
        maxSequenceLength = 10;
        sequenceSpeed = 600;
        break;
      default:
        gridSize = 4;
        maxSequenceLength = 5;
        sequenceSpeed = 1000;
        break;
    }

    lightStates = List.generate(gridSize, (index) => false);
    tapStates = List.generate(gridSize, (index) => false);

    switch (_normalizedDifficulty) {
      case 'Starter':
        totalRounds = 3;
        break;
      case 'Growing':
        totalRounds = 5;
        break;
      case 'Challenged':
        totalRounds = 7;
        break;
      default:
        totalRounds = 5;
        break;
    }

    animationControllers = List.generate(
      gridSize,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      ),
    );

    scaleAnimations = animationControllers
        .map(
          (controller) => Tween<double>(begin: 1.0, end: 1.0).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeInOut),
          ),
        )
        .toList();
  }

  void _startGame() {
    setState(() {
      showingCountdown = true;
      countdownNumber = 3;
    });
    _showCountdown();
  }

  void _showCountdown() async {
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() {
        countdownNumber = i;
      });
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    if (mounted) {
      setState(() {
        showingCountdown = false;
        gameStarted = true;
        gameOver = false;
        currentLevel = 1;
        roundsPlayed = 0;
        score = 0;
        correctSequences = 0;
        wrongTaps = 0;
        gameStartTime = DateTime.now();
        sequence.clear();
        userSequence.clear();
        showHud = true;
      });
      _hudController.forward();
      _nextLevel();
    }
  }

  void _nextLevel() {
    if (roundsPlayed >= totalRounds) {
      _endGame(true);
      return;
    }

    setState(() {
      sequenceLength = math.min(currentLevel + 1, maxSequenceLength);
      userSequence.clear();
      isWaitingForInput = false;
    });

    _generateNewSequence();
    _showSequence();
  }

  void _generateNewSequence() {
    final random = math.Random();
    sequence = List.generate(
      sequenceLength,
      (index) => random.nextInt(gridSize),
    );
  }

  void _showSequence() async {
    setState(() {
      isShowingSequence = true;
      isWaitingForInput = false;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    for (int i = 0; i < sequence.length; i++) {
      if (!mounted) return;

      final lightIndex = sequence[i];

      setState(() {
        lightStates[lightIndex] = true;
      });

      await Future.delayed(Duration(milliseconds: sequenceSpeed ~/ 2));

      setState(() {
        lightStates[lightIndex] = false;
      });

      await Future.delayed(Duration(milliseconds: sequenceSpeed ~/ 2));
    }
    
    if (!mounted) return;
    await _showGoOverlay();

    setState(() {
      isShowingSequence = false;
      isWaitingForInput = true;
    });
  }

  Future<void> _showGoOverlay() async {
    if (!mounted) return;
    setState(() => showingGo = true);
    await _goController.forward();
    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    await _goController.reverse();
    if (!mounted) return;
    setState(() => showingGo = false);
  }

  Future<void> _showStatusOverlay({
    required String text,
    required Color color,
    Color textColor = Colors.white,
  }) async {
    if (!mounted) return;
    setState(() {
      overlayText = text;
      overlayColor = color;
      overlayTextColor = textColor;
      showingStatus = true;
    });
    await _goController.forward();
    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    await _goController.reverse();
    if (!mounted) return;
    setState(() {
      showingStatus = false;
    });
  }

  void _onLightTap(int index) {
    if (!isWaitingForInput || isShowingSequence) return;

    _animateTap(index);

    setState(() {
      lightStates[index] = true;
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          lightStates[index] = false;
        });
      }
    });

    userSequence.add(index);

    if (userSequence.length <= sequence.length) {
      final currentIndex = userSequence.length - 1;

      if (userSequence[currentIndex] == sequence[currentIndex]) {
        setState(() {
          score += 10;
        });

        if (userSequence.length == sequence.length) {
          setState(() {
            correctSequences++;
            roundsPlayed++;
            currentLevel++;
            isWaitingForInput = false;
          });

          SoundEffectsManager().playSuccessWithVoice();
          _showStatusOverlay(text: '✓', color: Colors.green, textColor: Colors.white);

          Future.delayed(const Duration(milliseconds: 1000), () {
            if (!mounted) return;
            if (roundsPlayed >= totalRounds) {
              _endGame(true);
            } else {
              _nextLevel();
            }
          });
        }
      } else {
        setState(() {
          wrongTaps++;
          roundsPlayed++;
          isWaitingForInput = false;
        });

        SoundEffectsManager().playWrong();
        _showStatusOverlay(text: 'X', color: Colors.red, textColor: Colors.white);

        Future.delayed(const Duration(milliseconds: 1000), () {
          if (!mounted) return;
          if (roundsPlayed >= totalRounds) {
            _endGame(true);
          } else {
            _nextLevel();
          }
        });
      }
    }
  }

  void _endGame(bool completed) async {
    setState(() {
      gameOver = true;
      isWaitingForInput = false;
      isShowingSequence = false;
    });

    final completionTime = DateTime.now().difference(gameStartTime).inSeconds;
    final totalAttempts = correctSequences + wrongTaps;
    int accuracy = 0;
    if (totalAttempts > 0) {
      accuracy = ((correctSequences / totalAttempts) * 100).round();
    }
    accuracy = accuracy.clamp(0, 100);

    _showGameOverDialog(completed, accuracy, completionTime);
  }

  void _showGameOverDialog(bool completed, int accuracy, int completionTime) {
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
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                completed ? Icons.celebration : Icons.lightbulb_outline,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              completed ? 'Amazing! 🌟' : 'Great Effort! 💡',
              style: TextStyle(
                color: primaryColor,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatRow(Icons.star_rounded, 'Score', '$score points'),
              const SizedBox(height: 12),
              _buildStatRow(Icons.track_changes, 'Accuracy', '$accuracy%'),
              const SizedBox(height: 12),
              _buildStatRow(Icons.timer, 'Time', '${completionTime}s'),
              const SizedBox(height: 12),
              _buildStatRow(Icons.trending_up, 'Level Reached', '$currentLevel'),
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
                        setState(() {
                          score = 0;
                          correctSequences = 0;
                          wrongTaps = 0;
                          roundsPlayed = 0;
                          sequence.clear();
                          userSequence.clear();
                          isShowingSequence = false;
                          isWaitingForInput = false;
                          gameStarted = false;
                          gameOver = false;
                          showingCountdown = false;
                          showHud = false;
                        });
                        _hudController.reset();
                        _initializeGame();
                      },
                      icon: const Icon(Icons.refresh, size: 22),
                      label: const Text(
                        'Play Again',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
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
                      label: Text(
                        'Exit',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: primaryColor, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
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
                onPressed: () async {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                  
                  if (widget.onGameComplete != null) {
                    await widget.onGameComplete!(
                      accuracy: accuracy,
                      completionTime: completionTime,
                      challengeFocus: 'Memory',
                      gameName: 'Light Tap',
                      difficulty: _normalizedDifficulty,
                    );
                  }
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 22),
                label: const Text(
                  'Next Game',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                ),
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

  int _getGridColumns() {
    switch (gridSize) {
      case 4:
        return 2;
      case 6:
        return 2;
      case 9:
        return 3;
      default:
        return 2;
    }
  }

  int _getGridRows() {
    switch (gridSize) {
      case 4:
        return 2;
      case 6:
        return 3;
      case 9:
        return 3;
      default:
        return 2;
    }
  }

  void _handleBackButton(BuildContext context) {
    if (widget.requirePinOnExit) {
      _showTeacherPinDialog(context);
    } else {
      Navigator.of(context).pop();
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
@override
Widget build(BuildContext context) {
  return WillPopScope(
    onWillPop: () async {
      _handleBackButton(context);
      return false;
    },
    child: Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const SizedBox.shrink(),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              image: const DecorationImage(
                image: AssetImage('assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  children: [
                    Expanded(
                      child: showingCountdown
                          ? _buildCountdownScreen()
                          : (gameStarted
                              ? _buildGameGrid()
                              : _buildStartScreenWithInstruction()),
                    ),
                    const SizedBox(height: 0),
                  ],
                ),
                if (showHud) ...[
                  FadeTransition(
                    opacity: _hudOpacity,
                    child: ScaleTransition(
                      scale: _hudScale,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 104),
                          child: _infoCircle(
                            label: 'Round',
                            value: '${math.min(roundsPlayed + 1, totalRounds)}/$totalRounds',
                            circleSize: 104,
                            valueFontSize: 30,
                            labelFontSize: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                  FadeTransition(
                    opacity: _hudOpacity,
                    child: ScaleTransition(
                      scale: _hudScale,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 104),
                          child: _infoCircle(
                            label: 'Correct',
                            value: '$correctSequences',
                            circleSize: 104,
                            valueFontSize: 30,
                            labelFontSize: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (showingGo)
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
                                  const Text(
                                    'Get Ready!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: accentColor,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.30),
                                          offset: const Offset(0, 8),
                                          blurRadius: 0,
                                          spreadRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        'GO!',
                                        style: TextStyle(
                                          color: primaryColor,
                                          fontSize: 54,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (showingStatus)
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
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: overlayColor,
                                ),
                                child: Center(
                                  child: Text(
                                    overlayText,
                                    style: TextStyle(
                                      color: overlayTextColor,
                                      fontSize: 72,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Show Need Help button ONLY when in-game (not on start/instructions/countdown)
                if (gameStarted && !showingCountdown)
                  Positioned(
                    left: 24,
                    bottom: 24,
                    child: _buildHelpButton(),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
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
        HelpTtsManager().speak('Watch the sequence of glowing lights. When it is your turn, tap the same lights in the same order.');
        
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
                      color: const Color(0xFFFFD740),
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
                                color: const Color(0xFF5B6F4A).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.help_outline, color: Color(0xFF5B6F4A), size: 28),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Need Help?',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF5B6F4A),
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
                                ? 'Look at the lights as they glow. After that, tap the lights in the same order you saw them. Try to remember the pattern!'
                                : 'Watch the sequence of glowing lights. When it\'s your turn, tap the same lights in the same order.',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF5B6F4A),
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
                            child: const Text(
                              'That\'s the simpler explanation!',
                              style: TextStyle(
                                color: Color(0xFF5B6F4A),
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
                                      color: const Color(0xFF5B6F4A).withOpacity(0.6),
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
                                        HelpTtsManager().speak('Look at the lights as they glow. After that, tap the lights in the same order you saw them. Try to remember the pattern!');
                                      });
                                    } else {
                                      HelpTtsManager().stop();
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF5B6F4A),
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

  Widget _buildStartScreenWithInstruction() {
    final size = MediaQuery.of(context).size;
    final bool isTablet = size.shortestSide >= 600;
    final double panelMaxWidth = isTablet ? 560.0 : 420.0;

    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: math.min(size.width * 0.9, panelMaxWidth),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    offset: const Offset(0, 12),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Light Tap',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: isTablet ? 42 : 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: isTablet ? 100 : 84,
                    height: isTablet ? 100 : 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0),
                          blurRadius: 20,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.remove_red_eye_outlined,
                      size: isTablet ? 56 : 48,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Watch carefully!',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: isTablet ? 22 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 200),
                    crossFadeState: showSimpleInstruction
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: Text(
                      'Watch the sequence of glowing lights. When it\'s your turn, tap the same lights in the same order.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: primaryColor.withOpacity(0.9),
                        fontSize: isTablet ? 18 : 15,
                        height: 1.35,
                      ),
                    ),
                    secondChild: Text(
                      'Look at the lights as they glow. After that, tap the lights in the same order you saw them. Try to remember the pattern!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: primaryColor.withOpacity(0.9),
                        fontSize: isTablet ? 18 : 15,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
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
                        padding: EdgeInsets.symmetric(
                          vertical: isTablet ? 18 : 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 3,
                      ),
                      child: Text(
                        'START GAME',
                        style: TextStyle(
                          fontSize: isTablet ? 22 : 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
      ],
    );
  }

  Widget _infoCircle({
    required String label,
    required String value,
    double circleSize = 88,
    double valueFontSize = 18,
    double labelFontSize = 12,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: labelFontSize,
            fontWeight: FontWeight.w800,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.45),
                offset: const Offset(2, 2),
                blurRadius: 0,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                offset: const Offset(0, 6),
                blurRadius: 0,
                spreadRadius: 4,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: TextStyle(
              color: primaryColor,
              fontSize: valueFontSize,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCountdownScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Get Ready!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 40),
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFD740),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD740).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$countdownNumber',
                style: const TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5B6F4A),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'The game will start soon...',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameGrid() {
    final columns = _getGridColumns();
    final rows = _getGridRows();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSize = math.min(constraints.maxWidth, constraints.maxHeight);
        final gridSz = maxSize * 0.8;
        final buttonSize = (gridSz / math.max(columns, rows)) - 12;

        return Center(
          child: SizedBox(
            width: gridSz,
            height: gridSz,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: gridSize,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _onLightTap(index),
                  child: AnimatedScale(
                    scale: tapStates[index]
                        ? 0.95
                        : (lightStates[index] ? 1.05 : 1.0),
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeInOut,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: lightStates[index]
                            ? lightColors[index % lightColors.length].withOpacity(0.10)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: buttonSize * 0.38,
                              height: buttonSize * 0.38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: lightColors[index % lightColors.length].withOpacity(0.15),
                                border: Border.all(
                                  color: lightStates[index]
                                      ? lightColors[index % lightColors.length].withOpacity(0.55)
                                      : lightColors[index % lightColors.length].withOpacity(0.35),
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _getLightIcon(index),
                                size: buttonSize * 0.22,
                                color: _iconColorForIndex(index, lightStates[index]),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getLightName(index),
                              style: TextStyle(
                                fontSize: buttonSize * 0.12,
                                fontWeight: FontWeight.w600,
                                color: lightStates[index]
                                    ? Colors.white
                                    : primaryColor.withOpacity(0.8),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _animateTap(int index) {
    setState(() {
      tapStates[index] = true;
    });

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          tapStates[index] = false;
        });
      }
    });
  }

  IconData _getLightIcon(int index) {
    final icons = [
      Icons.star,
      Icons.favorite,
      Icons.flash_on,
      Icons.brightness_high,
      Icons.nightlight,
      Icons.local_fire_department,
      Icons.water_drop,
      Icons.eco,
      Icons.diamond,
    ];
    return icons[index % icons.length];
  }

  String _getLightName(int index) {
    final names = [
      'Star',
      'Heart',
      'Lightning',
      'Sun',
      'Moon',
      'Fire',
      'Water',
      'Leaf',
      'Diamond',
    ];
    return names[index % names.length];
  }

  Color _iconColorForIndex(int index, bool active) {
    final base = lightColors[index % lightColors.length];
    final hsl = HSLColor.fromColor(base);
    final double targetLightness = active ? 0.62 : 0.58;
    final double targetSaturation = (hsl.saturation + 0.18).clamp(0.45, 0.65);
    return HSLColor.fromAHSL(1.0, hsl.hue, targetSaturation, targetLightness).toColor();
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
      setState(() {
        _error = 'PIN must be 6 digits';
      });
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

      final doc = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(user.uid)
          .get();

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
              color: const Color.fromARGB(255, 181, 187, 17),
              blurRadius: 0,
              spreadRadius: 0,
              offset: const Offset(0, 8),
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
                    child: const Icon(Icons.lock, color: Color(0xFF5B6F4A), size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Teacher PIN Required',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF5B6F4A),
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
                child: const Text(
                  'Enter your 6-digit PIN to exit the session and access teacher features.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF5B6F4A),
                    fontWeight: FontWeight.w600,
                  ),
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
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5B6F4A),
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    hintStyle: TextStyle(
                      color: const Color(0xFF5B6F4A).withOpacity(0.4),
                      letterSpacing: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF5B6F4A),
                        width: 2,
                      ),
                    ),
                    errorText: _error,
                    errorStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
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
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.6),
                            blurRadius: 0,
                            spreadRadius: 0,
                            offset: const Offset(0, 4),
                          ),
                        ],
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF5B6F4A).withOpacity(0.6),
                            blurRadius: 0,
                            spreadRadius: 0,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyPin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5B6F4A),
                          foregroundColor: const Color(0xFFFFD740),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFFFFD740),
                                  ),
                                ),
                              )
                            : const Text(
                                'Verify',
                                style: TextStyle(
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
    );
  }
}