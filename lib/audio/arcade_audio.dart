import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// Sistema de áudio arcade multiplataforma (Android, iOS, Web, Desktop) via audioplayers.
///
/// Arquitetura de canais dedicados para efeitos sonoros (SFX):
/// 1. Música de fundo (BGM) desativada a pedido do usuário (somente efeitos sonoros ativos).
/// 2. Canais dedicados por categoria de som (toque, cortada, apito, ponto, aplausos/torcida).
/// 3. Chamada de stop() assíncrona antes do play() para garantir reset de estado (`playing = false`)
///    no Android, impedindo que o som emudeça após alguns segundos de jogo.
/// 4. Suporte a aplausos vibrantes e comemorações quando o time do jogador faz ponto.
class ArcadeAudio {
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

  /// Contexto de áudio sem disputa de foco exclusivo (nunca pausa outros sons)
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
      // Pré-carrega todos os efeitos no cache do dispositivo de forma assíncrona
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
  //  PLAYERS DEDICADOS POR CATEGORIA (Zero colisão de canais)
  // ============================================================
  static AudioPlayer? _touchPlayerInstance;
  static AudioPlayer? _spikePlayerInstance;
  static AudioPlayer? _whistlePlayerInstance;
  static AudioPlayer? _pointPlayerInstance;
  static AudioPlayer? _cheerPlayerInstance;

  static AudioPlayer? _createPlayer(double volume) {
    if (_isTestEnvironment()) return null;
    try {
      final p = AudioPlayer();
      p.setAudioContext(_audioContext).catchError((_) {});
      p.setVolume(volume).catchError((_) {});
      return p;
    } catch (_) {
      return null;
    }
  }

  static AudioPlayer? get _touchPlayer =>
      _touchPlayerInstance ??= _createPlayer(0.90);

  static AudioPlayer? get _spikePlayer =>
      _spikePlayerInstance ??= _createPlayer(1.0);

  static AudioPlayer? get _whistlePlayer =>
      _whistlePlayerInstance ??= _createPlayer(0.55);

  static AudioPlayer? get _pointPlayer =>
      _pointPlayerInstance ??= _createPlayer(0.95);

  static AudioPlayer? get _cheerPlayer =>
      _cheerPlayerInstance ??= _createPlayer(0.85);

  /// Executa o som garantindo que qualquer estado anterior seja resetado
  static void _playSound(AudioPlayer? player, String file) {
    if (!_sfxEnabled || _isTestEnvironment() || player == null) return;
    try {
      // Chama stop() primeiro para resetar o flag nativo `playing` no Android,
      // garantindo que os sons continuem tocando por tempo indeterminado
      player.stop().then((_) {
        player.play(AssetSource('audio/$file')).catchError((_) {});
      }).catchError((_) {
        // Fallback direto se o stop falhar
        player.play(AssetSource('audio/$file')).catchError((_) {});
      });
    } catch (_) {}
  }

  // ============================================================
  //  EFEITOS SONOROS DAS AÇÕES DO JOGO
  // ============================================================
  static void playTouch() => _playSound(_touchPlayer, 'touch.wav');

  static void playBounce() => _playSound(_touchPlayer, 'bounce.wav');

  static void playSpike({bool perfect = false}) =>
      _playSound(_spikePlayer, perfect ? 'spike_perfect.wav' : 'spike.wav');

  static void playBlock() => _playSound(_spikePlayer, 'block.wav');

  static void playWhistle() => _playSound(_whistlePlayer, 'whistle.wav');

  static void playStadiumHorn() => _playSound(_whistlePlayer, 'horn.wav');

  static void playPointCheer({bool perfect = false}) =>
      _playSound(_pointPlayer, 'point.wav');

  /// Aplausos e aclamação da torcida ao fazer ponto
  static void playApplause() => _playSound(_cheerPlayer, 'cheer.wav');

  static void playCrowdCheer({bool big = false}) =>
      _playSound(_cheerPlayer, 'cheer.wav');

  // ============================================================
  //  MÚSICA (Compatibilidade com testes / No-Op a pedido)
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
