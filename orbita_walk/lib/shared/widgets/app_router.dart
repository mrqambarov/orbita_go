import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/walk/screens/walk_dashboard_screen.dart';
import '../../features/walk/screens/active_walk_screen.dart';
import '../../features/walk/screens/leaderboard_screen.dart';
import '../../features/profile/screens/achievements_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/walk/screens/coupon_wallet_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      if (authState.status == AuthStatus.loading || authState.status == AuthStatus.initial) {
        return null;
      }
      final isAuthenticated = authState.status == AuthStatus.authenticated;
      final isLoggingIn = state.uri.path == '/login';

      if (!isAuthenticated && !isLoggingIn) {
        return '/login';
      }
      if (isAuthenticated && isLoggingIn) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const WalkDashboardScreen(),
      ),
      GoRoute(
        path: '/active-walk',
        builder: (context, state) => const ActiveWalkScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/coupons',
        builder: (context, state) => const CouponWalletScreen(),
      ),
      GoRoute(
        path: '/leaderboard',
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: '/achievements',
        builder: (context, state) => const AchievementsScreen(),
      ),
    ],
  );
});
