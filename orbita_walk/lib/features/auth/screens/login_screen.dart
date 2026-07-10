import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/localization/translations.dart';
import '../../../shared/theme/app_theme.dart';

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

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _referralCodeController = TextEditingController();

  bool _isIdentifierValid = false;
  bool _isPasswordValid = false;
  bool _isFullNameValid = false;
  bool _obscurePassword = true;
  bool _showReferralField = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _fadeController.forward();
    _slideController.forward();

    _identifierController.addListener(_validateFields);
    _passwordController.addListener(_validateFields);
    _fullNameController.addListener(_validateFields);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
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

  void _validateFields() {
    setState(() {
      _isIdentifierValid = _identifierController.text.trim().isNotEmpty;
      _isPasswordValid = _passwordController.text.length >= 6;
      _isFullNameValid = _fullNameController.text.trim().length >= 3;
    });
  }

  Future<void> _onContinue() async {
    if (!_isIdentifierValid) return;
    final info = _getInputInfo(_identifierController.text);
    final success = await ref.read(authProvider.notifier).checkIdentifier(info.normalizedValue);
    if (success) {
      _slideController.reset();
      _slideController.forward();
    } else {
      _showError();
    }
  }

  Future<void> _onLogin() async {
    if (!_isPasswordValid) return;
    final identifier = ref.read(authProvider).identifier ?? '';
    final password = _passwordController.text;
    final success = await ref.read(authProvider.notifier).login(identifier, password);
    if (success && mounted) {
      context.go('/dashboard');
    } else {
      _showError();
    }
  }

  Future<void> _onRegister() async {
    if (!_isPasswordValid || !_isFullNameValid) return;
    final identifier = ref.read(authProvider).identifier ?? '';
    final password = _passwordController.text;
    final fullName = _fullNameController.text.trim();
    final referralCode = _referralCodeController.text.trim();
    final success = await ref.read(authProvider.notifier).register(
      identifier,
      password,
      fullName,
      referredByCode: referralCode.isNotEmpty ? referralCode : null,
    );
    if (success && mounted) {
      context.go('/dashboard');
    } else {
      _showError();
    }
  }

  void _showError() {
    final error = ref.read(authProvider).error;
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: OrbitaColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showLanguageBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: OrbitaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final currentLanguage = ref.watch(languageProvider);
        final languages = [
          {'code': 'uz', 'name': 'O\'zbekcha', 'flag': '🇺🇿'},
          {'code': 'ru', 'name': 'Русский', 'flag': '🇷🇺'},
          {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tilni tanlang / Выберите язык',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ...languages.map((lang) {
                  final isSelected = lang['code'] == currentLanguage;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? OrbitaColors.primary.withOpacity(0.08) : const Color(0xFF1C1C2E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? OrbitaColors.primary : const Color(0xFF2A2A3E),
                        width: 1.5,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Text(
                        lang['flag']!,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        lang['name']!,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: OrbitaColors.primary, size: 24)
                          : const Icon(Icons.circle_outlined, color: OrbitaColors.textHint, size: 22),
                      onTap: () {
                        ref.read(languageProvider.notifier).setLanguage(lang['code']!);
                        Navigator.pop(context);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isLoading = auth.status == AuthStatus.loading;
    final inputInfo = _getInputInfo(_identifierController.text);
    final currentLanguage = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: OrbitaColors.background,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: OrbitaColors.backgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Language Switcher
                  Align(
                    alignment: Alignment.topRight,
                    child: TextButton.icon(
                      onPressed: _showLanguageBottomSheet,
                      icon: const Icon(Icons.language_rounded, color: OrbitaColors.primary, size: 18),
                      label: Text(
                        currentLanguage == 'uz' ? 'UZ' : (currentLanguage == 'ru' ? 'RU' : 'EN'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Logo Card
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: OrbitaColors.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: OrbitaColors.primary.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.directions_run_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Orbita Walk',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Yagona kirish (Orbita ID SSO)',
                          style: TextStyle(
                            color: OrbitaColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Interactive slide transitions based on SSO step
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!auth.isIdentifierChecked) ...[
                            // Step 1: Enter Identifier
                            const Text(
                              'Identifikator',
                              style: TextStyle(
                                color: OrbitaColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _identifierController,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: 'Orbita ID, Telefon yoki Username',
                                prefixIcon: Icon(inputInfo.icon, color: OrbitaColors.primary),
                                prefixText: inputInfo.prefixText,
                                prefixStyle: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton(
                              onPressed: !_isIdentifierValid || isLoading ? null : _onContinue,
                              child: isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text('Davom etish'),
                            ),
                          ] else if (auth.identifierExists) ...[
                            // Step 2a: Login (User exists)
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: OrbitaColors.success, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  auth.identifier ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Parol',
                              style: TextStyle(
                                color: OrbitaColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: 'Parolingizni kiriting',
                                prefixIcon: const Icon(Icons.lock_outline_rounded, color: OrbitaColors.primary),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: OrbitaColors.textHint,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton(
                              onPressed: !_isPasswordValid || isLoading ? null : _onLogin,
                              child: isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text('Kirish'),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: isLoading ? null : () => ref.read(authProvider.notifier).reset(),
                              child: const Text(
                                'Ortga qaytish',
                                style: TextStyle(color: OrbitaColors.textHint),
                              ),
                            ),
                          ] else ...[
                            // Step 2b: Register (User does not exist)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: OrbitaColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: OrbitaColors.primary.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded, color: OrbitaColors.primaryLight, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Yangi profil: ${auth.identifier}',
                                      style: const TextStyle(
                                        color: OrbitaColors.primaryLight,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Ism-familiyangiz',
                              style: TextStyle(
                                color: OrbitaColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _fullNameController,
                              textCapitalization: TextCapitalization.words,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                hintText: 'Masalan: Toshmatov Ali',
                                prefixIcon: Icon(Icons.person_outline_rounded, color: OrbitaColors.primary),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Parol o\'rnating',
                              style: TextStyle(
                                color: OrbitaColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: 'Kamida 6 ta belgi',
                                prefixIcon: const Icon(Icons.lock_outline_rounded, color: OrbitaColors.primary),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: OrbitaColors.textHint,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () => setState(() => _showReferralField = !_showReferralField),
                              child: Row(
                                children: [
                                  Icon(
                                    _showReferralField ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                    color: OrbitaColors.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _showReferralField ? 'Taklif kodini yopish' : 'Taklif kodi bormi? (Ixtiyoriy)',
                                    style: const TextStyle(
                                      color: OrbitaColors.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_showReferralField) ...[
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _referralCodeController,
                                textCapitalization: TextCapitalization.characters,
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                                decoration: const InputDecoration(
                                  hintText: 'ORB-XXXXXX',
                                  prefixIcon: Icon(Icons.card_giftcard_rounded, color: OrbitaColors.primary),
                                ),
                              ),
                            ],
                            const SizedBox(height: 32),
                            ElevatedButton(
                              onPressed: !_isPasswordValid || !_isFullNameValid || isLoading ? null : _onRegister,
                              child: isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text('Ro\'yxatdan o\'tish'),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: isLoading ? null : () => ref.read(authProvider.notifier).reset(),
                              child: const Text(
                                'Ortga qaytish',
                                style: TextStyle(color: OrbitaColors.textHint),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Ushbu ilova umumiy Orbita ID kirish tizimiga ulangan. Mavjud profillaringiz orqali to\'g\'ridan-to\'g\'ri kirishingiz mumkin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: OrbitaColors.textHint,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
