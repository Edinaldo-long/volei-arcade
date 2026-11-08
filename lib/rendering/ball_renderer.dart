import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Renderizador aprimorado de bola de vôlei.
/// Substitui os arcos simples por uma esfera 3D realista com gradiente esférico,
/// painéis aerodinâmicos em curva (estilo Mikasa V200W / bola olímpica) e brilho especular.
class BallRenderer {
  static const Color kOutline = Color(0xFF14122B);
  static const Color kBluePanel = Color(0xFF1565C0);
  static const Color kYellowPanel = Color(0xFFFFD600);
  static const Color kSeamColor = Color(0xFF0D1B2A);

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

    // Contorno escuro da bola
    final outlinePaint = Paint()
      ..color = kOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.2, radius * 0.16)
      ..isAntiAlias = true;

    // 1. Sombra e base da esfera com gradiente radial (efeito 3D volumétrico)
    final sphereRect = Rect.fromCircle(center: Offset.zero, radius: radius);
    final sphereGrad = RadialGradient(
      center: const Alignment(-0.35, -0.35),
      radius: 0.9,
      colors: const [
        Colors.white,
        Color(0xFFEEEEEE),
        Color(0xFFB0BEC5),
        Color(0xFF78909C),
      ],
      stops: const [0.0, 0.45, 0.85, 1.0],
    );

    final basePaint = Paint()
      ..shader = sphereGrad.createShader(sphereRect)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawCircle(Offset.zero, radius, basePaint);

    // 2. Painéis curvos aerodinâmicos que giram com o ângulo da bola
    canvas.save();
    canvas.rotate(angle);

    // Máscara circular para os painéis ficarem confinados à esfera
    canvas.clipPath(Path()..addOval(sphereRect));

    final seamPaint = Paint()
      ..color = kSeamColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, radius * 0.12)
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

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

      canvas.drawPath(
        bluePath,
        Paint()
          ..color = (i == 1 ? kYellowPanel : kBluePanel)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.drawPath(bluePath, seamPaint);

      // Faixa amarela de contraste
      final yellowArc = Path()
        ..addArc(
          Rect.fromCircle(center: Offset(radius * 0.2, radius * 0.2), radius: radius * 0.55),
          0.8,
          1.6,
        );
      canvas.drawPath(
        yellowArc,
        Paint()
          ..color = (i == 1 ? kBluePanel : kYellowPanel)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(3.0, radius * 0.32)
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true,
      );

      canvas.restore();
    }

    canvas.restore(); // Fecha rotação do spin dos painéis

    // 3. Contorno da bola
    canvas.drawCircle(Offset.zero, radius, outlinePaint);

    // 4. Brilho especular 3D (highlight superior esquerdo)
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-radius * 0.32, -radius * 0.32),
        width: radius * 0.55,
        height: radius * 0.35,
      ),
      highlightPaint,
    );

    canvas.restore();
  }
}
