import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/rxswift_logo.dart';
import '../auth/login_screen.dart';

// ─────────────────────────────────────────────────────────────
//  Design tokens — matched with LoginScreen
// ─────────────────────────────────────────────────────────────

abstract class _C {
  /// Brand teal
  static const primary = Color(0xFF0AA99B);

  /// Page background (same as login)
  static const bg = Color(0xFFF0F4F8);

  /// Muted grey subtitles / hints
  static const textMuted = Color(0xFF7A8BA0);

  static const footer = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textMuted,
    letterSpacing: 0.5,
  );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ──────────────────────────────────
  late final AnimationController _logoController;
  late final AnimationController _loaderController;
  late final AnimationController _exitController;

  // ── Animations ─────────────────────────────────────────────
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _loaderFade;
  late final Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();

    // Light background → dark status-bar icons
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    // Logo pop-in
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.elasticOut,
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(
          0.0,
          0.5,
          curve: Curves.easeIn,
        ),
      ),
    );

    // Loader fade-in
    _loaderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _loaderFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loaderController,
        curve: Curves.easeOut,
      ),
    );

    // Exit fade-out
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: Curves.easeIn,
      ),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Step 1 — logo animates in
    await Future.delayed(const Duration(milliseconds: 200));
    await _logoController.forward();

    // Step 2 — loader fades in
    await Future.delayed(const Duration(milliseconds: 120));
    await _loaderController.forward();

    // Step 3 — hold for branding moment
    await Future.delayed(const Duration(milliseconds: 1500));

    // Step 4 — fade out, then push login
    await _exitController.forward();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const LoginScreen(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _loaderController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: FadeTransition(
          opacity: _exitFade,
          child: SafeArea(
            child: Stack(
              children: [

                Positioned.fill(
                  child: Center(
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: FadeTransition(
                        opacity: _logoFade,
                        child: const RxSwiftLogo(),
                      ),
                    ),
                  ),
                ),

                // ── Bottom loader + footer ─────────────────
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 32,
                  child: FadeTransition(
                    opacity: _loaderFade,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _C.primary,
                            ),
                          ),
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Powered by RxSwift',
                          style: _C.footer,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}