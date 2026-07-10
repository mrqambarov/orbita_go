import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/localization/translations.dart';
import 'core/services/api_service.dart';
import 'core/services/socket_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/phone_screen.dart';
import 'features/home/screens/driver_home_screen.dart';
import 'features/order/screens/driver_order_screen.dart';
import 'features/order/screens/chat_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/history/screens/history_screen.dart';
import 'features/profile/screens/driver_wallet_screen.dart';
import 'shared/widgets/splash_screen.dart';
import 'shared/theme/app_theme.dart';

void main() {
  runApp(
    const ProviderScope(
      child: OrbitaDriverApp(),
    ),
  );
}

class OrbitaDriverApp extends ConsumerWidget {
  const OrbitaDriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Force driverModeProvider to true locally so the app routing functions in driver mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(driverModeProvider.notifier).state = true;
    });

    final router = ref.watch(driverRouterPrv);

    return MaterialApp.router(
      title: 'Orbita Driver',
      theme: OrbitaTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

// Router specifically for Driver App
final driverRouterPrv = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (authState.status == AuthStatus.initial) {
        return '/';
      }
      if (authState.status == AuthStatus.unauthenticated &&
          state.uri.path != '/phone') {
        return '/phone';
      }
      if (authState.status == AuthStatus.authenticated &&
          (state.uri.path == '/phone' || state.uri.path == '/')) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/phone', builder: (_, __) => const PhoneScreen()),
      GoRoute(path: '/home', builder: (_, __) => const DriverHomeScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
      GoRoute(path: '/driver-wallet', builder: (_, __) => const DriverWalletScreen()),
      GoRoute(
        path: '/driver-order/:id',
        builder: (context, state) {
          final orderId = state.pathParameters['id'] ?? '';
          return DriverOrderScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          final orderId = state.pathParameters['id'] ?? '';
          return ChatScreen(orderId: orderId);
        },
      ),
    ],
  );
});
