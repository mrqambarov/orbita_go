import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/localization/translations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/orbita_button.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class InputInfo {
  final IconData icon;
  final String? prefixText;
  final String normalizedValue;

  InputInfo({required this.icon, this.prefixText, required this.normalizedValue});
}

class _PhoneScreenState extends ConsumerState<PhoneScreen>
    with TickerProviderStateMixin {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _referralCodeController = TextEditingController();

  bool _isIdentifierValid = false;
  bool _isPasswordValid = false;
  bool _isFullNameValid = false;
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
    // Check if it's numeric/starts with numbers
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
        // Just the 9-digit local phone number, e.g. 991234567
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

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
    _referralCodeController.dispose();
  }

  Future<void> _onContinue() async {
    final info = _getInputInfo(_identifierController.text);
    await ref.read(authProvider.notifier).checkIdentifier(info.normalizedValue);
  }

  Future<void> _onLogin() async {
    final identifier = ref.read(authProvider).identifier ?? '';
    final password = _passwordController.text;
    final success = await ref.read(authProvider.notifier).login(identifier, password);
    if (success && mounted) {
      context.go('/home');
    }
  }

  Future<void> _onRegister() async {
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
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isLoading = auth.status == AuthStatus.loading;
    final inputInfo = _getInputInfo(_identifierController.text);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: OrbitaColors.backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),

                  // Logo
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
                            Icons.rocket_launch_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          ref.watch(driverModeProvider) ? 'Orbita Driver' : 'Orbita Go',
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Yagona kirish (Orbita ID SSO)',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: OrbitaColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Auth Fields
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!auth.isIdentifierChecked) ...[
                            // Step 1: Identifier Input
                            const Text(
                              'Identifikator',
                              style: TextStyle(
                                color: OrbitaColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _identifierController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: inputInfo.prefixText != null ? TextInputType.phone : TextInputType.text,
                              decoration: InputDecoration(
                                hintText: inputInfo.prefixText != null ? '90 123 45 67' : 'Telefon, email, username yoki ID',
                                prefixIcon: Icon(inputInfo.icon, color: OrbitaColors.primary),
                                prefixText: inputInfo.prefixText,
                                prefixStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (auth.error != null) ...[
                              const SizedBox(height: 12),
                              _buildErrorCard(auth.error!),
                            ],
                            const SizedBox(height: 24),
                            OrbitaButton(
                              label: 'Davom etish',
                              onPressed: (_isIdentifierValid && !isLoading) ? _onContinue : null,
                              isLoading: isLoading,
                              icon: Icons.arrow_forward_rounded,
                            ),
                          ] else if (auth.isIdentifierChecked && auth.identifierExists) ...[
                            // Step 2A: Login (Password Input)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Tizimga kirish',
                                        style: TextStyle(
                                          color: OrbitaColors.textSecondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        auth.identifier ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, color: OrbitaColors.primary),
                                  onPressed: () => ref.read(authProvider.notifier).reset(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Parol (Oflayn: 123456)',
                                prefixIcon: Icon(Icons.lock_outline_rounded, color: OrbitaColors.textHint),
                              ),
                            ),
                            if (auth.error != null) ...[
                              const SizedBox(height: 12),
                              _buildErrorCard(auth.error!),
                            ],
                            const SizedBox(height: 24),
                            OrbitaButton(
                              label: 'Kirish',
                              onPressed: (_isPasswordValid && !isLoading) ? _onLogin : null,
                              isLoading: isLoading,
                              icon: Icons.login_rounded,
                            ),
                            if (inputInfo.icon == Icons.phone_iphone_rounded) ...[
                              const SizedBox(height: 12),
                              Center(
                                child: TextButton.icon(
                                  icon: const Icon(Icons.sms_rounded, color: OrbitaColors.primary),
                                  label: const Text(
                                    'SMS tasdiqlash kodi orqali kirish',
                                    style: TextStyle(
                                      color: OrbitaColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: isLoading ? null : () async {
                                    final phone = inputInfo.normalizedValue;
                                    final sent = await ref.read(authProvider.notifier).sendOtp(phone);
                                    if (sent && mounted) {
                                      context.push('/otp/$phone');
                                    }
                                  },
                                ),
                              ),
                            ],
                          ] else ...[
                            // Step 2B: Register (Tanishing / Yangi foydalanuvchi)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Keling, tanishib olamiz!',
                                        style: TextStyle(
                                          color: OrbitaColors.primary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        auth.identifier ?? '',
                                        style: const TextStyle(
                                          color: OrbitaColors.textSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, color: OrbitaColors.primary),
                                  onPressed: () => ref.read(authProvider.notifier).reset(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _fullNameController,
                              textCapitalization: TextCapitalization.words,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Ism-familiyangiz',
                                prefixIcon: Icon(Icons.badge_outlined, color: OrbitaColors.textHint),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Yangi parol yarating',
                                prefixIcon: Icon(Icons.lock_outline_rounded, color: OrbitaColors.textHint),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Referral code toggle
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
                                      fontWeight: FontWeight.w600,
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
                                  prefixIcon: Icon(Icons.card_giftcard_rounded, color: OrbitaColors.primary),
                                  helperText: 'Do\'stingizning Orbita ID kodini kiriting',
                                  helperStyle: TextStyle(color: OrbitaColors.textHint, fontSize: 11),
                                ),
                              ),
                            ],
                            if (auth.error != null) ...[
                              const SizedBox(height: 12),
                              _buildErrorCard(auth.error!),
                            ],
                            const SizedBox(height: 24),
                            OrbitaButton(
                              label: 'Ro\'yxatdan o\'tish',
                              onPressed: (_isFullNameValid && _isPasswordValid && !isLoading) ? _onRegister : null,
                              isLoading: isLoading,
                              icon: Icons.person_add_alt_1_rounded,
                            ),
                            if (inputInfo.icon == Icons.phone_iphone_rounded) ...[
                              const SizedBox(height: 12),
                              Center(
                                child: TextButton.icon(
                                  icon: const Icon(Icons.sms_rounded, color: OrbitaColors.primary),
                                  label: const Text(
                                    'SMS tasdiqlash kodi orqali ro\'yxatdan o\'tish',
                                    style: TextStyle(
                                      color: OrbitaColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: (isLoading || !_isFullNameValid) ? null : () async {
                                    final phone = inputInfo.normalizedValue;
                                    final name = Uri.encodeComponent(_fullNameController.text.trim());
                                    final refCode = Uri.encodeComponent(_referralCodeController.text.trim());
                                    final sent = await ref.read(authProvider.notifier).sendOtp(phone);
                                    if (sent && mounted) {
                                      context.push('/otp/$phone?name=$name&ref=$refCode');
                                    }
                                  },
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Bottom note
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        'Davom etish orqali siz ${ref.watch(driverModeProvider) ? "Orbita Driver" : "Orbita Go"} foydalanish shartlarini qabul qilasiz.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: OrbitaColors.textHint,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OrbitaColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OrbitaColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: OrbitaColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                color: OrbitaColors.error,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
