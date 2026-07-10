import 'package:flutter/material.dart';
import '../theme.dart';

class PremiumCard extends StatelessWidget {
  final Widget child;
  final Color? glowColor;
  final EdgeInsets? padding;

  const PremiumCard({super.key, required this.child, this.glowColor, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GamesTheme.card.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: (glowColor ?? Colors.black).withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: -5,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.02),
            offset: const Offset(-2, -2),
            blurRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: child,
      ),
    );
  }
}
