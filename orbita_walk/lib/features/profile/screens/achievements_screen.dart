import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../walk/providers/achievement_provider.dart';
import '../../../shared/theme/app_theme.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(achievementProvider);
    final unlockedCount = achievements.where((a) => a.isUnlocked).length;
    final totalCount = achievements.length;
    final progress = totalCount > 0 ? unlockedCount / totalCount : 0.0;

    // Listen to achievements changes to show congrats dialog
    ref.listen<List<AchievementModel>>(achievementProvider, (previous, next) {
      if (previous != null) {
        for (var ach in next) {
          final prevAch = previous.firstWhere((a) => a.id == ach.id, orElse: () => ach);
          if (ach.isUnlocked && !prevAch.isUnlocked) {
            _showAchievementUnlockedDialog(context, ach);
          }
        }
      }
    });

    return Scaffold(
      backgroundColor: OrbitaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Mening Yutuqlarim',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: OrbitaColors.backgroundGradient,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Progress Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: OrbitaColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF2A2A3E)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Faollik darajasi',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$unlockedCount ta yutuq ochildi',
                              style: const TextStyle(
                                color: OrbitaColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$unlockedCount / $totalCount',
                          style: const TextStyle(
                            color: OrbitaColors.primaryLight,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: const Color(0xFF1C1C2E),
                        color: OrbitaColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 2. Section Title
              const Text(
                'Medallar va Nishonlar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // 3. Grid List of Badges
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: achievements.length,
                itemBuilder: (context, index) {
                  final ach = achievements[index];
                  return _buildAchievementCard(context, ach);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementCard(BuildContext context, AchievementModel ach) {
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OrbitaColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ach.isUnlocked ? OrbitaColors.primary.withOpacity(0.3) : const Color(0xFF2A2A3E),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Badge Icon Circle
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ach.isUnlocked
                      ? OrbitaColors.primary.withOpacity(0.12)
                      : Colors.white.withOpacity(0.04),
                  border: Border.all(
                    color: ach.isUnlocked ? OrbitaColors.primary : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _getIconData(ach.iconName),
                  color: ach.isUnlocked ? OrbitaColors.primaryLight : Colors.white24,
                  size: 32,
                ),
              ),
              if (!ach.isUnlocked)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E1E32),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.white60,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Badge Details
          Text(
            ach.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ach.isUnlocked ? Colors.white : Colors.white30,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              ach.description,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ach.isUnlocked ? OrbitaColors.textSecondary : Colors.white24,
                fontSize: 10,
                height: 1.3,
              ),
            ),
          ),
          if (ach.isUnlocked && ach.unlockDate != null) ...[
            const SizedBox(height: 4),
            Text(
              'Bajarildi: ${dateFormat.format(ach.unlockDate!)}',
              style: const TextStyle(
                color: OrbitaColors.success,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'morning':
        return Icons.wb_sunny_rounded;
      case 'marathon':
        return Icons.sports_score_rounded;
      case 'evos':
        return Icons.fastfood_rounded;
      case 'macro':
        return Icons.shopping_bag_rounded;
      default:
        return Icons.emoji_events_rounded;
    }
  }

  void _showAchievementUnlockedDialog(BuildContext context, AchievementModel ach) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              color: Colors.amber,
              size: 54,
            ),
            SizedBox(height: 12),
            Text(
              'YANGI NIShON!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Siz "${ach.title}" medalini muvaffaqiyatli qo\'lga kiritdingiz!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: OrbitaColors.primary.withOpacity(0.12),
                border: Border.all(color: OrbitaColors.primary, width: 2),
              ),
              child: Icon(
                _getIconData(ach.iconName),
                color: OrbitaColors.primaryLight,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              ach.description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: OrbitaColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tushunarli'),
          ),
        ],
      ),
    );
  }
}
