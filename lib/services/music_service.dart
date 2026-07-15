import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/player_state.dart';

enum MusicSource { appleMusic, spotify }

class MusicService {
  MusicService(this.playerState);

  final PlayerState playerState;
  Timer? _timer;
  MusicSource currentSource = MusicSource.appleMusic;

  void start({Duration interval = const Duration(seconds: 1)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _poll());
    _poll();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void changeSource(MusicSource newSource) {
    currentSource = newSource;
    _poll();
  }

  // 앱 이름 가져오기
  String get _appName => currentSource == MusicSource.spotify ? "Spotify" : "Music";

  Future<void> togglePlayPause() async {
    try {
      final script = '''
        tell application "$_appName"
          if it is running then
            try
              playpause
            on error
              play
            end try
          else
            activate
          end if
        end tell
      ''';
      await Process.run('osascript', ['-e', script]);
      await Future.delayed(const Duration(milliseconds: 400));
      await _poll();
    } catch (e) {
      debugPrint('$_appName togglePlayPause error: $e');
    }
  }

  Future<void> nextTrack() async {
    try {
      await Process.run('osascript', ['-e', 'tell application "$_appName" to next track']);
      await Future.delayed(const Duration(milliseconds: 200));
      await _poll();
    } catch (e) {
      debugPrint('$_appName nextTrack error: $e');
    }
  }

  Future<void> previousTrack() async {
    try {
      await Process.run('osascript', ['-e', 'tell application "$_appName" to previous track']);
      await Future.delayed(const Duration(milliseconds: 200));
      await _poll();
    } catch (e) {
      debugPrint('$_appName previousTrack error: $e');
    }
  }

  Future<void> _poll() async {
    try {
      // 각 앱별 스크립트 분기 처리
      final script = '''
        tell application "$_appName"
          if it is running then
            if player state is playing then
              set trackName to name of current track
              set artistName to artist of current track
              set trackId to (id of current track) as string
              return "playing|" & trackId & "|" & trackName & "|" & artistName
            else if player state is paused then
              return "paused|"
            else
              return "stopped|"
            end if
          else
            return "stopped|"
          end if
        end tell
      ''';

      final result = await Process.run('osascript', ['-e', script]);
      if (result.exitCode != 0) { playerState.setStopped(); return; }

      final output = (result.stdout as String).trim();
      final parts = output.split('|');
      final state = parts.isNotEmpty ? parts[0] : 'stopped';

      if (state == 'playing' && parts.length >= 4) {
        playerState.updateFromSpotify(
          isPlaying: true, trackId: parts[1], trackName: parts[2], artistName: parts[3],
        );
      } else if (state == 'paused') {
        playerState.updateFromSpotify(isPlaying: false, trackId: playerState.currentTrackId, trackName: playerState.trackName, artistName: playerState.artistName);
      } else {
        playerState.setStopped();
      }
    } catch (e) {
      playerState.setStopped();
    }
  }
}