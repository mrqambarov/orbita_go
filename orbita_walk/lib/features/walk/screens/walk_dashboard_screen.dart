import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/walk_provider.dart';
import '../providers/quest_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/models/quest_model.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/services/api_service.dart';

class WalkDashboardScreen extends ConsumerWidget {
  const WalkDashboardScreen({super.key});

  void _showCouponShopBottomSheet(BuildContext context, WidgetRef ref, double balance) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13131F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder(
              future: ref.read(apiServiceProvider).client.get('/api/games/shop'),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: OrbitaColors.primary));
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Yuklashda xatolik yuz berdi', style: TextStyle(color: Colors.white)));
                }

                final res = snapshot.data;
                final items = (res?.data['success'] == true)
                    ? (res?.data['items'] as List).where((item) => item['category'] == 'PROMO').toList()
                    : [];

                if (items.isEmpty) {
                  return const Center(child: Text('Hozircha kuponlar do\'koni bo\'sh', style: TextStyle(color: Colors.white70)));
                }

                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3A3A4E),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Kuponlar Do\'koni',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: OrbitaColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Balans: ${balance.toStringAsFixed(0)} UZS',
                              style: const TextStyle(color: OrbitaColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Hamyon balansini ishlatib hamkorlarimizdan eksklyuziv kuponlar sotib oling!',
                        style: TextStyle(color: OrbitaColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final name = item['name'] as String;
                            final desc = item['description'] as String;
                            final price = (item['price'] as num).toDouble();
                            final itemId = item['id'] as String;

                            final isAffordable = balance >= price;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: OrbitaColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF2A2A3E)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          desc,
                                          style: const TextStyle(color: OrbitaColors.textSecondary, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isAffordable ? OrbitaColors.primary : Colors.grey[800],
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    ),
                                    onPressed: !isAffordable ? null : () async {
                                      try {
                                        final buyRes = await ref.read(apiServiceProvider).client.post('/api/games/shop/buy', data: {'itemId': itemId});
                                        if (buyRes.data['success'] == true) {
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                            ref.read(authProvider.notifier).refreshUser();
                                            showDialog(
                                              context: context,
                                              builder: (c) => AlertDialog(
                                                backgroundColor: const Color(0xFF1C1C2E),
                                                title: const Text('Tabriklaymiz! 🎉', style: TextStyle(color: Colors.white)),
                                                content: Text('${buyRes.data['message']}'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(c),
                                                    child: const Text('OK'),
                                                  )
                                                ],
                                              ),
                                            );
                                          }
                                        }
                                      } catch (err) {
                                        final msg = (err as dynamic).response?.data['message'] ?? 'Xatolik yuz berdi';
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(msg), backgroundColor: OrbitaColors.error),
                                        );
                                      }
                                    },
                                    child: Text('${price.toStringAsFixed(0)} UZS'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showGeoQuestsBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13131F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder(
              future: ref.read(apiServiceProvider).client.get('/api/auth/walk/geo-quests'),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: OrbitaColors.primary));
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Yuklashda xatolik yuz berdi', style: TextStyle(color: Colors.white)));
                }

                final res = snapshot.data;
                final quests = (res?.data['success'] == true) ? res?.data['quests'] as List : [];

                if (quests.isEmpty) {
                  return const Center(child: Text('Hozircha geo-kvestlar yo\'q', style: TextStyle(color: Colors.white70)));
                }

                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3A3A4E),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Landmark Geo-Kvestlar',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Belgilangan joylarda kerakli qadamlarni bosib, maxsus mukofot va chegirma kuponlarini oching!',
                        style: TextStyle(color: OrbitaColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: quests.length,
                          itemBuilder: (context, index) {
                            final q = quests[index];
                            final title = q['title'] as String;
                            final steps = q['goalSteps'] as int;
                            final coins = q['rewardCoins'] as int;
                            final code = q['rewardCouponCode'] as String? ?? 'MAHSUS';
                            final questId = q['id'] as String;

                            final rewardPrice = coins * 10;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: OrbitaColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF2A2A3E)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.purple.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          'Kupon: $code',
                                          style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Maqsad: Ushbu hududda $steps ta qadam bosish.',
                                    style: const TextStyle(color: OrbitaColors.textSecondary, fontSize: 13),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Mukofot: +${rewardPrice.toStringAsFixed(0)} UZS',
                                        style: const TextStyle(color: OrbitaColors.success, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: OrbitaColors.success,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        ),
                                        onPressed: () async {
                                          try {
                                            final claimRes = await ref.read(apiServiceProvider).client.post('/api/auth/walk/geo-quests/claim', data: {'questId': questId});
                                            if (claimRes.data['success'] == true) {
                                              if (context.mounted) {
                                                Navigator.pop(context);
                                                ref.read(authProvider.notifier).refreshUser();
                                                showDialog(
                                                  context: context,
                                                  builder: (c) => AlertDialog(
                                                    backgroundColor: const Color(0xFF1C1C2E),
                                                    title: const Text('Muvaffaqiyatli topshirildi! 🎉', style: TextStyle(color: Colors.white)),
                                                    content: Text('${claimRes.data['message']}\nKuponingiz: ${claimRes.data['couponCode']}'),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(c),
                                                        child: const Text('OK'),
                                                      )
                                                    ],
                                                  ),
                                                );
                                              }
                                            }
                                          } catch (err) {
                                            final msg = (err as dynamic).response?.data['message'] ?? 'Xatolik yuz berdi';
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(msg), backgroundColor: OrbitaColors.error),
                                            );
                                          }
                                        },
                                        child: const Text('Bajarildi deb belgilash', style: TextStyle(fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showQuestCompletedDialog(BuildContext context, QuestModel quest) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Icon(
              Icons.emoji_events_rounded,
              color: Colors.amber,
              size: 54,
            ),
            SizedBox(height: 12),
            Text(
              'TABRIKLAYMIZ!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Siz "${quest.title}" topshirig\'ini muvaffaqiyatli bajardingiz!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: OrbitaColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: OrbitaColors.success.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_circle_outline_rounded, color: OrbitaColors.success, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '+${quest.rewardCoins.toInt()} UZS Hamyonga!',
                    style: const TextStyle(
                      color: OrbitaColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: OrbitaColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: OrbitaColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_activity_rounded, color: OrbitaColors.primaryLight, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      quest.rewardCoupon,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/coupons');
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Kuponni ko\'rish'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Yopish',
              style: TextStyle(color: OrbitaColors.textHint, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walkState = ref.watch(walkProvider);
    final authState = ref.watch(authProvider);
    final questState = ref.watch(questProvider);
    final user = authState.user;

    final progress = math.min(1.0, walkState.dailySteps / walkState.stepGoal);
    final distanceKm = double.parse((walkState.dailySteps * 0.00076).toStringAsFixed(2));
    final calories = (walkState.dailySteps * 0.04).round();
    final activeMinutes = walkState.walkHistory.fold<int>(0, (sum, item) => sum + (item.durationSecs ~/ 60));

    // Listen to quest completion event to display modal congrats dialog dynamically!
    ref.listen<QuestState>(questProvider, (previous, next) {
      if (previous != null) {
        for (var quest in next.quests) {
          final prevQuest = previous.quests.firstWhere((q) => q.id == quest.id, orElse: () => quest);
          if (quest.isCompleted && !prevQuest.isCompleted) {
            _showQuestCompletedDialog(context, quest);
          }
        }
      }
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: OrbitaColors.backgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                // Header Profile Bar
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.push('/profile'),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          gradient: OrbitaColors.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: OrbitaColors.surface,
                          child: const Icon(Icons.person_rounded, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? 'Foydalanuvchi',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            user?.orbitaId ?? '',
                            style: const TextStyle(
                              color: OrbitaColors.textHint,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Link to Unlocked Coupons
                    IconButton(
                      icon: const Icon(Icons.local_activity_rounded, color: OrbitaColors.primaryLight, size: 28),
                      onPressed: () => context.push('/coupons'),
                      tooltip: 'Mening kuponlarim',
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Step Progress Ring Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: OrbitaColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF2A2A3E)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Kunlik maqsad',
                        style: TextStyle(
                          color: OrbitaColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 180,
                            height: 180,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 16,
                              backgroundColor: const Color(0xFF1C1C2E),
                              color: OrbitaColors.primary,
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                NumberFormat.decimalPattern().format(walkState.dailySteps),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Kunlik maqsad: ${NumberFormat.decimalPattern().format(walkState.stepGoal)}',
                                style: const TextStyle(
                                  color: OrbitaColors.textHint,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      // Stats Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            context,
                            Icons.local_fire_department_rounded,
                            '$calories kkal',
                            'Kalloriya',
                          ),
                          Container(width: 1, height: 32, color: const Color(0xFF2A2A3E)),
                          _buildStatItem(
                            context,
                            Icons.directions_walk_rounded,
                            '$distanceKm km',
                            'Masofa',
                          ),
                          Container(width: 1, height: 32, color: const Color(0xFF2A2A3E)),
                          _buildStatItem(
                            context,
                            Icons.timer_rounded,
                            '$activeMinutes daqiqa',
                            'Vaqt',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Conversion / Wallet Drawer Trigger Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: OrbitaColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF2A2A3E)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: OrbitaColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.account_balance_wallet_rounded, color: OrbitaColors.primary),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Hamyonga o\'tkazish',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Qadamlar: ${walkState.unredeemedSteps} = ${walkState.unredeemedSteps.toDouble().toStringAsFixed(0)} UZS',
                                  style: const TextStyle(
                                    color: OrbitaColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: walkState.unredeemedSteps <= 0 || walkState.isRedeeming
                            ? null
                            : () async {
                                final success = await ref.read(walkProvider.notifier).redeemSteps(ref);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success ? 'Qadamlar muvaffaqiyatli pulga aylantirildi!' : 'Xatolik yuz berdi. Tarmoqni tekshiring.',
                                      ),
                                      backgroundColor: success ? OrbitaColors.success : OrbitaColors.error,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              },
                        child: walkState.isRedeeming
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Hamyonga o\'tkazish'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showGeoQuestsBottomSheet(context, ref),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: OrbitaColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF2A2A3E)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.map_rounded, color: Colors.purpleAccent, size: 20),
                              ),
                              const SizedBox(height: 12),
                              const Text('Geo-Kvestlar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 2),
                              const Text('Hudud topshiriqlari', style: TextStyle(color: OrbitaColors.textSecondary, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showCouponShopBottomSheet(context, ref, user?.walletBalance ?? 0.0),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: OrbitaColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF2A2A3E)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.shopping_bag_rounded, color: Colors.greenAccent, size: 20),
                              ),
                              const SizedBox(height: 12),
                              const Text('Kupon do\'koni', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 2),
                              const Text('Kupon xarid qilish', style: TextStyle(color: OrbitaColors.textSecondary, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Leaderboard Banner Card
                GestureDetector(
                  onTap: () => context.push('/leaderboard'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2A1B54), Color(0xFF140A2E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: OrbitaColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 24),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Haftalik Musobaqa',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Kim birinchi? Peshqadamlarni ko\'ring',
                                style: TextStyle(
                                  color: OrbitaColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Gamified Partner Quests Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Hamkorlik topshiriqlari',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/coupons'),
                      child: const Text('Kuponlarim', style: TextStyle(color: OrbitaColors.primaryLight, fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...questState.quests.map((quest) => _buildQuestCard(context, ref, walkState, quest, questState.activeQuestId)),
                const SizedBox(height: 28),

                // Walk History List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Oxirgi mashg\'ulotlar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (walkState.walkHistory.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Column(
                      children: [
                        Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.white.withOpacity(0.2)),
                        const SizedBox(height: 12),
                        const Text(
                          'Hali hech qanday mashg\'ulot bajarilmagan',
                          style: TextStyle(color: OrbitaColors.textHint, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                else
                  ...walkState.walkHistory.map((session) => _buildHistoryItem(context, session)),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: walkState.isActiveWalk
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/active-walk'),
              icon: const Icon(Icons.directions_run_rounded, color: Colors.white),
              label: const Text('Mashg\'ulot faol', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: OrbitaColors.primary,
            )
          : FloatingActionButton.extended(
              onPressed: () {
                ref.read(walkProvider.notifier).startWalk();
                context.push('/active-walk');
              },
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              label: const Text('Yurishni boshlash', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: OrbitaColors.primary,
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildStatItem(BuildContext context, IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: OrbitaColors.primary, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: OrbitaColors.textHint,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestCard(BuildContext context, WidgetRef ref, WalkState walkState, QuestModel quest, String? activeQuestId) {
    final isThisQuestActive = activeQuestId == quest.id;
    final progress = quest.targetType == 'STEPS'
        ? math.min(1.0, walkState.dailySteps / quest.targetSteps)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OrbitaColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: quest.isCompleted
              ? OrbitaColors.success.withOpacity(0.3)
              : (isThisQuestActive ? OrbitaColors.primary.withOpacity(0.6) : const Color(0xFF2A2A3E)),
          width: isThisQuestActive ? 2.0 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quest Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: quest.isCompleted
                  ? OrbitaColors.success.withOpacity(0.12)
                  : (isThisQuestActive ? OrbitaColors.primary.withOpacity(0.15) : OrbitaColors.primary.withOpacity(0.08)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              quest.id.contains('evos')
                  ? Icons.fastfood_rounded
                  : (quest.id.contains('macro') ? Icons.shopping_bag_rounded : Icons.emoji_events_rounded),
              color: quest.isCompleted
                  ? OrbitaColors.success
                  : (isThisQuestActive ? OrbitaColors.primary : OrbitaColors.primaryLight),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        quest.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (quest.isCompleted) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: OrbitaColors.success.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, color: OrbitaColors.success, size: 10),
                            SizedBox(width: 4),
                            Text(
                              'Bajarildi',
                              style: TextStyle(color: OrbitaColors.success, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isThisQuestActive) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: OrbitaColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.directions_run_rounded, color: OrbitaColors.primaryLight, size: 10),
                            SizedBox(width: 4),
                            Text(
                              'Faol',
                              style: TextStyle(color: OrbitaColors.primaryLight, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  quest.description,
                  style: const TextStyle(
                    color: OrbitaColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),

                // Reward & Status Label
                Row(
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, color: OrbitaColors.success, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '+${quest.rewardCoins.toInt()} UZS',
                      style: const TextStyle(color: OrbitaColors.success, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(width: 4, height: 4, decoration: const BoxDecoration(color: OrbitaColors.textHint, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    const Icon(Icons.local_activity_rounded, color: OrbitaColors.primaryLight, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        quest.rewardCoupon,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: OrbitaColors.primaryLight, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Active Check logic (Only track metrics if this quest is selected!)
                if (quest.isCompleted) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF152A22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.vpn_key_rounded, color: OrbitaColors.success, size: 12),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Kupon ochildi: ${quest.rewardPromoCode}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isThisQuestActive) ...[
                  // Dynamic tracking metrics
                  if (quest.targetType == 'LOCATION') ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E32),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: OrbitaColors.primaryLight, size: 12),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              quest.distanceToTarget != null
                                  ? 'Nishongacha masofa: ${(quest.distanceToTarget! / 1000).toStringAsFixed(2)} km'
                                  : 'Faol sayohat vaqtida GPS orqali kuzatiladi',
                              style: const TextStyle(
                                color: OrbitaColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: const Color(0xFF1C1C2E),
                            color: OrbitaColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Bajarilishi: ${(progress * 100).toInt()}%',
                              style: const TextStyle(color: OrbitaColors.textHint, fontSize: 10),
                            ),
                            Text(
                              '${NumberFormat.decimalPattern().format(walkState.dailySteps)} / ${NumberFormat.decimalPattern().format(quest.targetSteps)} qadam',
                              style: const TextStyle(color: OrbitaColors.textHint, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Deactivate Quest Button
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: OrbitaColors.error,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                    ),
                    onPressed: () {
                      ref.read(questProvider.notifier).deactivateQuest();
                    },
                    icon: const Icon(Icons.pause_circle_filled_rounded, size: 16),
                    label: const Text('Kuzatishni to\'xtatish', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ] else ...[
                  // Not active: show activation action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeQuestId != null ? const Color(0xFF1F1F35) : OrbitaColors.primary,
                          foregroundColor: activeQuestId != null ? OrbitaColors.textHint : Colors.white,
                          minimumSize: const Size(120, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: activeQuestId != null ? 0 : 4,
                        ),
                        onPressed: activeQuestId != null
                            ? null // Can only activate one quest at a time!
                            : () {
                                ref.read(questProvider.notifier).activateQuest(quest.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('"${quest.title}" topshirig\'i faollashtirildi!'),
                                    backgroundColor: OrbitaColors.primary,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                        child: Text(
                          activeQuestId != null ? 'Boshqa topshiriq faol' : 'Faollashtirish',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, WalkSession session) {
    final dateFormat = DateFormat('dd MMMM, HH:mm');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: OrbitaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F1F35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: OrbitaColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.directions_walk_rounded, color: OrbitaColors.primaryLight, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${NumberFormat.decimalPattern().format(session.steps)} qadam',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateFormat.format(session.date),
                  style: const TextStyle(
                    color: OrbitaColors.textHint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${session.distanceKm} km',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${session.calories} kkal',
                style: const TextStyle(
                  color: OrbitaColors.textHint,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
