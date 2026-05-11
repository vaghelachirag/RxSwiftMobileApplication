import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxswift/features/auth/provider/login_provider.dart';
import '../../../core/widgets/rxswift_logo.dart';
import '../../theme/app_theme.dart';
import '../today_route/today_route_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _focusNode = FocusNode();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _focusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onSendOtp(WidgetRef ref) {
    FocusScope.of(context).unfocus();
    ref.read(loginProvider.notifier).sendOtp();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginProvider);
    final theme = Theme.of(context);

    // React to success state
    ref.listen<LoginState>(loginProvider, (prev, next) {
      if (next.isSuccess) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const TodayRouteScaffold(),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 56),

                    // ── Logo ──────────────────────────────────
                    const RxSwiftLogo(size: 72, showWordmark: true),

                    const SizedBox(height: 48),

                    // ── Heading ───────────────────────────────
                    Text(
                      'Welcome Back',
                      style: theme.textTheme.displaySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Please login to continue',
                      style: theme.textTheme.bodyMedium,
                    ),

                    const SizedBox(height: 36),

                    // ── Phone Field Label ─────────────────────
                    Text(
                      'Phone Number',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Phone Input ───────────────────────────
                    _PhoneField(
                      controller: _phoneController,
                      focusNode: _focusNode,
                      hasError: state.hasError,
                      errorText: state.errorMessage,
                      onChanged: (val) =>
                          ref.read(loginProvider.notifier).onPhoneChanged(val),
                    ),

                    const SizedBox(height: 28),

                    // ── CTA Button ────────────────────────────
                    _SendOtpButton(
                      isLoading: state.isLoading,
                      onPressed: () => _onSendOtp(ref),
                    ),

                    const Spacer(),

                    // ── Footer ────────────────────────────────
                    Center(
                      child: TextButton(
                        onPressed: () {
                          // TODO: navigate to support
                        },
                        child: Text(
                          'Need help? Contact Support',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────
//  Phone Field
// ─────────────────────────────────────────────────────────────

class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onChanged,
    this.errorText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.textOnPrimary,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: hasError ? AppColors.error : AppColors.border,
              width: hasError ? 1.8 : 1.2,
            ),
          ),
          child: Row(
            children: [
              // Country code prefix
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Text(
                      '🇨🇦',
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '+1',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      height: 20,
                      width: 1,
                      color: AppColors.border,
                    ),
                  ],
                ),
              ),
              // Phone number input
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _PhoneNumberFormatter(),
                  ],
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '(403) 555-0123',
                    hintStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      color: AppColors.textHint,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 16,
                    ),
                  ),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
        if (hasError && errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 14,
                  color: AppColors.error,
                ),
                const SizedBox(width: 4),
                Text(
                  errorText!,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Phone Number Formatter  (formats as (XXX) XXX-XXXX)
// ─────────────────────────────────────────────────────────────

class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length && i < 10; i++) {
      if (i == 0) buffer.write('(');
      if (i == 3) buffer.write(') ');
      if (i == 6) buffer.write('-');
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Send OTP Button
// ─────────────────────────────────────────────────────────────

class _SendOtpButton extends StatelessWidget {
  const _SendOtpButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teal,
          disabledBackgroundColor: AppColors.teal.withOpacity(0.75),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          elevation: 0,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: isLoading
              ? const SizedBox(
            key: ValueKey('loader'),
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          )
              : const Text(
            'Send OTP',
            key: ValueKey('label'),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}