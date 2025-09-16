import 'package:audioplayers/audioplayers.dart';
import 'dart:math';

class SoundEffectsManager {
  static final SoundEffectsManager _instance = SoundEffectsManager._internal();
  factory SoundEffectsManager() => _instance;
  SoundEffectsManager._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _voicePlayer = AudioPlayer(); // Separate player for voice effects
  bool _soundEnabled = true;
  
  // Voice effects list
  final List<String> _voiceEffects = [
    'voice_fx/amazing.mp3',
    'voice_fx/fabulous.mp3',
    'voice_fx/keepitup.mp3',
    'voice_fx/nice.mp3',
  ];
  
  String? _lastPlayedVoice; // Track last played voice to prevent consecutive repeats
  final Random _random = Random();

  /// Play success sound effect
  Future<void> playSuccess() async {
    if (!_soundEnabled) return;
    
    try {
      await _audioPlayer.stop(); // Stop any currently playing sound
      await _audioPlayer.setSource(AssetSource('sound_fx/success_fx_1.mp3'));
      await _audioPlayer.setVolume(0.7); // Set volume to 70%
      await _audioPlayer.resume();
    } catch (e) {
      print('Error playing success sound: $e');
    }
  }

  /// Play wrong/error sound effect
  Future<void> playWrong() async {
    if (!_soundEnabled) return;
    
    try {
      await _audioPlayer.stop(); // Stop any currently playing sound
      await _audioPlayer.setSource(AssetSource('sound_fx/wrong_fx_1.mp3'));
      await _audioPlayer.setVolume(0.7); // Set volume to 70%
      await _audioPlayer.resume();
    } catch (e) {
      print('Error playing wrong sound: $e');
    }
  }

  /// Play congratulations sound effect
  Future<void> playCongratulations() async {
    if (!_soundEnabled) return;
    
    try {
      await _audioPlayer.stop(); // Stop any currently playing sound
      await _audioPlayer.setSource(AssetSource('sound_fx/congrats_fx_1.mp3'));
      await _audioPlayer.setVolume(0.8); // Set volume to 80% for celebration
      await _audioPlayer.resume();
    } catch (e) {
      print('Error playing congratulations sound: $e');
    }
  }

  /// Play random voice effect (amazing, fabulous, keep it up, nice)
  /// Ensures no consecutive repeats
  Future<void> playRandomVoiceEffect() async {
    if (!_soundEnabled) return;
    
    try {
      // Get available voices (excluding the last played one)
      List<String> availableVoices = List.from(_voiceEffects);
      if (_lastPlayedVoice != null && availableVoices.length > 1) {
        availableVoices.remove(_lastPlayedVoice);
      }
      
      // Select a random voice from available ones
      String selectedVoice = availableVoices[_random.nextInt(availableVoices.length)];
      _lastPlayedVoice = selectedVoice;
      
      // Play the selected voice effect
      await _voicePlayer.stop(); // Stop any currently playing voice
      await _voicePlayer.setSource(AssetSource(selectedVoice));
      await _voicePlayer.setVolume(0.8); // Set volume to 80%
      await _voicePlayer.resume();
    } catch (e) {
      print('Error playing voice effect: $e');
    }
  }

  /// Play success sound with voice effect
  Future<void> playSuccessWithVoice() async {
    if (!_soundEnabled) return;
    
    // Play both success sound and voice effect
    await Future.wait([
      playSuccess(),
      playRandomVoiceEffect(),
    ]);
  }

  /// Enable or disable sound effects
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
    if (!enabled) {
      _audioPlayer.stop();
    }
  }

  /// Check if sound effects are enabled
  bool get isSoundEnabled => _soundEnabled;

  /// Set volume for sound effects (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    try {
      await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      print('Error setting sound effects volume: $e');
    }
  }

  /// Play puzzle click sound effect
  Future<void> playPuzzleClickSound() async {
    if (!_soundEnabled) return;
    
    try {
      await _audioPlayer.stop(); // Stop any currently playing sound
      await _audioPlayer.setSource(AssetSource('sound_fx/puzzel click sounds.wav'));
      await _audioPlayer.setVolume(0.6); // Set volume to 60%
      await _audioPlayer.resume();
    } catch (e) {
      print('Error playing puzzle click sound: $e');
    }
  }

  /// Dispose of the audio players
  void dispose() {
    _audioPlayer.dispose();
    _voicePlayer.dispose();
  }
}