abstract final class ProfileValidators {
  static String? phone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return 'Enter a phone number.';
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!RegExp(r'^\+?[0-9][0-9\s-]*$').hasMatch(phone) ||
        digits.length < 7 ||
        digits.length > 15) {
      return 'Enter 7–15 digits, optionally using +, spaces or hyphens.';
    }
    return null;
  }
}
