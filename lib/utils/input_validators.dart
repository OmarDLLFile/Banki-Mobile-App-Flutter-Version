class InputValidators {
  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  static final RegExp _passwordUppercaseRegex = RegExp(r'[A-Z]');
  static final RegExp _passwordLowercaseRegex = RegExp(r'[a-z]');
  static final RegExp _numericRegex = RegExp(r'^\d+(\.\d+)?$');

  static String? requiredText(String? value, {required String fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }

    return null;
  }

  static String? email(String? value) {
    final requiredError = requiredText(value, fieldName: 'Email');

    if (requiredError != null) {
      return requiredError;
    }

    if (!_emailRegex.hasMatch(value!.trim())) {
      return 'Enter a valid email address';
    }

    return null;
  }

  static String? password(String? value) {
    final requiredError = requiredText(value, fieldName: 'Password');

    if (requiredError != null) {
      return requiredError;
    }

    final trimmed = value!.trim();

    if (trimmed.length < 8) {
      return 'Password must be at least 8 characters';
    }

    if (!_passwordUppercaseRegex.hasMatch(trimmed)) {
      return 'Password must contain an uppercase letter';
    }

    if (!_passwordLowercaseRegex.hasMatch(trimmed)) {
      return 'Password must contain a lowercase letter';
    }

    return null;
  }

  static String? amount(String? value, {String fieldName = 'Amount'}) {
    final requiredError = requiredText(value, fieldName: fieldName);

    if (requiredError != null) {
      return requiredError;
    }

    final trimmed = value!.trim();

    if (!_numericRegex.hasMatch(trimmed)) {
      return '$fieldName must contain only numbers';
    }

    final parsed = double.tryParse(trimmed);

    if (parsed == null || parsed <= 0) {
      return '$fieldName must be greater than 0';
    }

    return null;
  }
}
