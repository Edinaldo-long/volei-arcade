import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// Sistema de áudio arcade multiplataforma (Android, iOS, Web, Desktop) via audioplayers.
///
/// Otimizado especificamente para mobile/Android:
/// 1. Usa [AndroidAudioFocus.none] para que efeitos sonoros (SFX) NUNCA roubem o foco
///    da trilha musical (BGM), evitando que a música pare após poucos segundos.
/// 2. Evita chamadas de Binder síncronas ao AudioService do Android no frame rate,
///    eliminando micro-travamentos ("stuttering" / travadas).
/// 3. Mantém watchdog com [onPlayerComplete] e [onPlayerStateChanged] para garantir loop
///    ininterrupto do BGM mesmo em dispositivos com MediaPlayer instável.
/// 4. Pool otimizado de SFX com limitação de taxa (debounce) por efeito para economizar
///    mensagens de IPC de plataforma e alocação de buffers.
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

  static bool _isTestEnvironment() {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  /// Contexto de áudio sem conflito de foco para Android e iOS
  static final AudioContext _audioContext = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none, // CRÍTICO: nunca interrompe nem rouba foco do BGM
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.ambient,
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
  );

  static bool _initialized = false;
  static void init() {
    if (_initialized || _isTestEnvironment()) return;
    _initialized = true;
    try {
      AudioPlayer.global.setAudioContext(_audioContext).catchError((_) {});
      // Pré-aquece arquivos de áudio no cache do dispositivo de forma assíncrona
      AudioCache.instance.loadAll(const [
        'audio/touch.wav',
        'audio/spike.wav',
        'audio/spike_perfect.wav',
        'audio/block.wav',
        'audio/bounce.wav',
        'audio/whistle.wav',
        'audio/cheer.wav',
        'audio/horn.wav',
        'audio/point.wav',
      ]).catchError((_) => <Uri>[]);
    } catch (_) {}
  }

  static bool _isIntentionalPause = false;
  static AudioPlayer? _bgmPlayerInstance;
  static AudioPlayer? get _bgmPlayer {
    if (_isTestEnvironment()) return null;
    try {
      if (_bgmPlayerInstance == null) {
        final p = AudioPlayer();
        p.setAudioContext(_audioContext).catchError((_) {});
        p.setReleaseMode(ReleaseMode.loop).catchError((_) {});
        // Watchdog de loop: se por qualquer motivo o MediaPlayer nativo não repetir em loop
        p.onPlayerComplete.listen((_) {
          if (_musicEnabled && !_isIntentionalPause) {
            _bgmPlayerInstance?.seek(Duration.zero).catchError((_) {});
            _bgmPlayerInstance?.resume().catchError((_) {});
          }
        });
        // Watchdog de foco: se o Android pausar indevidamente, retoma automaticamente
        p.onPlayerStateChanged.listen((state) {
          if (_musicEnabled &&
              !_isIntentionalPause &&
              (state == PlayerState.paused || state == PlayerState.stopped)) {
            _bgmPlayerInstance?.resume().catchError((_) {});
          }
        });
        _bgmPlayerInstance = p;
      }
      return _bgmPlayerInstance;
    } catch (_) {
      return null;
    }
  }

  // Pool reduzido e controlado de SFX (4 players são ideais para mixagem sem sobrecarregar o SoundPool)
  static List<AudioPlayer>? _sfxPlayersInstance;
  static final List<double> _sfxVolumes = [1.0, 1.0, 1.0, 1.0];
  static List<AudioPlayer> get _sfxPlayers {
    if (_isTestEnvironment()) return const [];
    try {
      _sfxPlayersInstance ??= List.generate(4, (_) {
        final p = AudioPlayer();
        p.setAudioContext(_audioContext).catchError((_) {});
        return p;
      });
      return _sfxPlayersInstance!;
    } catch (_) {
      return const [];
    }
  }

  static int _sfxIndex = 0;
  static final Map<String, int> _lastPlayedMs = {};

  static void _playSfx(String assetPath, {double volume = 1.0, int minIntervalMs = 40}) {
    if (_isTestEnvironment()) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final last = _lastPlayedMs[assetPath] ?? 0;
      if (now - last < minIntervalMs) {
        return; // Evita envio redundante de comandos para o canal de plataforma no mesmo frame
      }
      _lastPlayedMs[assetPath] = now;

      final pool = _sfxPlayers;
      if (pool.isEmpty) return;
      final idx = _sfxIndex % pool.length;
      final player = pool[idx];
      _sfxIndex = (_sfxIndex + 1) % pool.length;

      // Só altera o volume se mudou significativamente, economizando chamadas de canal IPC
      if ((_sfxVolumes[idx] - volume).abs() > 0.05) {
        _sfxVolumes[idx] = volume;
        player.setVolume(volume).catchError((_) {});
      }
      player.play(AssetSource('audio/$assetPath'), mode: PlayerMode.lowLatency).catchError((_) {});
    } catch (_) {}
  }

  // ============================================================
  //  EFEITOS SONOROS (Com intervalos mínimos para evitar travadas)
  // ============================================================
  static void playTouch() => _playSfx('touch.wav', volume: 0.85, minIntervalMs: 50);

  static void playSpike({bool perfect = false}) =>
      _playSfx(perfect ? 'spike_perfect.wav' : 'spike.wav', volume: 1.0, minIntervalMs: 80);

  static void playBlock() => _playSfx('block.wav', volume: 0.95, minIntervalMs: 80);

  static void playBounce() => _playSfx('bounce.wav', volume: 0.75, minIntervalMs: 80);

  static void playWhistle() => _playSfx('whistle.wav', volume: 0.90, minIntervalMs: 250);

  static void playCrowdCheer({bool big = false}) =>
      _playSfx('cheer.wav', volume: big ? 1.0 : 0.75, minIntervalMs: 300);

  static void playApplause() => _playSfx('cheer.wav', volume: 0.65, minIntervalMs: 300);

  static void playStadiumHorn() => _playSfx('horn.wav', volume: 0.85, minIntervalMs: 250);

  static void playPointCheer({bool perfect = false}) =>
      _playSfx('point.wav', volume: 0.95, minIntervalMs: 300);

  // ============================================================
  //  TRILHA SONORA ARCADE (BGM)
  // ============================================================
  static void setMusicEnabled(bool enabled) {
    _musicEnabled = enabled;
    if (!_musicEnabled) {
      pauseBgm();
    } else {
      resumeBgm();
    }
  }

  static void nextTrack() {
    _currentTrack = (_currentTrack + 1) % trackNames.length;
    if (_musicEnabled) {
      startBgm();
    }
  }

  static void setTrack(int index) {
    _currentTrack = index % trackNames.length;
    if (_musicEnabled) {
      startBgm();
    }
  }

  static void startBgm() async {
    if (!_musicEnabled || _isTestEnvironment()) return;
    try {
      final player = _bgmPlayer;
      if (player == null) return;
      _isIntentionalPause = false;
      await player.setAudioContext(_audioContext).catchError((_) {});
      await player.setReleaseMode(ReleaseMode.loop).catchError((_) {});
      await player.setVolume(0.55).catchError((_) {});
      final trackFile = 'bgm_${_currentTrack % 4}.wav';
      await player.play(AssetSource('audio/$trackFile')).catchError((_) {});
    } catch (_) {}
  }

  static void stopBgm() async {
    _isIntentionalPause = true;
    if (_isTestEnvironment()) return;
    try {
      await _bgmPlayer?.stop().catchError((_) {});
    } catch (_) {}
  }

  static void pauseBgm() async {
    _isIntentionalPause = true;
    if (_isTestEnvironment()) return;
    try {
      await _bgmPlayer?.pause().catchError((_) {});
    } catch (_) {}
  }

  static void resumeBgm() async {
    if (!_musicEnabled || _isTestEnvironment()) return;
    try {
      _isIntentionalPause = false;
      final player = _bgmPlayer;
      if (player == null) return;
      if (player.state == PlayerState.paused) {
        await player.resume().catchError((_) {});
      } else if (player.state != PlayerState.playing) {
        startBgm();
      }
    } catch (_) {}
  }
}
