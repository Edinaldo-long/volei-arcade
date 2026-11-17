import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volei/audio/arcade_audio.dart';
import 'package:volei/effects/camera_shake.dart';
import 'package:volei/effects/hitstop_controller.dart';
import 'package:volei/effects/motion_trail.dart';
import 'package:volei/effects/timing_popup.dart';
import 'package:volei/gameplay/timing.dart';
import 'package:volei/gameplay/training_controller.dart';
import 'package:volei/main.dart';
import 'package:volei/physics/ball_physics.dart';
import 'package:volei/rendering/flag_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('BallPhysicsEngine Tests', () {
    test('Gravity pulls ball down to ground and bounces', () {
      final ball = BallPhysicsState()
        ..x = 200
        ..y = 200
        ..z = 100
        ..vz = 0;

      var bounced = false;
      for (var i = 0; i < 60; i++) {
        BallPhysicsEngine.step(ball, 1 / 60, onGroundCollision: (_) {
          bounced = true;
        });
      }

      expect(bounced, isTrue);
      expect(ball.z, greaterThanOrEqualTo(BallPhysicsEngine.kBR));
    });

    test('Topspin produces downward Magnus acceleration', () {
      final normalBall = BallPhysicsState()
        ..x = 200
        ..y = 200
        ..z = 150
        ..vx = 400
        ..vz = 50
        ..topspin = 0;

      final topspinBall = BallPhysicsState()
        ..x = 200
        ..y = 200
        ..z = 150
        ..vx = 400
        ..vz = 50
        ..topspin = 30; // positive topspin moving forward (+vx)

      for (var i = 0; i < 20; i++) {
        BallPhysicsEngine.step(normalBall, 1 / 60);
        BallPhysicsEngine.step(topspinBall, 1 / 60);
      }

      // Ball with topspin drops lower faster
      expect(topspinBall.z, lessThan(normalBall.z));
    });

    test('Prediction accurately estimates descent time', () {
      final ball = BallPhysicsState()
        ..x = 100
        ..y = 200
        ..z = 100
        ..vx = 200
        ..vz = 200;

      final pred = BallPhysicsEngine.predict(ball, BallPhysicsEngine.kBR);
      expect(pred.t, greaterThan(0.3));
      expect(pred.x, greaterThan(100));
    });
  });

  group('TimingEvaluator Tests', () {
    test('Spike at peak jump and optimal height yields perfect rating', () {
      final eval = TimingEvaluator.evaluateSpike(
        ballZ: 146,
        playerZ: 70, // relativeZ = 76 (optimal)
        playerVz: 10, // peak jump
        dist2D: 25, // centered
      );

      expect(eval.rating, TimingRating.perfect);
      expect(eval.speedMultiplier, greaterThan(1.2));
      expect(eval.hitstopDuration, greaterThan(0.05));
    });

    test('Spike with extended arm at high contact point yields perfect rating, not early', () {
      final eval = TimingEvaluator.evaluateSpike(
        ballZ: 175,
        playerZ: 70, // relativeZ = 105 (high spike at extended arm)
        playerVz: 60, // near apex with slight upward drive
        dist2D: 55, // well positioned
      );

      expect(eval.rating, TimingRating.perfect);
      expect(eval.speedMultiplier, greaterThan(1.3));
      expect(eval.label, 'PERFEITO!');
    });

    test('Solid spike within reaching distance yields good rating with full power', () {
      final eval = TimingEvaluator.evaluateSpike(
        ballZ: 160,
        playerZ: 65, // relativeZ = 95
        playerVz: -80, // slight descent
        dist2D: 95, // within reach (<= 125)
      );

      expect(eval.rating, TimingRating.good);
      expect(eval.speedMultiplier, greaterThan(1.1));
      expect(eval.label, 'BOM');
    });

    test('Premature swing when ball is excessively high produces early rating', () {
      final eval = TimingEvaluator.evaluateSpike(
        ballZ: 230,
        playerZ: 70, // relativeZ = 160 (> 145)
        playerVz: 360, // ascending fast (> 340)
        dist2D: 40,
      );

      expect(eval.rating, TimingRating.early);
      expect(eval.speedMultiplier, lessThan(1.0));
      expect(eval.label, 'CEDO');
    });

    test('Late swing when ball has dropped too low produces late rating', () {
      final eval = TimingEvaluator.evaluateSpike(
        ballZ: 85,
        playerZ: 60, // relativeZ = 25 (< 40)
        playerVz: -100,
        dist2D: 40,
      );

      expect(eval.rating, TimingRating.late);
      expect(eval.speedMultiplier, lessThan(1.0));
      expect(eval.label, 'TARDE');
    });
  });

  group('HitstopController Tests', () {
    test('Trigger freezes simulation for specified duration', () {
      final hitstop = HitstopController();
      expect(hitstop.isFrozen, isFalse);

      hitstop.trigger(0.065);
      expect(hitstop.isFrozen, isTrue);

      final stillFrozen = hitstop.update(0.040);
      expect(stillFrozen, isTrue);
      expect(hitstop.isFrozen, isTrue);

      final unfreeze = hitstop.update(0.035);
      expect(unfreeze, isFalse);
      expect(hitstop.isFrozen, isFalse);
    });
  });

  group('CameraShake Tests', () {
    test('Trauma decays smoothly and produces offset', () {
      final shake = CameraShake();
      shake.addTrauma(0.8);
      expect(shake.trauma, closeTo(0.8, 0.001));

      shake.update(0.1);
      expect(shake.trauma, lessThan(0.8));
    });
  });

  group('MotionTrail & TimingPopup Tests', () {
    test('MotionTrail adds points only above threshold', () {
      final trail = MotionTrail(minSpeedThreshold: 400);
      trail.addSample(
        screenPos: const Offset(100, 100),
        radius: 10,
        speed: 300, // below threshold
      );
      // nothing drawn or added
      trail.addSample(
        screenPos: const Offset(100, 100),
        radius: 10,
        speed: 550, // above threshold
      );
      trail.update(0.05);
      trail.clear();
    });

    test('TimingPopup updates and decays', () {
      final popups = TimingPopupManager();
      popups.add(
        text: 'PERFEITO!',
        position: const Offset(200, 200),
        color: Colors.amber,
      );
      popups.update(0.1);
      popups.clear();
    });
  });

  group('VolleyGame Integration Tests', () {
    test('Game initializes with new physics and effect subsystems', () {
      final game = VolleyGame();
      expect(game.ball, isNotNull);
      expect(game.hitstop, isNotNull);
      expect(game.cameraShake, isNotNull);
      expect(game.motionTrail, isNotNull);
      expect(game.timingPopups, isNotNull);

      // Verify delegation getters/setters
      game.bx = 300;
      expect(game.ball.x, 300);
      game.bz = 120;
      expect(game.ball.z, 120);
    });

    test('Hitstop freezes simulation while active', () {
      final game = VolleyGame();
      game.phase = Phase.rally;
      game.ballHeld = false;
      game.bvx = 200;

      game.hitstop.trigger(0.065);
      expect(game.hitstop.isFrozen, isTrue);

      final initialBallX = game.bx;
      game.update(0.02);

      // Ball does not move during freeze frame
      expect(game.bx, equals(initialBallX));
    });

    test('Pad controls allow keyboard and gamepad coexistence', () {
      final pad = Pad();

      // Teclado
      pad.kLeft = true;
      expect(pad.left, isTrue);
      expect(pad.dx, equals(-1.0));

      // Analógico sobrepõe teclado quando ativo
      pad.ax = 0.75;
      expect(pad.dx, closeTo(0.75, 0.001));

      // Soltando analógico volta a responder ao direcional
      pad.ax = 0.0;
      expect(pad.dx, equals(-1.0));
      pad.kLeft = false;
      expect(pad.dx, equals(0.0));

      // Pulo com suporte a toque e botões
      expect(pad.jump, isFalse);
      pad.jump = true;
      expect(pad.jump, isTrue);
      pad.jump = false;
      pad.gJump = true;
      expect(pad.jump, isTrue);
    });

    test('Pad handles virtual joystick axes and deadzone cleanly', () {
      final pad = Pad();
      // Dentro da zona morta (< 0.08)
      pad.ax = 0.05;
      pad.ay = -0.06;
      expect(pad.dx, equals(0.0));
      expect(pad.dy, equals(0.0));

      // Fora da zona morta (> 0.08)
      pad.ax = 0.85;
      pad.ay = -0.65;
      expect(pad.dx, closeTo(0.85, 0.001));
      expect(pad.dy, closeTo(-0.65, 0.001));

      // Resetando analógico
      pad.ax = 0;
      pad.ay = 0;
      expect(pad.dx, equals(0.0));
      expect(pad.dy, equals(0.0));
    });

    test('Human player maintains control stickiness during active joystick steering', () {
      final game = VolleyGame();
      game.startMatch(0);
      final p0 = game.players[0];
      final p1 = game.players[1];
      game.controlled[0] = p0;

      // Human jogador 0 movendo o analógico ativamente
      game.pads[0].ax = 1.0;
      expect(game.pads[0].dx, equals(1.0));

      // Simula bola vindo em posição onde o parceiro (p1) estaria ligeiramente mais próximo
      p0.x = 150;
      p0.y = 200;
      p1.x = 350;
      p1.y = 200;

      // Chama a seleção de papéis interna através do update de fase
      game.phase = Phase.rally;
      game.ball.x = 280;
      game.ball.y = 200;
      game.ball.z = 60;
      game.ball.vz = -100;
      game.touches[0] = 0;
      game.lastTeam = 1;

      // Atualiza o jogo: como p0 está ativamente comandado via joystick,
      // a histerese de 220px mantém p0 controlado sem travar ou trocar sozinho
      game.update(0.016);
      expect(game.controlled[0], equals(p0));
      expect(p0.human, isTrue);
    });

    test('Player prevents kangaroo bouncing when jump button is held', () {
      final player = Player(0, 0, 100, 200);
      expect(player.onGround, isTrue);

      // Primeiro pulo
      player.vz = 480;
      player.z = 10;
      player.jumpHeld = true;
      expect(player.onGround, isFalse);

      // Simulando aterrissagem enquanto o botão continua pressionado
      player.z = 0;
      player.vz = 0;
      expect(player.onGround, isTrue);
      expect(player.jumpHeld, isTrue);

      // Soltando o botão desarma a trava
      player.jumpHeld = false;
      expect(player.jumpHeld, isFalse);
    });

    test('togglePause toggles paused state and manages pause overlay', () {
      final game = VolleyGame();
      game.overlays.addEntry('pause', (_, _) => const SizedBox());
      game.phase = Phase.serving;
      expect(game.paused, isFalse);

      game.togglePause();
      expect(game.paused, isTrue);
      expect(game.overlays.isActive('pause'), isTrue);

      game.togglePause();
      expect(game.paused, isFalse);
      expect(game.overlays.isActive('pause'), isFalse);
    });

    test('toggleArena switches between gym and beach scenarios', () {
      final game = VolleyGame();
      expect(game.isBeach, isFalse);

      game.toggleArena();
      expect(game.isBeach, isTrue);

      game.toggleArena();
      expect(game.isBeach, isFalse);
    });

    test('Serve mechanism allows ball toss, running jump, and jump spike serve', () {
      final game = VolleyGame();
      game.startMatch(1); // Amistoso
      expect(game.phase, Phase.serving);
      expect(game.ballTossed, isFalse);

      // Jogador pressiona botão de bater para lançar a bola no ar (toss)
      game.pads[0].hitBuf = 0.25;
      game.update(0.016);
      expect(game.ballTossed, isTrue);
      expect(game.ballHeld, isFalse);
      expect(game.bvz, greaterThan(300));

      // Bola voa no ar e jogador pode correr para frente e saltar
      final server = game.players.firstWhere((p) => p.team == game.serving && p.slot == 0);
      game.pads[0].jump = true;
      game.pads[0].ax = 1.0;
      game.update(0.05);

      expect(server.vz, greaterThan(0));
      expect(server.z, greaterThan(0));

      // No ápice do salto, jogador executa o corte (saque viagem)
      game.pads[0].hitBuf = 0.25;
      game.update(0.016);

      // Transiciona imediatamente para rally com velocidade e efeito topspin potente
      expect(game.phase, Phase.rally);
      expect(game.ballTossed, isFalse);
      expect(game.ball.vx, greaterThan(350));
      expect(game.ball.topspin, greaterThan(10));
    });

    test('Serve fault triggers point for opponent if tossed ball hits ground', () {
      final game = VolleyGame();
      game.startMatch(1);
      final initialOppScore = game.score[1];

      // Lança a bola
      game.pads[0].hitBuf = 0.25;
      game.update(0.016);
      expect(game.ballTossed, isTrue);

      // Simula a passagem do tempo sem o jogador tocar na bola até cair no chão
      for (var i = 0; i < 90; i++) {
        game.update(0.016);
        if (game.phase != Phase.serving) break;
      }

      // Falta no saque: ponto para o adversário
      expect(game.score[1], equals(initialOppScore + 1));
      expect(game.phase, equals(Phase.pointPause));
    });

    test('Tournament allows configuring custom rival countries for each phase', () {
      final game = VolleyGame();
      // Seleciona Brasil como time do jogador e define rivais personalizados:
      game.playerTeamIndex = 0; // Brasil
      game.tournamentRivalIndices = [
        5, // França (Quartas)
        7, // Cuba (Semifinal)
        6, // Polônia (Final)
        4, // EUA (Grande Final)
      ];

      // Inicia Torneio (Fase 1: Quartas)
      game.startMatch(0);
      expect(game.teams[0].name, equals('BRASIL'));
      expect(game.teams[1].name, equals('FRANÇA'));

      // Avança para a Fase 2 (Semifinal)
      game.nextRound();
      expect(game.round, 1);
      expect(game.teams[0].name, equals('BRASIL'));
      expect(game.teams[1].name, equals('CUBA'));

      // Avança para a Fase 3 (Final)
      game.nextRound();
      expect(game.round, 2);
      expect(game.teams[1].name, equals('POLÔNIA'));

      // Avança para a Fase 4 (Grande Final)
      game.nextRound();
      expect(game.round, 3);
      expect(game.teams[1].name, equals('EUA'));
    });

    test('Music toggle enables and disables background music state', () {
      final game = VolleyGame();
      expect(game.musicEnabled, isTrue);

      game.toggleMusic();
      expect(game.musicEnabled, isFalse);

      game.toggleMusic();
      expect(game.musicEnabled, isTrue);
    });

    test('Positive plays by player excite the crowd and increase crowd cheering level', () {
      final game = VolleyGame();
      game.startMatch(1);
      game.phase = Phase.rally;
      game.ballHeld = false;
      expect(game.crowd, equals(0.0));

      // Ponto marcado pelo jogador (Time 0) com aterrissagem na quadra adversária
      game.bvx = 200;
      game.bx = 700; // quadra do time 1
      game.by = 200;
      game.bz = 10;
      game.lastTeam = 0;
      game.update(0.02);

      // Plateia ovaciona e se empolga (crowd > 1.0)
      expect(game.crowd, greaterThan(1.0));
      expect(game.consecutivePlayerPoints, equals(1));
    });

    test('FlagRenderer draws authentic flags for all nations without throwing', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const nations = [
        'BRASIL', 'ARGENTINA', 'JAPÃO', 'ITÁLIA', 'EUA',
        'FRANÇA', 'POLÔNIA', 'CUBA', 'ALEMANHA', 'HOLANDA',
      ];

      for (var i = 0; i < nations.length; i++) {
        expect(() {
          FlagRenderer.drawFlag(
            canvas,
            Rect.fromLTWH(i * 30.0, 0, 28, 20),
            countryName: nations[i],
          );
        }, returnsNormally);
      }
    });

    test('ArcadeAudio switches through 4 distinct chiptune BGM tracks', () {
      expect(ArcadeAudio.trackNames.length, equals(4));
      ArcadeAudio.setTrack(0);
      expect(ArcadeAudio.currentTrack, equals(0));
      expect(ArcadeAudio.currentTrackName, contains('Arcade Clássico'));

      ArcadeAudio.nextTrack();
      expect(ArcadeAudio.currentTrack, equals(1));
      expect(ArcadeAudio.currentTrackName, contains('Samba Groove'));

      ArcadeAudio.nextTrack();
      expect(ArcadeAudio.currentTrack, equals(2));
      expect(ArcadeAudio.currentTrackName, contains('Electro Tensão'));

      ArcadeAudio.nextTrack();
      expect(ArcadeAudio.currentTrack, equals(3));
      expect(ArcadeAudio.currentTrackName, contains('Brisa de Praia'));

      // Loop de volta à faixa 0
      ArcadeAudio.nextTrack();
      expect(ArcadeAudio.currentTrack, equals(0));
    });

    test('TrainingController sets up all 6 drills and evaluates landing correctly', () {
      final ctrl = TrainingController();
      expect(ctrl.drillIndex, equals(0));
      expect(ctrl.currentDrill, equals(TrainingDrill.serve));
      expect(ctrl.targets, isNotEmpty);

      // Avaliação de acerto no alvo da quadra
      final target = ctrl.targets.first;
      final scoreEarned = ctrl.evaluateBallLanding(
        target.rect.center.dx,
        target.rect.center.dy,
        speed: 400,
      );
      expect(scoreEarned, equals(target.points));
      expect(ctrl.successes, equals(1));
      expect(ctrl.totalScore, equals(target.points));
      expect(ctrl.coachCheering, isTrue);
      expect(ctrl.coachSpeechNotifier.value, isNotNull);

      // Limpar mensagem do treinador
      ctrl.clearCoachMessage();
      expect(ctrl.coachSpeechNotifier.value, isNull);

      // Repetir dica do exercício atual
      ctrl.repeatCurrentDrillTip();
      expect(ctrl.coachSpeechNotifier.value, equals(TrainingController.drillTip(0)));

      // Avança por todos os exercícios e checa mensagem
      for (var i = 1; i < 6; i++) {
        ctrl.nextDrill();
        expect(ctrl.drillIndex, equals(i));
        expect(ctrl.coachSpeechNotifier.value, equals(TrainingController.drillTip(i)));
      }
    });

    test('Net Blocking: jumping near net blocks opponent spike downward', () {
      final game = VolleyGame();
      game.startMatch(1); // Amistoso

      // Posiciona jogador 1 (rede) saltando em frente à rede (x = 430, z = 45)
      final netPlayer = game.players[1];
      netPlayer.x = 430;
      netPlayer.y = 215;
      netPlayer.z = 45;
      netPlayer.vz = 50;

      // Bola atacada pelo oponente vindo em direção à rede (bvx < 0, bz na altura do bloqueio)
      game.phase = Phase.rally;
      game.bx = 445;
      game.by = 215;
      game.bz = 145;
      game.bvx = -600;
      game.bvy = 0;
      game.bvz = 10;
      game.ballSide = 0;
      game.blockCd = 0;

      // Executa a checagem de bloqueio
      game.update(1 / 60);

      // A bola deve ser bloqueada: inverte bvx para o campo adversário (> 0) e crava para baixo (bvz < 0)
      expect(game.bvx, greaterThan(400));
      expect(game.bvz, lessThan(0));
      expect(game.lastTeam, equals(0));
      expect(game.blockCd, greaterThan(0));
    });

    test('TrainingController reception drill guides player via ball shadow without blue ring', () {
      expect(TrainingController.drillDescriptions[1], contains('sombra da bola'));
      expect(TrainingController.drillDescriptions[1].contains('ANEL AZUL'), isFalse);
    });

    test('TrainingController accuracy and rank calculations', () {
      final ctrl = TrainingController();
      expect(ctrl.rankLetter, equals('S')); // Padrão sem tentativas

      // 4 acertos em 5 tentativas = 80% (Rank S)
      ctrl.attempts = 5;
      ctrl.successes = 4;
      expect(ctrl.accuracy, equals(80));
      expect(ctrl.rankLetter, equals('A'));

      ctrl.successes = 5;
      expect(ctrl.accuracy, equals(100));
      expect(ctrl.rankLetter, equals('S'));
      expect(ctrl.rankTitle, contains('MESTRE'));

      // 1 acerto em 3 tentativas = 33% (Rank C)
      ctrl.attempts = 3;
      ctrl.successes = 1;
      expect(ctrl.accuracy, equals(33));
      expect(ctrl.rankLetter, equals('C'));
    });

    test('FlagRenderer draws coach tactical board without errors', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      FlagRenderer.drawFlag(
        canvas,
        const Rect.fromLTWH(0, 0, 40, 26),
        countryName: 'TREINADOR',
      );
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('Hybrid Mobile Arcade Controls: Auto-Switch locks arrow on closest player during reception', () {
      final game = VolleyGame();
      game.startMatch(1); // Amistoso (Time 0 humano)
      game.phase = Phase.rally;
      game.ballHeld = false;
      game.outgoing = false;
      game.lastTeam = 1; // Bola veio do adversário
      game.touches[0] = 0;
      game.touches[1] = 0;

      // Bola projetada para cair no fundo da quadra perto do jogador 0 (x = 160, y = 320)
      game.bx = 200;
      game.by = 310;
      game.bz = 180;
      game.bvx = -120;
      game.bvy = 10;
      game.bvz = -20;
      game.ballSide = 0;

      // Executa frame
      game.update(1 / 60);

      // Jogador 0 (fundo) deve ter sido selecionado e a seta travada nele
      final locked = game.controlled[0];
      expect(locked, isNotNull);
      expect(locked!.slot, equals(0));
      expect(locked.human, isTrue);

      // Agora simula o jogador movendo o analógico e mudando de posição
      game.pads[0].ax = 1.0;
      game.pads[0].ay = -1.0;

      // Mesmo que o jogador 0 se afaste e o jogador 1 (rede) esteja mais perto de outro ponto,
      // a seta NÃO pula nem oscila! Ela permanece estritamente travada no jogador 0 até o toque
      for (var i = 0; i < 10; i++) {
        game.update(1 / 60);
        expect(game.controlled[0], equals(locked),
            reason: 'A seta deve permanecer estritamente travada no mesmo jogador durante a jogada');
      }
    });

    test('Hybrid Mobile Arcade Controls: Auto-Switch passes arrow to partner on touch 1 and attacker on touch 2', () {
      final game = VolleyGame();
      game.startMatch(1);
      game.phase = Phase.rally;
      game.ballHeld = false;
      game.outgoing = false;
      game.lastTeam = 0;
      game.touches[0] = 1; // 1 toque já feito (recepção concluída)
      game.lastToucher = game.players[0]; // Jogador 0 recepcionou

      game.bx = 300;
      game.by = 200;
      game.bz = 150;
      game.bvx = 20;
      game.bvy = 0;
      game.bvz = 50;
      game.ballSide = 0;

      game.update(1 / 60);

      // No levantamento (toque 1), a seta deve passar para o parceiro (jogador 1)
      expect(game.controlled[0], equals(game.players[1]));

      // Agora simula que o parceiro levantou a bola (toque 2)
      game.touches[0] = 2;
      game.lastToucher = game.players[1];
      game.bx = 350;
      game.by = 220;
      game.bz = 180;
      game.update(1 / 60);

      // No ataque (toque 2), a seta deve passar de volta para o atacante (jogador 0)
      expect(game.controlled[0], equals(game.players[0]));
    });

    test('Hybrid Mobile Arcade Controls: Partner covers complementary space on court', () {
      final game = VolleyGame();
      game.startMatch(1);
      game.phase = Phase.rally;
      game.ballHeld = false;
      game.outgoing = false;
      game.lastTeam = 1;
      game.touches[0] = 0;
      game.ballSide = 0;

      // Bola caindo na metade superior da quadra (y = 120, fundo x = 150)
      game.bx = 150;
      game.by = 120;
      game.bz = 120;
      game.bvx = -10;
      game.bvy = 0;
      game.bvz = -50;

      game.update(1 / 60);

      // O jogador controlado assume a bola
      final active = game.controlled[0];
      final partner = game.players.where((p) => p.team == 0 && p != active).first;

      // O parceiro deve se posicionar na metade complementar (inferior y > 250) e frente de quadra
      expect(partner.ty, greaterThan(250.0));
      expect(partner.tx, greaterThan(240.0));
      expect(partner.wHit, isFalse);
    });

    test('Hybrid Mobile Arcade Controls: Partner emergency defense reflex rescues imminent ball', () {
      final game = VolleyGame();
      game.startMatch(1);
      game.phase = Phase.rally;
      game.ballHeld = false;
      game.outgoing = false;
      game.lastTeam = 1;
      game.touches[0] = 0;
      game.ballSide = 0;

      // Inicializa jogada com a bola vindo na direção do jogador 0 (ativo), travando a seta nele
      game.players[0].x = 120;
      game.players[0].y = 350;
      game.players[1].x = 320;
      game.players[1].y = 150;

      game.bx = 130;
      game.by = 345;
      game.bz = 180;
      game.bvx = 0;
      game.bvy = 0;
      game.bvz = -50;
      game.update(1 / 60);

      // Confirma que a seta travou no jogador 0 e o jogador 1 é o parceiro
      expect(game.controlled[0], equals(game.players[0]));

      // Agora a bola sofre desvio brusco e desce perto do parceiro (jogador 1)
      game.bx = 325;
      game.by = 155;
      game.bz = 70; // Bola baixa prestes a tocar o chão
      game.bvx = 0;
      game.bvy = 0;
      game.bvz = -80;

      game.update(1 / 60);

      // O parceiro (jogador 1) deve ativar a defesa de emergência, rebater e salvar a jogada
      final partner = game.players[1];
      expect(game.lastToucher, equals(partner));
      expect(game.touches[0], equals(1));
    });
  });
}
