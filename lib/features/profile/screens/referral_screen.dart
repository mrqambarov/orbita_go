import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/theme/app_theme.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

class ReferralFriend {
  final String id;
  final String fullName;
  final String orbitaId;
  final String? avatarUrl;
  final int totalStepsRedeemed;
  final int completedTrips;
  final bool isRewardClaimed;
  final int milestoneProgress;
  final int milestoneTarget;

  const ReferralFriend({
    required this.id,
    required this.fullName,
    required this.orbitaId,
    this.avatarUrl,
    required this.totalStepsRedeemed,
    required this.completedTrips,
    required this.isRewardClaimed,
    required this.milestoneProgress,
    required this.milestoneTarget,
  });

  factory ReferralFriend.fromJson(Map<String, dynamic> j) => ReferralFriend(
        id: j['id'] ?? '',
        fullName: j['fullName'] ?? 'Foydalanuvchi',
        orbitaId: j['orbitaId'] ?? '',
        avatarUrl: j['avatarUrl'],
        totalStepsRedeemed: j['totalStepsRedeemed'] ?? 0,
        completedTrips: j['completedTrips'] ?? 0,
        isRewardClaimed: j['isReferralRewardClaimed'] ?? false,
        milestoneProgress: j['milestoneProgress'] ?? 0,
        milestoneTarget: j['milestoneTarget'] ?? 50000,
      );
}

// ─── Provider ────────────────────────────────────────────────────────────────

class ReferralState {
  final bool isLoading;
  final String? myCode;
  final List<ReferralFriend> friends;
  final String? error;

  const ReferralState({
    this.isLoading = true,
    this.myCode,
    this.friends = const [],
    this.error,
  });

  ReferralState copyWith({
    bool? isLoading,
    String? myCode,
    List<ReferralFriend>? friends,
    String? error,
  }) =>
      ReferralState(
        isLoading: isLoading ?? this.isLoading,
        myCode: myCode ?? this.myCode,
        friends: friends ?? this.friends,
        error: error ?? this.error,
      );
}

final referralProvider =
    StateNotifierProvider.autoDispose<ReferralNotifier, ReferralState>(
  (ref) => ReferralNotifier(ref.read(apiServiceProvider)),
);

class ReferralNotifier extends StateNotifier<ReferralState> {
  final ApiService _api;
  ReferralNotifier(this._api) : super(const ReferralState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.getReferrals();
      if (res.data['success'] == true) {
        final data = res.data as Map<String, dynamic>;
        final friends = (data['referrals'] as List<dynamic>)
            .map((e) => ReferralFriend.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(
          isLoading: false,
          myCode: data['myReferralCode'] as String?,
          friends: friends,
        );
      } else {
        state = state.copyWith(isLoading: false, error: res.data['message']);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Yuklashda xatolik yuz berdi');
    }
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(referralProvider);
    final fallbackCode = ref.watch(authProvider).user?.orbitaId ?? '';
    final myCode = state.myCode?.isNotEmpty == true ? state.myCode! : fallbackCode;

    return Container(
      decoration: const BoxDecoration(gradient: OrbitaColors.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            "Do'sting bilan yur",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator(color: OrbitaColors.primary))
            : RefreshIndicator(
                color: OrbitaColors.primary,
                backgroundColor: OrbitaColors.card,
                onRefresh: () => ref.read(referralProvider.notifier).load(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeroCard(myCode: myCode),
                      const SizedBox(height: 20),
                      _MilestoneInfo(),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Text(
                            "Taklif qilgan do'stlar",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: OrbitaColors.primary.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${state.friends.length}',
                              style: const TextStyle(color: OrbitaColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (state.friends.isEmpty)
                        _EmptyFriendsCard()
                      else
                        ...state.friends.map((f) => _FriendCard(friend: f)),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

// ─── Hero Card ───────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final String myCode;
  const _HeroCard({required this.myCode});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [OrbitaColors.primary.withOpacity(0.22), const Color(0xFF6A3DE8).withOpacity(0.12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: OrbitaColors.primary.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: OrbitaColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.card_giftcard_rounded, color: OrbitaColors.primary, size: 32),
          ),
          const SizedBox(height: 14),
          const Text("Har bir do'stingiz uchun", style: TextStyle(color: OrbitaColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          const Text(
            "+5,000 UZS",
            style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          const Text(
            "Ikkalangizga ham tushadi!",
            style: TextStyle(color: OrbitaColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          // Code Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF12122A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: OrbitaColors.primary.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    myCode,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: OrbitaColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: myCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kod nusxa olindi!'),
                        backgroundColor: OrbitaColors.primary,
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: OrbitaColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.copy_rounded, color: OrbitaColors.primary, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: OrbitaColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                final text =
                    "Orbita Go – Kosonsoy'ning taksi ilovasi!\n"
                    "Mening taklif kodim bilan ro'yxatdan o'ting va ikkalamiz ham 5,000 UZS bonus olamiz!\n\n"
                    "Kod: $myCode";
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Matn nusxalandi — do'stingizga yuboring!"),
                    backgroundColor: OrbitaColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text("Do'stga ulashish", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Milestone Info ───────────────────────────────────────────────────────────

class _MilestoneInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OrbitaColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: OrbitaColors.primary, size: 18),
              SizedBox(width: 8),
              Text("Qanday ishlaydi?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          _StepItem(icon: Icons.person_add_alt_1_rounded, text: "Do'stingizga Orbita ID kodingizni yuboring"),
          const SizedBox(height: 8),
          _StepItem(icon: Icons.app_registration_rounded, text: "Do'stingiz ro'yxatdan o'tib, taklif kodingizni kiritadi"),
          const SizedBox(height: 8),
          _StepItem(icon: Icons.directions_car_rounded, text: "Do'stingiz 2 ta taksi safari qilgach yoki 50,000 qadam yurgach..."),
          const SizedBox(height: 8),
          _StepItem(icon: Icons.wallet_rounded, text: "Ikkalangizning hamyoniga avtomatik 5,000 UZS tushadi!", highlight: true),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlight;
  const _StepItem({required this.icon, required this.text, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: highlight ? OrbitaColors.success : OrbitaColors.textSecondary, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: highlight ? OrbitaColors.success : OrbitaColors.textSecondary,
              fontSize: 13,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Friend Card ─────────────────────────────────────────────────────────────

class _FriendCard extends StatelessWidget {
  final ReferralFriend friend;
  const _FriendCard({required this.friend});

  @override
  Widget build(BuildContext context) {
    final progress = (friend.milestoneProgress / friend.milestoneTarget).clamp(0.0, 1.0);
    final isClaimed = friend.isRewardClaimed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OrbitaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isClaimed ? OrbitaColors.success.withOpacity(0.4) : const Color(0xFF2A2A3E),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: OrbitaColors.primary.withOpacity(0.15),
                backgroundImage: friend.avatarUrl != null ? NetworkImage(friend.avatarUrl!) : null,
                child: friend.avatarUrl == null
                    ? Text(
                        (friend.fullName.isNotEmpty ? friend.fullName[0] : 'F').toUpperCase(),
                        style: const TextStyle(color: OrbitaColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(friend.fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(friend.orbitaId, style: const TextStyle(color: OrbitaColors.textHint, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isClaimed ? OrbitaColors.success.withOpacity(0.15) : OrbitaColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isClaimed ? '✅ Bajarildi' : '⏳ Davom etmoqda',
                  style: TextStyle(
                    color: isClaimed ? OrbitaColors.success : OrbitaColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.directions_walk_rounded, color: OrbitaColors.textHint, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${friend.milestoneProgress} / 50,000 qadam',
                            style: const TextStyle(color: OrbitaColors.textSecondary, fontSize: 11)),
                        Text('${friend.completedTrips} ta safar',
                            style: const TextStyle(color: OrbitaColors.textHint, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: const Color(0xFF2A2A3E),
                        color: isClaimed ? OrbitaColors.success : OrbitaColors.primary,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────

class _EmptyFriendsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: OrbitaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: const Column(
        children: [
          Icon(Icons.group_add_rounded, color: OrbitaColors.textHint, size: 48),
          SizedBox(height: 12),
          Text("Hali hech kim yo'q", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text(
            "Kodingizni do'stlaringizga ulashing\nva birgalikda bonus oling!",
            textAlign: TextAlign.center,
            style: TextStyle(color: OrbitaColors.textHint, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
