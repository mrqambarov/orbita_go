import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';

class AddressSearchBar extends StatelessWidget {
  final String hint;
  final String value;
  final VoidCallback onTap;

  const AddressSearchBar({
    super.key,
    required this.hint,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: OrbitaColors.card.withOpacity(0.95),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A2A3E)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.radio_button_checked,
              color: OrbitaColors.primary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value.isEmpty ? hint : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      value.isEmpty ? OrbitaColors.textHint : OrbitaColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
