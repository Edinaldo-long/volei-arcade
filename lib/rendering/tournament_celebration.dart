import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'character_renderer.dart';
import 'flag_renderer.dart';

/// Partícula de confete festivo para a celebração de vitória.
class _CelebrationConfetti {
  final double x;
  final double y;
  final double speed;
  final double swaySpeed;
  final double swayWidth;
  final double size;
  final double rotSpeed;
  final Color color;

  const _CelebrationConfetti({
    required this.x,
    required this.y,
    required this.speed,
    required this.swaySpeed,
    required this.swayWidth,
    required this.size,
    required this.rotSpeed,
    required this.color,
  });
}

/// Widget animado completo para a celebração do time campeão do Torneio.
///
/// Exibe os dois jogadores comemorando e pulando de alegria no pódio,
/// a taça dourada reluzente, a bandeira do país campeão ondulando e
/// uma chuva contínua de confetes e fogos festivos.
class TournamentCelebrationWidget extends StatefulWidget {
  final String championCountry;
  final Color shirtColor;
  final Color trimColor;
  final String rivalCountry;
  final int championScore;
  final int rivalScore;
  final bool isGrandChampion;
  final bool hasNextRound;
  final VoidCallback onNextRound;
  final VoidCallback onPlayAgain;
  final VoidCallback onMenu;
  final bool isBeach;

  const TournamentCelebrationWidget({
    super.key,
    required this.championCountry,
    required this.shirtColor,
    required this.trimColor,
    required this.rivalCountry,
    required this.championScore,
    required this.rivalScore,
    required this.isGrandChampion,
    required this.hasNextRound,
    required this.onNextRound,
    required this.onPlayAgain,
    required this.onMenu,
    this.isBeach = false,
  });

  @override
  State<TournamentCelebrationWidget> createState() => _TournamentCelebrationWidgetState();
}

class _TournamentCelebrationWidgetState extends State<TournamentCelebrationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_CelebrationConfetti> _confettiList;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    final rnd = math.Random(42);
    final colors = [
      const Color(0xFFFFD700), // Ouro
      const Color(0xFFFFEB3B), // Amarelo
      const Color(0xFF00E676), // Verde
      const Color(0xFF00B0FF), // Ciano
      const Color(0xFFFF1744), // Vermelho
      const Color(0xFFFFFFFF), // Branco
      widget.shirtColor,
      widget.trimColor,
    ];

    _confettiList = List.generate(45, (i) {
      return _CelebrationConfetti(
        x: rnd.nextDouble(),
        y: rnd.nextDouble(),
        speed: 0.18 + rnd.nextDouble() * 0.28,
        swaySpeed: 2.0 + rnd.nextDouble() * 4.0,
        swayWidth: 12.0 + rnd.nextDouble() * 18.0,
        size: 4.5 + rnd.nextDouble() * 5.0,
        rotSpeed: 1.5 + rnd.nextDouble() * 4.0,
        color: colors[i % colors.length],
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isGrandChampion
        ? '🏆 CAMPEÃO DO TORNEIO! 🏆'
        : 'VITÓRIA NO TORNEIO! 🎉';

    final subtitle = widget.isGrandChampion
        ? '${widget.championCountry} CONQUISTOU O TÍTULO MÁXIMO!'
        : '${widget.championCountry} AVANÇA PARA A PRÓXIMA FASE!';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final content = isLandscape
            ? _buildLandscape(context, title, subtitle)
            : _buildPortrait(context, title, subtitle);
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: content,
          ),
        );
      },
    );
  }

  Widget _buildLandscape(BuildContext context, String title, String subtitle) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 630, maxHeight: 310),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xEE090D2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700), width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66FFD700),
            blurRadius: 24,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black87,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // LADO ESQUERDO: Título, Bandeira, Placar e Botões de Ação
          Expanded(
            flex: 11,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 1. TÍTULO E SUBTÍTULO
                Column(
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        shadows: [
                          Shadow(offset: Offset(1.5, 1.5), color: Colors.black, blurRadius: 3),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                // 2. BANDEIRA ONDULANTE
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final wave = math.sin(_controller.value * 2 * math.pi * 2) * 2.5;
                    final tilt = math.sin(_controller.value * 2 * math.pi) * 0.03;
                    return Transform.translate(
                      offset: Offset(0, wave),
                      child: Transform.rotate(
                        angle: tilt,
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x77FFD700),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: FlagRenderer.flagWidget(
                            widget.championCountry,
                            width: 58,
                            height: 38,
                            borderRadius: 4.0,
                            border: true,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // 3. PLACAR
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x33000000),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FlagRenderer.flagWidget(widget.championCountry, width: 20, height: 13),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.championCountry} ${widget.championScore}  ×  ${widget.rivalScore} ${widget.rivalCountry}',
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 6),
                        FlagRenderer.flagWidget(widget.rivalCountry, width: 20, height: 13),
                      ],
                    ),
                  ),
                ),

                // 4. BOTÕES DE AÇÃO
                Column(
                  children: [
                    if (widget.hasNextRound)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC107),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          minimumSize: const Size(double.infinity, 36),
                        ),
                        onPressed: widget.onNextRound,
                        icon: const Icon(Icons.arrow_forward, size: 17),
                        label: const Text(
                          'PRÓXIMA PARTIDA',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      )
                    else
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          minimumSize: const Size(double.infinity, 36),
                        ),
                        onPressed: widget.onPlayAgain,
                        icon: const Icon(Icons.emoji_events, size: 17),
                        label: const Text(
                          'JOGAR TORNEIO NOVAMENTE',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 3),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: widget.onMenu,
                      icon: const Icon(Icons.home, size: 16),
                      label: const Text('MENU PRINCIPAL', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // LADO DIREITO: Animação Completa dos Atletas e Pódio
          Expanded(
            flex: 12,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _CelebrationCanvasPainter(
                      progress: _controller.value,
                      confettiList: _confettiList,
                      shirtColor: widget.shirtColor,
                      trimColor: widget.trimColor,
                      championCountry: widget.championCountry,
                      isBeach: widget.isBeach,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortrait(BuildContext context, String title, String subtitle) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 460),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xEE090D2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700), width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66FFD700),
            blurRadius: 28,
            spreadRadius: 3,
          ),
          BoxShadow(
            color: Colors.black87,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. TÍTULO E SUBTÍTULO FESTIVO
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              shadows: [
                Shadow(offset: Offset(2, 2), color: Colors.black, blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(offset: Offset(1, 1), color: Colors.black),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 2. BANDEIRA ONDULANTE GRANDE DO PAÍS CAMPEÃO
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final wave = math.sin(_controller.value * 2 * math.pi * 2) * 3.0;
              final tilt = math.sin(_controller.value * 2 * math.pi) * 0.035;
              return Transform.translate(
                offset: Offset(0, wave),
                child: Transform.rotate(
                  angle: tilt,
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x77FFD700),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: FlagRenderer.flagWidget(
                      widget.championCountry,
                      width: 72,
                      height: 48,
                      borderRadius: 5.0,
                      border: true,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),

          // 3. ANIMAÇÃO DO PÓDIO: ATLETAS COMEMORANDO, TAÇA E CONFETES
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 340,
                height: 180,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _CelebrationCanvasPainter(
                        progress: _controller.value,
                        confettiList: _confettiList,
                        shirtColor: widget.shirtColor,
                        trimColor: widget.trimColor,
                        championCountry: widget.championCountry,
                        isBeach: widget.isBeach,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 4. PLACAR FINAL COM BANDEIRAS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x33000000),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FlagRenderer.flagWidget(widget.championCountry, width: 22, height: 14),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.championCountry} ${widget.championScore}  ×  ${widget.rivalScore} ${widget.rivalCountry}',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FlagRenderer.flagWidget(widget.rivalCountry, width: 22, height: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 5. BOTÕES DE AÇÃO
          if (widget.hasNextRound)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: widget.onNextRound,
              icon: const Icon(Icons.arrow_forward, size: 20),
              label: const Text(
                'PRÓXIMA PARTIDA DO TORNEIO',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
            )
          else
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: widget.onPlayAgain,
              icon: const Icon(Icons.emoji_events, size: 20),
              label: const Text(
                'JOGAR TORNEIO NOVAMENTE',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
          const SizedBox(height: 6),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            onPressed: widget.onMenu,
            icon: const Icon(Icons.home, size: 18),
            label: const Text('MENU PRINCIPAL'),
          ),
        ],
      ),
    );
  }
}

/// Painter Customizado que desenha o fundo com raios dourados, confetes,
/// pódio 3D, taça dourada reluzente e os dois atletas pulando e comemorando.
class _CelebrationCanvasPainter extends CustomPainter {
  final double progress;
  final List<_CelebrationConfetti> confettiList;
  final Color shirtColor;
  final Color trimColor;
  final String championCountry;
  final bool isBeach;

  _CelebrationCanvasPainter({
    required this.progress,
    required this.confettiList,
    required this.shirtColor,
    required this.trimColor,
    required this.championCountry,
    required this.isBeach,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final t = progress * 2 * math.pi;

    // 1. FUNDO COM RAIOS DOURADOS ROTATIVOS (Sunburst)
    final bgPaint = Paint()..style = PaintingStyle.fill;
    bgPaint.color = const Color(0xFF0F174A);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final rayPaint = Paint()
      ..color = const Color(0x18FFD700)
      ..style = PaintingStyle.fill;

    const numRays = 16;
    final rayRot = t * 0.25;
    for (var i = 0; i < numRays; i++) {
      final a1 = rayRot + (i * 2 * math.pi / numRays);
      final a2 = a1 + (math.pi / numRays);
      final path = Path()
        ..moveTo(cx, cy - 10)
        ..lineTo(cx + math.cos(a1) * 350, cy - 10 + math.sin(a1) * 350)
        ..lineTo(cx + math.cos(a2) * 350, cy - 10 + math.sin(a2) * 350)
        ..close();
      canvas.drawPath(path, rayPaint);
    }

    // 2. CHUVA DE CONFETES
    final confPaint = Paint()..style = PaintingStyle.fill;
    for (final c in confettiList) {
      final py = ((c.y + progress * c.speed * 2) % 1.0) * size.height;
      final px = (c.x * size.width) + math.sin(t * c.swaySpeed + c.x * 12) * c.swayWidth;
      final rot = t * c.rotSpeed + c.x;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(rot);
      confPaint.color = c.color;
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: c.size, height: c.size * 0.6),
        confPaint,
      );
      canvas.restore();
    }

    // 3. PÓDIO DA VITÓRIA (Degrau de Campeão #1)
    final podiumPaint = Paint()..style = PaintingStyle.fill;
    final podiumOutline = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF14122B)
      ..strokeWidth = 2.0;

    final podiumRect = Rect.fromLTWH(cx - 75, size.height - 38, 150, 38);
    podiumPaint.color = const Color(0xFFD4AF37);
    canvas.drawRRect(RRect.fromRectAndRadius(podiumRect, const Radius.circular(6)), podiumPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(podiumRect, const Radius.circular(6)), podiumOutline);

    // Destaque superior do pódio
    final topHighlight = Rect.fromLTWH(cx - 73, size.height - 36, 146, 8);
    podiumPaint.color = const Color(0xFFFFE082);
    canvas.drawRRect(RRect.fromRectAndRadius(topHighlight, const Radius.circular(4)), podiumPaint);

    // Texto #1 no pódio
    final tpOne = TextPainter(
      text: const TextSpan(
        text: '★  1º LUGAR  ★',
        style: TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpOne.paint(canvas, Offset(cx - tpOne.width / 2, size.height - 24));

    // 4. ATLETAS CAMPEÕES PULANDO E COMEMORANDO (CharacterRenderer)
    // Atleta 1 (Camisa 1): salta no ritmo da alegria
    final jump1 = (math.sin(t * 3.5).abs() * 20.0);
    final air1 = jump1 > 3.0;

    // Atleta 2 (Camisa 7): salta com defasagem rítmica
    final jump2 = (math.sin(t * 3.5 + 1.2).abs() * 20.0);
    final air2 = jump2 > 3.0;

    const athleteScale = 4.6;
    final groundY = size.height - 38;

    // Jogador 1 (À esquerda, olhando para o centro / troféu com braços erguidos)
    CharacterRenderer.draw(
      canvas: canvas,
      ox: cx - 55,
      oy: groundY - jump1,
      P: athleteScale,
      face: 1.0, // Olhando para a direita
      shirtColor: shirtColor,
      trimColor: trimColor,
      skinColor: const Color(0xFFF0B888),
      hairColor: const Color(0xFF4E342E),
      jerseyNumber: '1',
      armsUp: true,
      swinging: false,
      air: air1,
      moving: true,
      step: air1 ? -2 : 0,
      isBeach: isBeach,
    );

    // Jogador 2 (À direita, olhando para o centro / troféu com braços erguidos)
    CharacterRenderer.draw(
      canvas: canvas,
      ox: cx + 55,
      oy: groundY - jump2,
      P: athleteScale,
      face: -1.0, // Olhando para a esquerda
      shirtColor: shirtColor,
      trimColor: trimColor,
      skinColor: const Color(0xFF9C5B2E),
      hairColor: const Color(0xFF151515),
      jerseyNumber: '7',
      armsUp: true,
      swinging: false,
      air: air2,
      moving: true,
      step: air2 ? -2 : 1,
      isBeach: isBeach,
    );

    // 5. TAÇA DOURADA RELUZENTE NO CENTRO DO PÓDIO
    _drawGoldenTrophy(canvas, Offset(cx, groundY - 2), t);
  }

  /// Desenha a taça de campeão procedural vetorial com ouro reluzente e brilhos.
  void _drawGoldenTrophy(Canvas canvas, Offset basePos, double time) {
    final goldPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF14122B)
      ..strokeWidth = 1.6
      ..isAntiAlias = true;

    final bx = basePos.dx;
    final by = basePos.dy;

    // Base de mármore do troféu
    final marbleRect = Rect.fromCenter(center: Offset(bx, by - 6), width: 34, height: 12);
    goldPaint.color = const Color(0xFF2C2C2C);
    canvas.drawRRect(RRect.fromRectAndRadius(marbleRect, const Radius.circular(2)), goldPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(marbleRect, const Radius.circular(2)), strokePaint);

    // Placa dourada na base
    final plateRect = Rect.fromCenter(center: Offset(bx, by - 6), width: 22, height: 6);
    goldPaint.color = const Color(0xFFFFD700);
    canvas.drawRect(plateRect, goldPaint);

    // Haste do troféu
    final stemPath = Path()
      ..moveTo(bx - 5, by - 12)
      ..lineTo(bx + 5, by - 12)
      ..lineTo(bx + 3, by - 22)
      ..lineTo(bx - 3, by - 22)
      ..close();
    goldPaint.color = const Color(0xFFFFA000);
    canvas.drawPath(stemPath, goldPaint);
    canvas.drawPath(stemPath, strokePaint);

    // Taça / Cálice principal
    final cupPath = Path()
      ..moveTo(bx - 18, by - 44)
      ..lineTo(bx + 18, by - 44)
      ..cubicTo(bx + 17, by - 32, bx + 12, by - 22, bx + 4, by - 22)
      ..lineTo(bx - 4, by - 22)
      ..cubicTo(bx - 12, by - 22, bx - 17, by - 32, bx - 18, by - 44)
      ..close();
    goldPaint.color = const Color(0xFFFFD700);
    canvas.drawPath(cupPath, goldPaint);
    canvas.drawPath(cupPath, strokePaint);

    // Alça esquerda da taça
    final handleL = Path()
      ..moveTo(bx - 16, by - 40)
      ..cubicTo(bx - 26, by - 38, bx - 26, by - 28, bx - 12, by - 28)
      ..lineTo(bx - 10, by - 25)
      ..cubicTo(bx - 29, by - 25, bx - 29, by - 42, bx - 16, by - 42)
      ..close();
    goldPaint.color = const Color(0xFFFFB300);
    canvas.drawPath(handleL, goldPaint);
    canvas.drawPath(handleL, strokePaint);

    // Alça direita da taça
    final handleR = Path()
      ..moveTo(bx + 16, by - 40)
      ..cubicTo(bx + 26, by - 38, bx + 26, by - 28, bx + 12, by - 28)
      ..lineTo(bx + 10, by - 25)
      ..cubicTo(bx + 29, by - 25, bx + 29, by - 42, bx + 16, by - 42)
      ..close();
    goldPaint.color = const Color(0xFFFFB300);
    canvas.drawPath(handleR, goldPaint);
    canvas.drawPath(handleR, strokePaint);

    // Brilho reluzente animado na taça
    final sparklePhase = (time * 3) % (2 * math.pi);
    final sparkleAlpha = (math.sin(sparklePhase).abs()).clamp(0.0, 1.0);
    final sparklePaint = Paint()
      ..color = Colors.white.withValues(alpha: sparkleAlpha)
      ..style = PaintingStyle.fill;

    // Estrela de 4 pontas no topo da taça
    _drawStar4(canvas, Offset(bx + 8, by - 38), 4.5 * sparkleAlpha, sparklePaint);
    _drawStar4(canvas, Offset(bx - 8, by - 30), 3.5 * (1.0 - sparkleAlpha), sparklePaint);
  }

  void _drawStar4(Canvas canvas, Offset pos, double r, Paint p) {
    if (r <= 0.5) return;
    final path = Path()
      ..moveTo(pos.dx, pos.dy - r)
      ..lineTo(pos.dx + r * 0.25, pos.dy - r * 0.25)
      ..lineTo(pos.dx + r, pos.dy)
      ..lineTo(pos.dx + r * 0.25, pos.dy + r * 0.25)
      ..lineTo(pos.dx, pos.dy + r)
      ..lineTo(pos.dx - r * 0.25, pos.dy + r * 0.25)
      ..lineTo(pos.dx - r, pos.dy)
      ..lineTo(pos.dx - r * 0.25, pos.dy - r * 0.25)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _CelebrationCanvasPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
