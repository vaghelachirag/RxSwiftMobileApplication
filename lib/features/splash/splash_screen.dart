import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/rxswift_logo.dart';
import '../auth/login_screen.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ──────────────────────────────────
  late final AnimationController _logoController;
  late final AnimationController _wordmarkController;
  late final AnimationController _taglineController;
  late final AnimationController _exitController;

  // ── Animations ─────────────────────────────────────────────
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _wordmarkFade;
  late final Animation<Offset> _wordmarkSlide;
  late final Animation<double> _taglineFade;
  late final Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    // Logo pop-in
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Wordmark slide up
    _wordmarkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _wordmarkFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _wordmarkController, curve: Curves.easeOut),
    );
    _wordmarkSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _wordmarkController, curve: Curves.easeOut),
    );

    // Tagline fade
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeOut),
    );

    // Exit fade-out
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeIn),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Step 1 — logo animates in
    await Future.delayed(const Duration(milliseconds: 200));
    await _logoController.forward();

    // Step 2 — wordmark slides up
    await Future.delayed(const Duration(milliseconds: 100));
    await _wordmarkController.forward();

    // Step 3 — tagline fades in
    await Future.delayed(const Duration(milliseconds: 80));
    await _taglineController.forward();

    // Step 4 — hold for branding moment
    await Future.delayed(const Duration(milliseconds: 1400));

    // Step 5 — fade out, then push login
    await _exitController.forward();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _wordmarkController.dispose();
    _taglineController.dispose();
    _exitController.dispose();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Scaffold(
      body: FadeTransition(
        opacity: _exitFade,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0D2B7A), // deep navy-blue
                Color(0xFF0E5E6F), // deep teal
              ],
              stops: [0.0, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                SizedBox(height: screenH * 0.20),

                // ── Animated Logo ──────────────────────────
                ScaleTransition(
                  scale: _logoScale,
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: RxSwiftLogo(size: screenH * 0.22),
                  ),
                ),

                SizedBox(height: screenH * 0.036),

                // ── Wordmark ────────────────────────────────
                SlideTransition(
                  position: _wordmarkSlide,
                  child: FadeTransition(
                    opacity: _wordmarkFade,
                    child: RxSwiftLogo(
                      size: 0, // icon hidden; wordmark only
                      showWordmark: true,
                      wordmarkFontSize: screenH * 0.052,
                    ),
                  ),
                ),

                SizedBox(height: screenH * 0.018),

                // ── Tagline ─────────────────────────────────
                FadeTransition(
                  opacity: _taglineFade,
                  child: Text(
                    'C A L G A R Y',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: screenH * 0.016,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.55),
                      letterSpacing: 5.0,
                    ),
                  ),
                ),

                const Spacer(),

                // ── Loading indicator ───────────────────────
                FadeTransition(
                  opacity: _wordmarkFade,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(
                            Colors.white.withOpacity(0.60),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Powered by RxSwift',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.40),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: screenH * 0.06),
              ],
            ),
          ),
        ),
      ),
    );
  }
}