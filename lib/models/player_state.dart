import 'package:flutter/foundation.dart';

enum PlaybackStatus { playing, paused, stopped }

class PlayerState extends ChangeNotifier {
  PlaybackStatus _status = PlaybackStatus.stopped;
  String? _currentTrackId;
  String? _trackName;
  String? _artistName;

  PlaybackStatus get status => _status;
  String? get currentTrackId => _currentTrackId;
  String? get trackName => _trackName;
  String? get artistName => _artistName;

  bool get isPlaying => _status == PlaybackStatus.playing;

  /// Call this whenever Spotify reports a playback update.
  /// Returns true if this is a NEW track (different from last one),
  /// so the UI can trigger the "package drop" animation.
  bool updateFromSpotify({
    required bool isPlaying,
    required String? trackId,
    String? trackName,
    String? artistName,
  }) {
    final isNewTrack = trackId != null && trackId != _currentTrackId;

    _status = isPlaying ? PlaybackStatus.playing : PlaybackStatus.paused;
    _currentTrackId = trackId;
    _trackName = trackName;
    _artistName = artistName;

    notifyListeners();
    return isNewTrack;
  }

  void setStopped() {
    _status = PlaybackStatus.stopped;
    _currentTrackId = null;
    _trackName = null;
    _artistName = null;
    notifyListeners();
  }

  // Temporary manual toggle for testing without Spotify hooked up yet.
  void debugToggle() {
    _status = _status == PlaybackStatus.playing
        ? PlaybackStatus.paused
        : PlaybackStatus.playing;
    notifyListeners();
  }
}