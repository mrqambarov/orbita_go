import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

final orderHistoryProvider = FutureProvider<List<OrderModel>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final user = ref.read(authProvider).user;
  if (user == null) return [];
  final res = await api.getOrderHistory(user.id);
  if (res.data['success'] == true) {
    final list = res.data['orders'] as List;
    return list.map((o) => OrderModel.fromJson(o)).toList();
  }
  return [];
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(orderHistoryProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: OrbitaColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Text(
                  'Sayohatlar tarixi',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: history.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: OrbitaColors.primary),
                  ),
                  error: (_, __) => const Center(
                    child: Text(
                      'Xatolik yuz berdi',
                      style: TextStyle(color: OrbitaColors.textSecondary),
                    ),
                  ),
                  data: (orders) {
                    if (orders.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: OrbitaColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: const Icon(
                                Icons.history_rounded,
                                color: OrbitaColors.primary,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Hali sayohatlar yo\'q',
                              style: TextStyle(
                                color: OrbitaColors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      itemCount: orders.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, i) =>
                          _OrderHistoryCard(order: orders[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderHistoryCard extends StatelessWidget {
  final OrderModel order;
  const _OrderHistoryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final isCompleted = order.status == OrderStatus.completed;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: OrbitaColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (isCompleted
                          ? OrbitaColors.success
                          : OrbitaColors.error)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isCompleted ? 'Yakunlangan' : 'Bekor qilingan',
                  style: TextStyle(
                    color: isCompleted
                        ? OrbitaColors.success
                        : OrbitaColors.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${order.price.toStringAsFixed(0)} so\'m',
                style: const TextStyle(
                  color: OrbitaColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _LocationRow(
            icon: Icons.radio_button_checked,
            color: OrbitaColors.primary,
            text: order.fromAddress,
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Container(
              width: 1,
              height: 18,
              color: const Color(0xFF3A3A4E),
            ),
          ),
          const SizedBox(height: 2),
          _LocationRow(
            icon: Icons.location_on_rounded,
            color: OrbitaColors.error,
            text: order.toAddress,
          ),
          const SizedBox(height: 10),
          Text(
            _formatDate(order.createdAt),
            style: const TextStyle(
              color: OrbitaColors.textHint,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _LocationRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: OrbitaColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
