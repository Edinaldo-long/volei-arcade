import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Serviço de feedback tátil (vibração) para jogadas de impacto no Vôlei Arcade.
/// 
/// Otimizado para melhorar o Game Feel em momentos de alto impacto:
/// - Cortada potente / Super Cortada: pulso curto (~40ms via [HapticFeedback.mediumImpact] ou [heavyImpact])
/// - Monster Block (bloqueio na rede): pulso duplo de impacto forte sincronizado com o bloqueio e efeito visual
/// - Toques simples / recepção / levantamento: sem vibração (para manter a clareza e economizar bateria)
class HapticService {
  static bool _vibrationEnabled = true;

  /// Retorna se a vibração háptica está ativada pelo jogador
  static bool get isVibrationEnabled => _vibrationEnabled;

  /// Define explicitamente se a vibração está ativa
  static void setVibrationEnabled(bool enabled) {
    _vibrationEnabled = enabled;
  }

  /// Alterna o estado de vibração e retorna o novo estado
  static bool toggleVibration() {
    _vibrationEnabled = !_vibrationEnabled;
    if (_vibrationEnabled && !_isTestEnvironment()) {
      try {
        HapticFeedback.selectionClick();
      } catch (_) {}
    }
    return _vibrationEnabled;
  }

  /// Verifica se o ambiente de execução é de testes automatizados
  static bool _isTestEnvironment() {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  /// Impacto tátil para cortada potente / super cortada.
  /// Dispara um pulso curto (~40ms via mediumImpact, ou heavyImpact se for perfeita).
  static Future<void> spikeImpact({bool perfect = false}) async {
    if (!_vibrationEnabled || _isTestEnvironment()) return;
    try {
      if (perfect) {
        await HapticFeedback.heavyImpact();
      } else {
        await HapticFeedback.mediumImpact();
      }
    } catch (_) {}
  }

  /// Impacto tátil para Monster Block (bloqueio na rede).
  /// Dispara um pulso forte duplo (~100ms) sincronizado com o bloqueio e tremor de câmera.
  static Future<void> monsterBlockImpact() async {
    if (!_vibrationEnabled || _isTestEnvironment()) return;
    try {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 70));
      if (!_vibrationEnabled) return;
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Feedback sutil para interação de botões na UI quando apropriado
  static Future<void> selectionFeedback() async {
    if (!_vibrationEnabled || _isTestEnvironment()) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
