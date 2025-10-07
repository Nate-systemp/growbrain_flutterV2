import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/background_music_manager.dart';
import '../utils/sound_effects_manager.dart';
import '../utils/difficulty_utils.dart';

class RhymeTimeGame extends StatefulWidget {
  final String difficulty;
  final Function({
    required int accuracy,
    required int completionTime,
    required String challengeFocus,
    required String gameName,
    required String difficulty,
  })? onGameComplete;

  const RhymeTimeGame({Key? key, required this.difficulty, this.onGameComplete}) : super(key: key);

  @override
  _RhymeTimeGameState createState() => _RhymeTimeGameState();
}

class RhymeWord {
  final String word;
  final String rhymeGroup;
  bool isSelected;
  bool isMatched;

  RhymeWord({required this.word, required this.rhymeGroup, this.isSelected = false, this.isMatched = false});
}

class _RhymeTimeGameState extends State<RhymeTimeGame> with TickerProviderStateMixin {
  List<RhymeWord> currentWords = [];
  RhymeWord? firstSelectedWord;
  RhymeWord? secondSelectedWord;
  bool canSelect = true;
  int correctMatches = 0;
  int totalAttempts = 0;
  int totalPairs = 0;
  late DateTime gameStartTime;
  int timerSeconds = 0;
  bool timerActive = false;
  bool gameStarted = false;
  bool gameActive = false;
  String _normalizedDifficulty = 'Starter';
  bool showSimpleInstruction = false;

  late FlutterTts flutterTts;

  // Match Cards–style UI additions
  bool showingCountdown = false;
  int countdownNumber = 3;

  bool showingGo = false;
  late final AnimationController _goController;
  late final Animation<double> _goOpacity;
  late final Animation<double> _goScale;

  bool showingStatus = false;
  String overlayText = '';
  Color overlayColor = Colors.green;
  Color overlayTextColor = Colors.white;

  final Color primaryColor = const Color(0xFF5D83B9);
  final Color accentColor = const Color(0xFF8AB4F8);

  final Map<String, List<Map<String, String>>> rhymeGroups = {
    'Starter': [
      {'cat': 'at', 'hat': 'at', 'bat': 'at', 'mat': 'at'},
      {'dog': 'og', 'frog': 'og', 'log': 'og', 'hog': 'og'},
      {'car': 'ar', 'star': 'ar', 'far': 'ar', 'jar': 'ar'},
      {'bee': 'ee', 'tree': 'ee', 'free': 'ee', 'see': 'ee'},
      {'run': 'un', 'fun': 'un', 'sun': 'un', 'bun': 'un'},
      {'red': 'ed', 'bed': 'ed', 'fed': 'ed', 'led': 'ed'},
      {'big': 'ig', 'pig': 'ig', 'fig': 'ig', 'wig': 'ig'},
      {'sit': 'it', 'hit': 'it', 'fit': 'it', 'pit': 'it'},
      {'cake': 'ake', 'make': 'ake', 'lake': 'ake', 'wake': 'ake'},
      {'ball': 'all', 'call': 'all', 'fall': 'all', 'wall': 'all'},
    ],
    'Growing': [
      {'window': 'indo', 'bingo': 'indo'},
      {'flower': 'ower', 'tower': 'ower', 'power': 'ower', 'shower': 'ower'},
      {'happy': 'appy', 'snappy': 'appy', 'clappy': 'appy'},
      {'chicken': 'icken', 'thicken': 'icken', 'quicken': 'icken'},
      {'butter': 'utter', 'mutter': 'utter', 'flutter': 'utter', 'clutter': 'utter'},
      {'apple': 'apple', 'grapple': 'apple', 'chapel': 'apple'},
      {'paper': 'aper', 'caper': 'aper', 'taper': 'aper'},
      {'cookie': 'ookie', 'rookie': 'ookie', 'bookie': 'ookie'},
      {'monkey': 'onkey', 'donkey': 'onkey', 'honkey': 'onkey'},
    ],
    'Challenged': [
      {'enough': 'uff', 'rough': 'uff', 'tough': 'uff', 'stuff': 'uff'},
      {'weight': 'ate', 'straight': 'ate', 'create': 'ate', 'relate': 'ate'},
      {'bought': 'ought', 'thought': 'ought', 'caught': 'ought', 'fought': 'ought'},
      {'listen': 'isten', 'glisten': 'isten', 'christen': 'isten'},
      {'ocean': 'tion', 'motion': 'tion', 'potion': 'tion', 'devotion': 'tion'},
      {'heart': 'art', 'part': 'art', 'start': 'art', 'smart': 'art'},
      {'break': 'ake', 'cake': 'ake', 'make': 'ake', 'mistake': 'ake'},
      {'elephant': 'ant', 'important': 'ant', 'pleasant': 'ant'},
    ],
  };

  Random random = Random();

  @override
  void initState() {
    super.initState();
    BackgroundMusicManager().startGameMusic('Rhyme Time');
    _initializeTts();
    _goController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _goOpacity = CurvedAnimation(parent: _goController, curve: Curves.easeInOut);
    _goScale = Tween<double>(begin: 0.90, end: 1.0).animate(CurvedAnimation(parent: _goController, curve: Curves.easeOutBack));
    _initializeGame();
  }

  void _initializeTts() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage('en-US');
    await flutterTts.setSpeechRate(0.6);
    await flutterTts.setVolume(0.8);
    await flutterTts.setPitch(1.0);
  }

  Future<void> _speakWord(String word) async {
    try {
      await flutterTts.speak(word);
    } catch (e) {
      print('Error speaking word: $e');
    }
  }

  void _initializeGame() {
    String diffKey = DifficultyUtils.normalizeDifficulty(widget.difficulty);
    _normalizedDifficulty = diffKey;
    switch (diffKey) {
      case 'Starter':
        totalPairs = 3;
        break;
      case 'Growing':
        totalPairs = 4;
        break;
      case 'Challenged':
        totalPairs = 5;
        break;
      default:
        totalPairs = 3;
    }
    _setupWords(diffKey);
  }

  void _setupWords(String difficultyKey) {
    currentWords.clear();
    List<Map<String, String>> availableGroups = rhymeGroups[difficultyKey] ?? rhymeGroups['Starter']!;
    List<Map<String, String>> selectedGroups = List.from(availableGroups)..shuffle();
    selectedGroups = selectedGroups.take(totalPairs).toList();

    for (var group in selectedGroups) {
      String rhymePattern = group.values.first;
      List<String> wordsInGroup = group.keys.toList();
      for (int i = 0; i < 2 && i < wordsInGroup.length; i++) {
        currentWords.add(RhymeWord(word: wordsInGroup[i], rhymeGroup: rhymePattern));
      }
    }
    currentWords.shuffle();
    setState(() {});
  }

  void _startGame() {
    setState(() {
      showingCountdown = true;
      countdownNumber = 3;
    });
    _showCountdown();
  }

  void _tickTimer() async {
    while (timerActive && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) break;
      setState(() => timerSeconds++);
    }
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

  Future<void> _showStatusOverlay({required String text, required Color color, Color textColor = Colors.white}) async {
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
    setState(() => showingStatus = false);
  }

  void _showCountdown() async {
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => countdownNumber = i);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    setState(() {
      showingCountdown = false;
      gameStarted = true;
      gameActive = true;
      gameStartTime = DateTime.now();
      correctMatches = 0;
      totalAttempts = 0;
      canSelect = true;
      for (var word in currentWords) {
        word.isSelected = false;
        word.isMatched = false;
      }
      firstSelectedWord = null;
      secondSelectedWord = null;
      timerSeconds = 0;
    });
    timerActive = true;
    _tickTimer();
    await _showGoOverlay();
  }

  void _onWordTapped(RhymeWord word) {
    if (!canSelect || !gameActive || word.isMatched) return;
    HapticFeedback.lightImpact();
    _speakWord(word.word);

    if (firstSelectedWord == null) {
      setState(() {
        firstSelectedWord = word;
        word.isSelected = true;
      });
    } else if (firstSelectedWord == word) {
      setState(() {
        firstSelectedWord = null;
        word.isSelected = false;
      });
    } else if (secondSelectedWord == null) {
      setState(() {
        secondSelectedWord = word;
        word.isSelected = true;
        canSelect = false;
      });
      totalAttempts++;
      Timer(const Duration(milliseconds: 800), () {
        _checkForRhyme();
      });
    }
  }

  void _checkForRhyme() {
    if (firstSelectedWord!.rhymeGroup == secondSelectedWord!.rhymeGroup) {
      setState(() {
        firstSelectedWord!.isMatched = true;
        secondSelectedWord!.isMatched = true;
        correctMatches++;
      });
      HapticFeedback.mediumImpact();
      SoundEffectsManager().playSuccessWithVoice();
      _showStatusOverlay(text: '✓', color: Colors.green, textColor: Colors.white).then((_) {
        if (correctMatches == totalPairs) {
          timerActive = false;
          _endGame();
        } else {
          _resetSelection();
        }
      });
    } else {
      HapticFeedback.lightImpact();
      SoundEffectsManager().playWrong();
      _showStatusOverlay(text: 'X', color: Colors.red, textColor: Colors.white).then((_) {
        setState(() {
          firstSelectedWord!.isSelected = false;
          secondSelectedWord!.isSelected = false;
        });
        _resetSelection();
      });
    }
  }

  void _resetSelection() {
    setState(() {
      firstSelectedWord = null;
      secondSelectedWord = null;
      canSelect = true;
    });
  }

  void _resetGame() {
    setState(() {
      correctMatches = 0;
      totalAttempts = 0;
      gameStarted = false;
      gameActive = false;
      canSelect = true;
      firstSelectedWord = null;
      secondSelectedWord = null;
      showingCountdown = false;
      countdownNumber = 3;
      timerSeconds = 0;
      timerActive = false;
    });
    for (var word in currentWords) {
      word.isSelected = false;
      word.isMatched = false;
    }
    _initializeGame();
  }

  void _endGame() {
    setState(() => gameActive = false);
    timerActive = false;
    double accuracyDouble = totalAttempts > 0 ? (correctMatches / totalAttempts) * 100 : 0;
    int accuracy = accuracyDouble.round();
    int completionTime = DateTime.now().difference(gameStartTime).inSeconds;

    if (widget.onGameComplete != null) {
      widget.onGameComplete!(
        accuracy: accuracy,
        completionTime: completionTime,
        challengeFocus: 'Verbal',
        gameName: 'Rhyme Time',
        difficulty: _normalizedDifficulty,
      );
    }
    _showGameOverDialog(accuracy, completionTime);
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
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.30), blurRadius: 14, offset: const Offset(0, 6))],
              ),
              child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 16),
            Text('Amazing! 🌟', style: TextStyle(color: primaryColor, fontSize: 26, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatRow(Icons.star_rounded, 'Matches', '$correctMatches'),
              const SizedBox(height: 12),
              _buildStatRow(Icons.flash_on, 'Attempts', '$totalAttempts'),
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

  // PIN PROTECTION METHODS
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

  Widget _buildHelpButton() {
    return FloatingActionButton.extended(
      heroTag: 'helpBtn',
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      icon: const Icon(Icons.help_outline),
      label: const Text('Need Help?'),
      onPressed: () {
        bool showSimple = false;
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) => Dialog(
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
                                ? 'Tap two words that sound the same at the end. Like "cat" and "hat" - they both end with "at" sound!'
                                : 'Tap two words that sound similar at the end. Words that rhyme have the same ending sound. Tap any word to hear it!',
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
                                      setState(() => showSimple = true);
                                    } else {
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
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _goController.dispose();
    timerActive = false;
    flutterTts.stop();
    BackgroundMusicManager().stopMusic();
    super.dispose();
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
          decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/verbalbg.png'), fit: BoxFit.cover)),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0x667A5833), Color(0x337A5833)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                ),
              ),
              Positioned.fill(
                child: showingCountdown ? _buildCountdownScreen() : (!gameStarted ? _buildStartScreenWithInstruction() : _buildGameContent()),
              ),
              if (gameStarted) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 104),
                    child: _infoCircle(label: 'Time', value: '${timerSeconds}s', circleSize: 104, valueFontSize: 30, labelFontSize: 26),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 104),
                    child: _infoCircle(label: 'Correct', value: '$correctMatches/$totalPairs', circleSize: 104, valueFontSize: 30, labelFontSize: 26),
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
                                const Text('Get Ready!', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 4)])),
                                const SizedBox(height: 16),
                                Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: accentColor,
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.3), offset: const Offset(0, 6), blurRadius: 0, spreadRadius: 0),
                                    ],
                                  ),
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
                              decoration: BoxDecoration(shape: BoxShape.circle, color: overlayColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.30), offset: const Offset(0, 8), blurRadius: 0, spreadRadius: 8)]),
                              child: Center(child: Text(overlayText, style: TextStyle(color: overlayTextColor, fontSize: 72,fontWeight: FontWeight.bold))),
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
),
);
}
Widget _buildGameContent() {
int crossAxisCount = 2;
double childAspectRatio = 2.5;
if (_normalizedDifficulty == 'Growing') {
  crossAxisCount = 2;
  childAspectRatio = 2.5;
} else if (_normalizedDifficulty == 'Challenged') {
  crossAxisCount = 2;
  childAspectRatio = 2.8;
}

return Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          '',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 2)]),
          textAlign: TextAlign.center,
        ),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 4),
          Text('', style: TextStyle(fontSize: 14, color: Colors.white70, fontStyle: FontStyle.italic)),
        ],
      ),
      const SizedBox(height: 20),
      Expanded(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: childAspectRatio,
                ),
                itemCount: currentWords.length,
                itemBuilder: (context, index) => _buildWordCard(currentWords[index]),
              ),
            ),
          ),
        ),
      ),
    ],
  ),
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
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(color: primaryColor.withOpacity(0.25), offset: const Offset(0, 12), blurRadius: 24, spreadRadius: 2),
          BoxShadow(color: Colors.white.withOpacity(0.5), offset: const Offset(0, -4), blurRadius: 12),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('Rhyme Time', style: TextStyle(color: primaryColor, fontSize: isTablet ? 42 : 34, fontWeight: FontWeight.w900, letterSpacing: 0.5), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Container(
            width: isTablet ? 100 : 84,
            height: isTablet ? 100 : 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 0, offset: Offset(0, 4), spreadRadius: 0),
              ],
            ),
            child: Icon(Icons.music_note_rounded, size: isTablet ? 56 : 48, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text('Find rhyming pairs!', style: TextStyle(color: primaryColor, fontSize: isTablet ? 22 : 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: showSimpleInstruction
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Text(
              'Tap two words that sound similar at the end. Words that rhyme have the same ending sound. Tap any word to hear it!',
              textAlign: TextAlign.center,
              style: TextStyle(color: primaryColor.withOpacity(0.85), fontSize: isTablet ? 18 : 15, height: 1.35),
            ),
            secondChild: Text(
              'Tap two words that sound the same at the end. Like "cat" and "hat" - they both end with "at" sound! Tap any word to hear it.',
              textAlign: TextAlign.center,
              style: TextStyle(color: primaryColor.withOpacity(0.85), fontSize: isTablet ? 18 : 15, height: 1.35, fontWeight: FontWeight.w600),
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
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: isTablet ? 18 : 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
                shadowColor: primaryColor.withOpacity(0.5),
              ),
              child: Text('START GAME', style: TextStyle(fontSize: isTablet ? 22 : 18, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
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
const Text('Get Ready!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 4)])),
const SizedBox(height: 40),
Container(
width: 150,
height: 150,
decoration: BoxDecoration(
shape: BoxShape.circle,
color: accentColor,
boxShadow: [
BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 0, offset: Offset(0, 6), spreadRadius: 0),
],
),
child: Center(child: Text('$countdownNumber', style: TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: primaryColor))),
),
const SizedBox(height: 40),
Text('The game will start soon...', style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500, shadows: [Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 2)])),
],
),
);
}
Widget _buildWordCard(RhymeWord word) {
Color cardColor;
Color borderColor;
Color textColor;
if (word.isMatched) {
  cardColor = const Color(0xFF4CAF50);
  borderColor = const Color(0xFF2E7D32);
  textColor = Colors.white;
} else if (word.isSelected) {
  cardColor = accentColor;
  borderColor = primaryColor;
  textColor = primaryColor;
} else {
  cardColor = primaryColor;
  borderColor = primaryColor.withOpacity(0.5);
  textColor = Colors.white;
}

return GestureDetector(
  onTap: () => _onWordTapped(word),
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
    decoration: BoxDecoration(
      gradient: word.isMatched || word.isSelected
          ? LinearGradient(
              colors: [cardColor, cardColor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      color: word.isMatched || word.isSelected ? null : cardColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: borderColor, width: word.isMatched || word.isSelected ? 3 : 2),
      boxShadow: [
        BoxShadow(
          color: (word.isSelected ? primaryColor : Colors.black).withOpacity(word.isSelected ? 0.30 : 0.15),
          blurRadius: word.isSelected ? 10 : 5,
          offset: Offset(0, word.isSelected ? 4 : 2),
        ),
      ],
    ),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              word.word,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
                letterSpacing: 1.0,
                shadows: word.isMatched || word.isSelected
                    ? [Shadow(color: Colors.black.withOpacity(0.2), offset: const Offset(1, 1), blurRadius: 2)]
                    : null,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Icon(Icons.volume_up_rounded, size: 14, color: textColor.withOpacity(0.8)),
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