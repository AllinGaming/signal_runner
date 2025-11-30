import 'sound_types.dart';

class StubSoundPlayer implements SoundPlayer {
  @override
  void blip(double freq, {double duration = 0.08}) {}

  @override
  void fail() {}

  @override
  void melody() {}

  @override
  void setEnabled(bool musicEnabled, bool sfxEnabled) {}
}

SoundPlayer createPlayerImpl() => StubSoundPlayer();
