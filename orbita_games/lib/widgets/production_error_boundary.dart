import 'package:flutter/material.dart';
import '../theme.dart';

class ProductionErrorBoundary extends StatelessWidget {
  final Widget child;
  const ProductionErrorBoundary({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Scaffold(
        backgroundColor: GamesTheme.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Kechirasiz, kutilmagan xatolik yuz berdi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Dasturni qaytadan ishga tushirib ko\'ring.',
                  style: TextStyle(color: GamesTheme.textSecondary),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GamesTheme.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('QAYTISH'),
                ),
              ],
            ),
          ),
        ),
      );
    };
    return child;
  }
}
