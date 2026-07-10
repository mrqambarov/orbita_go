import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/localization/translations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/orbita_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, String currentName, String currentUsername) {
    final nameController = TextEditingController(text: currentName);
    final usernameController = TextEditingController(text: currentUsername);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF13131F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            context.tr('edit_profile'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: context.tr('fullname'),
                    labelStyle: const TextStyle(color: OrbitaColors.textHint),
                  ),
                  validator: (val) => (val == null || val.trim().length < 3) ? 'Kamida 3 ta harf kiriting' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: context.tr('username'),
                    labelStyle: const TextStyle(color: OrbitaColors.textHint),
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Username kiriting' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('cancel'), style: const TextStyle(color: OrbitaColors.textHint)),
            ),
            TextButton(
              onPressed: () async {
                if (formKey.currentState?.validate() == true) {
                  final name = nameController.text.trim();
                  final user = usernameController.text.trim();
                  
                  Navigator.pop(context);
                  
                  final success = await ref.read(authProvider.notifier).updateProfile(name, user);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success ? 'Profil yangilandi' : 'Xatolik yuz berdi',
                        ),
                        backgroundColor: success ? OrbitaColors.success : OrbitaColors.error,
                      ),
                    );
                  }
                }
              },
              child: Text(context.tr('save'), style: const TextStyle(color: OrbitaColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showPaymentMethodsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13131F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('payment_method'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.money_rounded, color: OrbitaColors.success),
                  title: const Text('Naqd pul', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.check_circle_rounded, color: OrbitaColors.primary),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('To\'lov usuli: Naqd pul tanlandi')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.credit_card_rounded, color: Colors.blue),
                  title: const Text('Payme / Click (Tez kunda)', style: TextStyle(color: OrbitaColors.textHint)),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ushbu to\'lov tizimi tez kunda ishga tushadi')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLanguageBottomSheet(BuildContext context, WidgetRef ref, String currentLanguage) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13131F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final languages = [
          {'code': 'uz', 'name': 'O\'zbekcha', 'flag': '🇺🇿'},
          {'code': 'ru', 'name': 'Русский', 'flag': '🇷🇺'},
          {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tilni tanlang / Выберите язык',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ...languages.map((lang) {
                  final isSelected = lang['code'] == currentLanguage;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? OrbitaColors.primary.withOpacity(0.08) : const Color(0xFF1C1C2E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? OrbitaColors.primary : const Color(0xFF2A2A3E),
                        width: 1.5,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Text(
                        lang['flag']!,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        lang['name']!,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: OrbitaColors.primary, size: 24)
                          : const Icon(Icons.circle_outlined, color: OrbitaColors.textHint, size: 22),
                      onTap: () {
                        ref.read(languageProvider.notifier).setLanguage(lang['code']!);
                        Navigator.pop(context);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _callSupport() async {
    final uri = Uri.parse('tel:+998901234567');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF13131F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: OrbitaColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Orbita Go',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'v1.0.0 (Kosonsoy edition)',
                style: TextStyle(color: OrbitaColors.textHint, fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Text(
                'Kosonsoy tumani bo\'ylab eng tezkor va qulay taksi xizmati. Orbita ID yagona kirish tizimiga ulangan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: OrbitaColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              OrbitaButton(
                label: 'Yopish',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showQuestsBottomSheet(BuildContext context, WidgetRef ref) {
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
              future: ref.read(apiServiceProvider).getQuests(),
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
                  return const Center(child: Text('Hozircha faol vazifalar yo\'q', style: TextStyle(color: Colors.white70)));
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
                        'Safar Vazifalari',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Taksi safarlarini yakunlab, qo\'shimcha hamyon bonuslariga ega bo\'ling!',
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
                            final desc = q['description'] as String;
                            final target = q['targetCount'] as int;
                            final current = q['currentCount'] as int;
                            final price = (q['rewardPrice'] as num).toDouble();
                            final isCompleted = q['isCompleted'] as bool;

                            final percent = (current / target).clamp(0.0, 1.0);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: OrbitaColors.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isCompleted ? Colors.green.withOpacity(0.3) : const Color(0xFF2A2A3E),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              desc,
                                              style: const TextStyle(
                                                color: OrbitaColors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isCompleted
                                              ? Colors.green.withOpacity(0.15)
                                              : OrbitaColors.primary.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          isCompleted ? 'Tayyor' : '+${price.toStringAsFixed(0)} UZS',
                                          style: TextStyle(
                                            color: isCompleted ? Colors.green : OrbitaColors.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: percent,
                                            backgroundColor: const Color(0xFF2A2A3E),
                                            valueColor: AlwaysStoppedAnimation(
                                              isCompleted ? Colors.green : OrbitaColors.primary,
                                            ),
                                            minHeight: 6,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '$current / $target',
                                        style: TextStyle(
                                          color: isCompleted ? Colors.green : Colors.white70,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final currentLanguage = ref.watch(languageProvider);
    final isDriverMode = ref.watch(driverModeProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: OrbitaColors.backgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                      onPressed: () => context.go('/home'),
                    ),
                    Text(
                      context.tr('profile'),
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Avatar + Name
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: OrbitaColors.primaryGradient,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: OrbitaColors.primary.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 46,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            user?.fullName ?? 'Foydalanuvchi',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _showEditProfileDialog(
                              context,
                              ref,
                              user?.fullName ?? '',
                              user?.username ?? '',
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              color: OrbitaColors.primary,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.phoneNumber ?? (user?.username != null ? '@${user!.username}' : ''),
                        style: const TextStyle(
                          color: OrbitaColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      if (user?.orbitaId != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: OrbitaColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: OrbitaColors.primary.withOpacity(0.3)),
                          ),
                          child: Text(
                            'ID: ${user!.orbitaId}',
                            style: const TextStyle(
                              color: OrbitaColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Wallet card & topup (visible for all users)
                if (true) ...[
                  GestureDetector(
                    onTap: () => context.push('/driver-wallet'),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: OrbitaColors.primaryGradient,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: OrbitaColors.primary.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('wallet_balance'),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(user?.walletBalance ?? 0.0).toStringAsFixed(0)} so\'m',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (isDriverMode) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: OrbitaColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (user?.isVerified == true) ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          (user?.isVerified == true) ? Icons.verified_user_rounded : Icons.warning_amber_rounded,
                          color: (user?.isVerified == true) ? Colors.green : Colors.orange,
                          size: 26,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (user?.isVerified == true) ? 'Tasdiqlangan haydovchi' : 'Faollashtirilmagan haydovchi',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (user?.isVerified == true) ? 'Buyurtmalarni qabul qilishingiz mumkin' : 'Tasdiqlash so\'rovini yuboring',
                                style: const TextStyle(color: OrbitaColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        if (user?.isVerified != true)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: OrbitaColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            onPressed: () async {
                              final success = await ref.read(authProvider.notifier).verifyDriver();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(success ? 'Haydovchi tasdiqlandi!' : 'Xatolik yuz berdi'),
                                    backgroundColor: success ? OrbitaColors.success : OrbitaColors.error,
                                  ),
                                );
                              }
                            },
                            child: const Text('Faollash.', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Language Selector Card (custom to show current language on the right)
                GestureDetector(
                  onTap: () => _showLanguageBottomSheet(context, ref, currentLanguage),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: OrbitaColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF2A2A3E)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: OrbitaColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.language_rounded, color: OrbitaColors.primary, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          context.tr('language'),
                          style: const TextStyle(
                            color: OrbitaColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          currentLanguage == 'uz' ? 'O\'zbekcha 🇺🇿' : (currentLanguage == 'ru' ? 'Русский 🇷🇺' : 'English 🇬🇧'),
                          style: const TextStyle(
                            color: OrbitaColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: OrbitaColors.textHint,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),

                // Menu items
                _MenuItem(
                  icon: Icons.history_rounded,
                  title: context.tr('history'),
                  onTap: () => context.go('/history'),
                ),
                _MenuItem(
                  icon: Icons.payment_rounded,
                  title: context.tr('payment_method'),
                  onTap: () => _showPaymentMethodsBottomSheet(context),
                ),
                _MenuItem(
                  icon: Icons.card_giftcard_rounded,
                  title: "Do'sting bilan yur",
                  onTap: () => context.push('/referral'),
                ),
                _MenuItem(
                  icon: Icons.emoji_events_rounded,
                  title: "Safar Vazifalari",
                  onTap: () => _showQuestsBottomSheet(context, ref),
                ),
                _MenuItem(
                  icon: Icons.help_outline_rounded,
                  title: context.tr('help'),
                  onTap: _callSupport,
                ),
                _MenuItem(
                  icon: Icons.info_outline_rounded,
                  title: context.tr('about_app'),
                  onTap: () => _showAboutDialog(context),
                ),

                const SizedBox(height: 24),

                OrbitaButton(
                  label: context.tr('logout'),
                  isOutlined: true,
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) context.go('/phone');
                  },
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: OrbitaColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A3E)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: OrbitaColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: OrbitaColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Text(
              title,
              style: const TextStyle(
                color: OrbitaColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: OrbitaColors.textHint,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
