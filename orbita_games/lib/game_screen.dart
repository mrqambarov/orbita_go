import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';

// ─── Game Objects ───────────────────────────────────────────────────────────

class SpacePlanet {
  final double x;
  double y;
  final double radius;
  final Color color;
  final double rotationSpeed; // rad per frame
  final bool hasMine;
  double mineAngle = 0;

  SpacePlanet({
    required this.x,
    required this.y,
    required this.radius,
    required this.color,
    required this.rotationSpeed,
    this.hasMine = false,
  });
}

class SpaceCoin {
  final double x;
  double y;
  bool isCollected = false;

  SpaceCoin({required this.x, required this.y});
}

class SpacePowerUp {
  final double x;
  double y;
  final String type; // 'shield'
  bool isCollected = false;

  SpacePowerUp({required this.x, required this.y, required this.type});
}

class GameParticle {
  double x;
  double y;
  double vx;
  double vy;
  double life; // 1.0 to 0.0
  final Color color;

  GameParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.color,
  });
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final Random _random = Random();

  // Screen size
  Size _screenSize = Size.zero;

  // Game state
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isGameOver = false;

  // Score & Coins
  int _score = 0;
  int _coinsCollected = 0;

  // Player state
  double _playerX = 0;
  double _playerY = 0;
  double _playerVx = 0;
  double _playerVy = 0;
  double _playerAngle = 0; // angle relative to current planet
  double _playerRotDirection = 1; // 1 = clockwise, -1 = counter-clockwise

  // Orbit state
  SpacePlanet? _currentPlanet;
  bool _isInFlight = false;
  bool _hasShield = false;

  // Camera offset for scrolling
  double _cameraY = 0;
  double _targetCameraY = 0;

  // Spawns
  final List<SpacePlanet> _planets = [];
  final List<SpaceCoin> _coins = [];
  final List<SpacePowerUp> _powerups = [];
  final List<GameParticle> _particles = [];

  // screen shake
  double _shakeIntensity = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration duration) {
    if (!_isPlaying || _isGameOver) return;
    _updateGame();
  }

  void _startGame() {
    setState(() {
      _planets.clear();
      _coins.clear();
      _powerups.clear();
      _particles.clear();
      _score = 0;
      _coinsCollected = 0;
      _cameraY = 0;
      _targetCameraY = 0;
      _isInFlight = false;
      _hasShield = false;
      _isGameOver = false;
      _isPlaying = true;

      // Spawn initial planet at bottom center
      final homePlanet = SpacePlanet(
        x: _screenSize.width / 2,
        y: _screenSize.height - 150,
        radius: 45,
        color: GamesTheme.primary,
        rotationSpeed: 0.025,
      );
      _planets.add(homePlanet);
      _currentPlanet = homePlanet;

      // Position player on home planet
      _playerAngle = -pi / 2;
      _updatePlayerOnPlanet();

      // Spawn next few planets
      _spawnInitialPlanets();

      _ticker.start();
    });
  }

  void _spawnInitialPlanets() {
    double nextY = _planets.last.y - 200;
    for (int i = 0; i < 5; i++) {
      _spawnPlanetAtY(nextY);
      nextY -= 220;
    }
  }

  void _spawnPlanetAtY(double y) {
    final double radius = 25 + _random.nextDouble() * 20;
    // Keep it within horizontal bounds of screen margins
    final double x = 60 + _random.nextDouble() * (_screenSize.width - 120);

    final List<Color> colors = [
      GamesTheme.primary,
      GamesTheme.secondary,
      const Color(0xFFFF4081),
      const Color(0xFF64FFDA),
      const Color(0xFFE040FB),
    ];
    final color = colors[_random.nextInt(colors.length)];
    final rotationSpeed = 0.015 + _random.nextDouble() * 0.015; // Slower, easier rotation
    // 30% chance of space mine on the planet (easier)
    final hasMine = _random.nextDouble() < 0.3;

    final planet = SpacePlanet(
      x: x,
      y: y,
      radius: radius,
      color: color,
      rotationSpeed: rotationSpeed * (_random.nextBool() ? 1 : -1),
      hasMine: hasMine,
    );

    // Place mine at random angle
    planet.mineAngle = _random.nextDouble() * pi * 2;
    _planets.add(planet);

    // Spawn 1-2 coins around this planet trajectory
    if (_random.nextBool()) {
      final coinX = x + (planet.radius + 35) * cos(planet.mineAngle + pi);
      final coinY = y + (planet.radius + 35) * sin(planet.mineAngle + pi);
      _coins.add(SpaceCoin(x: coinX, y: coinY));
    }

    // 10% chance for a shield powerup
    if (_random.nextDouble() < 0.1) {
      final px = x + (planet.radius + 40) * cos(planet.mineAngle + pi/2);
      final py = y + (planet.radius + 40) * sin(planet.mineAngle + pi/2);
      _powerups.add(SpacePowerUp(x: px, y: py, type: 'shield'));
    }
  }

  void _updatePlayerOnPlanet() {
    if (_currentPlanet == null) return;
    final orbitRadius = _currentPlanet!.radius + 15;
    _playerX = _currentPlanet!.x + orbitRadius * cos(_playerAngle);
    _playerY = _currentPlanet!.y + orbitRadius * sin(_playerAngle);
  }

  void _launchPlayer() {
    if (_isInFlight || _currentPlanet == null) return;

    // Calculate tangent launch direction
    final double launchAngle = _playerAngle + (pi / 2) * _playerRotDirection;
    const double speed = 7.5; // Slightly slower for better control

    setState(() {
      _playerVx = speed * cos(launchAngle);
      _playerVy = speed * sin(launchAngle);
      _isInFlight = true;
      _currentPlanet = null;
      _shakeIntensity = 2.0;

      // Spawn launch burst particles
      _spawnExplosion(_playerX, _playerY, GamesTheme.primary, count: 12);
    });

    HapticFeedback.mediumImpact();
  }

  void _spawnExplosion(double x, double y, Color color, {int count = 10}) {
    for (int i = 0; i < count; i++) {
      final double angle = _random.nextDouble() * pi * 2;
      final double speed = 1 + _random.nextDouble() * 3;
      _particles.add(GameParticle(
        x: x,
        y: y,
        vx: speed * cos(angle),
        vy: speed * sin(angle),
        life: 1.0,
        color: color,
      ));
    }
  }

  void _updateGame() {
    setState(() {
      // 1. Smooth Camera Scroll
      _cameraY += (_targetCameraY - _cameraY) * 0.1;

      // Reduce shake
      if (_shakeIntensity > 0) {
        _shakeIntensity *= 0.9;
      }

      // 2. Update Planets (rotate mines)
      for (final planet in _planets) {
        if (planet.hasMine) {
          planet.mineAngle += planet.rotationSpeed * 0.6;
        }
      }

      // 3. Update Particles
      for (int i = _particles.length - 1; i >= 0; i--) {
        final p = _particles[i];
        p.x += p.vx;
        p.y += p.vy;
        p.life -= 0.04;
        if (p.life <= 0) {
          _particles.removeAt(i);
        }
      }

      // 4. Update Player
      if (_isInFlight) {
        _playerX += _playerVx;
        _playerY += _playerVy;

        // Spawn trailing particles
        if (_random.nextDouble() < 0.4) {
          _particles.add(GameParticle(
            x: _playerX,
            y: _playerY,
            vx: -_playerVx * 0.2 + (_random.nextDouble() - 0.5) * 1.5,
            vy: -_playerVy * 0.2 + (_random.nextDouble() - 0.5) * 1.5,
            life: 0.8,
            color: GamesTheme.secondary,
          ));
        }

        // Check bounds (Game Over)
        final relativeY = _playerY - _cameraY;
        if (relativeY > _screenSize.height + 50 ||
            _playerX < -50 ||
            _playerX > _screenSize.width + 50 ||
            relativeY < -200) {
          _triggerGameOver();
          return;
        }

        // Check capture by another planet
        for (final planet in _planets) {
          final dist = sqrt(pow(_playerX - planet.x, 2) + pow(_playerY - planet.y, 2));
          final captureRadius = planet.radius + 45; // Even larger capture radius for better playability

          if (dist < captureRadius) {
            // Captured!
            _currentPlanet = planet;
            _isInFlight = false;

            // Calculate new orbital angle relative to planet center
            _playerAngle = atan2(_playerY - planet.y, _playerX - planet.x);

            // Determine rotation direction based on launch tangent velocity
            final double normalX = cos(_playerAngle);
            final double normalY = sin(_playerAngle);
            final double tangX = -normalY;
            final double tangY = normalX;
            final double dot = _playerVx * tangX + _playerVy * tangY;
            _playerRotDirection = dot >= 0 ? 1 : -1;

            _score += 10;
            _spawnExplosion(_playerX, _playerY, planet.color, count: 6);

            // Trigger Camera Scroll upwards
            final relativePlanetY = planet.y - _cameraY;
            final targetY = _screenSize.height - 250;
            _targetCameraY += (relativePlanetY - targetY);

            // Dynamically spawn new planets above
            _spawnPlanetAtY(_planets.last.y - 220);

            // Clean up off-screen planets
            _planets.removeWhere((p) => p.y - _cameraY > _screenSize.height + 200);

            HapticFeedback.lightImpact();
            break;
          }
        }
      } else {
        // Player is orbiting current planet
        if (_currentPlanet != null) {
          _playerAngle += _currentPlanet!.rotationSpeed * _playerRotDirection;
          _updatePlayerOnPlanet();

          // Check if collided with space mine
          if (_currentPlanet!.hasMine) {
            final mineX = _currentPlanet!.x + (_currentPlanet!.radius + 25) * cos(_currentPlanet!.mineAngle);
            final mineY = _currentPlanet!.y + (_currentPlanet!.radius + 25) * sin(_currentPlanet!.mineAngle);
            final distToMine = sqrt(pow(_playerX - mineX, 2) + pow(_playerY - mineY, 2));

            if (distToMine < 18) {
              if (_hasShield) {
                _hasShield = false;
                _currentPlanet!.mineAngle += pi; // Move mine away
                _spawnExplosion(mineX, mineY, Colors.blue, count: 15);
                HapticFeedback.heavyImpact();
              } else {
                _triggerGameOver();
                return;
              }
            }
          }
        }
      }

      // 5. Coin Collections
      for (final coin in _coins) {
        if (!coin.isCollected) {
          final dist = sqrt(pow(_playerX - coin.x, 2) + pow(_playerY - coin.y, 2));
          if (dist < 25) {
            coin.isCollected = true;
            _coinsCollected++;
            _score += 50;
            _spawnExplosion(coin.x, coin.y, GamesTheme.accent, count: 8);
            HapticFeedback.selectionClick();
          }
        }
      }
      _coins.removeWhere((c) => c.isCollected || c.y - _cameraY > _screenSize.height + 200);

      // 6. PowerUp Collections
      for (final pu in _powerups) {
        if (!pu.isCollected) {
          final dist = sqrt(pow(_playerX - pu.x, 2) + pow(_playerY - pu.y, 2));
          if (dist < 30) {
            pu.isCollected = true;
            if (pu.type == 'shield') {
              _hasShield = true;
            }
            _spawnExplosion(pu.x, pu.y, Colors.blueAccent, count: 12);
            HapticFeedback.mediumImpact();
          }
        }
      }
      _powerups.removeWhere((p) => p.isCollected || p.y - _cameraY > _screenSize.height + 200);
    });
  }

  Future<void> _triggerGameOver() async {
    setState(() {
      _isGameOver = true;
      _isPlaying = false;
      _isInFlight = false;
      _ticker.stop();
      _shakeIntensity = 10.0;
      _spawnExplosion(_playerX, _playerY, Colors.red, count: 25);
    });

    HapticFeedback.vibrate();

    // Save stats
    final prefs = await SharedPreferences.getInstance();
    final currentHigh = prefs.getInt('high_score') ?? 0;
    if (_score > currentHigh) {
      await prefs.setInt('high_score', _score);
    }

    final currentCoins = prefs.getInt('coin_bank') ?? 0;
    await prefs.setInt('coin_bank', currentCoins + _coinsCollected);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _screenSize = MediaQuery.of(context).size;
          _isInitialized = true;
        });
      });
    }

    return Scaffold(
      backgroundColor: GamesTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(true),
        ),
        title: const Text('Orbita Gravity Run', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: _isInitialized
          ? Stack(
              children: [
                // Render Game
                GestureDetector(
                  onTap: _isPlaying ? _launchPlayer : null,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: GamePainter(
                      planets: _planets,
                      coins: _coins,
                      powerups: _powerups,
                      particles: _particles,
                      playerX: _playerX,
                      playerY: _playerY,
                      playerAngle: _playerAngle,
                      playerRotDirection: _playerRotDirection,
                      cameraY: _cameraY,
                      isInFlight: _isInFlight,
                      hasShield: _hasShield,
                      shakeIntensity: _shakeIntensity,
                    ),
                  ),
                ),
                // HUD (Score & Coins)
                if (_isPlaying)
                  Positioned(
                    top: 20,
                    left: 20,
                    right: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('BALL', style: TextStyle(color: GamesTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                            Text('$_score', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _hasShield ? Colors.blueAccent : GamesTheme.accent.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              if (_hasShield) ...[
                                const Icon(Icons.shield_rounded, color: Colors.blueAccent, size: 18),
                                const SizedBox(width: 8),
                              ],
                              const Icon(Icons.stars_rounded, color: GamesTheme.accent, size: 18),
                              const SizedBox(width: 6),
                              Text('$_coinsCollected', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                // Start Overlay
                if (!_isPlaying && !_isGameOver)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: GamesTheme.card,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: GamesTheme.primary.withOpacity(0.3)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: GamesTheme.primary.withOpacity(0.12), shape: BoxShape.circle),
                            child: const Icon(Icons.rocket_launch_rounded, color: GamesTheme.primary, size: 40),
                          ),
                          const SizedBox(height: 18),
                          Text('Orbita Gravity Run', style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          const Text(
                            'Sayyoralar atrofida aylanayotganda ekranga bosing!\n\nYordamchi ko\'k yo\'nalish chizig\'iga qarab nishonni to\'g\'rilang va sakrang.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: GamesTheme.textSecondary, fontSize: 12, height: 1.4),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: GamesTheme.primary,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _startGame,
                              child: const Text('BOSHLASH', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Game Over Overlay
                if (_isGameOver)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: GamesTheme.card,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 54),
                          const SizedBox(height: 16),
                          Text('O\'YIN TUGADI', style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _ResultBox(title: 'YAKUNIY BALL', value: '$_score'),
                              _ResultBox(title: 'TANGALAR', value: '+$_coinsCollected', color: GamesTheme.accent),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: GamesTheme.textSecondary),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('CHIQISH'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: GamesTheme.primary,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  onPressed: _startGame,
                                  child: const Text('QAYTA BOSHLASH', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : const Center(child: CircularProgressIndicator(color: GamesTheme.primary)),
    );
  }
}

class _ResultBox extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _ResultBox({required this.title, required this.value, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: GamesTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.outfit(color: color, fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ─── Painter ─────────────────────────────────────────────────────────────────

class GamePainter extends CustomPainter {
  final List<SpacePlanet> planets;
  final List<SpaceCoin> coins;
  final List<SpacePowerUp> powerups;
  final List<GameParticle> particles;
  final double playerX;
  final double playerY;
  final double playerAngle;
  final double playerRotDirection;
  final double cameraY;
  final bool isInFlight;
  final bool hasShield;
  final double shakeIntensity;

  GamePainter({
    required this.planets,
    required this.coins,
    required this.powerups,
    required this.particles,
    required this.playerX,
    required this.playerY,
    required this.playerAngle,
    required this.playerRotDirection,
    required this.cameraY,
    required this.isInFlight,
    required this.hasShield,
    required this.shakeIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rand = Random();
    
    // 0. Draw Background Stars (Parallax)
    final starPaint = Paint();
    for (int i = 0; i < 60; i++) {
      final double starX = (i * 137.5) % size.width;
      final double starY = (i * 243.1 - cameraY * 0.3) % size.height;
      canvas.drawCircle(Offset(starX, starY), 0.8, starPaint..color = Colors.white.withOpacity(0.3));
    }

    // Apply camera shake
    if (shakeIntensity > 0) {
      final dx = (rand.nextDouble() - 0.5) * shakeIntensity;
      final dy = (rand.nextDouble() - 0.5) * shakeIntensity;
      canvas.translate(dx, dy);
    }

    // Grid pattern
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.015)
      ..strokeWidth = 1.0;
    
    const double spacing = 50.0;
    final gridStartY = -(cameraY % spacing);
    
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = gridStartY; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 1. Draw Planets
    for (final planet in planets) {
      final double py = planet.y - cameraY;
      
      // Draw atmospheric glow ring
      canvas.drawCircle(
        Offset(planet.x, py),
        planet.radius + 15,
        Paint()
          ..shader = RadialGradient(
            colors: [
              planet.color.withOpacity(0.12),
              planet.color.withOpacity(0.0),
            ],
          ).createShader(Rect.fromCircle(center: Offset(planet.x, py), radius: planet.radius + 15)),
      );

      // Draw planet body
      canvas.drawCircle(
        Offset(planet.x, py),
        planet.radius,
        Paint()..color = planet.color.withOpacity(0.85),
      );
      
      // Outer border
      canvas.drawCircle(
        Offset(planet.x, py),
        planet.radius,
        Paint()
          ..color = planet.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      // Capture zone indicator (dotted)
      final capturePaint = Paint()
        ..color = planet.color.withOpacity(0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(Offset(planet.x, py), planet.radius + 45, capturePaint);

      // Draw mine
      if (planet.hasMine) {
        final mineX = planet.x + (planet.radius + 25) * cos(planet.mineAngle);
        final mineY = py + (planet.radius + 25) * sin(planet.mineAngle);
        
        canvas.drawCircle(Offset(mineX, mineY), 10, Paint()..color = Colors.redAccent.withOpacity(0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
        canvas.drawCircle(Offset(mineX, mineY), 5, Paint()..color = Colors.redAccent);
        
        final minePaint = Paint()..color = Colors.redAccent..strokeWidth = 1.5;
        canvas.drawLine(Offset(mineX - 8, mineY), Offset(mineX + 8, mineY), minePaint);
        canvas.drawLine(Offset(mineX, mineY - 8), Offset(mineX, mineY + 8), minePaint);
      }
    }

    // 2. Draw Coins
    for (final coin in coins) {
      if (!coin.isCollected) {
        final cy = coin.y - cameraY;
        
        canvas.drawCircle(Offset(coin.x, cy), 10, Paint()..color = GamesTheme.accent.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
        
        final path = Path();
        const double outerRadius = 7.0;
        const double innerRadius = 3.0;
        final center = Offset(coin.x, cy);
        
        for (int i = 0; i < 5; i++) {
          final double angle = -pi / 2 + (i * 2 * pi / 5);
          path.lineTo(center.dx + outerRadius * cos(angle), center.dy + outerRadius * sin(angle));
          final double innerAngle = angle + pi / 5;
          path.lineTo(center.dx + innerRadius * cos(innerAngle), center.dy + innerRadius * sin(innerAngle));
        }
        path.close();
        
        canvas.drawPath(path, Paint()..color = GamesTheme.accent);
      }
    }

    // 3. Draw PowerUps
    for (final pu in powerups) {
      if (!pu.isCollected) {
        final py = pu.y - cameraY;
        canvas.drawCircle(Offset(pu.x, py), 12, Paint()..color = Colors.blueAccent.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
        canvas.drawCircle(Offset(pu.x, py), 8, Paint()..color = Colors.blueAccent..style = PaintingStyle.stroke..strokeWidth = 2);
        canvas.drawIcon(Icons.shield_rounded, Offset(pu.x - 6, py - 6), Colors.white, size: 12);
      }
    }

    // 4. Draw Trajectory Helper Line (Prediction)
    if (!isInFlight) {
      final double launchAngle = playerAngle + (pi / 2) * playerRotDirection;
      final double plY = playerY - cameraY;
      
      final dottedPaint = Paint()
        ..color = GamesTheme.primary.withOpacity(0.6)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      // Draw a predictive launch line in space
      final double dx = cos(launchAngle);
      final double dy = sin(launchAngle);
      
      const double dashLength = 8.0;
      const double gapLength = 6.0;
      double currentDist = 20.0;
      
      while (currentDist < 500.0) { // Longer prediction line
        final startOffset = Offset(playerX + dx * currentDist, plY + dy * currentDist);
        final endOffset = Offset(playerX + dx * (currentDist + dashLength), plY + dy * (currentDist + dashLength));
        canvas.drawLine(startOffset, endOffset, dottedPaint);
        currentDist += dashLength + gapLength;
      }

      // Draw visual target indicator arrow head
      final arrowX = playerX + dx * 60;
      final arrowY = plY + dy * 60;
      canvas.drawCircle(Offset(arrowX, arrowY), 4, Paint()..color = GamesTheme.primary);
    }

    // 4. Draw Particles
    for (final p in particles) {
      final py = p.y - cameraY;
      canvas.drawCircle(
        Offset(p.x, py),
        2.5 * p.life,
        Paint()..color = p.color.withOpacity(p.life),
      );
    }

    // 5. Draw Player Rocket
    final double ply = playerX;
    final double plY = playerY - cameraY;

    canvas.drawCircle(
      Offset(ply, plY),
      14,
      Paint()..color = GamesTheme.secondary.withOpacity(0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    final path = Path();
    final p1 = Offset(ply + 10 * cos(playerAngle), plY + 10 * sin(playerAngle));
    final p2 = Offset(ply + 7 * cos(playerAngle + 2.3), plY + 7 * sin(playerAngle + 2.3));
    final p3 = Offset(ply + 7 * cos(playerAngle - 2.3), plY + 7 * sin(playerAngle - 2.3));
    
    path.moveTo(p1.dx, p1.dy);
    path.lineTo(p2.dx, p2.dy);
    path.lineTo(p3.dx, p3.dy);
    path.close();

    canvas.drawPath(path, Paint()..color = GamesTheme.secondary);

    // Shield effect
    if (hasShield) {
      canvas.drawCircle(
        Offset(ply, plY),
        20,
        Paint()
          ..color = Colors.blueAccent.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

extension on Canvas {
  void drawIcon(IconData icon, Offset offset, Color color, {double size = 24}) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
      ),
    );
    textPainter.layout();
    textPainter.paint(this, offset);
  }
}
