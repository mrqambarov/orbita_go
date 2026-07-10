import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_provider.dart';
import 'theme.dart';
import 'widgets/premium_card.dart';
import 'widgets/bouncy_button.dart';

class GardenScreen extends ConsumerStatefulWidget {
  const GardenScreen({super.key});

  @override
  ConsumerState<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends ConsumerState<GardenScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _garden;
  bool _isLoading = true;
  bool _isWatering = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final res = await ref.read(apiServiceProvider).getGarden();
      if (res.data['success'] == true) {
        setState(() {
          _garden = res.data['garden'];
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _water() async {
    if (_isWatering) return;
    setState(() => _isWatering = true);
    HapticFeedback.heavyImpact();

    try {
      final res = await ref.read(apiServiceProvider).waterGarden(amount: 10);
      if (res.data['success'] == true) {
        setState(() {
          _garden = res.data['garden'];
          _isWatering = false;
        });
        if (res.data['leveledUp'] == true) _showLevelUp();
      }
    } catch (_) {
      setState(() => _isWatering = false);
    }
  }

  void _showLevelUp() {
    showDialog(context: context, builder: (c) => AlertDialog(backgroundColor: GamesTheme.card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), title: const Text('DARAXT O\'SDI! 🌳', style: TextStyle(color: GamesTheme.success, fontWeight: FontWeight.bold)), content: const Text('Daraxtingiz yanada chiroyli va kuchli bo\'ldi!'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('DAVOM ETISH'))]));
  }

  Future<void> _showWaterFriendDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool processing = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: GamesTheme.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Do\'stga ko\'mak berish 🤝', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Do\'stingizning Orbita ID raqamini kiriting. Uning daraxtiga +10 suv quyiladi va sizga 50 UZS hamyon mukofoti beriladi.',
                  style: TextStyle(color: GamesTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'ORB-123456',
                    hintStyle: TextStyle(color: Colors.white24),
                    labelText: 'Orbita ID',
                    labelStyle: TextStyle(color: GamesTheme.success),
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Orbita ID kiritilishi shart' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: processing ? null : () => Navigator.pop(context),
              child: const Text('Bekor qilish', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: processing ? null : () async {
                if (formKey.currentState?.validate() == true) {
                  setDialogState(() => processing = true);
                  try {
                    final api = ref.read(apiServiceProvider);
                    final res = await api.waterFriendGarden(controller.text.trim());
                    if (context.mounted) {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (c) => AlertDialog(
                          backgroundColor: GamesTheme.card,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          title: const Text('MUVAFFAQIYAT! 🎉', style: TextStyle(color: GamesTheme.success, fontWeight: FontWeight.bold)),
                          content: Text(res.data['message'] ?? 'Do\'stingiz daraxti sug\'orildi va sizga mukofot berildi!'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: const Text('DAVOM ETISH'),
                            )
                          ],
                        ),
                      );
                    }
                  } catch (err: any) {
                    setDialogState(() => processing = false);
                    final msg = err.response?.data['message'] ?? 'Xatolik yuz berdi';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(msg), backgroundColor: GamesTheme.error),
                    );
                  }
                }
              },
              child: processing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: GamesTheme.success, strokeWidth: 2))
                  : const Text('Sug\'orish', style: TextStyle(color: GamesTheme.success, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: GamesTheme.background, body: Center(child: CircularProgressIndicator()));

    final int level = _garden?['level'] ?? 1;
    final int water = _garden?['water'] ?? 0;
    final int target = level * 100;
    final double progress = (water / target).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: GamesTheme.background,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: Text('VIRTUAL BOG\'', style: GoogleFonts.outfit(fontWeight: FontWeight.w900))),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0F0E2A), Color(0xFF0F2A14)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: Column(
          children: [
            const SizedBox(height: 30),
            PremiumCard(
              glowColor: GamesTheme.success,
              child: Column(
                children: [
                  Text('DARAXT DARAJASI: $level', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: progress, minHeight: 12, borderRadius: BorderRadius.circular(10), backgroundColor: Colors.white10, valueColor: const AlwaysStoppedAnimation(GamesTheme.success)),
                  const SizedBox(height: 8),
                  Text('$water / $target suv quyildi', style: const TextStyle(color: GamesTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Keyingi darajaga: 10 suv = 1 qadam', style: TextStyle(color: Colors.white54, fontSize: 10, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            const Spacer(),
            _VisualTree(level: level, isWatering: _isWatering),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  BouncyButton(
                    onTap: _water,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.water_drop_rounded, color: Colors.white),
                          SizedBox(width: 12),
                          Text('SUV QUYISH (10 T)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  BouncyButton(
                    onTap: _showWaterFriendDialog,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: GamesTheme.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_alt_rounded, color: GamesTheme.success),
                          SizedBox(width: 12),
                          Text('DO\'STGA KO\'MAK BERISH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _VisualTree extends StatelessWidget {
  final int level; final bool isWatering;
  const _VisualTree({required this.level, required this.isWatering});

  @override
  Widget build(BuildContext context) {
    IconData icon = Icons.grass_rounded;
    Color color = Colors.greenAccent;
    double size = 100 + (level * 15.0);

    if (level >= 3) icon = Icons.park_rounded;
    if (level >= 7) icon = Icons.eco_rounded;
    if (level >= 12) icon = Icons.forest_rounded;
    
    return AnimatedScale(
      scale: isWatering ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, size: size, color: Colors.green[900]?.withOpacity(0.5)),
          Icon(icon, size: size - 10, color: color),
          if (isWatering) const Positioned(top: 0, child: Icon(Icons.water_drop, color: Colors.blue, size: 30)),
        ],
      ),
    );
  }
}
