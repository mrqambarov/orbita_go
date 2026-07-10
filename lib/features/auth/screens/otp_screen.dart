import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../providers/auth_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/orbita_button.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  final String? fullName;
  final String? referredByCode;
  const OtpScreen({
    super.key,
    required this.phone,
    this.fullName,
    this.referredByCode,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with TickerProviderStateMixin {
  final _otpController = TextEditingController();
  bool _isComplete = false;
  int _resendSeconds = 60;
  late AnimationController _timerController;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendSeconds = 60;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendSeconds--);
      return _resendSeconds > 0;
    });
  }

  Future<void> _verify() async {
    final success = await ref
        .read(authProvider.notifier)
        .verifyOtp(
          widget.phone,
          _otpController.text,
          fullName: widget.fullName,
          referredByCode: widget.referredByCode,
        );
    if (success && mounted) {
      context.go('/home');
    } else if (mounted) {
      _shakeController.forward().then((_) => _shakeController.reverse());
      _otpController.clear();
      setState(() => _isComplete = false);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isLoading = auth.status == AuthStatus.loading;

    final defaultPinTheme = PinTheme(
      width: 60,
      height: 68,
      textStyle: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: OrbitaColors.textPrimary,
      ),
      decoration: BoxDecoration(
        color: OrbitaColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A3E), width: 1.5),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: OrbitaColors.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: OrbitaColors.primary.withOpacity(0.3),
            blurRadius: 12,
          ),
        ],
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: OrbitaColors.primary.withOpacity(0.15),
        border: Border.all(color: OrbitaColors.primary, width: 1.5),
      ),
    );

    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: OrbitaColors.error, width: 2),
        color: OrbitaColors.error.withOpacity(0.1),
      ),
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: OrbitaColors.backgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // Back button
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: OrbitaColors.surfaceLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF2A2A3E)),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: OrbitaColors.textPrimary,
                        size: 18,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Title
                  Text('SMS kod', style: Theme.of(context).textTheme.displayLarge),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: OrbitaColors.textSecondary,
                          ),
                      children: [
                        const TextSpan(text: 'Kod yuborildi: '),
                        TextSpan(
                          text: widget.phone,
                          style: const TextStyle(
                            color: OrbitaColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // OTP input
                  Center(
                    child: AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_shakeAnimation.value, 0),
                          child: child,
                        );
                      },
                      child: Pinput(
                        controller: _otpController,
                        length: 6,
                        defaultPinTheme: defaultPinTheme,
                        focusedPinTheme: focusedPinTheme,
                        submittedPinTheme: submittedPinTheme,
                        errorPinTheme: errorPinTheme,
                        hapticFeedbackType: HapticFeedbackType.lightImpact,
                        onCompleted: (pin) {
                          setState(() => _isComplete = true);
                          _verify();
                        },
                        onChanged: (value) {
                          setState(() => _isComplete = value.length == 6);
                        },
                      ),
                    ),
                  ),

                  if (auth.error != null) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        auth.error!,
                        style: const TextStyle(
                          color: OrbitaColors.error,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  OrbitaButton(
                    label: 'Tasdiqlash',
                    onPressed: (_isComplete && !isLoading) ? _verify : null,
                    isLoading: isLoading,
                  ),

                  const SizedBox(height: 24),

                  // Resend
                  Center(
                    child: _resendSeconds > 0
                        ? Text(
                            'Qayta yuborish: ${_resendSeconds}s',
                            style: const TextStyle(
                              color: OrbitaColors.textHint,
                              fontSize: 14,
                            ),
                          )
                        : GestureDetector(
                            onTap: () {
                              ref
                                  .read(authProvider.notifier)
                                  .sendOtp(widget.phone);
                              _startResendTimer();
                            },
                            child: const Text(
                              'Kodni qayta yuborish',
                              style: TextStyle(
                                color: OrbitaColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
