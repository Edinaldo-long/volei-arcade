import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// Sistema de áudio arcade multiplataforma (Android, iOS, Web, Desktop) via audioplayers.
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

  static AudioPlayer? _bgmPlayerInstance;
  static AudioPlayer? get _bgmPlayer {
    if (_isTestEnvironment()) return null;
    try {
      _bgmPlayerInstance ??= AudioPlayer();
      return _bgmPlayerInstance;
    } catch (_) {
      return null;
    }
  }

  // Pool de players para efeitos sonoros simultâneos e baixa latência (SoundPool no Android)
  static List<AudioPlayer>? _sfxPlayersInstance;
  static List<AudioPlayer> get _sfxPlayers {
    if (_isTestEnvironment()) return const [];
    try {
      _sfxPlayersInstance ??= List.generate(6, (_) => AudioPlayer());
      return _sfxPlayersInstance!;
    } catch (_) {
      return const [];
    }
  }
  static int _sfxIndex = 0;

  static void _playSfx(String assetPath, {double volume = 1.0}) {
    if (_isTestEnvironment()) return;
    try {
      final pool = _sfxPlayers;
      if (pool.isEmpty) return;
      final player = pool[_sfxIndex % pool.length];
      _sfxIndex = (_sfxIndex + 1) % pool.length;
      player.setVolume(volume).catchError((_) {});
      player.play(AssetSource('audio/$assetPath'), mode: PlayerMode.lowLatency).catchError((_) {});
    } catch (_) {}
  }

  // ============================================================
  //  EFEITOS SONOROS
  // ============================================================
  static void playTouch() => _playSfx('touch.wav', volume: 0.85);

  static void playSpike({bool perfect = false}) =>
      _playSfx(perfect ? 'spike_perfect.wav' : 'spike.wav', volume: 1.0);

  static void playBlock() => _playSfx('block.wav', volume: 0.95);

  static void playBounce() => _playSfx('bounce.wav', volume: 0.75);

  static void playWhistle() => _playSfx('whistle.wav', volume: 0.90);

  static void playCrowdCheer({bool big = false}) =>
      _playSfx('cheer.wav', volume: big ? 1.0 : 0.75);

  static void playApplause() => _playSfx('cheer.wav', volume: 0.65);

  static void playStadiumHorn() => _playSfx('horn.wav', volume: 0.85);

  static void playPointCheer({bool perfect = false}) =>
      _playSfx('point.wav', volume: 0.95);

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
      await player.setReleaseMode(ReleaseMode.loop).catchError((_) {});
      await player.setVolume(0.55).catchError((_) {});
      final trackFile = 'bgm_${_currentTrack % 4}.wav';
      await player.play(AssetSource('audio/$trackFile')).catchError((_) {});
    } catch (_) {}
  }

  static void stopBgm() async {
    if (_isTestEnvironment()) return;
    try {
      await _bgmPlayer?.stop().catchError((_) {});
    } catch (_) {}
  }

  static void pauseBgm() async {
    if (_isTestEnvironment()) return;
    try {
      await _bgmPlayer?.pause().catchError((_) {});
    } catch (_) {}
  }

  static void resumeBgm() async {
    if (!_musicEnabled || _isTestEnvironment()) return;
    try {
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
