import 'dart:math';
import 'package:flutter/material.dart';

class GalaxyBackground extends StatefulWidget {
  final Widget child;
  const GalaxyBackground({super.key, required this.child});

  @override
  State<GalaxyBackground> createState() => _GalaxyBackgroundState();
}

class _GalaxyBackgroundState extends State<GalaxyBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Star> _stars = List.generate(80, (index) => _Star());

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _GalaxyPainter(_stars, _controller.value),
          child: widget.child,
        );
      },
    );
  }
}

class _Star {
  final double x = Random().nextDouble();
  final double y = Random().nextDouble();
  final double size = Random().nextDouble() * 2 + 0.5;
  final double speed = Random().nextDouble() * 0.05 + 0.01;
}

class _GalaxyPainter extends CustomPainter {
  final List<_Star> stars;
  final double animation;
  _GalaxyPainter(this.stars, this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (var star in stars) {
      final y = (star.y + animation * star.speed) % 1.0;
      paint.color = Colors.white.withOpacity(0.3 + 0.7 * sin(animation * 10 + star.x * 100).abs());
      canvas.drawCircle(Offset(star.x * size.width, y * size.height), star.size, paint);
    }
    
    // Gradient
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    const gradient = RadialGradient(
      center: Alignment(0.5, -0.5),
      radius: 1.5,
      colors: [Color(0xFF1B1B4A), Color(0xFF0F0E2A)],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect)..blendMode = BlendMode.dstOver);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
