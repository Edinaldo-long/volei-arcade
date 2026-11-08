import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Renderizador estilizado e anatômico de personagens de vôlei.
///
/// Implementa visão em perspectiva 3/4 voltada para a rede e para o adversário,
/// com espelhamento perfeito para o oponente via canvas.scale(-1, 1),
/// eliminando qualquer deformação de coordenadas ou membros deslocados.
class CharacterRenderer {
  static const Color kOutline = Color(0xFF14122B);

  static void draw({
    required Canvas canvas,
    required double ox,
    required double oy,
    required double P,
    required double face, // 1.0 = time esquerdo (olha para a rede/direita), -1.0 = time direito (olha para a rede/esquerda)
    required Color shirtColor,
    required Color trimColor,
    required Color skinColor,
    required Color hairColor,
    String jerseyNumber = '7',
    bool armsUp = false,
    bool swinging = false,
    bool air = false,
    bool moving = false,
    int step = -1,
    bool isBeach = false,
  }) {
    canvas.save();
    canvas.translate(ox, oy);

    // O segredo do espelhamento perfeito:
    // Se face < 0 (oponente no lado direito da rede), espelhamos todo o canvas horizontalmente.
    // Todas as rotinas internas são desenhadas canonicamente com o jogador olhando para a DIREITA (em direção à rede).
    if (face < 0) {
      canvas.scale(-1.0, 1.0);
    }

    final outlinePaint = Paint()
      ..color = kOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, P * 0.42)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Tom de pele sombreado para profundidade muscular
    final skinShade = HSLColor.fromColor(skinColor)
        .withLightness((HSLColor.fromColor(skinColor).lightness * 0.82).clamp(0.0, 1.0))
        .toColor();

    // Sombra do uniforme
    final shirtShade = HSLColor.fromColor(shirtColor)
        .withLightness((HSLColor.fromColor(shirtColor).lightness * 0.76).clamp(0.0, 1.0))
        .toColor();

    void drawRounded(Rect r, Color color, [double radiusRatio = 0.4]) {
      final radius = Radius.circular(r.shortestSide * radiusRatio);
      final rrect = RRect.fromRectAndRadius(r, radius);
      fillPaint.color = color;
      canvas.drawRRect(rrect, fillPaint);
      canvas.drawRRect(rrect, outlinePaint);
    }

    // Offset dinâmico de passada e salto
    final legBackOffset = air ? -P * 3.5 : (step == 0 ? -P * 3.0 : (step == 1 ? P * 1.5 : 0.0));
    final legFrontOffset = air ? P * 3.0 : (step == 0 ? P * 3.0 : (step == 1 ? -P * 1.5 : 0.0));
    final footLift = air ? P * 2.8 : (moving && step >= 0 ? P * 1.3 : 0.0);

    // ==========================================
    // 1. BRAÇO TRASEIRO (Back Arm - fica atrás do tronco)
    // ==========================================
    if (!armsUp) {
      // Manga traseira
      drawRounded(
        Rect.fromLTWH(-P * 4.6, -P * 20.0, P * 2.8, P * 2.5),
        shirtShade,
        0.4,
      );
      // Braço estendido para baixo / pronto
      drawRounded(
        Rect.fromLTWH(-P * 4.4, -P * 17.6, P * 2.6, P * 7.8),
        skinShade,
        0.5,
      );
    } else {
      // Braço traseiro erguido no salto
      drawRounded(
        Rect.fromLTWH(-P * 2.5, swinging ? -P * 29.5 : -P * 30.5, P * 2.8, P * 10.5),
        skinShade,
        0.45,
      );
    }

    // ==========================================
    // 2. PERNA TRASEIRA (Back Leg)
    // ==========================================
    final backThighX = -P * 2.8 + legBackOffset * 0.4;
    drawRounded(
      Rect.fromLTWH(backThighX, -P * 10.0, P * 3.1, P * 6.5),
      skinShade,
      0.4,
    );

    final backFootX = -P * 2.8 + legBackOffset * 0.6;
    final backFootY = -P * 4.0 - footLift * 0.5;

    if (isBeach) {
      // Vôlei de praia: pés descalços com tornozeleira esportiva
      drawRounded(
        Rect.fromLTWH(backFootX, backFootY, P * 2.9, P * 2.6),
        skinShade,
        0.3,
      );
      // Tornozeleira / fita de areia
      fillPaint.color = Colors.white;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(backFootX - P * 0.1, backFootY + P * 0.4, P * 3.1, P * 0.9),
          Radius.circular(P * 0.3),
        ),
        fillPaint,
      );
      // Pé descalço apoiado na areia
      drawRounded(
        Rect.fromLTWH(backFootX - P * 0.4, -P * 1.6 - footLift * 0.5, P * 4.4, P * 1.6),
        skinShade,
        0.5,
      );
    } else {
      // Ginásio: Meia branca esportiva
      drawRounded(
        Rect.fromLTWH(backFootX, backFootY, P * 2.9, P * 2.6),
        Colors.white,
        0.3,
      );
      // Listra da meia
      fillPaint.color = trimColor;
      canvas.drawRect(
        Rect.fromLTWH(backFootX, backFootY + P * 0.4, P * 2.9, P * 0.6),
        fillPaint,
      );
      // Tênis traseiro profissional (branco com sola escura de aderência)
      drawRounded(
        Rect.fromLTWH(backFootX - P * 0.6, -P * 1.7 - footLift * 0.5, P * 4.6, P * 2.0),
        Colors.white,
        0.4,
      );
      // Detalhe de cor do time no calcanhar
      fillPaint.color = trimColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(backFootX - P * 0.5, -P * 1.6 - footLift * 0.5, P * 1.2, P * 1.4),
          Radius.circular(P * 0.2),
        ),
        fillPaint,
      );
      // Sola de borracha de alta aderência
      fillPaint.color = const Color(0xFF263238);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(backFootX - P * 0.6, -P * 0.6 - footLift * 0.5, P * 4.6, P * 0.8),
          Radius.circular(P * 0.3),
        ),
        fillPaint,
      );
    }

    // ==========================================
    // 3. PERNA DIANTEIRA (Front Leg)
    // ==========================================
    final frontThighX = P * 0.6 + legFrontOffset * 0.4;
    drawRounded(
      Rect.fromLTWH(frontThighX, -P * 10.0, P * 3.3, P * 6.8),
      skinColor,
      0.4,
    );

    final frontFootX = P * 0.6 + legFrontOffset * 0.6;
    final frontFootY = -P * 4.0 - footLift;

    if (isBeach) {
      // Vôlei de praia: pé dianteiro descalço
      drawRounded(
        Rect.fromLTWH(frontFootX, frontFootY, P * 3.0, P * 2.7),
        skinColor,
        0.3,
      );
      // Tornozeleira branca esportiva
      fillPaint.color = Colors.white;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(frontFootX - P * 0.1, frontFootY + P * 0.4, P * 3.2, P * 0.9),
          Radius.circular(P * 0.3),
        ),
        fillPaint,
      );
      // Pé descalço
      drawRounded(
        Rect.fromLTWH(frontFootX - P * 0.2, -P * 1.6 - footLift, P * 4.8, P * 1.7),
        skinColor,
        0.5,
      );
    } else {
      // Ginásio: Meia branca atlética dianteira
      drawRounded(
        Rect.fromLTWH(frontFootX, frontFootY, P * 3.0, P * 2.8),
        Colors.white,
        0.3,
      );
      // Listra da meia dianteira
      fillPaint.color = trimColor;
      canvas.drawRect(
        Rect.fromLTWH(frontFootX, frontFootY + P * 0.4, P * 3.0, P * 0.7),
        fillPaint,
      );
      // Tênis dianteiro profissional matching com o traseiro
      drawRounded(
        Rect.fromLTWH(frontFootX - P * 0.4, -P * 1.8 - footLift, P * 4.9, P * 2.1),
        Colors.white,
        0.4,
      );
      // Detalhe de cor do time
      fillPaint.color = trimColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(frontFootX - P * 0.3, -P * 1.7 - footLift, P * 1.3, P * 1.5),
          Radius.circular(P * 0.2),
        ),
        fillPaint,
      );
      // Sola de borracha
      fillPaint.color = const Color(0xFF263238);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(frontFootX - P * 0.4, -P * 0.6 - footLift, P * 4.9, P * 0.8),
          Radius.circular(P * 0.3),
        ),
        fillPaint,
      );
    }

    // ==========================================
    // 4. BERMUDA / CALÇÃO (Shorts)
    // ==========================================
    drawRounded(
      Rect.fromLTWH(-P * 3.4, -P * 14.4, P * 7.4, P * 5.2),
      trimColor,
      0.35,
    );

    // Listra atlética na lateral do calção
    fillPaint.color = Colors.white.withValues(alpha: 0.90);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-P * 0.4, -P * 14.1, P * 1.4, P * 4.6),
        Radius.circular(P * 0.4),
      ),
      fillPaint,
    );

    // ==========================================
    // 5. TRONCO E CAMISA (Torso / Jersey em 3/4)
    // ==========================================
    final jerseyRect = Rect.fromLTWH(-P * 3.6, -P * 21.2, P * 7.8, P * 7.6);
    drawRounded(jerseyRect, shirtColor, 0.35);

    // Sombra suave na lateral traseira para volume 3D
    fillPaint.color = shirtShade;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-P * 3.5, -P * 21.0, P * 2.0, P * 7.2),
        Radius.circular(P * 0.35),
      ),
      fillPaint,
    );

    // Barra da camisa
    fillPaint.color = trimColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-P * 3.4, -P * 14.8, P * 7.4, P * 1.3),
        Radius.circular(P * 0.3),
      ),
      fillPaint,
    );

    // Gola da camisa
    drawRounded(
      Rect.fromLTWH(-P * 0.5, -P * 21.4, P * 3.4, P * 1.6),
      trimColor,
      0.5,
    );

    // Número do uniforme (visível no peito / lateral)
    if (jerseyNumber.isNotEmpty) {
      final tpNum = TextPainter(
        text: TextSpan(
          text: jerseyNumber,
          style: TextStyle(
            color: Colors.white,
            fontSize: P * 3.2,
            fontWeight: FontWeight.w900,
            shadows: const [
              Shadow(offset: Offset(1.2, 1.2), color: kOutline),
              Shadow(offset: Offset(-1.2, 1.2), color: kOutline),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tpNum.paint(canvas, Offset(P * 0.2 - tpNum.width / 2, -P * 19.2));
    }

    // ==========================================
    // 6. CABEÇA E ROSTO (Olhando firmemente para a rede / oponente)
    // ==========================================
    // Cabeça desenhada em perfil 3/4 voltada para a direita (+X)
    final headRect = Rect.fromLTWH(-P * 2.5, -P * 27.8, P * 6.4, P * 6.8);
    drawRounded(headRect, skinColor, 0.45);

    // Nariz / queixo esportivo em perfil voltado para a frente
    fillPaint.color = skinColor;
    final nosePath = Path()
      ..moveTo(P * 3.6, -P * 25.2)
      ..lineTo(P * 4.6, -P * 24.0)
      ..lineTo(P * 3.5, -P * 23.2)
      ..close();
    canvas.drawPath(nosePath, fillPaint);
    canvas.drawPath(nosePath, outlinePaint);

    // Queixo e sombra do pescoço
    fillPaint.color = skinShade;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-P * 1.5, -P * 22.0, P * 4.4, P * 1.4),
        Radius.circular(P * 0.4),
      ),
      fillPaint,
    );

    // Faixa esportiva na cabeça (Headband)
    drawRounded(
      Rect.fromLTWH(-P * 2.6, -P * 27.2, P * 6.8, P * 1.8),
      trimColor,
      0.3,
    );

    // Cabelo esportivo volumoso com franja para trás
    drawRounded(
      Rect.fromLTWH(-P * 2.9, -P * 30.0, P * 7.2, P * 3.6),
      hairColor,
      0.5,
    );
    // Mecha de cabelo traseira
    drawRounded(
      Rect.fromLTWH(-P * 3.2, -P * 28.0, P * 2.8, P * 2.4),
      hairColor,
      0.4,
    );

    // OLHO ATLETA: Desenhado próximo à borda frontal da face (+X),
    // fixando o olhar diretamente no adversário e na rede!
    final eyeX = P * 2.2;
    final eyeY = -P * 24.6;

    // Globo ocular atlético
    fillPaint.color = Colors.white;
    final eyeRect = Rect.fromLTWH(eyeX - P * 1.1, eyeY - P * 0.9, P * 2.2, P * 1.8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(eyeRect, Radius.circular(P * 0.5)),
      fillPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(eyeRect, Radius.circular(P * 0.5)),
      outlinePaint,
    );

    // Pupila voltada para a frente (direção da rede/bola)
    fillPaint.color = kOutline;
    canvas.drawCircle(Offset(eyeX + P * 0.4, eyeY), P * 0.65, fillPaint);
    // Brilho no olhar
    fillPaint.color = Colors.white;
    canvas.drawCircle(Offset(eyeX + P * 0.25, eyeY - P * 0.2), P * 0.22, fillPaint);

    // Sobrancelha determinada apontando para a rede
    final browPaint = Paint()
      ..color = hairColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = P * 0.70
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(eyeX - P * 1.2, eyeY - P * 1.5),
      Offset(eyeX + P * 1.2, eyeY - P * 1.2),
      browPaint,
    );

    // ==========================================
    // 7. BRAÇO DIANTEIRO (Front Arm)
    // ==========================================
    if (!armsUp) {
      // Manga dianteira
      drawRounded(
        Rect.fromLTWH(P * 2.2, -P * 20.8, P * 3.2, P * 2.8),
        shirtColor,
        0.4,
      );
      // Braço e antebraço dianteiro (inclinado para a frente, postura de manchete/pronto)
      drawRounded(
        Rect.fromLTWH(P * 2.6, -P * 18.2, P * 3.0, P * 8.6),
        skinColor,
        0.5,
      );
      // Munhequeira atlética
      drawRounded(
        Rect.fromLTWH(P * 2.5, -P * 12.2, P * 3.2, P * 1.6),
        Colors.white,
        0.3,
      );
    } else if (swinging) {
      // Manga
      drawRounded(
        Rect.fromLTWH(P * 1.8, -P * 21.0, P * 3.4, P * 3.0),
        shirtColor,
        0.4,
      );
      // Braço de cortada esticado no alto
      drawRounded(
        Rect.fromLTWH(P * 2.4, -P * 31.8, P * 3.4, P * 12.8),
        skinColor,
        0.45,
      );
      // Mão aberta golpeando a bola
      drawRounded(
        Rect.fromLTWH(P * 2.8, -P * 33.6, P * 4.2, P * 3.0),
        skinColor,
        0.5,
      );
    } else {
      // Braços erguidos para bloqueio / recepção alta
      drawRounded(
        Rect.fromLTWH(P * 1.8, -P * 21.0, P * 3.2, P * 2.8),
        shirtColor,
        0.4,
      );
      drawRounded(
        Rect.fromLTWH(P * 2.4, -P * 30.8, P * 3.0, P * 11.6),
        skinColor,
        0.45,
      );
    }

    canvas.restore();
  }
}
