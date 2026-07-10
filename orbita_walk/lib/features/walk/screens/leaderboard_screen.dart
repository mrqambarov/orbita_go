import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/theme/app_theme.dart';

final leaderboardProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final res = await api.getWalkLeaderboard();
  if (res.data['success'] == true) {
    return res.data['leaderboard'] as List<dynamic>;
  }
  throw Exception('Peshqadamlar yuklanmadi');
});

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider);
    final currentUser = ref.watch(authProvider).user;

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
          'Peshqadamlar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => ref.invalidate(leaderboardProvider),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: OrbitaColors.backgroundGradient,
        ),
        child: leaderboardAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: OrbitaColors.primary),
          ),
          error: (err, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: OrbitaColors.error, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Yuklashda xatolik yuz berdi',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(leaderboardProvider),
                  child: const Text('Qayta urunish', style: TextStyle(color: OrbitaColors.primaryLight)),
                ),
              ],
            ),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const Center(
                child: Text('Reyting bo\'sh', style: TextStyle(color: OrbitaColors.textHint)),
              );
            }

            // Top 3 for the podium
            final top3 = list.take(3).toList();
            // Rest of the users (4-10)
            final rest = list.skip(3).toList();

            return Column(
              children: [
                const SizedBox(height: 16),
                // 1. Podium Section (Shohsupa)
                if (top3.isNotEmpty) _buildPodium(context, top3),
                const SizedBox(height: 24),
                // 2. Scrollable List for ranks 4-10
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: OrbitaColors.surface,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      itemCount: rest.length,
                      itemBuilder: (context, index) {
                        final user = rest[index];
                        final rank = index + 4;
                        final isMe = user['orbitaId'] == currentUser?.orbitaId;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isMe ? OrbitaColors.primary.withOpacity(0.08) : const Color(0xFF1E1E32),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isMe ? OrbitaColors.primary.withOpacity(0.4) : const Color(0xFF2A2A3E),
                              width: isMe ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Rank Number
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2A48),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$rank',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Avatar
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: OrbitaColors.primary.withOpacity(0.2),
                                child: Text(
                                  (user['fullName'] ?? 'F')[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 14),
                              // User details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user['fullName'] ?? 'Foydalanuvchi',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      user['orbitaId'] ?? '',
                                      style: const TextStyle(
                                        color: OrbitaColors.textHint,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Steps count
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${user['steps']} UZS',
                                    style: const TextStyle(
                                      color: OrbitaColors.success,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'jami mukofot',
                                    style: TextStyle(
                                      color: OrbitaColors.textHint,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPodium(BuildContext context, List<dynamic> top3) {
    // 1st, 2nd, 3rd places
    final first = top3[0];
    final second = top3.length > 1 ? top3[1] : null;
    final third = top3.length > 2 ? top3[2] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place (Left)
          if (second != null)
            _buildPodiumUser(
              context: context,
              user: second,
              rank: 2,
              avatarRadius: 28,
              podiumHeight: 70,
              medalColor: const Color(0xFFC0C0C0), // Silver
            ),

          // 1st Place (Center)
          _buildPodiumUser(
            context: context,
            user: first,
            rank: 1,
            avatarRadius: 36,
            podiumHeight: 95,
            medalColor: const Color(0xFFFFD700), // Gold
            hasCrown: true,
          ),

          // 3rd Place (Right)
          if (third != null)
            _buildPodiumUser(
              context: context,
              user: third,
              rank: 3,
              avatarRadius: 26,
              podiumHeight: 60,
              medalColor: const Color(0xFFCD7F32), // Bronze
            ),
        ],
      ),
    );
  }

  Widget _buildPodiumUser({
    required BuildContext context,
    required dynamic user,
    required int rank,
    required double avatarRadius,
    required double podiumHeight,
    required Color medalColor,
    bool hasCrown = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // User Avatar Card
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    medalColor.withOpacity(0.8),
                    medalColor.withOpacity(0.2),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: medalColor.withOpacity(0.15),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: avatarRadius,
                backgroundColor: const Color(0xFF1E1E32),
                child: Text(
                  (user['fullName'] ?? 'F')[0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: avatarRadius * 0.6,
                  ),
                ),
              ),
            ),
            // Crown/Podium Rank Badge
            if (hasCrown)
              Positioned(
                top: -12,
                child: Image.network(
                  'https://img.icons8.com/emoji/96/crown-emoji.png',
                  width: 24,
                  height: 24,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFFFFD700),
                    size: 20,
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: medalColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0A0A14), width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Name & Steps
        SizedBox(
          width: 90,
          child: Column(
            children: [
              Text(
                user['fullName'] ?? 'Foydalanuvchi',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${user['steps']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: medalColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'UZS',
                style: TextStyle(
                  color: OrbitaColors.textHint,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Visual Podium Pillar
        Container(
          width: 76,
          height: podiumHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1E1E32),
                const Color(0xFF131326),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: const Color(0xFF2A2A3E)),
          ),
          alignment: Alignment.center,
          child: Text(
            rank == 1 ? '1st' : (rank == 2 ? '2nd' : '3rd'),
            style: TextStyle(
              color: medalColor.withOpacity(0.5),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
