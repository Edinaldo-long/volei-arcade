/// Stub de áudio arcade para plataformas não-web (VM, testes).
class ArcadeAudio {
  static bool _musicEnabled = true;
  static bool get isMusicEnabled => _musicEnabled;

  static int _currentTrack = 0;
  static int get currentTrack => _currentTrack;

  static const List<String> trackNames = [
    'Arcade Clássico 🕹️',
    'Samba Groove 🇧🇷',
    'Electro Tensão ⚡',
    'Brisa de Praia 🏖️',
  ];

  static String get currentTrackName => trackNames[_currentTrack % trackNames.length];

  static void playTouch() {}
  static void playSpike({bool perfect = false}) {}
  static void playBlock() {}
  static void playBounce() {}
  static void playWhistle() {}

  // Efeitos de plateia, aplausos e torcida
  static void playCrowdCheer({bool big = false}) {}
  static void playApplause() {}
  static void playStadiumHorn() {}
  static void playPointCheer({bool perfect = false}) {}

  // Trilha sonora retrô arcade (BGM)
  static void setMusicEnabled(bool enabled) {
    _musicEnabled = enabled;
  }

  static void nextTrack() {
    _currentTrack = (_currentTrack + 1) % trackNames.length;
  }

  static void setTrack(int index) {
    _currentTrack = index % trackNames.length;
  }

  static void startBgm() {}
  static void stopBgm() {}
  static void pauseBgm() {}
  static void resumeBgm() {}
}
