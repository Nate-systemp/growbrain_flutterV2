import 'package:flutter_tts/flutter_tts.dart';

/// Manager for Text-to-Speech functionality in help dialogs
/// Configured with a happy, child-friendly voice tone
class HelpTtsManager {
  static final HelpTtsManager _instance = HelpTtsManager._internal();
  late FlutterTts _flutterTts;
  bool _isInitialized = false;

  factory HelpTtsManager() {
    return _instance;
  }

  HelpTtsManager._internal() {
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    _flutterTts = FlutterTts();
    
    // Configure for a happy, child-friendly voice
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5); // Slower, clearer for children
    await _flutterTts.setVolume(0.9); // Louder, clear volume
    await _flutterTts.setPitch(1.2); // Higher pitch for a happier, child-friendly tone
    
    _isInitialized = true;
  }

  /// Speaks the given text with a happy, child-friendly voice
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await _initializeTts();
    }
    
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      print('Error speaking help text: $e');
    }
  }

  /// Stops any ongoing speech
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      print('Error stopping TTS: $e');
    }
  }

  /// Sets custom TTS parameters if needed
  Future<void> setCustomParameters({
    double? speechRate,
    double? volume,
    double? pitch,
  }) async {
    if (speechRate != null) {
      await _flutterTts.setSpeechRate(speechRate);
    }
    if (volume != null) {
      await _flutterTts.setVolume(volume);
    }
    if (pitch != null) {
      await _flutterTts.setPitch(pitch);
    }
  }
}
