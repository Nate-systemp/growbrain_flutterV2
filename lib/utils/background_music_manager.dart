import 'package:audioplayers/audioplayers.dart';

class BackgroundMusicManager {
  static final BackgroundMusicManager _instance = BackgroundMusicManager._internal();
  factory BackgroundMusicManager() => _instance;
  BackgroundMusicManager._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _currentTrack;

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
        await _audioPlayer.setVolume(0.3); // Set volume to 30%
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

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    try {
      await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      print('Error setting volume: $e');
    }
  }

  /// Check if music is currently playing
  bool get isPlaying => _isPlaying;

  /// Get current track
  String? get currentTrack => _currentTrack;

  /// Dispose resources
  void dispose() {
    _audioPlayer.dispose();
  }
}
