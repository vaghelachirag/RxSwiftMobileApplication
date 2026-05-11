import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxswift/theme/app_theme.dart';


import 'features/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    const ProviderScope(
      child: RxSwiftApp(),
    ),
  );
}

class RxSwiftApp extends StatelessWidget {
  const RxSwiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RxSwift Calgary',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      home: const SplashScreen(), // ← starts here, auto-navigates to Login
    );
  }
}