import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

@JS('AudioParam')
extension type JSAudioParam(JSObject _) implements JSObject {
  external double get value;
  external set value(double v);
  external void setValueAtTime(double value, double startTime);
  external void exponentialRampToValueAtTime(double value, double endTime);
  external void linearRampToValueAtTime(double value, double endTime);
}

@JS('AudioNode')
extension type JSAudioNode(JSObject _) implements JSObject {
  external void connect(JSAudioNode destination);
}

@JS('AudioDestinationNode')
extension type JSAudioDestinationNode(JSObject _) implements JSAudioNode {}

@JS('GainNode')
extension type JSGainNode(JSObject _) implements JSAudioNode {
  external JSAudioParam get gain;
}

@JS('OscillatorNode')
extension type JSOscillatorNode(JSObject _) implements JSAudioNode {
  external String? get type;
  external set type(String? v);
  external JSAudioParam get frequency;
  external void start([double when]);
  external void stop([double when]);
}

@JS('AudioContext')
extension type JSAudioContext._(JSObject _) implements JSObject {
  external factory JSAudioContext();
  external double get currentTime;
  external String? get state;
  external void resume();
  external JSOscillatorNode createOscillator();
  external JSGainNode createGain();
  external JSAudioDestinationNode get destination;
}

/// Sintetizador de efeitos sonoros chiptune e trilha arcade via Web Audio API.
class ArcadeAudio {
  static JSAudioContext? _ctx;
  static JSGainNode? _musicGain;
  static JSGainNode? _sfxGain;
  static bool _musicEnabled = true;

  // Sequenciador de BGM arcade
  static Timer? _bgmTimer;
  static double _nextNoteTime = 0.0;
  static int _bgmStep = 0;
  static bool _bgmPlaying = false;

  static bool get isMusicEnabled => _musicEnabled;

  static JSAudioContext? get _context {
    try {
      if (_ctx == null) {
        _ctx = JSAudioContext();
        _sfxGain = _ctx!.createGain();
        _sfxGain!.gain.value = 0.90;
        _sfxGain!.connect(_ctx!.destination);

        _musicGain = _ctx!.createGain();
        _musicGain!.gain.value = _musicEnabled ? 0.14 : 0.0;
        _musicGain!.connect(_ctx!.destination);
      }
      if (_ctx!.state == 'suspended') {
        _ctx!.resume();
      }
      return _ctx;
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  //  EFEITOS SONOROS DE JOGABILIDADE
  // ============================================================

  /// Som de toque / passe suave (manchete ou levantamento).
  static void playTouch() {
    final ctx = _context;
    if (ctx == null || _sfxGain == null) return;
    try {
      final now = ctx.currentTime;
      final osc = ctx.createOscillator();
      final gain = ctx.createGain();

      osc.type = 'triangle';
      osc.frequency.setValueAtTime(320.0, now);
      osc.frequency.exponentialRampToValueAtTime(140.0, now + 0.08);

      gain.gain.setValueAtTime(0.22, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.08);

      osc.connect(gain);
      gain.connect(_sfxGain!);

      osc.start(now);
      osc.stop(now + 0.09);
    } catch (_) {}
  }

  /// Som de cortada potente (com variação para cortada perfeita).
  static void playSpike({bool perfect = false}) {
    final ctx = _context;
    if (ctx == null || _sfxGain == null) return;
    try {
      final now = ctx.currentTime;
      final osc = ctx.createOscillator();
      final gain = ctx.createGain();

      osc.type = 'square';
      final startFreq = perfect ? 580.0 : 380.0;
      final endFreq = perfect ? 75.0 : 60.0;
      final duration = perfect ? 0.18 : 0.12;

      osc.frequency.setValueAtTime(startFreq, now);
      osc.frequency.exponentialRampToValueAtTime(endFreq, now + duration);

      gain.gain.setValueAtTime(perfect ? 0.35 : 0.26, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + duration);

      osc.connect(gain);
      gain.connect(_sfxGain!);

      osc.start(now);
      osc.stop(now + duration + 0.01);

      if (perfect) {
        final beep = ctx.createOscillator();
        final beepGain = ctx.createGain();
        beep.type = 'sine';
        beep.frequency.setValueAtTime(880.0, now);
        beep.frequency.setValueAtTime(1320.0, now + 0.06);
        beep.frequency.setValueAtTime(1760.0, now + 0.11);

        beepGain.gain.setValueAtTime(0.18, now);
        beepGain.gain.exponentialRampToValueAtTime(0.001, now + 0.20);

        beep.connect(beepGain);
        beepGain.connect(_sfxGain!);

        beep.start(now);
        beep.stop(now + 0.21);
      }
    } catch (_) {}
  }

  /// Som de bloqueio na rede (impacto firme e seco).
  static void playBlock() {
    final ctx = _context;
    if (ctx == null || _sfxGain == null) return;
    try {
      final now = ctx.currentTime;
      final osc = ctx.createOscillator();
      final gain = ctx.createGain();

      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(420.0, now);
      osc.frequency.exponentialRampToValueAtTime(80.0, now + 0.14);

      gain.gain.setValueAtTime(0.30, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.14);

      osc.connect(gain);
      gain.connect(_sfxGain!);

      osc.start(now);
      osc.stop(now + 0.15);
    } catch (_) {}
  }

  /// Som de quique no chão.
  static void playBounce() {
    final ctx = _context;
    if (ctx == null || _sfxGain == null) return;
    try {
      final now = ctx.currentTime;
      final osc = ctx.createOscillator();
      final gain = ctx.createGain();

      osc.type = 'sine';
      osc.frequency.setValueAtTime(160.0, now);
      osc.frequency.exponentialRampToValueAtTime(45.0, now + 0.09);

      gain.gain.setValueAtTime(0.20, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.09);

      osc.connect(gain);
      gain.connect(_sfxGain!);

      osc.start(now);
      osc.stop(now + 0.10);
    } catch (_) {}
  }

  /// Apito do árbitro (marcação de ponto ou autorização de saque).
  static void playWhistle() {
    final ctx = _context;
    if (ctx == null || _sfxGain == null) return;
    try {
      final now = ctx.currentTime;
      final osc = ctx.createOscillator();
      final gain = ctx.createGain();

      osc.type = 'sine';
      osc.frequency.setValueAtTime(2400.0, now);
      osc.frequency.setValueAtTime(2800.0, now + 0.07);
      osc.frequency.setValueAtTime(2400.0, now + 0.14);

      gain.gain.setValueAtTime(0.12, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.28);

      osc.connect(gain);
      gain.connect(_sfxGain!);

      osc.start(now);
      osc.stop(now + 0.29);
    } catch (_) {}
  }

  // ============================================================
  //  PLATEIA, APLAUSOS E OVACIONAMENTO (LANCES POSITIVOS)
  // ============================================================

  /// Ovacionamento da torcida (estádio vibrando e comemorando).
  static void playCrowdCheer({bool big = false}) {
    final ctx = _context;
    if (ctx == null || _sfxGain == null) return;
    try {
      final now = ctx.currentTime;
      final duration = big ? 2.2 : 1.4;
      final maxGain = big ? 0.32 : 0.22;

      // 4 osciladores desafinados que juntos criam o rugido de multidão
      final freqs = big
          ? [
              [160.0, 360.0, 260.0],
              [240.0, 520.0, 380.0],
              [320.0, 680.0, 480.0],
              [120.0, 220.0, 180.0],
            ]
          : [
              [180.0, 340.0, 280.0],
              [260.0, 460.0, 390.0],
              [130.0, 210.0, 170.0],
            ];

      for (var i = 0; i < freqs.length; i++) {
        final f = freqs[i];
        final osc = ctx.createOscillator();
        final gain = ctx.createGain();

        osc.type = i % 2 == 0 ? 'sawtooth' : 'triangle';
        osc.frequency.setValueAtTime(f[0], now);
        osc.frequency.linearRampToValueAtTime(f[1], now + duration * 0.35);
        osc.frequency.exponentialRampToValueAtTime(f[2], now + duration);

        gain.gain.setValueAtTime(0.01, now);
        gain.gain.linearRampToValueAtTime(maxGain / freqs.length, now + 0.20);
        gain.gain.exponentialRampToValueAtTime(0.001, now + duration);

        osc.connect(gain);
        gain.connect(_sfxGain!);

        osc.start(now);
        osc.stop(now + duration + 0.05);
      }
    } catch (_) {}
  }

  /// Som de aplausos da plateia (palmas sincronizadas e dispersas).
  static void playApplause() {
    final ctx = _context;
    if (ctx == null || _sfxGain == null) return;
    try {
      final now = ctx.currentTime;
      final rnd = math.Random();
      const count = 24;

      for (var i = 0; i < count; i++) {
        // Dispersão natural das palmas ao longo de 1.2 segundos
        final clapDelay = (i / count) * 1.1 + (rnd.nextDouble() * 0.06 - 0.03);
        final clapTime = now + math.max(0.0, clapDelay);
        final osc = ctx.createOscillator();
        final gain = ctx.createGain();

        osc.type = 'triangle';
        final clapFreq = 1100.0 + rnd.nextDouble() * 500.0;
        osc.frequency.setValueAtTime(clapFreq, clapTime);
        osc.frequency.exponentialRampToValueAtTime(280.0, clapTime + 0.032);

        // Curva de ganho geral: palmas aumentam e depois decaem suavemente
        final envelopeK = math.sin((i / count) * math.pi);
        final clapGain = 0.12 * (0.4 + 0.6 * envelopeK);

        gain.gain.setValueAtTime(clapGain, clapTime);
        gain.gain.exponentialRampToValueAtTime(0.001, clapTime + 0.035);

        osc.connect(gain);
        gain.connect(_sfxGain!);

        osc.start(clapTime);
        osc.stop(clapTime + 0.04);
      }
    } catch (_) {}
  }

  /// Fanfarra clássica de corneta de estádio ("Da-da-da, da-da-DAAA!").
  static void playStadiumHorn() {
    final ctx = _context;
    if (ctx == null || _sfxGain == null) return;
    try {
      final now = ctx.currentTime;
      // Notas: G4, G4, G4, C5, E5, G5
      final notes = [
        [392.00, 0.00, 0.08],
        [392.00, 0.10, 0.08],
        [392.00, 0.20, 0.08],
        [523.25, 0.30, 0.11],
        [659.25, 0.43, 0.11],
        [783.99, 0.56, 0.40],
      ];

      for (final n in notes) {
        final freq = n[0];
        final start = now + n[1];
        final dur = n[2];

        final osc = ctx.createOscillator();
        final gain = ctx.createGain();

        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(freq, start);

        gain.gain.setValueAtTime(0.22, start);
        gain.gain.exponentialRampToValueAtTime(0.001, start + dur);

        osc.connect(gain);
        gain.connect(_sfxGain!);

        osc.start(start);
        osc.stop(start + dur + 0.02);
      }

      // Torcida comemora após a fanfarra
      Timer(const Duration(milliseconds: 620), () {
        playCrowdCheer(big: true);
      });
    } catch (_) {}
  }

  /// Reação completa de lance positivo do jogador (ovação + palmas + festa).
  static void playPointCheer({bool perfect = false}) {
    playCrowdCheer(big: perfect);
    playApplause();
    if (perfect) {
      Timer(const Duration(milliseconds: 180), () {
        playStadiumHorn();
      });
    }
  }

  // ============================================================
  //  MÚSICA RETRÔ ARCADE DE FUNDO (BGM MULTI-TRACK)
  // ============================================================

  static int _currentTrack = 0;
  static int get currentTrack => _currentTrack;

  static const List<String> trackNames = [
    'Arcade Clássico 🕹️',
    'Samba Groove 🇧🇷',
    'Electro Tensão ⚡',
    'Brisa de Praia 🏖️',
  ];

  static String get currentTrackName => trackNames[_currentTrack % trackNames.length];

  static void nextTrack() {
    _currentTrack = (_currentTrack + 1) % trackNames.length;
    if (_bgmPlaying && _musicEnabled) {
      stopBgm();
      startBgm();
    }
  }

  static void setTrack(int index) {
    _currentTrack = index % trackNames.length;
    if (_bgmPlaying && _musicEnabled) {
      stopBgm();
      startBgm();
    }
  }

  static void setMusicEnabled(bool enabled) {
    _musicEnabled = enabled;
    if (_musicGain != null && _ctx != null) {
      try {
        final now = _ctx!.currentTime;
        _musicGain!.gain.setValueAtTime(enabled ? 0.14 : 0.0, now);
      } catch (_) {}
    }
    if (!enabled) {
      stopBgm();
    } else if (!_bgmPlaying) {
      startBgm();
    }
  }

  static void startBgm() {
    if (!_musicEnabled) return;
    final ctx = _context;
    if (ctx == null) return;
    stopBgm();
    _bgmPlaying = true;
    _bgmStep = 0;
    _nextNoteTime = ctx.currentTime + 0.05;

    _bgmTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_bgmPlaying || _ctx == null) return;
      _scheduleBgmNotes();
    });
  }

  static void pauseBgm() {
    if (_musicGain != null && _ctx != null) {
      try {
        _musicGain!.gain.setValueAtTime(0.0, _ctx!.currentTime);
      } catch (_) {}
    }
  }

  static void resumeBgm() {
    if (!_musicEnabled) return;
    if (_musicGain != null && _ctx != null) {
      try {
        _musicGain!.gain.setValueAtTime(0.14, _ctx!.currentTime);
      } catch (_) {}
    }
    if (!_bgmPlaying) {
      startBgm();
    }
  }

  static void stopBgm() {
    _bgmPlaying = false;
    _bgmTimer?.cancel();
    _bgmTimer = null;
  }

  static void _scheduleBgmNotes() {
    try {
      final ctx = _ctx;
      if (ctx == null || _musicGain == null || !_musicEnabled) return;

      final now = ctx.currentTime;
      final stepDur = _stepDurations[_currentTrack % _stepDurations.length];

      // Agenda notas até 0.6s à frente (lookahead buffer zero-latency)
      while (_nextNoteTime < now + 0.6) {
        _playBgmStep(_bgmStep, _nextNoteTime, stepDur);
        _nextNoteTime += stepDur;
        _bgmStep = (_bgmStep + 1) % 32;
      }
    } catch (_) {}
  }

  static void _playBgmStep(int step, double time, double dur) {
    final ctx = _ctx;
    if (ctx == null || _musicGain == null) return;

    try {
      final trackIdx = _currentTrack % 4;
      final bassList = _allBassTracks[trackIdx];
      final leadList = _allLeadTracks[trackIdx];

      // 1. Linha de baixo (onda triangular enérgica)
      final bassFreq = bassList[step % bassList.length];
      if (bassFreq > 0) {
        final bOsc = ctx.createOscillator();
        final bGain = ctx.createGain();
        bOsc.type = 'triangle';
        bOsc.frequency.setValueAtTime(bassFreq, time);

        bGain.gain.setValueAtTime(0.24, time);
        bGain.gain.exponentialRampToValueAtTime(0.001, time + dur * 0.95);

        bOsc.connect(bGain);
        bGain.connect(_musicGain!);

        bOsc.start(time);
        bOsc.stop(time + dur);
      }

      // 2. Melodia principal (onda quadrada chiptune)
      final leadFreq = leadList[step % leadList.length];
      if (leadFreq > 0) {
        final lOsc = ctx.createOscillator();
        final lGain = ctx.createGain();
        lOsc.type = trackIdx == 3 ? 'sine' : 'square';
        lOsc.frequency.setValueAtTime(leadFreq, time);

        lGain.gain.setValueAtTime(0.16, time);
        lGain.gain.exponentialRampToValueAtTime(0.001, time + dur * 0.90);

        lOsc.connect(lGain);
        lGain.connect(_musicGain!);

        lOsc.start(time);
        lOsc.stop(time + dur);
      }
    } catch (_) {}
  }

  // Tempos de cada faixa (colcheia correspondente)
  static const List<double> _stepDurations = [
    0.2174, // 138 BPM (Arcade Clássico)
    0.1974, // 152 BPM (Samba Groove)
    0.2027, // 148 BPM (Electro Tensão)
    0.2344, // 128 BPM (Brisa de Praia)
  ];

  // ============================================================
  //  TABELA DE NOTAS MUSICAIS (4 FAIXAS COMPLETAS EM LOOP)
  // ============================================================

  // FAIXA 0: Arcade Clássico (Dm -> Bb -> F -> A)
  static const List<double> _bassTrack0 = [
    73.42, 146.83, 73.42, 146.83, 87.31, 174.61, 98.00, 110.00, // Dm
    116.54, 233.08, 116.54, 233.08, 130.81, 261.63, 130.81, 164.81, // Bb -> C
    87.31, 174.61, 87.31, 174.61, 110.00, 220.00, 110.00, 130.81, // F -> Am
    98.00, 196.00, 98.00, 196.00, 110.00, 138.59, 164.81, 220.00, // Gm -> A7
  ];

  static const List<double> _leadTrack0 = [
    440.0, 0.0, 587.33, 0.0, 523.25, 0.0, 440.0, 0.0,
    466.16, 0.0, 587.33, 0.0, 523.25, 0.0, 392.0, 0.0,
    440.0, 0.0, 523.25, 0.0, 698.46, 0.0, 659.25, 0.0,
    587.33, 0.0, 698.46, 0.0, 659.25, 0.0, 554.37, 0.0,
  ];

  // FAIXA 1: Samba Groove Brasileiro (Sol Maior gingado com síncope)
  static const List<double> _bassTrack1 = [
    98.00, 0.0, 196.00, 98.00, 82.41, 0.0, 164.81, 82.41, // G -> Em
    65.41, 0.0, 130.81, 65.41, 73.42, 0.0, 146.83, 73.42, // C -> D
    98.00, 0.0, 196.00, 98.00, 110.00, 0.0, 220.00, 110.00, // G -> A
    65.41, 130.81, 73.42, 146.83, 98.00, 196.00, 146.83, 98.00, // C-D-G
  ];

  static const List<double> _leadTrack1 = [
    392.00, 587.33, 493.88, 0.0, 440.00, 659.25, 587.33, 0.0,
    523.25, 392.00, 523.25, 659.25, 587.33, 0.0, 493.88, 440.00,
    392.00, 587.33, 493.88, 659.25, 783.99, 0.0, 659.25, 587.33,
    523.25, 493.88, 440.00, 392.00, 493.88, 587.33, 783.99, 0.0,
  ];

  // FAIXA 2: Electro Tensão (Synthwave rápido Am -> F -> C -> G)
  static const List<double> _bassTrack2 = [
    110.00, 220.00, 110.00, 220.00, 87.31, 174.61, 87.31, 174.61, // Am -> F
    130.81, 261.63, 130.81, 261.63, 98.00, 196.00, 98.00, 196.00, // C -> G
    110.00, 220.00, 110.00, 220.00, 87.31, 174.61, 87.31, 174.61, // Am -> F
    123.47, 246.94, 123.47, 246.94, 130.81, 146.83, 164.81, 220.00, // Bm -> E
  ];

  static const List<double> _leadTrack2 = [
    880.00, 659.25, 523.25, 659.25, 698.46, 523.25, 440.00, 523.25,
    523.25, 659.25, 783.99, 659.25, 587.33, 493.88, 392.00, 493.88,
    880.00, 659.25, 523.25, 659.25, 698.46, 783.99, 880.00, 1046.50,
    987.77, 880.00, 783.99, 659.25, 880.00, 0.0, 987.77, 0.0,
  ];

  // FAIXA 3: Brisa de Praia (Suave, praiano e relaxado)
  static const List<double> _bassTrack3 = [
    87.31, 0.0, 174.61, 87.31, 116.54, 0.0, 233.08, 116.54, // F -> Bb
    65.41, 0.0, 130.81, 65.41, 87.31, 0.0, 174.61, 87.31, // C -> F
    87.31, 0.0, 174.61, 87.31, 98.00, 0.0, 196.00, 98.00, // F -> Gm
    116.54, 0.0, 130.81, 0.0, 174.61, 130.81, 116.54, 87.31, // Bb-C-F
  ];

  static const List<double> _leadTrack3 = [
    349.23, 0.0, 440.00, 523.25, 466.16, 0.0, 392.00, 349.23,
    523.25, 0.0, 659.25, 587.33, 523.25, 0.0, 440.00, 0.0,
    349.23, 0.0, 440.00, 523.25, 587.33, 0.0, 523.25, 466.16,
    466.16, 440.00, 392.00, 349.23, 440.00, 523.25, 698.46, 0.0,
  ];

  static const List<List<double>> _allBassTracks = [
    _bassTrack0,
    _bassTrack1,
    _bassTrack2,
    _bassTrack3,
  ];

  static const List<List<double>> _allLeadTracks = [
    _leadTrack0,
    _leadTrack1,
    _leadTrack2,
    _leadTrack3,
  ];
}
