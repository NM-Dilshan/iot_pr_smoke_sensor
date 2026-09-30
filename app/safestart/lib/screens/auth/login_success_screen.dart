import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/primary_button.dart';
import 'login_screen.dart';

class LoginSuccessScreen extends StatelessWidget {
  const LoginSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: CustomCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.gold,
                    size: 48,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'SafeStart',
                    style: Theme.of(context).textTheme.headlineLarge
                        ?.copyWith(color: AppColors.gold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Login Successful',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Next Step: Dashboard',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  PrimaryButton(
                    label: 'Back to Sign In',
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const LoginScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
