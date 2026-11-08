import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Renderizador vetorial de alta precisão das bandeiras oficiais de cada país.
///
/// Desenha proporções, geometrias e cores autênticas para:
/// Brasil, Argentina, Japão, Itália, EUA, França, Polônia, Cuba, Alemanha e Holanda.
class FlagRenderer {
  static const Color kOutline = Color(0xFF14122B);

  /// Desenha a bandeira de um país dentro de um retângulo do Canvas.
  static void drawFlag(
    Canvas canvas,
    Rect rect, {
    required String countryName,
    double borderRadius = 3.0,
    bool border = true,
  }) {
    canvas.save();

    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    canvas.clipRRect(rrect);

    final normalized = countryName.toUpperCase().trim();

    if (normalized.contains('BRASIL') || normalized.contains('BRAZIL')) {
      _drawBrazil(canvas, rect);
    } else if (normalized.contains('ARGENTINA')) {
      _drawArgentina(canvas, rect);
    } else if (normalized.contains('JAPÃO') || normalized.contains('JAPAN')) {
      _drawJapan(canvas, rect);
    } else if (normalized.contains('ITÁLIA') || normalized.contains('ITALY') || normalized.contains('ITALIA')) {
      _drawItaly(canvas, rect);
    } else if (normalized.contains('EUA') || normalized.contains('USA')) {
      _drawUSA(canvas, rect);
    } else if (normalized.contains('FRANÇA') || normalized.contains('FRANCE') || normalized.contains('FRANCA')) {
      _drawFrance(canvas, rect);
    } else if (normalized.contains('POLÔNIA') || normalized.contains('POLAND') || normalized.contains('POLONIA')) {
      _drawPoland(canvas, rect);
    } else if (normalized.contains('CUBA')) {
      _drawCuba(canvas, rect);
    } else if (normalized.contains('ALEMANHA') || normalized.contains('GERMANY')) {
      _drawGermany(canvas, rect);
    } else if (normalized.contains('HOLANDA') || normalized.contains('NETHERLANDS')) {
      _drawNetherlands(canvas, rect);
    } else {
      // Fallback genérico esportivo
      _drawGeneric(canvas, rect);
    }

    canvas.restore();

    // Borda exterior nítida para contraste
    if (border) {
      final borderPaint = Paint()
        ..color = kOutline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..isAntiAlias = true;
      canvas.drawRRect(rrect, borderPaint);
    }
  }

  /// Retorna um widget Flutter que exibe a bandeira vetorial do país.
  static Widget flagWidget(
    String countryName, {
    double width = 28,
    double height = 20,
    double borderRadius = 3.0,
    bool border = true,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _FlagCustomPainter(
          countryName: countryName,
          borderRadius: borderRadius,
          border: border,
        ),
      ),
    );
  }

  // ============================================================
  //  BANDEIRAS NACIONAIS PROCEDURAIS
  // ============================================================

  /// Brasil: Verde (#009C3B), Losango Amarelo (#FFDF00), Círculo Azul (#002776) com faixa branca
  static void _drawBrazil(Canvas canvas, Rect r) {
    final fill = Paint()..style = PaintingStyle.fill..isAntiAlias = true;

    // 1. Fundo verde
    fill.color = const Color(0xFF009C3B);
    canvas.drawRect(r, fill);

    // 2. Losango amarelo proporcional
    fill.color = const Color(0xFFFFDF00);
    final mx = r.center.dx;
    final my = r.center.dy;
    final marginX = r.width * 0.12;
    final marginY = r.height * 0.14;

    final rhombus = Path()
      ..moveTo(mx, r.top + marginY)
      ..lineTo(r.right - marginX, my)
      ..lineTo(mx, r.bottom - marginY)
      ..lineTo(r.left + marginX, my)
      ..close();
    canvas.drawPath(rhombus, fill);

    // 3. Círculo azul celestial
    final circleRadius = r.height * 0.28;
    fill.color = const Color(0xFF002776);
    canvas.drawCircle(Offset(mx, my), circleRadius, fill);

    // 4. Faixa branca equatorial curvada
    final bandPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, r.height * 0.08)
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final arcRect = Rect.fromCircle(center: Offset(mx + circleRadius * 0.2, my + circleRadius * 0.9), radius: circleRadius * 1.1);
    canvas.drawArc(arcRect, -math.pi * 0.78, math.pi * 0.45, false, bandPaint);

    // 5. Estrelas representativas
    final starPaint = Paint()..color = Colors.white..style = PaintingStyle.fill..isAntiAlias = true;
    canvas.drawCircle(Offset(mx - circleRadius * 0.25, my + circleRadius * 0.4), 0.7, starPaint);
    canvas.drawCircle(Offset(mx + circleRadius * 0.30, my + circleRadius * 0.45), 0.7, starPaint);
    canvas.drawCircle(Offset(mx + circleRadius * 0.10, my - circleRadius * 0.35), 0.7, starPaint);
  }

  /// Argentina: 3 faixas horizontais (Azul-Branco-Azul) e Sol de Mayo no centro
  static void _drawArgentina(Canvas canvas, Rect r) {
    final fill = Paint()..style = PaintingStyle.fill..isAntiAlias = true;
    final h3 = r.height / 3;

    // Faixas horizontais
    fill.color = const Color(0xFF74ACDF);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, h3), fill);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top + h3 * 2, r.width, h3), fill);

    fill.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(r.left, r.top + h3, r.width, h3), fill);

    // Sol de Mayo dourado
    final cx = r.center.dx;
    final cy = r.center.dy;
    final sunR = h3 * 0.40;

    // Raios do sol
    final rayPaint = Paint()
      ..color = const Color(0xFFF6B40E)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    for (var a = 0.0; a < math.pi * 2; a += math.pi / 4) {
      final p1 = Offset(cx + math.cos(a) * sunR * 0.8, cy + math.sin(a) * sunR * 0.8);
      final p2 = Offset(cx + math.cos(a) * sunR * 1.35, cy + math.sin(a) * sunR * 1.35);
      canvas.drawLine(p1, p2, rayPaint);
    }

    fill.color = const Color(0xFFF6B40E);
    canvas.drawCircle(Offset(cx, cy), sunR * 0.85, fill);
    fill.color = const Color(0xFF8D5B00);
    canvas.drawCircle(Offset(cx, cy), sunR * 0.35, fill);
  }

  /// Japão: Fundo branco com círculo vermelho carmesim no centro
  static void _drawJapan(Canvas canvas, Rect r) {
    final fill = Paint()..style = PaintingStyle.fill..isAntiAlias = true;
    fill.color = Colors.white;
    canvas.drawRect(r, fill);

    fill.color = const Color(0xFFBC002D);
    canvas.drawCircle(r.center, r.height * 0.30, fill);
  }

  /// Itália: 3 faixas verticais (Verde - Branco - Vermelho)
  static void _drawItaly(Canvas canvas, Rect r) {
    final fill = Paint()..style = PaintingStyle.fill..isAntiAlias = true;
    final w3 = r.width / 3;

    fill.color = const Color(0xFF009246);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, w3, r.height), fill);

    fill.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(r.left + w3, r.top, w3, r.height), fill);

    fill.color = const Color(0xFFCE2B37);
    canvas.drawRect(Rect.fromLTWH(r.left + w3 * 2, r.top, w3 + 0.5, r.height), fill);
  }

  /// EUA: 13 listras vermelhas e brancas + Cantão Azul com estrelas
  static void _drawUSA(Canvas canvas, Rect r) {
    final fill = Paint()..style = PaintingStyle.fill..isAntiAlias = true;
    const stripes = 13;
    final sh = r.height / stripes;

    for (var i = 0; i < stripes; i++) {
      fill.color = i % 2 == 0 ? const Color(0xFFB22234) : Colors.white;
      canvas.drawRect(Rect.fromLTWH(r.left, r.top + i * sh, r.width, sh + 0.3), fill);
    }

    // Cantão azul (ocupa 7 listras de altura e 42% da largura)
    final cantonW = r.width * 0.44;
    final cantonH = sh * 7;
    fill.color = const Color(0xFF3C3B6E);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, cantonW, cantonH), fill);

    // Matriz de estrelas brancas
    final starPaint = Paint()..color = Colors.white..style = PaintingStyle.fill..isAntiAlias = true;
    for (var row = 1; row <= 3; row++) {
      for (var col = 1; col <= 4; col++) {
        final sx = r.left + (cantonW / 5) * col;
        final sy = r.top + (cantonH / 4) * row;
        canvas.drawCircle(Offset(sx, sy), 0.7, starPaint);
      }
    }
  }

  /// França: 3 faixas verticais (Azul - Branco - Vermelho)
  static void _drawFrance(Canvas canvas, Rect r) {
    final fill = Paint()..style = PaintingStyle.fill..isAntiAlias = true;
    final w3 = r.width / 3;

    fill.color = const Color(0xFF002395);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, w3, r.height), fill);

    fill.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(r.left + w3, r.top, w3, r.height), fill);

    fill.color = const Color(0xFFED2939);
    canvas.drawRect(Rect.fromLTWH(r.left + w3 * 2, r.top, w3 + 0.5, r.height), fill);
  }

  /// Polônia: 2 faixas horizontais (Branca em cima, Vermelha embaixo)
  static void _drawPoland(Canvas canvas, Rect r) {
    final fill = Paint()..style = PaintingStyle.fill..isAntiAlias = true;
    final h2 = r.height / 2;

    fill.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, h2), fill);

    fill.color = const Color(0xFFDC143C);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top + h2, r.width, h2), fill);
  }

  /// Cuba: 5 faixas (Azul-Branco) + Triângulo Vermelho com estrela
  static void _drawCuba(Canvas canvas, Rect r) {
    final fill = Paint()..style = PaintingStyle.fill..isAntiAlias = true;
    const stripes = 5;
    final sh = r.height / stripes;

    for (var i = 0; i < stripes; i++) {
      fill.color = i % 2 == 0 ? const Color(0xFF002590) : Colors.white;
      canvas.drawRect(Rect.fromLTWH(r.left, r.top + i * sh, r.width, sh + 0.3), fill);
    }

    // Triângulo vermelho à esquerda
    fill.color = const Color(0xFFCB1515);
    final triW = r.width * 0.42;
    final triangle = Path()
      ..moveTo(r.left, r.top)
      ..lineTo(r.left + triW, r.center.dy)
      ..lineTo(r.left, r.bottom)
      ..close();
    canvas.drawPath(triangle, fill);

    // Estrela branca no centro do triângulo
    final starPaint = Paint()..color = Colors.white..style = PaintingStyle.fill..isAntiAlias = true;
    final starCenter = Offset(r.left + triW * 0.36, r.center.dy);
    canvas.drawCircle(starCenter, r.height * 0.12, starPaint);
  }

  /// Alemanha: 3 faixas horizontais (Preto - Vermelho - Dourado)
  static void _drawGermany(Canvas canvas, Rect r) {
    final fill = Paint()..style = PaintingStyle.fill..isAntiAlias = true;
    final h3 = r.height / 3;

    fill.color = const Color(0xFF000000);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, h3), fill);

    fill.color = const Color(0xFFDD0000);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top + h3, r.width, h3), fill);

    fill.color = const Color(0xFFFFCE00);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top + h3 * 2, r.width, h3 + 0.5), fill);
  }

  /// Holanda: 3 faixas horizontais (Vermelho - Branco - Azul Cobalto)
  static void _drawNetherlands(Canvas canvas, Rect r) {
    final fill = Paint()..style = PaintingStyle.fill..isAntiAlias = true;
    final h3 = r.height / 3;

    fill.color = const Color(0xFFAE1C28);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, h3), fill);

    fill.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(r.left, r.top + h3, r.width, h3), fill);

    fill.color = const Color(0xFF21468B);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top + h3 * 2, r.width, h3 + 0.5), fill);
  }

  /// Genérico
  static void _drawGeneric(Canvas canvas, Rect r) {
    final fill = Paint()..style = PaintingStyle.fill..isAntiAlias = true;
    fill.color = const Color(0xFF1E88E5);
    canvas.drawRect(r, fill);
    fill.color = Colors.white;
    canvas.drawCircle(r.center, r.height * 0.3, fill);
  }
}

class _FlagCustomPainter extends CustomPainter {
  final String countryName;
  final double borderRadius;
  final bool border;

  _FlagCustomPainter({
    required this.countryName,
    required this.borderRadius,
    required this.border,
  });

  @override
  void paint(Canvas canvas, Size size) {
    FlagRenderer.drawFlag(
      canvas,
      Rect.fromLTWH(0, 0, size.width, size.height),
      countryName: countryName,
      borderRadius: borderRadius,
      border: border,
    );
  }

  @override
  bool shouldRepaint(covariant _FlagCustomPainter oldDelegate) {
    return oldDelegate.countryName != countryName ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.border != border;
  }
}
