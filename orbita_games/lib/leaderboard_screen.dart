import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_provider.dart';
import 'theme.dart';
import 'widgets/galaxy_background.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Map<String, String>> _gameTypes = [
    {'id': 'GRAVITY_RUN', 'name': 'Gravity Run'},
    {'id': 'MATH_DASH', 'name': 'Math Dash'},
    {'id': 'WORD_QUEST', 'name': 'Word Quest'},
  ];

  Map<String, List<dynamic>> _data = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _gameTypes.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _fetchData();
    });
    _fetchData();
  }

  Future<void> _fetchData() async {
    final gameType = _gameTypes[_tabController.index]['id']!;
    setState(() => _isLoading = true);
    try {
      final res = await ref.read(apiServiceProvider).getLeaderboard(gameType);
      if (res.data['success'] == true) {
        setState(() {
          _data[gameType] = res.data['leaderboard'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GalaxyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('PESHQADAMLAR', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: GamesTheme.primary,
            labelColor: GamesTheme.primary,
            unselectedLabelColor: GamesTheme.textSecondary,
            tabs: _gameTypes.map((t) => Tab(text: t['name'])).toList(),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: _gameTypes.map((t) => _buildLeaderboardList(t['id']!)).toList(),
        ),
      ),
    );
  }

  Widget _buildLeaderboardList(String gameType) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: GamesTheme.primary));
    final list = _data[gameType] ?? [];

    if (list.isEmpty) {
      return const Center(child: Text('Hali natijalar yo\'q', style: TextStyle(color: GamesTheme.textSecondary)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final user = item['user'];
        final score = item['highScore'];
        final level = item['level'];
        final isTop3 = index < 3;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: GamesTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isTop3 ? GamesTheme.primary.withOpacity(0.3) : const Color(0xFF1E1E45)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isTop3 ? GamesTheme.primary : Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isTop3 ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white.withOpacity(0.1),
                child: const Icon(Icons.person_rounded, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['fullName'] ?? 'Noma\'lum', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(user['orbitaId'] ?? '', style: const TextStyle(fontSize: 10, color: GamesTheme.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    gameType == 'WORD_QUEST' ? '$level LVL' : '$score',
                    style: const TextStyle(fontWeight: FontWeight.w900, color: GamesTheme.accent),
                  ),
                  const Text('BALL', style: TextStyle(fontSize: 8, color: GamesTheme.textSecondary)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
