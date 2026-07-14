import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_provider.dart';
import 'theme.dart';
import 'widgets/galaxy_background.dart';

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

class _LoginScreenState extends ConsumerState<LoginScreen> with TickerProviderStateMixin {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _referralCodeController = TextEditingController();
  final _otpController = TextEditingController();

  bool _obscurePassword = true;
  bool _showReferralField = false;

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _referralCodeController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  InputInfo _getInputInfo(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return InputInfo(icon: Icons.person_outline_rounded, normalizedValue: '');
    }
    if (trimmed.toLowerCase().startsWith('orb')) {
      return InputInfo(icon: Icons.rocket_launch_rounded, normalizedValue: trimmed.toUpperCase());
    }
    if (trimmed.contains('@') && trimmed.contains('.')) {
      return InputInfo(icon: Icons.email_outlined, normalizedValue: trimmed.toLowerCase());
    }
    final cleanText = trimmed.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final isNumeric = RegExp(r'^\+?[0-9]+$').hasMatch(cleanText);
    if (isNumeric) {
      if (cleanText.startsWith('+998')) {
        return InputInfo(icon: Icons.phone_iphone_rounded, normalizedValue: cleanText);
      } else if (cleanText.startsWith('998') && cleanText.length >= 12) {
        return InputInfo(icon: Icons.phone_iphone_rounded, normalizedValue: '+$cleanText');
      } else {
        return InputInfo(icon: Icons.phone_iphone_rounded, prefixText: '+998 ', normalizedValue: '+998$cleanText');
      }
    }
    return InputInfo(icon: Icons.alternate_email_rounded, normalizedValue: trimmed);
  }

  Future<void> _onContinue() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      _showSnackBar('Identifikator kiritish lozim');
      return;
    }
    final info = _getInputInfo(identifier);
    final val = info.normalizedValue;
    final isPhone = RegExp(r'^\+998[0-9]{9}$').hasMatch(val);
    if (isPhone) {
      final ok = await ref.read(authProvider.notifier).sendOtp(val);
      if (!ok && mounted) _showErrorSnackBar();
    } else {
      await ref.read(authProvider.notifier).checkIdentifier(val);
    }
  }

  Future<void> _onVerifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length < 4) {
      _showSnackBar('Tasdiqlash kodini kiriting');
      return;
    }
    final identifier = ref.read(authProvider).identifier ?? '';
    final name = _fullNameController.text.trim();
    final referral = _referralCodeController.text.trim();
    final success = await ref.read(authProvider.notifier).verifyOtp(
          identifier,
          code,
          fullName: name.isNotEmpty ? name : null,
          referredByCode: referral.isNotEmpty ? referral : null,
        );
    if (!success && mounted) _showErrorSnackBar();
  }

  Future<void> _onLogin() async {
    final password = _passwordController.text;
    if (password.length < 6) {
      _showSnackBar('Parol kamida 6 ta belgidan iborat bo\'lishi kerak');
      return;
    }
    final identifier = ref.read(authProvider).identifier ?? '';
    final success = await ref.read(authProvider.notifier).login(identifier, password);
    if (!success && mounted) _showErrorSnackBar();
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
    if (!success && mounted) _showErrorSnackBar();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showErrorSnackBar() {
    final error = ref.read(authProvider).error ?? 'Xatolik';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
    );
  }

  // ── Reusable UI ──────────────────────────────────────────
  InputDecoration _dec(String hint, IconData icon, {Widget? suffix, String? prefixText}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: GamesTheme.primary),
      prefixText: prefixText,
      suffixIcon: suffix,
    );
  }

  Widget _gameButton(String label, VoidCallback onTap, bool loading, {IconData? icon}) {
    return GestureDetector(
      onTap: loading ? null : () { HapticFeedback.mediumImpact(); onTap(); },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: loading ? 0.7 : 1,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [GamesTheme.primary, Color(0xFF7B2FF7)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: GamesTheme.primary.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: Center(
            child: loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[Icon(icon, color: Colors.black, size: 20), const SizedBox(width: 8)],
                      Text(label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final inputInfo = _getInputInfo(_identifierController.text);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: GamesTheme.background,
      body: GalaxyBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder: (_, t, child) => Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform.translate(offset: Offset(0, 30 * (1 - t)), child: child),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 22),
                    Text(
                      'ORBITA GAMES',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2.5,
                        shadows: [Shadow(color: GamesTheme.primary.withValues(alpha: 0.9), blurRadius: 20)],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('Galaktikadagi eng zo\'r arena', style: TextStyle(color: GamesTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 38),
                    _buildForm(authState, inputInfo, isLoading),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final v = _pulse.value; // 0..1
        return Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: GamesTheme.primary.withValues(alpha: 0.25 + 0.35 * v), blurRadius: 28 + 18 * v, spreadRadius: 2 + 6 * v),
              BoxShadow(color: GamesTheme.secondary.withValues(alpha: 0.15 + 0.2 * v), blurRadius: 40, spreadRadius: 1),
            ],
          ),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [GamesTheme.primary, Color(0xFF3B1F8F)]),
            ),
            child: const Icon(Icons.shield_moon_rounded, size: 58, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildForm(AuthState authState, InputInfo inputInfo, bool isLoading) {
    // Step 1 — Identifier
    if (!authState.isIdentifierChecked) {
      return Column(children: [
        TextField(
          controller: _identifierController,
          style: const TextStyle(color: Colors.white),
          onChanged: (_) => setState(() {}),
          decoration: _dec('Orbita ID, Telefon yoki Email', inputInfo.icon, prefixText: inputInfo.prefixText),
        ),
        const SizedBox(height: 24),
        _gameButton('BOSHLASH', _onContinue, isLoading, icon: Icons.play_arrow_rounded),
      ]);
    }

    // Step 2 — OTP (telefon)
    if (authState.otpSent) {
      return Column(children: [
        _infoChip(Icons.sms_rounded, 'SMS-kod yuborildi: ${authState.identifier}', GamesTheme.primary),
        const SizedBox(height: 20),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, letterSpacing: 10, fontSize: 22, fontWeight: FontWeight.bold),
          decoration: _dec('– – – – – –', Icons.password_rounded).copyWith(counterText: ''),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _fullNameController,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: Colors.white),
          decoration: _dec('Ism-familiya (yangi hisob uchun)', Icons.person_outline_rounded),
        ),
        const SizedBox(height: 24),
        _gameButton('TASDIQLASH VA KIRISH', _onVerifyOtp, isLoading, icon: Icons.login_rounded),
        _backButton(isLoading),
      ]);
    }

    // Step 3a — Login (parol)
    if (authState.identifierExists) {
      return Column(children: [
        _infoChip(Icons.account_circle_rounded, 'Mavjud profil: ${authState.identifier}', GamesTheme.primary),
        const SizedBox(height: 20),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: Colors.white),
          decoration: _dec('Parolingizni kiriting', Icons.lock_outline_rounded,
              suffix: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: GamesTheme.textSecondary),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              )),
        ),
        const SizedBox(height: 24),
        _gameButton('KIRISH', _onLogin, isLoading, icon: Icons.login_rounded),
        _backButton(isLoading),
      ]);
    }

    // Step 3b — Register (parol)
    return Column(children: [
      _infoChip(Icons.auto_awesome_rounded, 'Yangi profil: ${authState.identifier}', GamesTheme.secondary),
      const SizedBox(height: 20),
      TextField(
        controller: _fullNameController,
        textCapitalization: TextCapitalization.words,
        style: const TextStyle(color: Colors.white),
        decoration: _dec('Ism va familiyangiz', Icons.person_outline_rounded),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: const TextStyle(color: Colors.white),
        decoration: _dec('Yangi parol (kamida 6 ta belgi)', Icons.lock_outline_rounded,
            suffix: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: GamesTheme.textSecondary),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            )),
      ),
      const SizedBox(height: 14),
      GestureDetector(
        onTap: () => setState(() => _showReferralField = !_showReferralField),
        child: Row(children: [
          Icon(_showReferralField ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: GamesTheme.primary, size: 18),
          const SizedBox(width: 6),
          Text(_showReferralField ? 'Taklif kodini yopish' : 'Taklif kodi bormi? (Ixtiyoriy)',
              style: const TextStyle(color: GamesTheme.primary, fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
      ),
      if (_showReferralField) ...[
        const SizedBox(height: 10),
        TextField(
          controller: _referralCodeController,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: Colors.white, letterSpacing: 1.5),
          decoration: _dec('ORB-XXXXXX', Icons.card_giftcard_rounded),
        ),
      ],
      const SizedBox(height: 24),
      _gameButton('RO\'YXATDAN O\'TISH', _onRegister, isLoading, icon: Icons.rocket_launch_rounded),
      _backButton(isLoading),
    ]);
  }

  Widget _backButton(bool isLoading) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: TextButton(
          onPressed: isLoading ? null : () => ref.read(authProvider.notifier).reset(),
          child: const Text('Ortga qaytish', style: TextStyle(color: GamesTheme.textSecondary)),
        ),
      );
}
