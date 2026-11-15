import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Renderizador aprimorado de bola de vôlei.
/// Substitui os arcos simples por uma esfera 3D realista com gradiente esférico,
/// painéis aerodinâmicos em curva (estilo Mikasa V200W / bola olímpica) e brilho especular.
///
/// Otimizado para alto desempenho com reutilização de tintas e clip acelerado por hardware.
class BallRenderer {
  static const Color kOutline = Color(0xFF14122B);
  static const Color kBluePanel = Color(0xFF1565C0);
  static const Color kYellowPanel = Color(0xFFFFD600);
  static const Color kSeamColor = Color(0xFF0D1B2A);

  // Tintas reutilizáveis para eliminar alocações C++ no frame rate
  static final Paint _outlinePaint = Paint()
    ..color = kOutline
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  static final Paint _seamPaint = Paint()
    ..color = kSeamColor
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  static final Paint _bluePanelPaint = Paint()
    ..color = kBluePanel
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  static final Paint _yellowPanelPaint = Paint()
    ..color = kYellowPanel
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  static final Paint _blueArcPaint = Paint()
    ..color = kBluePanel
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  static final Paint _yellowArcPaint = Paint()
    ..color = kYellowPanel
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  static final Paint _highlightPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.55)
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  static final Paint _basePaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  static double _lastShaderRadius = -1.0;

  static void draw({
    required Canvas canvas,
    required double cx,
    required double cy,
    required double radius,
    required double angle,
    double stretch = 1.0,
    double squash = 1.0,
    double moveAngle = 0.0,
  }) {
    canvas.save();
    canvas.translate(cx, cy);

    // Squash & Stretch na direção do vetor de movimento
    if (stretch != 1.0 || squash != 1.0) {
      canvas.rotate(moveAngle);
      canvas.scale(stretch, squash);
      canvas.rotate(-moveAngle);
    }

    // 1. Sombra e base da esfera com gradiente radial (efeito 3D volumétrico)
    final sphereRect = Rect.fromCircle(center: Offset.zero, radius: radius);
    if ((_lastShaderRadius - radius).abs() > 0.5) {
      _lastShaderRadius = radius;
      _basePaint.shader = const RadialGradient(
        center: Alignment(-0.35, -0.35),
        radius: 0.9,
        colors: [
          Colors.white,
          Color(0xFFEEEEEE),
          Color(0xFFB0BEC5),
          Color(0xFF78909C),
        ],
        stops: [0.0, 0.45, 0.85, 1.0],
      ).createShader(sphereRect);
    }

    canvas.drawCircle(Offset.zero, radius, _basePaint);

    // 2. Painéis curvos aerodinâmicos que giram com o ângulo da bola
    canvas.save();
    canvas.rotate(angle);

    // Máscara circular acelerada por hardware (clipRRect evita buffer de estêncil)
    canvas.clipRRect(RRect.fromRectAndRadius(sphereRect, Radius.circular(radius)));

    _seamPaint.strokeWidth = math.max(1.8, radius * 0.12);

    // Painéis azuis e amarelos ondulados
    const panelCount = 3;
    for (var i = 0; i < panelCount; i++) {
      canvas.save();
      canvas.rotate(i * 2 * math.pi / panelCount);

      // Faixa ondulada azul
      final bluePath = Path()
        ..moveTo(-radius * 0.8, -radius * 0.2)
        ..cubicTo(
          -radius * 0.4,
          -radius * 0.8,
          radius * 0.4,
          -radius * 0.6,
          radius * 0.85,
          -radius * 0.1,
        )
        ..lineTo(radius * 0.7, radius * 0.3)
        ..cubicTo(
          radius * 0.2,
          -radius * 0.1,
          -radius * 0.3,
          -radius * 0.2,
          -radius * 0.8,
          radius * 0.1,
        )
        ..close();

      canvas.drawPath(bluePath, i == 1 ? _yellowPanelPaint : _bluePanelPaint);
      canvas.drawPath(bluePath, _seamPaint);

      // Faixa amarela de contraste
      final yellowArc = Path()
        ..addArc(
          Rect.fromCircle(center: Offset(radius * 0.2, radius * 0.2), radius: radius * 0.55),
          0.8,
          1.6,
        );

      final arcPaint = i == 1 ? _blueArcPaint : _yellowArcPaint;
      arcPaint.strokeWidth = math.max(3.0, radius * 0.32);
      canvas.drawPath(yellowArc, arcPaint);

      canvas.restore();
    }

    canvas.restore(); // Fecha rotação do spin dos painéis

    // 3. Contorno da bola
    _outlinePaint.strokeWidth = math.max(2.2, radius * 0.16);
    canvas.drawCircle(Offset.zero, radius, _outlinePaint);

    // 4. Brilho especular 3D (highlight superior esquerdo)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-radius * 0.32, -radius * 0.32),
        width: radius * 0.55,
        height: radius * 0.35,
      ),
      _highlightPaint,
    );

    canvas.restore();
  }
}
