import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_provider.dart';
import 'theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class InputInfo {
  final IconData icon;
  final String? prefixText;
  final String normalizedValue;

  InputInfo({required this.icon, this.prefixText, required this.normalizedValue});
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _referralCodeController = TextEditingController();

  bool _obscurePassword = true;
  bool _showReferralField = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  InputInfo _getInputInfo(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return InputInfo(
        icon: Icons.person_outline_rounded,
        normalizedValue: '',
      );
    }

    // 1. Orbita ID
    if (trimmed.startsWith('ORB-') || trimmed.startsWith('orb-') || trimmed.toLowerCase().startsWith('orb')) {
      return InputInfo(
        icon: Icons.rocket_launch_rounded,
        normalizedValue: trimmed.toUpperCase(),
      );
    }

    // 2. Email
    if (trimmed.contains('@') && trimmed.contains('.')) {
      return InputInfo(
        icon: Icons.email_outlined,
        normalizedValue: trimmed.toLowerCase(),
      );
    }

    // 3. Phone Number
    final cleanText = trimmed.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final isNumeric = RegExp(r'^\+?[0-9]+$').hasMatch(cleanText);
    if (isNumeric) {
      if (cleanText.startsWith('+998')) {
        return InputInfo(
          icon: Icons.phone_iphone_rounded,
          normalizedValue: cleanText,
        );
      } else if (cleanText.startsWith('998') && cleanText.length >= 12) {
        return InputInfo(
          icon: Icons.phone_iphone_rounded,
          normalizedValue: '+$cleanText',
        );
      } else {
        // Local 9-digit number
        return InputInfo(
          icon: Icons.phone_iphone_rounded,
          prefixText: '+998 ',
          normalizedValue: '+998$cleanText',
        );
      }
    }

    // 4. Username (default)
    return InputInfo(
      icon: Icons.alternate_email_rounded,
      normalizedValue: trimmed,
    );
  }

  Future<void> _onContinue() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      _showSnackBar('Identifikator kiritish lozim');
      return;
    }
    final info = _getInputInfo(identifier);
    await ref.read(authProvider.notifier).checkIdentifier(info.normalizedValue);
  }

  Future<void> _onLogin() async {
    final password = _passwordController.text;
    if (password.length < 6) {
      _showSnackBar('Parol kamida 6 ta belgidan iborat bo\'lishi kerak');
      return;
    }
    final identifier = ref.read(authProvider).identifier ?? '';
    final success = await ref.read(authProvider.notifier).login(identifier, password);
    if (!success && mounted) {
      _showErrorSnackBar();
    }
  }

  Future<void> _onRegister() async {
    final password = _passwordController.text;
    final fullName = _fullNameController.text.trim();
    final referralCode = _referralCodeController.text.trim();

    if (fullName.length < 3) {
      _showSnackBar('Ism-familiya kamida 3 ta belgidan iborat bo\'lishi shart');
      return;
    }
    if (password.length < 6) {
      _showSnackBar('Parol kamida 6 ta belgidan iborat bo\'lishi shart');
      return;
    }

    final identifier = ref.read(authProvider).identifier ?? '';
    final success = await ref.read(authProvider.notifier).register(
      identifier,
      password,
      fullName,
      referredByCode: referralCode.isNotEmpty ? referralCode : null,
    );
    if (!success && mounted) {
      _showErrorSnackBar();
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showErrorSnackBar() {
    final error = ref.read(authProvider).error ?? 'Xatolik';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final inputInfo = _getInputInfo(_identifierController.text);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.5),
            radius: 1.2,
            colors: [
              Color(0xFF140F3E),
              GamesTheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / Planet Icon
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: GamesTheme.primary.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                      gradient: const RadialGradient(
                        colors: [
                          GamesTheme.primary,
                          Color(0xFF006064),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.blur_on_rounded,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'ORBITA GAMES',
                    style: GoogleFonts.outfit(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2.0,
                      shadows: [
                        Shadow(
                          color: GamesTheme.primary.withOpacity(0.8),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Yagona kirish tizimi (Orbita ID SSO)',
                    style: TextStyle(color: GamesTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 36),

                  // SSO Steps
                  if (!authState.isIdentifierChecked) ...[
                    // Step 1: Identifier Check
                    TextField(
                      controller: _identifierController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Orbita ID, Telefon yoki Email',
                        prefixIcon: Icon(inputInfo.icon, color: GamesTheme.primary),
                        prefixText: inputInfo.prefixText,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GamesTheme.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: isLoading ? null : _onContinue,
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.black)
                            : const Text('DAVOM ETISH', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ] else if (authState.identifierExists) ...[
                    // Step 2a: Login
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: GamesTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: GamesTheme.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_circle_rounded, color: GamesTheme.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Mavjud profil: ${authState.identifier}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Parolingizni kiriting',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: GamesTheme.primary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: GamesTheme.textSecondary,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GamesTheme.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: isLoading ? null : _onLogin,
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.black)
                            : const Text('KIRISH', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: isLoading ? null : () => ref.read(authProvider.notifier).reset(),
                      child: const Text('Ortga qaytish', style: TextStyle(color: GamesTheme.textSecondary)),
                    ),
                  ] else ...[
                    // Step 2b: Register
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: GamesTheme.secondary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: GamesTheme.secondary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: GamesTheme.secondary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Yangi profil yaratish: ${authState.identifier}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _fullNameController,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Ism va familiyangiz',
                        prefixIcon: Icon(Icons.person_outline_rounded, color: GamesTheme.primary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Yangi parol yarating (Kamida 6 ta belgi)',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: GamesTheme.primary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: GamesTheme.textSecondary,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Expandable referral code input
                    GestureDetector(
                      onTap: () => setState(() => _showReferralField = !_showReferralField),
                      child: Row(
                        children: [
                          Icon(
                            _showReferralField ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                            color: GamesTheme.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _showReferralField ? 'Taklif kodini yopish' : 'Taklif kodi bormi? (Ixtiyoriy)',
                            style: const TextStyle(
                              color: GamesTheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_showReferralField) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _referralCodeController,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(color: Colors.white, letterSpacing: 1.5),
                        decoration: const InputDecoration(
                          hintText: 'ORB-XXXXXX',
                          prefixIcon: Icon(Icons.card_giftcard_rounded, color: GamesTheme.primary),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GamesTheme.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: isLoading ? null : _onRegister,
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.black)
                            : const Text('RO\'YXATDAN O\'TISH', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: isLoading ? null : () => ref.read(authProvider.notifier).reset(),
                      child: const Text('Ortga qaytish', style: TextStyle(color: GamesTheme.textSecondary)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
