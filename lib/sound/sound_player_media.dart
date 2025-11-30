import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'sound_types.dart';

class MediaSoundPlayer implements SoundPlayer {
  MediaSoundPlayer();

  final AudioPlayer _blipPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  final AudioPlayer _failPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  final AudioPlayer _melodyPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  bool _musicEnabled = true;
  bool _sfxEnabled = true;

  @override
  void blip(double freq, {double duration = 0.08}) {
    if (!_sfxEnabled) return;
    _playSafe(_blipPlayer, AssetSource('audio/blip.wav'));
  }

  @override
  void fail() {
    if (!_sfxEnabled) return;
    _playSafe(_failPlayer, AssetSource('audio/fail.wav'));
  }

  @override
  void melody() {
    if (!_musicEnabled) return;
    _playSafe(_melodyPlayer, AssetSource('audio/melody.wav'), stopFirst: true);
  }

  @override
  void setEnabled(bool musicEnabled, bool sfxEnabled) {
    _musicEnabled = musicEnabled;
    _sfxEnabled = sfxEnabled;
    if (!_musicEnabled) {
      _melodyPlayer.stop();
    }
  }

  void _playSafe(AudioPlayer player, Source source, {bool stopFirst = false}) {
    unawaited(_playSafeAsync(player, source, stopFirst: stopFirst));
  }

  Future<void> _playSafeAsync(AudioPlayer player, Source source, {bool stopFirst = false}) async {
    try {
      if (stopFirst) {
        await player.stop();
      }
      await player.play(source);
    } catch (_) {
      // Ignore playback interruptions on web (e.g., AbortError from overlapping stops).
    }
  }
}

SoundPlayer createPlayerImpl() => MediaSoundPlayer();
