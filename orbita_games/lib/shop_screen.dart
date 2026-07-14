import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_provider.dart';
import 'theme.dart';
import 'widgets/galaxy_background.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  List<dynamic> _items = [];
  List<dynamic> _inventory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final res = await ref.read(apiServiceProvider).getShopItems();
      if (res.data['success'] == true) {
        setState(() {
          _items = res.data['items'];
          _inventory = res.data['inventory'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _buyItem(String itemId) async {
    try {
      final res = await ref.read(apiServiceProvider).buyItem(itemId);
      if (res.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.data['message'] ?? 'Sotib olindi!'), backgroundColor: GamesTheme.success),
        );
        _loadData();
        ref.read(authProvider.notifier).checkSession(); // Refresh balance
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.data['message'] ?? 'Xatolik'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarmoq xatosi'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = (ref.watch(authProvider).user?['walletBalance'] ?? 0.0) as num;

    return GalaxyBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('O\'YIN DO\'KONI', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, color: GamesTheme.primary, size: 16),
                    const SizedBox(width: 8),
                    Text('${balance.toStringAsFixed(0)} UZS', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: GamesTheme.primary))
          : GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final isOwned = _inventory.any((i) => i['itemId'] == item['id']);

                return Container(
                  decoration: BoxDecoration(
                    color: GamesTheme.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1E1E45)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: Icon(
                            item['category'] == 'SKIN' ? Icons.rocket_launch_rounded : Icons.flash_on_rounded,
                            color: item['category'] == 'SKIN' ? GamesTheme.secondary : GamesTheme.accent,
                            size: 48,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 4),
                            Text(
                              item['description'],
                              style: const TextStyle(fontSize: 10, color: GamesTheme.textSecondary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isOwned ? Colors.grey.withOpacity(0.2) : GamesTheme.primary,
                                  foregroundColor: isOwned ? Colors.white70 : Colors.black,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: isOwned ? null : () => _buyItem(item['id']),
                                child: Text(isOwned ? 'SOTIB OLINGAN' : '${item['price']} T'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      ),
    );
  }
}
