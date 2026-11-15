import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Serviço nativo de feedback tátil (vibração) para jogadas de impacto no Vôlei Arcade.
/// 
/// Integra com o motor de vibração nativo do Android (`android.os.Vibrator` com `USAGE_GAME`)
/// garantindo que funcione de forma consistente em todos os aparelhos (Samsung, Xiaomi, Motorola, etc.),
/// mesmo se o usuário tiver desativado a vibração de toque do teclado do Android nas configurações gerais.
class HapticService {
  static const MethodChannel _vibratorChannel =
      MethodChannel('com.edinaldo.volei/vibrator');

  static bool _vibrationEnabled = true;

  /// Retorna se a vibração háptica está ativada pelo jogador
  static bool get isVibrationEnabled => _vibrationEnabled;

  /// Define explicitamente se a vibração está ativa
  static void setVibrationEnabled(bool enabled) {
    _vibrationEnabled = enabled;
  }

  /// Alterna o estado de vibração e retorna o novo estado.
  /// Se ligado, dispara um pulso de teste imediato para confirmar ao jogador que a vibração está funcionando.
  static bool toggleVibration() {
    _vibrationEnabled = !_vibrationEnabled;
    if (_vibrationEnabled) {
      _vibrateNative(durationMs: 50, amplitude: 220);
    }
    return _vibrationEnabled;
  }

  /// Dispara vibração nativa no Android com duração em milissegundos e amplitude exatas
  static Future<void> _vibrateNative({
    required int durationMs,
    int amplitude = 255,
  }) async {
    if (!_vibrationEnabled || _isTestEnvironment()) return;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final ok = await _vibratorChannel.invokeMethod<bool>('vibrate', {
          'duration': durationMs,
          'amplitude': amplitude,
        });
        if (ok == true) return;
      } catch (_) {}
    }
    // Fallback multiplataforma via HapticFeedback oficial do Flutter
    try {
      if (durationMs >= 60) {
        await HapticFeedback.heavyImpact();
      } else {
        await HapticFeedback.mediumImpact();
      }
    } catch (_) {}
  }

  /// Dispara padrão duplo/waveform de vibração nativo no Android
  static Future<void> _vibrateWaveformNative({
    required List<int> timings,
  }) async {
    if (!_vibrationEnabled || _isTestEnvironment()) return;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final ok = await _vibratorChannel.invokeMethod<bool>('vibrateWaveform', {
          'timings': timings,
          'repeat': -1,
        });
        if (ok == true) return;
      } catch (_) {}
    }
    // Fallback multiplataforma
    try {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 70));
      if (_vibrationEnabled) {
        await HapticFeedback.mediumImpact();
      }
    } catch (_) {}
  }

  /// Verifica com segurança se o ambiente é de testes automatizados
  static bool _isTestEnvironment() {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  /// Impacto tátil para cortada potente / super cortada.
  /// Dispara um pulso rápido e marcante (~45ms a ~65ms).
  static Future<void> spikeImpact({bool perfect = false}) async {
    if (!_vibrationEnabled || _isTestEnvironment()) return;
    await _vibrateNative(
      durationMs: perfect ? 65 : 45,
      amplitude: perfect ? 255 : 210,
    );
  }

  /// Impacto tátil para Monster Block (bloqueio na rede).
  /// Dispara um pulso forte duplo (~70ms impacto, 45ms pausa, 80ms reverberação),
  /// sincronizado com o som e tremor de tela.
  static Future<void> monsterBlockImpact() async {
    if (!_vibrationEnabled || _isTestEnvironment()) return;
    await _vibrateWaveformNative(
      timings: [0, 70, 45, 80],
    );
  }

  /// Feedback sutil de toque para confirmação em botões e menus
  static Future<void> selectionFeedback() async {
    if (!_vibrationEnabled || _isTestEnvironment()) return;
    await _vibrateNative(durationMs: 25, amplitude: 160);
  }
}
