import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Renderizador aprimorado da quadra, rede e elementos visuais de arena.
/// Suporta tanto Ginásio Olímpico (Indoor) quanto Vôlei de Praia (Beach).
class CourtRenderer {
  static const Color kOutline = Color(0xFF14122B);

  // Ginásio
  static const Color kCourtOrange = Color(0xFFD45D28);
  static const Color kCourtWoodAlt = Color(0xFFCB521E);
  static const Color kFloorBlue = Color(0xFF3B7BBF);

  // Praia
  static const Color kBeachSand = Color(0xFFF3D694);
  static const Color kBeachSandDeep = Color(0xFFE5BE6C);
  static const Color kBeachLineBlue = Color(0xFF1976D2);

  /// Desenha a superfície da quadra e suas marcações regulamentares.
  static void drawCourt({
    required Canvas canvas,
    required double Function(double gx, double gy) sx,
    required double Function(double gy, double gz) sy,
    required double kL,
    required double kWd,
    required double kMid,
    bool isBeach = false,
  }) {
    // 1. Polígono principal da quadra
    final courtPath = Path()
      ..moveTo(sx(0, 0), sy(0, 0))
      ..lineTo(sx(kL, 0), sy(0, 0))
      ..lineTo(sx(kL, kWd), sy(kWd, 0))
      ..lineTo(sx(0, kWd), sy(kWd, 0))
      ..close();

    // Sombra sutil sob a quadra
    canvas.drawPath(
      courtPath,
      Paint()
        ..color = Colors.black.withValues(alpha: isBeach ? 0.18 : 0.25)
        ..style = PaintingStyle.fill,
    );

    // Preenchimento base da quadra
    canvas.drawPath(
      courtPath,
      Paint()
        ..color = isBeach ? kBeachSand : kCourtOrange
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    if (isBeach) {
      // Textura suave de dunas / ondulações de areia
      final sandPaint = Paint()
        ..color = kBeachSandDeep.withValues(alpha: 0.50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..isAntiAlias = true;

      for (var y = 25.0; y < kWd; y += 38.0) {
        final path = Path();
        path.moveTo(sx(0, y), sy(y, 0));
        for (var x = 0.0; x <= kL; x += 60.0) {
          final waveY = y + math.sin(x * 0.03 + y) * 2.0;
          path.lineTo(sx(x, waveY), sy(waveY, 0));
        }
        canvas.drawPath(path, sandPaint);
      }

      // Fitas demarcatórias regulamentares de vôlei de praia (azul vibrante)
      final beachRibbon = Paint()
        ..color = kBeachLineBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.square
        ..strokeJoin = StrokeJoin.miter
        ..isAntiAlias = true;

      canvas.drawPath(courtPath, beachRibbon);

      // Fita sob a rede
      canvas.drawLine(
        Offset(sx(kMid, 0), sy(0, 0)),
        Offset(sx(kMid, kWd), sy(kWd, 0)),
        beachRibbon..strokeWidth = 3.0,
      );

      // Estacas / âncoras nos 4 cantos da fita de areia
      final pegPaint = Paint()
        ..color = const Color(0xFFD32F2F)
        ..style = PaintingStyle.fill;
      for (final pt in [
        Offset(sx(0, 0), sy(0, 0)),
        Offset(sx(kL, 0), sy(0, 0)),
        Offset(sx(kL, kWd), sy(kWd, 0)),
        Offset(sx(0, kWd), sy(kWd, 0)),
      ]) {
        canvas.drawCircle(pt, 4.0, pegPaint);
      }
    } else {
      // Textura de tábuas de piso esportivo em perspectiva (Ginásio)
      final plankPaint = Paint()
        ..color = kCourtWoodAlt.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..isAntiAlias = true;

      for (var y = 35.0; y < kWd; y += 45.0) {
        canvas.drawLine(
          Offset(sx(0, y), sy(y, 0)),
          Offset(sx(kL, y), sy(y, 0)),
          plankPaint,
        );
      }

      // Linhas brancas da quadra indoor
      final thickLine = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;

      // Linha de contorno externa
      canvas.drawPath(courtPath, thickLine);

      // Linha central sob a rede
      canvas.drawLine(
        Offset(sx(kMid, 0), sy(0, 0)),
        Offset(sx(kMid, kWd), sy(kWd, 0)),
        thickLine,
      );

      // Linhas de 3 metros (ataque)
      final attackLine = Paint()
        ..color = Colors.white.withValues(alpha: 0.90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..isAntiAlias = true;

      for (final a in [kMid - 150.0, kMid + 150.0]) {
        canvas.drawLine(
          Offset(sx(a, 0), sy(0, 0)),
          Offset(sx(a, kWd), sy(kWd, 0)),
          attackLine,
        );
      }
    }
  }

  /// Desenha uma fatia da rede com malha fina e fita superior com cabos de aço.
  static void drawNetSlice({
    required Canvas canvas,
    required double Function(double gy) sc,
    required double Function(double gy, double gz) sy,
    required double cx,
    required double g0,
    required double g1,
    required double kNetH,
    bool isBeach = false,
  }) {
    final hw0 = 5.0 * sc(g0), hw1 = 5.0 * sc(g1);
    final top0 = sy(g0, kNetH), bot1 = sy(g1, 0);

    final netMeshPath = Path()
      ..moveTo(cx - hw0, top0)
      ..lineTo(cx + hw0, top0)
      ..lineTo(cx + hw1, bot1)
      ..lineTo(cx - hw1, bot1)
      ..close();

    // Malha escura semitransparente
    canvas.drawPath(
      netMeshPath,
      Paint()
        ..color = const Color(0xC0151520)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    // Linhas quadriculadas da malha da rede
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var y = top0 + 4; y < bot1; y += 5.5) {
      final t = (y - top0) / (bot1 - top0);
      final hw = hw0 + (hw1 - hw0) * t;
      canvas.drawLine(Offset(cx - hw, y), Offset(cx + hw, y), gridPaint);
    }

    // Fita superior (amarelo solar na praia, branca no ginásio)
    final tapeColor = isBeach ? const Color(0xFFFFD54F) : const Color(0xFFF8F9FA);
    final tapePaint = Paint()
      ..color = tapeColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawRect(Rect.fromLTRB(cx - hw0 - 1, top0, cx - hw0 + 1, bot1), tapePaint);
    canvas.drawRect(Rect.fromLTRB(cx + hw0 - 1, top0, cx + hw0 + 1, bot1), tapePaint);

    // Cabo de aço na borda superior da fita
    canvas.drawLine(
      Offset(cx - hw0 - 1.5, top0),
      Offset(cx + hw1 + 1.5, top0),
      Paint()
        ..color = isBeach ? const Color(0xFF1976D2) : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  /// Desenha a antena regulamentar de vôlei (listras vermelhas e brancas acima da rede).
  static void drawAntenna({
    required Canvas canvas,
    required double Function(double gy) sc,
    required double Function(double gy, double gz) sy,
    required double cx,
    required double gy,
    required double kNetH,
  }) {
    final s = sc(gy);
    final topNetY = sy(gy, kNetH);
    final antennaTopY = topNetY - 55.0 * s;
    final antennaX = cx + (gy > 200 ? 5.0 * s : -5.0 * s);

    const stripes = 6;
    final stripeH = (topNetY - antennaTopY) / stripes;

    for (var i = 0; i < stripes; i++) {
      final y0 = antennaTopY + i * stripeH;
      final paint = Paint()
        ..color = (i.isEven ? const Color(0xFFE53935) : Colors.white)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.0, 3.2 * s)
        ..strokeCap = StrokeCap.square;

      canvas.drawLine(Offset(antennaX, y0), Offset(antennaX, y0 + stripeH), paint);
    }
  }
}
