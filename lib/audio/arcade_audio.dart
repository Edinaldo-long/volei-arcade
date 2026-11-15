import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// Sistema de áudio arcade multiplataforma (Android, iOS, Web, Desktop) via audioplayers.
///
/// Otimizado para máxima fluidez em mobile:
/// 1. Música de fundo (BGM) desativada para eliminar repetição e consumo de recursos.
/// 2. Efeitos sonoros das ações do jogo (SFX) executados com latência ultrabaixa via SoundPool.
/// 3. Zero chamadas síncronas ao AudioService do Android no loop de renderização (AndroidAudioFocus.none).
/// 4. Dois players dedicados (impactos da bola e eventos do jogo) para evitar rotação pesada de canais.
/// 5. Debounce inteligente por som para prevenir sobrecarga de mensagens IPC e travamentos.
class ArcadeAudio {
  // Trilha musical desativada a pedido do usuário (somente efeitos sonoros ativos)
  static bool _musicEnabled = false;
  static bool get isMusicEnabled => _musicEnabled;

  static bool _sfxEnabled = true;
  static bool get isSfxEnabled => _sfxEnabled;

  static void setSfxEnabled(bool enabled) {
    _sfxEnabled = enabled;
  }

  static void toggleSfx() {
    _sfxEnabled = !_sfxEnabled;
  }

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

  /// Contexto de áudio sem solicitação de foco exclusivo para Android e iOS
  static final AudioContext _audioContext = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
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
      // Pré-carrega os arquivos de efeitos no cache do dispositivo de forma assíncrona
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

  // ============================================================
  //  PLAYERS DE EFEITOS (Dedicados: Impactos de bola e Eventos)
  // ============================================================
  static AudioPlayer? _hitPlayerInstance;
  static AudioPlayer? _eventPlayerInstance;

  static AudioPlayer? get _hitPlayer {
    if (_isTestEnvironment()) return null;
    try {
      if (_hitPlayerInstance == null) {
        final p = AudioPlayer();
        p.setAudioContext(_audioContext).catchError((_) {});
        p.setVolume(0.90).catchError((_) {});
        _hitPlayerInstance = p;
      }
      return _hitPlayerInstance;
    } catch (_) {
      return null;
    }
  }

  static AudioPlayer? get _eventPlayer {
    if (_isTestEnvironment()) return null;
    try {
      if (_eventPlayerInstance == null) {
        final p = AudioPlayer();
        p.setAudioContext(_audioContext).catchError((_) {});
        p.setVolume(0.95).catchError((_) {});
        _eventPlayerInstance = p;
      }
      return _eventPlayerInstance;
    } catch (_) {
      return null;
    }
  }

  static final Map<String, int> _lastPlayedMs = {};

  static void _playHit(String file, {int minIntervalMs = 50}) {
    if (!_sfxEnabled || _isTestEnvironment()) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final last = _lastPlayedMs[file] ?? 0;
      if (now - last < minIntervalMs) return;
      _lastPlayedMs[file] = now;

      _hitPlayer?.play(AssetSource('audio/$file'), mode: PlayerMode.lowLatency).catchError((_) {});
    } catch (_) {}
  }

  static void _playEvent(String file, {int minIntervalMs = 250}) {
    if (!_sfxEnabled || _isTestEnvironment()) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final last = _lastPlayedMs[file] ?? 0;
      if (now - last < minIntervalMs) return;
      _lastPlayedMs[file] = now;

      _eventPlayer?.play(AssetSource('audio/$file'), mode: PlayerMode.lowLatency).catchError((_) {});
    } catch (_) {}
  }

  // ============================================================
  //  EFEITOS SONOROS DAS AÇÕES DO JOGO
  // ============================================================
  static void playTouch() => _playHit('touch.wav', minIntervalMs: 60);

  static void playSpike({bool perfect = false}) =>
      _playHit(perfect ? 'spike_perfect.wav' : 'spike.wav', minIntervalMs: 120);

  static void playBlock() => _playHit('block.wav', minIntervalMs: 120);

  static void playBounce() => _playHit('bounce.wav', minIntervalMs: 80);

  static void playWhistle() => _playEvent('whistle.wav', minIntervalMs: 300);

  static void playCrowdCheer({bool big = false}) =>
      _playEvent('cheer.wav', minIntervalMs: 400);

  static void playApplause() => _playEvent('cheer.wav', minIntervalMs: 400);

  static void playStadiumHorn() => _playEvent('horn.wav', minIntervalMs: 350);

  static void playPointCheer({bool perfect = false}) =>
      _playEvent('point.wav', minIntervalMs: 350);

  // ============================================================
  //  MÚSICA (Mantida compatibilidade de API como No-Op a pedido)
  // ============================================================
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
