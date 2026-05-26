import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxswift/features/auth/provider/auth_provider.dart';

import '../../widgets/app_dialougs.dart';
import '../../widgets/app_progress_dialoug.dart';
import '../../widgets/rxswift_logo.dart';
import '../today_route/today_route_screen.dart';

// ─────────────────────────────────────────────────────────────
//  Design tokens — tweak here, reflects everywhere
// ─────────────────────────────────────────────────────────────

abstract class _C {
  /// Brand teal
  static const primary      = Color(0xFF0AA99B);

  /// Page background
  static const bg           = Color(0xFFF0F4F8);

  /// Card / input fill
  static const surface      = Colors.white;

  /// Dark navy headings
  static const textDark     = Color(0xFF0B1A33);

  /// Muted grey subtitles / hints
  static const textMuted    = Color(0xFF7A8BA0);

  /// Input idle border
  static const border       = Color(0xFFDDE3EC);

  /// Error red
  static const error        = Color(0xFFE53935);

  static const _ff = 'Poppins';

  static const heading = TextStyle(
    fontFamily: _ff, fontSize: 26,
    fontWeight: FontWeight.w700, color: textDark,
  );
  static const sub = TextStyle(
    fontFamily: _ff, fontSize: 14,
    fontWeight: FontWeight.w400, color: textMuted,
  );
  static const label = TextStyle(
    fontFamily: _ff, fontSize: 13,
    fontWeight: FontWeight.w600, color: textDark,
  );
  static const inputText = TextStyle(
    fontFamily: _ff, fontSize: 15,
    fontWeight: FontWeight.w400, color: textDark,
  );
  static const hintText = TextStyle(
    fontFamily: _ff, fontSize: 15,
    fontWeight: FontWeight.w400, color: Color(0xFFB0BEC5),
  );
  static const btnText = TextStyle(
    fontFamily: _ff, fontSize: 16,
    fontWeight: FontWeight.w600, color: Colors.white,
    letterSpacing: 0.4,
  );
  static const footerText = TextStyle(
    fontFamily: _ff, fontSize: 12,
    fontWeight: FontWeight.w400, color: textMuted,
  );
  static const forgotText = TextStyle(
    fontFamily: _ff, fontSize: 13,
    fontWeight: FontWeight.w500, color: primary,
  );
  static const errorText = TextStyle(
    fontFamily: _ff, fontSize: 12,
    color: error,
  );
}

// ─────────────────────────────────────────────────────────────
//  Login Screen
// ─────────────────────────────────────────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey       = GlobalKey<FormState>();
  final _emailCtrl     = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  final _emailFocus    = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────

  void _submit() {

    _emailCtrl.text = "vaghelacd99@gmail.com";
    _passwordCtrl.text = "12345678";

    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    ref.read(authProvider.notifier).login(
      email:    _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
  }

  // ── Side-effects ──────────────────────────────────────────

  void _handleStateChange(AuthState? prev, AuthState next) {
    // ── Show progress when login starts ───────────────────────
    if (next.isLoading) {
      AppProgressDialog.show(context, message: '');
      return;
    }

    // ── Dismiss progress on any terminal state ────────────────
    if (prev?.isLoading == true) {
      AppProgressDialog.hide(context);
    }

    // ── Handle terminal states ────────────────────────────────
    if (next.isNoInternet) {
      AppDialogs.showNoInternet(context);
      return;
    }

    if (next.isSuccess) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const TodayRouteScaffold(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    ref.listen<AuthState>(authProvider, _handleStateChange);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 48),
                      // ── Logo ──────────────────────────────
                      Align(
                        alignment: Alignment.center,
                        child: RxSwiftLogo(),
                      ),
                      const SizedBox(height: 40),

                      // ── Heading ───────────────────────────
                      const Text('Welcome Back', style: _C.heading),
                      const SizedBox(height: 6),
                      const Text('Please login to continue', style: _C.sub),

                      const SizedBox(height: 32),

                      // ── Form card ─────────────────────────
                      _FormCard(
                        children: [

                          // Email
                          _FieldLabel('Email'),
                          const SizedBox(height: 8),
                          _AppTextField(
                            controller:      _emailCtrl,
                            focusNode:       _emailFocus,
                            hintText:        'driver@rxswift.com',
                            prefixIcon:      Icons.email_outlined,
                            keyboardType:    TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Please enter your email.';
                              }
                              if (!RegExp(r'^[\w.+-]+@[\w-]+\.\w+$')
                                  .hasMatch(v.trim())) {
                                return 'Please enter a valid email address.';
                              }
                              return null;
                            },
                            onSubmitted: (_) =>
                                FocusScope.of(context).requestFocus(_passwordFocus),
                          ),

                          const SizedBox(height: 20),

                          // Password
                          _FieldLabel('Password'),
                          const SizedBox(height: 8),
                          _AppTextField(
                            controller:      _passwordCtrl,
                            focusNode:       _passwordFocus,
                            hintText:        '••••••••',
                            prefixIcon:      Icons.lock_outline_rounded,
                            obscureText:     _obscurePassword,
                            textInputAction: TextInputAction.done,
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Please enter your password.';
                              }
                              return null;
                            },
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: _C.textMuted,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            onSubmitted: (_) => _submit(),
                          ),

                          const SizedBox(height: 8),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                // TODO: navigate to forgot-password screen
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Forgot Password?',
                                style: _C.forgotText,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // ── Inline API error ──────────────────
                      if (state.isError && state.errorMessage != null) ...[
                        const SizedBox(height: 14),
                        _ErrorBanner(state.errorMessage!),
                      ],
                      const SizedBox(height: 28),
                      _LoginButton(
                        isLoading: false,
                        onPressed: state.isLoading ? () {} : _submit,
                      ),

                      const SizedBox(height: 20),

                      // ── Divider hint ─────────────────────
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(color: Color(0xFFDDE3EC), thickness: 1),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Secure login',
                              style: _C.footerText.copyWith(fontSize: 11),
                            ),
                          ),
                          const Expanded(
                            child: Divider(color: Color(0xFFDDE3EC), thickness: 1),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      Center(
                        child: TextButton(
                          onPressed: () {

                          },
                          style: TextButton.styleFrom(
                            foregroundColor: _C.textMuted,
                          ),
                          child: const Text(
                            'Need help? Contact Support',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize:   12,
                              color:      _C.textMuted,
                              decoration: TextDecoration.underline,
                              decorationColor: _C.textMuted,
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
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Reusable sub-widgets
// ─────────────────────────────────────────────────────────────


class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: const Color(0xFF0B1A33).withOpacity(0.07),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Small bold label above each field.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: _C.label);
  }
}

/// Shared text field — identical API to original, updated decoration.
class _AppTextField extends StatelessWidget {
  const _AppTextField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText     = false,
    this.keyboardType    = TextInputType.text,
    this.textInputAction = TextInputAction.done,
    this.suffixIcon,
    this.validator,
    this.onSubmitted,
  });

  final TextEditingController       controller;
  final FocusNode                   focusNode;
  final String                      hintText;
  final IconData                    prefixIcon;
  final bool                        obscureText;
  final TextInputType               keyboardType;
  final TextInputAction             textInputAction;
  final Widget?                     suffixIcon;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>?       onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:       controller,
      focusNode:        focusNode,
      keyboardType:     keyboardType,
      textInputAction:  textInputAction,
      obscureText:      obscureText,
      validator:        validator,
      onFieldSubmitted: onSubmitted,
      style:            _C.inputText,
      decoration: InputDecoration(
        hintText:  hintText,
        hintStyle: _C.hintText,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(prefixIcon, size: 20, color: _C.textMuted),
        ),
        suffixIcon:     suffixIcon,
        filled:         true,
        fillColor:      const Color(0xFFF7F9FC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),

        // ── Borders ──────────────────────────────────────
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: _C.border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: _C.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: _C.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: _C.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: _C.error, width: 2),
        ),
        errorStyle: _C.errorText,
      ),
    );
  }
}

/// Red tinted error banner — shown when [AuthState.isError].
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          // ignore: deprecated_member_use
          color: _C.error.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: _C.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: _C.errorText.copyWith(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// Full-width teal login button with loading spinner.
class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.isLoading, required this.onPressed});
  final bool         isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _C.primary,
          // ignore: deprecated_member_use
          disabledBackgroundColor: _C.primary.withOpacity(0.55),
          foregroundColor: Colors.white,
          elevation:  0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: isLoading
              ? const SizedBox(
            key:    ValueKey('loader'),
            width:  22,
            height: 22,
            child:  CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          )
              : const Text(
            'Login',
            key:   ValueKey('label'),
            style: _C.btnText,
          ),
        ),
      ),
    );
  }
}