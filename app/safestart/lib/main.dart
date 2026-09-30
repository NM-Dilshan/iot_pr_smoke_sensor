import 'package:flutter/material.dart';

import 'screens/splash/splash_screen.dart';
import 'theme/app_theme.dart';

void main() => runApp(const SafeStartApp());

class SafeStartApp extends StatelessWidget {
  const SafeStartApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SafeStart',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    home: const SplashScreen(),
  );
}
