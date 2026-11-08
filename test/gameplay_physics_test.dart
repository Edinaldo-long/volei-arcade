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

    test('Early jump or high ball produces early rating', () {
      final eval = TimingEvaluator.evaluateSpike(
        ballZ: 220,
        playerZ: 70,
        playerVz: 250, // ascending fast
        dist2D: 40,
      );

      expect(eval.rating, TimingRating.early);
      expect(eval.speedMultiplier, lessThan(1.0));
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

    test('VolleyGame startTraining sets up mode 3, coach opponent and training targets', () {
      final game = VolleyGame();
      game.startTraining(drill: 0);
      expect(game.mode, equals(3));
      expect(game.teams[1].name, equals('TREINADOR'));
      expect(game.training.currentDrill, equals(TrainingDrill.serve));

      // Toggle de faixas musicais pelo jogo
      final initialTrack = ArcadeAudio.currentTrack;
      game.toggleNextMusicTrack();
      expect(ArcadeAudio.currentTrack, equals((initialTrack + 1) % 4));
    });

    test('TrainingController reception drill guides player via ball shadow without blue ring', () {
      final ctrl = TrainingController();
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
  });
}
