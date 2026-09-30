import 'package:flutter/material.dart';

import '../../widgets/primary_button.dart';
import 'auth_layout.dart';
import 'auth_validators.dart';
import '../home/home_screen.dart';
import 'password_field.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identity = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _identity.dispose();
    _password.dispose();
    super.dispose();
  }

  void _signIn() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    // Development only: valid input proceeds without authenticating or storing credentials.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute<bool>(builder: (_) => const SignupScreen()));
    if (!mounted || created != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account created successfully')),
    );
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'Welcome Back',
    subtitle: 'Sign in to continue to SafeStart',
    child: Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _identity,
            validator: (value) =>
                AuthValidators.requiredField(value, 'email or employee ID'),
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email / Employee ID',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 18),
          PasswordField(
            controller: _password,
            validator: AuthValidators.password,
            textInputAction: TextInputAction.done,
            onSubmitted: _signIn,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password reset is not available yet.'),
                ),
              ),
              child: const Text('Forgot Password?'),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(label: 'SIGN IN', onPressed: _signIn),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text("Don't have an account?"),
              TextButton(
                onPressed: _createAccount,
                child: const Text('Create Account'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
