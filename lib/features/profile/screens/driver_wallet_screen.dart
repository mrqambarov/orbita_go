import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/screens/driver_home_screen.dart';

class LocalTransaction {
  final String id;
  final double amount;
  final DateTime dateTime;

  LocalTransaction({required this.id, required this.amount, required this.dateTime});

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'dateTime': dateTime.toIso8601String(),
      };

  factory LocalTransaction.fromJson(Map<String, dynamic> json) {
    return LocalTransaction(
      id: json['id'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      dateTime: DateTime.tryParse(json['dateTime'] ?? '') ?? DateTime.now(),
    );
  }
}

class WalletTransactionModel {
  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final DateTime dateTime;
  final bool isCredit; // true = addition (+), false = deduction (-)
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;

  WalletTransactionModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.dateTime,
    required this.isCredit,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
  });
}

class DriverWalletScreen extends ConsumerStatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  ConsumerState<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends ConsumerState<DriverWalletScreen> {
  bool _isLoading = true;
  List<WalletTransactionModel> _transactions = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authState = ref.read(authProvider);
      final user = authState.user;
      if (user == null) {
        throw Exception('Foydalanuvchi tizimga kirmagan');
      }

      final api = ref.read(apiServiceProvider);
      final res = await api.getWalletTransactions();
      
      List<WalletTransactionModel> tempTransactions = [];

      if (res.data['success'] == true) {
        final txList = res.data['transactions'] as List;
        for (var t in txList) {
          final id = t['id'] ?? '';
          final title = t['title'] ?? 'Tranzaksiya';
          final subtitle = t['subtitle'] ?? '';
          final amount = (t['amount'] ?? 0.0).toDouble();
          final isCredit = t['isCredit'] ?? false;
          final type = t['type'] ?? '';
          final dateTime = DateTime.tryParse(t['createdAt'] ?? '') ?? DateTime.now();

          IconData icon = Icons.payment_rounded;
          Color iconColor = OrbitaColors.primary;
          
          if (type == 'REGISTRATION_BONUS') {
            icon = Icons.card_giftcard_rounded;
            iconColor = const Color(0xFFFF9F43);
          } else if (type == 'TOPUP') {
            icon = Icons.account_balance_wallet_rounded;
            iconColor = OrbitaColors.success;
          } else if (type == 'TRIP_EARNING') {
            icon = Icons.directions_car_rounded;
            iconColor = OrbitaColors.primary;
          } else if (type == 'COMMISSION') {
            icon = Icons.percent_rounded;
            iconColor = OrbitaColors.error;
          }

          tempTransactions.add(
            WalletTransactionModel(
              id: id,
              title: title,
              subtitle: subtitle,
              amount: amount,
              dateTime: dateTime,
              isCredit: isCredit,
              icon: icon,
              iconBgColor: iconColor.withOpacity(0.15),
              iconColor: iconColor,
            ),
          );
        }
      }

      setState(() {
        _transactions = tempTransactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ma\'lumotlarni yuklashda xatolik: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleTopup() async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final success = await ref.read(authProvider.notifier).topUpDriverWallet(50000);
      if (success) {
        // Refresh stats on home screen
        ref.read(driverOrdersProvider.notifier).loadAll();

        // Refresh wallet list
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Hamyon muvaffaqiyatli to\'ldirildi!'),
              backgroundColor: OrbitaColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        throw Exception('Balans to\'ldirishda xatolik yuz berdi');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: const Color(0xFF13131F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Hamyon va Hisob',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: OrbitaColors.primary,
        backgroundColor: const Color(0xFF1E1E30),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Balance card
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: OrbitaColors.primaryGradient,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: OrbitaColors.primary.withOpacity(0.35),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Joriy balans',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.security_rounded, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'Xavfsiz',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${(user?.walletBalance ?? 0.0).toStringAsFixed(0)} so\'m',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: OrbitaColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: _isLoading ? null : _handleTopup,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: OrbitaColors.primary, strokeWidth: 2),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_circle_outline_rounded, color: OrbitaColors.primary, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Balansni to\'ldirish (+50,000 UZS)',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // 2. Details info panel
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E30),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF2A2A3E)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Komissiya stavkasi',
                              style: TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '10%',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E30),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF2A2A3E)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Minimal balans',
                              style: TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '5,000 so\'m',
                              style: TextStyle(
                                color: (user?.walletBalance ?? 0.0) < 5000 ? OrbitaColors.error : Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // 3. Transactions header
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Batafsil tranzaksiyalar tarixi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 4. Transaction list
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: OrbitaColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else if (_transactions.isEmpty && !_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.history_toggle_off_rounded, color: Colors.white24, size: 48),
                        SizedBox(height: 12),
                        Text(
                          'Tranzaksiyalar mavjud emas',
                          style: TextStyle(color: Colors.white38),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: _transactions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final tx = _transactions[index];
                    final dateStr = '${tx.dateTime.day.toString().padLeft(2, '0')}.${tx.dateTime.month.toString().padLeft(2, '0')}.${tx.dateTime.year} • ${tx.dateTime.hour.toString().padLeft(2, '0')}:${tx.dateTime.minute.toString().padLeft(2, '0')}';
                    
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E30),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF2A2A3E)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: tx.iconBgColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(tx.icon, color: tx.iconColor, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  tx.subtitle,
                                  style: const TextStyle(
                                    color: Colors.white38,
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
                                '${tx.isCredit ? "+" : "-"}${tx.amount.toStringAsFixed(0)} UZS',
                                style: TextStyle(
                                  color: tx.isCredit ? OrbitaColors.success : OrbitaColors.error,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dateStr,
                                style: const TextStyle(
                                  color: Colors.white24,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// Math helper
class Math {
  static int min(int a, int b) => a < b ? a : b;
}
