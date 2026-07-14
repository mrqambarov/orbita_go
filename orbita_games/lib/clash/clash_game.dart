import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Image;
import '../widgets/audio_manager.dart';

/// Orbita Clash — real-time lane battler (botga qarshi MVP).
/// Flame `world` + topLeft kamera: world koordinatalari = ekran piksellari.

enum Team { player, enemy }

class FighterSpec {
  final String id, name, emoji;
  final int cost;
  final double maxHp, damage, speed, range, attackInterval;
  final Color color;
  final bool isSpell; // maydonga bosilганда bir martalik AoE
  final double splash; // > 0 bo'lsa zarba atrofdagilarga ham tegadi
  final double aoeRadius; // spell radiusi
  const FighterSpec({
    required this.id,
    required this.name,
    required this.emoji,
    required this.cost,
    required this.maxHp,
    required this.damage,
    required this.speed,
    required this.range,
    required this.attackInterval,
    required this.color,
    this.isSpell = false,
    this.splash = 0,
    this.aoeRadius = 0,
  });
}

const List<FighterSpec> kFighters = [
  FighterSpec(id: 'runner', name: 'Yuguruvchi', emoji: '🏃', cost: 2, maxHp: 60, damage: 8, speed: 46, range: 30, attackInterval: 0.8, color: Color(0xFF00E5FF)),
  FighterSpec(id: 'archer', name: 'Kamonchi', emoji: '🏹', cost: 3, maxHp: 70, damage: 17, speed: 32, range: 105, attackInterval: 1.0, color: Color(0xFFFFD700)),
  FighterSpec(id: 'shield', name: 'Qalqonchi', emoji: '🛡️', cost: 4, maxHp: 240, damage: 12, speed: 24, range: 34, attackInterval: 1.1, color: Color(0xFF7C4DFF)),
  FighterSpec(id: 'bomb', name: 'Bombachi', emoji: '💣', cost: 4, maxHp: 110, damage: 26, speed: 26, range: 34, attackInterval: 1.3, color: Color(0xFFFF9800), splash: 44),
  FighterSpec(id: 'rider', name: 'Chavandoz', emoji: '🐎', cost: 5, maxHp: 150, damage: 32, speed: 66, range: 30, attackInterval: 1.2, color: Color(0xFFFF5252)),
  FighterSpec(id: 'spell', name: 'Chaqmoq', emoji: '⚡', cost: 3, maxHp: 1, damage: 44, speed: 0, range: 0, attackInterval: 1, color: Color(0xFF40C4FF), isSpell: true, aoeRadius: 74),
];

void _text(Canvas c, String s, Offset center, {double size = 15, Color color = Colors.white, FontWeight w = FontWeight.w700}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color, fontWeight: w)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

void _hpBar(Canvas c, Offset center, double w, double frac, Color color) {
  frac = frac.clamp(0.0, 1.0);
  final r = Rect.fromCenter(center: center, width: w, height: 5);
  c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), Paint()..color = Colors.black.withValues(alpha: 0.55));
  final fr = Rect.fromLTWH(r.left, r.top, w * frac, 5);
  c.drawRRect(RRect.fromRectAndRadius(fr, const Radius.circular(3)), Paint()..color = frac > 0.35 ? color : Colors.redAccent);
}

// ─────────────────────────── Battlefield ───────────────────────────
class Battlefield extends PositionComponent with HasGameReference<ClashGame> {
  Battlefield() : super(priority: -10);

  @override
  void render(Canvas canvas) {
    final w = game.size.x, h = game.size.y;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.5), Paint()..color = const Color(0xFF2B5F3A));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.5, w, h * 0.5), Paint()..color = const Color(0xFF357048));
    const laneW = 46.0;
    for (final lx in game.laneX) {
      canvas.drawRect(Rect.fromCenter(center: Offset(lx, h / 2), width: laneW, height: h), Paint()..color = const Color(0x22FFFFFF));
    }
    final riverTop = h * 0.46, riverH = h * 0.08;
    canvas.drawRect(Rect.fromLTWH(0, riverTop, w, riverH), Paint()..color = const Color(0xFF1B4E7A));
    canvas.drawRect(Rect.fromLTWH(0, riverTop, w, 3), Paint()..color = const Color(0x55FFFFFF));
    for (final lx in game.laneX) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(lx, riverTop + riverH / 2), width: laneW + 10, height: riverH + 6), const Radius.circular(6)),
        Paint()..color = const Color(0xFF6B4A2B),
      );
    }
  }
}

// ─────────────────────────── Effects ───────────────────────────
class BlastEffect extends PositionComponent with HasGameReference<ClashGame> {
  final double maxR;
  final Color color;
  double _life;
  final double _dur;
  BlastEffect({required Vector2 pos, required this.maxR, required this.color, double duration = 0.4})
      : _life = duration,
        _dur = duration,
        super(position: pos, priority: 5);

  @override
  void update(double dt) {
    super.update(dt);
    _life -= dt;
    if (_life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = 1 - _life / _dur; // 0..1
    final r = maxR * p;
    final o = (1 - p).clamp(0.0, 1.0);
    canvas.drawCircle(Offset.zero, r, Paint()..color = color.withValues(alpha: 0.35 * o));
    canvas.drawCircle(
      Offset.zero, r,
      Paint()
        ..color = color.withValues(alpha: 0.9 * o)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }
}

class ExplosionEffect extends PositionComponent with HasGameReference<ClashGame> {
  double _life = 0.5;
  ExplosionEffect({required Vector2 pos}) : super(position: pos, priority: 6);

  @override
  void update(double dt) {
    super.update(dt);
    _life -= dt;
    if (_life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = 1 - _life / 0.5;
    final o = (1 - p).clamp(0.0, 1.0);
    canvas.drawCircle(Offset.zero, 20 + 26 * p, Paint()..color = Colors.orange.withValues(alpha: 0.4 * o));
    _text(canvas, '💥', Offset.zero, size: 30 + 16 * p);
  }
}

// ─────────────────────────── Unit ───────────────────────────
class UnitComponent extends PositionComponent with HasGameReference<ClashGame> {
  final Team team;
  final FighterSpec spec;
  final int lane;
  double hp;
  double _atkCd = 0;
  double _flash = 0;
  double _spawn = 0.35;
  late double _lastHp;

  UnitComponent({required this.team, required this.spec, required this.lane, required Vector2 pos})
      : hp = spec.maxHp,
        super(position: pos, anchor: Anchor.center) {
    _lastHp = hp;
  }

  bool get isDead => hp <= 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (_spawn > 0) _spawn = max(0, _spawn - dt);
    if (_flash > 0) _flash = max(0, _flash - dt);
    if (hp < _lastHp) _flash = 0.12;
    _lastHp = hp;

    if (game.result != null || isDead) return;
    _atkCd -= dt;
    final target = _findTarget();
    if (target == null) return;
    final tpos = target is UnitComponent ? target.position : (target as TowerComponent).position;
    final dist = tpos.distanceTo(position);
    if (dist <= spec.range) {
      if (_atkCd <= 0) {
        _atkCd = spec.attackInterval;
        if (target is UnitComponent) target.hp -= spec.damage;
        if (target is TowerComponent) target.hp -= spec.damage;
        // Portlovchi zarba (splash)
        if (spec.splash > 0) {
          game.world.add(BlastEffect(pos: tpos.clone(), maxR: spec.splash, color: const Color(0xFFFF9800), duration: 0.3));
          for (final u in game.units) {
            if (u.team == team || u.isDead || identical(u, target)) continue;
            if (u.position.distanceTo(tpos) <= spec.splash) u.hp -= spec.damage * 0.6;
          }
        }
      }
    } else {
      final dir = (tpos - position)..normalize();
      position.add(dir * spec.speed * dt);
    }
  }

  Object? _findTarget() {
    UnitComponent? nearest;
    double best = 150;
    for (final u in game.units) {
      if (u.team == team || u.isDead) continue;
      if ((u.position.x - position.x).abs() > 80) continue;
      final d = u.position.distanceTo(position);
      if (d < best) {
        best = d;
        nearest = u;
      }
    }
    return nearest ?? game.enemyTowerTargetFor(team, lane);
  }

  @override
  void render(Canvas canvas) {
    final scale = 1.0 - _spawn / 0.35 * 0.4;
    final r = 15.0 * scale;
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 13), width: r * 1.6, height: r * 0.5), Paint()..color = Colors.black.withValues(alpha: 0.25));
    canvas.drawCircle(Offset.zero, r, Paint()..color = spec.color.withValues(alpha: 0.9));
    canvas.drawCircle(
      Offset.zero, r,
      Paint()
        ..color = team == Team.player ? Colors.cyanAccent : Colors.redAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    if (_flash > 0) {
      canvas.drawCircle(Offset.zero, r, Paint()..color = Colors.white.withValues(alpha: _flash / 0.12 * 0.7));
    }
    _text(canvas, spec.emoji, Offset.zero, size: 16 * scale);
    _hpBar(canvas, const Offset(0, -22), 30, hp / spec.maxHp, spec.color);
  }
}

// ─────────────────────────── Tower ───────────────────────────
class TowerComponent extends PositionComponent with HasGameReference<ClashGame> {
  final Team team;
  final bool isKing;
  final int lane;
  double hp;
  final double maxHp;
  double _atkCd = 0;
  final double range = 118, damage = 22;
  bool _deadHandled = false;

  TowerComponent({required this.team, required this.isKing, required this.lane, required Vector2 pos})
      : hp = isKing ? 1000 : 520,
        maxHp = isKing ? 1000 : 520,
        super(position: pos, anchor: Anchor.center);

  bool get isDead => hp <= 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (isDead) {
      if (!_deadHandled) {
        _deadHandled = true;
        game.onTowerDestroyed(position.clone());
      }
      return;
    }
    if (game.result != null) return;
    _atkCd -= dt;
    if (_atkCd > 0) return;
    UnitComponent? target;
    double best = range;
    for (final u in game.units) {
      if (u.team == team || u.isDead) continue;
      final d = u.position.distanceTo(position);
      if (d < best) {
        best = d;
        target = u;
      }
    }
    if (target != null) {
      _atkCd = 0.85;
      target.hp -= damage;
    }
  }

  @override
  void render(Canvas canvas) {
    final wide = isKing ? 30.0 : 24.0;
    final tall = isKing ? 34.0 : 28.0;
    if (isDead) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, 8), width: wide * 1.4, height: tall * 0.6), const Radius.circular(5)),
        Paint()..color = Colors.black.withValues(alpha: 0.4),
      );
      _text(canvas, '🏚️', const Offset(0, 4), size: 18);
      return;
    }
    final body = team == Team.player ? const Color(0xFF2E6FB0) : const Color(0xFFB54250);
    final roof = team == Team.player ? const Color(0xFF64B5F6) : const Color(0xFFFF8A80);
    final rect = Rect.fromCenter(center: const Offset(0, 4), width: wide, height: tall);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), Paint()..color = body);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()
        ..color = team == Team.player ? Colors.cyanAccent : Colors.redAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final path = Path()
      ..moveTo(-wide / 2 - 2, -tall / 2 + 4)
      ..lineTo(0, -tall / 2 - 10)
      ..lineTo(wide / 2 + 2, -tall / 2 + 4)
      ..close();
    canvas.drawPath(path, Paint()..color = roof);
    _text(canvas, isKing ? '👑' : '🏰', const Offset(0, 5), size: isKing ? 20 : 15);
    _hpBar(canvas, Offset(0, -tall / 2 - 16), wide + 14, hp / maxHp, team == Team.player ? Colors.cyanAccent : Colors.redAccent);
  }
}

// ─────────────────────────── Game ───────────────────────────
class ClashGame extends FlameGame {
  final bool multiplayer;
  final void Function(Map<String, dynamic>)? onNetSend;
  ClashGame({this.multiplayer = false, this.onNetSend});

  final List<UnitComponent> units = [];
  final List<TowerComponent> towers = [];
  final Random _rng = Random();

  final ValueNotifier<double> playerEnergyN = ValueNotifier(5);
  final ValueNotifier<int> timeLeftN = ValueNotifier(180);
  final ValueNotifier<String?> resultN = ValueNotifier(null);
  final ValueNotifier<int> playerTowersN = ValueNotifier(3);
  final ValueNotifier<int> enemyTowersN = ValueNotifier(3);
  final ValueNotifier<int> shakeN = ValueNotifier(0); // ekran silkinishi triggeri

  double _playerEnergy = 5, _enemyEnergy = 5, _matchTime = 0, _botCd = 3;
  String? result;

  static const double _maxEnergy = 10, _matchDuration = 180;

  List<double> laneX = [0, 0];
  double _playerBaselineY = 0, _enemyBaselineY = 0;
  bool _built = false;

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    world.add(Battlefield());
    _tryBuild();
  }

  @override
  void onGameResize(Vector2 s) {
    super.onGameResize(s);
    _tryBuild();
  }

  void _tryBuild() {
    if (_built || size.x < 10 || size.y < 10) return;
    _built = true;
    final w = size.x, h = size.y;
    laneX = [w * 0.28, w * 0.72];
    _playerBaselineY = h * 0.70;
    _enemyBaselineY = h * 0.30;
    _addTower(Team.enemy, true, -1, Vector2(w * 0.5, h * 0.09));
    _addTower(Team.enemy, false, 0, Vector2(laneX[0], h * 0.20));
    _addTower(Team.enemy, false, 1, Vector2(laneX[1], h * 0.20));
    _addTower(Team.player, true, -1, Vector2(w * 0.5, h * 0.91));
    _addTower(Team.player, false, 0, Vector2(laneX[0], h * 0.80));
    _addTower(Team.player, false, 1, Vector2(laneX[1], h * 0.80));
  }

  void _addTower(Team team, bool isKing, int lane, Vector2 pos) {
    final t = TowerComponent(team: team, isKing: isKing, lane: lane, pos: pos);
    towers.add(t);
    world.add(t);
  }

  /// true — muvaffaqiyatli qo'llandi. Spell bo'lsa AoE, aks holda jangchi.
  bool spawnPlayer(FighterSpec spec, Offset tap) {
    if (result != null || !_built) return false;
    if (_playerEnergy < spec.cost) return false;
    _playerEnergy -= spec.cost;
    playerEnergyN.value = _playerEnergy;
    _sfx('deploy.wav');

    final lane = (tap.dx - laneX[0]).abs() <= (tap.dx - laneX[1]).abs() ? 0 : 1;

    if (spec.isSpell) {
      _castSpell(Team.player, spec, Vector2(tap.dx, tap.dy));
    } else {
      final y = tap.dy.clamp(size.y * 0.52, _playerBaselineY);
      _spawn(Team.player, spec, lane, Vector2(laneX[lane], y));
    }

    // Raqibga uzatamiz (u ekranida dushman bo'lib chiqadi)
    onNetSend?.call({
      'type': 'spawn',
      'specId': spec.id,
      'lane': lane,
      'spell': spec.isSpell,
      'nx': size.x > 0 ? tap.dx / size.x : 0.5,
      'ny': size.y > 0 ? tap.dy / size.y : 0.6,
    });
    return true;
  }

  /// Tarmoqdan kelgan raqib harakati — dushman jangchisi/spell sifatida qo'llaymiz.
  void applyNetAction(Map<String, dynamic> data) {
    if (!_built || result != null) return;
    final type = data['type'];
    if (type == 'result') {
      // Raqib bizni yutdi — mag'lub bo'lamiz
      _finish('lose', notify: false);
      return;
    }
    if (type != 'spawn') return;
    final specId = data['specId'] as String?;
    final lane = (data['lane'] as num?)?.toInt() ?? 0;
    final isSpell = data['spell'] == true;
    FighterSpec? spec;
    for (final f in kFighters) {
      if (f.id == specId) {
        spec = f;
        break;
      }
    }
    if (spec == null) return;

    if (isSpell) {
      // ny raqib tomonида — bizда vertikal ko'zgu
      final nx = (data['nx'] as num?)?.toDouble() ?? 0.5;
      final ny = (data['ny'] as num?)?.toDouble() ?? 0.4;
      _castSpell(Team.enemy, spec, Vector2(nx * size.x, (1 - ny) * size.y));
    } else {
      _spawn(Team.enemy, spec, lane.clamp(0, 1), Vector2(laneX[lane.clamp(0, 1)], _enemyBaselineY));
    }
  }

  void _castSpell(Team caster, FighterSpec spec, Vector2 at) {
    final enemy = caster == Team.player ? Team.enemy : Team.player;
    world.add(BlastEffect(pos: at.clone(), maxR: spec.aoeRadius, color: spec.color, duration: 0.45));
    for (final u in units) {
      if (u.team != enemy || u.isDead) continue;
      if (u.position.distanceTo(at) <= spec.aoeRadius) u.hp -= spec.damage;
    }
    for (final t in towers) {
      if (t.team != enemy || t.isDead) continue;
      if (t.position.distanceTo(at) <= spec.aoeRadius) t.hp -= spec.damage * 0.6;
    }
  }

  void _spawn(Team team, FighterSpec spec, int lane, Vector2 pos) {
    final u = UnitComponent(team: team, spec: spec, lane: lane, pos: pos);
    units.add(u);
    world.add(u);
  }

  void onTowerDestroyed(Vector2 pos) {
    world.add(ExplosionEffect(pos: pos));
    shakeN.value++;
    _sfx('explosion.wav');
  }

  void _sfx(String file) {
    AudioManager().playSFX('assets/sfx/$file');
  }

  TowerComponent? enemyTowerTargetFor(Team myTeam, int lane) {
    final enemy = myTeam == Team.player ? Team.enemy : Team.player;
    TowerComponent? side, king;
    for (final t in towers) {
      if (t.team != enemy || t.isDead) continue;
      if (!t.isKing && t.lane == lane) side = t;
      if (t.isKing) king = t;
    }
    return side ?? king;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (result != null || !_built) return;

    final rate = (_matchTime > _matchDuration - 60) ? (2 / 2.8) : (1 / 2.8);
    _playerEnergy = min(_maxEnergy, _playerEnergy + rate * dt);
    _enemyEnergy = min(_maxEnergy, _enemyEnergy + rate * dt);
    playerEnergyN.value = _playerEnergy;

    _matchTime += dt;
    timeLeftN.value = max(0, (_matchDuration - _matchTime).ceil());

    _runBot(dt);
    _cleanupDead();
    _checkResult();
  }

  void _runBot(double dt) {
    if (multiplayer) return; // online rejimда bot yo'q
    _botCd -= dt;
    if (_botCd > 0) return;
    _botCd = 1.8 + _rng.nextDouble() * 1.8;
    // Bot spell ishlatmaydi (faqat jangchilar)
    final affordable = kFighters.where((f) => !f.isSpell && f.cost <= _enemyEnergy).toList();
    if (affordable.isEmpty) return;
    final spec = affordable[_rng.nextInt(affordable.length)];
    final lane = _rng.nextInt(2);
    _enemyEnergy -= spec.cost;
    _spawn(Team.enemy, spec, lane, Vector2(laneX[lane], _enemyBaselineY));
  }

  void _cleanupDead() {
    final dead = units.where((u) => u.isDead).toList();
    for (final u in dead) {
      units.remove(u);
      u.removeFromParent();
    }
  }

  void _checkResult() {
    playerTowersN.value = towers.where((t) => t.team == Team.player && !t.isDead).length;
    enemyTowersN.value = towers.where((t) => t.team == Team.enemy && !t.isDead).length;

    final enemyKing = _king(Team.enemy);
    final playerKing = _king(Team.player);
    if (enemyKing != null && enemyKing.isDead) {
      _finish('win');
    } else if (playerKing != null && playerKing.isDead) {
      _finish('lose');
    } else if (_matchTime >= _matchDuration) {
      final p = playerTowersN.value, e = enemyTowersN.value;
      _finish(p > e ? 'win' : (p < e ? 'lose' : 'draw'));
    }
  }

  TowerComponent? _king(Team team) {
    for (final t in towers) {
      if (t.team == team && t.isKing) return t;
    }
    return null;
  }

  void _finish(String r, {bool notify = true}) {
    if (result != null) return;
    result = r;
    resultN.value = r;
    _sfx(r == 'win' ? 'win.wav' : r == 'lose' ? 'lose.wav' : 'coin.wav');
    // Online: biz yutgan bo'lsak, raqibga mag'lubiyatни bildiramiz
    if (multiplayer && notify && r == 'win') {
      onNetSend?.call({'type': 'result'});
    }
  }
}
