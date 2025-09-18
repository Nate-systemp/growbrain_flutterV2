import 'package:audioplayers/audioplayers.dart';

class BackgroundMusicManager {
  static final BackgroundMusicManager _instance = BackgroundMusicManager._internal();
  factory BackgroundMusicManager() => _instance;
  BackgroundMusicManager._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _currentTrack;
  double _backgroundMusicVolume = 0.3; // Global volume for background music (0.0 to 1.0)

  // Game categorization mapping
  static const Map<String, String> _gameToCategory = {
    // Attention games
    'Who Moved?': 'attention',
    'Light Tap': 'attention', 
    'Find Me': 'attention',
    
    // Verbal games
    'Sound Match': 'verbal',
    'Rhyme Time': 'verbal',
    'Picture Words': 'verbal',
    
    // Memory games
    'Match Cards': 'memory',
    'Fruit Shuffle': 'memory',
    'Object Hunt': 'memory',
    
    // Logic games
    'Puzzle': 'logic',
    'TicTacToe': 'logic',
    'Riddle Game': 'logic',
  };

  static const Map<String, String> _categoryToMusic = {
    'attention': 'assets/bg_music/bgmusicone.mp3',
    'verbal': 'assets/bg_music/bgmusictwo.mp3',
    'memory': 'assets/bg_music/bgmusicthree.wav',
    'logic': 'assets/bg_music/bgmusicfour.wav',
  };

  /// Start background music for a specific game
  Future<void> startGameMusic(String gameName) async {
    // Don't start music if volume is 0
    if (_backgroundMusicVolume == 0.0) {
      print('Background music volume is 0, skipping $gameName');
      return;
    }
    try {
      final category = _gameToCategory[gameName];
      if (category == null) {
        print('No category found for game: $gameName');
        return;
      }

      final musicFile = _categoryToMusic[category];
      if (musicFile == null) {
        print('No music file found for category: $category');
        return;
      }

      // Stop current music if different track
      if (_currentTrack != musicFile) {
        await stopMusic();
        _currentTrack = musicFile;
      }

      // Start new music if not already playing
      if (!_isPlaying) {
        await _audioPlayer.setSource(AssetSource(musicFile.replaceFirst('assets/', '')));
        await _audioPlayer.setReleaseMode(ReleaseMode.loop); // Loop the music
        await _audioPlayer.setVolume(_backgroundMusicVolume); // Set current volume
        await _audioPlayer.resume();
        _isPlaying = true;
        print('Started background music for $gameName: $musicFile');
      }
    } catch (e) {
      print('Error starting background music: $e');
    }
  }

  /// Stop background music
  Future<void> stopMusic() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        _isPlaying = false;
        _currentTrack = null;
        print('Stopped background music');
      }
    } catch (e) {
      print('Error stopping background music: $e');
    }
  }

  /// Pause background music
  Future<void> pauseMusic() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        _isPlaying = false;
        print('Paused background music');
      }
    } catch (e) {
      print('Error pausing background music: $e');
    }
  }

  /// Resume background music
  Future<void> resumeMusic() async {
    try {
      if (!_isPlaying && _currentTrack != null) {
        await _audioPlayer.resume();
        _isPlaying = true;
        print('Resumed background music');
      }
    } catch (e) {
      print('Error resuming background music: $e');
    }
  }

  /// Set background music volume (0.0 to 1.0)
  Future<void> setBackgroundMusicVolume(double volume) async {
    try {
      _backgroundMusicVolume = volume.clamp(0.0, 1.0);
      if (_isPlaying) {
        await _audioPlayer.setVolume(_backgroundMusicVolume);
      }
      // If volume is set to 0 and music is playing, stop it
      if (_backgroundMusicVolume == 0.0 && _isPlaying) {
        await stopMusic();
      }
    } catch (e) {
      print('Error setting background music volume: $e');
    }
  }

  /// Check if music is currently playing
  bool get isPlaying => _isPlaying;

  /// Get current track
  String? get currentTrack => _currentTrack;

  /// Enable or disable background music globally (for backward compatibility)
  void setBackgroundMusicEnabled(bool enabled) {
    setBackgroundMusicVolume(enabled ? 0.3 : 0.0);
  }

  /// Check if background music is enabled (for backward compatibility)
  bool get isBackgroundMusicEnabled => _backgroundMusicVolume > 0.0;
  
  /// Get current background music volume
  double get backgroundMusicVolume => _backgroundMusicVolume;

  /// Dispose resources
  void dispose() {
    _audioPlayer.dispose();
  }
}
