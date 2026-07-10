import 'dart:async';
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

class RocketRushScreen extends ConsumerStatefulWidget {
  const RocketRushScreen({super.key});

  @override
  ConsumerState<RocketRushScreen> createState() => _RocketRushScreenState();
}

class _RocketRushScreenState extends ConsumerState<RocketRushScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ParticleOverlayState> _particleKey = GlobalKey();
  final Random _random = Random();
  Timer? _timer;
  late AnimationController _pulseController;

  double _rocketY = 0;
  double _velocity = 0;
  final double _gravity = 0.22;
  final double _jumpStrength = -5.0;
  
  List<_Obstacle> _obstacles = [];
  List<_Star> _stars = [];
  int _score = 0;
  int _highScore = 0;
  bool _isPlaying = false;
  bool _isGameOver = false;
  double _gameSpeed = 4.5;
  int _collectedStars = 0;

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _highScore = prefs.getInt('rocket_rush_high_score') ?? 0);
  }

  void _startGame() {
    _timer?.cancel();
    setState(() {
      _rocketY = 0;
      _velocity = 0;
      _score = 0;
      _gameSpeed = 4.5;
      _obstacles = [];
      _collectedStars = 0;
      // Parallax star layers (layer 1, 2, 3)
      _stars = List.generate(60, (_) {
        final depth = _random.nextDouble();
        return _Star(
          _random.nextDouble() * 600,
          _random.nextDouble() * 1000,
          depth: depth < 0.3 ? 0.3 : (depth < 0.7 ? 0.6 : 1.0),
        );
      });
      _isPlaying = true;
      _isGameOver = false;
    });
    
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _update());
  }

  void _update() {
    if (!_isPlaying || _isGameOver) return;

    setState(() {
      _velocity += _gravity;
      _rocketY += _velocity;
      
      // Update star parallax
      for (var star in _stars) {
        star.x -= _gameSpeed * 0.2 * star.depth;
        if (star.x < -20) {
          star.x = MediaQuery.of(context).size.width + 20;
          star.y = _random.nextDouble() * MediaQuery.of(context).size.height;
        }
      }

      // Generate obstacles
      if (_obstacles.isEmpty || _obstacles.last.x < MediaQuery.of(context).size.width - 240) {
        double h = MediaQuery.of(context).size.height;
        double gapCenter = _random.nextDouble() * (h * 0.4) + (h * 0.3);
        _obstacles.add(_Obstacle(
          MediaQuery.of(context).size.width + 100, 
          gapCenter,
          hasBonusStar: _random.nextDouble() < 0.4
        ));
      }

      // Update obstacles
      for (int i = _obstacles.length - 1; i >= 0; i--) {
        _obstacles[i].x -= _gameSpeed;

        // Check if passed obstacle
        if (!_obstacles[i].passed && _obstacles[i].x < 80) {
          _obstacles[i].passed = true;
          _score++;
          _gameSpeed += 0.08;
        }

        // Check star collection
        if (_obstacles[i].hasBonusStar && !_obstacles[i].starCollected && _obstacles[i].x < 110 && _obstacles[i].x > 50) {
          double ry = MediaQuery.of(context).size.height / 2 + _rocketY;
          if ((ry - _obstacles[i].gapY).abs() < 50) {
            _obstacles[i].starCollected = true;
            _collectedStars++;
            _score += 3; // Bonus points
            HapticFeedback.lightImpact();
            _particleKey.currentState?.showBurst(
              Offset(80, ry), 
              color: Colors.amberAccent
            );
          }
        }

        if (_checkCollision(_obstacles[i])) {
          _triggerGameOver();
        }

        if (_obstacles[i].x < -100) {
          _obstacles.removeAt(i);
        }
      }

      // Screen boundary check
      double mid = MediaQuery.of(context).size.height / 2;
      if (mid + _rocketY > MediaQuery.of(context).size.height - 40 || mid + _rocketY < 40) {
        _triggerGameOver();
      }
    });
  }

  bool _checkCollision(_Obstacle ob) {
    double rx = 80;
    double ry = MediaQuery.of(context).size.height / 2 + _rocketY;
    double gap = 190;

    // Rocket box width: ~40, height: ~24
    if (rx + 18 > ob.x && rx - 18 < ob.x + 55) {
      if (ry - 12 < ob.gapY - (gap/2) || ry + 12 > ob.gapY + (gap/2)) {
        return true;
      }
    }
    return false;
  }

  void _triggerGameOver() async {
    _timer?.cancel();
    setState(() { 
      _isPlaying = false; 
      _isGameOver = true; 
    });
    HapticFeedback.vibrate();
    _particleKey.currentState?.showBurst(
      Offset(80, MediaQuery.of(context).size.height/2 + _rocketY), 
      color: Colors.redAccent
    );

    // Save score using ScoreManager
    await ScoreManager().saveResult(
      gameType: 'GRAVITY_RUN',
      score: _score,
      coins: _score + (_collectedStars * 5),
      api: ref.read(apiServiceProvider),
      ref: ref,
    );
    _loadHighScore();
  }

  @override
  Widget build(BuildContext context) {
    return ParticleOverlay(
      overlayKey: _particleKey,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF060518), Color(0xFF0C072E), Color(0xFF050314)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) {
              if (!_isPlaying) {
                _startGame();
              } else {
                setState(() => _velocity = _jumpStrength);
                // Particle trail on jump
                _particleKey.currentState?.showBurst(
                  Offset(65, MediaQuery.of(context).size.height/2 + _rocketY + 10), 
                  color: Colors.cyanAccent.withOpacity(0.6)
                );
              }
              HapticFeedback.lightImpact();
            },
            child: Stack(
              children: [
                // Starry background parallax
                ..._stars.map((s) => Positioned(
                  left: s.x,
                  top: s.y,
                  child: Container(
                    width: s.depth * 3.5,
                    height: s.depth * 3.5,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(s.depth * 0.7),
                      shape: BoxShape.circle,
                      boxShadow: s.depth > 0.7 ? [
                        BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 4, spreadRadius: 1)
                      ] : null,
                    ),
                  ),
                )),
                
                // Obstacles
                ..._obstacles.map((ob) => Stack(
                  children: [
                    // Top obstacle pillar
                    Positioned(
                      left: ob.x, 
                      top: 0, 
                      child: _ObPart(h: ob.gapY - 95, isTop: true)
                    ),
                    // Bottom obstacle pillar
                    Positioned(
                      left: ob.x, 
                      top: ob.gapY + 95, 
                      child: _ObPart(h: MediaQuery.of(context).size.height - (ob.gapY + 95), isTop: false)
                    ),
                    // Collectible space-star in the middle of gap
                    if (ob.hasBonusStar && !ob.starCollected)
                      Positioned(
                        left: ob.x + 15,
                        top: ob.gapY - 20,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1.0 + (_pulseController.value * 0.25),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amberAccent.withOpacity(0.6),
                                      blurRadius: 12,
                                      spreadRadius: 2
                                    )
                                  ]
                                ),
                                child: const Icon(
                                  Icons.star_rounded, 
                                  color: Colors.amber, 
                                  size: 30
                                ),
                              ),
                            );
                          }
                        ),
                      )
                  ],
                )),

                // Rocket Player
                Positioned(
                  left: 80 - 20,
                  top: MediaQuery.of(context).size.height / 2 + _rocketY - 20,
                  child: Transform.rotate(
                    angle: _velocity * 0.08,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Thruster flame effect
                        if (_isPlaying)
                          Positioned(
                            left: -12,
                            child: AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Icon(
                                  Icons.local_fire_department_rounded,
                                  color: _pulseController.value > 0.5 ? Colors.deepOrange : Colors.orangeAccent,
                                  size: 26,
                                );
                              }
                            ),
                          ),
                        // Neon styled rocket icon
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyanAccent.withOpacity(0.4),
                                blurRadius: 15,
                                spreadRadius: 2,
                              )
                            ]
                          ),
                          child: const Icon(
                            Icons.rocket_launch_rounded,
                            color: Colors.cyanAccent,
                            size: 40
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Score HUD
                Positioned(
                  top: 55,
                  left: 24,
                  right: 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 28),
                          const SizedBox(width: 4),
                          Text(
                            '$_score',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                const Shadow(color: Colors.cyanAccent, blurRadius: 10)
                              ]
                            )
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            '$_collectedStars',
                            style: GoogleFonts.outfit(
                              color: Colors.amberAccent,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Text(
                            'BEST: $_highScore',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 0.5
                            )
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Title / Game Over Screen overlay
                if (!_isPlaying)
                  Container(
                    color: Colors.black.withOpacity(0.75),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isGameOver ? 'YUTQAZDINGIZ' : 'ROCKET RUSH',
                            style: GoogleFonts.outfit(
                              color: _isGameOver ? Colors.redAccent : Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              shadows: [
                                Shadow(
                                  color: _isGameOver ? Colors.red : Colors.cyanAccent,
                                  blurRadius: 15
                                )
                              ]
                            )
                          ),
                          const SizedBox(height: 12),
                          if (_isGameOver) ...[
                            Text(
                              'Hozirgi ball: $_score',
                              style: const TextStyle(
                                color: Colors.white90,
                                fontSize: 18,
                                fontWeight: FontWeight.w600
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Yig\'ilgan yulduzlar: $_collectedStars',
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.w500
                              ),
                            ),
                            const SizedBox(height: 30),
                          ] else ...[
                            const Text(
                              'UCHISH UCHUN EKRANGA BOSING',
                              style: TextStyle(
                                color: Colors.white54,
                                letterSpacing: 2.0,
                                fontSize: 13,
                                fontWeight: FontWeight.w700
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: 1.0 + (_pulseController.value * 0.1),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _isGameOver ? Colors.redAccent : Colors.cyanAccent,
                                      width: 2
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_isGameOver ? Colors.red : Colors.cyanAccent).withOpacity(0.3),
                                        blurRadius: 15,
                                        spreadRadius: 1
                                      )
                                    ]
                                  ),
                                  child: Icon(
                                    _isGameOver ? Icons.refresh_rounded : Icons.rocket_launch_rounded,
                                    color: _isGameOver ? Colors.redAccent : Colors.cyanAccent,
                                    size: 40
                                  ),
                                ),
                              );
                            }
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ObPart extends StatelessWidget {
  final double h; 
  final bool isTop;
  
  const _ObPart({required this.h, required this.isTop});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 55, 
      height: h, 
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1B1846),
            const Color(0xFF0F0E2A),
            const Color(0xFF060515)
          ],
          begin: isTop ? Alignment.bottomCenter : Alignment.topCenter,
          end: isTop ? Alignment.topCenter : Alignment.bottomCenter,
        ),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.12), width: 1.5),
        borderRadius: BorderRadius.only(
          bottomLeft: isTop ? const Radius.circular(10) : Radius.zero,
          bottomRight: isTop ? const Radius.circular(10) : Radius.zero,
          topLeft: !isTop ? const Radius.circular(10) : Radius.zero,
          topRight: !isTop ? const Radius.circular(10) : Radius.zero,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withOpacity(0.04),
            blurRadius: 8,
            spreadRadius: 1
          )
        ]
      ),
    );
  }
}

class _Obstacle {
  double x, gapY;
  bool passed = false;
  bool hasBonusStar;
  bool starCollected = false;

  _Obstacle(this.x, this.gapY, {this.hasBonusStar = false});
}

class _Star {
  double x, y;
  double depth;

  _Star(this.x, this.y, {required this.depth});
}
