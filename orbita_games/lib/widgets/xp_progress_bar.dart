import 'package:flutter/material.dart';
import '../theme.dart';

class XpProgressBar extends StatelessWidget {
  final int level;
  final int currentXp;
  final int nextLevelXp;

  const XpProgressBar({super.key, required this.level, required this.currentXp, required this.nextLevelXp});

  @override
  Widget build(BuildContext context) {
    final double progress = (currentXp / nextLevelXp).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('LEVEL $level', style: const TextStyle(fontWeight: FontWeight.w900, color: GamesTheme.primary, fontSize: 12)),
            Text('$currentXp / $nextLevelXp XP', style: const TextStyle(color: GamesTheme.textSecondary, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Container(height: 8, color: Colors.white.withOpacity(0.05)),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                height: 8,
                width: MediaQuery.of(context).size.width * progress,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [GamesTheme.primary, GamesTheme.accent]),
                  boxShadow: [BoxShadow(color: GamesTheme.primary.withOpacity(0.5), blurRadius: 10)],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
