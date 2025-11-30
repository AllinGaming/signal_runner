abstract class SoundPlayer {
  void blip(double freq, {double duration = 0.08});
  void fail();
  void melody();
  void setEnabled(bool musicEnabled, bool sfxEnabled);
}
