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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Celular: tela cheia e sempre deitado (paisagem)
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final game = VolleyGame();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.amber,
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Courier New', 'Courier', 'monospace'],
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
          game: game,
          overlayBuilderMap: {
            'menu': (context, g) => _Menu(game: g),
            'controls': (context, g) => _Controls(game: g),
            'result': (context, g) => _Result(game: g),
          },
        ),
      ),
    ),
  );
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
const double kBR = 13; // raio da bola
const double kPG = 1500, kJump = 480; // jogadores
const double kFarY = 225, kNearY = 535; // posição na tela das bordas da quadra
const double kSFar = 0.54, kSNear = 0.80; // escala (perspectiva)

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
  double tx = 0, ty = 0; // alvo da IA
  bool wJump = false, wHit = false, human = false, moving = false;
  Player(this.team, this.slot, this.x, this.y);
  bool get onGround => z <= 0.5;
}

class Pad {
  bool left = false, right = false, up = false, down = false, jump = false;
  double ax = 0, ay = 0; // joystick de toque (-1..1)
  double hitBuf = 0; // "buffer" do botão de bater

  // Eixos finais: o analógico tem prioridade, senão usa o teclado
  double get dx => ax != 0 ? ax : ((right ? 1.0 : 0.0) - (left ? 1.0 : 0.0));
  double get dy => ay != 0 ? ay : ((down ? 1.0 : 0.0) - (up ? 1.0 : 0.0));
}

class TeamInfo {
  final String name;
  final Color color, trim;
  final double level; // 0..1 (força da IA)
  const TeamInfo(this.name, this.color, this.trim, this.level);
}

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

class _Part {
  final Rect r;
  final Color c;
  _Part(this.r, this.c);
}

class _Item {
  final double depth;
  final void Function() draw;
  _Item(this.depth, this.draw);
}

enum Phase { menu, serving, rally, pointPause, matchOver }

const _brasil = TeamInfo('BRASIL', Color(0xFFFFD600), Color(0xFF1B8E3E), 0.7);
const _opponents = [
  TeamInfo('ARGENTINA', Color(0xFF7EC8F2), Color(0xFFFFFFFF), 0.15),
  TeamInfo('JAPÃO', Color(0xFFE53935), Color(0xFFFFFFFF), 0.50),
  TeamInfo('ITÁLIA', Color(0xFF1565C0), Color(0xFFFFFFFF), 0.72),
  TeamInfo('EUA', Color(0xFF283593), Color(0xFFE53935), 0.92),
];

// ============================================================
//  JOGO
// ============================================================
class VolleyGame extends FlameGame with KeyboardEvents {
  final math.Random _rnd = math.Random();

  Phase phase = Phase.menu;
  bool paused = false;
  int mode = 0; // 0 torneio, 1 amistoso, 2 dois jogadores
  int difficulty = 1; // 0 fácil, 1 normal, 2 difícil
  int round = 0;
  int winner = 0;

  List<TeamInfo> teams = [_brasil, _opponents[0]];
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

  // Bola
  double bx = kMid, by = kWd / 2, bz = 80, bvx = 0, bvy = 0, bvz = 0;
  double bAng = 0, blockCd = 0;
  int ballSide = 0, lastTeam = 0;
  Player? lastToucher;
  final List<int> touches = [0, 0];
  bool ballHeld = true;
  bool outgoing = false; // bola "saindo" (saque, cortada, bola de graça)

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
  @override
  Future<void> onLoad() async {
    controlled[0] = players[0];
    controlled[1] = players[2];
    _nextServe();
    phase = Phase.menu;
    overlays.add('menu');
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

  void rematch() => _beginMatch();

  void toMenu() {
    phase = Phase.menu;
    paused = false;
    overlays.remove('result');
    overlays.remove('controls');
    overlays.add('menu');
  }

  void _setupTeams() {
    if (mode == 2) {
      teams = [
        const TeamInfo(
            'JOGADOR 1', Color(0xFFFFD600), Color(0xFF1B8E3E), 0.7),
        const TeamInfo(
            'JOGADOR 2', Color(0xFF43A047), Color(0xFFFFFFFF), 0.7),
      ];
    } else if (mode == 0) {
      teams = [_brasil, _opponents[math.min(round, 3)]];
    } else {
      const lv = [0.08, 0.55, 0.92];
      teams = [
        _brasil,
        TeamInfo('CPU', const Color(0xFFE53935), const Color(0xFFFFFFFF),
            lv[difficulty]),
      ];
    }
  }

  void _beginMatch() {
    _setupTeams();
    score[0] = 0;
    score[1] = 0;
    serving = 0;
    paused = false;
    overlays.remove('menu');
    overlays.remove('result');
    overlays.remove('controls');
    if (mode != 2) overlays.add('controls');
    _nextServe();
    _msg('${teams[0].name} x ${teams[1].name}', 2.0);
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
    ballSide = serving;
    bvx = 0;
    bvy = 0;
    bvz = 0;
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
    overlays.remove('controls');
    overlays.add('result');
  }

  void _msg(String s, [double t = 1.4]) {
    _msgText = s;
    _msgTimer = t;
  }

  // ---------- teclado ----------
  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keys) {
    bool k(LogicalKeyboardKey a) => keys.contains(a);
    if (mode == 2) {
      pads[0].left = k(LogicalKeyboardKey.keyA);
      pads[0].right = k(LogicalKeyboardKey.keyD);
      pads[0].up = k(LogicalKeyboardKey.keyW);
      pads[0].down = k(LogicalKeyboardKey.keyS);
      pads[0].jump = k(LogicalKeyboardKey.keyQ);
      pads[1].left = k(LogicalKeyboardKey.arrowLeft);
      pads[1].right = k(LogicalKeyboardKey.arrowRight);
      pads[1].up = k(LogicalKeyboardKey.arrowUp);
      pads[1].down = k(LogicalKeyboardKey.arrowDown);
      pads[1].jump = k(LogicalKeyboardKey.shiftRight);
    } else {
      pads[0].left =
          k(LogicalKeyboardKey.keyA) || k(LogicalKeyboardKey.arrowLeft);
      pads[0].right =
          k(LogicalKeyboardKey.keyD) || k(LogicalKeyboardKey.arrowRight);
      pads[0].up = k(LogicalKeyboardKey.keyW) || k(LogicalKeyboardKey.arrowUp);
      pads[0].down =
          k(LogicalKeyboardKey.keyS) || k(LogicalKeyboardKey.arrowDown);
      pads[0].jump = k(LogicalKeyboardKey.keyX);
      pads[1].left = pads[1].right = pads[1].up = pads[1].down = false;
      pads[1].jump = false;
    }
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (mode == 2) {
        if (key == LogicalKeyboardKey.space) pads[0].hitBuf = 0.2;
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) {
          pads[1].hitBuf = 0.2;
        }
      } else if (key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.keyZ) {
        pads[0].hitBuf = 0.2;
      }
      if ((key == LogicalKeyboardKey.keyP ||
              key == LogicalKeyboardKey.escape) &&
          (phase == Phase.serving ||
              phase == Phase.rally ||
              phase == Phase.pointPause)) {
        paused = !paused;
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
    double x = bx, y = by, z = bz, vx = bvx, vy = bvy, vz = bvz, t = 0;
    while (t < 4) {
      vz -= kG * 0.02;
      x += vx * 0.02;
      y += vy * 0.02;
      z += vz * 0.02;
      t += 0.02;
      if (vz < 0 && z <= zz) return Pred(x, y, t);
    }
    return Pred(x, y, t);
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
              o.tx = kMid - dirN * 150;
              o.ty = kWd * 0.5;
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
              o.tx = kMid - dirN * 110;
              o.ty = kWd * 0.5;
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
          // DEFESA / BLOQUEIO
          final opp = 1 - team;
          if (touches[opp] == 2 && ballSide == opp && lvl > 0.35) {
            final blocker = mates.firstWhere((m) => m.slot == 1);
            blocker.tx = kMid - dirN * 34;
            blocker.ty = by.clamp(20.0, kWd - 20).toDouble();
            final pr = _predict(150);
            if (blocker.onGround &&
                (bx - kMid).abs() < 170 &&
                bz > 110 &&
                pr.t < 0.45 + blocker.jumpErr) {
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
        mx = pad.dx; // analógico (joystick) ou teclado
        my = pad.dy;
        jump = pad.jump;
        wantHit = pad.hitBuf > 0;
        // pulo automático ao apertar "bater" com a bola alta por perto
        if (wantHit &&
            p.onGround &&
            phase == Phase.rally &&
            _eligible(p) &&
            bz > 128 &&
            bz < 260) {
          final ddx = bx - p.x, ddy = by - p.y;
          if (math.sqrt(ddx * ddx + ddy * ddy) < 85) jump = true;
        }
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
        p.x = (p.team == 0
                ? p.x.clamp(5.0, 110.0)
                : p.x.clamp(kL - 110, kL - 5))
            .toDouble();
        p.y = p.y.clamp(25.0, kWd - 25).toDouble();
      } else if (jump && p.onGround) {
        p.vz = kJump;
      }

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
      if (p == _server) _serve(p);
      return;
    }
    if (phase != Phase.rally || !_eligible(p)) return;
    final face = p.team == 0 ? 1.0 : -1.0;
    final hx = p.x + face * 10;
    final hz = p.z + (p.onGround ? 58 : 78);
    final dx = bx - hx, dy = (by - p.y) * 0.8, dz = bz - hz;
    final reach = p.human ? (p.onGround ? 100.0 : 110.0) : (p.onGround ? 72.0 : 80.0);
    if (dx * dx + dy * dy + dz * dz > reach * reach) return;
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

  /// Lança a bola até (tx, ty) na altura [tz], passando pelo ponto mais alto [apexZ].
  void _launchTo(double tx, double ty, double tz, double apexZ) {
    final apex = math.max(apexZ, math.max(bz, tz) + 30);
    final vz0 = math.sqrt(2 * kG * (apex - bz));
    final tUp = vz0 / kG;
    final tDown = math.sqrt(2 * (apex - tz) / kG);
    final tt = tUp + tDown;
    bvz = vz0;
    bvx = ((tx - bx) / tt).clamp(-900.0, 900.0).toDouble();
    bvy = ((ty - by) / tt).clamp(-700.0, 700.0).toDouble();
  }

  /// Lançamento rápido (cortada): escolhe o tempo de voo para passar por cima da rede.
  void _launchFast(double tx, double ty, double tz) {
    double tt = 0.45;
    for (; tt <= 1.0; tt += 0.05) {
      final vz = (tz - bz + 0.5 * kG * tt * tt) / tt;
      if ((tx - bx).abs() < 1) break;
      final f = (kMid - bx) / (tx - bx);
      if (f <= 0 || f >= 1) break;
      final tc = f * tt;
      final zc = bz + vz * tc - 0.5 * kG * tc * tc;
      if (zc > kNetH + kBR + 6) break;
    }
    bvz = (tz - bz + 0.5 * kG * tt * tt) / tt;
    bvx = (tx - bx) / tt;
    bvy = (ty - by) / tt;
  }

  void _hit(Player p) {
    final t = p.team;
    final dirOpp = t == 0 ? 1.0 : -1.0;
    final aimX = _aimX(p);
    final aimY = _aimY(p);
    final idx = touches[t];
    final air = !p.onGround;
    final nearNet = (bx - kMid).abs() < 230;
    final gyT = (kWd * 0.5 + aimY * kWd * 0.40).clamp(20.0, kWd - 20).toDouble();
    final gyP = kWd * 0.5 + aimY * kWd * 0.2;

    if (air && idx >= 1 && nearNet && bz > kNetH - 15) {
      // CORTADA
      _launchFast(kMid + dirOpp * (70 + 330 * (aimX + 1) / 2), gyT, kBR);
      outgoing = true;
      shake = math.max(shake, 5);
      _msg('CORTADA!', 0.7);
      _sparkBall(14, const Color(0xFFFFEB3B), 200);
    } else if (idx == 0) {
      _launchTo(kMid - dirOpp * (150 - 20 * aimX), gyP, 70, 230);
      outgoing = false;
    } else if (idx == 1) {
      _launchTo(kMid - dirOpp * (90 - 20 * aimX), gyP, 150, 215);
      outgoing = false;
    } else {
      _launchTo(kMid + dirOpp * (120 + 250 * (aimX + 1) / 2), gyT, kBR, 280);
      outgoing = true;
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

  void _serve(Player p) {
    final dirOpp = p.team == 0 ? 1.0 : -1.0;
    final aimX = _aimX(p);
    final aimY = _aimY(p);
    var tx = kMid + dirOpp * (120 + 300 * (aimX + 1) / 2);
    final ty = (kWd * 0.5 + aimY * kWd * 0.40).clamp(25.0, kWd - 25).toDouble();
    if (!p.human && _rnd.nextDouble() < (1 - _lvl(p.team)) * 0.30) {
      tx += dirOpp * 260; // saque errado (IA)
    }
    _launchTo(tx, ty, kBR, 300);
    ballHeld = false;
    phase = Phase.rally;
    lastTeam = p.team;
    lastToucher = p;
    touches[0] = 0;
    touches[1] = 0;
    outgoing = true;
    ballSide = bx < kMid ? 0 : 1;
    p.swing = 0.3;
    pads[p.team].hitBuf = 0;
    _sparkBall(6, Colors.white, 120);
  }

  // ============================================================
  //  BOLA
  // ============================================================
  void _stepBall(double dt) {
    final prevX = bx;
    bvz -= kG * dt;
    bx += bvx * dt;
    by += bvy * dt;
    bz += bvz * dt;
    bAng += bvx * dt * 0.02;
    blockCd = math.max(0, blockCd - dt);

    // Rede (só vale entre as antenas, e abaixo da fita)
    if (phase == Phase.rally &&
        by >= -4 &&
        by <= kWd + 4 &&
        (prevX < kMid) != (bx < kMid) &&
        bz - kBR * 0.3 < kNetH) {
      bx = prevX;
      bvx = -bvx * 0.3;
      bvy *= 0.6;
      bvz *= 0.7;
      outgoing = false;
      shake = math.max(shake, 3);
      _sparkBall(5, Colors.white70, 80);
    }

    // Troca de lado: zera os toques
    final s = bx < kMid ? 0 : 1;
    if (s != ballSide) {
      ballSide = s;
      touches[0] = 0;
      touches[1] = 0;
      outgoing = false;
    }

    // Chão
    if (bz - kBR <= 0) {
      bz = kBR;
      if (phase == Phase.rally) _ballLanded();
      if (bvz < -120) _sparkBall(8, const Color(0xFFE8B070), 110);
      bvz = -bvz * 0.5;
      bvx *= 0.85;
      bvy *= 0.85;
      if (bvz.abs() < 70) bvz = 0;
    }
  }

  void _blockCheck() {
    if (blockCd > 0 || phase != Phase.rally) return;
    for (final p in players) {
      if (p.onGround || (p.x - kMid).abs() > 80) continue;
      final inX = (bx - p.x).abs() < 26 + kBR;
      final inY = (by - p.y).abs() < 36 + kBR;
      final inZ = bz > p.z + 30 && bz < p.z + 100 + kBR;
      if (!(inX && inY && inZ)) continue;
      final towards = p.team == 0 ? bvx < 0 : bvx > 0;
      if (!towards) continue;
      bvx = -bvx * 0.6;
      bvz = bvz.abs() * 0.25 + 60;
      lastTeam = p.team;
      outgoing = false;
      blockCd = 0.25;
      shake = math.max(shake, 6);
      _msg('BLOQUEIO!', 0.8);
      _sparkBall(14, Colors.lightBlueAccent, 180);
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
    crowd = 1.2;
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

    if (paused || phase == Phase.menu || phase == Phase.matchOver) return;
    for (final pad in pads) {
      pad.hitBuf = math.max(0, pad.hitBuf - dt);
    }

    if (phase == Phase.serving) {
      _assignRoles();
      _updatePlayers(dt);
      if (phase == Phase.serving) {
        final s = _server;
        _placeBallOnServer();
        bvx = 0;
        bvy = 0;
        bvz = 0;
        _serveTimer -= dt;
        if (!_isHumanTeam(s.team) && _serveTimer <= 0) _serve(s);
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
    ..isAntiAlias = false;

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.miter
    ..isAntiAlias = false;

  void _text(Canvas canvas, String s, Offset pos,
      {double fs = 16,
      Color color = Colors.white,
      FontWeight w = FontWeight.w900,
      int align = 0}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color,
          fontSize: fs,
          fontWeight: w,
          fontFamily: 'monospace',
          fontFamilyFallback: const ['Courier New', 'Courier'],
          shadows: const [
            Shadow(offset: Offset(2, 2), color: kOutline),
            Shadow(offset: Offset(-2, 2), color: kOutline),
            Shadow(offset: Offset(2, -2), color: kOutline),
            Shadow(offset: Offset(-2, -2), color: kOutline),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = align == 1 ? tp.width / 2 : (align == 2 ? tp.width : 0.0);
    tp.paint(canvas, pos - Offset(dx, 0));
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
    if (shake > 0) {
      canvas.translate((_rnd.nextDouble() - 0.5) * shake,
          (_rnd.nextDouble() - 0.5) * shake);
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
    const n = 8;
    for (var i = 0; i < n; i++) {
      final g0 = kWd * i / n, g1 = kWd * (i + 1) / n;
      items.add(_Item((g0 + g1) / 2, () => _drawNetSlice(canvas, g0, g1)));
    }
    for (final p in players) {
      items.add(_Item(p.y, () => _drawPlayer(canvas, p)));
    }
    items.add(_Item(by, () => _drawBall(canvas)));
    items.sort((a, b) => a.depth.compareTo(b.depth));
    for (final it in items) {
      it.draw();
    }

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
    final pp = Paint()..isAntiAlias = false;

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
        canvas.drawRect(Rect.fromLTWH(x - 7, y + 6 + bob, 14, 12), pp);
        pp.color = skins[(i + r).abs() % 3];
        canvas.drawRect(Rect.fromLTWH(x - 4, y - 3 + bob, 8, 9), pp);
        pp.color = hairs[(i * 3 + r) % 3];
        canvas.drawRect(Rect.fromLTWH(x - 4, y - 3 + bob, 8, 3), pp);
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

  void _drawCourt(Canvas canvas) {
    final path = Path()
      ..moveTo(_sx(0, 0), _sy(0, 0))
      ..lineTo(_sx(kL, 0), _sy(0, 0))
      ..lineTo(_sx(kL, kWd), _sy(kWd, 0))
      ..lineTo(_sx(0, kWd), _sy(kWd, 0))
      ..close();
    canvas.drawPath(path, _fill(const Color(0xFFC9531F)));
    final ln = _stroke(Colors.white, 3);
    canvas.drawPath(path, ln);
    canvas.drawLine(Offset(_sx(kMid, 0), _sy(0, 0)),
        Offset(_sx(kMid, kWd), _sy(kWd, 0)), ln);
    final thin = _stroke(const Color(0xCCFFFFFF), 2);
    for (final a in const [kMid - 150, kMid + 150]) {
      canvas.drawLine(
          Offset(_sx(a, 0), _sy(0, 0)), Offset(_sx(a, kWd), _sy(kWd, 0)), thin);
    }
  }

  void _drawLineJudges(Canvas canvas) {
    for (final side in const [0, 1]) {
      final gx = side == 0 ? -45.0 : kL + 45.0;
      const gy = -38.0;
      _drawSprite(canvas, _sx(gx, gy), _sy(gy, 0), 3.0 * _sc(gy),
          side == 0 ? 1.0 : -1.0, Colors.white, const Color(0xFF222222),
          const Color(0xFFE8B98A), const Color(0xFF3E2723));
    }
  }

  void _drawReferee(Canvas canvas) {
    const gy = -30.0;
    final sc = _sc(gy);
    final cx = _sx(kMid, gy);
    final base = _sy(gy, 0);
    // pernas da cadeira
    final leg = _fill(const Color(0xFF9EA3AA));
    canvas.drawRect(Rect.fromLTRB(cx - 22 * sc, base - 100 * sc, cx - 17 * sc, base), leg);
    canvas.drawRect(Rect.fromLTRB(cx + 17 * sc, base - 100 * sc, cx + 22 * sc, base), leg);
    // plataforma
    canvas.drawRect(Rect.fromLTRB(cx - 30 * sc, base - 106 * sc, cx + 30 * sc, base - 98 * sc),
        _fill(kOutline));
    canvas.drawRect(Rect.fromLTRB(cx - 28 * sc, base - 104 * sc, cx + 28 * sc, base - 99 * sc),
        _fill(const Color(0xFFE53935)));
    // árbitro em cima
    _drawSprite(canvas, cx, base - 104 * sc, 3.0 * sc, 1.0, Colors.white,
        const Color(0xFF222222), const Color(0xFFE8B98A), const Color(0xFF3E2723));
  }

  void _drawPost(Canvas canvas, double gy, bool near) {
    final sc = _sc(gy);
    final cx = kW / 2;
    final base = _sy(gy, 0);
    final top = _sy(gy, kNetH + 16);
    final w = 5 * sc;
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

  void _drawNetSlice(Canvas canvas, double g0, double g1) {
    final cx = kW / 2;
    final hw0 = 4 * _sc(g0), hw1 = 4 * _sc(g1);
    final top0 = _sy(g0, kNetH), bot1 = _sy(g1, 0);
    final path = Path()
      ..moveTo(cx - hw0, top0)
      ..lineTo(cx + hw0, top0)
      ..lineTo(cx + hw1, bot1)
      ..lineTo(cx - hw1, bot1)
      ..close();
    canvas.drawPath(path, _fill(const Color(0xDD15151F)));
    final mesh = _fill(const Color(0x66FFFFFF));
    for (var y = top0; y < bot1; y += 6) {
      final t = (y - top0) / (bot1 - top0);
      final hw = hw0 + (hw1 - hw0) * t;
      canvas.drawRect(Rect.fromLTRB(cx - hw, y, cx + hw, y + 1.5), mesh);
    }
    canvas.drawRect(Rect.fromLTRB(cx - hw0 - 1, top0, cx - hw0 + 1, bot1),
        _fill(const Color(0xFFEDEDED)));
    canvas.drawRect(Rect.fromLTRB(cx + hw0 - 1, top0, cx + hw0 + 1, bot1),
        _fill(const Color(0xFFEDEDED)));
  }

  void _drawShadows(Canvas canvas) {
    final sh = _fill(const Color(0x77000000));
    for (final p in players) {
      final sc = _sc(p.y);
      final k = 1 - (p.z / 160).clamp(0.0, 0.5).toDouble();
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(_sx(p.x, p.y), _sy(p.y, 0)),
              width: 48 * sc * k,
              height: 13 * sc * k),
          sh);
    }
    final sc = _sc(by);
    final kb = 1 - ((bz - kBR) / 450).clamp(0.0, 0.7).toDouble();
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(_sx(bx, by), _sy(by, 0)),
            width: 30 * sc * kb,
            height: 9 * sc * kb),
        sh);
  }

  /// Anel amarelo no ponto onde o jogador deve ficar.
  void _drawMarkers(Canvas canvas) {
    if (phase != Phase.rally) return;
    // anel de queda
    for (final t in const [0, 1]) {
      final m = marker[t];
      if (m == null) continue;
      final sc = _sc(m.y);
      final k = 1 + 0.12 * math.sin(time * 10);
      final c = Offset(_sx(m.x, m.y), _sy(m.y, 0));
      final r1 = Rect.fromCenter(
          center: c, width: 56 * sc * k, height: 20 * sc * k);
      canvas.drawOval(r1, _fill(const Color(0x33FFEB3B)));
      canvas.drawOval(r1.inflate(1.5), _stroke(kOutline, 6));
      canvas.drawOval(r1, _stroke(const Color(0xFFFFEB3B), 3));
    }
  }

  /// Desenha um personagem em pixel art. (ox, oy) = pés; P = tamanho do "pixel".
  void _drawSprite(Canvas canvas, double ox, double oy, double P, double face,
      Color shirt, Color trim, Color skin, Color hair,
      {bool armsUp = false,
      bool swinging = false,
      bool air = false,
      int step = -1}) {
    final parts = <_Part>[];
    void b(int col, int row, int w, int h, Color c) {
      final x0 = col * P * face, x1 = (col + w) * P * face;
      parts.add(_Part(
          Rect.fromLTRB(
              math.min(x0, x1), row * P, math.max(x0, x1), (row + h) * P),
          c));
    }

    // Braço de trás
    if (!armsUp) {
      b(-5, -18, 2, 7, skin);
    } else {
      b(-1, swinging ? -28 : -29, 2, 10, skin);
    }
    // Pernas
    final lb = air ? -4 : (step == 0 ? -4 : (step == 1 ? -2 : -3));
    final lf = air ? 2 : (step == 0 ? 2 : (step == 1 ? 0 : 1));
    final footUp = air ? 2 : 0;
    b(lb, -9, 2, 7 - footUp, skin);
    b(lf, -9, 2, 7 - footUp, skin);
    b(lb, -2 - footUp, 3, 2, Colors.white);
    b(lf, -2 - footUp, 3, 2, Colors.white);
    // Calção e camisa
    b(-3, -13, 6, 4, trim);
    b(-4, -19, 8, 6, shirt);
    b(-4, -16, 8, 1, trim);
    // Braço da frente
    if (!armsUp) {
      b(3, -18, 2, 7, skin);
      b(3, -19, 2, 2, shirt);
    } else if (swinging) {
      b(2, -30, 2, 12, skin);
      b(4, -30, 3, 2, skin);
    } else {
      b(2, -29, 2, 11, skin);
    }
    // Cabeça
    b(-2, -24, 5, 5, skin);
    b(-3, -26, 7, 3, hair);
    b(-3, -24, 2, 3, hair);
    b(-3, -24, 7, 1, trim);
    b(2, -22, 1, 1, kOutline);

    canvas.save();
    canvas.translate(ox, oy);
    final o = _fill(kOutline);
    final inf = math.max(0.8, P * 0.3);
    for (final pt in parts) {
      canvas.drawRect(pt.r.inflate(inf), o);
    }
    for (final pt in parts) {
      canvas.drawRect(pt.r, _fill(pt.c));
    }
    canvas.restore();
  }

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
    final P = 3.4 * sc;
    final ox = _sx(p.x, p.y), oy = _sy(p.y, p.z);

    _drawSprite(canvas, ox, oy, P, face, info.color, info.trim, skin, hair,
        armsUp: air || swinging, swinging: swinging, air: air, step: step);

    // Marcador do jogador controlado
    if (p.human && phase != Phase.pointPause) {
      final u = P * 0.9;
      final bob = (math.sin(time * 6) * 3).roundToDouble();
      final base = oy - 33 * P + bob;
      final o = _fill(kOutline);
      canvas.drawRect(Rect.fromLTWH(ox - 5 * u, base - 1, 10 * u, 4.5 * u), o);
      canvas.drawRect(Rect.fromLTWH(ox - 2.5 * u, base + 3 * u, 5 * u, 3.5 * u), o);
      canvas.drawRect(Rect.fromLTWH(ox - 4 * u, base + 0.5, 8 * u, 3 * u),
          _fill(info.color));
      canvas.drawRect(Rect.fromLTWH(ox - 1.5 * u, base + 3 * u, 3 * u, 2.5 * u),
          _fill(info.color));
    }
  }

  void _drawBall(Canvas canvas) {
    final sc = _sc(by);
    final r = 15 * sc;
    canvas.save();
    canvas.translate(_sx(bx, by), _sy(by, bz));
    canvas.rotate(bAng);
    canvas.drawCircle(Offset.zero, r + 2, Paint()..color = kOutline);
    canvas.drawCircle(Offset.zero, r, Paint()..color = Colors.white);
    final rect = Rect.fromCircle(center: Offset.zero, radius: r * 0.7);
    for (var i = 0; i < 3; i++) {
      canvas.save();
      canvas.rotate(i * 2 * math.pi / 3);
      canvas.drawArc(
          rect,
          0.5,
          1.3,
          false,
          _stroke(i == 1 ? const Color(0xFFFFC107) : const Color(0xFF1E88E5),
              math.max(2.5, r * 0.28))
            ..isAntiAlias = true);
      canvas.restore();
    }
    canvas.restore();
  }

  void _drawHud(Canvas canvas) {
    const cx = kW / 2;
    // Placar LED (como no original)
    canvas.drawRect(const Rect.fromLTWH(cx - 150, 6, 300, 54), _fill(kOutline));
    canvas.drawRect(
        const Rect.fromLTWH(cx - 146, 10, 292, 46), _fill(const Color(0xFF07070C)));
    canvas.drawRect(const Rect.fromLTWH(cx - 146, 10, 292, 46),
        _stroke(const Color(0xFF8A8F99), 2));
    // bandeiras (cores dos times)
    for (final t in const [0, 1]) {
      final fx = t == 0 ? cx - 140 : cx + 112;
      canvas.drawRect(Rect.fromLTWH(fx, 15, 28, 36), _fill(kOutline));
      canvas.drawRect(Rect.fromLTWH(fx + 2, 17, 24, 32), _fill(teams[t].color));
      canvas.drawRect(Rect.fromLTWH(fx + 2, 29, 24, 8), _fill(teams[t].trim));
    }
    String two(int v) => v.toString().padLeft(2, '0');
    const led = Color(0xFFFFE600);
    _text(canvas, two(score[0]), const Offset(cx - 62, 12), fs: 36, color: led, align: 1);
    _text(canvas, two(score[1]), const Offset(cx + 62, 12), fs: 36, color: led, align: 1);
    _text(canvas, ':', const Offset(cx, 11), fs: 36, color: led, align: 1);

    // saque (quadradinho branco) e toques por time
    if (phase != Phase.menu) {
      final sx = serving == 0 ? cx - 108.0 : cx + 100.0;
      canvas.drawRect(Rect.fromLTWH(sx, 14, 8, 8), _fill(Colors.white));
    }
    for (final t in const [0, 1]) {
      for (var i = 0; i < 3; i++) {
        final x = (t == 0 ? cx - 62 : cx + 62) + (i - 1) * 14.0;
        final on = phase == Phase.rally && ballSide == t && i < touches[t];
        canvas.drawRect(Rect.fromLTWH(x - 3, 49, 6, 5),
            _fill(on ? const Color(0xFFFFC107) : const Color(0x44FFFFFF)));
      }
    }
    // nomes embaixo
    _text(canvas, teams[0].name, const Offset(cx - 146, 64),
        fs: 12, color: teams[0].color);
    _text(canvas, teams[1].name, const Offset(cx + 146, 64),
        fs: 12, color: teams[1].color, align: 2);
    if (mode == 0 && phase != Phase.menu) {
      _text(canvas, 'TORNEIO ${round + 1}/4', const Offset(14, 12), fs: 13);
    }

    // Mensagens (na faixa azul entre a publicidade e a quadra)
    if (_msgTimer > 0 && phase != Phase.menu) {
      _text(canvas, _msgText, const Offset(cx, 178),
          fs: 28, color: const Color(0xFFFFD600), align: 1);
    } else if (phase == Phase.serving && !paused && _isHumanTeam(serving)) {
      final key = mode == 2
          ? (serving == 0 ? 'ESPAÇO' : 'ENTER')
          : 'botão da BOLA / ESPAÇO';
      _text(canvas, 'SAQUE: $key', const Offset(cx, 182),
          fs: 18, color: const Color(0xFFFFD54F), align: 1);
    }
    if (paused) {
      canvas.drawRect(
          Rect.fromLTRB(vx0, vy0, vx1, vy1), _fill(const Color(0x99000000)));
      _text(canvas, 'PAUSADO', const Offset(cx, kH / 2 - 30), fs: 48, align: 1);
      _text(canvas, 'P ou ESC para continuar', const Offset(cx, kH / 2 + 26),
          fs: 18, align: 1);
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
            padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
            constraints: const BoxConstraints(maxWidth: 440),
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

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    return _Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sports_volleyball, color: Colors.amber, size: 52),
          const Text(
            'VÔLEI ARCADE',
            style: TextStyle(
                color: Color(0xFFFFD600),
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                shadows: [Shadow(offset: Offset(3, 3), color: Colors.black)]),
          ),
          const Text('2 contra 2  •  até 15 pontos',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => g.startMatch(0),
            icon: const Icon(Icons.emoji_events),
            label: const Text('TORNEIO (4 partidas)'),
          ),
          const SizedBox(height: 14),
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
            label: const Text('AMISTOSO vs CPU'),
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: () => g.startMatch(2),
            icon: const Icon(Icons.people),
            label: const Text('2 JOGADORES'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Celular: joystick à esquerda = mover (qualquer direção)\n'
            'Botão laranja = bater  •  botão azul = pular/bloquear\n'
            '1 jogador (teclado): setas ou WASD = mover\n'
            'ESPAÇO ou Z = bater (a bola alta faz pular sozinho)\n'
            'X = pular (use para BLOQUEAR na rede)\n'
            '2 jogadores: P1 = WASD + ESPAÇO + Q (pulo)\n'
            'P2 = setas + ENTER + SHIFT direito (pulo)\n'
            'Cada time tem no máximo 3 toques. P = pausa.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
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
      title = 'CAMPEÃO DO TORNEIO!';
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
          Text(
            '${game.teams[0].name} ${game.score[0]}  ×  ${game.score[1]} ${game.teams[1].name}',
            style: const TextStyle(
                color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          if (more)
            FilledButton.icon(
              onPressed: game.nextRound,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('PRÓXIMA PARTIDA'),
            )
          else
            FilledButton.icon(
              onPressed: game.rematch,
              icon: const Icon(Icons.replay),
              label: Text(
                  w == 0 && game.mode != 2 ? 'JOGAR DE NOVO' : 'REVANCHE'),
            ),
          const SizedBox(height: 10),
          TextButton(onPressed: game.toMenu, child: const Text('MENU')),
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

class _Controls extends StatelessWidget {
  final VolleyGame game;
  const _Controls({required this.game});

  @override
  Widget build(BuildContext context) {
    final pad = game.pads[0];
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Joystick analógico
              _Joystick(pad: pad),
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
    );
  }
}