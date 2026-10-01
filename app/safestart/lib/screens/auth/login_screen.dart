import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

import '../../widgets/primary_button.dart';
import 'auth_layout.dart';
import 'auth_validators.dart';
import '../home/home_screen.dart';
import 'password_field.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.auth, this.managedSession = false});
  final AuthService? auth;
  final bool managedSession;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identity = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _identity.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.auth == null) {
        throw const AppFailure(
          'Authentication is unavailable. Restart the app.',
        );
      }
      await widget.auth!.signIn(_identity.text.trim(), _password.text);
      if (mounted && !widget.managedSession) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is AppFailure
              ? error.message
              : 'Unable to sign in. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => SignupScreen(auth: widget.auth)),
    );
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
            validator: AuthValidators.email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email',
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
          if (_error != null) Text(_error!),
          PrimaryButton(label: 'SIGN IN', onPressed: _signIn, isLoading: _busy),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text("Don't have an account?"),
              TextButton(
                onPressed: _busy ? null : _createAccount,
                child: const Text('Create Account'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
