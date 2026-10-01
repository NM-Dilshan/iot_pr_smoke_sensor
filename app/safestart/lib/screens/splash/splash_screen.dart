import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.navigate = true});
  final bool navigate;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (!widget.navigate) return;
    _timer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.5),
          radius: 0.8,
          colors: [
            AppColors.gold.withValues(alpha: 0.08),
            AppColors.background,
          ],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 28,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/images/safestart_logo.png',
                        height: 136,
                        width: 130,
                        fit: BoxFit.cover,
                        semanticLabel: 'SafeStart shield with a road',
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text.rich(
                      const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Safe',
                            style: TextStyle(color: AppColors.gold),
                          ),
                          TextSpan(text: 'Start'),
                        ],
                      ),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Drive Safe, Work Safe\nLive Better',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.secondaryText,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/car_background.png',
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: 'Loading SafeStart',
                      ),
                    ),
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
