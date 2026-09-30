abstract final class AuthValidators {
  static String? requiredField(String? value, String label) =>
      value == null || value.trim().isEmpty ? 'Enter your $label.' : null;

  static String? password(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter your password.';
    if (value.length < 6) return 'Use at least 6 characters.';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter your email.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }
}
