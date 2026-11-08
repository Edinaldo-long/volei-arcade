import 'dart:math' as math;

/// Gerenciador de micro-pausas (freeze frames / hitstop).
/// Quando acionado, congela a atualização da física do jogo e movimentação
/// dos jogadores por breves instantes (ex: 40ms a 70ms), amplificando o impacto de cortadas e bloqueios.
class HitstopController {
  double _freezeTimer = 0.0;

  /// Retorna se a simulação principal está congelada neste frame.
  bool get isFrozen => _freezeTimer > 0;

  /// Tempo restante de congelamento em segundos.
  double get remainingTime => _freezeTimer;

  /// Dispara um hitstop com a [duration] em segundos.
  void trigger(double duration) {
    if (duration > _freezeTimer) {
      _freezeTimer = duration;
    }
  }

  /// Atualiza o temporizador. Retorna `true` se a simulação continua congelada.
  bool update(double dt) {
    if (_freezeTimer > 0) {
      _freezeTimer = math.max(0.0, _freezeTimer - dt);
      return _freezeTimer > 0;
    }
    return false;
  }

  /// Força o reset imediato do hitstop.
  void reset() {
    _freezeTimer = 0.0;
  }
}
