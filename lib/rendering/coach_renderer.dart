import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Renderizador estilizado do Treinador ("Prof. Silva") à beira da quadra.
///
/// Desenha o treinador com agasalho esportivo, boné retrô, apito e prancheta tática.
class CoachRenderer {
  static const Color kOutline = Color(0xFF14122B);

  static void draw({
    required Canvas canvas,
    required double x,
    required double y,
    required double scale,
    double animTimer = 0.0,
    bool whistling = false,
    bool cheering = false,
    String? speechText,
  }) {
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(scale, scale);

    final outline = Paint()
      ..color = kOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, scale * 1.6)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final fill = Paint()..style = PaintingStyle.fill..isAntiAlias = true;

    void rrect(Rect r, Color c, [double radius = 4.0]) {
      final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
      fill.color = c;
      canvas.drawRRect(rr, fill);
      canvas.drawRRect(rr, outline);
    }

    // 1. Sombra projetada no chão
    fill.color = const Color(0x55000000);
    canvas.drawOval(const Rect.fromLTWH(-20, 84, 40, 12), fill);

    // Movimento sutil de respiração / idle
    final bob = math.sin(animTimer * 3.0) * 1.5;

    // 2. Pernas e Calça Esportiva (Azul Marinho com faixa lateral branca)
    // Perna esquerda
    rrect(const Rect.fromLTWH(-13, 48, 10, 36), const Color(0xFF1A237E), 3.0);
    // Perna direita
    rrect(const Rect.fromLTWH(3, 48, 10, 36), const Color(0xFF1A237E), 3.0);

    // Listras brancas laterais da calça esportiva
    final stripePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawRect(const Rect.fromLTWH(-13, 50, 2.5, 32), stripePaint);
    canvas.drawRect(const Rect.fromLTWH(10.5, 50, 2.5, 32), stripePaint);

    // Sapatos / Tênis de Treinador (Branco com detalhes pretos)
    rrect(const Rect.fromLTWH(-15, 80, 13, 8), Colors.white, 3.0);
    rrect(const Rect.fromLTWH(2, 80, 13, 8), Colors.white, 3.0);
    fill.color = Colors.black87;
    canvas.drawRect(const Rect.fromLTWH(-15, 85, 13, 3), fill);
    canvas.drawRect(const Rect.fromLTWH(2, 85, 13, 3), fill);

    // 3. Tronco e Jaqueta Esportiva do Treinador (Azul Royal + Amarelo Dourado)
    final bodyTop = 18.0 + bob;
    rrect(Rect.fromLTWH(-16, bodyTop, 32, 34), const Color(0xFF0D47A1), 5.0);

    // Zíper e gola esportiva
    fill.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(-1.5, bodyTop + 4, 3, 30), fill);
    // Faixa amarela no peito
    fill.color = const Color(0xFFFFD600);
    canvas.drawRect(Rect.fromLTWH(-16, bodyTop + 14, 32, 6), fill);

    // Crachá / Apito no peito
    fill.color = const Color(0xFFFFC107);
    canvas.drawCircle(Offset(0, bodyTop + 10), 3.5, fill);
    canvas.drawCircle(Offset(0, bodyTop + 10), 3.5, outline);
    final cordPaint = Paint()..color = Colors.white70..strokeWidth = 1.2..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, bodyTop + 2), Offset(0, bodyTop + 7), cordPaint);

    // 4. Cabeça e Rosto
    final headTop = -4.0 + bob;
    // Pescoço
    rrect(Rect.fromLTWH(-5, headTop + 16, 10, 8), const Color(0xFFE0A97A), 2.0);
    // Rosto
    rrect(Rect.fromLTWH(-11, headTop, 22, 20), const Color(0xFFF2C299), 5.0);

    // Olhos e Sobrancelhas atentas
    fill.color = Colors.black87;
    canvas.drawCircle(Offset(-4, headTop + 9), 1.8, fill);
    canvas.drawCircle(Offset(5, headTop + 9), 1.8, fill);
    final browPaint = Paint()..color = const Color(0xFF3E2723)..strokeWidth = 1.4..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(-7, headTop + 6), Offset(-2, headTop + 7), browPaint);
    canvas.drawLine(Offset(3, headTop + 7), Offset(8, headTop + 6), browPaint);

    // Bigode clássico de treinador experiente
    final mustache = Path()
      ..moveTo(-5, headTop + 14)
      ..quadraticBezierTo(0, headTop + 12, 5, headTop + 14)
      ..lineTo(0, headTop + 15)
      ..close();
    fill.color = const Color(0xFF4E342E);
    canvas.drawPath(mustache, fill);

    // 5. Boné Esportivo de Treinador (Azul Royal com Aba Amarela)
    rrect(Rect.fromLTWH(-13, headTop - 7, 26, 11), const Color(0xFF0D47A1), 5.0);
    // Aba do boné
    rrect(Rect.fromLTWH(-15, headTop + 1, 30, 4), const Color(0xFFFFD600), 2.0);

    // 6. Braços e Itens (Prancheta tática e gesticulação)
    if (cheering) {
      // Dois braços para o alto vibrando
      rrect(Rect.fromLTWH(-24, bodyTop - 12, 9, 28), const Color(0xFF0D47A1), 4.0);
      rrect(Rect.fromLTWH(15, bodyTop - 12, 9, 28), const Color(0xFF0D47A1), 4.0);
      rrect(Rect.fromLTWH(-25, bodyTop - 18, 11, 10), const Color(0xFFF2C299), 3.0);
      rrect(Rect.fromLTWH(14, bodyTop - 18, 11, 10), const Color(0xFFF2C299), 3.0);
    } else if (whistling) {
      // Mão segurando o apito na boca
      rrect(Rect.fromLTWH(10, bodyTop + 2, 10, 22), const Color(0xFF0D47A1), 4.0);
      rrect(Rect.fromLTWH(2, bodyTop + 6, 12, 10), const Color(0xFFF2C299), 3.0);
      // Apito apitando
      fill.color = const Color(0xFFFFD600);
      canvas.drawRect(Rect.fromLTWH(-2, headTop + 12, 7, 5), fill);
      canvas.drawRect(Rect.fromLTWH(-2, headTop + 12, 7, 5), outline);
      // Ondas de som do apito
      final wavePaint = Paint()
        ..color = Colors.amber
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawArc(Rect.fromCircle(center: Offset(10, headTop + 14), radius: 8), -math.pi * 0.4, math.pi * 0.8, false, wavePaint);
      canvas.drawArc(Rect.fromCircle(center: Offset(10, headTop + 14), radius: 14), -math.pi * 0.4, math.pi * 0.8, false, wavePaint);
    } else {
      // Braço esquerdo segurando prancheta tática
      rrect(Rect.fromLTWH(-22, bodyTop + 4, 10, 24), const Color(0xFF0D47A1), 4.0);
      // Prancheta de treinador (madeira com folhas e clipe dourado)
      rrect(Rect.fromLTWH(-30, bodyTop + 12, 16, 24), const Color(0xFF8D6E63), 2.0);
      fill.color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(-28, bodyTop + 15, 12, 19), fill);
      // Desenho da quadra tática na folha da prancheta
      final courtLinePaint = Paint()..color = const Color(0xFFE53935)..strokeWidth = 1.0..style = PaintingStyle.stroke;
      canvas.drawRect(Rect.fromLTWH(-27, bodyTop + 17, 10, 15), courtLinePaint);
      canvas.drawLine(Offset(-27, bodyTop + 24.5), Offset(-17, bodyTop + 24.5), courtLinePaint);
      // Clipe da prancheta
      fill.color = const Color(0xFFFFD600);
      canvas.drawRect(Rect.fromLTWH(-24, bodyTop + 12, 6, 3), fill);

      // Braço direito apontando ou ao lado
      rrect(Rect.fromLTWH(13, bodyTop + 4, 9, 24), const Color(0xFF0D47A1), 4.0);
      rrect(Rect.fromLTWH(13, bodyTop + 25, 9, 8), const Color(0xFFF2C299), 3.0);
    }

    // 7. Indicador animado de fala do Treinador sobre a cabeça
    if (speechText != null && speechText.isNotEmpty) {
      _drawCoachSpeechIndicator(canvas, animTimer);
    }

    canvas.restore();
  }

  static void _drawCoachSpeechIndicator(Canvas canvas, double animTimer) {
    // Balão de fala cartunesco saltitante acima da cabeça do treinador indicando fala ativa
    final bounce = math.sin(animTimer * 5.0) * 2.5;
    const bubbleX = -18.0;
    final bubbleY = -34.0 + bounce;
    const bubbleW = 36.0;
    const bubbleH = 20.0;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bubbleX, bubbleY, bubbleW, bubbleH),
      const Radius.circular(8),
    );

    // Sombra
    final shadow = Paint()..color = const Color(0x55000000);
    canvas.drawRRect(rrect.shift(const Offset(2, 2)), shadow);

    // Fundo amarelo arcade brilhante com contorno forte
    final fill = Paint()..color = const Color(0xFFFFD54F);
    final outline = Paint()
      ..color = kOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(rrect, fill);
    canvas.drawRRect(rrect, outline);

    // Rabicho do balão apontando para a cabeça
    final tail = Path()
      ..moveTo(0, bubbleY + bubbleH)
      ..lineTo(-3, bubbleY + bubbleH + 6)
      ..lineTo(5, bubbleY + bubbleH)
      ..close();
    canvas.drawPath(tail, fill);
    canvas.drawPath(tail, outline);

    // Reticências animadas "..." dentro do balão
    final dotPaint = Paint()..color = const Color(0xFF0D47A1);
    canvas.drawCircle(Offset(-8, bubbleY + 10), 2.2, dotPaint);
    canvas.drawCircle(Offset(0, bubbleY + 10), 2.2, dotPaint);
    canvas.drawCircle(Offset(8, bubbleY + 10), 2.2, dotPaint);
  }

  /// Desenha o avatar / busto vetorial estilizado do Treinador Silva em qualquer tamanho.
  static void drawAvatar(Canvas canvas, Size size) {
    final s = size.width / 44.0;
    canvas.save();
    canvas.scale(s, s);

    final outline = Paint()
      ..color = kOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()..style = PaintingStyle.fill;

    // Fundo do círculo
    fill.color = const Color(0xFF0D47A1);
    canvas.drawCircle(const Offset(22, 22), 21, fill);

    // Ombro e Jaqueta
    fill.color = const Color(0xFF1565C0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(6, 30, 32, 20), const Radius.circular(8)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(6, 30, 32, 20), const Radius.circular(8)),
      outline,
    );
    // Faixa amarela do peito
    fill.color = const Color(0xFFFFD600);
    canvas.drawRect(const Rect.fromLTWH(6, 33, 32, 4), fill);

    // Pescoço
    fill.color = const Color(0xFFE0A97A);
    canvas.drawRect(const Rect.fromLTWH(18, 25, 8, 7), fill);

    // Rosto
    fill.color = const Color(0xFFF2C299);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(12, 12, 20, 16), const Radius.circular(4)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(12, 12, 20, 16), const Radius.circular(4)),
      outline,
    );

    // Olhos atentos
    fill.color = Colors.black87;
    canvas.drawCircle(const Offset(17, 19), 1.6, fill);
    canvas.drawCircle(const Offset(27, 19), 1.6, fill);

    // Bigode
    final mustache = Path()
      ..moveTo(17, 24)
      ..quadraticBezierTo(22, 22, 27, 24)
      ..lineTo(22, 25.5)
      ..close();
    fill.color = const Color(0xFF4E342E);
    canvas.drawPath(mustache, fill);

    // Boné com aba amarela
    fill.color = const Color(0xFF0D47A1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(10, 6, 24, 9), const Radius.circular(4)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(10, 6, 24, 9), const Radius.circular(4)),
      outline,
    );
    // Aba do boné
    fill.color = const Color(0xFFFFD600);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(8, 12, 28, 3.5), const Radius.circular(1.5)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(8, 12, 28, 3.5), const Radius.circular(1.5)),
      outline,
    );

    // Apito dourado no pescoço
    fill.color = const Color(0xFFFFD700);
    canvas.drawCircle(const Offset(22, 31), 2.5, fill);
    canvas.drawCircle(const Offset(22, 31), 2.5, outline);

    // Borda do círculo
    canvas.drawCircle(const Offset(22, 22), 21, outline);

    canvas.restore();
  }
}

/// Widget Flutter para exibir o avatar estilizado do Treinador Silva.
class CoachAvatarWidget extends StatelessWidget {
  final double size;
  const CoachAvatarWidget({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFD54F), width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 2)),
        ],
      ),
      child: ClipOval(
        child: CustomPaint(
          size: Size(size, size),
          painter: _CoachAvatarPainter(),
        ),
      ),
    );
  }
}

class _CoachAvatarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    CoachRenderer.drawAvatar(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
