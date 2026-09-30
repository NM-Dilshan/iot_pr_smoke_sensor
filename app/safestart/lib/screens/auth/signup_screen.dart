import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import 'auth_layout.dart';
import 'auth_validators.dart';
import 'password_field.dart';

enum _UserType { employee, driver }

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _employeeId = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  _UserType _userType = _UserType.employee;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _employeeId,
      _email,
      _password,
      _confirmation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _createAccount() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    // Development only: no account or credentials are persisted.
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'Create Account',
    subtitle: 'Get started with SafeStart',
    child: Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            validator: (value) =>
                AuthValidators.requiredField(value, 'full name'),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _employeeId,
            validator: (value) =>
                AuthValidators.requiredField(value, 'employee ID'),
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Employee ID',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _email,
            validator: AuthValidators.email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 18),
          PasswordField(
            controller: _password,
            validator: AuthValidators.password,
          ),
          const SizedBox(height: 18),
          PasswordField(
            controller: _confirmation,
            label: 'Confirm Password',
            textInputAction: TextInputAction.done,
            onSubmitted: _createAccount,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Confirm your password.';
              }
              if (value != _password.text) return 'Passwords do not match.';
              return null;
            },
          ),
          const SizedBox(height: 24),
          Text('User type', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final type in _UserType.values)
                ChoiceChip(
                  label: Text(
                    type == _UserType.employee ? 'Employee' : 'Driver',
                  ),
                  selected: _userType == type,
                  selectedColor: AppColors.gold,
                  checkmarkColor: AppColors.background,
                  labelStyle: TextStyle(
                    color: _userType == type
                        ? AppColors.background
                        : AppColors.primaryText,
                  ),
                  onSelected: (_) => setState(() => _userType = type),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FormField<bool>(
            initialValue: false,
            validator: (value) => value == true
                ? null
                : 'Please agree to the Terms & Privacy Policy.',
            builder: (field) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.gold,
                  checkColor: AppColors.background,
                  value: field.value ?? false,
                  onChanged: field.didChange,
                  title: const Text('I agree to the Terms & Privacy Policy'),
                ),
                if (field.hasError)
                  Text(
                    field.errorText!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(label: 'CREATE ACCOUNT', onPressed: _createAccount),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Already have an account?'),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('SIGN IN'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
