import 'package:flutter/material.dart';
import '../../../core/models/models.dart';
import '../../../shared/theme/app_theme.dart';
import '../providers/home_provider.dart';

class BookingBottomSheet extends StatelessWidget {
  final HomeState homeState;
  final Function(TariffModel) onTariffSelected;
  final VoidCallback onDestinationSearch;
  final VoidCallback onStopSearch;
  final VoidCallback onStopClear;
  final VoidCallback onOrderCreate;
  final double walletBalance;
  final Function(String) onPaymentMethodSelected;

  const BookingBottomSheet({
    super.key,
    required this.homeState,
    required this.onTariffSelected,
    required this.onDestinationSearch,
    required this.onStopSearch,
    required this.onStopClear,
    required this.onOrderCreate,
    required this.walletBalance,
    required this.onPaymentMethodSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF13131F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 30,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A4E),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Destination input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: onDestinationSearch,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: OrbitaColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: homeState.destinationPoint != null
                        ? OrbitaColors.primary.withOpacity(0.5)
                        : const Color(0xFF2A2A3E),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      color: homeState.destinationPoint != null
                          ? OrbitaColors.primary
                          : OrbitaColors.textHint,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        homeState.toAddress.isEmpty
                            ? 'Qayerga?'
                            : homeState.toAddress,
                        style: TextStyle(
                          color: homeState.toAddress.isEmpty
                              ? OrbitaColors.textHint
                              : OrbitaColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.search_rounded,
                      color: OrbitaColors.textHint,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Stopover point row
          if (homeState.stopPoint != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: OrbitaColors.surfaceLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.adjust_rounded, color: Colors.purpleAccent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        homeState.stopAddress,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: OrbitaColors.textHint, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: onStopClear,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextButton.icon(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.purpleAccent, size: 16),
                  label: const Text(
                    'Yo\'l-yo\'lakay to\'xtash joyi',
                    style: TextStyle(color: Colors.purpleAccent, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  onPressed: onStopSearch,
                ),
              ),
            ),
          ],

          // Tariff selector
          if (homeState.destinationPoint != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: TariffModel.defaults.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final tariff = TariffModel.defaults[i];
                  final isSelected =
                      homeState.selectedTariff?.id == tariff.id;
                  return TariffCard(
                    tariff: tariff,
                    isSelected: isSelected,
                    estimatedPrice: isSelected
                        ? homeState.estimatedPrice
                        : (homeState.distanceKm != null
                            ? tariff.calculatePrice(homeState.distanceKm!)
                            : null),
                    onTap: () => onTariffSelected(tariff),
                  );
                },
              ),
            ),
          ],

          // Payment method selector
          if (homeState.destinationPoint != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'To\'lov usuli',
                    style: TextStyle(
                      color: OrbitaColors.textHint,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // CASH option
                      Expanded(
                        child: GestureDetector(
                          onTap: () => onPaymentMethodSelected('CASH'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                            decoration: BoxDecoration(
                              color: homeState.paymentMethod == 'CASH'
                                  ? OrbitaColors.primary.withOpacity(0.12)
                                  : OrbitaColors.surfaceLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: homeState.paymentMethod == 'CASH'
                                    ? OrbitaColors.primary
                                    : const Color(0xFF2A2A3E),
                                width: homeState.paymentMethod == 'CASH' ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.money_rounded,
                                  color: homeState.paymentMethod == 'CASH'
                                      ? OrbitaColors.primary
                                      : Colors.white70,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Naqd pul',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // WALLET option
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            return GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Hamyon orqali to\'lov tez kunda ishga tushadi'),
                                    backgroundColor: OrbitaColors.primary,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: OrbitaColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFF2A2A3E),
                                    width: 1,
                                  ),
                                ),
                                child: const Opacity(
                                  opacity: 0.6,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.account_balance_wallet_rounded,
                                        color: Colors.white70,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Flexible(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Hamyon',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              'Tez kunda',
                                              style: TextStyle(
                                                color: OrbitaColors.textHint,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Price & Order button
          if (homeState.canOrder) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Taxminiy narx',
                        style: TextStyle(
                          color: OrbitaColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${(homeState.estimatedPrice ?? 0).toStringAsFixed(0)} so\'m',
                        style: const TextStyle(
                          color: OrbitaColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${homeState.distanceKm?.toStringAsFixed(1)} km • ${homeState.selectedTariff?.minMinutes}-${homeState.selectedTariff?.maxMinutes} daqiqa',
                        style: const TextStyle(
                          color: OrbitaColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: homeState.isLoading ? null : onOrderCreate,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: OrbitaColors.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: OrbitaColors.primary.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: homeState.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text(
                              'Taksi chaqirish',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class TariffCard extends StatelessWidget {
  final TariffModel tariff;
  final bool isSelected;
  final double? estimatedPrice;
  final VoidCallback onTap;

  const TariffCard({
    super.key,
    required this.tariff,
    required this.isSelected,
    this.estimatedPrice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 110,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? OrbitaColors.primary.withOpacity(0.15)
              : OrbitaColors.surfaceLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? OrbitaColors.primary
                : const Color(0xFF2A2A3E),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tariff.icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(
              tariff.name,
              style: TextStyle(
                color: isSelected
                    ? OrbitaColors.primary
                    : OrbitaColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            if (estimatedPrice != null) ...[
              const SizedBox(height: 2),
              Text(
                '${estimatedPrice!.toStringAsFixed(0)} so\'m',
                style: const TextStyle(
                  color: OrbitaColors.textSecondary,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
