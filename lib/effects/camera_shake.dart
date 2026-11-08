import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Gerenciador de tremor de tela baseado em Trauma (trauma^2 decay).
/// Proporciona um tremor muito mais natural e responsivo a impactos.
class CameraShake {
  /// Trauma acumulado (0.0 a 1.0).
  double trauma = 0.0;

  /// Amplitude máxima de deslocamento em pixels.
  final double maxOffset;

  /// Taxa de decaimento do trauma por segundo.
  final double decay;

  CameraShake({
    this.maxOffset = 14.0,
    this.decay = 2.4,
  });

  /// Adiciona trauma ao sistema (acumulativo até 1.0).
  void addTrauma(double amount) {
    trauma = (trauma + amount).clamp(0.0, 1.0);
  }

  /// Atualiza o decaimento temporal do trauma.
  void update(double dt) {
    if (trauma > 0) {
      trauma = math.max(0.0, trauma - decay * dt);
    }
  }

  /// Calcula o deslocamento (dx, dy) para este frame baseado em trauma ao quadrado.
  Offset getOffset(math.Random rnd) {
    if (trauma <= 0.001) return Offset.zero;
    final shake = trauma * trauma * maxOffset;
    final dx = (rnd.nextDouble() * 2.0 - 1.0) * shake;
    final dy = (rnd.nextDouble() * 2.0 - 1.0) * shake;
    return Offset(dx, dy);
  }

  /// Zera o trauma instantaneamente.
  void reset() {
    trauma = 0.0;
  }
}
