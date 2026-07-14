import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import 'clash_game.dart';

class ClashScreen extends StatefulWidget {
  final dynamic socket; // IO.Socket (online rejim); null bo'lsa bot bilan
  final String? opponentId;
  const ClashScreen({super.key, this.socket, this.opponentId});
  @override
  State<ClashScreen> createState() => _ClashScreenState();
}

class _ClashScreenState extends State<ClashScreen> with SingleTickerProviderStateMixin {
  late ClashGame _game;
  FighterSpec _selected = kFighters.first;
  late final AnimationController _shakeCtl;

  bool get _online => widget.socket != null;

  @override
  void initState() {
    super.initState();
    _shakeCtl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _game = _makeGame();
    _bind();
    if (_online) {
      widget.socket.on('clash_action', _onNet);
    }
  }

  ClashGame _makeGame() {
    return ClashGame(
      multiplayer: _online,
      onNetSend: _online
          ? (data) {
              data['to'] = widget.opponentId;
              widget.socket.emit('clash_action', data);
            }
          : null,
    );
  }

  void _onNet(dynamic d) {
    try {
      _game.applyNetAction(Map<String, dynamic>.from(d as Map));
    } catch (_) {}
  }

  void _bind() => _game.shakeN.addListener(_shakeNow);
  void _unbind() => _game.shakeN.removeListener(_shakeNow);

  void _shakeNow() {
    HapticFeedback.heavyImpact();
    if (mounted) _shakeCtl.forward(from: 0);
  }

  @override
  void dispose() {
    _unbind();
    if (_online) {
      try {
        widget.socket.off('clash_action', _onNet);
        widget.socket.disconnect();
      } catch (_) {}
    }
    _shakeCtl.dispose();
    super.dispose();
  }

  void _restart() {
    // Online rejimда qayta o'yin — lobbyга qaytish kerak
    if (_online) {
      Navigator.pop(context);
      return;
    }
    _unbind();
    setState(() {
      _game = _makeGame();
      _selected = kFighters.first;
    });
    _bind();
  }

  void _onArenaTap(TapDownDetails d) {
    if (_game.spawnPlayer(_selected, d.localPosition)) {
      HapticFeedback.selectionClick();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚡ Energiya yetarli emas'),
        backgroundColor: Colors.redAccent,
        duration: Duration(milliseconds: 650),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: _onArenaTap,
              child: AnimatedBuilder(
                animation: _shakeCtl,
                builder: (_, child) {
                  final t = _shakeCtl.value;
                  final dx = t == 0 ? 0.0 : sin(t * pi * 4) * (1 - t) * 9;
                  return Transform.translate(offset: Offset(dx, 0), child: child);
                },
                child: GameWidget(game: _game),
              ),
            ),
          ),

          // Yuqori HUD
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _glass(IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  )),
                  _TowerVs(game: _game),
                  _glass(ValueListenableBuilder<int>(
                    valueListenable: _game.timeLeftN,
                    builder: (_, t, __) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Text('⏱ ${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  )),
                ],
              ),
            ),
          ),

          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _BottomPanel(
              game: _game,
              selected: _selected,
              onSelect: (s) => setState(() => _selected = s),
            ),
          ),

          ValueListenableBuilder<String?>(
            valueListenable: _game.resultN,
            builder: (_, res, __) => res == null
                ? const SizedBox.shrink()
                : _ResultOverlay(result: res, onExit: () => Navigator.pop(context), onRematch: _restart),
          ),
        ],
      ),
    );
  }

  Widget _glass(Widget child) => Container(
        decoration: BoxDecoration(color: const Color(0xCC0F0F28), borderRadius: BorderRadius.circular(14)),
        child: child,
      );
}

class _TowerVs extends StatelessWidget {
  final ClashGame game;
  const _TowerVs({required this.game});
  @override
  Widget build(BuildContext context) {
    Widget side(ValueNotifier<int> n, Color c) => ValueListenableBuilder<int>(
          valueListenable: n,
          builder: (_, v, __) => Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.castle_rounded, color: c, size: 16),
            const SizedBox(width: 3),
            Text('$v', style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 15)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xCC0F0F28), borderRadius: BorderRadius.circular(14)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        side(game.playerTowersN, Colors.cyanAccent),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('VS', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 12))),
        side(game.enemyTowersN, Colors.redAccent),
      ]),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final ClashGame game;
  final FighterSpec selected;
  final ValueChanged<FighterSpec> onSelect;
  const _BottomPanel({required this.game, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xF20F0F28), Color(0xFF070714)]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ValueListenableBuilder<double>(
            valueListenable: game.playerEnergyN,
            builder: (_, e, __) {
              final full = e.floor();
              return Row(children: [
                const Text('⚡', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Expanded(
                  child: Row(
                    children: List.generate(10, (i) {
                      final on = i < full;
                      return Expanded(
                        child: Container(
                          height: 12,
                          margin: EdgeInsets.only(right: i == 9 ? 0 : 3),
                          decoration: BoxDecoration(
                            color: on ? const Color(0xFFFFC107) : Colors.white12,
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: on ? [const BoxShadow(color: Color(0x88FFC107), blurRadius: 5)] : null,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$full', style: const TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.w900, fontSize: 15)),
              ]);
            },
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<double>(
            valueListenable: game.playerEnergyN,
            builder: (_, e, __) => Row(
              children: kFighters.map((f) {
                final can = e >= f.cost;
                final sel = f.id == selected.id;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelect(f);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [f.color.withValues(alpha: sel ? 0.42 : 0.16), f.color.withValues(alpha: 0.05)],
                        ),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: sel ? f.color : Colors.white12, width: sel ? 2.2 : 1),
                        boxShadow: sel ? [BoxShadow(color: f.color.withValues(alpha: 0.5), blurRadius: 11)] : null,
                      ),
                      child: Opacity(
                        opacity: can ? 1 : 0.4,
                        child: Column(children: [
                          Text(f.emoji, style: const TextStyle(fontSize: 22)),
                          const SizedBox(height: 2),
                          FittedBox(child: Text(f.name, style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w600))),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: const Color(0x33FFC107), borderRadius: BorderRadius.circular(7)),
                            child: Text('⚡${f.cost}', style: const TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.w900, fontSize: 10)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
          const Text('Kartani tanlab, maydonga bosing', style: TextStyle(color: Colors.white38, fontSize: 10)),
        ]),
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  final String result;
  final VoidCallback onExit, onRematch;
  const _ResultOverlay({required this.result, required this.onExit, required this.onRematch});

  @override
  Widget build(BuildContext context) {
    final win = result == 'win';
    final draw = result == 'draw';
    final title = win ? 'G\'ALABA!' : draw ? 'DURANG' : 'MAG\'LUBIYAT';
    final emoji = win ? '🏆' : draw ? '🤝' : '💀';
    final color = win ? GamesTheme.success : draw ? GamesTheme.accent : Colors.redAccent;
    final trophy = win ? '+30 🏆' : draw ? '+0 🏆' : '−20 🏆';

    return Container(
      color: Colors.black.withValues(alpha: 0.78),
      alignment: Alignment.center,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 64)),
        const SizedBox(height: 8),
        Text(title, style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
          child: Text(trophy, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 28),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: color, foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onRematch,
            icon: const Icon(Icons.replay_rounded),
            label: const Text('YANA', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 14),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white30),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onExit,
            child: const Text('CHIQISH'),
          ),
        ]),
      ]),
    );
  }
}
