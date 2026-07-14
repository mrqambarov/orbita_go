import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_provider.dart';
import 'game_screen.dart';
import 'word_game_screen.dart';
import 'puzzle_game_screen.dart';
import 'math_dash_screen.dart';
import 'quiz_planet_screen.dart';
import 'star_connect_screen.dart';
import 'rocket_rush_screen.dart';
import 'shop_screen.dart';
import 'leaderboard_screen.dart';
import 'garden_screen.dart';
import 'duel_lobby_screen.dart';
import 'clash/clash_screen.dart';
import 'clash/clash_lobby.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets/premium_card.dart';
import 'widgets/galaxy_background.dart';
import 'widgets/xp_progress_bar.dart';
import 'widgets/bouncy_button.dart';
import 'widgets/xp_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _highScore = 0;
  int _mathHighScore = 0;
  int _starLevel = 1;
  int _rocketHighScore = 0;
  int _wordLevel = 1;
  int _coinBank = 0;
  bool _isConverting = false;
  List<dynamic> _missions = [];

  bool _hasCheckedInToday = false;
  int _checkInStreak = 0;
  List<int> _checkInRewards = [];
  bool _isLoadingCheckIn = true;

  @override
  void initState() {
    super.initState();
    _loadLocalStats();
    _loadMissions();
    _loadCheckInStatus();
    _seedIfEmpty();
  }

  Future<void> _seedIfEmpty() async {
    try {
      await ref.read(apiServiceProvider).seedData();
      _loadMissions();
    } catch (_) {}
  }

  Future<void> _loadLocalStats() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _highScore = prefs.getInt('high_score') ?? 0;
      _mathHighScore = prefs.getInt('math_high_score') ?? 0;
      _starLevel = (prefs.getInt('star_connect_level') ?? 0) + 1;
      _rocketHighScore = prefs.getInt('rocket_rush_high_score') ?? 0;
      _wordLevel = (prefs.getInt('word_level') ?? 0) + 1;
      _coinBank = prefs.getInt('coin_bank') ?? 0;
    });
    ref.read(xpProvider.notifier).loadXp();
  }

  Future<void> _loadMissions() async {
    try {
      final res = await ref.read(apiServiceProvider).getMissions();
      if (res.data['success'] == true) {
        setState(() {
          _missions = res.data['missions'];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCheckInStatus() async {
    try {
      final res = await ref.read(apiServiceProvider).getCheckInStatus();
      if (res.data['success'] == true) {
        setState(() {
          _hasCheckedInToday = res.data['hasCheckedInToday'];
          _checkInStreak = res.data['streak'];
          _checkInRewards = List<int>.from(res.data['rewards']);
          _isLoadingCheckIn = false;
        });
      }
    } catch (_) {
      setState(() => _isLoadingCheckIn = false);
    }
  }

  Future<void> _claimCheckInReward() async {
    if (_hasCheckedInToday) return;
    try {
      final res = await ref.read(apiServiceProvider).claimCheckIn();
      if (res.data['success'] == true) {
        final coinsWon = res.data['coins'] as int;
        final xpWon = res.data['xp'] as int;
        
        final prefs = await SharedPreferences.getInstance();
        final currentBank = prefs.getInt('coin_bank') ?? 0;
        await prefs.setInt('coin_bank', currentBank + coinsWon);

        await ref.read(xpProvider.notifier).addXp(xpWon);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.data['message'] ?? 'Kunlik mukofot olindi!'),
              backgroundColor: GamesTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        
        await ref.read(authProvider.notifier).checkSession();
        _loadLocalStats();
        _loadCheckInStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mukofotni olishda ulanish xatosi'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _claimMission(String missionId) async {
    try {
      final res = await ref.read(apiServiceProvider).claimMission(missionId);
      if (res.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Mukofot olindi: +${res.data['reward']} tanga!'),
              backgroundColor: GamesTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        await ref.read(authProvider.notifier).checkSession();
        _loadMissions();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.data['message'] ?? 'Xatolik yuz berdi'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ulanish xatosi'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _convertCoins() async {
    if (_coinBank <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hali konvertatsiya qilish uchun tangalar yo\'q.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _isConverting = true);
    try {
      final res = await ref.read(apiServiceProvider).convertCoins(_coinBank);
      if (res.data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('coin_bank', 0);
        setState(() => _coinBank = 0);
        ref.read(authProvider.notifier).updateUser(res.data['user']);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.data['message'] ?? 'O\'tkazildi!'), backgroundColor: GamesTheme.success, behavior: SnackBarBehavior.floating),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  void _openClashChooser() {
    showModalBottomSheet(
      context: context,
      backgroundColor: GamesTheme.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('⚔️ ORBITA CLASH', style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('Jang rejimini tanlang', style: TextStyle(color: GamesTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 22),
            _modeBtn('🤖  Bot bilan', 'Mashq va o\'rganish', Colors.blueGrey, () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ClashScreen()));
            }),
            const SizedBox(height: 12),
            _modeBtn('🌐  Online raqib', 'Real o\'yinchi bilan jang', const Color(0xFF7C4DFF), () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ClashLobbyScreen()));
            }),
          ],
        ),
      ),
    );
  }

  Widget _modeBtn(String title, String subtitle, Color color, VoidCallback onTap) {
    return BouncyButton(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withOpacity(0.35), color.withOpacity(0.12)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                  Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final xpState = ref.watch(xpProvider);
    final user = authState.user ?? {};
    final fullName = user['fullName'] ?? 'Foydalanuvchi';
    final orbitaId = user['orbitaId'] ?? 'ORB-000000';
    final balance = (user['walletBalance'] ?? 0.0) as num;

    return Scaffold(
      body: GalaxyBackground(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 140,
              floating: true,
              pinned: true,
              backgroundColor: const Color(0xFF0F0E2A).withOpacity(0.9),
              elevation: 0,
              centerTitle: true,
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: Text(
                  'ORBITA GALAXY',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900, 
                    letterSpacing: 3.0, 
                    fontSize: 22,
                    color: Colors.white,
                    shadows: [Shadow(color: GamesTheme.primary.withOpacity(0.8), blurRadius: 15)]
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_rounded, color: Colors.white),
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    _loadLocalStats();
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PremiumCard(
                          padding: const EdgeInsets.all(4),
                          glowColor: GamesTheme.primary,
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: GamesTheme.primary.withOpacity(0.1),
                            child: const Icon(Icons.person_rounded, color: GamesTheme.primary, size: 30),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                              Text(orbitaId, style: const TextStyle(color: GamesTheme.textSecondary, fontSize: 12)),
                              const SizedBox(height: 8),
                              XpProgressBar(level: xpState.level, currentXp: xpState.currentLevelXp, nextLevelXp: xpState.nextLevelXp),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    PremiumCard(
                      padding: const EdgeInsets.all(20),
                      glowColor: GamesTheme.accent,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _StatItem(label: 'BALANS', value: '${balance.toStringAsFixed(0)} UZS', icon: Icons.account_balance_wallet_rounded, color: GamesTheme.primary),
                              _StatItem(label: 'TANGALAR', value: '$_coinBank', icon: Icons.stars_rounded, color: GamesTheme.accent),
                            ],
                          ),
                          const SizedBox(height: 20),
                          BouncyButton(
                            onTap: _isConverting ? null : _convertCoins,
                            child: Container(
                              height: 50,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [GamesTheme.primary, Color(0xFF4CAF50)]),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: GamesTheme.primary.withOpacity(0.3), blurRadius: 10)],
                              ),
                              alignment: Alignment.center,
                              child: _isConverting 
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                : const Text('HAMYONGA O\'TKAZISH', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    _SectionHeader(title: 'FLAGMAN O\'YIN'),
                    const SizedBox(height: 16),
                    _ClashHeroBanner(onPlay: _openClashChooser),

                    const SizedBox(height: 32),
                    _SectionHeader(title: 'TEZKOR AMALLAR'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _QuickBtn(label: 'DO\'KON', icon: Icons.shopping_bag_rounded, color: GamesTheme.secondary, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen()))),
                        _QuickBtn(label: 'REYTING', icon: Icons.emoji_events_rounded, color: GamesTheme.accent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()))),
                        _QuickBtn(label: 'BOG\'', icon: Icons.park_rounded, color: Colors.greenAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GardenScreen()))),
                        _QuickBtn(label: 'DUEL', icon: Icons.flash_on_rounded, color: Colors.orangeAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DuelLobbyScreen()))),
                      ],
                    ),
                    
                    if (!_isLoadingCheckIn && _checkInRewards.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      _SectionHeader(title: 'KUNLIK MUKOFOTLAR'),
                      const SizedBox(height: 16),
                      PremiumCard(
                        padding: const EdgeInsets.all(16),
                        glowColor: _hasCheckedInToday ? Colors.grey : GamesTheme.primary,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'KUNLIK STREAK: $_checkInStreak KUN',
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _hasCheckedInToday ? 'Ertaga yangi mukofot ochiladi' : 'Bugungi mukofotni olishga tayyor!',
                                      style: TextStyle(color: _hasCheckedInToday ? GamesTheme.textSecondary : GamesTheme.accent, fontSize: 10),
                                    ),
                                  ],
                                ),
                                if (!_hasCheckedInToday)
                                  BouncyButton(
                                    onTap: _claimCheckInReward,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [GamesTheme.primary, Color(0xFF4CAF50)]),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'OLISH',
                                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white10,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.check_circle_outline_rounded, color: GamesTheme.success, size: 14),
                                        SizedBox(width: 6),
                                        Text(
                                          'OLINDI',
                                          style: TextStyle(color: GamesTheme.success, fontWeight: FontWeight.bold, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: List.generate(7, (index) {
                                  final dayNum = index + 1;
                                  final reward = _checkInRewards[index];
                                  
                                  bool isClaimed = false;
                                  bool isToday = false;
                                  
                                  if (_hasCheckedInToday) {
                                    if (dayNum <= _checkInStreak) {
                                      isClaimed = true;
                                    }
                                  } else {
                                    if (dayNum <= _checkInStreak) {
                                      isClaimed = true;
                                    } else if (dayNum == _checkInStreak + 1) {
                                      isToday = true;
                                    }
                                  }

                                  Color cardBorderColor = Colors.white10;
                                  Color cardBgColor = Colors.white.withOpacity(0.02);
                                  Widget statusIcon = const Icon(Icons.lock_rounded, color: Colors.white24, size: 16);

                                  if (isClaimed) {
                                    cardBorderColor = GamesTheme.success.withOpacity(0.4);
                                    cardBgColor = GamesTheme.success.withOpacity(0.05);
                                    statusIcon = const Icon(Icons.check_circle_rounded, color: GamesTheme.success, size: 18);
                                  } else if (isToday) {
                                    cardBorderColor = GamesTheme.accent;
                                    cardBgColor = GamesTheme.accent.withOpacity(0.1);
                                    statusIcon = const Icon(Icons.card_giftcard_rounded, color: GamesTheme.accent, size: 18);
                                  }

                                  return Container(
                                    width: 72,
                                    margin: const EdgeInsets.only(right: 10),
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: cardBgColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: cardBorderColor),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          '$dayNum-kun',
                                          style: TextStyle(
                                            color: isToday ? Colors.white : GamesTheme.textSecondary,
                                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                            fontSize: 10,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        statusIcon,
                                        const SizedBox(height: 8),
                                        Text(
                                          '+$reward T',
                                          style: GoogleFonts.outfit(
                                            color: isToday ? GamesTheme.accent : Colors.white70,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 32),
                    _SectionHeader(title: 'KUNLIK TOPSHIRIQLAR'),
                    const SizedBox(height: 16),
                    if (_missions.isEmpty)
                      const Text('Topshiriqlar yo\'q', style: TextStyle(color: GamesTheme.textSecondary))
                    else
                      ..._missions.map((m) => _MissionItem(mission: m, onClaim: () => _claimMission(m['id']))),

                    const SizedBox(height: 32),
                    _SectionHeader(title: 'GALAXY GAMES'),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate([
                _GameTile(title: 'ROCKET RUSH', subtitle: 'To\'siqlardan o\'ting', icon: Icons.rocket_launch_rounded, stats: 'BEST: $_rocketHighScore', color: GamesTheme.secondary, onPlay: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RocketRushScreen()))),
                _GameTile(title: 'WORD QUEST', subtitle: 'Bilimingizni sinang', icon: Icons.font_download_rounded, stats: 'LVL: $_wordLevel', color: GamesTheme.accent, onPlay: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WordGameScreen()))),
                _GameTile(title: 'MATH DASH', subtitle: 'Tezkor hisob-kitob', icon: Icons.calculate_rounded, stats: 'BEST: $_mathHighScore', color: Colors.deepOrangeAccent, onPlay: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MathDashScreen()))),
                _GameTile(title: 'STAR CONNECT', subtitle: 'Mantiqiy bog\'lanish', icon: Icons.auto_fix_high_rounded, stats: 'LVL: $_starLevel', color: Colors.tealAccent, onPlay: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StarConnectScreen()))),
                _GameTile(title: 'MEMORY', subtitle: 'Xotirani charxlang', icon: Icons.grid_view_rounded, stats: 'PUZZLE', color: Colors.lightBlueAccent, onPlay: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PuzzleGameScreen()))),
                const SizedBox(height: 40),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatItem({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 6), Text(label, style: const TextStyle(fontSize: 10, color: GamesTheme.textSecondary, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Text(title, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5));
  }
}

class _QuickBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickBtn({required this.label, required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: BouncyButton(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _MissionItem extends StatelessWidget {
  final dynamic mission;
  final VoidCallback onClaim;
  const _MissionItem({required this.mission, required this.onClaim});
  @override
  Widget build(BuildContext context) {
    final bool done = mission['isCompleted'];
    final bool claimed = mission['isClaimed'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: PremiumCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(done ? Icons.check_circle_rounded : Icons.radio_button_off_rounded, color: done ? GamesTheme.success : GamesTheme.textSecondary, size: 20),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(mission['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)), Text(mission['description'], style: const TextStyle(fontSize: 10, color: GamesTheme.textSecondary))])),
            if (done && !claimed) BouncyButton(onTap: onClaim, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: GamesTheme.accent, borderRadius: BorderRadius.circular(8)), child: Text('${mission['reward']} T', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10))))
            else if (claimed) const Text('OLINDI', style: TextStyle(color: GamesTheme.success, fontWeight: FontWeight.bold, fontSize: 10))
            else Text('${mission['currentValue']}/${mission['goalValue']}', style: const TextStyle(color: GamesTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _ClashHeroBanner extends StatefulWidget {
  final VoidCallback onPlay;
  const _ClashHeroBanner({required this.onPlay});
  @override
  State<_ClashHeroBanner> createState() => _ClashHeroBannerState();
}

class _ClashHeroBannerState extends State<_ClashHeroBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final glow = 0.35 + 0.35 * (0.5 - (_c.value - 0.5).abs()) * 2; // 0.35..0.70 pulse
        return GestureDetector(
          onTap: widget.onPlay,
          child: Container(
            height: 172,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3A2A7A), Color(0xFF1E163F), Color(0xFF120C24)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.6), width: 1.4),
              boxShadow: [BoxShadow(color: const Color(0xFF7C4DFF).withOpacity(glow), blurRadius: 26, spreadRadius: 1)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // Fon bezaklari
                  Positioned(right: -14, bottom: -22, child: Text('⚔️', style: TextStyle(fontSize: 130, color: Colors.white.withOpacity(0.06)))),
                  Positioned(right: 96, top: -26, child: Text('🏰', style: TextStyle(fontSize: 78, color: Colors.white.withOpacity(0.05)))),
                  // Harakatlanuvchi shimmer
                  Positioned.fill(
                    child: FractionallySizedBox(
                      widthFactor: 0.4,
                      alignment: Alignment(-1.4 + 2.8 * _c.value, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.06),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                    ),
                  ),
                  // Kontent
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: GamesTheme.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                          child: Text('⭐ FLAGMAN O\'YIN', style: GoogleFonts.outfit(color: GamesTheme.accent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        ),
                        const SizedBox(height: 10),
                        Text('ORBITA CLASH',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              shadows: [Shadow(color: const Color(0xFF7C4DFF).withOpacity(0.9), blurRadius: 16)],
                            )),
                        const SizedBox(height: 2),
                        const Text('Real-time arena jang — mahallang uchun kurash',
                            style: TextStyle(color: Colors.white70, fontSize: 11)),
                        const Spacer(),
                        Row(
                          children: [
                            _heroChip('🏆 PvP'),
                            const SizedBox(width: 8),
                            _heroChip('⚡ 3 daqiqa'),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [GamesTheme.primary, Color(0xFF7C4DFF)]),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [BoxShadow(color: GamesTheme.primary.withOpacity(0.5), blurRadius: 12)],
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                                Text('JANGGA KIRISH', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12)),
                                SizedBox(width: 6),
                                Icon(Icons.sports_kabaddi_rounded, color: Colors.black, size: 16),
                              ]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _heroChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      );
}

class _GameTile extends StatelessWidget {
  final String title, subtitle, stats;
  final IconData icon;
  final Color color;
  final VoidCallback onPlay;
  const _GameTile({required this.title, required this.subtitle, required this.stats, required this.icon, required this.color, required this.onPlay});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: BouncyButton(
        onTap: onPlay,
        child: PremiumCard(
          padding: const EdgeInsets.all(16),
          glowColor: color,
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: color, size: 28)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 15)), Text(subtitle, style: const TextStyle(color: GamesTheme.textSecondary, fontSize: 11))])),
              Text(stats, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: GamesTheme.primary, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
