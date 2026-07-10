import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'auth_provider.dart';
import 'widgets/particle_overlay.dart';
import 'widgets/score_manager.dart';
import 'widgets/bouncy_button.dart';

class StarLevel {
  final int size;
  final List<StarPair> pairs;
  StarLevel({required this.size, required this.pairs});
}

class StarPair {
  final int colorId;
  final Offset start;
  final Offset end;
  StarPair(this.colorId, this.start, this.end);
}

class StarConnectScreen extends ConsumerStatefulWidget {
  const StarConnectScreen({super.key});

  @override
  ConsumerState<StarConnectScreen> createState() => _StarConnectScreenState();
}

class _StarConnectScreenState extends ConsumerState<StarConnectScreen> {
  final GlobalKey<ParticleOverlayState> _particleKey = GlobalKey();
  final GlobalKey _gridKey = GlobalKey();
  
  int _currentLevelIdx = 0;
  final List<StarLevel> _levels = [
    // --- 5x5 Levels ---
    StarLevel(size: 5, pairs: [
      StarPair(0, const Offset(0, 0), const Offset(4, 0)),
      StarPair(1, const Offset(0, 1), const Offset(4, 4)),
      StarPair(2, const Offset(1, 1), const Offset(3, 3)),
    ]),
    StarLevel(size: 5, pairs: [
      StarPair(0, const Offset(0, 0), const Offset(0, 4)),
      StarPair(1, const Offset(1, 0), const Offset(4, 0)),
      StarPair(2, const Offset(1, 1), const Offset(4, 4)),
      StarPair(3, const Offset(2, 2), const Offset(3, 3)),
    ]),
    StarLevel(size: 5, pairs: [
      StarPair(0, const Offset(0, 0), const Offset(4, 4)),
      StarPair(1, const Offset(0, 4), const Offset(4, 0)),
      StarPair(2, const Offset(2, 0), const Offset(2, 4)),
    ]),
    StarLevel(size: 5, pairs: [
      StarPair(0, const Offset(0, 2), const Offset(4, 2)),
      StarPair(1, const Offset(2, 0), const Offset(2, 4)),
      StarPair(2, const Offset(0, 0), const Offset(1, 1)),
      StarPair(3, const Offset(4, 4), const Offset(3, 3)),
    ]),
    StarLevel(size: 5, pairs: [
      StarPair(0, const Offset(0, 0), const Offset(2, 2)),
      StarPair(1, const Offset(4, 0), const Offset(3, 1)),
      StarPair(2, const Offset(0, 4), const Offset(1, 3)),
      StarPair(3, const Offset(4, 4), const Offset(2, 3)),
    ]),

    // --- 6x6 Levels ---
    StarLevel(size: 6, pairs: [
      StarPair(0, const Offset(0, 0), const Offset(5, 5)),
      StarPair(1, const Offset(0, 1), const Offset(1, 5)),
      StarPair(2, const Offset(2, 0), const Offset(5, 0)),
      StarPair(3, const Offset(2, 1), const Offset(4, 4)),
    ]),
    StarLevel(size: 6, pairs: [
      StarPair(0, const Offset(0, 0), const Offset(0, 5)),
      StarPair(1, const Offset(1, 0), const Offset(1, 5)),
      StarPair(2, const Offset(2, 0), const Offset(5, 0)),
      StarPair(3, const Offset(2, 1), const Offset(5, 1)),
      StarPair(4, const Offset(3, 3), const Offset(4, 4)),
    ]),
    StarLevel(size: 6, pairs: [
      StarPair(0, const Offset(0, 3), const Offset(5, 3)),
      StarPair(1, const Offset(1, 1), const Offset(1, 4)),
      StarPair(2, const Offset(4, 1), const Offset(4, 4)),
      StarPair(3, const Offset(0, 0), const Offset(5, 0)),
    ]),
    StarLevel(size: 6, pairs: [
      StarPair(0, const Offset(0, 0), const Offset(5, 5)),
      StarPair(1, const Offset(5, 0), const Offset(0, 5)),
      StarPair(2, const Offset(2, 2), const Offset(3, 3)),
      StarPair(3, const Offset(1, 1), const Offset(4, 4)),
    ]),
    StarLevel(size: 6, pairs: [
      StarPair(0, const Offset(0, 0), const Offset(2, 0)),
      StarPair(1, const Offset(3, 0), const Offset(5, 0)),
      StarPair(2, const Offset(0, 5), const Offset(2, 5)),
      StarPair(3, const Offset(3, 5), const Offset(5, 5)),
      StarPair(4, const Offset(1, 2), const Offset(4, 2)),
    ]),

    // --- 7x7 Levels ---
    StarLevel(size: 7, pairs: [
      StarPair(0, const Offset(0, 0), const Offset(6, 6)),
      StarPair(1, const Offset(0, 1), const Offset(6, 5)),
      StarPair(2, const Offset(1, 0), const Offset(5, 6)),
      StarPair(3, const Offset(3, 3), const Offset(4, 4)),
    ]),
    StarLevel(size: 7, pairs: [
      StarPair(0, const Offset(0, 0), const Offset(0, 6)),
      StarPair(1, const Offset(1, 0), const Offset(6, 0)),
      StarPair(2, const Offset(6, 1), const Offset(6, 6)),
      StarPair(3, const Offset(1, 6), const Offset(5, 6)),
      StarPair(4, const Offset(3, 1), const Offset(3, 5)),
    ]),
    StarLevel(size: 7, pairs: [
      StarPair(0, const Offset(0, 3), const Offset(6, 3)),
      StarPair(1, const Offset(3, 0), const Offset(3, 6)),
      StarPair(2, const Offset(1, 1), const Offset(5, 5)),
      StarPair(3, const Offset(5, 1), const Offset(1, 5)),
    ]),
    StarLevel(size: 7, pairs: [
      StarPair(0, const Offset(0, 0), const Offset(1, 1)),
      StarPair(1, const Offset(5, 5), const Offset(6, 6)),
      StarPair(2, const Offset(0, 6), const Offset(6, 0)),
      StarPair(3, const Offset(3, 0), const Offset(3, 6)),
      StarPair(4, const Offset(0, 3), const Offset(6, 3)),
    ]),
    StarLevel(size: 7, pairs: [
      StarPair(0, const Offset(0, 0), const Offset(2, 2)),
      StarPair(1, const Offset(4, 4), const Offset(6, 6)),
      StarPair(2, const Offset(0, 6), const Offset(2, 4)),
      StarPair(3, const Offset(4, 2), const Offset(6, 0)),
      StarPair(4, const Offset(3, 0), const Offset(3, 3)),
    ]),

    // --- 8x8 Levels (Pro) ---
    StarLevel(size: 8, pairs: [
      StarPair(0, const Offset(0, 0), const Offset(7, 7)),
      StarPair(1, const Offset(0, 7), const Offset(7, 0)),
      StarPair(2, const Offset(3, 0), const Offset(3, 7)),
      StarPair(3, const Offset(0, 3), const Offset(7, 3)),
      StarPair(4, const Offset(1, 1), const Offset(6, 6)),
    ]),
    StarLevel(size: 8, pairs: [
      StarPair(0, const Offset(0, 0), const Offset(0, 7)),
      StarPair(1, const Offset(1, 0), const Offset(7, 0)),
      StarPair(2, const Offset(7, 1), const Offset(7, 7)),
      StarPair(3, const Offset(1, 7), const Offset(6, 7)),
      StarPair(4, const Offset(2, 2), const Offset(5, 5)),
      StarPair(5, const Offset(2, 5), const Offset(5, 2)),
    ]),
    StarLevel(size: 8, pairs: [
      StarPair(0, const Offset(0, 0), const Offset(7, 0)),
      StarPair(1, const Offset(0, 1), const Offset(7, 1)),
      StarPair(2, const Offset(0, 6), const Offset(7, 6)),
      StarPair(3, const Offset(0, 7), const Offset(7, 7)),
      StarPair(4, const Offset(3, 3), const Offset(4, 4)),
    ]),
    StarLevel(size: 8, pairs: [
      StarPair(0, const Offset(0, 0), const Offset(4, 4)),
      StarPair(1, const Offset(7, 7), const Offset(3, 3)),
      StarPair(2, const Offset(0, 7), const Offset(4, 3)),
      StarPair(3, const Offset(7, 0), const Offset(3, 4)),
      StarPair(4, const Offset(1, 1), const Offset(6, 6)),
    ]),
    StarLevel(size: 8, pairs: [
      StarPair(0, const Offset(0, 0), const Offset(2, 0)),
      StarPair(1, const Offset(0, 1), const Offset(2, 1)),
      StarPair(2, const Offset(5, 0), const Offset(7, 0)),
      StarPair(3, const Offset(5, 1), const Offset(7, 1)),
      StarPair(4, const Offset(0, 7), const Offset(7, 7)),
      StarPair(5, const Offset(3, 3), const Offset(4, 4)),
    ]),
    
    // Additional variety
    StarLevel(size: 5, pairs: [StarPair(0, const Offset(0,0), const Offset(4,4)), StarPair(1, const Offset(0,4), const Offset(4,0)), StarPair(2, const Offset(2,1), const Offset(2,3))]),
    StarLevel(size: 5, pairs: [StarPair(0, const Offset(1,1), const Offset(3,3)), StarPair(1, const Offset(1,3), const Offset(3,1)), StarPair(2, const Offset(0,0), const Offset(4,4))]),
    StarLevel(size: 6, pairs: [StarPair(0, const Offset(0,0), const Offset(5,5)), StarPair(1, const Offset(0,5), const Offset(5,0)), StarPair(2, const Offset(1,2), const Offset(4,2)), StarPair(3, const Offset(1,3), const Offset(4,3))]),
    StarLevel(size: 6, pairs: [StarPair(0, const Offset(0,0), const Offset(0,1)), StarPair(1, const Offset(5,0), const Offset(0,5)), StarPair(2, const Offset(1,1), const Offset(4,4))]),
    StarLevel(size: 7, pairs: [StarPair(0, const Offset(0,0), const Offset(6,6)), StarPair(1, const Offset(3,0), const Offset(3,6)), StarPair(2, const Offset(0,3), const Offset(6,3))]),
    StarLevel(size: 7, pairs: [StarPair(0, const Offset(1,1), const Offset(5,5)), StarPair(1, const Offset(1,5), const Offset(5,1)), StarPair(2, const Offset(3,0), const Offset(3,6))]),
    StarLevel(size: 8, pairs: [StarPair(0, const Offset(0,0), const Offset(7,7)), StarPair(1, const Offset(3,3), const Offset(4,4)), StarPair(2, const Offset(0,7), const Offset(7,0))]),
    StarLevel(size: 8, pairs: [StarPair(0, const Offset(1,1), const Offset(6,6)), StarPair(1, const Offset(1,6), const Offset(6,1)), StarPair(2, const Offset(3,0), const Offset(4,7))]),
    StarLevel(size: 8, pairs: [StarPair(0, const Offset(0,0), const Offset(1,1)), StarPair(1, const Offset(2,2), const Offset(3,3)), StarPair(2, const Offset(4,4), const Offset(5,5)), StarPair(3, const Offset(6,6), const Offset(7,7))]),
    StarLevel(size: 8, pairs: [StarPair(0, const Offset(0,0), const Offset(7,0)), StarPair(1, const Offset(0,7), const Offset(7,7)), StarPair(2, const Offset(3,3), const Offset(4,4)), StarPair(3, const Offset(3,4), const Offset(4,3))]),
  ];

  final List<Color> _pairColors = [
    Colors.redAccent, Colors.blueAccent, Colors.greenAccent,
    Colors.yellowAccent, Colors.purpleAccent, Colors.orangeAccent,
    Colors.cyanAccent, Colors.pinkAccent,
  ];

  Map<int, List<Offset>> _paths = {};
  int? _activeColorId;
  bool _isLevelComplete = false;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentLevelIdx = (prefs.getInt('star_connect_level') ?? 0) % _levels.length;
      _paths = {};
      _isLevelComplete = false;
      _activeColorId = null;
    });
  }

  void _handleInput(Offset globalPos) {
    if (_isLevelComplete) return;
    final RenderBox gridBox = _gridKey.currentContext?.findRenderObject() as RenderBox;
    final Offset localPos = gridBox.globalToLocal(globalPos);
    final level = _levels[_currentLevelIdx];
    final double cellSize = gridBox.size.width / level.size;
    
    int col = (localPos.dx / cellSize).floor();
    int row = (localPos.dy / cellSize).floor();

    if (row >= 0 && row < level.size && col >= 0 && col < level.size) {
      final pos = Offset(col.toDouble(), row.toDouble());
      
      if (_activeColorId == null) {
        for (var pair in level.pairs) {
          if (pair.start == pos || pair.end == pos) {
            setState(() {
              _activeColorId = pair.colorId;
              _paths[_activeColorId!] = [pos];
            });
            HapticFeedback.lightImpact();
            break;
          }
        }
        return;
      }

      final currentPath = _paths[_activeColorId!]!;
      if (currentPath.last != pos) {
        int? otherColorId;
        _paths.forEach((cid, path) {
          if (cid != _activeColorId && path.contains(pos)) otherColorId = cid;
        });

        if (otherColorId != null) {
           setState(() => _paths.remove(otherColorId));
           HapticFeedback.mediumImpact();
        }

        final last = currentPath.last;
        if ((last.dx - pos.dx).abs() + (last.dy - pos.dy).abs() == 1) {
          setState(() {
            if (currentPath.length > 1 && currentPath[currentPath.length - 2] == pos) {
              currentPath.removeLast();
            } else if (!currentPath.contains(pos)) {
              bool isBlockedByStar = false;
              for (var pair in level.pairs) {
                if (pair.colorId != _activeColorId && (pair.start == pos || pair.end == pos)) {
                  isBlockedByStar = true;
                  break;
                }
              }
              if (!isBlockedByStar) {
                 currentPath.add(pos);
              }
            }
          });
          HapticFeedback.selectionClick();
          
          final pair = level.pairs.firstWhere((p) => p.colorId == _activeColorId);
          if ((pos == pair.start || pos == pair.end) && currentPath.length > 1) {
            _activeColorId = null;
            HapticFeedback.lightImpact();
            _checkWin();
          }
        }
      }
    }
  }

  void _checkWin() {
    final level = _levels[_currentLevelIdx];
    bool allConnected = true;
    for (var pair in level.pairs) {
      final path = _paths[pair.colorId];
      if (path == null || path.length < 2 || 
         !((path.first == pair.start && path.last == pair.end) || 
           (path.first == pair.end && path.last == pair.start))) {
        allConnected = false;
        break;
      }
    }

    if (allConnected) {
      setState(() => _isLevelComplete = true);
      _onLevelWin();
    }
  }

  void _onLevelWin() async {
    _particleKey.currentState?.showBurst(const Offset(200, 300), color: GamesTheme.primary);
    await ScoreManager().saveResult(
      gameType: 'STAR_CONNECT',
      score: 100,
      level: _currentLevelIdx + 1,
      coins: 50,
      api: ref.read(apiServiceProvider),
      ref: ref,
    );
    
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _currentLevelIdx = (_currentLevelIdx + 1) % _levels.length;
          _paths = {};
          _isLevelComplete = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final level = _levels[_currentLevelIdx];

    return ParticleOverlay(
      overlayKey: _particleKey,
      child: Scaffold(
        backgroundColor: GamesTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent, elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
          title: const Text('STAR CONNECT PRO', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('DARAJA ${_currentLevelIdx + 1}', style: const TextStyle(color: GamesTheme.primary, fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('${level.size}x${level.size} MAYDON', style: const TextStyle(color: GamesTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Spacer(),
            GestureDetector(
              onPanStart: (d) => _handleInput(d.globalPosition),
              onPanUpdate: (d) => _handleInput(d.globalPosition),
              onPanEnd: (_) => setState(() => _activeColorId = null),
              child: Container(
                key: _gridKey,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(color: const Color(0xFF141436), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)]),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double cellSize = constraints.maxWidth / level.size;
                      return Stack(
                        children: [
                          // Grid
                          ...List.generate(level.size, (r) => List.generate(level.size, (c) => Positioned(
                            left: c * cellSize, top: r * cellSize, width: cellSize, height: cellSize,
                            child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white.withOpacity(0.02)))),
                          ))).expand((e) => e),
                          
                          // Paths
                          ..._paths.entries.map((entry) => CustomPaint(
                            painter: _PathPainter(entry.value, cellSize, _pairColors[entry.key % _pairColors.length]),
                            size: Size(constraints.maxWidth, constraints.maxWidth),
                          )),

                          // Stars
                          ...level.pairs.map((pair) {
                            final color = _pairColors[pair.colorId % _pairColors.length];
                            return Stack(children: [
                              _StarDot(pos: pair.start, size: cellSize, color: color),
                              _StarDot(pos: pair.end, size: cellSize, color: color),
                            ]);
                          }),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const Spacer(),
            if (_isLevelComplete)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: const Text('DARAJA YUTULDI! ✨', style: TextStyle(color: GamesTheme.success, fontSize: 24, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _StarDot extends StatelessWidget {
  final Offset pos; final double size; final Color color;
  const _StarDot({required this.pos, required this.size, required this.color});
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: pos.dx * size, top: pos.dy * size, width: size, height: size,
      child: Center(
        child: Container(
          width: size * 0.7, height: size * 0.7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 15)]),
          child: const Icon(Icons.star_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  final List<Offset> points; final double cellSize; final Color color;
  _PathPainter(this.points, this.cellSize, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()..color = color..strokeWidth = 14..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final path = Path();
    path.moveTo(points.first.dx * cellSize + cellSize/2, points.first.dy * cellSize + cellSize/2);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx * cellSize + cellSize/2, points[i].dy * cellSize + cellSize/2);
    }
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
