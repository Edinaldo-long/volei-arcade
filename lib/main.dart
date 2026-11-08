// VÔLEI ARCADE 2 x 2 - visão em perspectiva (estilo Great Volleyball / Master System)
// Flutter + Flame
//
// Dependência:  flutter pub add flame
// (não usa nenhum outro pacote nem imagens/sons)
//
// ALTERAÇÃO: o direcional em cruz foi trocado por um JOYSTICK ANALÓGICO
// virtual (um único toque que acompanha o dedo em qualquer direção).
import 'dart:math' as math;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/arcade_audio.dart';
import 'effects/camera_shake.dart';
import 'effects/hitstop_controller.dart';
import 'effects/motion_trail.dart';
import 'effects/timing_popup.dart';
import 'gameplay/timing.dart';
import 'input/gamepad_reader.dart';
import 'physics/ball_physics.dart';
import 'rendering/ball_renderer.dart';
import 'rendering/character_renderer.dart';
import 'rendering/court_renderer.dart';
import 'rendering/flag_renderer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Celular: tela cheia e sempre deitado (paisagem)
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const VolleyApp());
}

class VolleyApp extends StatefulWidget {
  final VolleyGame? game;
  const VolleyApp({super.key, this.game});

  @override
  State<VolleyApp> createState() => _VolleyAppState();
}

class _VolleyAppState extends State<VolleyApp> {
  late final VolleyGame _game;

  @override
  void initState() {
    super.initState();
    _game = widget.game ?? VolleyGame();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.amber,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: const RoundedRectangleBorder(),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        chipTheme: const ChipThemeData(shape: RoundedRectangleBorder()),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF0B1038),
        body: GameWidget<VolleyGame>(
          game: _game,
          overlayBuilderMap: {
            'menu': (context, g) => _Menu(game: g),
            'controls': (context, g) => _Controls(game: g),
            'pause': (context, g) => _PauseMenu(game: g),
            'result': (context, g) => _Result(game: g),
          },
        ),
      ),
    );
  }
}

// ============================================================
//  CONSTANTES
//  Quadra: gx = comprimento (0..kL, rede em kMid), gy = profundidade
//  (0 = lado do fundo/longe, kWd = lado da câmera/perto), gz = altura.
//  Tela virtual: 800 x 600.
// ============================================================
const double kW = 800, kH = 600;
const double kL = 900, kWd = 430, kMid = 450;
const double kNetH = 130;
const double kG = 900; // gravidade da bola
const double kBR = 14; // raio da bola
const double kPG = 1500, kJump = 480; // jogadores
const double kFarY = 192, kNearY = 560; // posição na tela das bordas da quadra
const double kSFar = 0.70, kSNear = 1.02; // escala (perspectiva aumentada)

const Color kOutline = Color(0xFF14122B);

// projeção
double _sc(double gy) => kSFar + (kSNear - kSFar) * (gy / kWd);
double _sx(double gx, double gy) => kW / 2 + (gx - kL / 2) * _sc(gy);
double _sy(double gy, double gz) =>
    kFarY + (kNearY - kFarY) * (gy / kWd) - gz * _sc(gy);

// ============================================================
//  MODELOS
// ============================================================
class Player {
  final int team, slot; // slot 0 = fundo, slot 1 = rede
  double x, y, z = 0, vz = 0;
  double hitCd = 0, swing = 0, errX = 0, errY = 0, jumpErr = 0;
  double jumpCd = 0;
  bool jumpHeld = false;
  double tx = 0, ty = 0; // alvo da IA
  bool wJump = false, wHit = false, human = false, moving = false;
  Player(this.team, this.slot, this.x, this.y);
  bool get onGround => z <= 0.5;
}

class Pad {
  // Teclado
  bool kLeft = false, kRight = false, kUp = false, kDown = false, kJump = false;
  // Gamepad
  bool gLeft = false, gRight = false, gUp = false, gDown = false, gJump = false;
  // Toque na tela
  bool tJump = false;
  double ax = 0, ay = 0; // joystick analógico / virtual (-1..1)
  double hitBuf = 0; // "buffer" do botão de bater

  bool get left => kLeft || gLeft;
  bool get right => kRight || gRight;
  bool get up => kUp || gUp;
  bool get down => kDown || gDown;
  bool get jump => kJump || gJump || tJump;
  set jump(bool v) => tJump = v;

  // Eixos finais: o analógico tem prioridade fora da zona morta, senão usa direcionais
  double get dx {
    if (ax.abs() > 0.08) return ax;
    return (right ? 1.0 : 0.0) - (left ? 1.0 : 0.0);
  }

  double get dy {
    if (ay.abs() > 0.08) return ay;
    return (down ? 1.0 : 0.0) - (up ? 1.0 : 0.0);
  }
}

class TeamInfo {
  final String name;
  final Color color, trim;
  final double level; // 0..1 (força da IA)
  final String flagEmoji;
  const TeamInfo(this.name, this.color, this.trim, this.level, [this.flagEmoji = '🏐']);
}

const List<TeamInfo> kAvailableTeams = [
  TeamInfo('BRASIL', Color(0xFFFFD600), Color(0xFF1B8E3E), 0.75, '🇧🇷'),
  TeamInfo('ARGENTINA', Color(0xFF7EC8F2), Color(0xFFFFFFFF), 0.55, '🇦🇷'),
  TeamInfo('JAPÃO', Color(0xFFE53935), Color(0xFFFFFFFF), 0.65, '🇯🇵'),
  TeamInfo('ITÁLIA', Color(0xFF1565C0), Color(0xFFFFFFFF), 0.78, '🇮🇹'),
  TeamInfo('EUA', Color(0xFF1A237E), Color(0xFFD32F2F), 0.92, '🇺🇸'),
  TeamInfo('FRANÇA', Color(0xFF0D47A1), Color(0xFFD32F2F), 0.85, '🇫🇷'),
  TeamInfo('POLÔNIA', Color(0xFFD32F2F), Color(0xFFFFFFFF), 0.88, '🇵🇱'),
  TeamInfo('CUBA', Color(0xFFC62828), Color(0xFF1565C0), 0.72, '🇨🇺'),
  TeamInfo('ALEMANHA', Color(0xFF212121), Color(0xFFFFD600), 0.70, '🇩🇪'),
  TeamInfo('HOLANDA', Color(0xFFFF6D00), Color(0xFF0D47A1), 0.74, '🇳🇱'),
];

class Pred {
  final double x, y, t;
  Pred(this.x, this.y, this.t);
}

class Spark {
  double x, y, vx, vy, life;
  final double maxLife, size;
  final Color color;
  Spark(this.x, this.y, this.vx, this.vy, this.maxLife, this.size, this.color)
      : life = maxLife;
}

class _Item {
  final double depth;
  final void Function() draw;
  _Item(this.depth, this.draw);
}

enum Phase { menu, serving, rally, pointPause, matchOver }

// ============================================================
//  JOGO
// ============================================================
class VolleyGame extends FlameGame with KeyboardEvents {
  final math.Random _rnd = math.Random();

  Phase phase = Phase.menu;
  @override
  bool paused = false;
  int mode = 0; // 0 torneio, 1 amistoso, 2 dois jogadores
  int difficulty = 1; // 0 fácil, 1 normal, 2 difícil
  int round = 0;
  int winner = 0;
  bool isBeach = false; // false = Ginásio Olímpico, true = Vôlei de Praia
  bool ballTossed = false; // saque viagem: bola lançada no ar aguardando corte/toque
  double serveTossTimer = 0.0;
  bool musicEnabled = true;
  int consecutivePlayerPoints = 0;

  int playerTeamIndex = 0; // 0 = BRASIL
  TeamInfo get playerTeam =>
      kAvailableTeams[playerTeamIndex % kAvailableTeams.length];

  // Rivais selecionados para as 4 fases do Torneio (Quartas, Semifinal, Final, Super Final)
  List<int> tournamentRivalIndices = [1, 2, 3, 4]; // ARG, JPN, ITA, EUA por padrão
  List<TeamInfo> get tournamentRivals => tournamentRivalIndices
      .map((i) => kAvailableTeams[i % kAvailableTeams.length])
      .toList();

  int exhibitionRivalIndex = 1; // Rival padrão para o amistoso (ARGENTINA)
  TeamInfo get exhibitionRival =>
      kAvailableTeams[exhibitionRivalIndex % kAvailableTeams.length];

  List<TeamInfo> teams = [kAvailableTeams[0], kAvailableTeams[1]];
  final List<Player> players = [
    Player(0, 0, 150, kWd * 0.66),
    Player(0, 1, 330, kWd * 0.30),
    Player(1, 0, kL - 150, kWd * 0.66),
    Player(1, 1, kL - 330, kWd * 0.30),
  ];
  final List<Player?> controlled = [null, null];
  final List<Pad> pads = [Pad(), Pad()];
  final List<int> score = [0, 0];
  int serving = 0;

  // Motor físico e efeitos modernos
  final BallPhysicsState ball = BallPhysicsState();
  final HitstopController hitstop = HitstopController();
  final CameraShake cameraShake = CameraShake();
  final MotionTrail motionTrail = MotionTrail();
  final TimingPopupManager timingPopups = TimingPopupManager();
  double ballSquashTime = 0.0;
  double ballSquashFactor = 1.0;

  // Bola (propriedades delegadas para BallPhysicsState mantendo compatibilidade)
  double get bx => ball.x;
  set bx(double v) => ball.x = v;
  double get by => ball.y;
  set by(double v) => ball.y = v;
  double get bz => ball.z;
  set bz(double v) => ball.z = v;
  double get bvx => ball.vx;
  set bvx(double v) => ball.vx = v;
  double get bvy => ball.vy;
  set bvy(double v) => ball.vy = v;
  double get bvz => ball.vz;
  set bvz(double v) => ball.vz = v;
  double get bAng => ball.angle;
  set bAng(double v) => ball.angle = v;
  double get blockCd => ball.blockCd;
  set blockCd(double v) => ball.blockCd = v;
  int get ballSide => ball.side;
  set ballSide(int v) => ball.side = v;
  bool get ballHeld => ball.held;
  set ballHeld(bool v) => ball.held = v;
  bool get outgoing => ball.outgoing;
  set outgoing(bool v) => ball.outgoing = v;

  int lastTeam = 0;
  Player? lastToucher;
  final List<int> touches = [0, 0];

  // Tempo e efeitos
  double time = 0, shake = 0, crowd = 0;
  double _serveTimer = 0, _pauseTimer = 0, _msgTimer = 0;
  String _msgText = '';
  final List<Spark> sparks = [];
  // ponto de queda (anel no chão) para o jogador humano de cada time
  final List<Pred?> marker = [null, null];

  // Área visível (coordenadas da tela virtual)
  double vx0 = 0, vx1 = kW, vy0 = 0, vy1 = kH;

  Player get _server =>
      players.firstWhere((q) => q.team == serving && q.slot == 0);

  bool _isHumanTeam(int t) => t == 0 || mode == 2;

  double _lvl(int team) {
    if (team == 0 || mode == 2) return 0.7;
    return teams[1].level;
  }

  // ---------- início / fim de partida ----------
  void _safeAddOverlay(String name) {
    if (overlays.registeredOverlays.contains(name)) {
      overlays.add(name);
    }
  }

  @override
  Future<void> onLoad() async {
    controlled[0] = players[0];
    controlled[1] = players[2];
    _nextServe();
    phase = Phase.menu;
    _safeAddOverlay('menu');
  }

  void startMatch(int m, {int diff = 1}) {
    mode = m;
    difficulty = diff;
    round = 0;
    _beginMatch();
  }

  void nextRound() {
    round++;
    _beginMatch();
  }

  void toggleArena() {
    isBeach = !isBeach;
    _msg(isBeach ? 'ARENA: PRAIA TROPICAL 🏖️' : 'ARENA: GINÁSIO OLÍMPICO 🏢', 1.2);
  }

  void toggleMusic() {
    musicEnabled = !musicEnabled;
    ArcadeAudio.setMusicEnabled(musicEnabled);
    _msg(musicEnabled ? 'MÚSICA: LIGADA 🎵' : 'MÚSICA: DESLIGADA 🔇', 1.2);
  }

  void toggleNextMusicTrack() {
    ArcadeAudio.nextTrack();
    _msg('MÚSICA: ${ArcadeAudio.currentTrackName}', 1.6);
  }

  void _resetPositions() {
    _nextServe();
  }

  void togglePause() {
    if (phase != Phase.serving &&
        phase != Phase.rally &&
        phase != Phase.pointPause) {
      return;
    }
    paused = !paused;
    if (paused) {
      ArcadeAudio.pauseBgm();
      _safeAddOverlay('pause');
    } else {
      ArcadeAudio.resumeBgm();
      overlays.remove('pause');
    }
  }

  void rematch() => _beginMatch();

  void toMenu() {
    phase = Phase.menu;
    paused = false;
    ballTossed = false;
    ArcadeAudio.stopBgm();
    overlays.remove('result');
    overlays.remove('controls');
    overlays.remove('pause');
    _safeAddOverlay('menu');
  }

  void _setupTeams() {
    if (mode == 2) {
      final t1 = playerTeam;
      final t2 = exhibitionRival;
      teams = [
        TeamInfo('P1: ${t1.name}', t1.color, t1.trim, 0.7, t1.flagEmoji),
        TeamInfo('P2: ${t2.name}', t2.color, t2.trim, 0.7, t2.flagEmoji),
      ];
    } else if (mode == 0) {
      final rival = tournamentRivals[math.min(round, tournamentRivals.length - 1)];
      teams = [playerTeam, rival];
    } else {
      const lv = [0.18, 0.58, 0.92];
      final rival = exhibitionRival;
      teams = [
        playerTeam,
        TeamInfo(rival.name, rival.color, rival.trim, lv[difficulty], rival.flagEmoji),
      ];
    }
  }

  void _beginMatch() {
    _setupTeams();
    score[0] = 0;
    score[1] = 0;
    serving = 0;
    paused = false;
    ballTossed = false;
    consecutivePlayerPoints = 0;
    overlays.remove('menu');
    overlays.remove('result');
    overlays.remove('controls');
    overlays.remove('pause');
    _safeAddOverlay('controls');
    if (musicEnabled) {
      ArcadeAudio.startBgm();
    }
    _nextServe();
    final rTitle = mode == 0
        ? const ['QUARTAS', 'SEMIFINAL', 'FINAL', 'GRANDE FINAL'][math.min(round, 3)]
        : '';
    final sub = rTitle.isNotEmpty ? ' [$rTitle]' : '';
    _msg('${teams[0].name} x ${teams[1].name}$sub', 2.2);
  }

  void _nextServe() {
    for (final p in players) {
      p.z = 0;
      p.vz = 0;
      p.hitCd = 0;
      p.swing = 0;
      p.x = _baseXFor(p, true);
      p.y = _baseYFor(p, true);
    }
    touches[0] = 0;
    touches[1] = 0;
    lastTeam = serving;
    lastToucher = null;
    outgoing = false;
    ballHeld = true;
    ballTossed = false;
    serveTossTimer = 0.0;
    ballSide = serving;
    bvx = 0;
    bvy = 0;
    bvz = 0;
    ball.topspin = 0;
    hitstop.reset();
    motionTrail.clear();
    timingPopups.clear();
    ballSquashTime = 0;
    controlled[serving] = _server;
    _serveTimer = 1.0 + _rnd.nextDouble() * 0.6;
    phase = Phase.serving;
    _placeBallOnServer();
    _rerollAi();
  }

  void _placeBallOnServer() {
    final s = _server;
    final face = s.team == 0 ? 1.0 : -1.0;
    bx = s.x + face * 14;
    by = s.y;
    bz = s.z + 88;
  }

  void _endMatch() {
    phase = Phase.matchOver;
    winner = score[0] > score[1] ? 0 : 1;
    paused = false;
    ballTossed = false;
    overlays.remove('controls');
    overlays.remove('pause');
    _safeAddOverlay('result');
    if (winner == 0) {
      crowd = 2.5;
      ArcadeAudio.playPointCheer(perfect: true);
    }
  }

  void _msg(String s, [double t = 1.4]) {
    _msgText = s;
    _msgTimer = t;
  }

  // ---------- teclado e gamepad ----------
  @override
  KeyEventResult onKeyEvent(
      KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    bool k(LogicalKeyboardKey a) => keysPressed.contains(a);
    final p0Left = k(LogicalKeyboardKey.keyA) ||
        k(LogicalKeyboardKey.arrowLeft);
    final p0Right = k(LogicalKeyboardKey.keyD) ||
        k(LogicalKeyboardKey.arrowRight);
    final p0Up = k(LogicalKeyboardKey.keyW) ||
        k(LogicalKeyboardKey.arrowUp);
    final p0Down = k(LogicalKeyboardKey.keyS) ||
        k(LogicalKeyboardKey.arrowDown);
    final p0Jump = k(LogicalKeyboardKey.keyX) ||
        k(LogicalKeyboardKey.gameButtonB) ||
        k(LogicalKeyboardKey.gameButtonY) ||
        k(LogicalKeyboardKey.gameButtonLeft1);

    if (mode == 2) {
      pads[0].kLeft = p0Left;
      pads[0].kRight = p0Right;
      pads[0].kUp = p0Up;
      pads[0].kDown = p0Down;
      pads[0].kJump = p0Jump || k(LogicalKeyboardKey.keyQ);
      pads[1].kLeft = k(LogicalKeyboardKey.arrowLeft);
      pads[1].kRight = k(LogicalKeyboardKey.arrowRight);
      pads[1].kUp = k(LogicalKeyboardKey.arrowUp);
      pads[1].kDown = k(LogicalKeyboardKey.arrowDown);
      pads[1].kJump = k(LogicalKeyboardKey.shiftRight);
    } else {
      pads[0].kLeft = p0Left;
      pads[0].kRight = p0Right;
      pads[0].kUp = p0Up;
      pads[0].kDown = p0Down;
      pads[0].kJump = p0Jump;
      pads[1].kLeft = pads[1].kRight = pads[1].kUp = pads[1].kDown = false;
      pads[1].kJump = false;
    }
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      final isHitKey = key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.keyZ ||
          key == LogicalKeyboardKey.gameButtonA ||
          key == LogicalKeyboardKey.gameButtonX ||
          key == LogicalKeyboardKey.gameButtonRight1 ||
          key == LogicalKeyboardKey.gameButtonRight2;
      if (mode == 2) {
        if (isHitKey) pads[0].hitBuf = 0.25;
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) {
          pads[1].hitBuf = 0.25;
        }
      } else if (isHitKey) {
        pads[0].hitBuf = 0.25;
      }
      if (key == LogicalKeyboardKey.keyC) {
        toggleArena();
      }
      if (key == LogicalKeyboardKey.keyM) {
        toggleMusic();
      }
      if (key == LogicalKeyboardKey.keyN) {
        toggleNextMusicTrack();
      }
      final isStartKey = key == LogicalKeyboardKey.keyP ||
          key == LogicalKeyboardKey.escape ||
          key == LogicalKeyboardKey.gameButtonStart ||
          key == LogicalKeyboardKey.gameButtonSelect;
      if (isStartKey) {
        togglePause();
      }
    }
    return KeyEventResult.handled;
  }

  // ============================================================
  //  IA / PAPÉIS
  // ============================================================
  double _baseXFor(Player p, bool forServe) {
    if (forServe && p.team == serving && p.slot == 0) {
      return p.team == 0 ? 45 : kL - 45;
    }
    final b = p.slot == 0 ? 150.0 : 330.0;
    return p.team == 0 ? b : kL - b;
  }

  double _baseYFor(Player p, bool forServe) {
    if (forServe && p.team == serving && p.slot == 0) return kWd * 0.5;
    return p.slot == 0 ? kWd * 0.66 : kWd * 0.30;
  }

  double _baseX(Player p) => _baseXFor(p, phase == Phase.serving);
  double _baseY(Player p) => _baseYFor(p, phase == Phase.serving);

  bool _eligible(Player p) =>
      touches[p.team] < 3 &&
      !(lastToucher == p && lastTeam == p.team && touches[p.team] > 0);

  Player? _pick(List<Player> mates, double x, double y) {
    double d(Player p) {
      final dx = p.x - x, dy = p.y - y;
      return math.sqrt(dx * dx + dy * dy);
    }

    Player? best;
    for (final m in mates) {
      if (!_eligible(m)) continue;
      if (best == null || d(m) < d(best)) best = m;
    }
    final cur = controlled[mates.first.team];
    if (best != null &&
        cur != null &&
        cur != best &&
        _eligible(cur) &&
        d(cur) <= d(best) + 45) {
      best = cur;
    }
    return best;
  }

  /// Prevê onde (x, y) e quando (t) a bola desce passando pela altura [zz].
  Pred _predict(double zz) {
    final pred = BallPhysicsEngine.predict(ball, zz);
    return Pred(pred.x, pred.y, pred.t);
  }

  void _rerollAi() {
    for (final p in players) {
      final l = _lvl(p.team);
      p.errX = (_rnd.nextDouble() * 2 - 1) * (1 - l) * 80;
      p.errY = (_rnd.nextDouble() * 2 - 1) * (1 - l) * 65;
      p.jumpErr = (_rnd.nextDouble() * 2 - 1) * (1 - l) * 0.1;
    }
  }

  void _assignRoles() {
    for (final team in const [0, 1]) {
      final mates = players.where((p) => p.team == team).toList();
      final dirN = team == 0 ? 1.0 : -1.0; // sentido da rede
      final lvl = _lvl(team);
      marker[team] = null;
      for (final p in mates) {
        p.wJump = false;
        p.wHit = false;
        p.tx = _baseX(p);
        p.ty = _baseY(p);
      }
      Player? primary;

      if (phase == Phase.serving) {
        if (team == serving) primary = _server;
      } else if (phase == Phase.rally) {
        final land = _predict(kBR);
        final comingToMe = team == 0 ? land.x < kMid + 30 : land.x > kMid - 30;
        final out = outgoing && lastTeam == team;
        final myBall = !out &&
            (ballSide == team || comingToMe) &&
            (lastTeam != team || touches[team] == 0);

        if (myBall) {
          // RECEPÇÃO
          final pr = _predict(62);
          primary = _pick(mates, pr.x, pr.y);
          if (_isHumanTeam(team) && primary != null) marker[team] = pr;
          if (primary != null) {
            primary.tx = pr.x + primary.errX;
            primary.ty = pr.y + primary.errY;
            primary.wHit = true;
          }
          for (final o in mates) {
            if (o != primary) {
              o.tx = _baseX(o);
              o.ty = _baseY(o);
            }
          }
        } else if (!out &&
            lastTeam == team &&
            ballSide == team &&
            touches[team] == 1) {
          // LEVANTAMENTO
          final pr = _predict(70);
          primary = _pick(mates, pr.x, pr.y);
          if (_isHumanTeam(team) && primary != null) marker[team] = pr;
          if (primary != null) {
            primary.tx = pr.x + primary.errX * 0.5;
            primary.ty = pr.y + primary.errY * 0.5;
            primary.wHit = true;
          }
          for (final o in mates) {
            if (o != primary) {
              o.tx = _baseX(o);
              o.ty = _baseY(o);
            }
          }
        } else if (!out &&
            lastTeam == team &&
            ballSide == team &&
            touches[team] == 2) {
          // ATAQUE
          final pr = _predict(150);
          primary = _pick(mates, pr.x, pr.y);
          if (_isHumanTeam(team) && primary != null) marker[team] = pr;
          if (primary != null) {
            primary.tx = pr.x - dirN * 10 + primary.errX * 0.5;
            primary.ty = pr.y + primary.errY * 0.5;
            primary.wHit = !primary.onGround || bz < 90;
            final ddx = primary.x - primary.tx, ddy = primary.y - primary.ty;
            if (primary.onGround &&
                math.sqrt(ddx * ddx + ddy * ddy) < 80 &&
                pr.t < 0.34 + primary.jumpErr) {
              primary.wJump = true;
            }
          }
        } else if (lastTeam != team) {
          // DEFESA / BLOQUEIO NA REDE
          final opp = 1 - team;
          final isOppAttacking = (touches[opp] >= 1 && ballSide == opp) ||
              (team == 0 ? bvx < -120 : bvx > 120);
          final blocker = mates.firstWhere((m) => m.slot == 1);
          if (isOppAttacking) {
            blocker.tx = kMid - dirN * 32;
            blocker.ty = by.clamp(25.0, kWd - 25).toDouble();
            final pr = _predict(148);
            if (blocker.onGround &&
                (bx - kMid).abs() < 220 &&
                bz > 105 &&
                pr.t < 0.50 + blocker.jumpErr) {
              blocker.wJump = true;
            }
          }
        }
      }
      controlled[team] = primary ?? controlled[team] ?? mates.first;
    }
  }

  // ============================================================
  //  JOGADORES
  // ============================================================
  void _updatePlayers(double dt) {
    for (final p in players) {
      final pad = pads[p.team];
      p.human = _isHumanTeam(p.team) && controlled[p.team] == p;
      final lvl = _lvl(p.team);
      double mx = 0, my = 0;
      bool jump = false, wantHit = false;
      if (p.human) {
        mx = pad.dx; // analógico (joystick/gamepad) ou teclado
        my = pad.dy;
        jump = pad.jump;
        wantHit = pad.hitBuf > 0;
      } else {
        final dx = p.tx - p.x, dy = p.ty - p.y;
        if (dx.abs() > 6) mx = dx.sign * math.min(1.0, dx.abs() / 20);
        if (dy.abs() > 6) my = dy.sign * math.min(1.0, dy.abs() / 20);
        jump = p.wJump;
        wantHit = p.wHit;
      }
      p.moving = mx != 0 || my != 0;
      final len = math.sqrt(mx * mx + my * my);
      if (len > 1) {
        mx /= len;
        my /= len;
      }
      final spd = p.human
          ? 290.0
          : (_isHumanTeam(p.team) ? 150 + 170 * lvl : 100 + 150 * lvl);
      final airK = p.onGround ? 1.0 : 0.6;
      p.x += mx * spd * airK * dt;
      p.y += my * spd * airK * dt;

      final lo = p.team == 0 ? -25.0 : kMid + 16;
      final hi = p.team == 0 ? kMid - 16 : kL + 25.0;
      p.x = p.x.clamp(lo, hi).toDouble();
      p.y = p.y.clamp(-30.0, kWd + 30).toDouble();

      final isServer = phase == Phase.serving && p == _server;
      if (isServer) {
        final maxServeX = ballTossed ? 220.0 : 110.0;
        p.x = (p.team == 0
                ? p.x.clamp(5.0, maxServeX)
                : p.x.clamp(kL - maxServeX, kL - 5.0))
            .toDouble();
        p.y = p.y.clamp(25.0, kWd - 25).toDouble();
        if (ballTossed && jump && !p.jumpHeld && p.jumpCd <= 0 && p.onGround) {
          p.vz = kJump;
          p.jumpHeld = true;
          p.jumpCd = 0.22;
        }
      } else if (jump && !p.jumpHeld && p.jumpCd <= 0 && p.onGround) {
        p.vz = kJump;
        p.jumpHeld = true;
        p.jumpCd = 0.22;
        // Bloqueio cooperativo na rede: quando o jogador humano salta, o parceiro em frente à rede
        // também salta para formar o duplo paredão de bloqueio caso a bola esteja se aproximando
        if (p.human && _isHumanTeam(p.team)) {
          final netMate = players.firstWhere(
            (m) => m.team == p.team && m.slot == 1,
            orElse: () => p,
          );
          if (netMate != p && netMate.onGround && netMate.jumpCd <= 0 && (bx - kMid).abs() < 280) {
            netMate.vz = kJump;
            netMate.jumpHeld = true;
            netMate.jumpCd = 0.22;
          }
        }
      }
      if (!jump) {
        p.jumpHeld = false;
      }
      p.jumpCd = math.max(0, p.jumpCd - dt);

      if (!p.onGround || p.vz > 0) {
        p.vz -= kPG * dt;
        p.z += p.vz * dt;
        if (p.z <= 0) {
          p.z = 0;
          p.vz = 0;
        }
      }
      p.hitCd = math.max(0, p.hitCd - dt);
      p.swing = math.max(0, p.swing - dt);
      if (wantHit && p.hitCd <= 0) _tryHit(p);
    }
  }

  void _tryHit(Player p) {
    if (phase == Phase.serving) {
      if (p == _server) {
        if (!ballTossed) {
          _tossBall(p);
        } else {
          final face = p.team == 0 ? 1.0 : -1.0;
          final hx = p.x + face * 10;
          final hz = p.z + (p.onGround ? 65 : 86);
          final dx = bx - hx, dy = (by - p.y) * 0.8, dz = bz - hz;
          final reach = p.onGround ? 120.0 : 135.0;
          if (dx * dx + dy * dy + dz * dz <= reach * reach) {
            if (p.human && !p.onGround && pads[p.team].hitBuf > 0.05 && p.vz > 220 && bz > hz + 20) {
              return;
            }
            _spikeServe(p);
          }
        }
      }
      return;
    }
    if (phase != Phase.rally || !_eligible(p)) return;
    final face = p.team == 0 ? 1.0 : -1.0;
    final hx = p.x + face * 10;
    final hz = p.z + (p.onGround ? 65 : 86);
    final dx = bx - hx, dy = (by - p.y) * 0.8, dz = bz - hz;
    final reach = p.human ? (p.onGround ? 115.0 : 125.0) : (p.onGround ? 85.0 : 95.0);
    if (dx * dx + dy * dy + dz * dz > reach * reach) return;
    if (p.human && !p.onGround && pads[p.team].hitBuf > 0.05 && p.vz > 220 && bz > hz + 20) {
      return;
    }
    _hit(p);
  }

  /// direção horizontal da mira: -1 (curto) .. +1 (longo)
  double _aimX(Player p) {
    final dirOpp = p.team == 0 ? 1.0 : -1.0;
    if (p.human) return pads[p.team].dx * dirOpp;
    final l = _lvl(p.team);
    final a =
        -0.2 + _rnd.nextDouble() * 1.2 + (_rnd.nextDouble() - 0.5) * (1 - l);
    return a.clamp(-1.0, 1.0).toDouble();
  }

  /// direção de profundidade da mira: -1 (fundo) .. +1 (perto da câmera)
  double _aimY(Player p) {
    if (p.human) return pads[p.team].dy;
    return (_rnd.nextDouble() * 2 - 1) * 0.9;
  }

  void _hit(Player p) {
    final t = p.team;
    final dirOpp = t == 0 ? 1.0 : -1.0;
    final aimX = _aimX(p);
    final aimY = _aimY(p);
    final idx = touches[t];
    final air = !p.onGround;
    final nearNet = (bx - kMid).abs() < 260;
    final gyT = (kWd * 0.5 + aimY * kWd * 0.40).clamp(20.0, kWd - 20).toDouble();
    final gyP = (kWd * 0.5 + aimY * kWd * 0.25).clamp(20.0, kWd - 20).toDouble();

    final dist2D = math.sqrt((bx - p.x) * (bx - p.x) + (by - p.y) * (by - p.y));

    // Passe para companheiro só ocorre se o jogador puxar o direcional explicitamente para trás (aimX < -0.45)
    final wantPassToMate = p.human ? (aimX < -0.45 && idx == 0) : (!air && idx == 0 && _rnd.nextDouble() < 0.45);

    if (air && nearNet && bz > kNetH - 25) {
      // CORTADA POTENTE (Spike) - Ataque aéreo direto para a quadra adversária!
      final eval = TimingEvaluator.evaluateSpike(
        ballZ: bz,
        playerZ: p.z,
        playerVz: p.vz,
        dist2D: dist2D,
      );

      final effAimX = aimX * eval.accuracyFactor;
      final targetX = kMid + dirOpp * (70 + 330 * (effAimX + 1) / 2);

      BallPhysicsEngine.launchFast(
        ball,
        tx: targetX,
        ty: gyT,
        tz: BallPhysicsEngine.kBR,
        topspin: eval.topspin,
        speedMultiplier: eval.speedMultiplier,
      );
      outgoing = true;
      ArcadeAudio.playSpike(perfect: eval.isPerfect);
      if (_isHumanTeam(t) && eval.isPerfect) {
        crowd = 1.8;
        ArcadeAudio.playCrowdCheer(big: false);
        ArcadeAudio.playApplause();
      }

      if (eval.hitstopDuration > 0) {
        hitstop.trigger(eval.hitstopDuration);
      }
      cameraShake.addTrauma(eval.shakeTrauma);
      shake = math.max(shake, eval.isPerfect ? 8.0 : 5.0);

      _msg(eval.isPerfect ? 'CORTADA PERFEITA!' : 'CORTADA!', 0.7);
      timingPopups.add(
        text: eval.label,
        position: Offset(_sx(p.x, p.y), _sy(p.y, p.z) - 52),
        color: eval.color,
      );

      final sparkCount = eval.isPerfect ? 24 : 14;
      final sparkColor = eval.isPerfect ? const Color(0xFFFFD600) : const Color(0xFFFFEB3B);
      _sparkBall(sparkCount, sparkColor, eval.isPerfect ? 260 : 200);
      ballSquashFactor = eval.isPerfect ? 1.45 : 1.30;
      ballSquashTime = 0.12;
    } else if (wantPassToMate) {
      // PASSE PARA COMPANHEIRO DE TIME
      final eval = TimingEvaluator.evaluateGroundTouch(dist2D: dist2D, touchIndex: 0);
      BallPhysicsEngine.launchTo(
        ball,
        tx: kMid - dirOpp * (140 - 20 * aimX),
        ty: gyP,
        tz: 75,
        apexZ: 240,
        topspin: -3.0,
      );
      outgoing = false;
      ArcadeAudio.playTouch();
      cameraShake.addTrauma(eval.shakeTrauma);
      timingPopups.add(
        text: 'PASSE',
        position: Offset(_sx(p.x, p.y), _sy(p.y, p.z) - 44),
        color: const Color(0xFF40C4FF),
      );
      ballSquashFactor = 1.15;
      ballSquashTime = 0.08;
    } else {
      // ARREMESSO / DEVOLUÇÃO DIRETA PARA A QUADRA ADVERSÁRIA (SEM DEPENDER DO COMPANHEIRO)
      final eval = TimingEvaluator.evaluateGroundTouch(dist2D: dist2D, touchIndex: idx);
      final targetX = kMid + dirOpp * (100 + 290 * (aimX + 1) / 2);
      BallPhysicsEngine.launchTo(
        ball,
        tx: targetX,
        ty: gyT,
        tz: BallPhysicsEngine.kBR,
        apexZ: 245,
        topspin: 8.0,
      );
      outgoing = true;
      ArcadeAudio.playTouch();

      cameraShake.addTrauma(eval.shakeTrauma * 0.7);
      timingPopups.add(
        text: eval.label,
        position: Offset(_sx(p.x, p.y), _sy(p.y, p.z) - 44),
        color: eval.color,
      );
      ballSquashFactor = 1.20;
      ballSquashTime = 0.08;
    }

    lastTeam = t;
    lastToucher = p;
    touches[t]++;
    p.hitCd = 0.3;
    p.swing = 0.25;
    pads[t].hitBuf = 0;
    _sparkBall(6, Colors.white, 120);
    _rerollAi();
  }

  void _tossBall(Player p) {
    ballTossed = true;
    ballHeld = false;
    serveTossTimer = 0.0;
    final dirOpp = p.team == 0 ? 1.0 : -1.0;
    bx = p.x + dirOpp * 18;
    by = p.y;
    bz = p.z + 85;
    bvx = dirOpp * 75.0;
    bvy = 0.0;
    bvz = 390.0;
    ball.topspin = 0;
    p.swing = 0.2;
    pads[p.team].hitBuf = 0;
    ArcadeAudio.playTouch();
    _sparkBall(5, Colors.white70, 70);
    _msg('CORRA, SALTE E CORTE NO AR!', 1.2);
  }

  void _spikeServe(Player p) {
    final t = p.team;
    final dirOpp = t == 0 ? 1.0 : -1.0;
    final aimX = _aimX(p);
    final aimY = _aimY(p);
    final air = !p.onGround;
    final dist2D = math.sqrt((bx - p.x) * (bx - p.x) + (by - p.y) * (by - p.y));

    if (air) {
      // SAQUE VIAGEM (Jump Spike Serve)
      final eval = TimingEvaluator.evaluateSpike(
        ballZ: bz,
        playerZ: p.z,
        playerVz: p.vz,
        dist2D: dist2D,
      );

      final effAimX = aimX * eval.accuracyFactor;
      final targetX = kMid + dirOpp * (120 + 310 * (effAimX + 1) / 2);
      final targetY =
          (kWd * 0.5 + aimY * kWd * 0.40).clamp(25.0, kWd - 25).toDouble();

      BallPhysicsEngine.launchFast(
        ball,
        tx: targetX,
        ty: targetY,
        tz: BallPhysicsEngine.kBR,
        topspin: eval.topspin * 1.35,
        speedMultiplier: eval.speedMultiplier * 1.15,
      );

      if (eval.hitstopDuration > 0) {
        hitstop.trigger(eval.hitstopDuration);
      }
      cameraShake.addTrauma(math.max(0.40, eval.shakeTrauma));
      shake = math.max(shake, eval.isPerfect ? 8.0 : 5.0);

      final sx = _sx(bx, by);
      final sy = _sy(by, bz);
      timingPopups.add(
        text: eval.label,
        position: Offset(sx, sy - 40),
        color: eval.color,
      );

      ArcadeAudio.playSpike(perfect: eval.isPerfect);
      if (_isHumanTeam(t) && eval.isPerfect) {
        crowd = 2.0;
        ArcadeAudio.playCrowdCheer(big: true);
        ArcadeAudio.playApplause();
      }
      _msg(eval.isPerfect ? 'SAQUE VIAGEM PERFEITO!!' : 'SAQUE VIAGEM!', 1.3);
      final sparkCount = eval.isPerfect ? 24 : 14;
      final sparkColor =
          eval.isPerfect ? const Color(0xFFFFD600) : const Color(0xFFFF9100);
      _sparkBall(sparkCount, sparkColor, eval.isPerfect ? 260 : 200);
      ballSquashFactor = eval.isPerfect ? 1.45 : 1.30;
      ballSquashTime = 0.12;
    } else {
      // SAQUE FLUTUANTE (No chão)
      var tx = kMid + dirOpp * (120 + 300 * (aimX + 1) / 2);
      final ty =
          (kWd * 0.5 + aimY * kWd * 0.40).clamp(25.0, kWd - 25).toDouble();
      if (!p.human && _rnd.nextDouble() < (1 - _lvl(p.team)) * 0.30) {
        tx += dirOpp * 260; // erro IA
      }
      BallPhysicsEngine.launchTo(
        ball,
        tx: tx,
        ty: ty,
        tz: BallPhysicsEngine.kBR,
        apexZ: 285,
        topspin: 5.0,
      );
      ArcadeAudio.playTouch();
      _msg('SAQUE FLUTUANTE', 1.0);
      _sparkBall(6, Colors.white, 120);
      ballSquashFactor = 1.25;
      ballSquashTime = 0.08;
    }

    ballHeld = false;
    ballTossed = false;
    phase = Phase.rally;
    lastTeam = p.team;
    lastToucher = p;
    touches[0] = 0;
    touches[1] = 0;
    outgoing = true;
    ballSide = bx < kMid ? 0 : 1;
    p.swing = 0.3;
    pads[p.team].hitBuf = 0;
    ArcadeAudio.playWhistle();
    _rerollAi();
  }

  void _updateAiServe(Player s, double dt) {
    final lvl = _lvl(s.team);
    final dirOpp = s.team == 0 ? 1.0 : -1.0;
    final wantsJumpSpike = lvl > 0.4 || (lvl > 0.2 && _rnd.nextDouble() < 0.6);

    if (wantsJumpSpike) {
      final targetX = bx - dirOpp * 10;
      if ((targetX - s.x).abs() > 6) {
        s.x += dirOpp * 140 * dt;
      }
      s.y = by;

      if (s.onGround && serveTossTimer >= 0.28 && bvz < 180) {
        s.vz = kJump;
        s.jumpHeld = true;
      }

      if (!s.onGround && s.vz <= 80 && (bz - (s.z + 86)).abs() < 55) {
        _spikeServe(s);
      }
    } else {
      s.x = (bx - dirOpp * 12);
      s.y = by;
      if (serveTossTimer >= 0.45 && bz < 115) {
        _spikeServe(s);
      }
    }
  }

  // ============================================================
  //  BOLA
  // ============================================================
  void _stepBall(double dt) {
    BallPhysicsEngine.step(
      ball,
      dt,
      onNetCollision: (isTape) {
        if (phase == Phase.rally) {
          ArcadeAudio.playBlock();
          if (isTape) {
            cameraShake.addTrauma(0.35);
            _msg('NA FITA!', 0.6);
            _sparkBall(6, Colors.white, 90);
          } else {
            cameraShake.addTrauma(0.45);
            shake = math.max(shake, 3);
            _sparkBall(8, Colors.white70, 90);
          }
          motionTrail.clear();
        }
      },
      onGroundCollision: (impactSpeed) {
        if (phase == Phase.rally) _ballLanded();
        if (phase == Phase.serving && ballTossed) {
          ballTossed = false;
          ArcadeAudio.playBounce();
          _point(1 - serving, 'FALTA NO SAQUE! ');
        }
        if (impactSpeed > 100) {
          ArcadeAudio.playBounce();
          _sparkBall(10, const Color(0xFFE8B070), 120);
          cameraShake.addTrauma(0.25);
          ballSquashFactor = 1.35;
          ballSquashTime = 0.10;
        }
        motionTrail.clear();
      },
    );

    // Troca de lado: zera os toques
    final s = bx < kMid ? 0 : 1;
    if (s != ballSide) {
      ballSide = s;
      touches[0] = 0;
      touches[1] = 0;
      outgoing = false;
    }
  }

  void _blockCheck() {
    if (blockCd > 0 || phase != Phase.rally) return;
    for (final p in players) {
      // Bloqueador precisa ter saltado e estar posicionado em frente à rede
      if (p.onGround || (p.x - kMid).abs() > 140) continue;

      // Bola vindo do oponente em direção à quadra deste jogador
      final towards = p.team == 0 ? bvx < 0 : bvx > 0;
      if (!towards) continue;

      // Bola na região da rede entre o oponente e o jogador
      final inX = p.team == 0
          ? (bx >= p.x - 30 && bx <= kMid + 95)
          : (bx <= p.x + 30 && bx >= kMid - 95);
      if (!inX) continue;

      // Alcance lateral dos braços estendidos do bloqueador
      final inY = (by - p.y).abs() <= 70.0;
      if (!inY) continue;

      // Alcance vertical: bola na altura da rede ou nos braços do bloqueador saltando
      final inZ = bz >= kNetH - 35 && bz <= p.z + 125;
      if (!inZ) continue;

      final eval = TimingEvaluator.evaluateBlock(
        ballSpeed: ball.speed,
        playerZ: p.z,
        ballZ: bz,
      );

      final dirOpp = p.team == 0 ? 1.0 : -1.0;
      final blockSpeed = math.max(ball.speed * 0.90, 560.0);
      bvx = dirOpp * blockSpeed;
      bvy = (by - p.y) * 1.3;
      bvz = -150.0; // Bola cravada para baixo na quadra adversária!
      lastTeam = p.team;
      ballSide = 1 - p.team;
      touches[p.team] = 0;
      touches[1 - p.team] = 0;
      outgoing = true;
      blockCd = 0.35;

      hitstop.trigger(eval.hitstopDuration);
      cameraShake.addTrauma(eval.shakeTrauma);
      shake = math.max(shake, 7);
      _msg('MONSTER BLOCK! 🧱', 1.0);
      ArcadeAudio.playBlock();
      if (_isHumanTeam(p.team)) {
        crowd = 2.0;
        ArcadeAudio.playCrowdCheer(big: true);
        ArcadeAudio.playApplause();
      }
      timingPopups.add(
        text: 'MONSTER BLOCK! 🧱',
        position: Offset(_sx(p.x, p.y), _sy(p.y, p.z) - 55),
        color: const Color(0xFFFFD600),
      );
      _sparkBall(22, Colors.amberAccent, 240);
      motionTrail.clear();
      break;
    }
  }

  void _ballLanded() {
    final inBounds = bx >= 0 && bx <= kL && by >= 0 && by <= kWd;
    final scorer = inBounds ? (bx < kMid ? 1 : 0) : 1 - lastTeam;
    _point(scorer, inBounds ? '' : 'FORA!  ');
  }

  void _point(int scorer, String prefix) {
    score[scorer]++;
    serving = scorer;
    phase = Phase.pointPause;
    _pauseTimer = 1.7;
    ArcadeAudio.playWhistle();

    final isPlayerPoint = _isHumanTeam(scorer);
    if (isPlayerPoint) {
      consecutivePlayerPoints++;
      crowd = 2.0;
      final big = score[scorer] >= 14 || consecutivePlayerPoints >= 2;
      ArcadeAudio.playPointCheer(perfect: big);
      _sparkBall(18, Colors.amber, 200);
    } else {
      consecutivePlayerPoints = 0;
      crowd = 0.5;
    }

    _msg('$prefix PONTO ${teams[scorer].name}!', 1.6);
  }

  void _afterPoint() {
    final a = score[0], b = score[1];
    final mx = math.max(a, b);
    if ((mx >= 15 && (a - b).abs() >= 2) || mx >= 21) {
      _endMatch();
    } else {
      _nextServe();
    }
  }

  // ---------- partículas (em coordenadas de tela) ----------
  void _sparkBall(int n, Color color, double speed) {
    final sx = _sx(bx, by), sy = _sy(by, bz);
    for (var i = 0; i < n; i++) {
      final a = _rnd.nextDouble() * 2 * math.pi;
      final s = speed * 0.6 * (0.3 + _rnd.nextDouble());
      sparks.add(Spark(sx, sy, math.cos(a) * s, math.sin(a) * s - 30,
          0.4 + _rnd.nextDouble() * 0.4, 2 + _rnd.nextDouble() * 2.5, color));
    }
    if (sparks.length > 200) sparks.removeRange(0, sparks.length - 200);
  }

  // ============================================================
  //  ATUALIZAÇÃO
  // ============================================================
  @override
  void update(double dt) {
    super.update(dt);
    dt = math.min(dt, 1 / 30);
    time += dt;

    // Atualização dos subsistemas de efeitos
    cameraShake.update(dt);
    timingPopups.update(dt);
    motionTrail.update(dt);
    if (ballSquashTime > 0) {
      ballSquashTime = math.max(0.0, ballSquashTime - dt);
    }

    if (phase == Phase.rally && !ballHeld) {
      motionTrail.addSample(
        screenPos: Offset(_sx(bx, by), _sy(by, bz)),
        radius: 15 * _sc(by),
        speed: ball.speed,
        color: ball.topspin.abs() > 14.0
            ? const Color(0xFFFFD54F)
            : const Color(0xFF81D4FA),
      );
    }

    for (final s in sparks) {
      s.life -= dt;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.vy += 300 * dt;
    }
    sparks.removeWhere((s) => s.life <= 0);
    shake = math.max(0, shake - 25 * dt);
    crowd = math.max(0, crowd - dt);
    if (_msgTimer > 0) _msgTimer -= dt;

    // Leitura contínua de controles (Gamepad API no navegador e desktop)
    GamepadReader.poll(
      onGamepadState:
          (playerIndex, ax, ay, left, right, up, down, jump, hit, start) {
        final targetIndex = (mode == 2) ? playerIndex : 0;
        if (targetIndex >= pads.length) return;
        final pad = pads[targetIndex];

        // Seta e reseta a cada frame para o gamepad não travar valores
        pad.ax = ax;
        pad.ay = ay;
        pad.gLeft = left;
        pad.gRight = right;
        pad.gUp = up;
        pad.gDown = down;
        pad.gJump = jump;

        if (hit) {
          pad.hitBuf = 0.25;
        }

        if (start) {
          if (phase == Phase.menu) {
            startMatch(0);
          } else {
            togglePause();
          }
        }
      },
    );

    if (paused || phase == Phase.menu || phase == Phase.matchOver) return;
    for (final pad in pads) {
      pad.hitBuf = math.max(0, pad.hitBuf - dt);
    }

    // Micro-pausa / Hitstop nos impactos fortes (cortadas e bloqueios)
    if (hitstop.update(dt)) {
      return;
    }

    if (phase == Phase.serving) {
      _assignRoles();
      _updatePlayers(dt);
      if (phase == Phase.serving) {
        final s = _server;
        if (!ballTossed) {
          _placeBallOnServer();
          bvx = 0;
          bvy = 0;
          bvz = 0;
          _serveTimer -= dt;
          if (!_isHumanTeam(s.team) && _serveTimer <= 0) {
            _tossBall(s);
          }
        } else {
          serveTossTimer += dt;
          for (var i = 0; i < 3; i++) {
            _stepBall(dt / 3);
            if (phase != Phase.serving) break;
          }
          if (phase == Phase.serving) {
            if (bz <= BallPhysicsEngine.kBR + 2) {
              ballTossed = false;
              ArcadeAudio.playBounce();
              _point(1 - s.team, 'FALTA NO SAQUE! ');
            } else if (!_isHumanTeam(s.team)) {
              _updateAiServe(s, dt);
            }
          }
        }
      }
    } else if (phase == Phase.rally) {
      _assignRoles();
      _updatePlayers(dt);
      for (var i = 0; i < 3; i++) {
        _stepBall(dt / 3);
        _blockCheck();
        if (phase != Phase.rally) break;
      }
    } else if (phase == Phase.pointPause) {
      for (final p in players) {
        if (!p.onGround || p.vz > 0) {
          p.vz -= kPG * dt;
          p.z += p.vz * dt;
          if (p.z <= 0) {
            p.z = 0;
            p.vz = 0;
          }
        }
      }
      for (var i = 0; i < 3; i++) {
        _stepBall(dt / 3);
      }
      _pauseTimer -= dt;
      if (_pauseTimer <= 0) _afterPoint();
    }
  }

  // ============================================================
  //  DESENHO (8-bit: sem suavização, blocos e contorno escuro)
  // ============================================================
  Paint _fill(Color c) => Paint()
    ..color = c
    ..isAntiAlias = true;

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  void _text(Canvas canvas, String s, Offset pos,
      {double fs = 16,
      Color color = Colors.white,
      FontWeight w = FontWeight.w900,
      int align = 0}) {
    if (s.isEmpty) return;
    try {
      final shadowDist = fs >= 22 ? 1.5 : 1.0;
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            color: color,
            fontSize: fs,
            fontWeight: w,
            fontFamily: 'sans-serif',
            letterSpacing: 0.6,
            shadows: [
              Shadow(
                offset: Offset(shadowDist, shadowDist),
                blurRadius: fs >= 18 ? 2.0 : 1.0,
                color: Colors.black,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = align == 1 ? tp.width / 2 : (align == 2 ? tp.width : 0.0);
      tp.paint(canvas, pos - Offset(dx, 0));
    } catch (_) {}
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x <= 0) return;
    final s = math.min(size.x / kW, size.y / kH);
    final ox = (size.x - kW * s) / 2;
    // em telas altas (celular em pé) a quadra sobe, deixando espaço p/ os botões
    final oy = (size.y - kH * s) * 0.3;
    vx0 = -ox / s;
    vx1 = kW + ox / s;
    vy0 = -oy / s;
    vy1 = (size.y - oy) / s;

    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y), _fill(const Color(0xFF0B1038)));

    canvas.save();
    canvas.translate(ox, oy);
    canvas.scale(s);

    final shakeOffset = cameraShake.getOffset(_rnd);
    if (shakeOffset != Offset.zero || shake > 0) {
      final legX = shake > 0 ? (_rnd.nextDouble() - 0.5) * shake : 0.0;
      final legY = shake > 0 ? (_rnd.nextDouble() - 0.5) * shake : 0.0;
      canvas.translate(shakeOffset.dx + legX, shakeOffset.dy + legY);
    }

    _drawBackground(canvas);
    _drawCourt(canvas);
    _drawLineJudges(canvas);
    _drawShadows(canvas);
    _drawMarkers(canvas);

    // objetos ordenados por profundidade (quem está mais longe é desenhado primeiro)
    final items = <_Item>[];
    items.add(_Item(-40, () => _drawReferee(canvas)));
    items.add(_Item(-6, () => _drawPost(canvas, -6, false)));
    items.add(_Item(kWd + 8, () => _drawPost(canvas, kWd + 8, true)));
    // Antenas regulamentares de vôlei nos limites laterais da rede
    items.add(_Item(-2, () => CourtRenderer.drawAntenna(
          canvas: canvas,
          sc: _sc,
          sy: _sy,
          cx: kW / 2,
          gy: -2,
          kNetH: kNetH,
        )));
    items.add(_Item(kWd + 2, () => CourtRenderer.drawAntenna(
          canvas: canvas,
          sc: _sc,
          sy: _sy,
          cx: kW / 2,
          gy: kWd + 2,
          kNetH: kNetH,
        )));
    const n = 8;
    for (var i = 0; i < n; i++) {
      final g0 = kWd * i / n, g1 = kWd * (i + 1) / n;
      items.add(_Item((g0 + g1) / 2, () => _drawNetSlice(canvas, g0, g1)));
    }
    for (final p in players) {
      items.add(_Item(p.y, () => _drawPlayer(canvas, p)));
    }
    // Rastro da bola desenhado logo atrás da bola
    items.add(_Item(by - 0.1, () => motionTrail.render(canvas)));
    items.add(_Item(by, () => _drawBall(canvas)));
    items.sort((a, b) => a.depth.compareTo(b.depth));
    for (final it in items) {
      it.draw();
    }

    // Popups de timing do golpe renderizados na tela
    timingPopups.render(canvas);

    for (final sp in sparks) {
      final a = sp.life / sp.maxLife;
      final sz = (sp.size * a + 1).roundToDouble();
      canvas.drawRect(Rect.fromLTWH(sp.x - sz / 2, sp.y - sz / 2, sz, sz),
          _fill(sp.color));
    }
    _drawHud(canvas);
    canvas.restore();
  }

  void _drawBackground(Canvas canvas) {
    final pp = Paint()..isAntiAlias = true;

    if (isBeach) {
      // ==========================================
      // CENÁRIO: PRAIA TROPICAL (Vôlei de Praia)
      // ==========================================
      // 1. Céu tropical ensolarado com gradiente azul turquesa
      final skyRect = Rect.fromLTRB(vx0, vy0, vx1, 105);
      final skyGrad = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0288D1), Color(0xFF4FC3F7), Color(0xFFB3E5FC)],
        stops: [0.0, 0.65, 1.0],
      ).createShader(skyRect);
      canvas.drawRect(skyRect, Paint()..shader = skyGrad);

      // Sol radiante na praia
      final sunX = vx0 + (vx1 - vx0) * 0.78;
      canvas.drawCircle(Offset(sunX, 42), 34, Paint()..color = const Color(0x33FFF59D));
      canvas.drawCircle(Offset(sunX, 42), 26, Paint()..color = const Color(0x66FFEE58));
      canvas.drawCircle(Offset(sunX, 42), 18, Paint()..color = const Color(0xFFFFF176));

      // Nuvens brancas suaves passando ao vento
      final cloudPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..isAntiAlias = true;
      for (var c = 0; c < 4; c++) {
        final cx = vx0 + ((time * 10 + c * 260) % (vx1 - vx0 + 240)) - 120;
        final cy = 24.0 + (c % 2) * 22;
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: 68, height: 20), cloudPaint);
        canvas.drawOval(Rect.fromCenter(center: Offset(cx - 16, cy + 2), width: 42, height: 16), cloudPaint);
        canvas.drawOval(Rect.fromCenter(center: Offset(cx + 16, cy + 2), width: 42, height: 16), cloudPaint);
      }

      // 2. Mar / Oceano azul tropical com ondas e espuma branca
      canvas.drawRect(Rect.fromLTRB(vx0, 96, vx1, 132), Paint()..color = const Color(0xFF01579B));
      canvas.drawRect(Rect.fromLTRB(vx0, 108, vx1, 132), Paint()..color = const Color(0xFF0277BD));

      // Crista das ondas do oceano com animação
      final wavePath = Path()..moveTo(vx0, 120);
      for (var x = vx0; x <= vx1 + 30; x += 30) {
        final wy = 120.0 + math.sin(time * 2.8 + x * 0.04) * 3.5;
        wavePath.lineTo(x, wy);
      }
      wavePath.lineTo(vx1, 132);
      wavePath.lineTo(vx0, 132);
      wavePath.close();
      canvas.drawPath(wavePath, Paint()..color = const Color(0xFF039BE5));

      // Espuma branca na crista da onda
      final foamPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..isAntiAlias = true;
      final foamPath = Path()..moveTo(vx0, 120);
      for (var x = vx0; x <= vx1 + 30; x += 30) {
        final wy = 120.0 + math.sin(time * 2.8 + x * 0.04) * 3.5;
        foamPath.lineTo(x, wy);
      }
      canvas.drawPath(foamPath, foamPaint);

      // 3. Orla com coqueiros tropicais (Palm Trees)
      for (final px in [vx0 + 55.0, vx0 + 160.0, vx1 - 170.0, vx1 - 65.0]) {
        // Tronco curvado
        final trunk = Path()
          ..moveTo(px, 134)
          ..quadraticBezierTo(px + 10, 105, px + 8, 78)
          ..lineTo(px + 12, 78)
          ..quadraticBezierTo(px + 15, 105, px + 5, 134)
          ..close();
        canvas.drawPath(trunk, Paint()..color = const Color(0xFF5D4037));

        // Folhas verdes do coqueiro
        final palmLeafPaint = Paint()
          ..color = const Color(0xFF2E7D32)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true;

        final top = Offset(px + 10, 78);
        canvas.drawLine(top, top + const Offset(-22, -9), palmLeafPaint);
        canvas.drawLine(top, top + const Offset(-18, 9), palmLeafPaint);
        canvas.drawLine(top, top + const Offset(20, -9), palmLeafPaint);
        canvas.drawLine(top, top + const Offset(18, 9), palmLeafPaint);
        canvas.drawLine(top, top + const Offset(0, -18), palmLeafPaint);
      }

      // 4. Faixa de publicidade praiana / quiosque de verão
      pp.color = const Color(0xFFFFA000);
      canvas.drawRect(Rect.fromLTRB(vx0, 128, vx1, 172), pp);
      pp.color = const Color(0xFFFF8F00);
      canvas.drawRect(Rect.fromLTRB(vx0, 166, vx1, 172), pp);
      _text(canvas, 'SENAC PRAIA', const Offset(190, 134),
          fs: 30, color: const Color(0xFF0D47A1), align: 1);
      _text(canvas, 'VÔLEI DE PRAIA', const Offset(600, 134),
          fs: 30, color: const Color(0xFF0D47A1), align: 1);

      // 5. Areia de praia contínua fora da quadra
      pp.color = const Color(0xFFE5BE6C);
      canvas.drawRect(Rect.fromLTRB(vx0, 172, vx1, vy1), pp);

      // Grãos e textura de areia sutil
      final grainPaint = Paint()
        ..color = const Color(0xFFC99F44).withValues(alpha: 0.35)
        ..isAntiAlias = true;
      for (var y = 180.0; y < vy1; y += 40.0) {
        for (var x = vx0 + 20; x < vx1; x += 55.0) {
          canvas.drawCircle(Offset(x + ((y * 11) % 35), y), 1.5, grainPaint);
        }
      }
    } else {
      // ==========================================
      // CENÁRIO: GINÁSIO OLÍMPICO (Indoor)
      // ==========================================
      // Parede e arquibancada
      pp.color = const Color(0xFF0B1038);
      canvas.drawRect(Rect.fromLTRB(vx0, vy0, vx1, 130), pp);
      pp.color = const Color(0xFF151D55);
      canvas.drawRect(Rect.fromLTRB(vx0, 64, vx1, 130), pp);

      const shirts = [
        Color(0xFF8E3B46),
        Color(0xFFB89B3C),
        Color(0xFF3E7A52),
        Color(0xFF3A6A9E),
        Color(0xFFC9CBD6),
        Color(0xFF6C4A8A),
      ];
      const skins = [Color(0xFFE8B98A), Color(0xFFC68642), Color(0xFF8D5524)];
      const hairs = [Color(0xFF111111), Color(0xFF3E2723), Color(0xFFFFD54F)];
      final i0 = (vx0 / 20).floor() - 1, i1 = (vx1 / 20).ceil() + 1;
      for (var r = 0; r < 3; r++) {
        final y = 70.0 + r * 21;
        pp.color = r.isEven ? const Color(0xFF111850) : const Color(0xFF19225E);
        canvas.drawRect(Rect.fromLTRB(vx0, y + 10, vx1, y + 24), pp);
        for (var i = i0; i <= i1; i++) {
          final x = i * 20.0 + (r % 2) * 10;
          final bob = crowd > 0
              ? (math.sin(time * 14 + i * 1.3 + r) * 5 * crowd.clamp(0.0, 1.0))
                  .roundToDouble()
              : 0.0;
          final h = (i * 7 + r * 13) % 6;
          pp.color = shirts[h];
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromLTWH(x - 7, y + 6 + bob, 14, 12), const Radius.circular(3)),
              pp);
          pp.color = skins[(i + r).abs() % 3];
          canvas.drawOval(Rect.fromLTWH(x - 4, y - 3 + bob, 8, 9), pp);
          pp.color = hairs[(i * 3 + r) % 3];
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromLTWH(x - 4, y - 3 + bob, 8, 3.5), const Radius.circular(1.5)),
              pp);
        }
      }

      // Faixa de publicidade (verde, como no jogo original)
      pp.color = const Color(0xFF1E9E4A);
      canvas.drawRect(Rect.fromLTRB(vx0, 128, vx1, 172), pp);
      pp.color = const Color(0xFF157A38);
      canvas.drawRect(Rect.fromLTRB(vx0, 166, vx1, 172), pp);
      _text(canvas, 'SENAC', const Offset(190, 134),
          fs: 30, color: const Color(0xFFD6EBFF), align: 1);
      _text(canvas, 'VÔLEI ARCADE', const Offset(600, 134),
          fs: 30, color: const Color(0xFFD6EBFF), align: 1);

      // Piso de fora da quadra (azul)
      pp.color = const Color(0xFF4A89CB);
      canvas.drawRect(Rect.fromLTRB(vx0, 172, vx1, vy1), pp);
    }
  }

  void _drawCourt(Canvas canvas) {
    CourtRenderer.drawCourt(
      canvas: canvas,
      sx: _sx,
      sy: _sy,
      kL: kL,
      kWd: kWd,
      kMid: kMid,
      isBeach: isBeach,
    );
  }

  void _drawLineJudges(Canvas canvas) {
    for (final side in const [0, 1]) {
      final gx = side == 0 ? -55.0 : kL + 55.0;
      const gy = -42.0;
      CharacterRenderer.draw(
        canvas: canvas,
        ox: _sx(gx, gy),
        oy: _sy(gy, 0),
        P: 4.0 * _sc(gy),
        face: side == 0 ? 1.0 : -1.0,
        shirtColor: isBeach ? const Color(0xFFFFB300) : Colors.white,
        trimColor: isBeach ? const Color(0xFF0D47A1) : const Color(0xFF222222),
        skinColor: const Color(0xFFE8B98A),
        hairColor: const Color(0xFF3E2723),
        jerseyNumber: '',
        armsUp: false,
        swinging: false,
        air: false,
        moving: false,
        step: -1,
        isBeach: isBeach,
      );
    }
  }

  void _drawReferee(Canvas canvas) {
    const gy = -30.0;
    final sc = _sc(gy);
    final cx = _sx(kMid, gy);
    final base = _sy(gy, 0);
    // pernas da cadeira
    final legColor = isBeach ? const Color(0xFF8D6E63) : const Color(0xFF9EA3AA);
    final leg = _fill(legColor);
    canvas.drawRect(Rect.fromLTRB(cx - 24 * sc, base - 105 * sc, cx - 18 * sc, base), leg);
    canvas.drawRect(Rect.fromLTRB(cx + 18 * sc, base - 105 * sc, cx + 24 * sc, base), leg);
    // plataforma
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(cx - 32 * sc, base - 111 * sc, cx + 32 * sc, base - 103 * sc),
            const Radius.circular(2)),
        _fill(kOutline));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(cx - 30 * sc, base - 109 * sc, cx + 30 * sc, base - 104 * sc),
            const Radius.circular(2)),
        _fill(isBeach ? const Color(0xFF1976D2) : const Color(0xFFE53935)));
    // árbitro em cima
    CharacterRenderer.draw(
      canvas: canvas,
      ox: cx,
      oy: base - 109 * sc,
      P: 4.0 * sc,
      face: 1.0,
      shirtColor: isBeach ? const Color(0xFFFFB300) : Colors.white,
      trimColor: isBeach ? const Color(0xFF0D47A1) : const Color(0xFF222222),
      skinColor: const Color(0xFFE8B98A),
      hairColor: const Color(0xFF3E2723),
      jerseyNumber: '',
      armsUp: false,
      swinging: false,
      air: false,
      moving: false,
      step: -1,
      isBeach: isBeach,
    );
  }

  void _drawPost(Canvas canvas, double gy, bool near) {
    final sc = _sc(gy);
    final cx = kW / 2;
    final base = _sy(gy, 0);
    final top = _sy(gy, kNetH + 16);
    final w = 6 * sc;
    if (isBeach) {
      // Poste de madeira tropical / bambu na praia
      canvas.drawRect(Rect.fromLTRB(cx - w - 1.5, top - 1.5, cx + w + 1.5, base + 1.5),
          _fill(kOutline));
      canvas.drawRect(Rect.fromLTRB(cx - w, top, cx + w, base),
          _fill(const Color(0xFF8D6E63)));
      canvas.drawRect(Rect.fromLTRB(cx - w, top, cx - w * 0.3, base),
          _fill(const Color(0xFFA1887F)));
      if (near) {
        // Almofada protetora da praia (azul royal com amarelo)
        canvas.drawRect(Rect.fromLTRB(cx - w - 3, base - 70 * sc, cx + w + 3, base),
            _fill(kOutline));
        canvas.drawRect(Rect.fromLTRB(cx - w - 1, base - 68 * sc, cx + w + 1, base - 1),
            _fill(const Color(0xFF1976D2)));
      }
    } else {
      // Poste de ginásio
      canvas.drawRect(Rect.fromLTRB(cx - w - 1.5, top - 1.5, cx + w + 1.5, base + 1.5),
          _fill(kOutline));
      canvas.drawRect(Rect.fromLTRB(cx - w, top, cx + w, base),
          _fill(const Color(0xFFB0B5BD)));
      canvas.drawRect(Rect.fromLTRB(cx - w, top, cx - w * 0.3, base), _fill(Colors.white));
      if (near) {
        // protetor vermelho do poste da frente
        canvas.drawRect(Rect.fromLTRB(cx - w - 3, base - 70 * sc, cx + w + 3, base),
            _fill(kOutline));
        canvas.drawRect(Rect.fromLTRB(cx - w - 1, base - 68 * sc, cx + w + 1, base - 1),
            _fill(const Color(0xFFD32F2F)));
      }
    }
  }

  void _drawNetSlice(Canvas canvas, double g0, double g1) {
    CourtRenderer.drawNetSlice(
      canvas: canvas,
      sc: _sc,
      sy: _sy,
      cx: kW / 2,
      g0: g0,
      g1: g1,
      kNetH: kNetH,
      isBeach: isBeach,
    );
  }

  void _drawShadows(Canvas canvas) {
    final sh = _fill(const Color(0x77000000));
    for (final p in players) {
      final sc = _sc(p.y);
      final k = 1 - (p.z / 160).clamp(0.0, 0.5).toDouble();
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(_sx(p.x, p.y), _sy(p.y, 0)),
              width: 62 * sc * k,
              height: 16 * sc * k),
          sh);
    }
    final sc = _sc(by);
    final kb = 1 - ((bz - kBR) / 450).clamp(0.0, 0.7).toDouble();
    final sCenter = Offset(_sx(bx, by), _sy(by, 0));
    final sWidth = 40.0 * sc * (0.65 + 0.35 * kb);
    final sHeight = 13.0 * sc * (0.65 + 0.35 * kb);

    // Sombra da bola no chão (nítida e com gradiente de proximidade para excelente leitura de profundidade)
    canvas.drawOval(
      Rect.fromCenter(center: sCenter, width: sWidth + 4, height: sHeight + 2),
      _fill(Colors.black.withValues(alpha: 0.25 * kb)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: sCenter, width: sWidth, height: sHeight),
      _fill(Colors.black.withValues(alpha: 0.70 * kb)),
    );
  }

  /// Marcadores no chão desativados para focar 100% na leitura da sombra real da bola.
  void _drawMarkers(Canvas canvas) {}

  void _drawPlayer(Canvas canvas, Player p) {
    final face = p.team == 0 ? 1.0 : -1.0;
    final info = teams[p.team];
    final skin =
        p.slot == 0 ? const Color(0xFFF0B888) : const Color(0xFF9C5B2E);
    final hair =
        p.slot == 0 ? const Color(0xFF4E342E) : const Color(0xFF151515);
    final air = !p.onGround;
    final swinging = p.swing > 0;
    final step = air ? -2 : (p.moving ? ((time * 12).floor() + p.slot) % 2 : -1);
    final sc = _sc(p.y);
    final P = 4.6 * sc;
    final ox = _sx(p.x, p.y), oy = _sy(p.y, p.z);

    // Personagem atlético com formas estilizadas, suaves e ricas em detalhes
    CharacterRenderer.draw(
      canvas: canvas,
      ox: ox,
      oy: oy,
      P: P,
      face: face,
      shirtColor: info.color,
      trimColor: info.trim,
      skinColor: skin,
      hairColor: hair,
      jerseyNumber: p.slot == 0 ? '1' : '7',
      armsUp: air || swinging,
      swinging: swinging,
      air: air,
      moving: p.moving,
      step: step,
      isBeach: isBeach,
    );

    // Marcador do jogador controlado (indicador estilo console clássico aprimorado)
    if (p.human && phase != Phase.pointPause) {
      final bob = math.sin(time * 6) * 3.5;
      final tipY = oy - 30 * P + bob;
      final topY = tipY - 14.0 * sc;
      final arrowPath = Path()
        ..moveTo(ox - 8.5 * sc, topY)
        ..lineTo(ox + 8.5 * sc, topY)
        ..lineTo(ox, tipY)
        ..close();

      canvas.drawPath(
        arrowPath,
        Paint()
          ..color = kOutline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true,
      );
      canvas.drawPath(
        arrowPath,
        Paint()
          ..color = const Color(0xFFFFD600)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    }
  }

  void _drawBall(Canvas canvas) {
    final sc = _sc(by);
    final r = 18 * sc;

    // Squash & Stretch dinâmico orientado pelo vetor de movimento e impacto
    final speed = ball.speed;
    final scrVx = bvx * sc;
    final scrVy = bvy * (kNearY - kFarY) / kWd - bvz * sc;
    final moveAngle = math.atan2(scrVy, scrVx);

    double stretch = 1.0;
    double squash = 1.0;

    if (ballSquashTime > 0) {
      // Deformação de impacto (achatamento perpendicular)
      stretch = (1.0 / ballSquashFactor).clamp(0.60, 1.0);
      squash = ballSquashFactor.clamp(1.0, 1.45);
    } else if (speed > 220) {
      // Estiramento elástico em voo veloz
      stretch = (1.0 + math.min(0.35, speed / 2200.0)).clamp(1.0, 1.35);
      squash = 1.0 / math.sqrt(stretch);
    }

    BallRenderer.draw(
      canvas: canvas,
      cx: _sx(bx, by),
      cy: _sy(by, bz),
      radius: r,
      angle: bAng,
      stretch: stretch,
      squash: squash,
      moveAngle: moveAngle,
    );
  }

  void _drawHud(Canvas canvas) {
    const cx = kW / 2;
    // Placar LED estilizado com cantos arredondados
    final hudOuter = RRect.fromRectAndRadius(
      const Rect.fromLTWH(cx - 150, 6, 300, 54),
      const Radius.circular(8),
    );
    final hudInner = RRect.fromRectAndRadius(
      const Rect.fromLTWH(cx - 146, 10, 292, 46),
      const Radius.circular(6),
    );
    canvas.drawRRect(hudOuter, _fill(kOutline));
    canvas.drawRRect(hudInner, _fill(const Color(0xFF07070C)));
    canvas.drawRRect(hudInner, _stroke(const Color(0xFF8A8F99), 2));

    // Bandeiras reais oficiais de cada país
    for (final t in const [0, 1]) {
      final fx = t == 0 ? cx - 140.0 : cx + 112.0;
      final flagRect = Rect.fromLTWH(fx + 2, 17, 24, 32);
      final flagRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(fx, 15, 28, 36),
        const Radius.circular(4),
      );
      canvas.drawRRect(flagRRect, _fill(kOutline));
      FlagRenderer.drawFlag(
        canvas,
        flagRect,
        countryName: teams[t].name,
        borderRadius: 3.0,
      );
    }
    String two(int v) => v.toString().padLeft(2, '0');
    const led = Color(0xFFFFE600);
    _text(canvas, two(score[0]), const Offset(cx - 62, 12), fs: 36, color: led, align: 1);
    _text(canvas, two(score[1]), const Offset(cx + 62, 12), fs: 36, color: led, align: 1);
    _text(canvas, ':', const Offset(cx, 11), fs: 36, color: led, align: 1);

    // Saque e toques por time
    if (phase != Phase.menu) {
      final sx = serving == 0 ? cx - 108.0 : cx + 100.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(sx, 14, 8, 8), const Radius.circular(2)),
        _fill(Colors.white),
      );
    }
    for (final t in const [0, 1]) {
      for (var i = 0; i < 3; i++) {
        final x = (t == 0 ? cx - 62 : cx + 62) + (i - 1) * 14.0;
        final on = phase == Phase.rally && ballSide == t && i < touches[t];
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x - 3, 49, 6, 5), const Radius.circular(1.5)),
          _fill(on ? const Color(0xFFFFC107) : const Color(0x44FFFFFF)),
        );
      }
    }

    // Nomes dos países centralizados embaixo de cada lado do placar (legíveis e alinhados)
    _text(canvas, teams[0].name, const Offset(cx - 75, 63),
        fs: 13, color: Colors.white, w: FontWeight.w900, align: 1);
    _text(canvas, teams[1].name, const Offset(cx + 75, 63),
        fs: 13, color: Colors.white, w: FontWeight.w900, align: 1);

    if (phase != Phase.menu) {
      final arenaTag = isBeach ? 'PRAIA' : 'GINÁSIO';
      final trackTag = musicEnabled ? 'TRILHA ${ArcadeAudio.currentTrack + 1}' : 'MUDO';
      if (mode == 0) {
        final rName = const ['QUARTAS', 'SEMIFINAL', 'FINAL', 'GRANDE FINAL'][math.min(round, 3)];
        _text(canvas, 'TORNEIO: $rName', const Offset(12, 10), fs: 11, color: Colors.amber);
        _text(canvas, 'ARENA: $arenaTag', const Offset(12, 24), fs: 11, color: Colors.white);
        _text(canvas, '[M] Som  [N] $trackTag', const Offset(12, 38), fs: 9, color: Colors.white70);
      } else {
        final mTitle = mode == 2 ? 'VERSUS (2P)' : 'AMISTOSO';
        _text(canvas, mTitle, const Offset(12, 10), fs: 11, color: Colors.amber);
        _text(canvas, 'ARENA: $arenaTag', const Offset(12, 24), fs: 11, color: Colors.white);
        _text(canvas, '[M] Som  [N] $trackTag', const Offset(12, 38), fs: 9, color: Colors.white70);
      }
    }

    // Mensagens (na faixa entre a publicidade e a quadra)
    if (_msgTimer > 0 && phase != Phase.menu) {
      _text(canvas, _msgText, const Offset(cx, 178),
          fs: 28, color: const Color(0xFFFFD600), align: 1);
    } else if (phase == Phase.serving && !paused && _isHumanTeam(serving)) {
      if (!ballTossed) {
        final key = mode == 2
            ? (serving == 0 ? 'ESPAÇO' : 'ENTER')
            : 'botão da BOLA / ESPAÇO';
        _text(canvas, 'LANÇAR BOLA: $key', const Offset(cx, 182),
            fs: 18, color: const Color(0xFFFFD54F), align: 1);
      } else {
        _text(canvas, 'SAQUE VIAGEM: Corra, SALTE e CORTE no ar!',
            const Offset(cx, 182),
            fs: 18, color: const Color(0xFFFF9100), align: 1);
      }
    }
    if (paused) {
      canvas.drawRect(
          Rect.fromLTRB(vx0, vy0, vx1, vy1), _fill(const Color(0x99000000)));
    }
  }
}

// ============================================================
//  TELAS (overlays) - visual retrô
// ============================================================
class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1050),
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(7, 7)),
              ],
            ),
            child: child,
          ),
        ),
      );
}

class _Menu extends StatefulWidget {
  final VolleyGame game;
  const _Menu({required this.game});

  @override
  State<_Menu> createState() => _MenuState();
}

class _MenuState extends State<_Menu> {
  int diff = 1;
  bool showTournamentSetup = false;

  void _shuffleRivals(VolleyGame g) {
    final available = List<int>.generate(kAvailableTeams.length, (i) => i)
      ..remove(g.playerTeamIndex);
    available.shuffle();
    setState(() {
      g.tournamentRivalIndices = available.take(4).toList();
    });
  }

  void _resetDefaultRivals(VolleyGame g) {
    setState(() {
      g.tournamentRivalIndices = [1, 2, 3, 4];
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    const roundNames = ['1ª Fase (Quartas)', '2ª Fase (Semifinal)', '3ª Fase (Final)', '4ª Fase (Super Final)'];

    return _Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sports_volleyball, color: Colors.amber, size: 48),
          const Text(
            'VÔLEI ARCADE',
            style: TextStyle(
                color: Color(0xFFFFD600),
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                shadows: [Shadow(offset: Offset(3, 3), color: Colors.black)]),
          ),
          const Text('2 contra 2  •  até 15 pontos',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 12),

          // Seletor de país do jogador
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x33000000),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white30),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('SEU TIME:',
                    style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                DropdownButton<int>(
                  value: g.playerTeamIndex,
                  dropdownColor: const Color(0xFF0A1050),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.amber),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  items: [
                    for (var i = 0; i < kAvailableTeams.length; i++)
                      DropdownMenuItem<int>(
                        value: i,
                        child: Row(
                          children: [
                            FlagRenderer.flagWidget(kAvailableTeams[i].name, width: 26, height: 17),
                            const SizedBox(width: 8),
                            Text(kAvailableTeams[i].name),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        g.playerTeamIndex = v;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // MODO TORNEIO
          FilledButton.icon(
            onPressed: () => g.startMatch(0),
            icon: const Icon(Icons.emoji_events),
            label: const Text('JOGAR TORNEIO (4 FASES)'),
          ),
          const SizedBox(height: 6),

          // Botão para configurar países rivais do torneio
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.amber,
              side: const BorderSide(color: Colors.amber),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () => setState(() => showTournamentSetup = !showTournamentSetup),
            icon: Icon(showTournamentSetup ? Icons.expand_less : Icons.tune),
            label: Text(showTournamentSetup ? 'OCULTAR RIVAIS DO TORNEIO' : 'ESCOLHER RIVAIS DO TORNEIO 🏆'),
          ),

          // Painel expansível de escolha de rivais do torneio
          if (showTournamentSetup) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0x33000000),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  const Text('RIVAIS DE CADA FASE:',
                      style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 12)),
                  const SizedBox(height: 6),
                  for (var r = 0; r < 4; r++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(roundNames[r], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          DropdownButton<int>(
                            value: g.tournamentRivalIndices[r] % kAvailableTeams.length,
                            dropdownColor: const Color(0xFF0A1050),
                            underline: const SizedBox(),
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.amber, size: 18),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            items: [
                              for (var i = 0; i < kAvailableTeams.length; i++)
                                DropdownMenuItem<int>(
                                  value: i,
                                  child: Row(
                                    children: [
                                      FlagRenderer.flagWidget(kAvailableTeams[i].name, width: 22, height: 15),
                                      const SizedBox(width: 6),
                                      Text(kAvailableTeams[i].name),
                                    ],
                                  ),
                                ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  g.tournamentRivalIndices[r] = v;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () => _shuffleRivals(g),
                        icon: const Icon(Icons.casino, size: 16),
                        label: const Text('SORTEAR 🎲', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 10),
                      TextButton.icon(
                        onPressed: () => _resetDefaultRivals(g),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('PADRÃO 🔄', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // MODO AMISTOSO COM ESCOLHA DE RIVAL
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x22000000),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('RIVAL AMISTOSO:',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                DropdownButton<int>(
                  value: g.exhibitionRivalIndex % kAvailableTeams.length,
                  dropdownColor: const Color(0xFF0A1050),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.amber, size: 18),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  items: [
                    for (var i = 0; i < kAvailableTeams.length; i++)
                      DropdownMenuItem<int>(
                        value: i,
                        child: Row(
                          children: [
                            FlagRenderer.flagWidget(kAvailableTeams[i].name, width: 24, height: 16),
                            const SizedBox(width: 6),
                            Text(kAvailableTeams[i].name),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        g.exhibitionRivalIndex = v;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                ChoiceChip(
                  label: Text(const ['Fácil', 'Normal', 'Difícil'][i]),
                  selected: diff == i,
                  onSelected: (_) => setState(() => diff = i),
                ),
            ],
          ),
          const SizedBox(height: 6),
          FilledButton.tonalIcon(
            onPressed: () => g.startMatch(1, diff: diff),
            icon: const Icon(Icons.person),
            label: const Text('JOGAR AMISTOSO'),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: () => g.startMatch(2),
            icon: const Icon(Icons.people),
            label: const Text('2 JOGADORES (VERSUS LOCAL)'),
          ),
          const SizedBox(height: 12),

          // Seletor de Trilha Sonora Retrô
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x22000000),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TRILHA:',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                Flexible(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        g.toggleNextMusicTrack();
                      });
                    },
                    icon: const Icon(Icons.queue_music, color: Colors.amber, size: 18),
                    label: Text(
                      ArcadeAudio.currentTrackName,
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Opções de Música e Cenário
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => setState(() => g.toggleMusic()),
                  style: FilledButton.styleFrom(
                    backgroundColor: g.musicEnabled ? const Color(0xFF2E7D32) : const Color(0xFF424242),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  icon: Icon(g.musicEnabled ? Icons.music_note : Icons.music_off, size: 18),
                  label: Text(
                    g.musicEnabled ? 'MÚSICA: ON 🎵' : 'MÚSICA: OFF 🔇',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => setState(() => g.toggleArena()),
                  style: FilledButton.styleFrom(
                    backgroundColor: g.isBeach ? const Color(0xFFF57F17) : const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  icon: Icon(g.isBeach ? Icons.beach_access : Icons.stadium, size: 18),
                  label: Text(
                    g.isBeach ? 'PRAIA 🏖️' : 'GINÁSIO 🏢',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'M = música  •  C = cenário  •  P / ESC = pausa\n'
            'Saque: 1 toque = lançar bola  •  Pular + bater = Saque Viagem!\n'
            'Celular: joystick à esquerda • botão laranja = bater • azul = pular',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  final VolleyGame game;
  const _Result({required this.game});

  @override
  Widget build(BuildContext context) {
    final w = game.winner;
    final name = game.teams[w].name;
    final tournament = game.mode == 0;
    final champion = tournament && w == 0 && game.round >= 3;
    final more = tournament && w == 0 && game.round < 3;

    String title;
    if (game.mode == 2) {
      title = '$name VENCEU!';
    } else if (champion) {
      title = '🏆 CAMPEÃO DO TORNEIO! 🏆';
    } else if (w == 0) {
      title = 'VITÓRIA!';
    } else {
      title = 'DERROTA';
    }

    return _Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(champion ? Icons.emoji_events : Icons.sports_volleyball,
              color: Colors.amber, size: 48),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FlagRenderer.flagWidget(game.teams[0].name, width: 28, height: 18),
                const SizedBox(width: 8),
                Text(
                  '${game.teams[0].name} ${game.score[0]}  ×  ${game.score[1]} ${game.teams[1].name}',
                  style: const TextStyle(
                      color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                FlagRenderer.flagWidget(game.teams[1].name, width: 28, height: 18),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (more)
            FilledButton.icon(
              onPressed: game.nextRound,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('PRÓXIMA PARTIDA DO TORNEIO'),
            )
          else
            FilledButton.icon(
              onPressed: game.rematch,
              icon: const Icon(Icons.replay),
              label: Text(
                  w == 0 && game.mode != 2 ? 'JOGAR DE NOVO' : 'REVANCHE'),
            ),
          const SizedBox(height: 10),
          TextButton(onPressed: game.toMenu, child: const Text('MENU PRINCIPAL')),
        ],
      ),
    );
  }
}

class _PauseMenu extends StatefulWidget {
  final VolleyGame game;
  const _PauseMenu({required this.game});

  @override
  State<_PauseMenu> createState() => _PauseMenuState();
}

class _PauseMenuState extends State<_PauseMenu> {
  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    return _Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pause_circle_filled, color: Colors.amber, size: 52),
          const SizedBox(height: 6),
          const Text(
            'JOGO PAUSADO',
            style: TextStyle(
              color: Color(0xFFFFD600),
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              shadows: [Shadow(offset: Offset(3, 3), color: Colors.black)],
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FlagRenderer.flagWidget(g.teams[0].name, width: 26, height: 17),
                const SizedBox(width: 8),
                Text(
                  '${g.teams[0].name} ${g.score[0]}  ×  ${g.score[1]} ${g.teams[1].name}',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                FlagRenderer.flagWidget(g.teams[1].name, width: 26, height: 17),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: g.togglePause,
            icon: const Icon(Icons.play_arrow),
            label: const Text('CONTINUAR'),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: () {
              setState(() {
                g.toggleNextMusicTrack();
              });
            },
            icon: const Icon(Icons.queue_music),
            label: Text('FAIXA: ${ArcadeAudio.currentTrackName}'),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: () {
              setState(() {
                g.toggleMusic();
              });
            },
            icon: Icon(g.musicEnabled ? Icons.music_note : Icons.music_off),
            label: Text(g.musicEnabled ? 'MÚSICA: LIGADA 🎵' : 'MÚSICA: DESLIGADA 🔇'),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: () {
              setState(() {
                g.toggleArena();
              });
            },
            icon: Icon(g.isBeach ? Icons.sports_volleyball : Icons.beach_access),
            label: Text(g.isBeach ? 'CENÁRIO: GINÁSIO' : 'CENÁRIO: PRAIA'),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: () {
              g.togglePause();
              g.rematch();
            },
            icon: const Icon(Icons.replay),
            label: const Text('REINICIAR PARTIDA'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white38),
            ),
            onPressed: () {
              g.togglePause();
              g.toMenu();
            },
            icon: const Icon(Icons.home),
            label: const Text('SAIR PARA O MENU'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  CONTROLES DE TOQUE (modos de 1 jogador): joystick + pular + bater
// ============================================================
class _PadButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color color;
  final ValueChanged<bool> onChange;
  const _PadButton({
    required this.icon,
    required this.onChange,
    this.size = 62,
    this.color = const Color(0x99000000),
  });

  @override
  State<_PadButton> createState() => _PadButtonState();
}

class _PadButtonState extends State<_PadButton> {
  bool down = false;

  void _set(bool v) {
    if (down == v) return;
    setState(() => down = v);
    widget.onChange(v);
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          width: widget.size,
          height: widget.size,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: down ? const Color(0xCCFFFFFF) : widget.color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: down
                ? null
                : const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
          ),
          child: Icon(widget.icon,
              color: down ? Colors.black : Colors.white,
              size: widget.size * 0.5),
        ),
      );
}

/// Joystick analógico virtual: um único toque que acompanha o dedo,
/// permitindo mudar de direção sem soltar.
class _Joystick extends StatefulWidget {
  final Pad pad;
  final double size;
  const _Joystick({required this.pad, this.size = 170});

  @override
  State<_Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<_Joystick> {
  int? _id;
  Offset _knob = Offset.zero;

  double get _maxR => widget.size / 2 - 28;

  void _update(Offset local) {
    final c = Offset(widget.size / 2, widget.size / 2);
    var d = local - c;
    if (d.distance > _maxR) d = d / d.distance * _maxR;
    // chega à velocidade máxima com ~70% do curso, com zona morta pequena
    double ax = (d.dx / _maxR * 1.4).clamp(-1.0, 1.0).toDouble();
    double ay = (d.dy / _maxR * 1.4).clamp(-1.0, 1.0).toDouble();
    if (ax.abs() < 0.12) ax = 0;
    if (ay.abs() < 0.12) ay = 0;
    widget.pad.ax = ax;
    widget.pad.ay = ay;
    setState(() => _knob = d);
  }

  void _release() {
    _id = null;
    widget.pad.ax = 0;
    widget.pad.ay = 0;
    if (mounted) setState(() => _knob = Offset.zero);
  }

  @override
  void dispose() {
    widget.pad.ax = 0;
    widget.pad.ay = 0;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (_id != null) return;
        _id = e.pointer;
        _update(e.localPosition);
      },
      onPointerMove: (e) {
        if (e.pointer == _id) _update(e.localPosition);
      },
      onPointerUp: (e) {
        if (e.pointer == _id) _release();
      },
      onPointerCancel: (e) {
        if (e.pointer == _id) _release();
      },
      child: SizedBox(
        width: s,
        height: s,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: s - 20,
              height: s - 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x66000000),
                border: Border.all(color: Colors.white54, width: 3),
              ),
            ),
            Transform.translate(
              offset: _knob,
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xCCFFFFFF),
                  border: Border.all(color: Colors.black, width: 3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatefulWidget {
  final VolleyGame game;
  const _Controls({required this.game});

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final pad = game.pads[0];
    final showTouchPad = game.mode != 2;
    return SafeArea(
      child: Stack(
        children: [
          // Botões superiores de Música, Faixa e Pausa
          Positioned(
            top: 10,
            right: 14,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botão para Trocar de Trilha Musical
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      game.toggleNextMusicTrack();
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xDD0A1050),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amberAccent, width: 2),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black54, offset: Offset(2, 2)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.queue_music,
                            color: Colors.amberAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'FAIXA ${ArcadeAudio.currentTrack + 1}',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Botão Ligar/Desligar Música
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      game.toggleMusic();
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xDD0A1050),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: game.musicEnabled
                                ? Colors.greenAccent
                                : Colors.white38,
                            width: 2),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black54, offset: Offset(2, 2)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            game.musicEnabled
                                ? Icons.music_note
                                : Icons.music_off,
                            color: game.musicEnabled
                                ? Colors.greenAccent
                                : Colors.white60,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            game.musicEnabled ? 'SOM' : 'MUDO',
                            style: TextStyle(
                              color: game.musicEnabled
                                  ? Colors.greenAccent
                                  : Colors.white70,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: game.togglePause,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xDD0A1050),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white70, width: 2),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black54, offset: Offset(2, 2)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.pause, color: Colors.amber, size: 20),
                          SizedBox(width: 4),
                          Text(
                            'PAUSA',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Joystick e botões de toque (1 jogador)
          if (showTouchPad)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Joystick analógico
                    _Joystick(pad: pad, size: 170),
                    // Pular e bater
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      _PadButton(
                        icon: Icons.keyboard_double_arrow_up,
                        size: 66,
                        color: const Color(0xCC1E88E5),
                        onChange: (v) => pad.jump = v,
                      ),
                      _PadButton(
                        icon: Icons.sports_volleyball,
                        size: 88,
                        color: const Color(0xCCFFA000),
                        onChange: (v) {
                          if (v) pad.hitBuf = 0.4;
                        },
                      ),
                    ]),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}