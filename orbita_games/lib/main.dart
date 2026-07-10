import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_provider.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'theme.dart';
import 'widgets/production_error_boundary.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const ProviderScope(child: OrbitaGamesApp()));
}

class OrbitaGamesApp extends ConsumerWidget {
  const OrbitaGamesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Orbita Games',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: GamesTheme.primary,
        scaffoldBackgroundColor: GamesTheme.background,
        textTheme: GoogleFonts.outfitTextTheme(Theme.of(context).textTheme),
        colorScheme: ColorScheme.fromSeed(
          seedColor: GamesTheme.primary,
          brightness: Brightness.dark,
        ),
      ),
      builder: (context, child) => ProductionErrorBoundary(child: child!),
      home: authState.status == AuthStatus.authenticated
          ? const DashboardScreen()
          : const LoginScreen(),
    );
  }
}
