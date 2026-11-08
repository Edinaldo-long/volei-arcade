import 'dart:math' as math;
import 'package:flutter/material.dart';

enum TrainingDrill {
  serve,      // 0: Saque Viagem & Flutuante
  reception,  // 1: Recepção / Manchete
  setting,    // 2: Levantamento na Rede
  spike,      // 3: Cortada no Ápice (Timing Master)
  block,      // 4: Bloqueio na Rede (Monster Block)
  freeRally,  // 5: Jogo-Treino Livre
}

class TrainingTarget {
  final Rect rect; // coordenadas da quadra (gx, gy)
  final int points;
  final String label;
  final Color color;

  TrainingTarget({
    required this.rect,
    required this.points,
    required this.label,
    required this.color,
  });
}

/// Controlador do Modo de Treino com o Treinador ("Prof. Silva").
class TrainingController {
  TrainingDrill currentDrill = TrainingDrill.serve;
  int drillIndex = 0;

  int attempts = 0;
  int successes = 0;
  int totalScore = 0;

  double coachAnimTimer = 0.0;
  bool coachWhistling = false;
  bool coachCheering = false;
  double _whistleTimer = 0.0;
  double _cheerTimer = 0.0;

  static const List<String> drillTitles = [
    '1. SAQUE',
    '2. RECEPÇÃO',
    '3. LEVANTAMENTO',
    '4. CORTADA',
    '5. BLOQUEIO',
    '6. JOGO LIVRE',
  ];

  static const List<String> drillFullTitles = [
    '1. SAQUE VIAGEM & FLUTUANTE',
    '2. RECEPÇÃO & MANCHETE',
    '3. LEVANTAMENTO PRECISO',
    '4. CORTADA NO ÁPICE',
    '5. MONSTER BLOCK',
    '6. JOGO-TREINO LIVRE',
  ];

  static const List<String> drillDescriptions = [
    'Lance a bola no ar (ESPAÇO/A), corra, salte e corte mirando nos alvos da quadra adversária!',
    'Acompanhe a sombra da bola no chão! Posicione seu jogador exatamente embaixo da sombra para fazer a recepção perfeita!',
    'Receba a bola e faça um levantamento suave em parábola alta rente à rede para armar o ataque!',
    'Espere o levantamento, salte no momento exato e aperte Bater no ponto mais alto para uma cortada indefensável!',
    'Acompanhe o ataque adversário na rede e salte junto para formar o paredão de bloqueio!',
    'Troca de bolas contínua com seu parceiro e adversário. Aplique todas as jogadas aprendidas!',
  ];

  static String drillTip(int idx) => '${drillFullTitles[idx]}: ${drillDescriptions[idx]}';

  String coachMessage = drillTip(0);
  double coachMessageTimer = 6.5;
  final ValueNotifier<String?> coachSpeechNotifier = ValueNotifier<String?>(drillTip(0));

  // Alvos na quadra para o exercício atual
  final List<TrainingTarget> targets = [];

  // Modo Demonstração / Vídeo Interativo (Replay do Lance Perfeito)
  bool isDemo = false;
  double demoTimer = 0.0;
  String demoCaption = '';
  final ValueNotifier<bool> isDemoNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> demoCaptionNotifier = ValueNotifier<String>('');

  int get accuracy => attempts > 0 ? ((successes / attempts) * 100).round() : 100;

  String get rankLetter {
    if (attempts == 0) return 'S';
    final acc = accuracy;
    if (acc >= 85) return 'S';
    if (acc >= 70) return 'A';
    if (acc >= 50) return 'B';
    return 'C';
  }

  String get rankTitle {
    switch (rankLetter) {
      case 'S':
        return 'MESTRE 🏆';
      case 'A':
        return 'EXCELENTE 🥇';
      case 'B':
        return 'BOM 🥈';
      default:
        return 'EM TREINO 🥉';
    }
  }

  TrainingController() {
    _setupCurrentDrill();
  }

  void startDemo() {
    isDemo = true;
    demoTimer = 0.0;
    demoCaption = 'Iniciando demonstração da jogada pelo Treinador...';
    demoCaptionNotifier.value = demoCaption;
    isDemoNotifier.value = true;
    triggerWhistle();
  }

  void stopDemo() {
    isDemo = false;
    demoTimer = 0.0;
    demoCaption = '';
    demoCaptionNotifier.value = '';
    isDemoNotifier.value = false;
  }

  void setDemoCaption(String caption) {
    demoCaption = caption;
    demoCaptionNotifier.value = caption;
  }

  void update(double dt) {
    coachAnimTimer += dt;
    if (isDemo) {
      demoTimer += dt;
    }
    if (_whistleTimer > 0) {
      _whistleTimer -= dt;
      if (_whistleTimer <= 0) coachWhistling = false;
    }
    if (_cheerTimer > 0) {
      _cheerTimer -= dt;
      if (_cheerTimer <= 0) coachCheering = false;
    }
    if (coachMessageTimer > 0) {
      coachMessageTimer -= dt;
      if (coachMessageTimer <= 0) {
        coachSpeechNotifier.value = null;
      }
    }
  }

  void setDrill(int index) {
    drillIndex = index.clamp(0, TrainingDrill.values.length - 1);
    currentDrill = TrainingDrill.values[drillIndex];
    attempts = 0;
    successes = 0;
    _setupCurrentDrill();
    triggerWhistle();
    setCoachMessage(drillTip(drillIndex), duration: 6.5);
  }

  void nextDrill() {
    setDrill((drillIndex + 1) % TrainingDrill.values.length);
  }

  void prevDrill() {
    setDrill((drillIndex - 1 + TrainingDrill.values.length) % TrainingDrill.values.length);
  }

  void repeatCurrentDrillTip() {
    triggerWhistle();
    setCoachMessage(drillTip(drillIndex), duration: 6.5);
  }

  void triggerWhistle() {
    coachWhistling = true;
    _whistleTimer = 0.9;
  }

  void triggerCheer() {
    coachCheering = true;
    _cheerTimer = 1.6;
  }

  void setCoachMessage(String msg, {double duration = 4.0}) {
    coachMessage = msg;
    coachMessageTimer = duration;
    coachSpeechNotifier.value = msg;
  }

  void clearCoachMessage() {
    coachMessageTimer = 0.0;
    coachSpeechNotifier.value = null;
  }

  void _setupCurrentDrill() {
    targets.clear();
    switch (currentDrill) {
      case TrainingDrill.serve:
        // Alvos na quadra adversária (gx: 450..900, gy: 0..430)
        targets.add(TrainingTarget(
          rect: const Rect.fromLTRB(760, 40, 880, 190),
          points: 150,
          label: 'FUNDO (150 pts)',
          color: const Color(0xFFFF5252),
        ));
        targets.add(TrainingTarget(
          rect: const Rect.fromLTRB(760, 240, 880, 390),
          points: 150,
          label: 'FUNDO (150 pts)',
          color: const Color(0xFFFF5252),
        ));
        targets.add(TrainingTarget(
          rect: const Rect.fromLTRB(540, 110, 720, 320),
          points: 100,
          label: 'CENTRO (100 pts)',
          color: const Color(0xFFFFD740),
        ));
        targets.add(TrainingTarget(
          rect: const Rect.fromLTRB(470, 30, 560, 180),
          points: 120,
          label: 'PARALELA (120 pts)',
          color: const Color(0xFF69F0AE),
        ));
        break;

      case TrainingDrill.spike:
        // Alvos para treinar cortadas diagonais e paralelas
        targets.add(TrainingTarget(
          rect: const Rect.fromLTRB(480, 260, 680, 410),
          points: 200,
          label: 'DIAGONAL CURTA (200 pts)',
          color: const Color(0xFFFF4081),
        ));
        targets.add(TrainingTarget(
          rect: const Rect.fromLTRB(720, 50, 880, 220),
          points: 180,
          label: 'PARALELA FUNDO (180 pts)',
          color: const Color(0xFF40C4FF),
        ));
        break;

      default:
        break;
    }
  }

  /// Avalia onde a bola caiu e gera feedback do treinador.
  int evaluateBallLanding(double gx, double gy, {double speed = 0.0}) {
    attempts++;
    var earned = 0;
    TrainingTarget? hitTarget;

    for (final t in targets) {
      if (t.rect.contains(Offset(gx, gy))) {
        hitTarget = t;
        earned = t.points;
        break;
      }
    }

    if (earned > 0) {
      successes++;
      totalScore += earned;
      triggerCheer();
      final speedKmh = (speed * 0.16).round();
      setCoachMessage(
        '🎯 EXCELENTE! Acertou o alvo ${hitTarget!.label} a ${speedKmh > 0 ? '$speedKmh km/h!' : '!'}',
        duration: 3.2,
      );
    } else if (gx >= 450 && gx <= 900 && gy >= 0 && gy <= 430) {
      successes++;
      totalScore += 50;
      setCoachMessage('Boa bola dentro! Tente agora mirar nas áreas destacadas.', duration: 2.8);
    } else {
      setCoachMessage('Bola fora! Regule a força e a direção com o analógico.', duration: 2.8);
    }

    return earned;
  }

  /// Feedback para cortada no ápice
  void onSpikeEvaluated(String rating, double jumpHeightRatio) {
    attempts++;
    if (rating == 'PERFEITO') {
      successes++;
      totalScore += 200;
      triggerCheer();
      setCoachMessage('🔥 CORTADA PERFEITA! (+200 pts) Impacto no ápice do salto!', duration: 3.5);
    } else if (rating == 'BOM') {
      successes++;
      totalScore += 100;
      setCoachMessage('Bom ataque! (+100 pts) Salte um instante antes para cortar no ápice.', duration: 3.5);
    } else {
      setCoachMessage('Atrasou ou antecipou o salto. Entre no anel e salte junto com a bola!', duration: 3.5);
    }
  }

  /// Feedback para bloqueio
  void onBlockEvaluated(bool success) {
    attempts++;
    if (success) {
      successes++;
      totalScore += 150;
      triggerCheer();
      setCoachMessage('🧱 MONSTER BLOCK! Parede intransponível!', duration: 3.0);
    } else {
      setCoachMessage('Suba junto com o braço do atacante para fechar o ângulo!', duration: 2.8);
    }
  }

  /// Desenha alvos visuais do treino no chão da quadra
  void drawCourtTargets({
    required Canvas canvas,
    required double Function(double gx, double gy) sx,
    required double Function(double gy, double gz) sy,
  }) {
    if (targets.isEmpty) return;

    for (final t in targets) {
      final r = t.rect;
      final p1 = Offset(sx(r.left, r.top), sy(r.top, 0));
      final p2 = Offset(sx(r.right, r.top), sy(r.top, 0));
      final p3 = Offset(sx(r.right, r.bottom), sy(r.bottom, 0));
      final p4 = Offset(sx(r.left, r.bottom), sy(r.bottom, 0));

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..lineTo(p4.dx, p4.dy)
        ..close();

      // Preenchimento semitransparente brilhante
      final fill = Paint()
        ..color = t.color.withValues(alpha: 0.35 + 0.12 * math.sin(coachAnimTimer * 4.0))
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawPath(path, fill);

      // Borda pulsante
      final border = Paint()
        ..color = t.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..isAntiAlias = true;
      canvas.drawPath(path, border);

      // Texto do alvo
      final centerScreen = Offset(
        (p1.dx + p2.dx + p3.dx + p4.dx) / 4,
        (p1.dy + p2.dy + p3.dy + p4.dy) / 4,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: t.label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            shadows: const [
              Shadow(offset: Offset(1, 1), color: Colors.black),
              Shadow(offset: Offset(-1, 1), color: Colors.black),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, centerScreen - Offset(tp.width / 2, tp.height / 2));
    }
  }
}
