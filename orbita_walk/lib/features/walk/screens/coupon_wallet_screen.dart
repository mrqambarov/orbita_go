import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/quest_provider.dart';
import '../../../shared/theme/app_theme.dart';

class CouponWalletScreen extends ConsumerWidget {
  const CouponWalletScreen({super.key});

  Widget _buildBarcode(String code) {
    // Generate a stylized, premium-looking barcode using vertical lines
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                32,
                (index) => Container(
                  width: (index % 3 == 0) ? 3.0 : ((index % 5 == 0) ? 1.0 : 2.0),
                  color: (index % 7 == 0) ? Colors.transparent : Colors.black87,
                  margin: const EdgeInsets.symmetric(horizontal: 1.2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            code,
            style: const TextStyle(
              color: Colors.black87,
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questState = ref.watch(questProvider);
    final completedQuests = questState.quests.where((q) => q.isCompleted).toList();

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
          'Mening Kuponlarim',
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
        child: completedQuests.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: OrbitaColors.primary.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_activity_rounded,
                          size: 64,
                          color: OrbitaColors.primaryLight,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Kuponlar mavjud emas',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Hamkorlarimizdan chegirma kuponlarini olish uchun xaritadagi topshiriqlarni bajaring va ko\'proq sayr qiling!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: OrbitaColors.textHint,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.directions_run_rounded, size: 20),
                        label: const Text('Topshiriqlarni ko\'rish'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: completedQuests.length,
                itemBuilder: (context, index) {
                  final quest = completedQuests[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1E1E32),
                          const Color(0xFF252542).withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: OrbitaColors.primary.withOpacity(0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        children: [
                          // Ticket Body
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                // Icon/Bonus Badge
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    gradient: OrbitaColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    quest.id.contains('evos')
                                        ? Icons.fastfood_rounded
                                        : (quest.id.contains('macro')
                                            ? Icons.shopping_bag_rounded
                                            : Icons.emoji_events_rounded),
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Coupon Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        quest.targetName.toUpperCase(),
                                        style: const TextStyle(
                                          color: OrbitaColors.primaryLight,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        quest.rewardCoupon,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Bonus: +${quest.rewardCoins.toInt()} UZS hamyonga o\'tkazildi',
                                        style: const TextStyle(
                                          color: OrbitaColors.success,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Dotted Divider Line
                          Row(
                            children: List.generate(
                              30,
                              (index) => Expanded(
                                child: Container(
                                  height: 1,
                                  color: index.isEven ? Colors.transparent : Colors.white30,
                                ),
                              ),
                            ),
                          ),

                          // Barcode / Promo Code Section
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                _buildBarcode(quest.rewardPromoCode),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Kassada ushbu shtrix-kodni ko\'rsating',
                                      style: TextStyle(
                                        color: OrbitaColors.textHint,
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: quest.rewardPromoCode));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Text('Promo-kod nusxalandi!'),
                                            backgroundColor: OrbitaColors.primary,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            duration: const Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.copy_rounded, size: 14, color: OrbitaColors.primaryLight),
                                      label: const Text(
                                        'Nusxalash',
                                        style: TextStyle(
                                          color: OrbitaColors.primaryLight,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
