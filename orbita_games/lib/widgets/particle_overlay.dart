import 'dart:math';
import 'package:flutter/material.dart';

class ParticleOverlay extends StatefulWidget {
  final Widget child;
  final GlobalKey<ParticleOverlayState> overlayKey;

  const ParticleOverlay({required this.overlayKey, required this.child, super.key});

  @override
  State<ParticleOverlay> createState() => ParticleOverlayState();
}

class ParticleOverlayState extends State<ParticleOverlay> with TickerProviderStateMixin {
  final List<_Particle> _particles = [];
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(() {
        setState(() {
          _updateParticles();
        });
      })
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void showBurst(Offset position, {Color? color, int count = 20}) {
    final random = Random();
    for (int i = 0; i < count; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final speed = 2.0 + random.nextDouble() * 4.0;
      _particles.add(_Particle(
        position: position,
        velocity: Offset(cos(angle) * speed, sin(angle) * speed),
        color: color ?? Colors.yellowAccent,
        life: 1.0,
        size: 2.0 + random.nextDouble() * 4.0,
      ));
    }
  }

  void _updateParticles() {
    for (int i = _particles.length - 1; i >= 0; i--) {
      _particles[i].position += _particles[i].velocity;
      _particles[i].velocity = Offset(_particles[i].velocity.dx, _particles[i].velocity.dy + 0.15); // Gravity
      _particles[i].life -= 0.02;
      if (_particles[i].life <= 0) {
        _particles.removeAt(i);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        IgnorePointer(
          child: CustomPaint(
            painter: _ParticlePainter(_particles),
            size: Size.infinite,
          ),
        ),
      ],
    );
  }
}

class _Particle {
  Offset position;
  Offset velocity;
  Color color;
  double life;
  double size;

  _Particle({required this.position, required this.velocity, required this.color, required this.life, required this.size});
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;

  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      paint.color = p.color.withOpacity(p.life);
      canvas.drawCircle(p.position, p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
