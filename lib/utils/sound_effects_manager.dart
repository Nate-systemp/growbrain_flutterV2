import 'package:audioplayers/audioplayers.dart';

class SoundEffectsManager {
  static final SoundEffectsManager _instance = SoundEffectsManager._internal();
  factory SoundEffectsManager() => _instance;
  SoundEffectsManager._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _soundEnabled = true;

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

  /// Dispose of the audio player
  void dispose() {
    _audioPlayer.dispose();
  }
}