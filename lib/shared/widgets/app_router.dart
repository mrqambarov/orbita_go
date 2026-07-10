import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/translations.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/phone_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/driver_home_screen.dart';
import '../../features/order/screens/order_tracking_screen.dart';
import '../../features/order/screens/driver_order_screen.dart';
import '../../features/order/screens/chat_screen.dart';
import '../../features/history/screens/history_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/driver_wallet_screen.dart';
import '../../features/profile/screens/referral_screen.dart';
import 'splash_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (authState.status == AuthStatus.loading) return null;
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
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) {
              final isDriver = ref.read(driverModeProvider);
              if (isDriver) {
                return const DriverHomeScreen();
              }
              return const HomeScreen();
            },
          ),
          GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/order/:id',
        builder: (context, state) {
          final orderId = state.pathParameters['id'] ?? '';
          return OrderTrackingScreen(orderId: orderId);
        },
      ),
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
      GoRoute(
        path: '/driver-wallet',
        builder: (_, __) => const DriverWalletScreen(),
      ),
      GoRoute(
        path: '/referral',
        builder: (_, __) => const ReferralScreen(),
      ),
      GoRoute(
        path: '/otp/:phone',
        builder: (context, state) {
          final phone = state.pathParameters['phone'] ?? '';
          final fullName = state.uri.queryParameters['name'];
          final referredByCode = state.uri.queryParameters['ref'];
          return OtpScreen(
            phone: phone,
            fullName: fullName,
            referredByCode: referredByCode,
          );
        },
      ),
    ],
  );
});

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    int currentIndex = 0;
    if (location == '/history') currentIndex = 1;
    if (location == '/profile') currentIndex = 2;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF13131F),
          border: Border(top: BorderSide(color: Color(0xFF2A2A3E))),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFF6C63FF),
          unselectedItemColor: const Color(0xFF6B6B8A),
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          onTap: (index) {
            if (index == 0) context.go('/home');
            if (index == 1) context.go('/history');
            if (index == 2) context.go('/profile');
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Bosh sahifa',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              label: 'Tarix',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
