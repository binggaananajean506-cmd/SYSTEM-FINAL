abstract final class ESugidInputLimits {
  static const fullName = 100;
  static const email = 254;
  static const shortTitle = 100;
  static const address = 200;
  static const description = 1000;
  static const shortNote = 300;
  static const referenceNumber = 50;
  static const helpdeskSubject = 120;
  static const chatMessage = 500;
  static const imageBytes = 8 * 1024 * 1024;
}

class EmailDomainSuggestion {
  const EmailDomainSuggestion({
    required this.originalEmail,
    required this.correctedEmail,
  });

  final String originalEmail;
  final String correctedEmail;
}

abstract final class ESugidValidators {
  static const List<String> _commonEmailDomains = [
    'gmail.com',
    'yahoo.com',
    'outlook.com',
    'hotmail.com',
    'icloud.com',
  ];

  // These real providers are close to a supported provider name and must not
  // be treated as typos by the conservative distance check below.
  static const Set<String> _knownNearbyEmailDomains = {
    'mail.com',
    'ymail.com',
    'live.com',
    'msn.com',
    'aol.com',
    'gmx.com',
    'zoho.com',
    'fastmail.com',
    'protonmail.com',
  };

  static final RegExp _emailPattern = RegExp(
    r"^[A-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?(?:\.[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?)+$",
    caseSensitive: false,
  );

  static String? requiredText(
    String? value, {
    required String label,
    int minLength = 1,
    int? maxLength,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$label is required';
    if (text.length < minLength) {
      return '$label must have at least $minLength characters';
    }
    if (maxLength != null && text.length > maxLength) {
      return '$label must not exceed $maxLength characters';
    }
    return null;
  }

  static String? optionalText(
    String? value, {
    required String label,
    required int maxLength,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.length > maxLength) {
      return '$label must not exceed $maxLength characters';
    }
    return null;
  }

  static String? fullName(String? value) => requiredText(
    value,
    label: 'Full name',
    minLength: 2,
    maxLength: ESugidInputLimits.fullName,
  );

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email address is required';
    if (text.length > ESugidInputLimits.email ||
        text.contains(RegExp(r'\s')) ||
        !_emailPattern.hasMatch(text)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String normalizeEmail(String value) => value.trim().toLowerCase();

  /// Suggests a correction only when a syntactically valid address is one
  /// small edit away from a well-known provider. Unrelated and custom domains
  /// continue through normal authentication without being blocked.
  static EmailDomainSuggestion? commonEmailDomainSuggestion(String? value) {
    final emailAddress = normalizeEmail(value ?? '');
    if (email(emailAddress) != null) return null;

    final separator = emailAddress.lastIndexOf('@');
    if (separator <= 0 || separator == emailAddress.length - 1) return null;

    final localPart = emailAddress.substring(0, separator);
    final domain = emailAddress.substring(separator + 1);
    if (_commonEmailDomains.contains(domain) ||
        _knownNearbyEmailDomains.contains(domain)) {
      return null;
    }

    final domainParts = domain.split('.');
    if (domainParts.length != 2) return null;

    final provider = domainParts.first;
    final topLevelDomain = domainParts.last;
    String? closestDomain;
    var closestScore = 1 << 20;

    for (final candidate in _commonEmailDomains) {
      final candidateParts = candidate.split('.');
      final providerDistance = _damerauLevenshtein(
        provider,
        candidateParts.first,
      );
      final topLevelDistance = _damerauLevenshtein(
        topLevelDomain,
        candidateParts.last,
      );
      final isProviderTypo =
          topLevelDomain == candidateParts.last && providerDistance == 1;
      final isTopLevelTypo =
          provider == candidateParts.first && topLevelDistance == 1;
      if (!isProviderTypo && !isTopLevelTypo) continue;

      final score = providerDistance + topLevelDistance;
      if (score < closestScore) {
        closestScore = score;
        closestDomain = candidate;
      }
    }

    if (closestDomain == null) return null;
    return EmailDomainSuggestion(
      originalEmail: emailAddress,
      correctedEmail: '$localPart@$closestDomain',
    );
  }

  static int _damerauLevenshtein(String source, String target) {
    final rows = source.length + 1;
    final columns = target.length + 1;
    final distance = List.generate(
      rows,
      (row) => List<int>.filled(columns, 0)..[0] = row,
    );
    for (var column = 0; column < columns; column++) {
      distance[0][column] = column;
    }

    for (var row = 1; row < rows; row++) {
      for (var column = 1; column < columns; column++) {
        final substitutionCost =
            source.codeUnitAt(row - 1) == target.codeUnitAt(column - 1) ? 0 : 1;
        distance[row][column] = _minimumOf(
          distance[row - 1][column] + 1,
          distance[row][column - 1] + 1,
          distance[row - 1][column - 1] + substitutionCost,
        );
        if (row > 1 &&
            column > 1 &&
            source.codeUnitAt(row - 1) == target.codeUnitAt(column - 2) &&
            source.codeUnitAt(row - 2) == target.codeUnitAt(column - 1)) {
          final transposition = distance[row - 2][column - 2] + 1;
          if (transposition < distance[row][column]) {
            distance[row][column] = transposition;
          }
        }
      }
    }
    return distance.last.last;
  }

  static int _minimumOf(int first, int second, int third) {
    var minimum = first < second ? first : second;
    if (third < minimum) minimum = third;
    return minimum;
  }

  static String? philippineMobile(String? value) {
    final normalized = normalizePhilippineMobile(value ?? '');
    return normalized == null
        ? 'Enter a valid 11-digit PH mobile number'
        : null;
  }

  static String? normalizePhilippineMobile(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('63') && digits.length == 12) {
      digits = '0${digits.substring(2)}';
    } else if (digits.length == 10 && digits.startsWith('9')) {
      digits = '0$digits';
    }
    if (!RegExp(r'^09\d{9}$').hasMatch(digits)) return null;
    return '+63${digits.substring(1)}';
  }

  static String localPhilippineMobile(String value) {
    final normalized = normalizePhilippineMobile(value);
    return normalized == null ? value : '0${normalized.substring(3)}';
  }

  static String? pesoAmount(String? value) {
    final amount = parsePeso(value ?? '');
    if (amount == null) return 'Enter a valid amount';
    if (amount <= 0) return 'Amount must be greater than zero';
    if (amount > 999999999.99) return 'Amount is too large';
    return null;
  }

  static double? parsePeso(String value) {
    final cleaned = value.replaceAll(',', '').trim();
    if (!RegExp(r'^\d{1,9}(?:\.\d{1,2})?$').hasMatch(cleaned)) return null;
    return double.tryParse(cleaned);
  }

  static String normalizePeso(String value) {
    final amount = parsePeso(value);
    if (amount == null) return value.replaceAll(',', '').trim();
    return amount.toStringAsFixed(2);
  }

  static String formatPeso(String value) {
    final amount = parsePeso(value);
    if (amount == null) return value;
    final fixed = amount.toStringAsFixed(2).split('.');
    final digits = fixed.first;
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
      buffer.write(digits[index]);
    }
    return '$buffer.${fixed.last}';
  }

  static String? positiveWholeNumber(
    String? value, {
    String label = 'Quantity',
    int maximum = 999999,
  }) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < 1) return '$label must be greater than zero';
    if (parsed > maximum) return '$label must not exceed $maximum';
    return null;
  }

  static bool isSupportedImageMimeType(String? mimeType) {
    return const {
      'image/jpeg',
      'image/png',
      'image/webp',
    }.contains(mimeType?.toLowerCase());
  }

  static bool isSupportedImageFileName(String path) {
    final normalized = path.toLowerCase();
    return normalized.endsWith('.jpg') ||
        normalized.endsWith('.jpeg') ||
        normalized.endsWith('.png') ||
        normalized.endsWith('.webp');
  }

  // ── Password Validation (matches registration rules in signup_screen) ────
  static bool hasPasswordMinLength(String password) => password.length >= 8;
  static bool hasPasswordLetter(String password) =>
      RegExp(r'[a-zA-Z]').hasMatch(password);
  static bool hasPasswordNumber(String password) =>
      RegExp(r'[0-9]').hasMatch(password);
  static bool hasPasswordSymbol(String password) =>
      RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=~`\[\]\\;/]').hasMatch(password);
  static bool isPasswordSecure(String password) =>
      hasPasswordMinLength(password) &&
      hasPasswordLetter(password) &&
      hasPasswordNumber(password) &&
      hasPasswordSymbol(password);

  static String? validateRegistrationPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Password is required';
    if (!hasPasswordMinLength(text)) {
      return 'Password must be at least 8 characters';
    }
    if (!hasPasswordLetter(text)) {
      return 'Password must contain at least one letter';
    }
    if (!hasPasswordNumber(text)) {
      return 'Password must contain at least one number';
    }
    if (!hasPasswordSymbol(text)) {
      return 'Password must contain at least one special symbol';
    }
    return null;
  }
}
