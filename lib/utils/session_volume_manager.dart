import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'background_music_manager.dart';
import 'sound_effects_manager.dart';

class SessionVolumeManager {
  static SessionVolumeManager? _instance;
  static SessionVolumeManager get instance => _instance ??= SessionVolumeManager._internal();
  SessionVolumeManager._internal();

  // Session-specific volume levels
  double _sessionBackgroundMusicVolume = 0.3;
  double _sessionSoundEffectsVolume = 0.7;
  
  // Default demo/main app volume levels (separate from session)
  static const double _defaultDemoBackgroundVolume = 0.3;
  static const double _defaultDemoSoundEffectsVolume = 0.7;
  
  // Track if we're currently in a session
  bool _isInSession = false;
  String? _currentStudentId;

  /// Get current session background music volume
  double get sessionBackgroundMusicVolume => _sessionBackgroundMusicVolume;

  /// Get current session sound effects volume
  double get sessionSoundEffectsVolume => _sessionSoundEffectsVolume;

  /// Check if currently in a session
  bool get isInSession => _isInSession;

  /// Start a session for a specific student and load their volume settings
  Future<void> startSession(String studentId) async {
    _isInSession = true;
    _currentStudentId = studentId;
    await _loadSessionVolumes(studentId);
    _applySessionVolumes();
  }

  /// End the current session and restore default demo volumes
  Future<void> endSession() async {
    if (_isInSession) {
      // Save current session volumes before ending
      if (_currentStudentId != null) {
        await saveSessionVolumes(_currentStudentId!);
      }
    }
    
    _isInSession = false;
    _currentStudentId = null;
    
    // Restore default demo volumes
    await BackgroundMusicManager().setBackgroundMusicVolume(_defaultDemoBackgroundVolume);
    await SoundEffectsManager().setSoundEffectsVolume(_defaultDemoSoundEffectsVolume);
  }

  /// Set session background music volume and apply immediately
  Future<void> setSessionBackgroundMusicVolume(double volume) async {
    _sessionBackgroundMusicVolume = volume.clamp(0.0, 1.0);
    if (_isInSession) {
      await BackgroundMusicManager().setBackgroundMusicVolume(_sessionBackgroundMusicVolume);
    }
  }

  /// Set session sound effects volume and apply immediately
  Future<void> setSessionSoundEffectsVolume(double volume) async {
    _sessionSoundEffectsVolume = volume.clamp(0.0, 1.0);
    if (_isInSession) {
      await SoundEffectsManager().setSoundEffectsVolume(_sessionSoundEffectsVolume);
    }
  }

  /// Load session volumes from Firebase for specific student
  Future<void> _loadSessionVolumes(String studentId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(user.uid)
          .collection('students')
          .doc(studentId)
          .get();

      final data = doc.data();
      if (data != null) {
        _sessionBackgroundMusicVolume = (data['backgroundMusicVolume'] as num?)?.toDouble() ?? 0.3;
        _sessionSoundEffectsVolume = (data['soundEffectsVolume'] as num?)?.toDouble() ?? 0.7;
      }
    } catch (e) {
      print('Error loading session volumes: $e');
      // Use defaults on error
      _sessionBackgroundMusicVolume = 0.3;
      _sessionSoundEffectsVolume = 0.7;
    }
  }

  /// Save session volumes to Firebase for current student
  Future<void> saveSessionVolumes(String studentId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('teachers')
          .doc(user.uid)
          .collection('students')
          .doc(studentId)
          .set({
            'backgroundMusicVolume': _sessionBackgroundMusicVolume,
            'soundEffectsVolume': _sessionSoundEffectsVolume,
          }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving session volumes: $e');
    }
  }

  /// Apply current session volumes to the audio managers
  Future<void> _applySessionVolumes() async {
    await BackgroundMusicManager().setBackgroundMusicVolume(_sessionBackgroundMusicVolume);
    await SoundEffectsManager().setSoundEffectsVolume(_sessionSoundEffectsVolume);
  }

  /// Initialize demo volumes (call this at app start)
  Future<void> initializeDemoVolumes() async {
    if (!_isInSession) {
      await BackgroundMusicManager().setBackgroundMusicVolume(_defaultDemoBackgroundVolume);
      await SoundEffectsManager().setSoundEffectsVolume(_defaultDemoSoundEffectsVolume);
    }
  }

  /// Reset to default session volumes (useful for new students)
  void resetToDefaults() {
    _sessionBackgroundMusicVolume = 0.3;
    _sessionSoundEffectsVolume = 0.7;
  }
}
