import 'package:flutter/material.dart';

/// Ponto individual na trilha de movimento da bola.
class TrailPoint {
  final Offset position;
  final double radius;
  final Color color;
  double life;
  final double maxLife;

  TrailPoint({
    required this.position,
    required this.radius,
    required this.color,
    required this.maxLife,
  }) : life = maxLife;
}

/// Gerenciador de rastro dinâmico (speed streak) para a bola em alta velocidade.
class MotionTrail {
  final List<TrailPoint> _points = [];
  final double minSpeedThreshold;
  final int maxPoints;
  final double pointLifetime;

  MotionTrail({
    this.minSpeedThreshold = 420.0,
    this.maxPoints = 12,
    this.pointLifetime = 0.18,
  });

  /// Adiciona uma amostra na trilha se a velocidade instantânea estiver acima do limiar.
  void addSample({
    required Offset screenPos,
    required double radius,
    required double speed,
    Color color = const Color(0xFFFFD54F),
  }) {
    if (speed < minSpeedThreshold) return;

    // Evita acumular pontos muito próximos na mesma posição
    if (_points.isNotEmpty) {
      final last = _points.last.position;
      final distSq = (screenPos.dx - last.dx) * (screenPos.dx - last.dx) +
          (screenPos.dy - last.dy) * (screenPos.dy - last.dy);
      if (distSq < 16.0) return;
    }

    _points.add(TrailPoint(
      position: screenPos,
      radius: radius,
      color: color,
      maxLife: pointLifetime,
    ));

    if (_points.length > maxPoints) {
      _points.removeAt(0);
    }
  }

  /// Atualiza o decaimento dos pontos.
  void update(double dt) {
    for (final pt in _points) {
      pt.life -= dt;
    }
    _points.removeWhere((pt) => pt.life <= 0);
  }

  /// Limpa toda a trilha imediatamente (ex: ao tocar no chão ou na rede).
  void clear() {
    _points.clear();
  }

  /// Renderiza o rastro no Canvas antes da bola.
  void render(Canvas canvas) {
    if (_points.isEmpty) return;

    for (var i = 0; i < _points.length; i++) {
      final pt = _points[i];
      final factor = (pt.life / pt.maxLife).clamp(0.0, 1.0);
      final alpha = (factor * 0.45 * (i / _points.length)).clamp(0.0, 0.5);
      final r = pt.radius * (0.4 + 0.6 * factor);

      final paint = Paint()
        ..color = pt.color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      canvas.drawCircle(pt.position, r, paint);
    }
  }
}
