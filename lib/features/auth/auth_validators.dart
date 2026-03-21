class AuthValidators {
  static const int minPasswordLength = 12;

  static String? requiredText(String? value, String fieldLabel) {
    if ((value ?? '').trim().isEmpty) {
      return 'Please enter your $fieldLabel.';
    }
    return null;
  }

  static String? email(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) {
      return 'Please enter your email address.';
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  static String? mobileNumber(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Please enter your mobile number.';
    }
    if (normalizePhilippineMobile(value) == null) {
      return 'Enter a valid mobile number (example: 09XXXXXXXXX).';
    }
    return null;
  }

  static String? passwordPolicy(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Please enter your password.';
    }
    if (password.contains(RegExp(r'\s'))) {
      return 'Password cannot contain spaces.';
    }
    if (password.length < minPasswordLength) {
      return 'Password must be at least 12 characters.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must include at least one uppercase letter.';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Password must include at least one lowercase letter.';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must include at least one number.';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Password must include at least one symbol.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String originalPassword) {
    if ((value ?? '').isEmpty) {
      return 'Please confirm your password.';
    }
    if (value != originalPassword) {
      return 'Password and Confirm Password do not match.';
    }
    return null;
  }

  static String? normalizePhilippineMobile(String? rawInput) {
    final raw = (rawInput ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }
    final cleaned = raw.replaceAll(RegExp(r'[\s()-]'), '');
    final digits = cleaned.replaceAll(RegExp(r'\D'), '');

    if (RegExp(r'^09\d{9}$').hasMatch(digits)) {
      return '+63${digits.substring(1)}';
    }
    if (RegExp(r'^9\d{9}$').hasMatch(digits)) {
      return '+63$digits';
    }
    if (RegExp(r'^63\d{10}$').hasMatch(digits)) {
      return '+$digits';
    }
    if (RegExp(r'^\+639\d{9}$').hasMatch(cleaned)) {
      return cleaned;
    }
    return null;
  }
}
