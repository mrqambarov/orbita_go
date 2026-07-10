import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/walk_provider.dart';
import '../../../core/localization/translations.dart';
import '../../../shared/theme/app_theme.dart';

class ActiveWalkScreen extends ConsumerStatefulWidget {
  const ActiveWalkScreen({super.key});

  @override
  ConsumerState<ActiveWalkScreen> createState() => _ActiveWalkScreenState();
}

class _ActiveWalkScreenState extends ConsumerState<ActiveWalkScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final walkState = ref.watch(walkProvider);

    // Listen to walk provider errors to show error dialog safely as a side-effect
    ref.listen<WalkState>(walkProvider, (previous, next) {
      if (next.permissionError != null && previous?.permissionError != next.permissionError) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: OrbitaColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Xatolik", style: TextStyle(color: OrbitaColors.error, fontWeight: FontWeight.bold)),
            content: Text(next.permissionError!, style: const TextStyle(color: Colors.white)),
            actions: [
              TextButton(
                onPressed: () {
                  ref.read(walkProvider.notifier).cancelSession();
                  Navigator.pop(context); // close dialog
                  context.go('/dashboard'); // return to dashboard
                },
                child: const Text("Tushunarli", style: TextStyle(color: OrbitaColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    });

    final distanceKm = double.parse((walkState.sessionSteps * 0.00076).toStringAsFixed(2));
    final calories = (walkState.sessionSteps * 0.04).round();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: OrbitaColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Session Status Header
              Text(
                context.tr('active_session').toUpperCase(),
                style: const TextStyle(
                  color: OrbitaColors.primaryLight,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              // Timer Display
              Text(
                _formatDuration(walkState.sessionDuration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 54,
                  fontWeight: FontWeight.w900,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),

              // Heartbeat/Pulsating Visualizer representation of walking
              Center(
                child: ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: OrbitaColors.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: OrbitaColors.primary.withOpacity(0.4),
                          blurRadius: 32,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.directions_walk_rounded,
                      color: Colors.white,
                      size: 72,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Dynamic counter displays
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: OrbitaColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF2A2A3E)),
                ),
                child: Column(
                  children: [
                    Text(
                      walkState.sessionSteps.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'Mashg\'ulot qadamlari',
                      style: TextStyle(
                        color: OrbitaColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFF2A2A3E)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Icon(Icons.edit_road_rounded, color: Colors.green),
                            const SizedBox(height: 6),
                            Text(
                              '$distanceKm km',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              context.tr('distance'),
                              style: const TextStyle(
                                color: OrbitaColors.textHint,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Icon(Icons.local_fire_department_rounded, color: Colors.orange),
                            const SizedBox(height: 6),
                            Text(
                              '$calories kcal',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              context.tr('calories'),
                              style: const TextStyle(
                                color: OrbitaColors.textHint,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Spacer(),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: OrbitaColors.error),
                          foregroundColor: OrbitaColors.error,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          // Dialog confirming cancel
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: OrbitaColors.surface,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: const Text('Mashg\'ulotni bekor qilish?', style: TextStyle(color: Colors.white)),
                              content: const Text(
                                'Bu mashg\'ulotda yig\'ilgan qadamlar saqlanmaydi.',
                                style: TextStyle(color: OrbitaColors.textSecondary),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Davom etish', style: TextStyle(color: OrbitaColors.textHint)),
                                ),
                                TextButton(
                                  onPressed: () {
                                    ref.read(walkProvider.notifier).cancelSession();
                                    Navigator.pop(context); // close dialog
                                    context.go('/dashboard'); // return to dashboard
                                  },
                                  child: const Text('Bekor qilish', style: TextStyle(color: OrbitaColors.error, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text('Bekor qilish'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OrbitaColors.success,
                        ),
                        onPressed: () async {
                          await ref.read(walkProvider.notifier).saveSession();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.tr('session_saved')),
                                backgroundColor: OrbitaColors.success,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                            context.go('/dashboard');
                          }
                        },
                        child: Text(context.tr('stop_walk')),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
