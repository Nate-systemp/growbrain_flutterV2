import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/background_music_manager.dart';
import '../utils/difficulty_utils.dart';
import '../utils/sound_effects_manager.dart';
import '../utils/help_tts_manager.dart';

enum ShapeType {
  circle,
  square,
  triangle,
  diamond,
  pentagon,
  hexagon,
  star,
  oval,
}

class GameShape {
  ShapeType type;
  Color color;
  bool isMoved;

  GameShape({required this.type, required this.color, this.isMoved = false});
}

class WhoMovedGame extends StatefulWidget {
  final String difficulty;
  final String? challengeFocus;
  final String? gameName;
  final Future<void> Function({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })?
  onGameComplete;

  const WhoMovedGame({
    super.key,
    required this.difficulty,
    this.challengeFocus,
    this.gameName,
    this.onGameComplete,
  });

  @override
  _WhoMovedGameState createState() => _WhoMovedGameState();
}

class _WhoMovedGameState extends State<WhoMovedGame>
    with TickerProviderStateMixin {
  List<GameShape> shapes = [];
  int movedShapeIndex = -1;
  int? selectedShapeIndex;
  List<bool> tapStates = [];
  int score = 0;
  int timer = 0;
  int roundsPlayed = 0;
  int correctAnswers = 0;
  late DateTime gameStartTime;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _resultAnimationController;
  late Animation<double> _resultScaleAnimation;
  late Animation<double> _resultBounceAnimation;
  bool gameStarted = false;
  bool showingAnimation = false;
  bool canSelect = false;
  bool gameCompleted = false;
  bool showingCountdown = false;
  int countdownNumber = 3;
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
  bool showingResult = false;
  String resultText = '';
  bool isCorrectResult = false;
  String _normalizedDifficulty = 'Starter';

  final Color primaryColor = const Color(0xFF5B6F4A);
  final Color accentColor = const Color(0xFFFFD740);
  final Color backgroundColor = const Color(0xFFF5F5DC);
  final Color headerGradientEnd = const Color(0xFF6B7F5A);
  final Color surfaceColor = const Color(0xFFF5F5DC);

  ShapeType? previousMovedShapeType;
  static const int totalRounds = 3;

  int get numberOfShapes {
    switch (_normalizedDifficulty) {
      case 'Starter':
        return 3;
      case 'Growing':
        return 5;
      case 'Challenged':
        return 8;
      default:
        return 3;
    }
  }

  int get timerDuration {
    int baseDuration;
    switch (_normalizedDifficulty) {
      case 'Starter':
        baseDuration = 30;
        break;
      case 'Growing':
        baseDuration = 25;
        break;
      case 'Challenged':
        baseDuration = 20;
        break;
      default:
        baseDuration = 30;
    }
    int reduction = (roundsPlayed) * 5;
    return math.max(10, baseDuration - reduction);
  }

  Duration get shakeDuration {
    double baseDurationSeconds;
    switch (_normalizedDifficulty) {
      case 'Starter':
        baseDurationSeconds = 1.0;
        break;
      case 'Growing':
        baseDurationSeconds = 0.8;
        break;
      case 'Challenged':
        baseDurationSeconds = 0.6;
        break;
      default:
        baseDurationSeconds = 1.0;
    }
    double speedIncrease = (roundsPlayed) * 0.15;
    double finalDuration = math.max(0.3, baseDurationSeconds - speedIncrease);
    return Duration(milliseconds: (finalDuration * 1000).round());
  }

  @override
  void initState() {
    super.initState();
    gameStartTime = DateTime.now();
    BackgroundMusicManager().startGameMusic('Who Moved?');
    _normalizedDifficulty = DifficultyUtils.normalizeDifficulty(
      widget.difficulty,
    );

    print(
      '[WhoMoved] init difficulty="${widget.difficulty}" normalized="$_normalizedDifficulty"',
    );

    _shakeController = AnimationController(
      duration: shakeDuration,
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _resultAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _resultScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _resultAnimationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _resultBounceAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _resultAnimationController,
        curve: const Interval(0.6, 1.0, curve: Curves.bounceOut),
      ),
    );

    _goController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _goOpacity = CurvedAnimation(
      parent: _goController,
      curve: Curves.easeInOut,
    );
    _goScale = Tween<double>(begin: 0.9, end: 1.0).animate(
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
    _initializeGame();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _resultAnimationController.dispose();
    _goController.dispose();
    _hudController.dispose();
    BackgroundMusicManager().stopMusic();
    super.dispose();
  }

  void _initializeGame() {
    final colors = [
      const Color(0xFF5B6F4A),
      const Color(0xFFFFD740),
      const Color(0xFF8BC34A),
      const Color(0xFFFF9800),
      const Color(0xFF2196F3),
      const Color(0xFF9C27B0),
      const Color(0xFFE91E63),
      const Color(0xFF607D8B),
    ];

    final availableTypes = ShapeType.values
        .where((t) => t != ShapeType.circle)
        .toList();
    availableTypes.shuffle();

    shapes.clear();
    final selectedTypes = <ShapeType>[];
    while (selectedTypes.length < numberOfShapes) {
      selectedTypes.addAll(availableTypes);
    }
    selectedTypes.shuffle();
    final typesToUse = selectedTypes.take(numberOfShapes).toList();

    for (int i = 0; i < numberOfShapes; i++) {
      shapes.add(
        GameShape(type: typesToUse[i], color: colors[i % colors.length]),
      );
    }

    tapStates = List.generate(numberOfShapes, (index) => false);

    final rand = math.Random();
    int candidate = rand.nextInt(numberOfShapes);
    const int maxAttempts = 8;
    int attempts = 0;
    while (previousMovedShapeType != null &&
        shapes[candidate].type == previousMovedShapeType &&
        attempts < maxAttempts) {
      candidate = rand.nextInt(numberOfShapes);
      attempts++;
    }
    movedShapeIndex = candidate;
    previousMovedShapeType = shapes[movedShapeIndex].type;

    selectedShapeIndex = null;
    canSelect = false;
    showingAnimation = false;
  }

  void _startRoundTimer() {
    setState(() {
      timer = timerDuration;
    });
    _runTimer();
  }

  void _runTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && timer > 0 && canSelect && !gameCompleted) {
        setState(() {
          timer--;
        });
        _runTimer();
      } else if (timer <= 0 && canSelect) {
        _handleTimeUp();
      }
    });
  }

  void _handleTimeUp() {
    setState(() {
      canSelect = false;
    });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: primaryColor,
        title: const Text('Time\'s Up!', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You ran out of time for this round.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: accentColor),
            onPressed: () {
              Navigator.of(context).pop();
              _nextRound();
            },
            child: const Text('Next Round'),
          ),
        ],
      ),
    );
  }

  void _startGame() {
    _shakeController.duration = shakeDuration;
    _shakeController.reset();
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    setState(() {
      gameStarted = true;
      showingCountdown = true;
      showingAnimation = false;
      canSelect = false;
      timer = 0;
      countdownNumber = 3;
    });

    print(
      '[WhoMoved] start round ${roundsPlayed + 1} with speed=${shakeDuration.inMilliseconds}ms',
    );

    _startCountdown();
  }

  void _startCountdown() {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && countdownNumber > 1) {
        setState(() {
          countdownNumber--;
        });
        _startCountdown();
      } else if (mounted) {
        setState(() {
          showingCountdown = false;
          showingAnimation = true;
          showHud = true;
        });
        _hudController.forward();

        Future.delayed(const Duration(milliseconds: 500), () async {
          if (mounted) {
            await _shakeController.forward();
            await Future.delayed(const Duration(milliseconds: 400));

            if (mounted) {
              await _showGoOverlay();
              if (!mounted) return;
              setState(() {
                showingAnimation = false;
                canSelect = true;
              });
              _startRoundTimer();
            }
          }
        });
      }
    });
  }

  Future<void> _showGoOverlay() async {
    if (!mounted) return;

    setState(() {
      showingAnimation = false;
      showingGo = true;
    });

    await _goController.forward();
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    await _goController.reverse();
    if (!mounted) return;

    setState(() {
      showingGo = false;
      canSelect = true;
    });
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

  void _selectShape(int index) async {
    if (!canSelect) return;

    _animateTap(index);

    setState(() {
      selectedShapeIndex = index;
      canSelect = false;
    });

    if (index == movedShapeIndex) {
      score += 10;
      correctAnswers++;
      SoundEffectsManager().playSuccessWithVoice();
      await _showStatusOverlay(text: '✓', color: Colors.green, textColor: Colors.white);
    } else {
      SoundEffectsManager().playWrong();
      await _showStatusOverlay(text: 'X', color: Colors.red, textColor: Colors.white);
    }

    if (!mounted) return;
    _nextRound();
  }

  void _showResult(bool correct) {
    setState(() {
      showingResult = true;
      isCorrectResult = correct;
      resultText = correct ? 'Correct!' : 'Wrong!';
    });

    _resultAnimationController.reset();
    _resultAnimationController.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          showingResult = false;
        });
        _resultAnimationController.reset();
        _nextRound();
      }
    });
  }

  void _nextRound() {
    setState(() {
      roundsPlayed++;
    });

    if (roundsPlayed >= totalRounds) {
      _endGame();
      return;
    }

    _shakeController.reset();
    _resultAnimationController.reset();

    setState(() {
      timer = 0;
    });

    _initializeGame();

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _startGame();
      }
    });
  }

  void _endGame() {
    setState(() {
      gameCompleted = true;
      canSelect = false;
    });

    if (widget.onGameComplete != null) {
      final completionTime = DateTime.now().difference(gameStartTime).inSeconds;
      int accuracy = 0;
      if (roundsPlayed > 0) {
        final safeCorrect = math.min(correctAnswers, roundsPlayed);
        accuracy = ((safeCorrect / roundsPlayed) * 100).round();
      }
      accuracy = accuracy.clamp(0, 100);
      widget.onGameComplete!(
        accuracy: accuracy,
        completionTime: completionTime,
        challengeFocus: widget.challengeFocus ?? 'Memory',
        gameName: widget.gameName ?? 'Who Moved?',
        difficulty: _normalizedDifficulty,
      );
    }

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
              child: const Icon(
                Icons.emoji_events,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Excellent Work! 🎉',
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
              _buildStatRow(
                Icons.flag_circle,
                'Rounds Completed',
                '$correctAnswers/$totalRounds',
              ),
              const SizedBox(height: 12),
              _buildStatRow(Icons.star_rounded, 'Final Score', '$score points'),
              const SizedBox(height: 12),
              _buildStatRow(
                Icons.speed,
                'Accuracy',
                '${((correctAnswers / totalRounds) * 100).round()}%',
              ),
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
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
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

  Widget _infoCircle({
    required String label,
    required String value,
    double circleSize = 84,
    double valueFontSize = 18,
    double labelFontSize = 12,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color.fromARGB(255, 255, 255, 255),
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
              color: valueColor ?? primaryColor,
              fontSize: valueFontSize,
              fontWeight: FontWeight.w900,
            ),
          ),
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
        HelpTtsManager().speak('Watch carefully as one shape moves briefly. When the movement stops, tap the shape that moved.');
        
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
                                ? 'Look at the shapes. One of them will shake or move a little. After they stop moving, tap the shape that moved!'
                                : 'Watch carefully as one shape moves briefly. When the movement stops, tap the shape that moved.',
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
                                        HelpTtsManager().speak('Look at the shapes. One of them will shake or move a little. After they stop moving, tap the shape that moved!');
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

    return Center(
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
                'Who Moved',
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
              Text(
                'You will see several shapes. One of them will move briefly. Can you spot which one moved?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryColor.withOpacity(0.9),
                  fontSize: isTablet ? 18 : 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
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
    );
  }

  void _resetGame() {
    setState(() {
      score = 0;
      timer = 0;
      gameStarted = false;
      roundsPlayed = 0;
      correctAnswers = 0;
      gameCompleted = false;
      canSelect = false;
      showingAnimation = false;
      showingCountdown = false;
      countdownNumber = 3;
      showingResult = false;
      resultText = '';
      isCorrectResult = false;
      showHud = false;
    });
    gameStartTime = DateTime.now();
    _shakeController.reset();
    _initializeGame();
  }

  void _animateTap(int index) {
    setState(() {
      tapStates[index] = true;
    });

    Future.delayed(Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          tapStates[index] = false;
        });
      }
    });
  }

  Widget _buildShapeGrid() {
    int columns;
    double shapeSize;
    switch (numberOfShapes) {
      case 3:
        columns = 3;
        shapeSize = 270.0;
        break;
      case 5:
        columns = 3;
        shapeSize = 240.0;
        break;
      case 8:
        columns = 2;
        shapeSize = 260.0;
        break;
      default:
        columns = 3;
        shapeSize = 190.0;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double availableWidth = constraints.maxWidth;
        double spacing = numberOfShapes == 8 ? 12.0 : 18.0;
        double maxShapeSize =
            (availableWidth - (columns - 1) * spacing) / columns;
        shapeSize = math.min(shapeSize, maxShapeSize - 16);

        return Wrap(
          alignment: WrapAlignment.center,
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(numberOfShapes, (index) {
            bool isSelected = selectedShapeIndex == index;
            bool isMoved = index == movedShapeIndex && showingAnimation;

            return AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                double shakeOffset = 0;
                if (isMoved) {
                  shakeOffset =
                      math.sin(_shakeAnimation.value * math.pi * 8) * 2;
                }
                return Transform.translate(
                  offset: Offset(shakeOffset, 0),
                  child: GestureDetector(
                    onTap: () => _selectShape(index),
                    child: AnimatedScale(
                      scale: tapStates[index] ? 0.9 : 1.0,
                      duration: Duration(milliseconds: 150),
                      curve: Curves.easeInOut,
                      child: Container(
                        width: shapeSize,
                        height: shapeSize,
                        child: Center(
                          child: CustomShapeWidget(
                            shape: shapes[index],
                            size: shapeSize,
                            isSelected: isSelected,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        );
      },
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
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/home', (route) => false);
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackButton(context);
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Scaffold(
            backgroundColor: const Color.fromARGB(0, 0, 0, 0),
            appBar: null,
            body: SafeArea(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 70),
                        if (showHud) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              FadeTransition(
                                opacity: _hudOpacity,
                                child: ScaleTransition(
                                  scale: _hudScale,
                                  child: _infoCircle(
                                    label: 'Score',
                                    value: '$score',
                                    circleSize: 110,
                                    valueFontSize: 30,
                                    labelFontSize: 26,
                                  ),
                                ),
                              ),
                              FadeTransition(
                                opacity: _hudOpacity,
                                child: ScaleTransition(
                                  scale: _hudScale,
                                  child: _infoCircle(
                                    label: 'Round',
                                    value: '${roundsPlayed + 1}/$totalRounds',
                                    circleSize: 110,
                                    valueFontSize: 30,
                                    labelFontSize: 26,
                                  ),
                                ),
                              ),
                              FadeTransition(
                                opacity: _hudOpacity,
                                child: ScaleTransition(
                                  scale: _hudScale,
                                  child: _infoCircle(
                                    label: 'Time',
                                    value: canSelect && timer > 0
                                        ? '${timer}s'
                                        : showingAnimation
                                        ? '...'
                                        : '${timer}s',
                                    circleSize: 110,
                                    valueFontSize: 30,
                                    labelFontSize: 26,
                                    valueColor: timer <= 5 && canSelect
                                        ? Colors.red
                                        : primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                if (!gameStarted) ...[
                                  Expanded(
                                    child: _buildStartScreenWithInstruction(),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 10),
                                  Expanded(
                                    child: Stack(
                                      children: [
                                        if (showingAnimation || showingGo || canSelect || showingResult || showingStatus)
                                          Center(
                                            child: RepaintBoundary(
                                              child: _buildShapeGrid(),
                                            ),
                                          )
                                        else
                                          const SizedBox.shrink(),
                                        if (showingCountdown)
                                          Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text(
                                                  'Get Ready!',
                                                  style: TextStyle(
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(height: 24),
                                                Container(
                                                  width: 150,
                                                  height: 150,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: accentColor,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: accentColor.withOpacity(0.3),
                                                        blurRadius: 20,
                                                        spreadRadius: 5,
                                                      ),
                                                    ],
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      countdownNumber.toString(),
                                                      style: TextStyle(
                                                        fontSize: 80,
                                                        fontWeight: FontWeight.bold,
                                                        color: primaryColor,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 32),
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
                                          ),
                                        if (showingResult)
                                          Center(
                                            child: AnimatedBuilder(
                                              animation: _resultAnimationController,
                                              builder: (context, child) {
                                                return Transform.scale(
                                                  scale: _resultScaleAnimation.value * _resultBounceAnimation.value,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 40,
                                                      vertical: 20,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: isCorrectResult
                                                          ? Colors.green.withOpacity(0.9)
                                                          : Colors.red.withOpacity(0.9),
                                                      borderRadius: BorderRadius.circular(20),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withOpacity(0.3),
                                                          spreadRadius: 2,
                                                          blurRadius: 8,
                                                          offset: const Offset(0, 4),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Text(
                                                      resultText,
                                                      style: const TextStyle(
                                                        fontSize: 48,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
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
                                                                  offset: Offset(0, 8),
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
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors.black.withOpacity(0.30),
                                                              offset: Offset(0, 8),
                                                              blurRadius: 0,
                                                              spreadRadius: 8,
                                                            ),
                                                          ],
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
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (gameStarted && !showingCountdown)
                    Positioned(
                      left: 24,
                      bottom: 24,
                      child: _buildHelpButton(),
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
                  style: TextStyle(
                    fontSize: 16,
                    color: const Color(0xFF5B6F4A),
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
                      letterSpacing: 8
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: const Color(0xFF5B6F4A),
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
                            offset: Offset(0, 4),
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
                            offset: Offset(0, 4),
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

class CustomShapeWidget extends StatelessWidget {
  final GameShape shape;
  final double size;
  final bool isSelected;

  const CustomShapeWidget({
    super.key,
    required this.shape,
    required this.size,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: ShapePainter(shape.type, shape.color, isSelected),
    );
  }
}

class ShapePainter extends CustomPainter {
  final ShapeType shapeType;
  final Color color;
  final bool isSelected;

  ShapePainter(this.shapeType, this.color, this.isSelected);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    final lightColor = Color.lerp(color, Colors.white, 0.3)!;
    final darkColor = Color.lerp(color, Colors.black, 0.2)!;

    final gradientPaint = Paint()
      ..shader = RadialGradient(
        colors: [lightColor, color, darkColor],
        stops: const [0.0, 0.7, 1.0],
        center: const Alignment(-0.3, -0.3),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    final borderGradient = LinearGradient(
      colors: [
        Colors.white.withOpacity(0.8),
        Colors.white.withOpacity(0.4),
        Colors.white.withOpacity(0.8),
      ],
      stops: const [0.0, 0.5, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final borderPaint = Paint()
      ..shader = borderGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final shapePath = _getShapePath(shapeType, center, radius);

    if (isSelected) {
      final glowColor = Color.lerp(color, Colors.white, 0.4)!;
      canvas.drawShadow(
        _getShapePath(shapeType, center, radius + 8),
        glowColor.withOpacity(0.8),
        12,
        false,
      );
      canvas.drawShadow(
        _getShapePath(shapeType, center, radius + 4),
        glowColor.withOpacity(0.6),
        8,
        false,
      );
    }

    canvas.drawShadow(
      shapePath.shift(const Offset(3, 3)),
      Colors.black.withOpacity(0.25),
      8,
      false,
    );

    canvas.drawShadow(
      shapePath.shift(const Offset(1, 1)),
      Colors.black.withOpacity(0.15),
      4,
      false,
    );

    canvas.drawShadow(shapePath, Colors.black.withOpacity(0.08), 2, false);

    canvas.drawPath(shapePath, gradientPaint);

    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final innerPath = _getShapePath(shapeType, center, radius * 0.85);
    canvas.drawPath(innerPath, highlightPaint);

    canvas.drawPath(shapePath, borderPaint);

    if (isSelected) {
      final selectionPaint = Paint()
        ..color = Color.lerp(color, Colors.white, 0.6)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      final outlinePath = _getShapePath(shapeType, center, radius + 2);
      canvas.drawPath(outlinePath, selectionPaint);
    }
  }

  Path _getShapePath(ShapeType type, Offset center, double radius) {
    switch (type) {
      case ShapeType.circle:
        return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
      case ShapeType.square:
        return Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: center,
              width: radius * 1.6,
              height: radius * 1.6,
            ),
            Radius.circular(radius * 0.35),
          ),
        );
      case ShapeType.triangle:
        final path = Path();
        path.moveTo(center.dx, center.dy - radius);
        path.lineTo(center.dx - radius, center.dy + radius * 0.8);
        path.lineTo(center.dx + radius, center.dy + radius * 0.8);
        path.close();
        return path;
      case ShapeType.diamond:
        final path = Path();
        path.moveTo(center.dx, center.dy - radius);
        path.lineTo(center.dx + radius * 0.8, center.dy);
        path.lineTo(center.dx, center.dy + radius);
        path.lineTo(center.dx - radius * 0.8, center.dy);
        path.close();
        return path;
      case ShapeType.pentagon:
        final path = Path();
        for (int i = 0; i < 5; i++) {
          final angle = (i * 2 * math.pi / 5) - math.pi / 2;
          final x = center.dx + radius * math.cos(angle);
          final y = center.dy + radius * math.sin(angle);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        return path;
      case ShapeType.hexagon:
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = (i * 2 * math.pi / 6) - math.pi / 2;
          final x = center.dx + radius * math.cos(angle);
          final y = center.dy + radius * math.sin(angle);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        return path;
      case ShapeType.star:
        final path = Path();
        for (int i = 0; i < 5; i++) {
          final outerAngle = (i * 2 * math.pi / 5) - math.pi / 2;
          final innerAngle = ((i + 0.5) * 2 * math.pi / 5) - math.pi / 2;
          final outerX = center.dx + radius * math.cos(outerAngle);
          final outerY = center.dy + radius * math.sin(outerAngle);
          final innerX = center.dx + (radius * 0.5) * math.cos(innerAngle);
          final innerY = center.dy + (radius * 0.5) * math.sin(innerAngle);
          if (i == 0) {
            path.moveTo(outerX, outerY);
          } else {
            path.lineTo(outerX, outerY);
          }
          path.lineTo(innerX, innerY);
        }
        path.close();
        return path;
      case ShapeType.oval:
        return Path()..addOval(
          Rect.fromCenter(
            center: center,
            width: radius * 2,
            height: radius * 1.2,
          ),
        );
    }
  }

  @override
  bool shouldRepaint(covariant ShapePainter oldDelegate) {
    return oldDelegate.shapeType != shapeType ||
        oldDelegate.color != color ||
        oldDelegate.isSelected != isSelected;
  }
}