import 'package:flutter/material.dart';

/// Classificação da qualidade do contato com a bola.
enum TimingRating {
  perfect,
  good,
  early,
  late,
}

/// Resultado detalhado da avaliação mecânica do toque.
class HitEvaluation {
  final TimingRating rating;
  final double speedMultiplier;
  final double topspin;
  final double accuracyFactor;
  final String label;
  final Color color;
  final double hitstopDuration;
  final double shakeTrauma;

  const HitEvaluation({
    required this.rating,
    required this.speedMultiplier,
    required this.topspin,
    required this.accuracyFactor,
    required this.label,
    required this.color,
    required this.hitstopDuration,
    required this.shakeTrauma,
  });

  bool get isPerfect => rating == TimingRating.perfect;
  bool get isGood => rating == TimingRating.good;
}

/// Avaliador de timing e ponto de contato.
class TimingEvaluator {
  /// Avalia um golpe aéreo (cortada / ataque).
  static HitEvaluation evaluateSpike({
    required double ballZ,
    required double playerZ,
    required double playerVz,
    required double dist2D,
  }) {
    // Altura relativa ideal da bola em relação ao jogador para cortada potente
    // O jogador costuma golpear com o braço estendido acima da cabeça (~70 a 85 acima do pé)
    final relativeZ = ballZ - playerZ;
    const optimalRelZ = 76.0;
    final diffZ = (relativeZ - optimalRelZ).abs();

    // No topo do salto, playerVz está próximo de zero (-80 a 80)
    final inPeakJump = playerVz.abs() < 110.0;
    final centered = dist2D < 42.0;

    if (diffZ <= 18.0 && inPeakJump && centered) {
      return const HitEvaluation(
        rating: TimingRating.perfect,
        speedMultiplier: 1.35,
        topspin: 28.0,
        accuracyFactor: 1.0,
        label: 'PERFEITO!',
        color: Color(0xFFFFD600), // Dourado
        hitstopDuration: 0.065,
        shakeTrauma: 0.70,
      );
    }

    if (diffZ <= 36.0 && dist2D < 68.0) {
      return const HitEvaluation(
        rating: TimingRating.good,
        speedMultiplier: 1.05,
        topspin: 16.0,
        accuracyFactor: 0.85,
        label: 'BOM',
        color: Color(0xFF40C4FF), // Ciano
        hitstopDuration: 0.040,
        shakeTrauma: 0.38,
      );
    }

    if (playerVz > 110.0 || relativeZ > optimalRelZ) {
      return const HitEvaluation(
        rating: TimingRating.early,
        speedMultiplier: 0.78,
        topspin: 6.0,
        accuracyFactor: 0.50,
        label: 'CEDO',
        color: Color(0xFFFF9100), // Laranja
        hitstopDuration: 0.0,
        shakeTrauma: 0.18,
      );
    }

    return const HitEvaluation(
      rating: TimingRating.late,
      speedMultiplier: 0.72,
      topspin: 4.0,
      accuracyFactor: 0.45,
      label: 'TARDE',
      color: Color(0xFFFF5252), // Vermelho claro
      hitstopDuration: 0.0,
      shakeTrauma: 0.18,
    );
  }

  /// Avalia um toque no chão (manchete de recepção ou levantamento).
  static HitEvaluation evaluateGroundTouch({
    required double dist2D,
    required int touchIndex, // 0 = recepção, 1 = levantamento
  }) {
    if (dist2D < 32.0) {
      return HitEvaluation(
        rating: TimingRating.perfect,
        speedMultiplier: 1.0,
        topspin: 0.0,
        accuracyFactor: 1.0,
        label: touchIndex == 0 ? 'RECEPÇÃO PERFEITA!' : 'LEVANTAMENTO PERFEITO!',
        color: const Color(0xFFFFD600),
        hitstopDuration: 0.0,
        shakeTrauma: 0.10,
      );
    }

    if (dist2D < 65.0) {
      return HitEvaluation(
        rating: TimingRating.good,
        speedMultiplier: 0.95,
        topspin: 0.0,
        accuracyFactor: 0.85,
        label: touchIndex == 0 ? 'BOM PASSE' : 'BOM LEVANTAMENTO',
        color: const Color(0xFF40C4FF),
        hitstopDuration: 0.0,
        shakeTrauma: 0.05,
      );
    }

    return HitEvaluation(
      rating: TimingRating.late,
      speedMultiplier: 0.80,
      topspin: 0.0,
      accuracyFactor: 0.55,
      label: 'DIFÍCIL',
      color: const Color(0xFFFF9100),
      hitstopDuration: 0.0,
      shakeTrauma: 0.05,
    );
  }

  /// Avalia um bloqueio sincronizado na rede.
  static HitEvaluation evaluateBlock({
    required double ballSpeed,
    required double playerZ,
    required double ballZ,
  }) {
    final diffZ = (ballZ - (playerZ + 60)).abs();
    if (diffZ < 25.0) {
      return const HitEvaluation(
        rating: TimingRating.perfect,
        speedMultiplier: 1.2,
        topspin: -15.0,
        accuracyFactor: 1.0,
        label: 'SUPER BLOQUEIO!',
        color: Color(0xFFFFD600),
        hitstopDuration: 0.060,
        shakeTrauma: 0.65,
      );
    }

    return const HitEvaluation(
      rating: TimingRating.good,
      speedMultiplier: 1.0,
      topspin: -8.0,
      accuracyFactor: 0.85,
      label: 'BLOQUEIO!',
      color: Color(0xFF40C4FF),
      hitstopDuration: 0.040,
      shakeTrauma: 0.40,
    );
  }
}
