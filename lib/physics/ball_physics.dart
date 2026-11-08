import 'dart:math' as math;

/// Estado físico da bola no espaço pseudo-3D da quadra.
class BallPhysicsState {
  double x = 450.0;
  double y = 215.0;
  double z = 80.0;
  double vx = 0.0;
  double vy = 0.0;
  double vz = 0.0;

  /// Rotação angular em torno do eixo Y (topspin > 0 inclina a trajetória para baixo em direção ao adversário).
  double topspin = 0.0;

  /// Ângulo visual da bola para rotação do sprite.
  double angle = 0.0;

  /// Temporizador de invulnerabilidade/cooldown do bloqueio.
  double blockCd = 0.0;

  /// Lado atual da quadra (0 = esquerda/Brasil, 1 = direita/Adversário).
  int side = 0;

  /// Último time a tocar na bola.
  int lastTeam = 0;

  /// Indica se a bola está em movimento de ataque/saque em direção ao outro lado.
  bool outgoing = false;

  /// Indica se a bola está presa nas mãos do sacador.
  bool held = true;

  /// Velocidade linear escalar total.
  double get speed => math.sqrt(vx * vx + vy * vy + vz * vz);

  /// Velocidade horizontal (plano do chão).
  double get speed2D => math.sqrt(vx * vx + vy * vy);
}

/// Resultado de uma predição balística futura.
class BallPrediction {
  final double x;
  final double y;
  final double t;

  const BallPrediction(this.x, this.y, this.t);
}

/// Motor de simulação física da bola com gravidade, arrasto e efeito Magnus.
class BallPhysicsEngine {
  /// Gravidade vertical calibrada para dinamismo esportivo arcade.
  static const double kG = 960.0;

  /// Raio físico da bola.
  static const double kBR = 13.0;

  /// Altura regulamentar da fita da rede.
  static const double kNetH = 130.0;

  /// Posição X da rede no centro da quadra.
  static const double kNetX = 450.0;

  /// Comprimento total da quadra em X.
  static const double kCourtL = 900.0;

  /// Profundidade total da quadra em Y.
  static const double kCourtWd = 430.0;

  /// Coeficiente de arrasto aerodinâmico.
  static const double kAirDrag = 0.00016;

  /// Coeficiente do efeito Magnus (topspin).
  static const double kMagnus = 0.0016;

  /// Coeficiente de restituição vertical ao quicar no chão.
  static const double kBounceRestitutionZ = 0.52;

  /// Fricção tangencial ao tocar o solo.
  static const double kGroundFriction = 0.82;

  /// Integra um sub-passo da simulação física da bola.
  static void step(
    BallPhysicsState ball,
    double dt, {
    void Function(bool isTape)? onNetCollision,
    void Function(double impactVelocity)? onGroundCollision,
  }) {
    final prevX = ball.x;
    final speed = ball.speed;

    // 1. Força de arrasto aerodinâmico (oposta ao vetor de velocidade)
    final dragAccX = -kAirDrag * speed * ball.vx;
    final dragAccY = -kAirDrag * speed * ball.vy;
    final dragAccZ = -kAirDrag * speed * ball.vz;

    // 2. Efeito Magnus (Topspin ao redor do eixo Y)
    // Se a bola viaja para a direita (vx > 0) e tem topspin > 0, sofre aceleração para baixo (-Z).
    // Se viaja para a esquerda (vx < 0) e tem topspin < 0 (em direção à esquerda), também sofre aceleração para baixo (-Z).
    final magnusAccZ = -kMagnus * ball.topspin * ball.vx;
    final magnusAccX = kMagnus * ball.topspin * ball.vz;

    // 3. Atualização das velocidades com sub-passo
    ball.vx += (dragAccX + magnusAccX) * dt;
    ball.vy += dragAccY * dt;
    ball.vz += (-kG + dragAccZ + magnusAccZ) * dt;

    // 4. Integração das posições
    ball.x += ball.vx * dt;
    ball.y += ball.vy * dt;
    ball.z += ball.vz * dt;

    // 5. Rotação visual e decaimento natural do topspin
    ball.angle += (ball.vx * 0.025 + ball.topspin * 0.08) * dt;
    ball.topspin *= math.max(0.0, 1.0 - 0.45 * dt);

    if (ball.blockCd > 0) {
      ball.blockCd = math.max(0.0, ball.blockCd - dt);
    }

    // 6. Colisão com a Rede
    if (ball.y >= -6.0 &&
        ball.y <= kCourtWd + 6.0 &&
        (prevX < kNetX) != (ball.x < kNetX)) {
      // Se estiver abaixo ou na fita da rede
      if (ball.z - kBR * 0.3 < kNetH) {
        // Efeito "Fita": raspou na borda superior da fita
        final isTape = ball.z >= kNetH - 12.0 && ball.vz > -180;
        if (isTape) {
          // A bola amortece, perde velocidade X mas pode cair do outro lado
          ball.vx *= 0.35;
          ball.vy *= 0.70;
          ball.vz = math.max(30.0, ball.vz * 0.5);
          onNetCollision?.call(true);
        } else {
          // Bateu em cheio na rede: ricocheteia para trás
          ball.x = prevX;
          ball.vx = -ball.vx * 0.32;
          ball.vy *= 0.60;
          ball.vz *= 0.65;
          ball.topspin = 0.0;
          ball.outgoing = false;
          onNetCollision?.call(false);
        }
      }
    }

    // 7. Colisão com o Chão
    if (ball.z - kBR <= 0.0) {
      final impactSpeed = ball.vz.abs();
      ball.z = kBR;
      ball.vz = -ball.vz * kBounceRestitutionZ;
      ball.vx *= kGroundFriction;
      ball.vy *= kGroundFriction;
      ball.topspin = 0.0;

      if (ball.vz.abs() < 65.0) {
        ball.vz = 0.0;
      }

      onGroundCollision?.call(impactSpeed);
    }
  }

  /// Lança a bola até um destino parabólico suave (passes e levantamentos).
  static void launchTo(
    BallPhysicsState ball, {
    required double tx,
    required double ty,
    required double tz,
    required double apexZ,
    double topspin = 0.0,
  }) {
    final apex = math.max(apexZ, math.max(ball.z, tz) + 25.0);
    final vz0 = math.sqrt(2 * kG * (apex - ball.z));
    final tUp = vz0 / kG;
    final tDown = math.sqrt(2 * (apex - tz) / kG);
    final tt = math.max(0.1, tUp + tDown);

    ball.vz = vz0;
    ball.vx = ((tx - ball.x) / tt).clamp(-850.0, 850.0);
    ball.vy = ((ty - ball.y) / tt).clamp(-650.0, 650.0);
    ball.topspin = topspin;
  }

  /// Lançamento rápido de ataque/cortada, calibrado para passar pela rede com topspin agressivo.
  static void launchFast(
    BallPhysicsState ball, {
    required double tx,
    required double ty,
    required double tz,
    double topspin = 22.0,
    double speedMultiplier = 1.0,
  }) {
    double tt = 0.40 / speedMultiplier;
    tt = tt.clamp(0.28, 0.75);

    // Ajusta o tempo de voo mínimo para certificar que passa a fita com folga
    for (; tt <= 0.95; tt += 0.04) {
      final vz = (tz - ball.z + 0.5 * kG * tt * tt) / tt;
      if ((tx - ball.x).abs() < 1.0) break;
      final f = (kNetX - ball.x) / (tx - ball.x);
      if (f <= 0.0 || f >= 1.0) break;
      final tc = f * tt;
      final zc = ball.z + vz * tc - 0.5 * kG * tc * tc;
      if (zc > kNetH + kBR + 4.0) break;
    }

    ball.vz = (tz - ball.z + 0.5 * kG * tt * tt) / tt;
    ball.vx = (tx - ball.x) / tt;
    ball.vy = (ty - ball.y) / tt;

    // Define o topspin orientado no sentido do ataque
    final dirX = (tx - ball.x).sign;
    ball.topspin = topspin * (dirX >= 0 ? 1.0 : -1.0);
  }

  /// Predição de trajetória para IA e anel marcador no solo.
  static BallPrediction predict(
    BallPhysicsState ball,
    double targetZ, {
    double maxTime = 4.0,
    double stepDt = 0.02,
  }) {
    double px = ball.x;
    double py = ball.y;
    double pz = ball.z;
    double pvx = ball.vx;
    double pvy = ball.vy;
    double pvz = ball.vz;
    double pts = ball.topspin;
    double t = 0.0;

    while (t < maxTime) {
      final speed = math.sqrt(pvx * pvx + pvy * pvy + pvz * pvz);
      final dragX = -kAirDrag * speed * pvx;
      final dragY = -kAirDrag * speed * pvy;
      final dragZ = -kAirDrag * speed * pvz;
      final magnusZ = -kMagnus * pts * pvx;
      final magnusX = kMagnus * pts * pvz;

      pvx += (dragX + magnusX) * stepDt;
      pvy += dragY * stepDt;
      pvz += (-kG + dragZ + magnusZ) * stepDt;

      px += pvx * stepDt;
      py += pvy * stepDt;
      pz += pvz * stepDt;
      pts *= math.max(0.0, 1.0 - 0.45 * stepDt);
      t += stepDt;

      if (pvz < 0 && pz <= targetZ) {
        return BallPrediction(px, py, t);
      }
    }

    return BallPrediction(px, py, t);
  }
}
